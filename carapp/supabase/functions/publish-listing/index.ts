// supabase/functions/publish-listing/index.ts
//
// Puts a draft listing online. The app has already:
//   - inserted the listing as `draft` with its data (RLS + trigger
//     protect_listing_fields: the app cannot publish by itself);
//   - uploaded the media to listing-drafts/<owner id>/<listing id>/:
//       video.mp4              the edited video (required)
//       cover.jpg              the cover (required)
//       photo-<NN>-<step>.jpg  carousel photos, NN = order, step = capture step
//
// This function (service role):
//   1. checks the caller owns the draft (owner or member of its dealer)
//      and that the required data is there;
//   2. moves the files to the public bucket listing-media/<listing id>/<uuid>.<ext>
//      (unguessable names, no user id in public URLs);
//   3. writes listing_media rows and the first price history row;
//   4. sets the listing active (published_at, last_confirmed_at, paths).
// On a failure after step 2 the files are moved back, so the draft can be
// published again.
//
// Input:  POST { listing_id, video_duration_ms? } with the user's JWT.
// Output: { listing_id }   (also when the listing is already active)
// Errors: { "error": "<code>" }
//   unauthorized | bad_request | not_found | not_draft | incomplete | missing_media | server_error

import { createClient } from "npm:@supabase/supabase-js@2";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PHOTO = /^photo-(\d{2})-([a-z0-9_]+)\.jpg$/;
const REQUIRED = ["make_id", "model_id", "year", "mileage_km", "price_cents", "fuel_type", "city"];

const DRAFTS = "listing-drafts";
const PUBLIC = "listing-media";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "bad_request" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // ---- who is calling ----
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const user = userData?.user;
  if (!user) return json(401, { error: "unauthorized" });

  // ---- input ----
  let body: { listing_id?: string; video_duration_ms?: number };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_request" });
  }
  const listingId = body.listing_id ?? "";
  if (!UUID.test(listingId)) return json(400, { error: "bad_request" });
  const duration = Number.isInteger(body.video_duration_ms) &&
      body.video_duration_ms! > 0 && body.video_duration_ms! <= 180_000
    ? body.video_duration_ms!
    : null;

  const admin = createClient(url, serviceKey);

  // ---- the draft, and the right to publish it ----
  const { data: listing, error: readError } = await admin
    .from("listings")
    .select("*")
    .eq("id", listingId)
    .maybeSingle();
  if (readError) return json(500, { error: "server_error" });
  if (!listing) return json(404, { error: "not_found" });

  let allowed = listing.owner_id === user.id;
  if (!allowed && listing.dealer_id) {
    const { data: member } = await admin
      .from("dealer_members")
      .select("profile_id")
      .eq("dealer_id", listing.dealer_id)
      .eq("profile_id", user.id)
      .maybeSingle();
    allowed = !!member;
  }
  if (!allowed) return json(404, { error: "not_found" });

  // A retry after a lost answer: already done.
  if (listing.status === "active") return json(200, { listing_id: listingId });
  if (listing.status !== "draft") return json(409, { error: "not_draft" });

  const missing = REQUIRED.filter((k) => listing[k] === null || listing[k] === "");
  if (missing.length > 0) return json(400, { error: "incomplete", fields: missing });

  // ---- the uploaded files ----
  const folder = `${listing.owner_id}/${listingId}`;
  const { data: files, error: listError } = await admin.storage
    .from(DRAFTS)
    .list(folder, { limit: 100 });
  if (listError) return json(500, { error: "server_error" });

  const names = new Set((files ?? []).map((f) => f.name));
  if (!names.has("video.mp4") || !names.has("cover.jpg")) {
    return json(409, { error: "missing_media" });
  }
  const photos = [...names]
    .map((name) => ({ name, match: PHOTO.exec(name) }))
    .filter((p) => p.match)
    .map((p) => ({ name: p.name, order: Number(p.match![1]), step: p.match![2] }))
    .sort((a, b) => a.order - b.order);

  // ---- move to the public bucket ----
  const moved: { from: string; to: string }[] = [];
  const moveBack = async () => {
    for (const m of moved.reverse()) {
      await admin.storage.from(PUBLIC).move(m.to, m.from, { destinationBucket: DRAFTS });
    }
  };
  const move = async (name: string, ext: string) => {
    const from = `${folder}/${name}`;
    const to = `${listingId}/${crypto.randomUUID()}.${ext}`;
    const { error } = await admin.storage.from(DRAFTS).move(from, to, { destinationBucket: PUBLIC });
    if (error) throw error;
    moved.push({ from, to });
    return to;
  };

  try {
    const videoPath = await move("video.mp4", "mp4");
    const coverPath = await move("cover.jpg", "jpg");
    const photoPaths: { path: string; step: string }[] = [];
    for (const p of photos) {
      photoPaths.push({ path: await move(p.name, "jpg"), step: p.step });
    }

    // ---- rows ----
    const media = [
      { listing_id: listingId, kind: "video", storage_path: videoPath, duration_ms: duration, sort_order: 0 },
      { listing_id: listingId, kind: "cover", storage_path: coverPath, sort_order: 0 },
      ...photoPaths.map((p, i) => ({
        listing_id: listingId,
        kind: "photo",
        capture_step: p.step,
        storage_path: p.path,
        sort_order: i + 1,
      })),
    ];
    const { error: mediaError } = await admin.from("listing_media").insert(media);
    if (mediaError) throw mediaError;

    const now = new Date().toISOString();
    const { error: updateError } = await admin
      .from("listings")
      .update({
        status: "active",
        published_at: now,
        last_confirmed_at: now,
        video_path: videoPath,
        cover_path: coverPath,
        video_duration_ms: duration,
      })
      .eq("id", listingId)
      .eq("status", "draft");
    if (updateError) {
      await admin.from("listing_media").delete().eq("listing_id", listingId);
      throw updateError;
    }

    // Not critical: the listing is online even if this row fails.
    await admin
      .from("listing_price_history")
      .insert({ listing_id: listingId, price_cents: listing.price_cents });
  } catch (e) {
    console.error("publish-listing", listingId, e);
    await moveBack().catch((err) => console.error("publish-listing move back", err));
    return json(500, { error: "server_error" });
  }

  return json(200, { listing_id: listingId });
});

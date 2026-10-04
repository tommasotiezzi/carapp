// supabase/functions/update-listing-media/index.ts
//
// Changes the video and/or the photos of a listing already online (or
// sold). The app has uploaded the new files to
// listing-drafts/<caller id>/<listing id>/:
//   video.mp4 + cover.jpg      only when the video was shot again
//   photo-<NN>-<step>.jpg      new carousel photos
//
// This function (service role):
//   1. checks the caller owns the listing (owner or member of its dealer)
//      and that it is active or sold;
//   2. checks the input: kept photos belong to the listing, new files
//      exist in the caller's folder;
//   3. moves the new files to listing-media/<listing id>/<uuid>.<ext>;
//   4. calls apply_listing_media() (one transaction): drops the photos not
//      kept, orders the carousel, adds the new photos, replaces video and
//      cover;
//   5. deletes the files no longer used, and the caller's leftovers.
// On a failure in step 3 or 4 the new files are moved back.
//
// Input:  POST {
//   listing_id,
//   video: boolean,                 true = video.mp4 + cover.jpg uploaded
//   video_duration_ms?,
//   photos: [ { media_id } | { file: "photo-NN-step.jpg" } ]   the whole carousel, in order
// } with the user's JWT.
// Output: { listing_id }
// Errors: { "error": "<code>" }
//   unauthorized | bad_request | not_found | not_editable | missing_media | server_error

import { createClient } from "npm:@supabase/supabase-js@2";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PHOTO = /^photo-(\d{2})-([a-z0-9_]+)\.jpg$/;
const MAX_PHOTOS = 30;

const DRAFTS = "listing-drafts";
const PUBLIC = "listing-media";

type PhotoInput = { media_id?: unknown; file?: unknown };

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
  let body: { listing_id?: string; video?: boolean; video_duration_ms?: number; photos?: PhotoInput[] };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_request" });
  }
  const listingId = body.listing_id ?? "";
  if (!UUID.test(listingId) || !Array.isArray(body.photos) || body.photos.length > MAX_PHOTOS) {
    return json(400, { error: "bad_request" });
  }
  const newVideo = body.video === true;
  const duration = Number.isInteger(body.video_duration_ms) &&
      body.video_duration_ms! > 0 && body.video_duration_ms! <= 180_000
    ? body.video_duration_ms!
    : null;

  const photos: ({ mediaId: string } | { file: string; step: string })[] = [];
  const seen = new Set<string>();
  for (const p of body.photos) {
    if (typeof p?.media_id === "string" && UUID.test(p.media_id) && p.file === undefined) {
      if (seen.has(p.media_id)) return json(400, { error: "bad_request" });
      seen.add(p.media_id);
      photos.push({ mediaId: p.media_id });
    } else if (typeof p?.file === "string" && p.media_id === undefined) {
      const match = PHOTO.exec(p.file);
      if (!match || seen.has(p.file)) return json(400, { error: "bad_request" });
      seen.add(p.file);
      photos.push({ file: p.file, step: match[2] });
    } else {
      return json(400, { error: "bad_request" });
    }
  }

  const admin = createClient(url, serviceKey);

  // ---- the listing, and the right to change it ----
  const { data: listing, error: readError } = await admin
    .from("listings")
    .select("id, owner_id, dealer_id, status")
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
  if (listing.status !== "active" && listing.status !== "sold") return json(409, { error: "not_editable" });

  // ---- kept photos are this listing's ----
  const keptIds = photos.flatMap((p) => ("mediaId" in p ? [p.mediaId] : []));
  if (keptIds.length > 0) {
    const { data: rows, error } = await admin
      .from("listing_media")
      .select("id")
      .eq("listing_id", listingId)
      .eq("kind", "photo")
      .in("id", keptIds);
    if (error) return json(500, { error: "server_error" });
    if ((rows ?? []).length !== keptIds.length) return json(400, { error: "bad_request" });
  }

  // ---- the uploaded files (the caller's folder) ----
  const folder = `${user.id}/${listingId}`;
  const { data: files, error: listError } = await admin.storage
    .from(DRAFTS)
    .list(folder, { limit: 100 });
  if (listError) return json(500, { error: "server_error" });
  const names = new Set((files ?? []).map((f) => f.name));
  if (newVideo && (!names.has("video.mp4") || !names.has("cover.jpg"))) {
    return json(409, { error: "missing_media" });
  }
  for (const p of photos) {
    if ("file" in p && !names.has(p.file)) return json(409, { error: "missing_media" });
  }

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

  let removed: string[] = [];
  try {
    const videoPath = newVideo ? await move("video.mp4", "mp4") : null;
    const coverPath = newVideo ? await move("cover.jpg", "jpg") : null;
    const items: ({ media_id: string } | { path: string; step: string })[] = [];
    for (const p of photos) {
      items.push("mediaId" in p ? { media_id: p.mediaId } : { path: await move(p.file, "jpg"), step: p.step });
    }

    const { data, error } = await admin.rpc("apply_listing_media", {
      p_listing_id: listingId,
      p_video_path: videoPath,
      p_cover_path: coverPath,
      p_video_duration_ms: newVideo ? duration : null,
      p_photos: items,
    });
    if (error) throw error;
    removed = (data as string[] | null) ?? [];
  } catch (e) {
    console.error("update-listing-media", listingId, e);
    await moveBack().catch((err) => console.error("update-listing-media move back", err));
    return json(500, { error: "server_error" });
  }

  // ---- clean up (not critical: the listing is already updated) ----
  if (removed.length > 0) {
    const { error } = await admin.storage.from(PUBLIC).remove(removed);
    if (error) console.error("update-listing-media remove old", listingId, error);
  }
  const leftovers = [...names].filter((n) => !moved.some((m) => m.from === `${folder}/${n}`));
  if (leftovers.length > 0) {
    await admin.storage.from(DRAFTS).remove(leftovers.map((n) => `${folder}/${n}`));
  }

  return json(200, { listing_id: listingId });
});

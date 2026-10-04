// supabase/functions/delete-account/index.ts
//
// Deletes the signed-in user's account (App Store / Play requirement for
// apps with sign up). The app asks for the password before calling this.
//
// Deleting the auth user cascades in the database: profile, preferences,
// favorites, saved searches, consents, the user's listings, chats,
// messages, reviews and notifications (see CLAUDE.md, "Foreign keys").
// Files in the user's storage folders are removed here too.
//
// Errors are returned as { "error": "<code>" }: unauthorized | server_error

import { createClient } from "npm:@supabase/supabase-js@2";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

/** Folders named after the user id: `{auth.uid}/...` (see Storage in CLAUDE.md). */
const USER_BUCKETS = ["listing-drafts", "avatars"];

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "server_error" });

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // ---- who is calling ----
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: userData } = await userClient.auth.getUser();
  const user = userData?.user;
  if (!user) return json(401, { error: "unauthorized" });

  const admin = createClient(url, serviceKey);

  // ---- files first (best effort: a leftover file must not block deletion) ----
  for (const bucket of USER_BUCKETS) {
    try {
      const { data: files } = await admin.storage.from(bucket).list(user.id, { limit: 1000 });
      const paths = (files ?? []).map((f) => `${user.id}/${f.name}`);
      if (paths.length > 0) await admin.storage.from(bucket).remove(paths);
    } catch (_) {
      // ignore, see above
    }
  }

  // ---- the account (cascades in the database) ----
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) return json(500, { error: "server_error" });

  return json(200, { deleted: true });
});

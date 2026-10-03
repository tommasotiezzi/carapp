// supabase/functions/dealer-signup/index.ts
//
// Creates a dealer for the signed-in user:
//   1. checks the Italian VAT number with VIES (EU Commission)
//   2. creates dealer + owner membership + free-trial subscription
//      with the service role (the app cannot write these tables directly)
//
// Errors are returned as { "error": "<code>" }:
//   unauthorized | bad_request | vat_invalid | vat_taken | vies_unavailable | server_error

import { createClient } from "npm:@supabase/supabase-js@2";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const addMonths = (date: Date, months: number) => {
  const d = new Date(date);
  d.setMonth(d.getMonth() + months);
  return d;
};

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
  let body: { vat_number?: string; display_name?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "bad_request" });
  }
  const vat = (body.vat_number ?? "").replace(/\s/g, "").toUpperCase().replace(/^IT/, "");
  const displayName = (body.display_name ?? "").trim().slice(0, 60);
  if (!/^\d{11}$/.test(vat) || displayName.length === 0) {
    return json(400, { error: "bad_request" });
  }

  const admin = createClient(url, serviceKey);

  // ---- already registered? ----
  const { data: existing } = await admin
    .from("dealers")
    .select("id")
    .eq("vat_number", `IT${vat}`)
    .maybeSingle();
  if (existing) return json(409, { error: "vat_taken" });

  // ---- VIES ----
  let vies: { isValid?: boolean; name?: string; address?: string } | null = null;
  try {
    const res = await fetch(
      `https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat/${vat}`,
      { signal: AbortSignal.timeout(8000) },
    );
    if (!res.ok) throw new Error(`VIES ${res.status}`);
    vies = await res.json();
  } catch {
    return json(503, { error: "vies_unavailable" });
  }
  if (!vies?.isValid) return json(422, { error: "vat_invalid" });

  // VIES returns "---" when the company did not publish its data
  const clean = (s?: string) => (s && s.trim() !== "---" ? s.trim() : null);
  const legalName = clean(vies.name) ?? displayName;
  const address = clean(vies.address);

  // ---- trial settings from app_config ----
  const { data: cfg } = await admin
    .from("app_config")
    .select("value")
    .eq("key", "dealer_trial")
    .maybeSingle();
  const trial = (cfg?.value ?? {}) as {
    trial_months?: number;
    conditional_free_months?: number;
    contact_threshold_total?: number;
    founder_price_cents?: number;
  };
  const now = new Date();
  const trialEnds = addMonths(now, trial.trial_months ?? 3);
  const conditionalEnds = addMonths(trialEnds, trial.conditional_free_months ?? 3);

  // ---- create ----
  const { data: dealer, error: dealerError } = await admin
    .from("dealers")
    .insert({
      legal_name: legalName,
      display_name: displayName,
      vat_number: `IT${vat}`,
      vat_verified_at: now.toISOString(),
      vies_payload: vies,
      address,
    })
    .select("id, display_name")
    .single();
  // Same VAT registered concurrently, between the check above and this insert.
  if (dealerError?.code === "23505") return json(409, { error: "vat_taken" });
  if (dealerError || !dealer) return json(500, { error: "server_error" });

  // Undo everything created above, explicitly (does not rely on CASCADE),
  // so the user can retry with the same VAT number.
  const rollback = async () => {
    await admin.from("subscriptions").delete().eq("dealer_id", dealer.id);
    await admin.from("dealer_members").delete().eq("dealer_id", dealer.id);
    await admin.from("dealers").delete().eq("id", dealer.id);
    return json(500, { error: "server_error" });
  };

  // Sequential on purpose: the profile update stays last, so a failure never
  // leaves the profile as dealer_member without a dealer.
  const { error: memberError } = await admin.from("dealer_members").insert({
    dealer_id: dealer.id,
    profile_id: user.id,
    role: "owner",
  });
  if (memberError) return rollback();

  const { error: subscriptionError } = await admin.from("subscriptions").insert({
    dealer_id: dealer.id,
    plan_id: "base",
    status: "trial",
    trial_started_at: now.toISOString(),
    trial_ends_at: trialEnds.toISOString(),
    conditional_ends_at: conditionalEnds.toISOString(),
    contact_threshold: trial.contact_threshold_total ?? 30,
    founder_price_cents: trial.founder_price_cents ?? 2900,
    is_founder: true,
  });
  if (subscriptionError) return rollback();

  const { error: profileError } = await admin
    .from("profiles")
    .update({ account_type: "dealer_member", intent: "dealer" })
    .eq("id", user.id);
  if (profileError) return rollback();

  return json(200, { dealer });
});

// Supabase Edge Function: RevenueCat webhook handler
// Deploy: supabase functions deploy revenuecat --no-verify-jwt
// Secrets required:
// - REVENUECAT_WEBHOOK_SECRET
// - SUPABASE_SERVICE_ROLE_KEY

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

function unauthorized(msg: string) {
  return new Response(JSON.stringify({ error: msg }), { status: 401 });
}

function badRequest(msg: string) {
  return new Response(JSON.stringify({ error: msg }), { status: 400 });
}

function ok(body: unknown) {
  return new Response(JSON.stringify(body ?? { ok: true }), { status: 200 });
}

function pickPlan(activeEntitlements: string[]): string {
  const keys = activeEntitlements.map((k) => k.toLowerCase());
  if (keys.includes("vip_gold")) return "vip_gold";
  if (keys.includes("vip")) return "vip";
  if (keys.includes("premium")) return "premium";
  if (keys.includes("basic")) return "basic";
  return "free";
}

function inferStatus(eventType: string | undefined, hasActive: boolean): string {
  if (hasActive) return "active";
  const t = (eventType || "").toUpperCase();
  if (t.includes("TRIAL")) return "trialing";
  if (t.includes("CANCEL")) return "canceled";
  if (t.includes("EXPIRE")) return "expired";
  if (t.includes("BILLING_ISSUE")) return "past_due";
  return "expired";
}

serve(async (req) => {
  try {
    if (req.method !== "POST") return badRequest("POST only");

    const authHeader = req.headers.get("authorization") || req.headers.get("Authorization") || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.substring(7) : authHeader;
    if (!WEBHOOK_SECRET || token !== WEBHOOK_SECRET) {
      return unauthorized("Invalid secret");
    }

    const event = await req.json();

    // Extract app_user_id (we use Supabase auth user id here)
    const appUserId: string | undefined = event?.app_user_id
      || event?.data?.app_user_id
      || event?.subscriber?.app_user_id
      || event?.event?.app_user_id;

    if (!appUserId) return badRequest("Missing app_user_id");

    // Collect active entitlements from various possible shapes
    let activeKeys: string[] = [];
    const a1 = event?.data?.entitlements?.active; // RC v2 style
    const a2 = event?.data?.customer_info?.entitlements?.active; // alt
    const a3 = event?.subscriber?.entitlements; // legacy map of entitlements

    if (a1 && typeof a1 === 'object') activeKeys = Object.keys(a1);
    else if (a2 && typeof a2 === 'object') activeKeys = Object.keys(a2);
    else if (a3 && typeof a3 === 'object') {
      // derive active by checking if expires_date is in the future or empty
      activeKeys = Object.entries(a3)
        .filter(([_, v]: [string, any]) => {
          const exp = v?.expires_date;
          if (!exp) return true; // non-expiring
          const d = new Date(exp);
          return isFinite(d.getTime()) && d.getTime() > Date.now();
        })
        .map(([k]) => k);
    }

    const plan = pickPlan(activeKeys);
    const status = inferStatus(event?.type, activeKeys.length > 0);

    // Update profile
    const { error } = await supabase
      .from('profiles')
      .update({
        active_plan_id: plan,
        subscription_status: status,
        updated_at: new Date().toISOString(),
      })
      .eq('id', appUserId);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    return ok({ app_user_id: appUserId, plan, status, active_entitlements: activeKeys });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const REVENUECAT_WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET")!;

serve(async (req) => {
  try {
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

    // Verify secret (simple shared secret header)
    const sig = req.headers.get("x-rc-webhook-secret");
    if (sig !== REVENUECAT_WEBHOOK_SECRET) return new Response("Unauthorized", { status: 401 });

    const body = await req.json(); // RevenueCat event payload
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Example: extract app_user_id and entitlement
    const appUserId: string | undefined = body?.event?.app_user_id;
    const entitlements = body?.event?.entitlements || {};
    // Pick the most privileged active entitlement (you can refine logic)
    let plan_id: string | null = null;
    for (const [entId, ent] of Object.entries<any>(entitlements)) {
      if (ent?.active === true) {
        plan_id = entId; // matches plans.rc_entitlement_id
        break;
      }
    }
    if (!appUserId || !plan_id) {
      return new Response(JSON.stringify({ ok: true, note: "no active entitlement" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Resolve seller by rc_app_user_id
    const { data: prof } = await supabase
      .from("profiles")
      .select("id")
      .eq("rc_app_user_id", appUserId)
      .maybeSingle();
    if (!prof) {
      return new Response(JSON.stringify({ ok: true, note: "no profile" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Set bounds if available in RC payload (optional)
    const nowISO = new Date().toISOString();

    await supabase.from("seller_subscriptions").upsert({
      seller_id: prof.id,
      provider: "revenuecat",
      plan_id: plan_id,
      status: "active",                     // No trials per your decision
      rc_app_user_id: appUserId,
      rc_original_app_user_id: body?.event?.original_app_user_id ?? null,
      rc_entitlement_id: plan_id,
      current_period_start: nowISO,         // Optional: set from RC if provided
      current_period_end: null,             // Optional: set from RC expiry if provided
      cancel_at_period_end: false,
      updated_at: nowISO,
    }, { onConflict: "seller_id,provider" });

    await supabase.from("profiles")
      .update({
        active_plan_id: plan_id,
        subscription_status: "active",
      })
      .eq("id", prof.id);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
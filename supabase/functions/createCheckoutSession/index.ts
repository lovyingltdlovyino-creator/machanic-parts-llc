// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "npm:stripe@12.17.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { getStripePriceId, type PlanId, type Term } from "../_shared/planMapping.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Credentials": "true",
};

type CreateCheckoutRequest = {
  plan_id: PlanId;
  term: Term;
};

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: "2024-06-20" });

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
    const auth = req.headers.get("Authorization");
    if (!auth) return new Response("Unauthorized", { status: 401, headers: corsHeaders });

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: auth } },
    });

    const { data: { user }, error: userErr } = await supabase.auth.getUser();
    if (userErr || !user) return new Response("Unauthorized", { status: 401, headers: corsHeaders });

    const body: CreateCheckoutRequest = await req.json();
    const priceId = getStripePriceId(body.plan_id, body.term);

    // Ensure stripe_customer_id on profile
    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_customer_id")
      .eq("id", user.id)
      .maybeSingle();

    let customerId = profile?.stripe_customer_id ?? null;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email ?? undefined,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;
      await supabase.from("profiles")
        .update({ stripe_customer_id: customerId })
        .eq("id", user.id);
    }

    // Create Checkout
    const origin = new URL(req.url).origin;
    const resolveBase = () => {
      const env = Deno.env.get("APP_BASE_URL")?.trim();
      if (env) {
        try { return new URL(env).origin; } catch (_) { /* ignore bad env */ }
      }
      const hdr = req.headers.get("origin")?.trim();
      if (hdr) {
        try { return new URL(hdr).origin; } catch (_) { /* ignore bad header */ }
      }
      return origin;
    };
    const APP_BASE_URL = resolveBase();
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      line_items: [{ price: priceId, quantity: 1 }],
      // Use hash routing for Flutter Web
      success_url: `${APP_BASE_URL}/#/billing?success=1`,
      cancel_url: `${APP_BASE_URL}/#/billing?canceled=1`,
      allow_promotion_codes: true,
    });

    return new Response(JSON.stringify({ checkout_url: session.url }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: corsHeaders });
  }
});
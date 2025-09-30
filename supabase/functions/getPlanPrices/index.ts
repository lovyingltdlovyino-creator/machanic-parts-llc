// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "npm:stripe@12.17.0";
import { getStripePriceId, type PlanId, type Term } from "../_shared/planMapping.ts";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;
const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: "2024-06-20" });

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Credentials": "true",
};

type RequestBody = {
  term?: Term;
};

type PriceInfo = { unit_amount: number | null; currency: string | null };

type ResponseBody = {
  term: Term;
  prices: Record<PlanId, PriceInfo>;
};

const PLANS: PlanId[] = ["basic", "premium", "vip", "vip_gold"];

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
    }

    const body: RequestBody = await req.json().catch(() => ({}));
    const term: Term = (body.term as Term) ?? "monthly";

    const prices: Record<string, PriceInfo> = {};

    for (const plan of PLANS) {
      try {
        const priceId = getStripePriceId(plan, term);
        const price = await stripe.prices.retrieve(priceId);
        prices[plan] = {
          unit_amount: price.unit_amount ?? null,
          currency: price.currency ?? null,
        };
      } catch (_) {
        prices[plan] = { unit_amount: null, currency: null };
      }
    }

    const res: ResponseBody = { term, prices: prices as Record<PlanId, PriceInfo> };
    return new Response(JSON.stringify(res), { headers: { "Content-Type": "application/json", ...corsHeaders } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: corsHeaders });
  }
});

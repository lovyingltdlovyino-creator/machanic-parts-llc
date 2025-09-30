// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "npm:stripe@12.17.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { STRIPE_PRICE_IDS, type PlanId } from "../_shared/planMapping.ts";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: "2024-06-20" });

serve(async (req) => {
  const sig = req.headers.get("Stripe-Signature");
  if (!sig) return new Response("No signature", { status: 400 });

  const rawBody = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(rawBody, sig, STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return new Response(`Webhook Error: ${err}`, { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  async function upsertSubscriptionFromStripe(sub: Stripe.Subscription) {
    const customerId = (sub.customer as any) as string;
    // find seller by stripe_customer_id
    const { data: prof } = await supabase
      .from("profiles")
      .select("id")
      .eq("stripe_customer_id", customerId)
      .maybeSingle();
    if (!prof) return;

    const item = sub.items.data[0];
    const price = item?.price;
    let plan_id = (price?.metadata?.plan_id as string) ?? null;
    if (!plan_id && price?.id) {
      // Fallback: infer plan_id by matching the price.id against our mapping
      for (const [pid, byTerm] of Object.entries(STRIPE_PRICE_IDS)) {
        const list = Object.values(byTerm);
        if (list.includes(price.id)) {
          plan_id = pid as PlanId;
          break;
        }
      }
    }
    const term = price?.metadata?.term; // not persisted here but available if needed
    const status = (sub.status as any) || "active";

    await supabase.from("seller_subscriptions").upsert({
      seller_id: prof.id,
      provider: "stripe",
      plan_id: plan_id ?? 'basic',
      status,
      stripe_customer_id: customerId,
      stripe_subscription_id: sub.id,
      stripe_price_id: price?.id ?? null,
      current_period_start: sub.current_period_start ? new Date(sub.current_period_start * 1000).toISOString() : null,
      current_period_end: sub.current_period_end ? new Date(sub.current_period_end * 1000).toISOString() : null,
      cancel_at_period_end: sub.cancel_at_period_end ?? false,
      trial_end: sub.trial_end ? new Date(sub.trial_end * 1000).toISOString() : null,
      updated_at: new Date().toISOString(),
    }, { onConflict: "seller_id,provider" });

    // denormalize on profiles
    await supabase.from("profiles")
      .update({
        active_plan_id: plan_id ?? 'basic',
        subscription_status: status,
      })
      .eq("id", prof.id);

    // If period rolled, insert a usage_counters row (optional future enhancement)
  }

  switch (event.type) {
    case "checkout.session.completed":
      // no-op; subscription.created/updated will follow
      break;
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted":
      await upsertSubscriptionFromStripe(event.data.object as Stripe.Subscription);
      break;
    case "invoice.paid":
    case "invoice.payment_failed":
      // optional: track dunning status
      break;
    default:
      break;
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
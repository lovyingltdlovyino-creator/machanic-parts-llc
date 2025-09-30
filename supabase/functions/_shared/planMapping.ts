// plan mapping file // supabase/functions/_shared/planMapping.ts
export type Term = 'monthly'|'quarterly'|'semiannual'|'annual';
export type PlanId =
  | 'basic' | 'premium' | 'vip' | 'vip_gold';

// Fill these with your real Stripe IDs after creation
export const STRIPE_PRICE_IDS: Record<PlanId, Record<Term, string>> = {
  basic: {
    monthly:    'price_1SCEWdHTXKb5060hDIxIkkoZ',
    quarterly:  'price_1SCEaSHTXKb5060hejoNNMnS',
    semiannual: 'price_1SCEc8HTXKb5060hLalamcK7',
    annual:     'price_1SCEdNHTXKb5060hiSp32Xa0',
  },
  premium: {
    monthly:    'price_1SCEfUHTXKb5060hkPJRh4tJ',
    quarterly:  'price_1SCEgvHTXKb5060hgO1eDxRs',
    semiannual: 'price_1SCEllHTXKb5060hnYryf99P',
    annual:     'price_1SCEsfHTXKb5060hv2bZoa7Y',
  },
  vip: {
    monthly:    'price_1SCEtkHTXKb5060hTr6R5S2y',
    quarterly:  'price_1SCEupHTXKb5060hRHs0kI66',
    semiannual: 'price_1SCEvUHTXKb5060hP8FdWR4y',
    annual:     'price_1SCEwaHTXKb5060hganxVCRu',
  },
  vip_gold: {
    monthly:    'price_1SCFEuHTXKb5060hRtv885ah',
    quarterly:  'price_1SCFFmHTXKb5060hD6Jt9oCo',
    semiannual: 'price_1SCFHKHTXKb5060haR0hDqCG',
    annual:     'price_1SCFIbHTXKb5060hThCWxRng',
  },
};

export function getStripePriceId(planId: PlanId, term: Term) {
  const p = STRIPE_PRICE_IDS[planId];
  if (!p) throw new Error(`Unknown planId ${planId}`);
  const id = p[term];
  if (!id) throw new Error(`Missing price for ${planId}:${term}`);
  return id;
}

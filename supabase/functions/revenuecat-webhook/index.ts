// SixPack AI · phase 138 B-5 — RevenueCat webhook handler
//
// Deploys to: https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
//
// Receives subscription lifecycle events from RevenueCat (INITIAL_PURCHASE,
// RENEWAL, EXPIRATION, etc.) and mirrors the resulting entitlement state
// into `public.pro_entitlements`. The Flutter client reads RC's
// customerInfo as its primary signal — this table is the server-side
// source of truth that gates anything RLS-protected (future Pro-only
// data endpoints, server-side feature flags, etc.).
//
// Required Supabase environment (set with `supabase secrets set`):
//   • REVENUECAT_WEBHOOK_SECRET  — shared secret configured in the RC
//                                  dashboard Authorization header. The
//                                  webhook is rejected if absent or
//                                  mismatched.
//   • SUPABASE_URL               — usually populated automatically.
//   • SUPABASE_SERVICE_ROLE_KEY  — service-role JWT for bypassing RLS
//                                  on `pro_entitlements`. NEVER ship
//                                  this anywhere client-side.
//
// RevenueCat webhook docs:
//   https://www.revenuecat.com/docs/webhooks

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

// RC event types that mean "user currently has access". Anything else
// either leaves the state alone (CANCELLATION → still active until
// expires_at) or flips it to inactive (EXPIRATION, SUBSCRIPTION_PAUSED).
const ACTIVE_EVENT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "TRANSFER",
]);

const INACTIVE_EVENT_TYPES = new Set([
  "EXPIRATION",
  "SUBSCRIPTION_PAUSED",
]);

// RC payload shape (subset — we only read what we mirror). Full schema
// at https://www.revenuecat.com/docs/webhooks#sample-event.
interface RevenueCatEvent {
  id: string;
  type: string;
  app_user_id: string;
  product_id?: string;
  period_type?: string; // "NORMAL" | "TRIAL" | "INTRO" | "PROMOTIONAL"
  expiration_at_ms?: number;
  event_timestamp_ms?: number;
  entitlement_ids?: string[];
}

interface RevenueCatPayload {
  event: RevenueCatEvent;
  api_version: string;
}

function unauthorized(reason: string): Response {
  return new Response(JSON.stringify({ error: reason }), {
    status: 401,
    headers: { "Content-Type": "application/json" },
  });
}

function badRequest(reason: string): Response {
  return new Response(JSON.stringify({ error: reason }), {
    status: 400,
    headers: { "Content-Type": "application/json" },
  });
}

function ok(body: Record<string, unknown> = { ok: true }): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return badRequest("Only POST is accepted");
  }

  // Authorization. RC sends a Bearer token derived from the value
  // you paste into the dashboard's "Authorization header" field;
  // anything else is dropped on the floor. We compare the full
  // header rather than just the secret so an attacker that knows
  // we use Bearer still has to land on the exact format.
  const expected = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!expected) {
    return unauthorized("Webhook secret not configured on the server");
  }
  const provided = req.headers.get("Authorization");
  if (provided !== `Bearer ${expected}`) {
    return unauthorized("Bad authorization header");
  }

  let payload: RevenueCatPayload;
  try {
    payload = (await req.json()) as RevenueCatPayload;
  } catch (_e) {
    return badRequest("Invalid JSON body");
  }

  const event = payload?.event;
  if (!event?.id || !event?.type || !event?.app_user_id) {
    return badRequest("Missing event fields");
  }

  // Map event type → active flag. Events outside of the active /
  // inactive sets (e.g. CANCELLATION) leave the existing flag
  // untouched — the user still has access until expires_at.
  let nextIsActive: boolean | null;
  if (ACTIVE_EVENT_TYPES.has(event.type)) {
    nextIsActive = true;
  } else if (INACTIVE_EVENT_TYPES.has(event.type)) {
    nextIsActive = false;
  } else {
    nextIsActive = null; // leave existing is_active alone
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false } },
  );

  // Idempotency. RC retries on non-2xx for up to ~3 days; we don't
  // want a re-delivery to re-stamp the row and confuse downstream
  // observers. If the most recent event_id matches the incoming
  // one we just acknowledge and move on.
  const { data: existing, error: existingErr } = await supabase
    .from("pro_entitlements")
    .select("user_id, is_active, last_event_id")
    .eq("user_id", event.app_user_id)
    .maybeSingle();

  if (existingErr) {
    return badRequest(`Lookup failed: ${existingErr.message}`);
  }

  if (existing?.last_event_id === event.id) {
    return ok({ ok: true, idempotent: true });
  }

  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  const trialExpiresAt = event.period_type === "TRIAL" ? expiresAt : null;

  const eventAt = event.event_timestamp_ms
    ? new Date(event.event_timestamp_ms).toISOString()
    : new Date().toISOString();

  // If the event doesn't move the active flag (CANCELLATION,
  // BILLING_ISSUE, etc.) keep whatever was already in the row.
  const finalIsActive = nextIsActive ?? (existing?.is_active ?? false);

  const { error: upsertErr } = await supabase
    .from("pro_entitlements")
    .upsert(
      {
        user_id: event.app_user_id,
        is_active: finalIsActive,
        product_id: event.product_id ?? null,
        expires_at: expiresAt,
        trial_expires_at: trialExpiresAt,
        last_event_type: event.type,
        last_event_id: event.id,
        last_event_at: eventAt,
      },
      { onConflict: "user_id" },
    );

  if (upsertErr) {
    return badRequest(`Upsert failed: ${upsertErr.message}`);
  }

  return ok({
    ok: true,
    user_id: event.app_user_id,
    is_active: finalIsActive,
    event_type: event.type,
  });
});

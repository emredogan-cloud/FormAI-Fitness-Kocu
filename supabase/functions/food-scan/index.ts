// ============================================================
// food-scan · AI food recognition from a photograph
// ============================================================
//
// Deploys to: https://<project-ref>.supabase.co/functions/v1/food-scan
//
// Sibling of `coach-chat`, and deliberately built from the same pattern:
// ANTHROPIC_API_KEY is read from the function environment and never
// reaches the device, the prompt is locale-aware, and every upstream
// failure is mapped to a typed error rather than surfaced raw.
//
// ------------------------------------------------------------
// HOW THIS DIFFERS FROM coach-chat, AND WHY IT HAS TO
// ------------------------------------------------------------
//
// `coach-chat` does not identify its caller. That is defensible there:
// the cost of a chat turn is bounded by a human typing.
//
// It is not defensible here. A vision call costs roughly a hundred times
// a chat turn's image-free input, and `docs/CALORIE_TRACKING_RESEARCH.md`
// §5.2 sizes an ungoverned rollout at ~$480/month at 1000 DAU × 4 scans.
// So this function establishes WHO is calling before it spends anything,
// and it does so from the caller's JWT rather than from a field in the
// request body — a user id the client supplies is a request, not a fact.
//
// The quota itself lives in Postgres (`claim_food_scan`, migration 028),
// not in this function, for two reasons: the limit depends on entitlement
// (2 free / 20 Pro) which only the database knows authoritatively via
// `pro_entitlements`, and a limit enforced in a stateless function has no
// way to be atomic across concurrent requests.
//
// ------------------------------------------------------------
// THE ORDER OF OPERATIONS IS THE COST CONTROL
// ------------------------------------------------------------
//
//   1. verify the JWT            — cheap, rejects anonymous callers
//   2. validate the image        — cheap, rejects oversized payloads
//   3. claim a scan slot         — one round trip, rejects over-quota
//   4. call the model            — the only expensive step
//   5. settle the claim          — refunds the slot iff WE failed
//
// The model call is last on purpose. Every check that can reject a
// request happens before the money is spent, and a request that fails
// validation costs a database round trip rather than a vision call.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// Haiku is the research doc's recommendation (§4.1): vision-capable,
// cheapest current tier, and it supports the structured outputs that make
// the confidence field trustworthy rather than optional. Overridable by
// env so an accuracy escalation to Sonnet needs no redeploy of this file.
const MODEL = Deno.env.get("FOOD_SCAN_MODEL") ?? "claude-haiku-4-5";
const MAX_TOKENS = Number(Deno.env.get("FOOD_SCAN_MAX_TOKENS") ?? "1200");

// Research doc §5.2. The client already downscales to a 1024 px long edge
// and re-encodes at q80, which lands well under this; the cap exists for
// the client that doesn't, not the one that does.
const MAX_IMAGE_BYTES = 1_500_000;
const TIMEOUT_MS = 20_000;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ------------------------------------------------------------
// The response contract
// ------------------------------------------------------------
//
// Enforced by the API rather than requested in prose. A prompt that ASKS
// for confidence gets it most of the time; a schema that REQUIRES it gets
// it every time, and `docs/CALORIE_TRACKING_RESEARCH.md` §6 is built on
// that field being present — a UI that must render three confidence
// states cannot have the field go missing on the ambiguous plates, which
// are exactly the ones where the model is likeliest to drop it.
const RESULT_SCHEMA = {
  type: "object",
  properties: {
    recognized: {
      type: "boolean",
      description:
        "false when the image contains no identifiable food at all.",
    },
    clarification: {
      type: ["string", "null"],
      description:
        "When something is genuinely ambiguous, a short question for the " +
        "user in their language — e.g. 'Is this rice or bulgur?'. null " +
        "when nothing needs asking. Never invent a question to seem careful.",
    },
    items: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          portion_label: {
            type: "string",
            description:
              "Household measure in the user's language: '1 kase', '200 ml'.",
          },
          kcal: { type: "integer" },
          protein_g: { type: "number" },
          carbs_g: { type: "number" },
          fat_g: { type: "number" },
          confidence: { type: "string", enum: ["high", "medium", "low"] },
        },
        required: [
          "name",
          "portion_label",
          "kcal",
          "protein_g",
          "carbs_g",
          "fat_g",
          "confidence",
        ],
        additionalProperties: false,
      },
    },
  },
  required: ["recognized", "clarification", "items"],
  additionalProperties: false,
};

// ------------------------------------------------------------
// Prompts
// ------------------------------------------------------------
//
// Both say the same thing, because the honesty requirement is not a
// localisation detail. The specific instruction that matters is the one
// about composite dishes: every source in the research doc (§1.1) agrees
// that stews, rice dishes and anything with hidden oil are where these
// models fail, and Turkish home cooking is disproportionately composite.
// Telling the model to mark those `low` rather than guess confidently is
// the difference between an estimate and a false claim.

const PROMPT_TR = `Sen FormAI'nin besin analiz motorusun. Sana bir yemek
fotoğrafı veriliyor; içindeki yiyecekleri tanı ve her biri için porsiyon,
kalori ve makro tahmini yap.

Kurallar:
- Tahmin ettiğini bil. Bunlar ölçüm değil, tahmindir.
- Karışık yemeklerde (güveç, pilav üstü, soslu tabaklar, kızartmalar)
  gizli yağ ve porsiyon belirsizliği yüksektir — bu kalemleri "low"
  güvenle işaretle. Emin olmadığın hiçbir kalemi "high" yapma.
- Tabakta birden fazla yiyecek varsa her birini ayrı kalem olarak ver.
- Gerçekten ayırt edemediğin bir şey varsa "clarification" alanına
  kullanıcıya soracağın kısa bir soru yaz. Dikkatli görünmek için
  uydurma soru yazma.
- Fotoğrafta yemek yoksa recognized=false ve items=[] döndür.
- İsimleri ve porsiyonları Türkçe yaz.`;

const PROMPT_EN = `You are FormAI's nutrition analysis engine. You are given
a photograph of food. Identify what is in it and estimate the portion,
calories and macros for each item.

Rules:
- Know that you are estimating. These are estimates, not measurements.
- Composite dishes (stews, rice-based plates, anything sauced or fried)
  hide oil and resist portion estimation — mark those items "low"
  confidence. Never mark an item "high" that you are not sure of.
- If the plate holds several foods, return each as its own item.
- If something is genuinely ambiguous, put a short question for the user
  in "clarification". Do not invent a question to appear careful.
- If there is no food in the image, return recognized=false and items=[].
- Write names and portions in English.`;

// ------------------------------------------------------------
// Rounding
// ------------------------------------------------------------
//
// Research doc §6: a number is never shown to more precision than it is
// known to. With 15–25% real-world error, "347 kcal" claims an accuracy
// no source supports — so calories round to 10 and macros to 1 g.
//
// Done here rather than in the client because it is a property of the
// data, not of one screen. A second consumer (an export, a widget, a
// future web view) would otherwise have to remember to round, and one
// that forgot would quietly start making the claim again.
function roundKcal(n: number): number {
  return Math.max(0, Math.round(n / 10) * 10);
}
function roundGrams(n: number): number {
  return Math.max(0, Math.round(n));
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!apiKey || !supabaseUrl || !anonKey) {
    // Same contract as coach-chat's `coach_unconfigured`: tell the client
    // it is a configuration problem so it can show a real message rather
    // than a generic failure.
    return json({ error: "scanner_unconfigured" }, 502);
  }

  // ── 1 · Who is calling ────────────────────────────────────────────────
  // The caller's own token is forwarded to PostgREST, so `auth.uid()`
  // inside the SECURITY DEFINER quota functions resolves to the real
  // user. No service-role impersonation: this function never needs to
  // act as anyone but the person who called it, and holding a key that
  // could would make it a much more attractive thing to compromise.
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return json({ error: "unauthenticated" }, 401);
  }

  let payload: { image?: string; media_type?: string; locale?: string };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  // ── 2 · Is the image sane ─────────────────────────────────────────────
  const image = (payload.image ?? "").toString();
  if (image.length === 0) return json({ error: "missing_image" }, 400);

  // base64 inflates by 4/3, so this is the decoded-size test.
  if ((image.length * 3) / 4 > MAX_IMAGE_BYTES) {
    return json({ error: "image_too_large", max_bytes: MAX_IMAGE_BYTES }, 413);
  }

  const mediaType = (payload.media_type ?? "image/jpeg").toString();
  if (!["image/jpeg", "image/png", "image/webp"].includes(mediaType)) {
    return json({ error: "unsupported_media_type" }, 415);
  }

  const locale = (payload.locale ?? "tr").toString().slice(0, 8);
  const prompt = locale.startsWith("en") ? PROMPT_EN : PROMPT_TR;

  const rest = {
    apikey: anonKey,
    Authorization: authHeader,
    "Content-Type": "application/json",
  };

  // ── 3 · Take a scan slot ──────────────────────────────────────────────
  let claimId: string | null = null;
  let scanLimit = 0;
  let remaining = 0;
  try {
    const res = await fetch(`${supabaseUrl}/rest/v1/rpc/claim_food_scan`, {
      method: "POST",
      headers: rest,
      body: "{}",
    });
    if (res.status === 401 || res.status === 403) {
      return json({ error: "unauthenticated" }, 401);
    }
    if (!res.ok) return json({ error: "quota_unavailable" }, 502);

    const rows = await res.json();
    const row = Array.isArray(rows) ? rows[0] : rows;
    scanLimit = Number(row?.scan_limit ?? 0);
    remaining = Number(row?.remaining ?? 0);

    if (!row?.allowed) {
      // 429 with the numbers attached, so the client can say "0 of 2 left
      // today" and offer the upgrade without a second round trip.
      return json(
        { error: "scan_limit_reached", scan_limit: scanLimit, remaining: 0 },
        429,
      );
    }
    claimId = row.claim_id;
  } catch {
    return json({ error: "quota_unavailable" }, 502);
  }

  // Settle the claim. `ok: false` returns the slot — the user must not
  // pay for our outage. Best-effort and never allowed to mask the real
  // result: if settling fails the worst case is one slot the user
  // doesn't get back, which is strictly better than a 500 on a scan that
  // actually succeeded.
  const settle = async (ok: boolean) => {
    if (!claimId) return;
    try {
      await fetch(`${supabaseUrl}/rest/v1/rpc/settle_food_scan`, {
        method: "POST",
        headers: rest,
        body: JSON.stringify({ p_claim: claimId, p_ok: ok }),
      });
    } catch {
      // Deliberately swallowed — see above.
    }
  };

  // ── 4 · The expensive part ────────────────────────────────────────────
  const body = {
    model: MODEL,
    max_tokens: MAX_TOKENS,
    system: prompt,
    output_config: { format: { type: "json_schema", schema: RESULT_SCHEMA } },
    messages: [
      {
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: mediaType, data: image },
          },
          {
            type: "text",
            text: locale.startsWith("en")
              ? "Analyse this meal."
              : "Bu öğünü analiz et.",
          },
        ],
      },
    ],
  };

  // One retry, and only on the failures a retry can actually fix.
  // Retrying a 400 just pays twice for the same rejection, and retrying a
  // refusal pays twice to be refused again.
  let text: string | null = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });
      clearTimeout(timer);

      if (res.status >= 500 && attempt === 0) continue;
      if (!res.ok) {
        await settle(false);
        return json({ error: "model_error", status: res.status }, 502);
      }

      const data = await res.json();

      // A safety decline is a 200 with stop_reason "refusal" and possibly
      // empty content — reading content[0] first would throw on exactly
      // the response that needs handling most.
      if (data?.stop_reason === "refusal") {
        await settle(false);
        return json({ error: "refused" }, 422);
      }

      text = (data?.content ?? [])
        .filter((b: { type?: string }) => b?.type === "text")
        .map((b: { text?: string }) => b.text ?? "")
        .join("")
        .trim();
      break;
    } catch (_e) {
      clearTimeout(timer);
      if (attempt === 0) continue;
      await settle(false);
      return json({ error: "upstream_failure" }, 502);
    }
  }

  if (!text) {
    await settle(false);
    return json({ error: "empty_reply" }, 502);
  }

  // ── 5 · Shape and return ──────────────────────────────────────────────
  let parsed: {
    recognized?: boolean;
    clarification?: string | null;
    items?: Array<Record<string, unknown>>;
  };
  try {
    parsed = JSON.parse(text);
  } catch {
    // The schema should make this unreachable; if it happens it is our
    // failure, so the slot goes back.
    await settle(false);
    return json({ error: "malformed_reply" }, 502);
  }

  const items = (Array.isArray(parsed.items) ? parsed.items : []).map((it) => ({
    name: String(it.name ?? "").slice(0, 120),
    portion_label: String(it.portion_label ?? "").slice(0, 80),
    kcal: roundKcal(Number(it.kcal ?? 0)),
    protein_g: roundGrams(Number(it.protein_g ?? 0)),
    carbs_g: roundGrams(Number(it.carbs_g ?? 0)),
    fat_g: roundGrams(Number(it.fat_g ?? 0)),
    confidence: ["high", "medium", "low"].includes(String(it.confidence))
      ? String(it.confidence)
      : "low",
  })).filter((it) => it.name.length > 0);

  await settle(true);

  return json({
    recognized: Boolean(parsed.recognized) && items.length > 0,
    clarification: parsed.clarification ?? null,
    items,
    scan_limit: scanLimit,
    remaining,
  });
});

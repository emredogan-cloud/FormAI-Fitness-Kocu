// FormAI · coach-chat — the server-side brain for the AI Coach ("Form").
//
// Deploys to: https://<project-ref>.supabase.co/functions/v1/coach-chat
//
// The Flutter app's LlmCoachBrain calls this function with the user's context
// (their real state — goal, today's workout, progress, streak, BMI…), the
// recent conversation, and the new message. This function prepends the coaching
// persona, calls Claude, and returns the reply. The model key lives ONLY here
// (a Supabase secret) — it must never ship in the app's bundled .env.
//
// Required Supabase environment (set with `supabase secrets set`):
//   • ANTHROPIC_API_KEY — your Anthropic key. Without it the function returns
//     502 and the app falls back to its offline rule-based coach.
// Optional:
//   • COACH_MODEL       — model id (default: the cheapest current Haiku tier).
//   • COACH_MAX_TOKENS  — output cap (default 400 — a coaching turn is short).
//
// Cost: Haiku + a capped output + history compression on the client + a
// cacheable persona keeps a typical turn to a few hundred tokens.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const MODEL = Deno.env.get("COACH_MODEL") ?? "claude-haiku-4-5-20251001";
const MAX_TOKENS = Number(Deno.env.get("COACH_MAX_TOKENS") ?? "400");

// The definitive production persona. Static across every user and turn, so it
// is marked cacheable below — Anthropic prompt caching then serves it at a
// fraction of the input cost on repeat turns. Written in Turkish because "Form"
// only ever speaks Turkish to the user.
const PERSONA = `Sen "Form"sun — FormAI uygulamasının kişisel fitness koçu.
Sıradan bir yapay zekâ asistanı DEĞİLSİN; kullanıcıyı her gün takip eden,
onu tanıyan gerçek bir koç gibi davranırsın. Kendini asla "yapay zekâ",
"asistan", "model" ya da "ChatGPT" olarak tanıtmazsın; sen Form'sun.

KİŞİLİK:
- Sıcak, motive edici ve profesyonel. Gerektiğinde nazikçe disiplinli.
- Duygusal zekâsı yüksek: kullanıcının hâlini önemser, önce onu duyar.
- Robotik değilsin; kısa, doğal, insana yakın konuşursun. Emoji'yi ölçülü
  kullanırsın (bir mesajda en fazla bir tane).

KONUŞMA KURALLARI:
- Her zaman Türkçe yanıt ver.
- Kısa tut: 2-4 cümle. Uzun paragraflar yok. Net bir sonraki adım öner.
- Kullanıcının GERÇEK verilerini kullan (aşağıdaki bağlam). Sahip olmadığın
  bir bilgiyi UYDURMA; bilmiyorsan dürüstçe söyle ve uygulamada nereye
  bakacağını göster.
- Kullanıcıya adıyla, bağlamdaki hedefine ve bugünkü antrenmanına göre hitap et.

GÜVENLİK (çok önemli):
- Tıbbi tavsiye VERME. Ağrı, sakatlık, hastalık ya da ilaç konuları geçerse:
  bölgeyi zorlamamasını söyle ve bir sağlık uzmanına danışmasını öner.
- Teşhis koyma, doz/ilaç önerme, tehlikeli ya da aşırı egzersiz önerme.
- Emin olmadığın şeyde kendinden emin gibi davranma; abartılı vaatler verme
  ("2 haftada 10 kilo" gibi ifadeler yasak).

Amacın: kullanıcıyı bugünkü doğru adıma yönlendirmek ve onu yolda tutmak.`;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

interface Turn {
  role?: string;
  text?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    // No key configured yet — tell the client so it falls back gracefully.
    return json({ error: "coach_unconfigured" }, 502);
  }

  let payload: { context?: string; turns?: Turn[]; message?: string };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  const message = (payload.message ?? "").toString().trim();
  if (!message) return json({ error: "empty_message" }, 400);

  const contextBlock = (payload.context ?? "").toString().slice(0, 4000);
  const history = Array.isArray(payload.turns) ? payload.turns : [];

  // Map the recent conversation into Anthropic message turns. Anything that
  // isn't a clean user/assistant string is skipped defensively.
  const messages = history
    .filter((t) => typeof t?.text === "string" && t.text!.trim().length > 0)
    .map((t) => ({
      role: t.role === "assistant" ? "assistant" : "user",
      content: t.text!.toString().slice(0, 2000),
    }));
  messages.push({ role: "user", content: message });

  // system = [cacheable persona] + [per-session context]. The persona is
  // identical on every call so Anthropic caches it; the context changes only
  // when the user's state changes.
  const system = [
    { type: "text", text: PERSONA, cache_control: { type: "ephemeral" } },
    {
      type: "text",
      text: contextBlock
        ? `KULLANICI BAĞLAMI (gerçek veriler):\n${contextBlock}`
        : "Kullanıcı bağlamı henüz yok; genel ama dürüst rehberlik ver.",
    },
  ];

  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system,
        messages,
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      console.error("anthropic_error", res.status, detail.slice(0, 500));
      return json({ error: "model_error", status: res.status }, 502);
    }

    const data = await res.json();
    const reply = Array.isArray(data?.content)
      ? data.content
          .filter((b: { type?: string }) => b?.type === "text")
          .map((b: { text?: string }) => b.text ?? "")
          .join("")
          .trim()
      : "";

    if (!reply) return json({ error: "empty_reply" }, 502);
    return json({ reply });
  } catch (e) {
    console.error("coach_chat_exception", String(e));
    return json({ error: "upstream_failure" }, 502);
  }
});

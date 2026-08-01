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
const MAX_TOKENS = Number(Deno.env.get("COACH_MAX_TOKENS") ?? "700");

// The Turkish production persona. Static across every user and turn, so it
// is marked cacheable below — Anthropic prompt caching then serves it at a
// fraction of the input cost on repeat turns.
const PERSONA = `Sen "Form"sun — FormAI uygulamasının kişisel fitness koçu.
Sıradan bir yapay zekâ asistanı DEĞİLSİN; kullanıcıyı her gün takip eden,
onu tanıyan gerçek bir koç gibi davranırsın. Kendini asla "yapay zekâ",
"asistan", "model" ya da "ChatGPT" olarak tanıtmazsın; sen Form'sun.

KİŞİLİK:
- Sıcak, motive edici ve profesyonel. Gerektiğinde nazikçe disiplinli.
- Duygusal zekâsı yüksek: kullanıcının hâlini önemser, önce onu duyar.
- Robotik değilsin; doğal, insana yakın, akıcı Türkçe konuşursun. Emoji'yi
  ölçülü kullanırsın.

GERÇEKLİK (en önemli kural):
- SADECE aşağıdaki bağlamda ve konuşma geçmişinde verilen bilgileri kullan.
- Geçmiş konuşma, ölçüm, istatistik, olay ASLA uydurma ("geçen hafta şöyle
  demiştin", "kullanıcıların çoğu 3. günde bırakır" gibi cümleler YASAK —
  bağlamda yoksa söyleme).
- Bilmediğin bir şeyi dürüstçe söyle ve uygulamada nereye bakacağını göster.
- Sayıları bağlamdan aynen al; yuvarlama/uydurma yok.
- Egzersiz isimleri bağlamda varsa aynen kullan. Set/tekrar sayısı bağlamda
  YOKSA uydurma — "planındaki set ve tekrar sayılarını uygula" de, ya da genel
  bir öneri verdiğini açıkça belirt.

YANIT BİÇİMİ:
- Her zaman Türkçe.
- Sohbet/duygu ağırlıklı sorularda: kısa ve doğal, 2-4 cümle, düz metin.
- Plan/antrenman/beslenme gibi LİSTELENEBİLİR cevaplarda zengin biçim kullan:
  emoji başlıklı kısa bölümler + madde işaretleri. Örnek:
  🏋 Bugünkü antrenman
  • Şınav — 3x12
  • Plank — 3x40sn
  💡 Koç ipucu
  Dirseklerini gövdene yakın tut.
- Önemli kelimeleri **kalın** yazabilirsin. En fazla 2-3 bölüm; tarama
  kolaylığı esas. Uzun paragraf duvarı YASAK.
- Yanıtını ASLA yarıda bırakma — uzun olacaksa baştan daha kısa yaz.
- Temiz, akıcı Türkçe yaz; yalnızca Türk alfabesindeki karakterleri kullan,
  yazım hatası yapma.
- Net bir sonraki adımla bitir.

GÜVENLİK (çok önemli):
- Tıbbi tavsiye VERME. Ağrı, sakatlık, hastalık ya da ilaç konuları geçerse:
  bölgeyi zorlamamasını söyle ve bir sağlık uzmanına danışmasını öner.
- Teşhis koyma, doz/ilaç önerme, tehlikeli ya da aşırı egzersiz önerme.
- Emin olmadığın şeyde kendinden emin gibi davranma; abartılı vaatler verme
  ("2 haftada 10 kilo" gibi ifadeler yasak).

Amacın: kullanıcıyı bugünkü doğru adıma yönlendirmek ve onu yolda tutmak.`;

// Roadmap Phase 6 · the English Form. Written, not translated — see the
// note on [PERSONAS]. A few things are deliberately NOT literal
// renderings of the Turkish:
//
//   • The Turkish persona says "yalnızca Türk alfabesindeki karakterleri
//     kullan" to stop the model reaching for ASCII lookalikes. English
//     has no such failure mode, so that line is gone rather than
//     mistranslated into something meaningless.
//   • "Sıcak" is warm-as-in-a-person, not warm-as-in-friendly-support-
//     agent. English gets "on the user's side", which is the same idea
//     in a language where "warm" has drifted toward customer service.
//   • The forbidden-promise example is re-picked for the market: a US
//     reader recognises "lose 10 pounds in 2 weeks" as the shape of a
//     scam claim; a literal "10 kilos" would not land the same way.
//
// The guardrails are identical in force and wording where it matters:
// no invented history, no invented set/rep numbers, no medical advice,
// no diagnosis, no exaggerated promises.
const PERSONA_EN = `You are "Form" — the personal fitness coach inside the
FormAI app. You are NOT a general-purpose AI assistant; you behave like a real
coach who follows this person day to day and knows them. Never introduce
yourself as an "AI", an "assistant", a "model" or "ChatGPT". You are Form.

WHO YOU ARE:
- On the user's side, motivating, and professional. Firm when it helps them,
  never sharp.
- Emotionally literate: you notice how they are doing and hear them out first.
- Not robotic. Natural, fluent English, spoken like a person. Emoji sparingly.

TRUTHFULNESS (the most important rule):
- Use ONLY what is in the context block and the conversation history below.
- NEVER invent past conversations, measurements, statistics or events
  ("last week you said…", "most users quit on day 3" are FORBIDDEN unless
  they are in the context).
- If you do not know something, say so plainly and point to where in the app
  they can find it.
- Take numbers verbatim from the context. No rounding, no inventing.
- Use exercise names exactly as the context gives them. If the context does
  NOT carry set and rep counts, do not invent them — say "follow the sets and
  reps in your plan", or state clearly that you are giving general advice.

HOW TO ANSWER:
- Always in English.
- For conversational or emotional questions: short and natural, 2-4 sentences,
  plain prose.
- For answers that are genuinely a list — a plan, a workout, a meal — use
  structure: short emoji-headed sections with bullets. For example:
  🏋 Today's workout
  • Push-ups — 3x12
  • Plank — 3x40s
  💡 Coach's tip
  Keep your elbows close to your body.
- You may **bold** the words that matter. Two or three sections at most;
  scannability is the point. No walls of text.
- NEVER cut a reply off mid-thought — if it is going to be long, write a
  shorter one from the start.
- End with one clear next step.

SAFETY (critical):
- Do NOT give medical advice. If pain, injury, illness or medication comes up:
  tell them not to push through it, and to speak to a health professional.
- No diagnosis, no dosages, no dangerous or extreme exercise suggestions.
- Do not sound certain about things you are not, and make no exaggerated
  promises ("lose 10 pounds in 2 weeks" and anything like it is forbidden).

Your job: point them at the right next step today, and keep them going.`;

// Roadmap Phase 5 (AI work) · per-locale persona registry, filled in by
// Phase 6.
//
// Every entry is a HAND-WRITTEN persona, never a machine translation of
// the Turkish one. Form's voice is a brand asset and raw MT flattens
// exactly the things that make it a voice: the directness, the
// second-person warmth, the refusal to sound like an assistant. A
// translated persona still reads as a translation, and the coach is the
// one surface where every user would notice.
//
// Selection happens server-side, so `es`, `fr` and `de` ship without an
// app release — the whole reason the client threads `locale`.
const PERSONAS: Record<string, string> = {
  tr: PERSONA,
  en: PERSONA_EN,
};

// Minimal instruction for the rolling-summary mode. Deliberately persona-free
// and tiny: the output is machine-consumed (stored client-side and fed back as
// "ÖNCEKİ KONUŞMALARDAN NOTLAR"), so every token counts.
const SUMMARIZER = `Aşağıda bir fitness koçu ile kullanıcı arasındaki konuşma
ve (varsa) önceki not özeti var. Kullanıcı hakkında koçun HATIRLAMASI gereken
kalıcı bilgileri güncelle: hedefler, alışkanlıklar, tercih edilen antrenman/
beslenme tarzı, güçlü/zayıf yönler, tekrarlayan hatalar, motivasyon durumu,
kısıtlar (sakatlık, ekipman, zaman). Geçici gevezelikleri atla. UYDURMA.
En fazla 8 kısa madde, her madde "- " ile başlasın, toplam 120 kelimeyi geçme.
Sadece maddeleri yaz, başka hiçbir şey yazma.`;

const SUMMARIZER_EN = `Below is a conversation between a fitness coach and a
user, plus (if present) the previous note summary. Update the durable facts the
coach should REMEMBER about this user: goals, habits, preferred training and
eating style, strengths and weaknesses, recurring mistakes, motivation, and
constraints (injury, equipment, time). Skip small talk. DO NOT INVENT.
At most 8 short bullets, each starting with "- ", 120 words total maximum.
Write only the bullets, nothing else.`;

// Everything the model is handed that is prose rather than persona.
//
// The summary is the reason this matters more than it looks: it is
// written by the model, stored on the device, and fed BACK in as the
// coach's memory on later turns. Summarise an English conversation with
// the Turkish summariser and every future English reply is grounded in
// Turkish notes under a Turkish heading — the coach starts quoting
// itself in the wrong language.
const SCAFFOLD: Record<string, {
  summarizer: string;
  coach: string;
  user: string;
  priorSummary: string;
  newConversation: string;
  contextHeader: string;
  noContext: string;
  memoryHeader: string;
}> = {
  tr: {
    summarizer: SUMMARIZER,
    coach: "Koç",
    user: "Kullanıcı",
    priorSummary: "ÖNCEKİ ÖZET",
    newConversation: "YENİ KONUŞMA",
    contextHeader: "KULLANICI BAĞLAMI (gerçek veriler)",
    noContext: "Kullanıcı bağlamı henüz yok; genel ama dürüst rehberlik ver.",
    memoryHeader: "ÖNCEKİ KONUŞMALARDAN NOTLAR (koçun hafızası)",
  },
  en: {
    summarizer: SUMMARIZER_EN,
    coach: "Coach",
    user: "User",
    priorSummary: "PREVIOUS SUMMARY",
    newConversation: "NEW CONVERSATION",
    contextHeader: "USER CONTEXT (real data)",
    noContext:
      "No user context yet; give general but honest guidance.",
    memoryHeader: "NOTES FROM EARLIER CONVERSATIONS (the coach's memory)",
  },
};

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

  let payload: {
    context?: string;
    turns?: Turn[];
    message?: string;
    summary?: string;
    mode?: string;
    // Roadmap Phase 5 (AI work) · the app's locale, not the device's.
    // Accepted and recorded now so per-locale personas can land in
    // Phase 7 without an app release; until then every value resolves
    // to the Turkish persona below.
    locale?: string;
  };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }

  // Roadmap Phase 5 built this seam; Phase 6 is the first call that
  // actually turns. Adding a language is a new PERSONAS entry plus a
  // SCAFFOLD entry, with no app release — which is the entire reason
  // the client has been threading `locale` since a phase before
  // anything read it.
  //
  // An unknown locale falls back to Turkish rather than to English: a
  // locale we do not have a persona for is a locale whose UI is already
  // resolving to Turkish, and the coach must not be the one surface
  // speaking a different language from the rest of the app.
  const locale = (payload.locale ?? "tr").toString().slice(0, 8);
  const personaLocale = locale.startsWith("en") ? "en" : "tr";
  const scaffold = SCAFFOLD[personaLocale];

  const contextBlock = (payload.context ?? "").toString().slice(0, 4000);
  const history = Array.isArray(payload.turns) ? payload.turns : [];
  const priorSummary = (payload.summary ?? "").toString().slice(0, 1200);

  // Map the recent conversation into Anthropic message turns. Anything that
  // isn't a clean user/assistant string is skipped defensively.
  const messages = history
    .filter((t) => typeof t?.text === "string" && t.text!.trim().length > 0)
    .map((t) => ({
      role: t.role === "assistant" ? "assistant" : "user",
      content: t.text!.toString().slice(0, 2000),
    }));

  // ── Rolling-summary mode ────────────────────────────────────────────────
  // The client periodically sends the conversation (+ the previous summary)
  // and stores the returned digest locally; subsequent chat calls carry it
  // back via `summary`. Long-term memory without resending history.
  if (payload.mode === "summarize") {
    if (messages.length === 0) return json({ error: "empty_turns" }, 400);
    const transcript = messages
      .map((m) =>
        `${m.role === "assistant" ? scaffold.coach : scaffold.user}: ${m.content}`
      )
      .join("\n");
    const body = {
      model: MODEL,
      max_tokens: 250,
      system: [{ type: "text", text: scaffold.summarizer }],
      messages: [
        {
          role: "user",
          content: priorSummary
            ? `${scaffold.priorSummary}:\n${priorSummary}\n\n` +
              `${scaffold.newConversation}:\n${transcript}`
            : `${scaffold.newConversation}:\n${transcript}`,
        },
      ],
    };
    return await callAnthropic(apiKey, body, "summary");
  }

  const message = (payload.message ?? "").toString().trim();
  if (!message) return json({ error: "empty_message" }, 400);
  messages.push({ role: "user", content: message });

  // system = [cacheable persona] + [per-session context]. The persona is
  // identical on every call so Anthropic caches it; the context changes only
  // when the user's state changes.
  const system = [
    {
      type: "text",
      text: PERSONAS[personaLocale] ?? PERSONA,
      cache_control: { type: "ephemeral" },
    },
    {
      type: "text",
      text: [
        contextBlock
          ? `${scaffold.contextHeader}:\n${contextBlock}`
          : scaffold.noContext,
        priorSummary ? `\n${scaffold.memoryHeader}:\n${priorSummary}` : "",
      ].join(""),
    },
  ];

  return await callAnthropic(
    apiKey,
    { model: MODEL, max_tokens: MAX_TOKENS, system, messages },
    "reply",
  );
});

/// Shared Anthropic call. Returns `{ [field]: text }` on success, a typed
/// error JSON on failure (the app falls back to the rule brain on any of them).
async function callAnthropic(
  apiKey: string,
  body: unknown,
  field: "reply" | "summary",
): Promise<Response> {
  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const detail = await res.text();
      console.error("anthropic_error", res.status, detail.slice(0, 500));
      return json({ error: "model_error", status: res.status }, 502);
    }

    const data = await res.json();
    const text = Array.isArray(data?.content)
      ? data.content
          .filter((b: { type?: string }) => b?.type === "text")
          .map((b: { text?: string }) => b.text ?? "")
          .join("")
          .trim()
      : "";

    if (!text) return json({ error: "empty_reply" }, 502);
    return json({ [field]: text });
  } catch (e) {
    console.error("coach_chat_exception", String(e));
    return json({ error: "upstream_failure" }, 502);
  }
}

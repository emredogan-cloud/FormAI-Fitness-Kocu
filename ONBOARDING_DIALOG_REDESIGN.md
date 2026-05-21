# Onboarding Dialog Redesign — Emotional Reframe + AI Cascade

**Branch:** feature/cdn-meal-migration
**Date:** 2026-05-21
**Scope:** Replace Q2 with an emotional reframe question, remove Q3, deliver a 5-message AI cascade after Q2 answer.

---

## Flow — Before vs After

### Before
1. **Q1 — Name:** "Bu yolculukta sana nasıl sesleneyim?"
2. **Q2 — Coaching tone (weak):** "Bir şey daha. Yanında nasıl olmamı istersin?"
   Chips: Cesaret veren / Net ve direkt / Sakin, hatırlatan
3. **Q3 — Motivation style (removed):** "Son bir şey. Seni en çok ne motive eder?"
   Chips: Sonuçları görmek / Disiplin kurmak / Daha güçlü hissetmek

Each chip got one one-line acknowledgment, then auto-advance. No emotional depth — felt like a configuration step.

### After
1. **Q1 — Name:** unchanged.
2. **Q2 — Emotional reframe:** **"Şu an seni en çok ne yoruyor?"**
   Chips:
   - `dongu` — "Aynı döngüye düşmek"
   - `gormek` — "Sonuç görememek"
   - `yalniz` — "Yalnız hissetmek"
3. **Q3 — removed.**
4. **5-message AI cascade** plays after the user picks a Q2 chip, branching on token, then auto-advances to the next step.

---

## Why "Şu an seni en çok ne yoruyor?"

The user's stated goals were: emotional connection, self-reflection, AI-companion feeling, commitment, future-self framing, "yanındayım", FOMO, momentum — without being cringe / therapy / generic.

"What's tiring you most right now?" hits these because:

- **Self-reflection without therapy:** the user names a *current* drain, not a childhood wound.
- **Emotional connection:** asking about fatigue is the gesture a real coach makes, not a quiz.
- **AI-companion framing:** the answer hands Form a specific pain to acknowledge, reframe, and offer presence around. Generic "what's your goal" can't do that.
- **Three branch-able answers** — each one maps to a distinct cascade tonality (loop / blindness / loneliness) so the follow-up reads as personalized, not templated.

Alternative drafts considered + rejected:
- "Bu sefer farklı olması için neye ihtiyacın var?" — too forward-looking, skips the empathy beat.
- "30 gün sonra aynaya baktığında ne hissetmek istiyorsun?" — strong future-self pull but doesn't let Form *acknowledge* anything first.
- "Geçmişte vazgeçmenin sebebi neydi?" — risks landing as guilt instead of empathy.

---

## The Cascade (5 messages per chip)

After the user taps a chip, Form delivers — with 750ms composing-dots between each — five sequential messages:

| # | Role | Purpose |
|---|------|---------|
| 1 | **Acknowledge** | Name the pain back to the user so they feel heard |
| 2 | **Confirm understanding** | Reframe the pain so it's not a personal failing |
| 3 | **Companion offer** | Position Form as the constant presence they've been missing |
| 4 | **Future-self pull** | Plant a specific milestone (Day 21 / Day 30) |
| 5 | **Transition** | Hand off to the next step ("now I'm building your plan") |

After message 5's typewriter completes, a 1.6 s dwell + `onContinue()`.

### Branch · `dongu` (Aynı döngüye düşmek)

1. *Ack:* "{Name}, aynı döngüye düşmek…"
2. *Confirm:* "Çoğu kez başlayıp durdun. Sebep motivasyon değildi — sessizlikti."
3. *Companion:* "Ben her gün sessizliği kıracağım. Sözle değil — küçük, sıralı adımlarla."
4. *Future:* "30 gün sonra döngüye değil, kendi ritmine bakıyor olacaksın."
5. *Transition:* "{Name}, şimdi sana özel planı kuruyorum."

### Branch · `gormek` (Sonuç görememek)

1. *Ack:* "{Name}, sonuç göremezken devam etmek yorar."
2. *Confirm:* "Gözle ölçemediğin için yok sandın. Aslında yön yanlıştı, sen değil."
3. *Companion:* "Ben her tekrarını izleyeceğim. Yön doğru olunca, sonuç sessizce gelir."
4. *Future:* "İlk farkı 21. günde göreceksin. Bekle bunu."
5. *Transition:* "{Name}, şimdi sana özel planı kuruyorum."

### Branch · `yalniz` (Yalnız hissetmek)

1. *Ack:* "{Name}, yalnız hissetmek…"
2. *Confirm:* "Kimsenin yüksek sesle söylemediği en büyük sebep bu."
3. *Companion:* "Bundan sonra her sabah ben buradayım — hatırlatan, ölçen, gören."
4. *Future:* "30 gün sonra dönüp baktığında, yalnız olmadığını bileceksin."
5. *Transition:* "{Name}, şimdi sana özel planı kuruyorum."

Tone target: high-end AI coach. Specific, calm, embodied. No exclamation marks, no "let's crush it", no toxic urgency.

---

## Implementation Notes

### Files touched
- `lib/features/onboarding/presentation/steps/name_capture_step.dart` — full rewrite of the chat-cascade logic.
- `lib/features/onboarding/providers/wizard_provider.dart` — removed `motivationStyle` field, setter, copyWith param, toJson key, fromJson key.

### Field naming
Kept `coachingTone` as the persisted field name (string nullable, captures the reframe token). Tokens changed (`cesaretlendirici/direkt/sakin` → `dongu/gormek/yalniz`). The doc-comment was rewritten to reflect new semantics.

Rationale for keeping the name: the field is pure storage; nothing downstream reads it (verified via repo grep). Renaming would force a fromJson migration without any operator benefit.

### Legacy install behavior
Old installs with `coachingTone: 'direkt'` (legacy token) stored in SharedPreferences:
- `fromJson` reads it as-is.
- `NameCaptureStep` returning-state collapse uses `existingReframe != null` so the old token still satisfies "already answered" → the cascade collapses to its final auto-advance state.
- The user's wizard never sees the new Q2 — their previous answer counts.
- Their (now-orphan) `coachingTone` token doesn't crash anything because no downstream code branches on the token values.

Old installs with `motivationStyle` in the JSON blob: `fromJson` silently ignores unknown keys. No migration error.

### State machine
Five new bool pairs (`_ackReady/_ackDone`, `_confirmReady/_confirmDone`, `_companionReady/_companionDone`, `_futureReady/_futureDone`, `_transitionReady/_transitionDone`) drive the cascade. Each `*Done` handler schedules the next `*Ready` via the shared `_scheduleNext` helper, which honors `_isReturning` (skips the 750 ms beat) and dedupes via the `isReady()` predicate.

### Returning-user collapse
`_isReturning = name != null && coachingTone != null`. All cascade flags set true in `initState`; a post-frame `Future.delayed(1500ms)` triggers `onContinue()`. Cascade text is rendered without typewriter (`typewriter: !_isReturning`) so the user sees their previous flow in summary, not in re-played slow-motion.

### Mood progression
Simplified from 4 phases to 3:
- `listening` while asking name
- `proud` after name acknowledged
- `listening` while asking reframe
- `proud` for the entire cascade

---

## Validation

- `flutter analyze lib/` → **No issues found! (ran in 6.9s)**
- `grep -rn "motivationStyle" lib/` → zero matches (clean removal).
- `grep -rn "coachingTone" lib/` → only in `wizard_provider.dart` (definition) and `name_capture_step.dart` (capture site).

---

## Net Change

| Quantity | Direction |
|---|---|
| Onboarding questions | 3 → 2 (Q3 fully removed) |
| Q2 chip count | 3 → 3 (same count, different semantics) |
| AI messages after Q2 answer | 1 → 5 |
| Wizard fields | -1 (`motivationStyle`) |
| Field setters | -1 (`setMotivationStyle`) |
| Persisted JSON keys | -1 |
| Lines in `name_capture_step.dart` | 967 → ≈770 (denser; one beat instead of two, but each beat now has 5 messages and shared infra) |

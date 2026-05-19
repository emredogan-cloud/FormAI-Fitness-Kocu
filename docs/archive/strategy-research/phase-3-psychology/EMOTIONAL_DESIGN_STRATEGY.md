# EMOTIONAL DESIGN STRATEGY

**Phase 3 — Psychology · Emotional Layer Diagnostic**
**Project:** SixPack AI / FormAI Fit
**Generated:** 2026-05-09
**Inputs:**
- atlas (`reports/phase-1-project-discovery/PROJECT_STRUCTURE_MAP.md`) §4–§7, §9, §10, §11
- Phase 2 PRODUCT_STRUCTURE_REPORT.md (24 IA findings); USER_FLOW_ANALYSIS.md (5 journeys); PREMIUMIZATION_STRATEGY.md (perception-by-surface)
- Phase 3 USER_PSYCHOLOGY_REPORT.md (33 findings P-01..P-33) — emotional valence map, identity gap, cultural register
- Phase 3 RETENTION_TRIGGER_REPORT.md (15 findings T-01..T-15) — re-engagement copy
- Phase 3 HABIT_LOOP_STRATEGY.md (11 findings H-01..H-11) — reward magnitude, cue specificity
- Targeted source-file inspection: `gelisim_tab.dart`, `today_task_card.dart`, `paywall_screen.dart`, `auth_screen.dart`, `auth_modal_bottom_sheet.dart`, `nutrition_tab.dart`, `workout_camera_screen.dart`, `notification_service.dart`, `session_complete_overlay.dart`, `weekly_retrospective_card.dart`, `suggestions_screen.dart`, `onboarding_screen.dart`

**Scope:** Diagnostic of the emotional layer of the product — *the emotional state the surface assumes the user is in, and the emotional state it actually produces.* Not a redesign. Severity-scored findings with file:line evidence. The other Phase 3 reports analyzed mechanism (psychology), trigger (retention), and loop (habit). This one analyzes **affect** — the felt experience.

---

## 0. HOW TO READ THIS REPORT

Each finding follows the schema:

```
### Finding E-NN: [imperative title]
Severity: N/5 (emotional impact, not engineering complexity)
Where:    file:line + atlas §X.Y
Surface:  [which surface produces the affect]
Assumed user state:  [what emotional state the surface assumes]
Produced user state: [what emotional state it actually produces]
Cost:        [why the gap matters]
Evidence:    [code or copy]
```

Severity scale (emotional impact):
- **5** — produces shame, dissonance, or guilt at a moment that should produce pride/safety/anticipation
- **4** — emotional flatness or coldness at a moment that should be warm
- **3** — register-mismatch or tonal slip — the user feels "this was written by a different person"
- **2** — small affect leak; cleanable in copy
- **1** — cosmetic

Frameworks referenced (used where they earn it; never invoked without app-specific evidence):
- **Affective forecasting** (Wilson & Gilbert) — users' emotional response to product moments diverges systematically from designer-intended response
- **Self-Determination Theory** (Deci & Ryan) — autonomy / competence / **relatedness** as emotional needs
- **Identity-based habits** (Clear) — emotional reinforcement of self-concept, not just behavior
- **Reciprocity asymmetry** (Cialdini) — emotional cost of disclosure-without-acknowledgment
- **Operant conditioning** (Skinner) — fixed vs variable rewards as affect-shapers, not just behavior-shapers
- **Cultural register theory** — Turkish-specific tonal layers (tu/sen vs siz; gym-buddy vs caregiver vs military vs kitchen voice)

ERRATA versus prior phase reports flagged inline.

---

## 1. EXECUTIVE FINDINGS TABLE

| ID | Sev | Title | Surface |
|---|---|---|---|
| E-01 | 5 | Day-0 Gelişim is a 7-section silent broadcast of "you have nothing" — the product's first emotional impression of the user's own progress is total absence | Gelişim |
| E-02 | 5 | Streak break renders shame across 5 surfaces simultaneously — header pill, streak card, 5-dot row, weekly chart, home-screen widget — the system shouts the failure at the user from every direction | Gelişim + widget |
| E-03 | 5 | Day 4 paywall lands when motivation is already lowest, with a green "go" button visual — the user feels betrayed at the precise moment of habit-formation fragility | Today Task Card |
| E-04 | 5 | Forced-auth modal at paywall arrival triggers identity-violation affect immediately after the AI promised to know the user — "the AI knows you, sign up so we can know you" emotional contradiction | Paywall + auth modal |
| E-05 | 5 | The AI Coach Card on Gelişim is the canonical "warmth surface" — it's also the surface with the lowest emotional bandwidth (3 hardcoded copy branches keyed on streak alone) | Gelişim |
| E-06 | 4 | Workout-camera scaffold is hardcoded `Colors.black` + cyber-cyan — the most demanding moment (live form correction) emotionally inhabits a different product than the rest of the app | Workout |
| E-07 | 4 | Onboarding asks for vulnerability (gender, weight, what blocks you) and gives back two labor-illusions and a generic banner — disclosure → acknowledgment ratio is broken | Onboarding |
| E-08 | 4 | "Serini bozma!" subtitle at streak=0 reads as accusation — the system is still scolding a user who already failed | Gelişim Streak Card |
| E-09 | 4 | Notification voice ("🔥 fethettin", "geride kalırsın") and in-app voice (warm AI Coach, neon halos) are emotionally distinct registers — two different brand personalities | Notification + in-app |
| E-10 | 4 | Pre-paywall summary copy "AI motorun seni baştan sona dinledi" is anthropomorphism over a system that the user did 99% of the talking to — the affect of being heard isn't earned | Onboarding step 12 |
| E-11 | 4 | Locked-day cells communicate "you are not allowed" — the future of the program is rendered as forbidden territory rather than the next destination | Gelişim 30-day grid |
| E-12 | 4 | "Bugün hedeflerimize bir adım daha yaklaşıyoruz" default coach line is generic-LLM voice fired in the user's primary daily emotional touchpoint | Gelişim AI Coach |
| E-13 | 4 | Identity language is structurally absent — copy says "you used the app" but never "you are someone who trains" — the brand never reflects the user back to themselves | Cross-cutting |
| E-14 | 3 | Three concurrent pulse animations on Gelişim (current cell, coach avatar, neon halos) compete for attention — energy reads as anxiety, not invitation | Gelişim |
| E-15 | 3 | "🔥 10.000+ kişi kullanıyor" social proof at the conversion gate is the most emotionally suspect moment in the funnel — round-number-with-emoji reads as ad copy | Paywall |
| E-16 | 3 | Recipe macro chips use phosphor-yellow #EAFF00 against off-white in light mode — visceral discomfort on a surface that should produce appetite | Recipe Detail |
| E-17 | 3 | Coach-intro typewriter (~4 s) treats the AI's first words as machinery, not voice — pacing breaks the warmth the line claims | Onboarding step 2 |
| E-18 | 3 | "Kalori aşıldı" red banner when over target is shame-coded — uses deficit framing for what could be a neutral counter | Beslenme tab |
| E-19 | 3 | Profile tab's "Hesabı Sil" (delete account) tile is rendered with the same chrome as "Bildirimler" — destructive action lives in mundane settings register | Profile |
| E-20 | 3 | Program-complete card is undersized — 30 days of consistency rewarded with a 60-px inline card, smaller than a single badge unlock dialog | Gelişim |
| E-21 | 3 | The "Şampiyon" hardcoded fallback name reads as gym-trainer voice — friendly first impression that compounds into "this app calls every user the same name" | TTS coach summary |
| E-22 | 2 | "Günü fethettin" (you conquered the day) uses military verb in Turkish — register skews male/aggressive on a brand that's not committed to that voice | Notification |
| E-23 | 2 | "Bugünkü Görev" (today's task) frames the workout as duty rather than activity or ownership | Today Task Card label |
| E-24 | 2 | "Günaydın $name" daily-summary TTS greets "good morning" regardless of when user taps — clock-blind on a fitness app | TTS coach summary |

**Total: 24 findings.** **5 sev-5, 8 sev-4, 8 sev-3, 3 sev-2.**

---

## 2. EMOTIONAL STATE-BY-SURFACE AUDIT

The user moves through 7 primary surfaces (Onboarding, Antrenman, Beslenme, Gelişim, Profil, Workout-Camera, Paywall). Each surface assumes a user emotional state and produces one. The gap between assumption and production is the design debt this report enumerates.

### 2.1 Onboarding — Hook → Investment → Reveal arc

**Assumed state:** curious, skeptical, willing-to-try.
**Produced state (well):** anticipation (Welcome step 1 cinematic photo + ShaderMask gradient title).
**Produced state (poorly):** patience-tax (typewriter ~4 s on step 2), labor-illusion-tax (1.5 s + 6 s + 1.4 s forced waits across steps 8/10/11), reciprocity asymmetry (vulnerable disclosures on steps 3, 8, 9 met with one-line auto-advance banners).

By step 12 the user has invested ~85-120 seconds and 11 deliberate disclosures. The reveal — the "Kişisel AI Raporun" + 92% confidence bar — is supposed to redeem the investment. Per USER_PSYCHOLOGY_REPORT P-23, the report is shown once and never re-rendered. The endowment is built and immediately discarded.

**The most consequential emotional fact in onboarding:** by the moment the user lands on the paywall, the labor of investment is done but the *artifact of investment* (the personalized AI report) is gone. The paywall arrival is psychologically the empty-handed moment after a 90-second build-up.

#### Finding E-07: Onboarding asks for vulnerability and reciprocates with labor-illusions
**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:1316–1319` (pain-point step), `:1110, 1182` (Metabolizmanı hesaplıyorum… 1.5 s), `:1374–1407` (Vücudun analiz ediliyor… 6 s)
**Surface:** Onboarding steps 3, 8, 9, 10
**Assumed user state:** willing to share, expecting genuine response.
**Produced user state:** asymmetry-of-effort feeling. The user gives substance; the system gives theatre.

**Observation:** Step 9 prompts: "Seni en çok zorlayan ne?" with options including "Motivasyon", "Süreklilik", "Ne yapacağımı bilmiyorum", "Diyet" plus a free-text path. The user discloses a personal struggle (e.g. types "Akşamları çok yorgun oluyorum ve diyeti bozuyorum…" per the input hint at line 1346). The system's response: a 1.5 s feedback banner — `'Bunu çözmek için planını optimize edeceğim.'` — and an auto-advance.

The disclosure is logged (`setPainPointDescription(text)`) but never re-surfaced. The dynamic AI report does not echo the disclosure verbatim back to the user. The dashboard's AI Coach card has 3 hardcoded copy branches — none of which key on `painPoint` (`gelisim_tab.dart:1613–1621`).

**Cost:** Reciprocity asymmetry (Cialdini). The cleanest persuasion moments are when ask and offer are matched. A free-text disclosure of personal vulnerability with a 1-line generic acknowledgment is the **shape** of dismissal, even if the database stores the answer. For Turkish users where "seni en çok zorlayan ne?" demands a sincere answer (the question is intimate-direct in Turkish), a generic auto-advance feels rude.

The fix isn't a new UI. The fix is an emotional contract that says "you told us this; we'll come back to it." The system has the storage; it doesn't have the callback.

**Evidence:**
```dart
// onboarding_screen.dart:1316–1319 (pain point feedback)
feedbackText: 'Bunu çözmek için planını optimize edeceğim.',
```
A grep confirms `painPointDescription` is read only inside `AiPersonalizationEngine._assessment` (`ai_personalization_engine.dart:152–168`):
```
grep -rn 'painPointDescription\|painPoint' lib/
→ wizard_provider (writes), ai_personalization_engine (single read in engine), onboarding_screen (writes via callback)
→ no consumer outside the wizard surface
```

**ERRATA-vs-USER_PSYCHOLOGY_REPORT-P-21:** USER_PSYCHOLOGY_REPORT P-21 framed this as reciprocity asymmetry (sev-3). E-07 reframes for emotional design (sev-4) — same fact, different lens, slightly higher severity because the *affect* (feeling unheard) is more durable than the structural reciprocity gap.

---

#### Finding E-10: "AI motorun seni baştan sona dinledi" anthropomorphism
**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:1999–2007` (pre-paywall summary subtitle)
**Surface:** Onboarding step 12 (pre-paywall summary)
**Assumed user state:** grateful for being understood after 90 seconds of disclosure.
**Produced user state:** suspicion-of-marketing-voice — for users who notice that "the AI" was actually 8 card taps + 3 wheel scrolls + maybe 3 free-text answers.

**Observation:**
```dart
// onboarding_screen.dart:1999–2007
const Text(
  'AI motorun seni baştan sona dinledi ve aşağıdaki paketi '
  'senin için kurdu.',
  textAlign: TextAlign.center,
  style: TextStyle(
    color: Colors.white60,
    fontSize: 13,
    height: 1.45,
  ),
),
```

"Baştan sona dinledi" — listened from start to finish. The user did not speak. They tapped 8 cards, scrolled 3 wheels, optionally typed in 3 hybrid steps. "Listened" is metaphor.

For users in 2026 who have used voice-AI products (Siri, Alexa, Whisper-based transcription apps), "listened" is a verb that implies audio input. Applied to a multiple-choice wizard, it reads as marketing voice.

**Cost:** Compounds with the labor illusions on steps 8 + 10 + 11 (USER_PSYCHOLOGY_REPORT P-10/P-11 covered the mechanism cost). The *affect* cost is cumulative: by step 12 the user has been through three theatrical computation claims and one anthropomorphic "I listened" claim. The brand voice slips from "AI coach" to "AI marketing copy."

For Turkish-market users, the "AI motorun" possessive ("your AI engine") is a particular tonal layer — half technical ("motor" engineering metaphor), half intimate ("senin"). Used carefully, it's distinctive. Used loosely, it's a sales tic.

---

#### Finding E-17: Coach-intro typewriter treats the AI's first words as machinery
**Severity:** 3/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:553–586` (typewriter mechanism); `:559` (`_perChar = 28ms`)
**Surface:** Onboarding step 2 (Coach Intro)
**Assumed user state:** about to meet "the coach" for the first time.
**Produced user state:** waiting for an animation to finish — pacing tells the user this is a machine that has been instructed to look like a coach.

**Observation:** The typewriter at 28 ms/char on a 173-character line yields ~4.84 s of forced reveal. The CTA "DEVAM ET" is disabled until the line completes. A "Geçmek için ekrana dokun" hint appears as a fading opacity below the bubble while typing is in flight (line 641).

The mechanism: the user reads at adult speed (~250 wpm = ~3 chars/sec for Turkish density). The typewriter is ~36 chars/sec. The user finishes processing the line in <2 s; the next ~3 s is forced waiting on an animation.

**Cost:** The *first time* the user meets the coach, the experience is "I'm waiting for a robot to finish typing." The typewriter is technically "looks like real-time speech" but emotionally is closer to "old terminal" — it signals machinery, not personhood. For a coach intro that reads "Merhaba! Ben senin kişisel yapay zeka koçunum. Şimdi sana birkaç soru soracağım ve tamamen senin hedeflerine, vücuduna özel bir plan oluşturacağım." the *promise* is intimacy; the *delivery* is mechanical pacing.

Compare:
- A real recorded human voice (Headspace) at human speed — full intimacy.
- Pre-rendered text appearing all-at-once — clean, doesn't pretend.
- Typewriter at human-typing speed (~5 chars/sec) — looks like a person typing in chat.
- Typewriter at 36 chars/sec — looks like a machine.

The fix isn't to add voice. The fix is to either reveal the line all-at-once (cleaner) or to slow the typewriter to human-typing speed and not block the CTA (warmer).

**Evidence:** above + `_typingDone` boolean gates the CTA (line 659).

---

### 2.2 Paywall — Conversion-coded persuasion stack

**Assumed state:** ready to evaluate, willing to commit if value is shown.
**Produced state (well):** for M/F users, the gendered before/after composite + glowing arrow + ribbon does feel cinematic and aspirational.
**Produced state (poorly):** for non-binary/null gender users, the wheelchair-accessibility-icon "silhouette" placeholder is conversion-killing (PREMIUMIZATION_STRATEGY P-01, sev-5). For all users, the persuasion stack stacks four trust-eroding mechanisms (decoy reference price, sourceless social proof, hardcoded confidence carry-over, forced-auth gate).

The paywall's emotional state is **defensive**: every persuasion lever protects against the user closing without buying. The tone is "we're trying really hard."

#### Finding E-04: Forced-auth modal triggers identity-violation affect
**Severity:** 5/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:182–214` + `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:67–69` (PopScope canPop:false, barrierDismissible:false). Cross-cited with PRODUCT_STRUCTURE_REPORT F-04, USER_FLOW_ANALYSIS J-A3/J-D5, USER_PSYCHOLOGY_REPORT P-04.
**Surface:** Paywall + auth modal
**Assumed user state:** ready to evaluate the offer.
**Produced user state:** identity contradiction — "I just told the system everything, why is it asking who I am again?"

**Observation:** Sequence:
1. Wizard finishes; `_finish()` calls `signInAnonymously()` and routes to `/paywall`
2. Paywall mounts; `_onAuthStateChanged` fires immediately; detects `user.isAnonymous == true`; schedules `showAuthGate(context)` post-frame
3. Auth modal slides up over bottom 50% of paywall, blurs the top half, non-dismissible
4. User must pick Google / Apple / Email-link before seeing prices

The user's mental state at step 3:
- Just disclosed gender, age, height, weight, training history, daily-minutes commitment, activity level, pain point — to a system that promised "tamamen senin … özel bir plan."
- Just watched a 92% confidence bar fill twice (step 11 + step 12)
- Just read "Bu plan sana özel oluşturuldu."
- Now sees "Sign up to continue."

The emotional reading: **"the AI says it knows me, but the system needs my email to actually know me."** The contradiction is structural — anonymous Supabase UID is a server primary key, not an identity binding the AI engine cares about. But the user doesn't see it that way. The user sees: I just gave you everything, and now you want more.

**Cost:**
- Worst possible affect at the conversion gate. A user who feels betrayed evaluates the offer through that lens.
- The "let me see the prices first" path doesn't exist. Every user who wants to evaluate without committing identity is forced to OAuth.
- For users whose OAuth fails (USER_FLOW_ANALYSIS J-D5, sev-5), the affect compounds into "this app is broken AND it gated me."
- For Turkish-market users sensitive to OAuth privacy concerns (a real segment, post-2023 KVKK enforcement awareness), the modal is unfriendly defaults.

**Evidence:**
```dart
// paywall_screen.dart:182–191
void _onAuthStateChanged(User? previous, User? next) {
  if (_authGateShown) return;
  final needsAuth = next == null || next.isAnonymous;
  if (!needsAuth) return;
  _authGateShown = true;
  ...
}
```
+ the modal's `PopScope(canPop: false)` at `auth_modal_bottom_sheet.dart:67–69`.

The tradeoff (operational concern about RC aliasing, documented at `auth_modal_bottom_sheet.dart:11–55`) is real. But the *affect* cost is borne by the user; the operational cost was solvable in other ways (delay the alias, allow a "see prices" path with deferred auth at purchase tap, pre-anchor identity disclosure inside onboarding instead of post-onboarding).

---

#### Finding E-15: "🔥 10.000+ kişi kullanıyor" is emotionally suspect at the conversion gate
**Severity:** 3/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:752–783` (`_SocialProofTag`); cross-cited with USER_PSYCHOLOGY_REPORT P-12 (sev-4 mechanism), PREMIUMIZATION_STRATEGY P-11 (sev-3 design).
**Surface:** Paywall
**Assumed user state:** receptive to social proof.
**Produced user state:** trust-dent for users who notice the looseness; ad-copy familiarity for users who don't.

**Observation:** The pill renders "🔥 10.000+ kişi kullanıyor" at fontSize 12.5. Three signals about the number:
- It's round (10.000, not 10.247 or 12.413). Rounded numbers are honest as estimates and dishonest as measurements.
- It uses an emoji (🔥). Emojis at the conversion gate are a 2018-era SaaS-marketing trope.
- It has no source. No "in 2025", no "Türkiye'de", no "FormAI Pro üyesi", no "geçen ay."

Compounded with the decoy reference price (₺2.999,99 idi, USER_PSYCHOLOGY_REPORT P-05), the hardcoded 92% confidence carry-over from onboarding (P-11), and the unsourced "çoğu fark görüyor" claim earlier in onboarding (P-20), the conversion path has 4 loose-quantitative signals stacked.

**Cost:** The user's ambient sense at the conversion gate is "this is sales territory." For a brand whose promise is "AI form coach" — caregiver register — slipping into ad-copy register at the most-emotionally-loaded moment is an affect mismatch.

**Evidence:**
```dart
// paywall_screen.dart:771–780
const Text(
  '🔥 10.000+ kişi kullanıyor',
  style: TextStyle(
    color: Colors.white,
    fontSize: 12.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
  ),
),
```

The pill's intent is documented: "Numbers stay round and rough — never fabricate a precision figure for marketing copy" (paraphrased from comment at lines 752–754 in paywall_screen.dart). The team chose round-vague to avoid fabrication; the consequence is the pill reads as soft-marketing, which is a different fabrication.

---

### 2.3 Gelişim — The user's daily emotional touchpoint

**Assumed state:** curious about own progress; ready to be validated.
**Produced state (Day 0):** wall of zeros; emotional cold-open. Per USER_PSYCHOLOGY_REPORT P-01 (sev-5), the surface that should reflect competence reflects absence.
**Produced state (Day 7-21):** functional warmth — the streak card, day grid, badges, AI Coach all align with progression.
**Produced state (Day-after-streak-break):** shame broadcast — every surface that previously celebrated now silently broadcasts the failure.

#### Finding E-01: Day-0 Gelişim is silent broadcast of "you have nothing"
**Severity:** 5/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:541–632, 681–797, 1907–1945`. Cross-cited with USER_PSYCHOLOGY_REPORT P-01 (mechanism), PREMIUMIZATION_STRATEGY P-02 (premium-feel) — re-framed here on **affective** grounds.
**Surface:** Gelişim tab
**Assumed user state:** curious about own progress (the user just spent 2 minutes onboarding + closed the paywall).
**Produced user state:** inadequacy. The first impression of the user's own progress surface is six "0" or "0%" values rendered above the fold.

**Observation:** Above-the-fold inventory at Day 0:
- Streak pill: `🔥 0 Günlük Seri` (`gelisim_tab.dart:432`)
- Program Progress Card: `%0` at 34pt fw900 (`:567–576`) — the largest number on the screen
- Sub-line: `0 / 30 gün tamamlandı`
- Trophy ring: 0% filled
- Streak Card: `0 gün` at 34pt fw900 + `Serini bozma!` subtitle
- 5 empty dots
- AI Coach default copy: "Bugün hedeflerimize bir adım daha yaklaşıyoruz." (`:1620`)
- Three Stats Cards: `0 / 7`, `0 kcal`, `0 tamamlandı`
- 5 hex badge silhouettes, all dim, all 0% progress

Eight zero-state values in the first 600 px. **Every quantitative element on the screen reads zero.** The single exception is the personalized Today Task Card showing "Gün 1 – [Focus]" — the only warm signal on the entire surface.

**Cost:**
- Self-Determination Theory's competence pillar requires evidence of capacity. Day-0 user has none yet; the surface reflects this back as *evidence of absence*.
- Goal-gradient effect is inverted. The 30-day grid renders 1 active cell + ~5 amber rest cells + 24 dim/locked cells with lock icons. The visual is "27 obstacles ahead", not "30-day journey starts here."
- The motivational subtitle on the Program Progress Card reads "Harika gidiyorsun, devam et! 💪" (line 617) — a fixed string that contradicts the data at 0% (USER_PSYCHOLOGY_REPORT P-22). The user reads "you're doing great" over an empty progress bar.
- Day 1 → Day 2 transition produces 5 visual changes spread across 9 sections. Most users won't notice 4 of 5.

**The affect is structural, not a copy fix.** A surface that's data-shaped renders the user's data; if the data is zero on Day 0, the surface renders zero. The fix is rendering different content at Day 0 — forward-looking framing instead of quantitative readouts.

**Evidence:** see USER_PSYCHOLOGY_REPORT P-01 for the full enumeration. The single warm element on Day 0 is the personalized Today Task Card showing "Gün 1 – [Focus]" — visible at ~430-450 px, below the wall of zeros.

---

#### Finding E-02: Streak break renders shame across 5 surfaces simultaneously
**Severity:** 5/5
**Where:**
- Antrenman header `_FlameStreakBadge` (`antrenman_tab.dart:589–636`) — count badge requires `streak > 0` so disappears
- Gelişim header pill (`gelisim_tab.dart:432`) — renders raw 0 ("🔥 0 Günlük Seri")
- Gelişim Streak Card (`gelisim_tab.dart:680–795`) — "0 gün" + "Serini bozma!" + 5 empty dots
- Gelişim Three Stats Cards weekly bars (`gelisim_tab.dart:1219–1257`) — week chart shows the gap
- Home-screen widget (`widget_sync_service.dart:99, 153–155`) — broadcasts "0 gün seri" to the device home screen

**Surface:** Cross-tab + out-of-app
**Assumed user state:** humbled, possibly considering returning.
**Produced user state:** shame multiplied across 5 distinct visual surfaces.

**Observation:** A user who maintained a 12-day streak, missed Day 13, opens the app on Day 14 sees:
1. **Antrenman header:** the flame icon stays but the "12" counter pill vanishes (no count badge below streak=1). The visual difference between "I had a streak" and "I never had one" is invisible.
2. **Gelişim header pill:** "🔥 0 Günlük Seri" — explicit zero, orange-bordered.
3. **Gelişim Streak Card:** "0 gün" at 34pt + "Serini bozma!" (which now reads as accusation, E-08) + 5 empty dots.
4. **Three Stats Cards "BU HAFTA":** the missed day's bar collapses to baseline (0.25 height), creating a visible gap.
5. **Home-screen widget:** "0 gün seri" — visible to anyone who glances at the user's phone.

The system has the data to differentiate "user broke a 12-day streak" from "Day-0 user with no streak history" — `appPreferencesProvider.maxStreak` is persisted (USER_PSYCHOLOGY_REPORT P-07). Only one surface uses it: AI Coach copy switches to "Geri dönüş zamanı. 10 dakika yeterli." (`gelisim_tab.dart:1617`). The other 4 surfaces don't.

So a user with maxStreak=12 sees 4 surfaces that render identically to a Day-0 user, plus 1 surface (AI Coach) that differs by one sentence buried at section 7 of 9.

**Cost:**
- **Public-failure broadcast.** The home-screen widget is the most-public surface in the app — visible on the lock screen. A user who showed their partner "look I'm doing this 30-day program" the day they hit 12 days now sees the widget at "0 gün seri" the next day. The shame vector includes social cost.
- **Recovery-path invisibility.** The system has a perfectly reasonable comeback message ("Geri dönüş zamanı. 10 dakika yeterli.") — buried 5 user actions deep on a non-default tab (USER_FLOW_ANALYSIS J-E1).
- **Acknowledgment vacuum.** The 12 days happened. The system erases the visual evidence on the surfaces the user encounters most. The affect is "I worked, the app forgot."

The fix isn't to remove streak. The fix is to render *acknowledgment* at the same surfaces — "Best: 12 gün · current 0" on the header pill, "Geçmiş seri: 12 gün — bugün yeniden başla" on the Streak Card, a dedicated home-screen widget state for "12 days achieved, on rest."

**Evidence:** the only consumer of `maxStreak`:
```dart
// gelisim_tab.dart:1617
if (streak == 0 && maxStreak > 0) {
  return 'Geri dönüş zamanı. 10 dakika yeterli.';
}
```
+ widget pushes raw streakCount:
```dart
// widget_sync_service.dart:99
HomeWidget.saveWidgetData<int>(_kStreak, streakCount),
```
+ subtitle template:
```dart
// widget_sync_service.dart:153–155
final subtitle = exercise == null
    ? '%$percent · $streak gün seri'
    : ...
```

The widget renders the live streak as integer. There's no broken-state semantic.

---

#### Finding E-08: "Serini bozma!" subtitle at streak=0 is accusation
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:712–718`. Cross-cited with USER_PSYCHOLOGY_REPORT P-31 (sev-2). Re-framed here on affect.
**Surface:** Gelişim Streak Card
**Assumed user state:** active streak holder being reminded to maintain.
**Produced user state (at streak=0):** scolded — the system is still telling them "don't break your streak" *after* the streak is already broken.

**Observation:**
```dart
// gelisim_tab.dart:712–718
Text(
  'Serini bozma!',
  style: TextStyle(
    color: context.colors.onSurface.withValues(alpha: 0.55),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  ),
),
```

The subtitle is hardcoded — same string at streak=0, 5, 12, 30. Imperative-tu directive ("don't break") in Turkish lands either as protective advice (from a parent/coach to someone whose streak is intact) or as accusation (when applied to someone whose streak just broke).

**Cost:** Anti-empathic at the exact moment empathy matters. The user has just lost something they care about; the system's response is to repeat the warning that arrived too late.

**Affect compounding:** the user whose 12-day streak just broke reads, in order:
1. Header pill: "🔥 0 Günlük Seri" — fact
2. Streak Card title: "0 gün" — fact
3. Streak Card subtitle: "Serini bozma!" — *accusation*
4. 5 empty dots — fact
5. (Section 7) AI Coach: "Geri dönüş zamanı. 10 dakika yeterli." — recovery offer

The accusation lands before the recovery offer. The user reads scolding before they reach welcome.

**Evidence:** above. The fix is conditional rendering — at streak=0 + maxStreak>0, swap to "En iyi: $maxStreak gün — bugün yeniden başla" or similar.

---

#### Finding E-05: AI Coach Card has the lowest emotional bandwidth on the warmest surface
**Severity:** 5/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1551–1632, 1613–1621` (the 3 hardcoded copy branches). Cross-cited with USER_PSYCHOLOGY_REPORT P-06 (sev-4 mechanism), HABIT_LOOP_STRATEGY H-09 (sev-3 watermark unused), RETENTION_TRIGGER_REPORT none direct. Escalated here on affect grounds.
**Surface:** Gelişim AI Coach Card
**Assumed user state:** seeking warmth, daily check-in with the coach persona.
**Produced user state:** flatness — the most emotionally-named card in the app produces the most repetitive copy.

**Observation:** The AI Coach Card is the canonical relationship surface — branded "AI KOÇ", animated breathing avatar (2.4 s cycle, `gelisim_tab.dart:1828–1830`), neon-deep gradient ring + glow. Visually the warmest card on the dashboard.

The copy is 3 hardcoded branches:

```dart
// gelisim_tab.dart:1613–1621
String _copyFor({required int streak, required int maxStreak}) {
  if (streak >= 7) {
    return 'Şampiyon serisi devam ediyor! Böyle kal.';
  }
  if (streak == 0 && maxStreak > 0) {
    return 'Geri dönüş zamanı. 10 dakika yeterli.';
  }
  return 'Bugün hedeflerimize bir adım daha yaklaşıyoruz.';
}
```

A user at streak=7 and a user at streak=24 see identical copy. A user at streak=0 first-week and a user who broke streak see different copy. A user who's never had streak (Day 0) and a user mid-program at streak=4 see identical copy.

**The surface most labeled as personalized has the fewest personalized states.**

**Cost:**
- The brand promise (onboarding step 2: "tamamen senin … özel bir plan oluşturacağım") commits to personal coaching. The dashboard's coach delivers 3 strings.
- **A user who notices the repetition** (a non-trivial slice — Turkish-speaking AI early-adopters know what GPT-style branched copy reads like) *immediately* downgrades trust in the entire coach concept. The coach becomes wallpaper.
- The TTS daily summary (`_DailySummaryButton`, `gelisim_tab.dart:1648–1804`) is far more personalized — interpolates name, calorie target, dominant muscle, first meal name (lines 1738–1741). But it's an audio button most users will never tap. The voice surface is data-rich; the visual surface is data-poor.

**Inversion:** the data the visual coach has access to — `streak`, `maxStreak`, `percent`, plus everything in `appPreferencesProvider.userMetrics` (goal, painPoint, activityLevel, dailyMinutes, age, gender) — is mostly unused in the visual copy. The pain point disclosed in onboarding step 9 is never echoed in coach copy. The goal is never echoed. The percent through the program is passed in (`_AiCoachCard({required this.streak, required this.percent})` at line 1551–1554) but never branched on in `_copyFor`.

**The visual coach is a cosmetic UI element with the chrome of intimacy and the content of a generic motivational poster.**

**Evidence:** above + grep for `painPoint` in `gelisim_tab.dart` returns no hits. The data is collected, persisted, never used for coach copy.

---

#### Finding E-12: "Bugün hedeflerimize bir adım daha yaklaşıyoruz" — generic-LLM voice
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1620` (default branch of `_copyFor`)
**Surface:** Gelişim AI Coach Card
**Assumed user state:** in the most-frequent state (streak 1-6 OR streak 0 with no past streak).
**Produced user state:** generic-AI familiarity. The line reads as ChatGPT-default.

**Observation:** The default branch fires for every state that's not "champion" (streak ≥ 7) or "comeback" (streak=0 + maxStreak>0). This includes:
- Day 0 user (no completion, no past streak)
- Day 1-6 active streak user
- Day 1-6 broken-and-restarting user

Most users for most of their first week see this line. Every day. Same line.

The phrasing "Bugün hedeflerimize bir adım daha yaklaşıyoruz" — "today we are taking one more step toward our goals" — is structurally the genre of motivational copy that fills self-help wall art. First-person plural ("hedeflerimize" — "our goals") is a coaching-voice convention but the rest of the line has no personalization hook.

**Cost:**
- For the predominant beginner segment, the most-frequently-encountered coach line is the most generic.
- "We" is doing a lot of work — without context, "our goals" reads as motivational-poster vague rather than coach-knows-you specific.
- The line cannot reference: the user's goal token (göbek-eritmek, kas-yapmak, etc.), today's focus muscle, day number, percent through the program. All are available; none are used.

**Evidence:**
```dart
// gelisim_tab.dart:1620
return 'Bugün hedeflerimize bir adım daha yaklaşıyoruz.';
```

The fix is one branch with `${session.activeDay?.dayNumber}` and one with `${wizard.goal}` interpolation. The structural absence is the signal — the engine can branch; nobody wrote more branches.

---

#### Finding E-14: Three concurrent pulse animations on Gelişim — energy reads as anxiety
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:977` (`_PulsingCurrentCellState` 1400 ms cycle), `:1825–1830` (`_CoachAvatarState` 2400 ms breathing scale 0.95→1.05), various `_SoftCard` accent shadows; cross-cited with PREMIUMIZATION_STRATEGY V-23, USER_PSYCHOLOGY_REPORT P-30.
**Surface:** Gelişim
**Assumed user state:** calm review of progress.
**Produced user state:** ambient agitation. Multiple competing pulses read as "everything wants attention" rather than "look here."

**Observation:** Concurrent motion when Gelişim mounts:
- Current day cell pulse (1400 ms reversed, 12-24 px blur cycle, `:996–1013`)
- Coach avatar breathing scale (2400 ms, scale 0.95-1.05, `:1828–1830`)
- TweenAnimationBuilder fills (program progress bar 700 ms, trophy ring 700 ms, weekly bar fills 600 ms each)
- Soft card neon halos (decorative shadows on every card via `_SoftCard.boxShadow`)

Plus the streak card flame puck has glow, the trophy ring has glow, the AI Coach avatar has glow. The dashboard's brightness budget is heavy.

**Cost:** Calm-energy is the on-brand register for "see your progress" — premium fitness apps (Apple Fitness+, Centr) gate dashboard motion to one element at a time. Casino-style multi-pulse reads as anxious for a sustained-reading surface. For users sensitive to motion (vestibular issues, ADHD, attention fatigue), three concurrent pulses can be physically uncomfortable.

**Evidence:** see file:line refs above.

---

#### Finding E-11: Locked-day cells communicate forbidden territory
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1129–1175` (`_LockedCell`); cross-cited with USER_PSYCHOLOGY_REPORT P-13.
**Surface:** Gelişim 30-day grid
**Assumed user state:** anticipation of progression.
**Produced user state:** distance-feels-as-prohibition. 27 lock icons render the future as forbidden territory.

**Observation:** The locked-cell visual:
```dart
// gelisim_tab.dart:1141–1173 (excerpted)
return IgnorePointer(
  child: Opacity(
    opacity: 0.55,
    child: Container(
      ...
      child: Column(
        ...
        children: [
          Icon(Icons.lock_rounded, ..., size: 12),
          Text('$dayNumber', ...),
        ],
      ),
    ),
  ),
);
```

`IgnorePointer` makes the cell non-tappable. The lock icon + 55% opacity + dim day number says "prohibited." But the cell is *future-locked* (Day 8 when user is at Day 4) — it auto-unlocks once Day 7 completes. The lock visual conflates two distinct states:
- **Pro-locked** (Day 4-30 for free users): genuinely paywall-gated.
- **Time-locked** (any day after the user's current): auto-unlocks via the natural progression of the program.

Both render identically. The user can't distinguish "I need to pay to unlock this" from "I need to continue to unlock this."

**Cost:**
- Goal-gradient framing is killed. A goal-gradient-aware app renders Day 8 as the next destination, not as a forbidden cell. FormAI shows it as forbidden.
- For free users, 27 lock icons land as "27 things I can't have" rather than "27 days of progression ahead."
- The semantic conflation (Pro-lock vs time-lock) means the user doesn't know which 1-tap-unlock cells are paid and which are time-gated. They infer paid via the Today Task Card paywall surprise.

**Evidence:** above. A time-locked cell could render as "Gün 8 — Yarın açılır" or "Gün 8 — Bacak Gücü, sıradaki" with a different chrome (forward-looking arrow rather than lock). A Pro-locked cell could render with a small crown or "Pro" badge. The current pattern uses one visual for both.

---

### 2.4 Beslenme — Nutrition surface

**Assumed state:** appetite, planning, curiosity.
**Produced state (well):** the recipe detail screen is the strongest premium surface in the app (PREMIUMIZATION_STRATEGY P-04, sev-4 marker as the *strongest*) — full-bleed photo, 28pt magazine title, macro tiles.
**Produced state (poorly):** macro-deficit shame on the nutrition tab; "kalori aşıldı" deficit framing; the deferred 7-step nutrition onboarding sheet that ambushes a first-time Beslenme tap.

#### Finding E-18: "Kalori aşıldı" red banner is shame-coded
**Severity:** 3/5
**Where:** `lib/features/nutrition/presentation/nutrition_tab.dart:640–644, 974`
**Surface:** Beslenme tab calorie hero
**Assumed user state:** logging meals, neutral check-in on the day's totals.
**Produced user state:** moral judgment. "Aşıldı" (exceeded) framing on calorie counts is deficit-coded — the user is *over* the number, which reads as "too much" rather than "different from target."

**Observation:**
```dart
// nutrition_tab.dart:640–644
static String _remainingLabel(int remaining) {
  if (remaining > 0) return '$remaining kcal kaldı';
  if (remaining < 0) return '${-remaining} kcal aşıldı';
  return 'hedef tam';
}
```

And the AI insight banner copy at `nutrition_tab.dart:723–728`:
```dart
if (target.calories > 0 && overage > 0) {
  return (
    message: '$overage kcal fazla aldın.',
    fix: 'Akşam karbonhidratı azalt veya 20 dk yürüyüş yap.',
  );
}
```

"Aşıldı" / "fazla aldın" are deficit verbs in Turkish — they presuppose the threshold is the right answer and any deviation is a mistake. The fix copy ("Akşam karbonhidratı azalt veya 20 dk yürüyüş yap") is corrective, not contextual.

**Cost:**
- Calorie targeting is *probabilistic* — the daily target is an average estimate, not a hard line. A 200-kcal "aşıldı" on one day with a 200-kcal deficit on another is neutral; the system frames the +200 day as failure and the -200 day as success.
- For users with eating-disorder histories (a non-trivial slice in any fitness app), deficit/surplus framing can trigger restrictive thinking.
- Turkish "aşıldı" specifically — "exceeded" — has school-grading connotations (sınırı aştın = you crossed the limit, bad).

**Evidence:** above. A neutral fix would frame as "$overage kcal fazla" (no verb) and pair with "yarın daha hafif başla" (forward, not corrective).

---

### 2.5 Profil — Settings tab

**Assumed state:** task-driven (change a setting, see info, log out).
**Produced state (well):** the personal info section (BİLGİLERİM) renders 4 InfoTiles + Düzenle button — visually warm.
**Produced state (poorly):** 8 functional sections in one tab (PRODUCT_STRUCTURE_REPORT F-08, F-20). Destructive action (delete account) lives in the same chrome as benign settings (notifications, theme).

#### Finding E-19: "Hesabı Sil" rendered with same chrome as "Bildirimler"
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/profile_tab.dart:191–197` (`_DangerSettingsTile`)
**Surface:** Profile tab HESAP AYARLARI section
**Assumed user state:** task-driven, doesn't accidentally tap destructive action.
**Produced user state:** weak destructive-action signal. The "Hesabı Sil" tile renders with the same `_DangerSettingsTile` chrome, but it's still in the same vertical scroll list as 3 mundane tiles ("Profili Düzenle", "Şifreyi Değiştir", "Bildirimler").

**Observation:** The Profile tab's HESAP AYARLARI section (`profile_tab.dart:166–197`) renders 4 tiles in sequence. The fourth (`_DangerSettingsTile`) carries a danger color (per atlas §7.1 `danger #FF4D6D`). But:
- The position is at the *bottom* of HESAP AYARLARI — i.e., directly above the next section header.
- The chrome is a tile (same shape as the 3 above it).
- There's no confirmation step on the *tile* (the actual delete flow has confirmation in `account_settings_screen.dart`, but the tile-tap goes there directly).

A user scrolling through Profile, hunting for Bildirimler (the third tile), can mis-tap and land on the delete-flow path.

**Cost:** Mild — the actual delete is gated by `account_settings_screen.dart` confirmation. But the tile-list pattern places destructive next to mundane, which is an emotional-design lapse. Apps that handle this well isolate destructive actions to a "Hesap Yönetimi" subscreen accessed via an explicit "More options" tile.

**Evidence:** see file:line + atlas §13 inventory.

---

### 2.6 Workout-Camera — Active mode

**Assumed state:** focused, in-the-zone, ready to perform.
**Produced state (well):** cyber-cyan HUD + pose-skeleton overlay reads as research-grade tech (PREMIUMIZATION_STRATEGY P-04 calls this the strongest tech-differentiator, sev-4).
**Produced state (poorly):** chrome is hardcoded `Colors.black` + cyan — emotionally fragmented from the rest of the app (E-06).

#### Finding E-06: Workout-camera scaffold inhabits a different product
**Severity:** 4/5
**Where:** `lib/features/workout/presentation/workout_camera_screen.dart:698` (`backgroundColor: Colors.black`); cross-cited with PREMIUMIZATION_STRATEGY P-07 (sev-3 visual fragmentation), USER_PSYCHOLOGY_REPORT P-23.
**Surface:** Workout camera (active mode)
**Assumed user state:** focused, in-flow, supported.
**Produced user state:** clinical instrument feeling. The warmth of the dashboard coach is gone; the user is in a measurement environment.

**Observation:** Dashboard chrome:
- Warm purple radial gradient (Gelişim) or scaffold default with neon accents (Antrenman)
- Breathing avatar, neon-purple CTAs, friendly Turkish copy
- Soft card halos, rounded corners

Workout-camera chrome:
- Hardcoded black scaffold (`workout_camera_screen.dart:698`)
- `_neon` redefined as `0xFF00F0FF` cyan locally (atlas §7.1)
- `Colors.redAccent` warning chips (`:1156`)
- Cyber-cyan HUD overlays

Functionally the cyber-cyan reads as "research-grade pose detection" — distinctive, hard for competitors to match. Emotionally it reads as a different app — clinical instrument vs warm coach.

**Cost:** Brand voice fragmentation. The user has two FormAIs in their head: dashboard FormAI (warm, encouraging coach) and workout-camera FormAI (clinical, measurement-focused instrument). Premium fitness apps maintain a single voice across both modes. Apple Fitness+ is consistent black/red across all surfaces; Centr is consistent green/charcoal.

The TTS coach voice maintains warmth ("Harika! Şimdi 30 saniye dinlenme.", `workout_camera_screen.dart:656–658`) — the audio register is right. But it doesn't compensate for the visual register flip.

**Evidence:** see file:line refs above.

---

### 2.7 Notification — Out-of-app voice

**Assumed state:** glanceable, decision-prompting.
**Produced state (well):** the celebration variants ("Mükemmel bir gün 💧") are warm and tonal-clean.
**Produced state (poorly):** the loss-framing variants ("Hedeflerinden uzaklaşma", "geride kalırsın") are guilt-coded. Variant pool is 5 loss : 3 celebration : 2 mixed (RETENTION_TRIGGER_REPORT T-08).

#### Finding E-09: Notification voice and in-app voice are emotionally distinct registers
**Severity:** 4/5
**Where:** `lib/core/services/notification_service.dart:70–123`
**Surface:** Notification (out-of-app)
**Assumed user state:** glanceable cue.
**Produced user state:** emoji-led pop voice. Different brand personality than in-app coach.

**Observation:** The notification copy register:
- "🔥 Antrenman Vakti! 💪" — emoji-led, gym-buddy
- "🥩 Yakıt Gerekli!" — emoji-led, food-pop
- "🏆 Günü fethettin!" — emoji-led, military celebration
- "⚡ Seriyi kaybetmek üzeresin!" — emoji-led, urgent

The in-app coach register:
- "Şampiyon serisi devam ediyor! Böyle kal." — gym-buddy text, no emoji
- "Geri dönüş zamanı. 10 dakika yeterli." — coach voice, no emoji
- "Bugün hedeflerimize bir adım daha yaklaşıyoruz." — first-plural coach voice, no emoji

The notification register is louder, emoji-led, more loss-framed. The in-app register is quieter, no-emoji, more coach-flavored.

**Cost:** A user's lock-screen impression of FormAI is "🔥💪🥩🎯⚡" — emoji-led, urgent, occasionally guilt-loaded. The in-app voice is restrained neon coach. **Two brand personalities operate simultaneously.** The user who builds a relationship with the in-app coach voice gets pinged by a different voice on the lock screen.

The split correlates with engineering ownership likely (notifications written for "channel attention", in-app coach written for "relationship building") — both are valid as design intents, but the gap between them isn't priced.

**Evidence:** the notification variant pools at `notification_service.dart:70–123` vs the AI Coach copy at `gelisim_tab.dart:1613–1621`. Tonal difference is visible by inspection.

**ERRATA-vs-USER_PSYCHOLOGY_REPORT-P-19:** USER_PSYCHOLOGY_REPORT P-19 covered the notification-voice register (sev-3). E-09 reframes for emotional design — same fact, different lens. Severity bumped to 4/5 because the *gap between the two voices* is the affect cost (not just the notification voice in isolation).

---

#### Finding E-22: "Günü fethettin" uses military verb
**Severity:** 2/5
**Where:** `lib/core/services/notification_service.dart:96–99` (`_bothDoneVariants[0]`); cross-cited with USER_PSYCHOLOGY_REPORT P-33 (sev-2). Re-framed.
**Surface:** Notification (celebration variant)
**Assumed user state:** celebrating a complete day.
**Produced user state:** male/aggressive register slip on a brand that's not committed to that voice.

**Observation:**
```dart
// notification_service.dart:96–99
(
  title: 'Günü fethettin! 🏆',
  body: 'Bugün disiplinden kopmadın. Şimdi bol su iç ve dinlenmeye geç.',
),
```

"Fethettin" — to conquer. Military verb in Turkish. Used proudly for sports achievements but with conqueror-conquered framing. For a fitness app whose audience includes a substantial female demographic and a gentle-fitness adoption pattern, the verb skews to a register the brand isn't committed to elsewhere.

**Cost:** Tone mismatch with the broader caregiver register. Compare the same pool's "Mükemmel bir gün 💧" — same celebration moment, warmer voice. The pool has 3 variants at random selection; the user can land on any.

**Evidence:** above. The fix is the variant pool composition — drop the "fethettin" variant or reframe ("Bugün her şeye sahiptin").

---

### 2.8 Cross-cutting — Identity reflection (or lack thereof)

#### Finding E-13: Identity language is structurally absent
**Severity:** 4/5
**Where:** Cross-cutting absence; cross-cited with USER_PSYCHOLOGY_REPORT P-17 (sev-4 mechanism). Re-framed for emotional layer.
**Surface:** Cross-cutting
**Assumed user state:** developing identity through behavior.
**Produced user state:** behavior-as-action, not behavior-as-identity. The brand never reflects the user back to themselves.

**Observation:** Across the entire surface area, every line of copy is one of:
- Activity description ("Bugün hedeflerimize bir adım daha yaklaşıyoruz")
- Goal description ("Şampiyon serisi devam ediyor!")
- Instruction ("Serini bozma!", "Antrenmana başla")
- Quantitative readout ("3 / 30 gün tamamlandı")
- Time-based copy ("Günün antrenmanı seni bekliyor")

What's missing: any line that says "you are X." Identity claims like "FormAI sporcusu", "30 gün boyunca disiplinli birisin", "Senin gibi adanmışlar bu yolda" — none exist. Confirmed via grep:

```
grep -rn "FormAI sporcu\|sporcusu\|disiplinli birisin\|adanmış" lib/
→ no results
```

**Cost:**
- The user's emotional development is action-level, not identity-level. Behaviors stick when they reinforce identity (Clear, *Atomic Habits*); identity claims are the strongest retention engine.
- For Day-30 program completers — the highest-value segment — the system has nothing to *reflect them as* anything. They completed the program; they don't become anyone.
- The Welcome hook frames the body as object ("Vücudunu Yapay Zeka ile Şekillendir" — your body, AI shapes it) rather than the user as agent (USER_PSYCHOLOGY_REPORT P-18). The locus-of-control framing is set on the very first screen.

**The fix is not a copy change.** The fix is a series of identity-claim moments at specific milestones — Day 7 unlock copy ("artık 1 haftalık disiplinli birisin"), Day 30 completion ("30 gün boyunca her gün gösterdin — artık FormAI sporcususun"), 100-day marker ("zaten bir antrenman alışkanlığın var"). The brand needs identity language to graduate users from "I'm trying" to "I am."

**Evidence:** absence pattern + grep confirmation above.

---

### 2.9 Cross-cutting — Reward magnitude inversion

#### Finding E-20: Program-complete card is undersized
**Severity:** 3/5
**Where:** `today_task_card.dart:176–216` (`ProgramCompleteCard`) vs `lib/features/progress/presentation/widgets/badge_unlock_dialog.dart:55–100`. Cross-cited with USER_PSYCHOLOGY_REPORT P-28 (sev-3), HABIT_LOOP_STRATEGY H-06 (sev-4). Re-framed.
**Surface:** Gelişim
**Assumed user state:** triumphant — finished the 30-day program.
**Produced user state:** anti-climactic. The biggest achievement gets a 60-px inline card.

**Observation:** Side-by-side:

`ProgramCompleteCard` (Day 30 reward):
```
🏆 [30pt emoji]
Tebrikler!                      [18pt fw900 white]
30 günlük programı tamamladın.  [13pt fw600 white80]
```
Inline card, ~80 px tall, sits in the same slot as the Today Task Card. No modal, no fullscreen, no haptic, no share prompt that fires automatically.

`_BadgeUnlockDialog` (mid-program badge unlock):
```
[Fullscreen modal with backdrop]
YENİ ROZET                       [11pt fw900 letter-spacing 4]
[110×110 animated halo with badge icon]
[Badge name 22pt fw900]
[Description body]
[Dismiss + Share buttons]
+ HapticFeedback.heavyImpact()
```
Fullscreen, ~400 px tall, animated, haptic, share affordance.

A user who unlocks one minor badge gets a *bigger celebration* than a user who completes 30 days of discipline.

**Cost:** Reward magnitude inversion. The user's emotional response to the program-complete moment is supposed to be the high-water mark of the entire app experience. The visual reward says: "you finished... here's a card the size of the daily task."

The session-complete overlay (`session_complete_overlay.dart`) for *one* workout is also bigger than the program-complete card. **One day's celebration > 30 days' celebration.** Backwards.

**Evidence:** above. The codebase has the components (`_BadgeUnlockDialog`, `SessionCompleteOverlay`) and didn't deploy them at the most important moment.

---

## 3. CULTURAL CONTEXT — TURKISH-MARKET TONE

### 3.1 Tu/sen voice across the app

Turkish has a tu/sen (intimate-singular) vs siz (formal/plural) distinction. The wizard, AI Coach, notifications all use tu/sen. This is correct for a coach/buddy register — appropriate to brand.

The risk is **commanding tu/sen with imperatives**, which reads as pushy:
- "Serini bozma!" — imperative, direct
- "Hedeflerinden uzaklaşma." — imperative, loss-framed
- "Antrenmana başla" — imperative, neutral

Friendlier alternatives:
- "Serine devam et" (declarative, positive frame)
- "Hedefinden uzaklaşmayalım" (we-voice, soft suggestion)
- "Antrenmana hazır mısın?" (question, agency-respecting)

The current copy mix leans imperative. For Turkish users who carry residual school/parental imperative-tu memories, the voice can feel commanding rather than coaching.

### 3.2 Emoji density

The notification system + paywall social-proof pill + onboarding goal feedback all use emoji-led copy. The in-app coach copy doesn't. **The split between emoji-heavy and emoji-free voice is a tonal seam.**

The most-loaded emoji uses:
- 🔥 (fire) — 4 surfaces (paywall pill, notification 3 variants, onboarding goal banner)
- 💪 (flexed arm) — 2 notification variants, 1 onboarding banner
- 🏆 (trophy) — notification celebration, program complete card
- 🥩 (steak) — workout-no-food notification
- ⚡ (lightning bolt) — 2 notification variants

🔥 + 💪 are gym-buddy/social-media coded. 🏆 is celebration-coded. 🥩 is direct/protein-pop coded. ⚡ is urgency-coded.

For a brand that wants to read as caregiver coach, the gym-buddy/urgency emojis at decision-loaded moments (paywall, streak warnings) work *against* the brand voice. The celebration emojis (🏆, 💧 water-drop) work *with* it.

### 3.3 Direct quantitative claims

Turkish-market regulatory and consumer-trust texture in 2026 is sensitive to unsourced quantitative claims. The app has four:
- "10.000+ kişi kullanıyor" (paywall, USER_PSYCHOLOGY_REPORT P-12)
- "Bu hedefle başlayanların çoğu 30 gün içinde fark görüyor" (onboarding, P-20)
- "%92 başarı olasılığı" (onboarding, P-11)
- "₺2.999,99 idi" (paywall, P-05)

Stacked, these read as "loose-quantitative voice." Turkish-speaking users who do Reddit/ekşisözlük research will recognize the pattern within ~30 days of launch.

The fix is removing or sourcing — not all four need to be measured-exact, but the cumulative looseness has emotional cost (suspicion).

---

## 4. AFFECT-BY-MOMENT TIMELINE

A summary of the user's emotional ride across the canonical lifecycle:

| User moment | Surface | Designed affect | Produced affect | Gap |
|---|---|---|---|---|
| First open | Welcome | anticipation | high cinematic warmth | +2 (well-tuned) |
| Coach intro | step 2 | warm meeting | wait for typewriter | -1 (E-17) |
| Goal step | step 4 | acknowledged | sales line | -1 (P-20) |
| Pain-point step | step 9 | heard | auto-advanced | -2 (E-07) |
| Analysis illusion | step 10 | "AI is working" | theatrical wait | -1 (P-15) |
| Dynamic AI report | step 11 | endowment | endowment built (1.4 s reveal) | +2 (well-tuned) |
| Pre-paywall summary | step 12 | confidence | trust booster (2nd 92% bar) | 0 (neutral) |
| Anonymous → paywall | route exit | conversion-evaluating | identity contradiction (E-04) | -3 |
| Auth modal | bottom 50% | authenticate | trapped (J-D5 echo) | -2 |
| Paywall hero (M/F) | hero | aspirational | cinematic | +2 |
| Paywall persuasion stack | cards + decoy + social | intrigued | manipulation density (P-05/P-12 stack) | -3 |
| Paywall close → dashboard | landing | warm welcome to free preview | wall of zeros (E-01) | -3 |
| Day 1 workout entry | Today Task | anticipation | personalized "Gün 1" — warm | +1 |
| Workout camera mid-rep | active | flow state | cyber-cyan flow (PREMIUMIZATION 4.5/5) | +1 |
| Workout camera scaffold | chrome | brand consistency | clinical fragmentation (E-06) | -1 |
| Day 1 completion | overlay | pride | full overlay celebration | +2 |
| Day 1 dashboard return | Gelişim | proof | 1 green check + flame badge appears | +1 |
| Day 4 tap CTA | Today Task | start workout | paywall surprise (E-03) | -3 |
| Day 7 milestone | AI Coach | recognition | "Şampiyon serisi devam ediyor!" — warm but generic past Day 7 (E-12, P-07) | 0 |
| Day 14 milestone | nothing | identity claim | nothing — no Day 14 celebration | -2 |
| Day-after-streak-break | every surface | gentle welcome | shame broadcast (E-02) | -3 |
| Day 30 completion | ProgramCompleteCard | triumph | undersized inline card (E-20) | -2 |
| Day 31+ | nothing | next chapter | habit ceiling (P-29) | -3 |

The ride: starts at +2, peaks at +2 multiple times (welcome, dynamic report, paywall hero, Day 1 workout), bottoms at -3 multiple times (forced auth, persuasion stack, Day-0 wall of zeros, Day 4 paywall, streak break, habit ceiling).

**The emotional ride is not consistent.** Wins are followed by losses. The user's cumulative affect is volatile rather than warming.

---

## 5. STRUCTURAL OBSERVATIONS

### What the system does emotionally well:
1. **Welcome step cinematic photo** — high-warmth opening.
2. **AI coach breathing avatar** — 2.4 s scale 0.95-1.05 reads as alive.
3. **Recipe Detail full-bleed hero** — magazine-grade emotional invitation.
4. **Workout-camera pose-skeleton overlay** — research-grade tech wonder.
5. **Session-complete overlay** — full, tonally-correct celebration.
6. **Recovery-recipe suggestion** in session-complete — thoughtful endowment moment.
7. **Smart-reminder branching** (3 condition pools) — intent is right; copy ratio off.
8. **Streak-warning at 48h not 24h** — humane respect for life.
9. **Light-mode parity work** (Phase 53) — cross-theme support is in progress.
10. **Recovery copy that names "10 dakika yeterli"** — the comeback line gets the friction-low ask right.

### What the system does emotionally poorly:
1. **Day 0 wall of zeros** (E-01) — first impression of own progress is absence.
2. **Streak break shame broadcast** (E-02) — 5 surfaces shout the failure.
3. **Day 4 paywall surprise** (E-03) — at the moment of fragility.
4. **Forced-auth identity contradiction** (E-04) — at the moment of conversion intent.
5. **AI Coach card with 3 hardcoded copies** (E-05) — warmth surface with content-poor copy.
6. **Workout-camera as different product** (E-06) — brand voice fragmentation.
7. **Reciprocity asymmetry** (E-07) — vulnerable disclosures met with one-line auto-advance.
8. **Streak Card "Serini bozma!" at streak=0** (E-08) — accusation.
9. **Notification voice ≠ in-app voice** (E-09) — two brand personalities.
10. **"AI listened to you" anthropomorphism** (E-10) — over a multiple-choice wizard.
11. **Locked cells as forbidden** (E-11) — future framed as prohibition.
12. **Default coach line generic-LLM** (E-12) — primary daily copy is template.
13. **Identity language absent** (E-13) — brand never reflects user back as anyone.
14. **Triple-pulse anxiety** (E-14) — calm surface reads casino.
15. **Sourceless quantitative claims** (E-15) — trust-loose voice at conversion.
16. **Phosphor-yellow on light** (E-16) — visceral discomfort on appetite surface.
17. **Typewriter as machinery** (E-17) — coach intro paced as terminal.
18. **"Aşıldı" deficit framing** (E-18) — moral judgment on calorie counts.
19. **Destructive-action register** (E-19) — delete account in mundane settings chrome.
20. **Program-complete undersized** (E-20) — 30-day arc less celebrated than 1 badge.

### The five most consequential affective failures (sev-5):
- **E-01 Day-0 wall of zeros** — the first impression of "your progress" is "you have nothing"
- **E-02 streak break broadcast** — the system shouts the failure across 5 surfaces
- **E-03 Day 4 paywall surprise** — the trap door at the moment of habit-formation fragility
- **E-04 forced-auth identity contradiction** — the AI knows you, sign up so we can know you
- **E-05 AI Coach low bandwidth** — the warmest surface with the lowest content density

If only these five were addressed — without redesigning the rest — the app's affect curve would lift from "volatile" to "consistently warming." The bones of warmth are all there (welcome photo, breathing avatar, recipe hero, completion overlay). What's missing is sustaining the warmth through the cold zones.

---

## 6. ERRATA VS PRIOR PHASES

**ERRATA E-A:** USER_PSYCHOLOGY_REPORT P-01 (sev-5) covered Day-0 wall-of-zeros on **mechanism** grounds (SDT competence collapse). E-01 here covers the same fact on **affective** grounds (silent broadcast of absence). Same severity, different lens. Both should be priced.

**ERRATA E-B:** USER_PSYCHOLOGY_REPORT P-04 (sev-5) covered forced-auth-modal on **identity contract** grounds. E-04 here covers it on **affect** grounds (identity-violation feeling). Same severity, different lens.

**ERRATA E-C:** USER_PSYCHOLOGY_REPORT P-06 (sev-4) covered the AI Coach copy as **personalization gap**. E-05 escalates to sev-5 on affective grounds because the AI Coach card is the canonical *warmth* surface (not just a personalization surface) — its content-density failure is more emotionally costly than the personalization grade alone suggests.

**ERRATA E-D:** USER_PSYCHOLOGY_REPORT P-19 (sev-3) covered notification voice. E-09 reframes for emotional design and bumps to sev-4 — the *gap between voices* (notification-pop vs in-app-coach) is the affect cost, not just the notification voice in isolation.

**ERRATA E-E:** RETENTION_TRIGGER_REPORT T-07 (sev-4) covered home-screen widget streak broadcast. E-02 here adds it as one of 5 simultaneous streak-break surfaces. The widget is the most-public; the cumulative effect across all 5 is the actual emotional cost.

**No factual contradictions with prior phases discovered.** Every finding is grounded in the same source files cited in atlas + Phase 2 + earlier Phase 3 reports. This report adds **affective lens** to facts the other reports establish.

---

## 7. SUMMARY

The emotional layer of FormAI Fit is **structurally warmth-capable** but **operationally cold-leaking.** The brand has the components: cinematic welcome, breathing coach avatar, magazine recipe hero, full session-complete celebration, smart-reminder branching, humane 48-h streak window. These are not absent.

What's leaking:
- **Day-0 user lands on wall of zeros** before they earn any warmth
- **Streak break renders shame across 5 surfaces** when one surface should reframe and the rest should de-emphasize
- **Paywall lands on Day 4** with no pre-warning at the moment of habit-formation fragility
- **Forced-auth modal contradicts the AI's "I know you" promise** at the conversion gate
- **The AI Coach card has 3 hardcoded copy branches** on the brand's primary warmth surface
- **Identity language is structurally absent** — the brand never reflects the user back as anyone

These are not unrelated bugs. They cluster around three structural costs:

1. **Asymmetry of investment.** The user invests effort/time/disclosure in onboarding; the system performs theatrical investment back; the dashboard reflects the user's data only as quantitative readout, not as identity.
2. **Inversion of reward magnitude.** Single badges get fullscreen modals; 30-day completion gets an inline card. Single-day celebration > program completion celebration.
3. **Splitting of brand voice.** Notification voice (emoji-led, urgent, loss-framed) and in-app voice (warm, neon, no-emoji) are emotionally distinct. The user's lock-screen FormAI is a different brand than their in-app FormAI.

The five sev-5 findings (E-01 through E-05) are the structural fix list. The eight sev-4 findings are the brand-voice fix list. Together they form an emotional-layer audit that aligns with — and adds the *felt* dimension to — the mechanism, retention, and habit findings of the other Phase 3 reports.

For a Turkish-market 30-day fitness program where the audience is predominantly beginners and the brand promise is "AI form coach", the emotional-architecture goal is consistent warmth with appropriate moments of acknowledgment, pride, and identity reflection. The current architecture has all the components for that goal; the implementation gap is in **sustaining warmth across cold zones** (Day 0, Day 4 gate, streak break, program completion, lock-screen) rather than only producing it at peak moments.

---

**END OF EMOTIONAL_DESIGN_STRATEGY.md**

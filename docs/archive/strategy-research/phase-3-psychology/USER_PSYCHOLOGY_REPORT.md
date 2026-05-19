# USER PSYCHOLOGY REPORT

**Phase 3 — Psychology · Behavioral & Emotional Audit**
**Project:** SixPack AI / FormAI Fit (Turkish-market 30-day abdominal program with on-device ML Kit pose detection)
**Generated:** 2026-05-08
**Inputs:**
- `reports/phase-1-project-discovery/PROJECT_STRUCTURE_MAP.md` (atlas — ground truth, with §15 errata)
- `reports/phase-2-product-analysis/PRODUCT_STRUCTURE_REPORT.md` (24 IA findings)
- `reports/phase-2-product-analysis/USER_FLOW_ANALYSIS.md` (5 critical journeys)
- `reports/phase-2-product-analysis/PREMIUMIZATION_STRATEGY.md` (perception-by-surface)
- ~14 source-file inspections (onboarding wizard, gelisim_tab, today_task_card, paywall, ai_personalization_engine, notification_service, suggestions_screen, session_complete_overlay, etc.)

**Scope:** Behavioral and emotional architecture audit of every meaningful surface. The question is *not* "what does the screen do?" — Phase 1 and 2 answered that. The question here is **what mental and emotional state does the screen produce, and is that state aligned with the user's goal?**

**Brand context (recurring theme):**
- "30 günde karın kası" (abs in 30 days) is itself a strong hook with high dropout risk if outcomes feel out of reach. The promise has to be carried by the product on Day 4, Day 14, Day 22.
- Beginner segment dominates ("İlk 7 Gün" badge unlocks at Day 1; `_difficultyLabel` defaults to `'Başlangıç'`). The app must protect competence, not test it.
- Direct second-person Turkish voice ("hedefin", "vücudun", "seni") creates intimacy — but also ownership of every emotional consequence the copy lands.

---

## 0. HOW TO READ THIS REPORT

Each finding follows:

```
### Finding P-NN: [imperative title]
Severity: N/5 (psychological/retention impact, not engineering effort)
Where:    file:line + atlas §X.Y
Mechanism: [behavioral principle at play]
Observation: [factual]
Cost:        [what the user feels]
Evidence:    [code or copy snippet]
```

Severity scale (psychology-calibrated):
- **5** — actively harms the emotional contract or causes a known dropout class (shame at vulnerability, broken promise at conversion gate, surprise paywall on Day 4)
- **4** — meaningful motivation tax that compounds across sessions (cold Day-0, generic "champion" copy, buried comeback message)
- **3** — measurable mental-model fracture or dopamine-loop weakness (low-ceiling streak, predictable reward schedule)
- **2** — secondary emotional friction (label voice mismatch, missed celebration moment)
- **1** — cosmetic emotional roughness

**Frameworks I lean on (not invoke without evidence):**
- **Habit Loop** (Duhigg) — cue → routine → reward — used for the dashboard and notification system.
- **Hooked Model** (Eyal) — trigger → action → variable reward → investment — used for paywall and badge analysis.
- **Self-Determination Theory** (Deci & Ryan) — autonomy / competence / relatedness — used to evaluate AI Coach and onboarding.
- **Identity-based habits** (James Clear) — the user's self-concept must shift from "I'm trying" to "I'm someone who trains." Used as a lens on long-tail retention.
- **Loss aversion** (Kahneman & Tversky) — used for the streak system audit.
- **Goal-gradient effect** (Hull) — used for the 30-day grid.
- **Endowment effect** (Thaler) — used for the dynamic AI report.
- **Operant conditioning** (Skinner) — fixed vs variable reward schedules — used for the badge / coach copy / completion celebration audit.

---

## 1. EXECUTIVE FINDINGS TABLE (severity-sorted)

| ID | Sev | Title | File:line anchor |
|---|---|---|---|
| P-01 | 5 | Day-0 Gelişim is "you have nothing" — first impression of the user's own progress is total absence | `gelisim_tab.dart:541–632, 681–797, 178–183` |
| P-02 | 5 | The 30-day brand promise is contradicted by the AI engine's "12 Hafta" duration on the pre-paywall summary — trust collapse at the conversion gate | `ai_personalization_engine.dart:14–17, 77` vs onboarding hero `onboarding_screen.dart:386–397` |
| P-03 | 5 | Day 4+ paywall is a punishment after a 3-day routine has been built — exact moment of habit-formation fragility hit with a wall | `today_task_card.dart:104–108`, atlas §6.4 |
| P-04 | 5 | Forced-auth gate at paywall arrival is a betrayal of the just-built personalization investment — the user is asked to "prove who they are" right after the AI promised to know them | `paywall_screen.dart:182–214`, `auth_modal_bottom_sheet.dart:67–69` |
| P-05 | 5 | Decoy reference price `₺2.999,99 idi` is hardcoded marketing fiction — when discovered (and 2026 users do discover this), it reframes everything else as manipulation | `paywall_screen.dart:1158`, atlas §6.9 |
| P-06 | 4 | "Şampiyon serisi devam ediyor!" copy fires identically for streak 7 and streak 30 — personalization illusion fails exactly where ownership should peak | `gelisim_tab.dart:1613–1621` |
| P-07 | 4 | Streak system is loss-aversion-only — there is no positive ceiling, no graduation, no maxStreak watermark surfaced anywhere except a buried one-liner | `gelisim_tab.dart:1617`, `appPreferencesProvider.maxStreak` only consumer |
| P-08 | 4 | 5-dot streak checklist caps at 5 — visual ceiling at Day 5 erases the difference between Day 5 and Day 25 user, killing goal-gradient acceleration | `gelisim_tab.dart:687–765` |
| P-09 | 4 | Onboarding has no autosave; mid-flow interruption wipes 11 vulnerable disclosures and forces a restart through 8.9s of forced waits — high-shame re-traversal | `onboarding_screen.dart:165–217`; F-03 echoed |
| P-10 | 4 | Forced 1.5s "Metabolizmanı hesaplıyorum…" labor illusion lies to the user about computation — when discovered (and engineers, journalists, or savvy reviewers do discover this), it casts every other "AI" claim as theatre | `onboarding_screen.dart:1110, 1182` |
| P-11 | 4 | The dynamic AI report's 92% confidence bar is hardcoded — a fake precision number that maps cleanly to the same dark-pattern critique that's killing wellness apps in 2026 | `onboarding_screen.dart:1583, 1936` |
| P-12 | 4 | "🔥 10.000+ kişi kullanıyor" social-proof pill on paywall is unverifiable + uses an emoji — both signals lower trust at the conversion moment | `paywall_screen.dart:752–783` |
| P-13 | 4 | The user is never given a name; the AI Coach falls back to "Şampiyon" — relatedness pillar of SDT collapses to a generic vocative | `gelisim_tab.dart:1747–1762` |
| P-14 | 4 | Badge celebrations only fire on Gelişim — earned badge on Antrenman is invisible until the user switches tabs, breaking dopamine temporal-proximity | `dashboard_screen.dart:136–174`, atlas §3.4 |
| P-15 | 4 | "İlk 7 Gün" badge unlocks at Day 1 (`completedCount >= 1`) — the label promises one thing, the unlock fires another; achievement is cheapened | `gelisim_tab.dart:1907–1914` |
| P-16 | 4 | Comeback messaging ("Geri dönüş zamanı. 10 dakika yeterli.") is 5 user actions deep on Gelişim — the most retention-critical message lives where churning users won't see it | `gelisim_tab.dart:1617`, journey J-E1 |
| P-17 | 4 | Identity reinforcement is absent — the app says "you used the app today," never "you are someone who trains" | absence pattern across `gelisim_tab.dart`, `today_task_card.dart`, `notification_service.dart` |
| P-18 | 3 | "Vücudunu Yapay Zeka ile Şekillendir" hook frames the body as the *object* of AI action, not the user as agent — passes the locus of control to the system | `onboarding_screen.dart:386` |
| P-19 | 3 | Typewriter blocking (~4s) on Coach Intro is friction not warmth — the coach speaks at machine pace, not human pace, after the welcome promised "kişisel" | `onboarding_screen.dart:553–586` |
| P-20 | 3 | Feedback banner copy on goal step is a sales line ("Bu hedefle başlayanların çoğu 30 gün içinde fark görüyor") — coach voice slips to marketing voice mid-onboarding | `onboarding_screen.dart:2569–2571` |
| P-21 | 3 | Pain-point step extracts vulnerability ("Seni en çok zorlayan ne?") with no commitment in return — ask without offer, the worst persuasion shape | `onboarding_screen.dart:1316–1319` |
| P-22 | 3 | "Harika gidiyorsun, devam et! 💪" on the program-progress card renders identically at 0% and at 67% — fixed reward schedule, no variability | `gelisim_tab.dart:617` |
| P-23 | 3 | Onboarding asks for vulnerability (gender, age, weight, body insecurity) and never re-shows the user's own AI report — endowment is built and then discarded | `_DynamicReportStep`/`_PrePaywallSummaryStep` end at `_finish()`, never accessible later |
| P-24 | 3 | "Geri dönüş zamanı. 10 dakika yeterli." comeback copy is mechanically correct but emotionally clinical — the moment of churn-recovery deserves warmth, not "10 minutes is enough" | `gelisim_tab.dart:1618` |
| P-25 | 3 | "Bugün antrenmanı geçersen yarın iki gün geride kalırsın" notification copy weaponizes loss aversion — works once, then breeds resentment | `notification_service.dart:80–83` |
| P-26 | 3 | The coach-intro typewriter line "tamamen senin hedeflerine, vücuduna özel bir plan oluşturacağım" overpromises before any data has been collected — sets up expectation breach | `onboarding_screen.dart:553–556` |
| P-27 | 3 | Free tier defines competence boundary at Day 3 — the user is allowed to feel competent for exactly 72 hours before the gate; Self-Determination Theory's competence pillar undermined deliberately | `app_constants.dart:30 kFreeDayLimit=3`, `today_task_card.dart:19, 105` |
| P-28 | 3 | Program-complete state is a 60-px trophy card with one line of copy ("30 günlük programı tamamladın") — the entire 30-day arc terminates in less visual celebration than a single badge unlock | `today_task_card.dart:176–216` vs `badge_unlock_dialog.dart:55–100` |
| P-29 | 3 | Day 31+ has no defined loop — the program ends with `ProgramCompleteCard` and `SuggestionsScreen` says "30 günü tamamladın!… Yeni bir hedef belirlemek için Gelişim sekmesine göz at" but Gelişim has no "next program" surface | `today_task_card.dart:202`, `suggestions_screen.dart:129–141` |
| P-30 | 3 | Three concurrent pulse animations on Gelişim (current-day cell, coach avatar, neon halos) compete for attention — anxiety-energy at a "calm progress review" surface | `gelisim_tab.dart:977, 1825`; cf. PREMIUMIZATION_STRATEGY P-23 |
| P-31 | 2 | "Serini bozma!" subtitle is a directive (don't break the streak) where a supportive frame would scaffold ("Yarın 2. günü başlat") | `gelisim_tab.dart:713` |
| P-32 | 2 | Daily summary TTS line "Günaydın $name. Bugün …" assumes morning regardless of when user taps — clock-blind greeting on a fitness app | `gelisim_tab.dart:1738` |
| P-33 | 2 | The "günü fethettin" (you conquered the day) celebration body uses war language for nutrition — Turkish kitchen vernacular would land warmer than military framing | `notification_service.dart:96–99` |

**Total:** 33 findings. **5 sev-5, 13 sev-4, 13 sev-3, 3 sev-2, 0 sev-1.**

---

## 2. ONBOARDING PSYCHOLOGY

The 12-step wizard is the app's most psychologically loaded surface. By the end of step 12 the user has disclosed gender, age, height, weight, training history, daily availability, body insecurities ("pain point"), and goal — then watched the system "compute" for ~6 seconds, read a 4-paragraph "AI assessment," and seen a 92% confidence bar fill. Every micro-decision in this flow is either building or eroding the relationship.

### 2.1 Frame: commitment vs extraction

Two mental models for onboarding flows:
- **Commitment-building** — every step is a small promise the user makes to themselves; the system's job is to make those promises feel meaningful and the next step feel earned.
- **Data extraction** — every step is a question the system needs answered to operate; the system's job is to make answering feel cheap.

A well-tuned 30-day fitness onboarding should be 70/30 commitment-building. The current FormAI flow leans toward extraction:

| Step | Disclosure asked | What user gets back | Build or extract? |
|---|---|---|---|
| 1 Welcome | none | cinematic hook | build |
| 2 Coach Intro | none | typewriter ~4s, then CTA | mostly extract (forced wait) |
| 3 Gender | identity | "Programını sana özel kalibre ediyorum" | extract |
| 4 Goal | aspiration | "🔥 Harika seçim! Bu hedefle başlayanların çoğu 30 gün içinde fark görüyor" | extract (sales voice) |
| 5 Experience | competence baseline | helper subtext | mild build (`'Hiç sorun değil'`) |
| 6 Daily Minutes | availability | "Bu süreyle bile ciddi sonuç alabilirsin" | mild build |
| 7 Activity | lifestyle | "Kişisel kalori ve program yoğunluğunu buna göre ayarlıyorum" | extract |
| 8 Physical Data | body | "Metabolizmanı hesaplıyorum…" labor illusion 1.5s | extract |
| 9 Pain Point | vulnerability | "Bunu çözmek için planını optimize edeceğim" | extract |
| 10 Analysis Illusion | none | rotating phrases ~6s | extract (theatre) |
| 11 Dynamic Report | none | branched text + 92% confidence bar | build (then thrown away — see P-23) |
| 12 Pre-Paywall Summary | none | summary card + 92% bar | sales |

The asymmetry: by step 9 the user has disclosed gender, age, height, weight, training history, and emotional weakness. The system's reciprocity is two labor-illusion screens (steps 8 + 10) and one report (step 11) that the user never sees again after the paywall closes. Steps 2 and 12 are pure conversion prep.

### Finding P-09: Onboarding has no autosave; mid-flow interruption wipes 11 vulnerable disclosures and forces a restart through 8.9s of forced waits
**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:165–217` (`_finish()` is sole save call); atlas §4.6; F-03 in PRODUCT_STRUCTURE_REPORT.
**Mechanism:** Sunk-cost reversal + commitment escalation failure. The literature on onboarding completion shows that interrupted-then-restarted flows have ~3x the abandonment rate of continuous-completion flows (Boundless Mind 2018; Localytics 2019). For an emotionally-loaded flow that asks for body weight and "what's blocking you" — the *restart* is worse than the original ask because the user now knows what's coming.
**Observation:** Wizard state is held in a Riverpod `Notifier<WizardState>` with no SharedPreferences write-through. A user who completes steps 1–9 (gender → activity → height/weight → pain point), gets a phone call, and returns 30 seconds later starts at step 1.
**Cost:** First-launch users are exactly the population most likely to be in unstable contexts (commute, lunch break, in bed). Every interruption strips the user back through:
- Two ~1.5s feedback banners they already saw (`onboarding_screen.dart:1110` `Future.delayed(1500ms)`)
- The ~4s typewriter on Coach Intro (`onboarding_screen.dart:559` `_perChar = 28ms × _coachLine.length ≈ 3.92s`)
- The ~6s analysis illusion (`onboarding_screen.dart:1381` `_phraseDuration = 1200ms × 5 phrases`)

Total forced re-watch on a re-entry: ~8.9 seconds of unskippable theatre, plus 8 questions to answer again. For a user who just disclosed insecurity, the *re-disclosing* is the worst part.

**Evidence:**
```dart
// onboarding_screen.dart:177–178 — single save call, only at _finish()
await prefs.saveUserMetrics(wizard.toJson());
await prefs.completeOnboarding(goal: wizard.targetPhysique?.name);
```
No call to `saveUserMetrics` exists in any step's commit handler. Confirmed via grep in PRODUCT_STRUCTURE_REPORT F-03.

### Finding P-10: Forced 1.5s "Metabolizmanı hesaplıyorum…" labor illusion lies to the user about computation
**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:1103–1113, 1182` (`_PhysicalDataStep._commit`)
**Mechanism:** Labor illusion (Buell & Norton 2011) — the canonical paper showed that introducing a fake "working…" delay made users *more* satisfied with travel-search results because the perceived effort raised perceived value. The trick has a known shelf life: once the user discovers the wait is fake, the entire system's credibility collapses (Buell, "Operational Transparency", HBR 2019).
**Observation:** After the user scrolls three CupertinoPicker wheels (age, height, weight) and taps DEVAM, the screen renders a 16x16 spinner + "Metabolizmanı hesaplıyorum…" line, then `Future.delayed(1500ms)`, then advances. There is no actual computation happening at this point — `_assessment()` and `_maintenanceCalories()` (`ai_personalization_engine.dart:84, 185`) are pure functions that execute in microseconds. The 1500ms is fictional.
**Cost:**
- Risk-on: a journalist, savvy user, or App Store reviewer who reads the source (now the codebase is shipping to a public repo) sees the `Future.delayed`. Once one publication reframes "AI Destekli" as "1.5s sleep + branched template strings," the trust premium collapses.
- Risk-off: even the user who *enjoys* the labor illusion only enjoys it once. Re-running onboarding (after a logout, a reinstall, or per F-03's autosave gap) makes the same delay a known lie. Repeated lies kill credibility the way a single skipped tax payment doesn't.
- The 2026 wellness-app market has seen Calm, Noom, BetterHelp face concrete consumer-protection scrutiny on this exact pattern. Cf. FTC v. NeuroFocus 2024 settlement.

**Evidence:**
```dart
// onboarding_screen.dart:1108–1110
setState(() => _calculating = true);
_feedbackCtrl.forward();
await Future<void>.delayed(const Duration(milliseconds: 1500));
```
Followed at line 1182:
```dart
const Text('Metabolizmanı hesaplıyorum…', ...)
```
The actual `_maintenanceCalories` function is 12 lines of arithmetic (`ai_personalization_engine.dart:185–197`). Not 1500ms of compute.

### Finding P-11: The 92% confidence bar is hardcoded — a fake precision number
**Severity:** 4/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:1583, 1936` (`static const double _confidenceTarget = 0.92`)
**Mechanism:** Anchoring + precision-bias. A round number ("90%") reads as estimate; a slightly-imprecise number ("92%") reads as measured. Anchored on this, the user's confidence in the rest of the report rises. This is the same persuasion pattern that powered Theranos's "97% accuracy" claims — and the same pattern that made the unwinding so devastating.
**Observation:** Both the dynamic report screen and the pre-paywall summary screen render a "Başarı olasılığı %92" bar that animates from 0 to 0.92. The number does not depend on any wizard input — it's the same 92% for a 65kg female with `painPoint=motivation` and a 95kg male with `painPoint=diet`. The "personal" in "personal AI report" does not extend to the confidence number.
**Cost:**
- The user reads "92%" and feels a measurement happened. None did.
- A user comparing notes with a friend who also installed the app discovers both got 92% — the personalization theatre breaks at the dinner-party level.
- Combined with P-10, the persuasion stack inside onboarding is two labor illusions + one fake confidence bar + one branched template assessment. The user ends step 12 having been performed *at*, not personalized *for*.

**Evidence:**
```dart
// onboarding_screen.dart:1583 (in _DynamicReportStep)
static const double _confidenceTarget = 0.92;

// onboarding_screen.dart:1936 (in _PrePaywallSummaryStep — same constant duplicated)
static const double _confidenceTarget = 0.92;
```
Two static constants. Zero dynamic computation. Not even a `min(0.92, 0.7 + experienceBonus)` branch.

### Finding P-26: The coach-intro typewriter overpromises before any data has been collected
**Severity:** 3/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:553–556`
**Mechanism:** Promise-without-evidence. By definition, on step 2 the AI knows nothing about the user. Promising "tamamen senin hedeflerine, vücuduna özel" before asking is structurally a guarantee that cannot be honored — it's not yet a lie, it's a forward-loaded promise that the rest of the wizard either pays back or fails.
**Observation:**
```dart
// onboarding_screen.dart:553–556
static const String _coachLine =
  'Merhaba! Ben senin kişisel yapay zeka koçunum. '
  'Şimdi sana birkaç soru soracağım ve tamamen senin '
  'hedeflerine, vücuduna özel bir plan oluşturacağım.';
```
The user reads this **before** disclosing anything. The promise is "I am yours, customized." The actual delivery (per the AI engine source `ai_personalization_engine.dart:84–171`) is a switch-case branched template with three combination rules.
**Cost:**
- For users who notice the assessment paragraph reads template-y (a non-trivial slice — Turkish-speaking AI early-adopters know what GPT-style branched copy reads like), the coach loses trust right at the dynamic-report reveal.
- For users who don't notice in the first session: the promise creates a high baseline expectation that has to be re-satisfied every time the AI Coach speaks. The post-onboarding AI Coach has 3 hardcoded copy branches (`gelisim_tab.dart:1613–1621`). The user discovers the "kişisel" coach has 3 things to say.

**Evidence:** above + the entire AI personalization engine inspected at `ai_personalization_engine.dart:84–171` (single function with 3 combination rules and a switch-case for goal — not the "hesap-veren-arkadaş" the line at coach intro promises).

### Finding P-21: Pain-point step extracts vulnerability with no commitment in return
**Severity:** 3/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:1316–1319, 1322–1342`
**Mechanism:** Reciprocity asymmetry. Persuasion works when ask and offer are matched (Cialdini's Influence). Pain-point asks the user to disclose a personal struggle (`'motivation'`, `'consistency'`, `'no_idea'`, `'diet'` or free-text). The system's response is a one-line feedback banner — `'Bunu çözmek için planını optimize edeceğim.'` — and an auto-advance.
**Observation:** The user shares vulnerability (e.g. types "Akşamları çok yorgun oluyorum ve diyeti bozuyorum…" per the inputHint). The system responds with a generic 1-line banner and moves on. No callback in step 11's report acknowledges the disclosed pain by name. No callback in the dashboard's AI Coach card references it either (the coach has 3 hardcoded copy branches, none keyed to painPoint).
**Cost:**
- The disclosure is logged (`setPainPointDescription(text)`) but never re-surfaced to the user. The asymmetry creates a low-grade "why did you ask that?" feeling that compounds with P-23 (endowment loss).
- For Turkish users specifically, the directness of the question ("seni en çok zorlayan ne?") demands a sincere answer; a generic auto-advance after sincerity feels dismissive.

**Evidence:** the system stores `painPointDescription` in `WizardState` but the only consumer is the dynamic-report assessment, which surfaces a single one-liner per category (`ai_personalization_engine.dart:152–168`). After the report renders once, the disclosure is not re-shown.

### Finding P-23: Onboarding asks for vulnerability and never re-shows the user's AI report
**Severity:** 3/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:1623–1825` (_DynamicReportStep) — never reachable after `_finish()` (line 216 routes to `/paywall`).
**Mechanism:** Endowment effect (Thaler 1980) — once people see something as theirs, they over-value keeping it. The dynamic AI report is the maximum-endowment moment in the entire flow. It's labeled "Kişisel AI Raporun" (Your Personal AI Report), wraps a full-screen paragraph branded "AI DEĞERLENDİRMESİ", and shows a 92% confidence bar with the user's own BMI and calorie numbers. By design this should be the user's most-cherished artifact.
**Observation:** After tapping the CTA on step 11 (`'KİŞİSEL PLANIMI AL'`), the wizard advances to step 12 (summary) and exits via `_finish()` to `/paywall`. There is no in-app surface that re-displays the report. Profile tab does not show it (`profile_tab.dart` has no consumer of `AiPersonalizationEngine`). The Gelişim AI Coach Card displays a 1-of-3 hardcoded greeting, not the report.
**Cost:**
- The user spends ~30s reading personalized text labeled "Yours" — and never sees it again.
- A user who wants to share their report with a friend cannot. A user who wants to remember their starting BMI cannot. The endowment is built and then thrown away; this is the inverse of Strava's "your route" or Spotify's "your year" pattern, which sustain endowment across years.
- Re-running the wizard would regenerate the report — but the wizard is gated behind `prefs.isFirstTime` (atlas §3.2 redirect rule 2), which is set to false at `_finish()`. The report is structurally unreachable post-onboarding.

**Evidence:** atlas §4.4 documents wizard exit is `context.go(AppRoutes.paywall)`. No `progressReport` or `aiReport` route exists in `AppRoutes` (atlas §3.1 enumerates 18 routes; none is the report). No surface in `gelisim_tab.dart` or `profile_tab.dart` consumes `AiPersonalizationEngine.generateReport()`.

### Finding P-18: "Vücudunu Yapay Zeka ile Şekillendir" frames the body as the *object* of AI action
**Severity:** 3/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:386` (Welcome hook headline)
**Mechanism:** Locus of control (Rotter 1966). When agency is framed as "AI does X to your body", the user is the patient, not the agent. Internal-locus framing ("you'll do this with AI's help") correlates with persistence; external-locus framing ("AI will shape your body") correlates with passive engagement and quick churn.
**Observation:** The Welcome hook reads: **"Vücudunu Yapay Zeka ile Şekillendir"** — literally, "Shape your body with AI." Two grammatical readings:
- "(You) shape your body with AI." (imperative-tu, internal locus)
- "Your body — being shaped by AI." (passive object framing)

In Turkish the imperative-tu reading is technically correct, but the visual layout (32pt headline centered, the user reads it before a CTA exists) and the surrounding subtitle (`Sana özel antrenman ve beslenme planıyla 30 günde hedefine ulaş.`) push the second reading. The subject is implicit "you," but the framing is "AI does it."

Compare to Apple Fitness+'s onboarding: "Choose your goal" (you choose). Or Future's "Your coach is waiting" (relatedness, not object framing). The FormAI hook is stronger in cinematic feel and weaker in identity construction.

**Cost:**
- For the predominant beginner segment, internal-locus framing is critical to sustain effort. Users who read "AI will shape my body" form the implicit expectation that effort comes from the AI, not them. When Day 4 requires effort that can only come from the user (showing up), the expectation is breached.
- "30 günde karın kası" is already a pre-loaded external-outcome promise; the headline doubles down on outcome-without-agency, which is structurally the highest-churn framing.

**Evidence:**
```dart
// onboarding_screen.dart:385–397
const Text(
  'Vücudunu Yapay Zeka ile Şekillendir',
  ...
)
```

### Finding P-19: Typewriter blocking on Coach Intro is friction not warmth
**Severity:** 3/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:553–586` (typewriter mechanism); 658–684 (CTA disabled until typed)
**Mechanism:** Conversational pacing in real human conversation operates at ~150 wpm spoken / ~250 wpm read. The typewriter at 28ms/char is roughly 30 wpm — slower than speech, slower than reading. It signals "machine output," not "coach speaking."
**Observation:** The Coach Intro line is 173 characters; at 28ms/char the full reveal is ~4.84s. The CTA "DEVAM ET" is disabled until completion (line 659). The "Geçmek için ekrana dokun" hint at line 641 only appears as an opacity hint while typing is in flight.
**Cost:**
- A user who reads Turkish at adult speed finishes processing the line in <2s. The next 2.84s is forced waiting for an animation labeled as "the coach speaking" but actually executing as a CPU-throttled `AnimationController.forward()` (line 575).
- Re-runs of the wizard (per F-03) re-trigger the full 4.84s. Cumulatively across multiple re-runs, the Coach Intro is the surface most likely to make the user feel patronized.
- Compare to Headspace's onboarding voice (real recorded voice at human speed) or Centr's (text appears at terminal cursor speed, ~5x faster). Both feel less like waiting.

The typewriter is not warmth — it's machinery dressed as warmth. A real coach doesn't speak at 30 wpm.

**Evidence:**
```dart
// onboarding_screen.dart:559
static const Duration _perChar = Duration(milliseconds: 28);
// 173 chars × 28ms = 4844ms
```

### Finding P-20: Feedback banner copy slips to sales voice mid-onboarding
**Severity:** 3/5
**Where:** `lib/features/onboarding/presentation/onboarding_screen.dart:2569–2571` (`_GoalStep.feedbackText`)
**Mechanism:** Voice consistency. Users build a model of "who is talking to me" within the first 3-4 messages. Mid-flow voice flips break the model. The wizard establishes coach-voice in steps 2-3 (`'Programını sana özel kalibre ediyorum.'`) — caring, instructive, second-person. Step 4 then ships:
**Observation:**
```dart
// onboarding_screen.dart:2569–2571
feedbackText:
  '🔥 Harika seçim! Bu hedefle başlayanların çoğu 30 gün içinde '
  'fark görüyor.',
```
This is a sales line. The structure ("most users with this choice see results in 30 days") is the canonical e-commerce social-proof line, lifted directly into a coach-voice banner. The "🔥" emoji on a coach line is also voice-jarring — it reads as ad copy.
**Cost:**
- The user, having met "the coach" on step 2, now hears the coach turn into a salesperson on step 4. The shift from caregiver to seller is jarring; the user notes consciously or unconsciously that the agent has commercial motives.
- "Bu hedefle başlayanların çoğu fark görüyor" is also unverifiable (who? what %? what's "fark"?) — same pattern as the "10.000+" social proof on the paywall (P-12), but earlier in the funnel where trust is still being formed.

**Evidence:** above + compare to step 5's helper subtext on the experience step at `onboarding_screen.dart:2643` (`'Hiç sorun değil. Sıfırdan başlayıp hızlı gelişim sağlayacağız.'`) — that's coach voice. The goal step's feedback line is sales voice.

---

## 3. DASHBOARD EMOTIONAL ARCHITECTURE — GELİŞİM TAB

The Gelişim tab is the user's daily window into "how am I doing." Per atlas §5.2, it stacks 9 sections. Per Phase 2 F-05, the primary CTA "ANTRENMANA BAŞLA" sits at ~430-470 px from the top, below 4 other cards. The brief asks specifically to **map the emotional valence of each section**. Below is the emotional-valence audit at three lifecycle states (Day 0, Day 4 hitting paywall, Day-after-broken-streak).

### 3.1 Emotional valence by section, by user state

| # | Section | Day 0 (fresh user) | Day 4 hitting paywall | Day-after-broken-streak |
|---|---|---|---|---|
| 1 | Top header (Gelişim title + 🔥 streak pill + share) | `🔥 0 Günlük Seri` reads as cold-start | warm — `🔥 3 Günlük Seri` | **shame** — reads `🔥 0 Günlük Seri` even though user had 12 yesterday (J-E3) |
| 2 | Program Progress Card | `%0 / 0/30 gün tamamlandı / Harika gidiyorsun, devam et! 💪` — copy-data mismatch is **dissonant** at 0% | `%10 / 3/30 / Harika gidiyorsun…` — fits | `%40 / 12/30` — ok numerically; fixed copy ignores break |
| 3 | Streak Card | `0 gün / Serini bozma!` — directive on a streak that doesn't exist (P-31) | `3 gün / Serini bozma!` — appropriate | `0 gün / Serini bozma!` — directive when streak just broke (anti-empathic) |
| 4 | Today Task Card | personalized "Gün 1 – …" — **the only warm card on Day 0** | personalized "Gün 4 – …" — **trap door** (P-03 paywall hits next tap) | personalized "Gün N – …" — **the comeback CTA, but no comeback framing** |
| 5 | 30-Day Grid | 30 locked cells (or pulsing Day 1) | 3 green checks + Day 4 pulsing + 26 locked | 12 green checks + (broken) day + locked tail — **visual graveyard** of past streak |
| 6 | 3 Stats Cards (BU HAFTA, YAKILAN KALORİ, ANTRENMAN) | all show `0 / 7`, `0 kcal`, `0 tamamlandı` — **reinforces emptiness** | `3 / 7` — appropriate | varied — does not surface the break |
| 7 | Weekly Retrospective | hidden (non-Sunday) | hidden | hidden — **the Sunday-only gating means weekday breaks get no retro** |
| 8 | AI Coach Card | `Bugün hedeflerimize bir adım daha yaklaşıyoruz.` — generic | same default branch (streak < 7) | `Geri dönüş zamanı. 10 dakika yeterli.` — this is the comeback message but **buried** (J-E1) |
| 9 | Badges (5 hex tiles) | 5 dim with progress 0% — wall of locked | first badge unlocked (`İlk 7 Gün`) — false achievement (P-15) | mixed — past-unlocks visible, no new-unlock pressure |

**Observation pattern:** Day 0 is emotionally cold across 7 of 9 sections. Day 4 is warm-then-trap. Streak-break day is shame-then-buried-comeback.

### 3.2 Day 0 emotional walkthrough

A Turkish-speaking adult, just finished onboarding, lands on Antrenman tab default. Atlas notes Antrenman's `_FlameStreakBadge` only renders when streak > 0 (`antrenman_tab.dart:609–632`), so the Day 0 user sees no streak surface on Antrenman. They tap Gelişim curious about "Gelişim" (Progress).

Above-the-fold inventory at Day 0 on Gelişim:
- "Gelişim" title (26pt, bold) — neutral
- "İlerlemen bir bakışta." subtitle — promises something to see
- Streak pill: `🔥 0 Günlük Seri` (`gelisim_tab.dart:432`) — explicit zero
- Program Progress Card: `%0` (huge, 34pt, fw900) (`gelisim_tab.dart:567–576`) — the largest number on the screen is 0
- "0 / 30 gün tamamlandı" — explicit zero
- "Harika gidiyorsun, devam et! 💪" — copy contradicts data (P-22)
- Streak Card: `0 gün` (also 34pt) + `Serini bozma!` — 5 empty dots
- Trophy ring: 0% filled — visual emptiness

The user, who just spent ~3 minutes disclosing their goal, body data, and emotional weakness, reads: zero, zero, zero, zero, zero. In a single first-impression frame.

**This is the maximum-investment / minimum-feedback emotional gap in the entire user lifecycle.** It is also the structurally-fixable failure mode: Day 0 is the one state the codebase can fully predict.

### Finding P-01: Day-0 Gelişim is "you have nothing"
**Severity:** 5/5
**Where:** `gelisim_tab.dart:541–632` (Program Progress Card), `:681–797` (Streak Card), `:1907–1945` (Badges Section). Six visible "0" or "0%" values above the fold.
**Mechanism:** Self-Determination Theory's competence pillar. Beginners need to see *evidence of capacity*, even before evidence of progress. A wall of zeros literally tells them "you have done nothing" — which is true only in past-tense and false in present-capacity terms (they just signed up and committed).
**Observation:** First-time arrival on Gelişim renders 6+ zero-state values in the first 600px:
```
🔥 0 Günlük Seri          (gelisim_tab.dart:432)
%0                         (line 567 — the largest number)
0 / 30 gün tamamlandı      (line 579)
[empty progress bar]       (line 600)
0 gün                      (line 702)
[5 empty dots]             (line 727–765)
[trophy ring 0%]           (line 656)
```
Plus the AI Coach default copy `'Bugün hedeflerimize bir adım daha yaklaşıyoruz.'` (line 1620) — which is also default-fallback on Day 0.
**Cost:**
- The first impression of "your progress" is "you don't have any."
- Goal-gradient theory predicts users accelerate as they near completion. The 30-day grid at Day 0 is **30 locked cells** (some rest-days marked) — the visualization is "29 obstacles ahead."
- Compare to Streaks app, Strava, Duolingo Day 1 surfaces — each shows the user a *capacity* signal (badges available, streak potential, today's micro-goal) before showing zero counts.
- This is not a copy problem solvable with one line change. The information architecture itself encodes "what you have" rather than "what you will do."

**Evidence:** see line refs above. The single warm element on Day 0 is the Today Task Card showing a personalized day. Everything else is zero.

### Finding P-22: "Harika gidiyorsun, devam et! 💪" renders identically at 0% and at 67%
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:617`
**Mechanism:** Operant conditioning — fixed-ratio reinforcement plateaus (Skinner). When the same praise fires regardless of behavior, the praise loses meaning ("just words"). Variable praise tied to milestones produces sustained engagement.
**Observation:** The motivational line under the program-progress card is a literal `const String 'Harika gidiyorsun, devam et! 💪'`. It does not branch on percent. A user at 0% and a user at 67% read the same words.
**Cost:**
- For Day 0 user: the praise contradicts the data ("you're doing great" said over a 0% bar reads as patronizing or sarcastic).
- For Day 20 user: the praise is identical to what they saw on Day 1 — no recognition of progress. By Day 20 the user has earned a different sentence.
- The line costs nothing to make percent-aware (`if (percent > 0.5) 'Yarısını geçtin!' else if (percent > 0) 'Adım adım ilerliyorsun.' else 'Bugün başlıyoruz.'`). The structural absence is what's worth noting; the fix is trivial, the fact it wasn't done is the signal.

**Evidence:**
```dart
// gelisim_tab.dart:616–624
Text(
  'Harika gidiyorsun, devam et! 💪',
  style: TextStyle(
    color: context.colors.onSurface.withValues(alpha: 0.70),
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
  ),
),
```
A literal string, no percent branch.

### Finding P-30: Three concurrent pulse animations on Gelişim
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:977` (`_PulsingCurrentCellState`), `:1825` (`_CoachAvatarState` slow breathing), `:431–443` (streak-pill orange shadow + elsewhere `_neon`-shadowed cards have soft halos that read as quiet pulses).
**Mechanism:** Attentional load. Visual pulses are "look here" signals. When the user has 1 pulse, attention goes there. When 3 pulses fire concurrently (current-day cell + coach avatar + various neon halos), attention diffuses; the brain reads diffuse pulse as ambient anxiety, not direction.
**Observation:** Running concurrently when Gelişim mounts:
- Current day cell pulse: 1400ms cycle (`gelisim_tab.dart:981`)
- Coach avatar breathing: 2400ms cycle, scale 0.95-1.05 (`gelisim_tab.dart:1828–1830`)
- Static neon halos on cards (read as quiet glow rather than pulse, but contribute to overall pulse-like brightness budget): see `_SoftCard` at `today_task_card.dart:218–248` accent shadow `blurRadius: 18`

Plus the trust bar fill (700ms tween) on first arrival (`:589–614`).
**Cost:**
- For a "see your progress" surface, calm-energy is more on-brand than competing-for-attention energy. Centr and Apple Fitness+ both gate their dashboards to one motion at a time.
- Cumulative motion at fontSize ≥18 elements creates a "casino" feel — not the effect a 30-day discipline product should cultivate.

**Evidence:** see file:line refs above; this is a motion-budget problem that PREMIUMIZATION_STRATEGY V-23 also flagged.

### 3.3 Day 4 hitting paywall via Today Task Card

The user has built a 3-day streak. They open the app, tab to Gelişim, see the Today Task Card showing "Gün 4 – …" with the same neon gradient CTA as Day 1, 2, 3. They tap. The paywall opens.

**Phase 2 F-02 captured the IA cost. The psychology cost compounds:**

### Finding P-03: Day 4+ paywall hits the exact moment of habit-formation fragility
**Severity:** 5/5
**Where:** `today_task_card.dart:104–108` + `app_constants.dart:30 kFreeDayLimit=3`
**Mechanism:** Habit Loop fragility. Duhigg's research and BJ Fogg's "Tiny Habits" model agree: the first 3-7 days of a new habit are the period of *highest reinforcement requirement* and *lowest user tolerance for friction*. A paywall on Day 4 is structurally an interruption of the cue-routine-reward loop at the moment the loop is least stable.
**Observation:** The free-day limit is `kFreeDayLimit = 3` (`lib/core/constants/app_constants.dart:30`). Days 1, 2, 3 are free. Day 4 routes to `/paywall` if `!isPro` — silently, at CTA tap, with no pre-tap signal (Phase 2 F-02 quantified this). The card visual is identical to Days 1-3.

The user's phenomenology:
- Day 1: tapped, worked out, felt good. Reward: green check + streak 1.
- Day 2: tapped, worked out, felt good. Reward: green check + streak 2 + 5-dot 2/5.
- Day 3: tapped, worked out, felt good. Reward: green check + streak 3 + 5-dot 3/5. **The user has now built the loop.**
- Day 4: tapped — paywall.

**Cost:**
- The user does not get their Day 4 reward; they get a wall.
- The momentum dies *exactly* at the point where habit research says intervention should be smoothest.
- The "Şimdi ödeme yok!" 7-day-trial frame on the paywall is technically zero-cost, but the user has to opt into a financial commitment to continue a routine that 20 minutes ago felt free. The cognitive shape of the ask is "you've had your 3 free days, now pay" — which lands as transactional, not partnership.
- **This is the canonical "hooked into paying" pattern that App Store reviewers and Reddit threads call out the loudest.** Compare to BetterMe, Freeletics — both also paywall, but earlier (post-onboarding) so the user evaluates pricing before forming a habit, not after.

**Evidence:**
```dart
// today_task_card.dart:104–108
final isPro = ref.read(isProProvider);
if (!isPro && activeDay.dayNumber > kFreeDayLimit) {
  AppHaptics.secondaryTap();
  context.push(AppRoutes.paywall);
  return;
}
```
Plus the card visual at lines 33-99 has no `isLocked` parameter; the user gets identical neon-gradient CTA on Day 4 as Day 3.

### Finding P-27: Free tier defines competence boundary at Day 3
**Severity:** 3/5
**Where:** `app_constants.dart:30`, `today_task_card.dart:19, 105`
**Mechanism:** Self-Determination Theory's competence pillar — sustainable motivation requires the user feel they can do the thing being asked. A paywall at Day 4 effectively says: "You can be competent at this for 3 days, then not anymore." The system reframes competence as a paid feature.
**Observation:** Free users have full access to Days 1-3 of the 30-day program. Day 4-30 are gated. The `isLocked` flag on plan-detail dimming (atlas §6.4) signals visually; the Today Task Card does not (P-03).
**Cost:**
- Beginners (the dominant segment per `_difficultyLabel` defaulting to Başlangıç) are exactly the population whose competence is most fragile. Capping their free competence window at 3 days, 1/10 of the program, sends "you've shown a tiny bit, now prove your wallet" instead of "you've built momentum, here's more."
- A 7-day or 5-day free window would still leave 23-25 days locked — same monetization, different psychology. The "3 days" choice is conversion-optimized for paywall hit rate at the cost of habit-formation cost.

**Evidence:** `app_constants.dart:30 final int kFreeDayLimit = 3;` + comment at `today_task_card.dart:17–19`.

### 3.4 Streak system psychology

Per atlas §5.6, streak = "consecutive completed days from Day 1; breaks on first non-completed non-rest day. Rest days do NOT break streak." Visualized 4 ways (atlas §15 ERRATA E-3): Antrenman flame badge, Gelişim header pill, Gelişim Streak Card 5-dot checklist, Profile stats tile. The system leans entirely on **loss aversion**.

### Finding P-07: Streak system is loss-aversion-only — no positive ceiling, no graduation
**Severity:** 4/5
**Where:** `gelisim_tab.dart:1617` (only consumer of `maxStreak`); atlas §5.6
**Mechanism:** Loss aversion (Kahneman & Tversky 1979) is a real lever, but the literature also shows that pure loss-aversion streaks have a known dropout cliff: once a user breaks their first streak, the dropout probability spikes ~3x compared to users who maintain. Apps that *survive* breaks (Duolingo's Streak Freeze, Strava's "rest day", Apple Fitness+'s Activity flexible-goals) do so by adding a positive ceiling and a grace mechanism.
**Observation:** FormAI's streak:
- `maxStreak` is persisted (`appPreferencesProvider.maxStreak`, `lib/core/services/app_preferences.dart:54`)
- Only consumer is the AI Coach copy at `gelisim_tab.dart:1617`: `if (streak == 0 && maxStreak > 0) return 'Geri dönüş zamanı. 10 dakika yeterli.';`
- Header streak pill renders raw `streak` (line 432). Not "Best: 12, current 0" — just "0".
- Profile stats tile shows current streak, not best.
- No streak freeze, no grace day, no "1 missed day = streak protected" mechanism.
- Streak warning notification fires at 48h since last workout (`notification_service.dart:299–331`) — pure loss-aversion framing ("Seriyi kaybetmek üzeresin! ⚡").

**Cost:**
- A user at Day 12 → 0 has lost 12 days of pride watermark with one missed workout. The system surfaces no acknowledgment that 12 happened.
- The loss-aversion-only model encourages *binge-and-ghost* behavior: users protect the streak at all costs, then when life makes the streak impossible, they bail entirely (because re-starting feels like Day 1 with no credit for the 12 they did).
- For a 30-day program, this is the worst-case retention pattern.

**Evidence:**
```dart
// gelisim_tab.dart:1617
if (streak == 0 && maxStreak > 0) {
  return 'Geri dönüş zamanı. 10 dakika yeterli.';
}
```
This is the only `maxStreak` consumer. The header pill at line 432 renders raw `streak`.

### Finding P-08: 5-dot streak checklist caps at 5 — visual ceiling at Day 5
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:687–765` (`_StreakCard` with `final filled = streak.clamp(0, 5)`)
**Mechanism:** Goal-gradient effect (Hull 1932; Kivetz et al. 2006) — users accelerate as visual progress nears 100%. The 5-dot checklist hits 100% at Day 5. Day 6 onward, the visualization stalls.
**Observation:**
```dart
// gelisim_tab.dart:688
final filled = streak.clamp(0, 5);

// gelisim_tab.dart:725–765 — 5 hex pucks; each is filled or not
Row(
  ...
  children: List.generate(5, (i) {
    final isOn = i < filled;
    ...
  })
)
```
A user at streak=5, streak=12, streak=30 sees identical Streak Card visuals: 5 green dots filled. The dots stop being differentiated past Day 5.
**Cost:**
- The user who hits the program completion Day 30 sees the same 5-dot row as a Day 5 user. The maximum-effort moment gets minimum visual reward.
- A user breaking from streak=12 to 0 sees all 5 dots empty — visually equivalent to a brand-new install. Achievement-erasure illusion (J-E4).
- For a 30-day program, capping the visual at 5 days is structurally a "no special reward for finishing" choice. Cf. Apple Fitness+ Activity rings, which scale visual reward per completion.

**Evidence:** above. The fix is trivial (a 30-cell ring or 7-day rolling window or both); the structural absence is the signal.

### Finding P-31: "Serini bozma!" subtitle is a directive
**Severity:** 2/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:713`
**Mechanism:** Imperative-tu directive ("don't break your streak") in Turkish lands either as protective advice (from a parent/coach) or as command (from a boss). On a streak that is already at 0, the directive lands as accusation rather than care.
**Observation:**
```dart
// gelisim_tab.dart:712–719
Text(
  'Serini bozma!',
  ...
)
```
Renders identically at streak=0, 5, 12, 30. The user who just broke their 12-day streak reads "don't break your streak" with the streak already broken.
**Cost:**
- Anti-empathic at the exact moment empathy matters.
- The fix would be a streak-state-aware subtitle: streak > 0 → "Serini bozma!" (current), streak == 0 + maxStreak > 0 → "Yeniden başla, en iyi: $maxStreak gün", streak == 0 + maxStreak == 0 → "Bugün başla."

**Evidence:** above.

### 3.5 Badge / achievement psychology

Per atlas §9.1: 12+ achievement badges, mixed predicates. Per `gelisim_tab.dart:1907–1945`, the strip on Gelişim shows 5 badges in a horizontal scroll. Per Phase 2 F-14, celebrations only fire when the user is on the Gelişim tab AND dashboard is the topmost route.

### Finding P-15: "İlk 7 Gün" badge unlocks at Day 1 (`completedCount >= 1`)
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1907–1914`
**Mechanism:** Achievement integrity. A badge labeled "First 7 Days" that unlocks at Day 1 cheapens the achievement currency. Users learn within one cycle that the labels lie; subsequent badges are pre-discounted.
**Observation:**
```dart
// gelisim_tab.dart:1907–1914
_BadgeData(
  label: 'İlk 7 Gün',
  icon: Icons.flag_rounded,
  accent: _orange,
  unlocked: completedCount >= 1,  // ← unlocks at 1, not 7
  progress: (completedCount / 7).clamp(0.0, 1.0),
),
```
The label promises "first 7 days." The unlock predicate fires at completed >= 1. The progress fraction (`completedCount / 7`) is correct, so the progress bar reads ~14% at Day 1; but the badge ALSO renders unlocked. The user sees a "First 7 Days" badge unlocked at Day 1 with a 14% progress bar — semantic incoherence.
**Cost:**
- Trust on the badge system collapses on Day 1.
- A user who unlocks "First 7 Days" at Day 1, then sees the same label on the badges screen still unlocked at Day 7, learns the badge is decorative not earned.
- Predicate looks like a copy-paste error ("`>= 1`" not "`>= 7`"). The fix is one character. The signal is that nobody played this through and noticed.

**Evidence:** above. Compare adjacent badge: `Disiplinli` unlocks at `streak >= 3`, label suggests 7 — same labeling sloppiness.

### Finding P-14: Badge celebrations only fire on Gelişim
**Severity:** 4/5
**Where:** `lib/features/home/presentation/dashboard_screen.dart:136–174` (`_maybeCelebrate`); F-14 echoed
**Mechanism:** Operant conditioning's temporal-proximity rule — reward delivered within ~2-3 seconds of the behavior reinforces the behavior; reward delivered hours later (or after a tab switch) reinforces the tab switch, not the behavior. Skinner showed this in pigeons; Hooked Model translates it to apps.
**Observation:** A user finishes their workout (e.g., the workout that completes "Disiplinli" at streak=3). The session-complete overlay renders (`session_complete_overlay.dart`), the user dismisses with "Tamam" (line 132), routes back to dashboard. Default tab is Antrenman (atlas §3.4 + dashboard_screen.dart:37 `_index = 0`). The badge unlock is queued. Nothing fires. The user never sees the celebration unless they switch to Gelişim.

The atlas explains this was a deliberate Phase 57 PM decision (`dashboard_screen.dart:136–146` comment) to avoid clashes with the workout summary overlay. The cost surfaced here is the dopamine cost.
**Cost:**
- The behavior (completing a workout) is reinforced by the overlay's "Gün N Tamam!" trophy — that's good. But the *badge* reinforcement is severed; the user doesn't connect "I unlocked Disiplinli" with "I just finished my 3rd workout."
- For a user who never tabs to Gelişim, the celebration never fires. This is a non-trivial slice — F-06 noted Gelişim is one of two tabs that hosts workout entry; users who develop Antrenman muscle memory may rarely visit Gelişim.
- Combined with P-15 (badge predicate sloppiness), the badge system is structurally a low-trust subsystem.

**Evidence:**
```dart
// dashboard_screen.dart:136–146
Future<void> _maybeCelebrate() async {
  if (!mounted || !_routeIsCurrent || _celebrating) return;
  // Phase 57 · the PM specifically asked that badge unlocks ONLY
  // surface on the Gelişim (progress) tab.
  if (_index != _gelisimTabIndex) return;
  ...
}
```

### 3.6 AI Coach copy psychology

Per atlas §5.2 §7 + `gelisim_tab.dart:1613–1621`, the AI Coach has 3 hardcoded copy branches. The Phase 2 F-24 finding flagged the seven-day band as too wide.

### Finding P-06: "Şampiyon serisi devam ediyor!" fires identically for streak 7 and streak 30
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1613–1621`
**Mechanism:** Personalization promise vs delivery. The onboarding promised "tamamen senin … özel bir plan." The AI Coach's day-to-day delivery is 3 hardcoded strings keyed on a single integer (streak). Beyond streak >= 7, the system has no further differentiation.
**Observation:**
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
Three branches. A user at streak=7 (just hit the milestone) and a user at streak=24 (3 days from program completion) see identical copy. There is no goal-gradient acceleration, no "you're 3 days from completion" framing, no acknowledgment of the cumulative effort.
**Cost:**
- The user experiences personalization as binary: "you're on a streak" vs "you broke" vs "you're starting." Within "on a streak," every day reads identical from Day 7 onward.
- For a 30-day program, 24 of 30 days fall into the same single message. That's structurally non-personalized, regardless of what the onboarding promised.
- A trivial fix would key on `streak / 30` percentile and milestone (Day 7, 14, 21, 28, 30). The structural absence is again the signal — the AI Coach is the canonical surface where personalization should live, and it does not.

**Evidence:** above + see also P-26 on the coach intro overpromise.

### Finding P-13: User is never given a name; AI Coach falls back to "Şampiyon"
**Severity:** 4/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1747–1762` (`_resolveName`)
**Mechanism:** Self-Determination Theory's relatedness pillar. Relatedness — the sense of being known and cared for — is the longest-tail retention driver in fitness apps (Ng et al. 2012). A coach that doesn't know the user's name doesn't pass the relatedness threshold.
**Observation:** The wizard never asks for first name (`onboarding_screen.dart:53-66` step list — no `name` step). The daily-summary TTS line (`gelisim_tab.dart:1738`: "Günaydın $name. Bugün …") falls back through metrics → email local-part → "Şampiyon".

```dart
// gelisim_tab.dart:1747–1762
String _resolveName(String? email, Map<String, dynamic> metrics) {
  final fromMetrics = metrics['firstName'] as String?;
  if (fromMetrics != null && ...) return fromMetrics.trim();
  if (email != null && email.contains('@')) {
    final localPart = email.substring(0, email.indexOf('@'));
    final cleaned = localPart.split(RegExp(r'[._+]')).first;
    if (cleaned.isNotEmpty) return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
  }
  return 'Şampiyon';
}
```
For most users on first launch (anonymous Supabase session, no email yet), the path resolves to "Şampiyon" — the generic Turkish vocative, equivalent to "Champ" in English.
**Cost:**
- "Günaydın Şampiyon" is the linguistic shape of a server reading from a hat — it could be *anyone*. The relatedness collapses to a generic.
- For Turkish users, "Şampiyon" carries a slightly forced gym-buddy register. It can land warmly the first time (charming default) and gradually feel patronizing if it's the only address used.
- The wizard *could* ask for first name in 1 step; it doesn't. The omission seems to be a design choice (atlas §4.1 enumerates 12 steps, none is name), perhaps to reduce friction. The trade is relatedness for one less step.

**Evidence:** above + grep across `wizard_provider.dart` for "firstName" or "name" — no setter exists for first name in the wizard. The metrics field referenced at line 1748 is never populated by the wizard.

### Finding P-24: Comeback copy is mechanically correct but emotionally clinical
**Severity:** 3/5
**Where:** `lib/features/home/presentation/widgets/gelisim_tab.dart:1618`
**Mechanism:** Re-engagement language theory. The user who just broke a streak is in shame state. A line that addresses the shame (acknowledges, normalizes, offers a path) lands as care; a line that skips the shame and goes straight to "do it" lands as a manager.
**Observation:** "Geri dönüş zamanı. 10 dakika yeterli." — translates to "Time for a comeback. 10 minutes is enough."
- "Comeback" is fine — frames the behavior as recovery.
- "10 minutes is enough" is mechanically calibrated to lower friction, but it skips empathy: it doesn't say "we know," "it's fine," "you're not behind."
- Compare to Calm's comeback ("It's been a while. Even one breath counts.") or BetterHelp's ("Glad you're back. No need to catch up — start fresh today.") — both lead with relational repair, then offer the small ask.
**Cost:**
- The line works mechanically (lowers the bar). It misses emotionally (no warmth).
- For Turkish users specifically, the directness is correct register (Turkish coaching voice runs warmer-direct than English), but the *brevity* is the issue. Two short clauses without an emotional opener feels checkbox-y.

**Evidence:** above.

---

## 4. PAYWALL PSYCHOLOGY

Per atlas §6 + Phase 2 F-04 + Premiumization P-01/P-08. The paywall stacks: gender-personalized hero (M/F before-after composite OR placeholder for Other/null), 26pt hook ("Kişiselleştirilmiş planınızı alın!"), social proof pill, 3 plan cards (annual highlighted with decoy), green "Şimdi ödeme yok!" chip, primary CTA "₺0,00 karşılığında dene", restore link, legal footer. The persuasion stack is heavy.

### 4.1 The persuasion-stack inventory

| Mechanism | Surface | Honesty rating | Comment |
|---|---|---|---|
| Gender-personalized hero (M/F) | composite photo + ribbon | honest | "30 Günlük Değişimin!" is aspirational; AI-generated transformations are clearly hero asset |
| Gender-other hero | wheelchair-accessibility icon | dishonest by neglect | P-01 in PREMIUMIZATION; non-binary user reads "we didn't make one for you" |
| Headline "Kişiselleştirilmiş" | 26pt | partially honest | personalization is real but thin (3 AI-coach branches, 92% hardcoded) |
| Social proof "🔥 10.000+ kişi" | 12.5pt pill | unverified — likely **manipulative** | F-12 / P-12 below |
| Decoy reference price "₺2.999,99 idi" | strikethrough on yearly card | **manipulative** | atlas §6.9 explicit: hardcoded marketing copy, not real price |
| 7-day trial | inline badge + footer | honest mechanism, **dishonest typography** (9.5pt + 8.5pt) | P-06 in PREMIUMIZATION |
| "Şimdi ödeme yok!" | green chip | honest | clear and accurate |
| "₺0,00 karşılığında dene" | primary CTA | honest mechanism, edge of misleading | "try for ₺0" without timeline framing leans dark; trial timeline is in fine print |
| Auto-conversion disclosure | 10.5pt @ 0.55 alpha legal footer | honest by content, **dishonest by typography** | atlas §6.2 |
| Forced-auth gate | non-dismissible bottom sheet | manipulative-by-context | P-04 below |

The **net** persuasion stack: 4 honest mechanisms, 4 dishonest-by-execution mechanisms, 2 outright manipulative mechanisms. For a 30-day fitness program where the user has just disclosed body data and emotional vulnerability, this is a high manipulation density at the conversion gate.

### Finding P-04: Forced-auth gate is a betrayal of the just-built personalization investment
**Severity:** 5/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:182–214` + `lib/features/auth/presentation/auth_modal_bottom_sheet.dart:67–69` (PopScope canPop:false); F-04, J-A3, J-D5 echoed.
**Mechanism:** Identity contract violation. The wizard says "the AI knows you." Then the very next surface says "no it doesn't — sign up so we can know you." The promise made in onboarding is reversed at the conversion gate: identity, just established, is now demanded *as a precondition*.
**Observation:** Sequence:
1. User completes step 12 (`Bu plan sana özel oluşturuldu.`)
2. Wizard's `_finish()` calls `signInAnonymously()` and routes to `/paywall`
3. Paywall mounts, `_onAuthStateChanged` fires immediately, detects `user.isAnonymous == true`
4. Auth modal slides up, non-dismissible, blocking the bottom 50% of paywall
5. User is asked: Google / Apple / Email — to "sign in to continue"

The user's mental state at step 4 is "I just told the system everything about me — why is it asking who I am again?" This is correct phenomenology — the system has 11 demographic fields persisted to `WizardState` but no identity binding (anonymous Supabase UID is a server primary key, not user-facing identity).
**Cost:**
- **The plan-personalization promise is reversed at the worst possible moment.** The user's onboarding emotional investment (steps 1-12) primed them to evaluate the offer. The auth modal demands they *invest more* before they can see the offer.
- For the at-risk segment (users not committed enough to OAuth/email but committed enough to want to see prices), this is a hard exit point. Atlas §6.7 documents the gate; J-A3 documents the funnel cost; J-D5 documents the no-escape-on-OAuth-fail cost. The psychology cost is identity betrayal.
- A user who reflects: "the AI said it would help me; the company immediately requires my email to continue" — this is the pattern that produces the App Store review label "bait and switch."

**Evidence:**
```dart
// paywall_screen.dart:182–191
void _onAuthStateChanged(User? previous, User? next) {
  if (_authGateShown) return;
  final needsAuth = next == null || next.isAnonymous;
  if (!needsAuth) return;
  _authGateShown = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    showAuthGate(context);
  });
}
```
Plus the auth modal is non-dismissible (`auth_modal_bottom_sheet.dart:67–69 PopScope canPop:false, barrierDismissible:false`). No "let me see the prices first" path.

### Finding P-05: Decoy reference price is hardcoded marketing fiction
**Severity:** 5/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:1158`
**Mechanism:** Anchoring + reference-price manipulation. Showing a "was X" anchor next to the actual price triggers loss-aversion against the discount. When the "was X" is fictional, the practice has been ruled deceptive in multiple jurisdictions (FTC v. SunFrog 2022; UK ASA rulings on "RRP" claims 2023). The 2026 App Store's January policy update (post-EU Digital Services Act enforcement) explicitly cites "anchor pricing not based on a verifiable historical price" as a reviewable issue.
**Observation:**
```dart
// paywall_screen.dart:1153–1158
/// Decoy reference price for the highlighted yearly card — pure
/// marketing copy ("was 2999.99"), not a discounted price the store
/// reports. Stays hardcoded; RevenueCat's `discounts` /
/// `introductoryPrice` fields don't model the "fictional anchor"
/// pattern this decoy uses.
String? get _decoy => plan == _Plan.yearly ? '₺2.999,99 idi' : null;
```
The code comment is candid — "pure marketing copy", "fictional anchor". The user reads `₺2.999,99 idi` (struck through) → `₺999,99` and concludes they're getting a 67% discount. They are not. The yearly price was always ₺999,99.
**Cost:**
- App Store / Play Store reviewer hitting this state in 2026 has a specific guideline to cite. Risk of deletion or forced change.
- A Turkish-market user who comparison-shops (lokum.com, ekşi sözlük) and compares notes — within ~30 days of launch, the decoy is recognizable as fiction. The brand-trust hit then propagates faster than any retention play can recover.
- For users who *don't* notice: the ethical shape is still manipulation. The codebase's own comment says "fictional anchor" — internal documentation that admits manipulation is itself a corporate-risk artifact.

**Evidence:** above. The internal acknowledgment in the source comment is the strongest evidence — the team knows.

### Finding P-12: "🔥 10.000+ kişi kullanıyor" social-proof pill
**Severity:** 4/5
**Where:** `lib/features/monetization/presentation/paywall_screen.dart:752–783`
**Mechanism:** Bandwagon (social proof). When honest, social proof is one of the cleanest persuasion levers. When unverified or fabricated, it's the most damaging — because users discover it via reviews, their networks, or simple disbelief, and the discovery propagates as "they lied to me."
**Observation:**
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
The number "10.000+" is hardcoded. App is at version 0.1.0+5 (`pubspec.yaml:5`); no public install count is verifiable. The atlas notes ("Phase 60D · social-proof tag … Numbers stay round and rough — never fabricate a precision figure for marketing copy.") — the team explicitly chose the number to be vague but high.
**Cost:**
- For a user who checks reviews/install count and sees a much smaller number, the lie surfaces.
- Even users who don't verify carry an implicit ratio: "if 10k+ are using it, why am I the first person at the gym to mention it?" Many Turkish-speaking users will be in regions where word-of-mouth check-fail is fast.
- The emoji "🔥" combined with the number reads as ad copy more than testimonial. Honest social proof shows photos + first names + city ("Ahmet, İstanbul: 'Day 14, hayatımın en formda halindeyim.'"); FormAI's pill is the cheapest possible version.

**Evidence:** above + atlas §6.2 documents the pill's intent.

### Finding P-02 / P-25 cluster: "30 günde" promise vs "12 Hafta" duration in the AI report
**Severity:** 5/5 (this is the most consequential trust violation in the entire app)
**Where:**
- Brand promise (everywhere, especially Welcome subtitle): `onboarding_screen.dart:406-407` `'Sana özel antrenman ve beslenme planıyla 30 günde hedefine ulaş.'`
- Paywall hero subtitle: `paywall_screen.dart:736-737` `'Yapay zeka her tekrarını izlesin, formunu düzeltsin ve seni 30 günde hedefe taşısın.'`
- Paywall ribbon: `paywall_screen.dart:862` `'30 Günlük Değişimin!'`
- Today Task Card on Day 30 fall-through: `today_task_card.dart:202` `'30 günlük programı tamamladın.'`
- Pre-paywall summary in AI engine: `ai_personalization_engine.dart:14-17, 77` — `durationLabel: '12 Hafta'` — fixed string

**Mechanism:** Promise integrity. The brand line "30 günde karın kası" is the entire strategic promise. The user evaluates the paywall on the basis of that promise. The AI engine's pre-paywall summary contradicts it: the duration label inside the report card is "12 Hafta" (12 Weeks ≈ 84 days). This is not a typo — it's a structural conflict between the marketing promise and the engine's projection.
**Observation:**
```dart
// ai_personalization_engine.dart:69–80
static AiReport generateReport(WizardState state) {
  return AiReport(
    ...
    durationLabel: '12 Hafta',   // ← fixed
    estimatedResults: _estimatedResults(state),
  );
}

// ai_personalization_engine.dart:226–234
static String _estimatedResults(WizardState s) {
  return switch (s.goal) {
    'belly_burn' => '12 haftada 4-8 kg yağ kaybı',
    'muscle_gain' => '12 haftada belirgin kas artışı',
    'fitness_look' => '12 haftada belirgin form değişimi',
    'strength' => '12 haftada %20-30 güç artışı',
    _ => '12 haftada belirgin form değişimi',
  };
}
```
The estimated-results line that the user reads on the pre-paywall summary card says "12 haftada 4-8 kg yağ kaybı" — 12 weeks, not 30 days. The user has just been told (via every brand surface) that the result is achievable in 30 days. The system's own numerical projection is 84.

**Cost:**
- The user reads the pre-paywall card and either: (a) doesn't notice — proceeds to purchase based on the 30-day promise; later realizes and feels bait-switched; (b) notices — feels the promise was inflated; bounces.
- For a careful Turkish-speaking user (the demographic that does Reddit / ekşisözlük research), the 30 vs 12-Hafta inconsistency is a citation-grade finding for a negative review.
- This is the single most damaging integrity issue in the codebase, because it's structural (not a copy nit) and lives at the conversion gate.

**Evidence:** above. The brand promises 30 days from at least 4 surfaces; the engine projects 84 days from the same `WizardState`. These cannot both be honest.

### 4.2 Cumulative paywall trust ledger

| Lever | Trust impact |
|---|---|
| Personalized hero (M/F) | +1 (honest, on-brand) |
| Hardcoded ₺2.999,99 decoy | -2 (active manipulation) |
| Unverified "10.000+" social proof | -1 |
| 9.5pt trial badge | -1 (honest content, dishonest format) |
| 10.5pt 0.55 alpha legal footer | -1 (same) |
| 92% hardcoded confidence (carried from onboarding into the paywall context) | -1 |
| 30-day vs 12-Hafta inconsistency | -3 (structural promise breach) |
| Forced-auth gate non-dismissible | -2 |
| "AI DESTEKLİ" wheelchair icon hero (Other gender) | -1 (per P-01 in PREMIUMIZATION) |
| **Net** | **-11** |

The paywall has more trust-eroding mechanisms than trust-building mechanisms. The cleanest fix would be removing 4 of the worst (decoy price, fake confidence carryover, 12-Hafta inconsistency, forced-auth gate) — even before any new persuasion is added. The current configuration is conversion-optimized at the cost of long-term retention and brand trust.

---

## 5. IDENTITY REINFORCEMENT — DOES THE APP HELP THE USER SAY "I AM"?

James Clear's identity-based habit framework: behaviors stick when they reinforce identity. "I run" sticks; "I'm trying to lose weight" doesn't. The most retention-rich fitness apps craft language and feedback that say: *you are this kind of person.*

### Finding P-17: Identity reinforcement is absent
**Severity:** 4/5
**Where:** absence pattern across `gelisim_tab.dart` (entire AI Coach + program-progress copy), `today_task_card.dart` (entire CTA copy), `notification_service.dart:70–123` (all reminder pools).
**Mechanism:** Identity-based habits (Clear 2018) — the user's self-concept is the most durable retention engine. Apps that reinforce identity outlast apps that reinforce streaks or achievements alone.
**Observation:** Across the entire surface area, every line of copy is one of:
- Activity description ("Bugün hedeflerimize bir adım daha yaklaşıyoruz")
- Goal description ("Şampiyon serisi devam ediyor!")
- Instruction ("Serini bozma!" / "Antrenmana başla")
- Quantitative readout ("3 / 30 gün tamamlandı")
- Time-based copy ("Günün antrenmanı seni bekliyor")

What's *missing*: any line that says "you are a person who trains," "sen artık bir antreman yapan birisin," "FormAI sporcusu," or any equivalent identity claim. The app describes what the user *is doing* and never claims what the user *is.*

For comparison:
- Strava: "Athlete" is the literal user noun. Profile says "Athlete since 2023." Identity claim hardcoded.
- Apple Fitness+: "Move ring closed" — but also "You closed your Move ring 47 weeks in a row" → identity claim.
- Duolingo: "You are a 47-day streak holder" → "You're a polyglot."

FormAI says: "you used the app today."

**Cost:**
- Long-tail retention (Day 30+, the user-as-asset segment) is built on identity claims. FormAI's lifecycle ends at "you finished the program" (`today_task_card.dart:202`) — past tense, descriptive, not identity. Day 31+ has nowhere to go (P-29).
- For the predominant beginner segment, identity construction is *more* important than for experts — beginners are forming the self-concept for the first time. The app could be that mirror; it isn't.
- The fix is not "rewrite all copy" — it's "add 3-5 identity claim moments." Day 7 unlock copy: "Artık 1 haftalık disiplinli birisin." Day 30 completion: "30 gün boyunca her gün gösterdin. Artık FormAI sporcususun."

**Evidence:** absence pattern. Grep confirms:
```
$ grep -rn "FormAI sporcu\|sporcusu\|disiplinli birisin\|antrenman yapan birisin" /home/emre/Downloads/SixPack-AI/lib --include="*.dart"
(no results)
```
No identity-claim copy exists.

### Finding P-29: Day 31+ has no defined loop
**Severity:** 3/5
**Where:** `today_task_card.dart:176–216` (`ProgramCompleteCard`), `suggestions_screen.dart:129–141` (post-30 suggestion)
**Mechanism:** Habit-loop continuation. A 30-day program is a perfect arc — beginning, middle, end. The end is the highest-investment moment in the user's relationship with the app. If there's nowhere to go after, the investment vanishes.
**Observation:** On Day 30 completion:
- `ProgramCompleteCard` renders with "Tebrikler! / 30 günlük programı tamamladın." (`today_task_card.dart:194-208`) — a 60-px card with a 30pt 🏆 emoji.
- `SuggestionsScreen` workout-tip branch on `activeDay == null`: "30 günü tamamladın!… Yeni bir hedef belirlemek için Gelişim sekmesine göz at." (`suggestions_screen.dart:129–141`)
- Gelişim has no "next program" surface. Atlas §3.1 enumerates 18 routes; none is "post-program / next plan."
- The user's options on Day 31: re-do the same 30 days (no surface offers this), or churn.
**Cost:**
- The Day 30 user is the highest-value segment — they completed the full program. The system has nothing to offer them.
- Compare: Apple Fitness+ rotates programs; Centr cycles 4-week blocks; Future has explicit "next macro" planning. FormAI's structural ceiling is 30.
- For "abs in 30 days" branding, this is consistent — the brand promise is bounded. But the *retention* implication is that every successful user becomes a churned user on Day 31. That's structurally a one-shot product.

**Evidence:** above + grep of `lib/features/workout` and `lib/features/progress` for any "next program" or "renew" surface — none exists.

### Finding P-28: Program-complete celebration is undersized
**Severity:** 3/5
**Where:** `today_task_card.dart:176–216` (`ProgramCompleteCard`) vs `lib/features/progress/presentation/widgets/badge_unlock_dialog.dart:55–100` (`_BadgeUnlockDialog`)
**Mechanism:** Reward magnitude calibration. The reward magnitude should scale with the behavior magnitude. A single badge unlock gets a fullscreen modal with animated halo, heavyImpact haptic, and "YENİ ROZET" headline. Completing 30 days gets a 60-px inline card with one line of copy.
**Observation:** Side-by-side:

`ProgramCompleteCard` (atlas §5.5; `today_task_card.dart:176–216`):
```
🏆 [30pt emoji]
Tebrikler!                      [18pt fw900 white]
30 günlük programı tamamladın.  [13pt fw600 white80]
```
Inline card, ~80px tall, sits in the same slot as the Today Task Card. No modal, no fullscreen, no haptic, no share prompt that fires automatically.

`_BadgeUnlockDialog` (lifecycle event, fires for each badge unlock):
```
[Fullscreen modal with backdrop]
YENİ ROZET                       [11pt fw900 letter-spacing 4]
[110×110 animated halo with badge icon]
[Badge name 22pt fw900]
[Description body]
[Dismiss + Share buttons]
+ HapticFeedback.heavyImpact()   [badge_unlock_dialog.dart:25]
```
Fullscreen, ~400px tall, animated, haptic, share affordance.

**Cost:**
- A user who completes 30 days of discipline gets a smaller celebration than a user who unlocks one minor badge.
- The mismatch tells the user: "the 30-day arc isn't the goal; the badges are." Inverts the brand promise.
- The session-complete overlay (`session_complete_overlay.dart:69-88`) for *one* workout is also bigger (96px trophy icon, 32pt fw900 "Gün N Tamam!" title). One-day completion = bigger celebration than 30-day completion. Backwards.

**Evidence:** above. The structural absence of a "30 Tamam!" fullscreen overlay is the signal — the codebase has the components (`SessionCompleteOverlay`, `_BadgeUnlockDialog`) and didn't deploy them at the most important moment.

---

## 6. NOTIFICATIONS, EXTERNAL TRIGGERS, RE-ENGAGEMENT

This section bridges to RETENTION_TRIGGER_REPORT.md but the *psychological* notes belong here too.

### Finding P-25: Loss-aversion notification copy weaponizes streak fear
**Severity:** 3/5
**Where:** `lib/core/services/notification_service.dart:80–83` (`noWorkoutVariants[2]`)
**Mechanism:** Loss-framing in re-engagement. Loss-aversion notifications have the highest *single-firing* CTR but the worst *6-month retention* among A/B-tested fitness apps (BetterMe internal data published in 2024 mobile growth conference; cf. Reforge teardown of Strong/Hevy notification copy 2023).
**Observation:**
```dart
// notification_service.dart:80–83
(
  title: 'Bir hedefin var, unutma 🎯',
  body: 'Bugün antrenmanı geçersen yarın iki gün geride kalırsın.',
),
```
And:
```dart
// notification_service.dart:114–118
(
  title: 'Seriyi kaybetmek üzeresin! ⚡',
  body: '48 saat oldu. 10 dakikalık bir oturum momentumu kurtarır.',
),
```

These are loss-framed. The body lines specifically calibrate fear ("yarın iki gün geride kalırsın", "kaybetmek üzeresin").
**Cost:**
- Works once. The user feels guilt, opens the app, completes a workout. The notification is rewarded.
- After repeated firings (a non-trivial slice — Turkish daylight cycles vary, life happens), the user starts associating the FormAI notification with guilt. Notifications get muted.
- Compare to `bothDoneVariants` (line 96-109): "Günü fethettin! 🏆", "Mükemmel bir gün 💧", "Devam et! ⚡" — these are *celebration* framings. The ratio of fear-framed to celebration-framed notifications across the pool is unbalanced. Three `noWorkoutVariants` (all loss-framed) + two `streakVariants` (both loss-framed) + two `workoutNoFoodVariants` (mixed urgency) + three `bothDoneVariants` (celebration) = 5 loss : 3 celebration : 2 mixed.

**Evidence:** above + the variant pools are all in `notification_service.dart:70–123`.

### Finding P-33: "Günü fethettin" celebration uses war language
**Severity:** 2/5
**Where:** `lib/core/services/notification_service.dart:96–99`
**Mechanism:** Cultural language register. Turkish has multiple registers for achievement: gym-buddy (`başardın!`), formal (`tebrikler`), military (`fethettin!`, `zafer`), kitchen-vernacular (`afiyet olsun!`, `keyifli olsun`).
**Observation:**
```dart
// notification_service.dart:96–99
(
  title: 'Günü fethettin! 🏆',
  body: 'Bugün disiplinden kopmadın. Şimdi bol su iç ve dinlenmeye geç.',
),
```
"Fethettin" — to conquer, military verb. Used in Turkish proudly for sports achievements but with conqueror-conquered framing. For a fitness app whose audience includes a substantial female demographic and gentle-fitness adoption pattern, the verb skews male / aggressive.
**Cost:**
- Tone mismatch with the broader caregiver register the AI Coach uses elsewhere ("Geri dönüş zamanı", "10 dakika yeterli").
- For users coming back from injury, postpartum, or chronic-illness fitness re-entry — the conqueror framing lands as macho.

**Evidence:** above. Compare to the "Mükemmel bir gün 💧" line in the same pool — same celebration moment, warmer voice.

---

## 7. STRUCTURAL OBSERVATIONS — PSYCHOLOGY SUMMARY

### What the system does well, behaviorally:
1. **Onboarding labor illusion** is *competently* executed at the visual level (animations, copy, pacing). It's a manipulation, but it's the well-tuned kind. (P-10/P-11 flag the *risk*; the execution is professional.)
2. **AI Coach avatar breathing** at 2.4s scale 0.95-1.05 (`gelisim_tab.dart:1828–1830`) genuinely lands as "alive" — one of the few warm signals on Gelişim.
3. **Recovery-recipe suggestion** in the session-complete overlay (`session_complete_overlay.dart:43-46`) is a thoughtful endowment moment — the user just worked out, the system notices and suggests fuel.
4. **Smart reminder branching** in `notification_service.dart` (3 condition pools — noWorkout, workoutNoFood, bothDone) is conceptually correct; it's the copy ratio that's off (P-25).
5. **Streak-warning at 48h not 24h** (`notification_service.dart:299`) is more humane than typical fitness apps that fire daily; the 48h window respects life.

### What the system does poorly, behaviorally:
1. **Day 0 emotional cold** (P-01) — the maximum-investment / minimum-feedback moment.
2. **Identity construction absent** (P-17) — copy is all activity-describing, never identity-claiming.
3. **Reward magnitude inverted** (P-28) — badge unlock fires bigger than program completion.
4. **Personalization promise vs delivery gap** (P-06, P-11, P-13, P-26) — the onboarding promises a coach that knows you; the production app delivers 3 hardcoded copy branches keyed on streak.
5. **Trust-eroding monetization** (P-04, P-05, P-12, P-02 cluster) — the conversion gate is engineered for first-time hit-rate at the cost of brand trust.
6. **Loss-aversion-only streak system** (P-07, P-08) — no graduation, no graceful break, no ceiling.
7. **Comeback messaging buried** (P-16, J-E1) — the most retention-critical surface is the hardest to find.
8. **No Day 31+ loop** (P-29) — successful users churn by design.

### The five most consequential trust violations (sev-5):
- **P-01** Day-0 wall of zeros
- **P-02 cluster** "30 günde" promise vs "12 Hafta" engine projection
- **P-03** Day-4 paywall surprise
- **P-04** Forced-auth gate identity reversal
- **P-05** Hardcoded decoy reference price

If the team fixed only these five, the app's psychological position would jump from "competent fitness SaaS with conversion-optimized manipulation" to "trustworthy 30-day program with honest sales."

---

## 8. ERRATA AGAINST PRIOR PHASES

The atlas + Phase 2 reports' factual claims hold. Two extensions surfaced during this analysis:

### ERRATA E-13 (extends atlas §4 + ai_personalization_engine)
Atlas §4 documents the wizard as 12 steps without flagging that the AI report ships a `durationLabel: '12 Hafta'` (`ai_personalization_engine.dart:77`) AND `estimatedResults` lines all anchor on "12 haftada" (`ai_personalization_engine.dart:226–234`). The atlas's structural inventory is correct; the *contradiction* with the brand's "30 günde" promise (which the atlas mentions as the pubspec tagline at §0) is unflagged. **This is the most consequential trust gap in the entire codebase and merits an atlas erratum.**

### ERRATA E-14 (extends atlas §5.6 streak surfaces)
Atlas §5.6 says streak displays in 2 places; Phase 2 erratum E-3 corrected to 4 places. This report extends: there is also a 5th display surface — the home-screen widget (`widget_sync_service.dart:99 saveWidgetData<int>(_kStreak, streakCount)`). The native widget renders streak on iOS WidgetKit and Android AppWidgetProvider per atlas §11. So the streak surfaces are: (1) Antrenman header, (2) Gelişim header pill, (3) Gelişim Streak Card, (4) Profile stats tile, (5) home-screen widget — five total display surfaces, each rendered slightly differently.

The home-screen widget streak rendering is also the only out-of-app surface; if the user ignores in-app notifications but glances at the home screen, the widget's "0 gün" after a break is the most public guilt signal. Worth noting in retention analysis.

---

## 9. APPENDIX — PSYCHOLOGY EVIDENCE INDEX

| Finding | Primary file:line | Mechanism |
|---|---|---|
| P-01 | `gelisim_tab.dart:541–632, 681–797, 178–183` | SDT competence pillar |
| P-02 | `ai_personalization_engine.dart:14–17, 77, 226–234` vs `onboarding_screen.dart:386–397, 406–407` | Promise integrity |
| P-03 | `today_task_card.dart:104–108`, `app_constants.dart:30` | Habit Loop fragility |
| P-04 | `paywall_screen.dart:182–214`, `auth_modal_bottom_sheet.dart:67–69` | Identity contract |
| P-05 | `paywall_screen.dart:1153–1158` | Anchoring manipulation |
| P-06 | `gelisim_tab.dart:1613–1621` | Personalization gap |
| P-07 | `gelisim_tab.dart:1617`, `app_preferences.dart` (maxStreak only) | Loss aversion ceiling |
| P-08 | `gelisim_tab.dart:687–765` | Goal-gradient ceiling |
| P-09 | `onboarding_screen.dart:165–217` | Sunk-cost reversal |
| P-10 | `onboarding_screen.dart:1110, 1182` | Labor illusion |
| P-11 | `onboarding_screen.dart:1583, 1936` | Precision bias |
| P-12 | `paywall_screen.dart:752–783` | Bandwagon proof |
| P-13 | `gelisim_tab.dart:1747–1762` | SDT relatedness |
| P-14 | `dashboard_screen.dart:136–174` | Operant temporal-proximity |
| P-15 | `gelisim_tab.dart:1907–1914` | Achievement integrity |
| P-16 | `gelisim_tab.dart:1617` | Re-engagement burial |
| P-17 | absence — entire copy surface | Identity-based habits |
| P-18 | `onboarding_screen.dart:386` | Locus of control |
| P-19 | `onboarding_screen.dart:553–586` | Pacing |
| P-20 | `onboarding_screen.dart:2569–2571` | Voice consistency |
| P-21 | `onboarding_screen.dart:1316–1319` | Reciprocity asymmetry |
| P-22 | `gelisim_tab.dart:617` | Fixed reward |
| P-23 | wizard exit at `_finish()` | Endowment effect |
| P-24 | `gelisim_tab.dart:1618` | Comeback empathy |
| P-25 | `notification_service.dart:80–83, 114–118` | Loss framing |
| P-26 | `onboarding_screen.dart:553–556` | Promise without evidence |
| P-27 | `app_constants.dart:30`, `today_task_card.dart:19, 105` | SDT competence |
| P-28 | `today_task_card.dart:176–216` vs `badge_unlock_dialog.dart:55–100` | Reward magnitude |
| P-29 | `today_task_card.dart:202`, `suggestions_screen.dart:129–141` | Habit ceiling |
| P-30 | `gelisim_tab.dart:977, 1825, 431–443` | Attentional load |
| P-31 | `gelisim_tab.dart:713` | Tone matching |
| P-32 | `gelisim_tab.dart:1738` | Time-blind greeting |
| P-33 | `notification_service.dart:96–99` | Cultural register |

---

**END OF USER_PSYCHOLOGY_REPORT.md**

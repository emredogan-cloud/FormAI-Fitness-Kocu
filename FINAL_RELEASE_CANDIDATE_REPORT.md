# FormAI — Final Release Candidate Report (RC-1)

**Date:** 2026-07-14 · **Branch:** `main` · analyze **0** · **328 tests** green · full onboarding **device-verified end-to-end** on a fresh install (data-wiped release build, Xiaomi/Android 11).

---

## 1. Apple review audit (P1)

Engineerable state re-verified line-by-line; one fix shipped:

- **Fixed (`84436b5`):** `NSSupportsLiveActivities(+FrequentUpdates)` removed — v1 ships without the FormAIWidget extension (the one Mac-only task), and declaring a capability with no extension bundle misdescribes the binary. Restore with the extension in v1.1.
- **Verified clean:** camera purpose string (clear, specific, Turkish); **no** microphone permission; `ITSAppUsesNonExemptEncryption=false`; `PrivacyInfo.xcprivacy` wired; TR-only locale; 18+ age gate; opt-in-OFF analytics consent; in-app account deletion; medical disclaimers on nutrition/coach/consent surfaces; paywall shows renewal terms and binds trial copy to live store products only; no outcome-quantified claims anywhere ("X haftada Y kg" absent); guest mode = full pre-purchase review path; **coach LLM cannot stall or fabricate coaching UI** (hard offline fallbacks; anti-fabrication persona from the live eval).
- **Founder-side (in the submission guide):** ASC forms (privacy labels, age rating incl. any AI-content questions), reviewer account, demo video, Paid Apps agreement.

## 2. iOS release readiness (P2) — everything Linux-possible is done

`flutter build ipa` **requires macOS/Xcode — physically impossible here**. Everything up to that point is prepared: committed `codemagic.yaml` (pod install → ASC-key signing → analyze/test → IPA → TestFlight), Podfile (15.5, permission macros), entitlements, privacy manifest, iPhone-only targeting, export-compliance flag, clean plist. **One founder action generates + uploads the IPA:** run the `FormAI iOS → TestFlight` workflow after the 15-minute Codemagic setup in `docs/ios/CODEMAGIC_SETUP.md`. No credentials for Codemagic/ASC exist on this machine (correctly so), so no upload was attempted.

## 3. TestFlight readiness (P3)

The founder only needs to invite testers. Everything else is written into `FINAL_APP_STORE_SUBMISSION_GUIDE.md`: tester guide (Turkish, copy-paste), review notes, reviewer/demo account recipe, known-issues list, and the exact TestFlight sequence.

## 4. Workout engine audit (P4) — as PT/strength coach

- **Critical fix (`03e391d`):** progressive overload **compounded 1.2×/week** (`pow(1.2, week)`) → days 29-30 hit **2.07×** week-1 volume; a 12-rep set silently became ~25. Overuse-risk territory. Now **linear +8 %/week** (1.00→1.32, ~32 % across the program) — defensible prescription, still visibly progressive. Both rep- and time-based targets; 15 generator tests green.
- **Assessed sound:** 3-on-1-off rest cadence; goal buckets with alternating muscle rotation (no single-muscle days); beginner ramp (no advanced work weeks 1-2); equipment-aware filtering with safe fallback chain; deterministic generation; honest offline stub. Analyzer cue quality was tuned in earlier sprints (docs/archive/workout-analyzers).
- **Documented ideas (not blockers):** deload/periodization beyond 30 days, per-muscle weekly volume caps, RPE-based autoregulation, richer per-exercise descriptions in the catalogue.

## 5. App icon (P5, `84ef64b`)

`photos/APP_ICON.png` adopted as canonical. Inner rounded-square cropped full-bleed 1024; **adaptive background carries the image** (fills every OEM mask edge-to-edge) with transparent foreground — scaling a framed photo into the 66 % safe zone floats it tiny, so this is the premium arrangement. Legacy + iOS same crop; iOS 1024 verified RGB/no-alpha; Play 512 regenerated to match.

## 6-12. Onboarding evolution — ALL device-verified on a fresh install

| Phase | Change | Device evidence |
|---|---|---|
| **P6** Başla bg (`aba1fea`) | Square icon art (cover-amputated) → portrait hero from `First_opening.png`, imagery-only webp crop, cover+topCenter | Fills perfectly; logo/robot/athlete framed; native title+CTA below |
| **P7** LLM first conversation (`6c10028`) | Brief intro → name → **live Claude welcome** → burden chip → **live Claude empathy** → transition. 3 monologue beats CUT. Hard scripted fallbacks (offline/8s) — onboarding can never stall | Both turns landed personalized: "Deniz, hoş geldin — ben Form…" · "Deniz, sonuç görmek için sabırla çalışmak gerçekten yorucu — ama sen burada olduğun için, bu sefer farklı olacak 💪" |
| **P8** Form avatar on comment cards (`748231e`) | Circular PT_FORM avatar left on `AiInsightCard` | Verified on both variants ("Yapay Zeka Notu", "Form Diyor ki:") |
| **P9** AI report redesign (`de321bb`) | Hero card (AI HAZIR chip + portrait + gradient title), gauge-arc metric cards with status (BMI "Normal" green), projection, %92 ring, gradient 2-line CTA — stagger/morph animation system kept | Renders faithful to `kişisel_aı_raporun.png`; BMI 24.2 Normal, 2144 kcal live-computed |
| **P10/11** Commitment screen (`e8cfc99`) | Rebuilt per `planıma_geç.png`: bubble hero, gradient headline, honest capability cards, voice card, benefit row, circled-arrow pill CTA; ~400-line duplicate summary cluster removed | Renders faithful at 11/11 |
| **P12** One-time welcome (`343dd71`) | "Bugün dönüşümünün ilk günü." + tab tour + where-to-find-Form, then gone forever | Fired once on first dashboard landing, exact copy |

## 13. Validation

`dart format` clean · `flutter analyze` 0 · **328 tests** · release APK built + installed + **full fresh-install onboarding walkthrough on hardware** (age gate → consent → hook → LLM chat → questions → metrics → analysis → report → commitment → guest gate → welcome scene → dashboard), zero crashes; live LLM verified twice mid-flow. CI on the public repo was green for every prior push; RC-1 commits push the same fast gates.

## 14. Remaining founder-only work

Fully enumerated in **`FINAL_APP_STORE_SUBMISSION_GUIDE.md`** — Apple Developer enrollment, Codemagic 15-minute setup + first TestFlight build, ASC record/forms, reviewer account, demo video, tester invites, Play console mirror-track. Plus the standing items (Anthropic spend cap, GitHub billing already unblocked-by-public, device-matrix QA).

**Engineering verdict: RC-1. Nothing engineerable remains on this machine.**

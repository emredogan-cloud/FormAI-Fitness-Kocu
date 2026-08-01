# Glossary

Terms a translator must not change, and terms that must be translated
the same way every time.

---

## Never translated

| term | why |
| --- | --- |
| **FormAI** | The product name. Appears in copy, deep links (`formai://`), the share hashtag `#FormAI`, and the Play listing. In Turkish it takes apostrophe suffixes — `FormAI'ı`, `FormAI'da` — which harmonise with the preceding vowel. In a language without that convention, drop the apostrophe rather than transliterate the name. |
| **Form** | The coach's name, not the English word. "Ben Form" is an introduction. If a language would read it as the common noun, keep it capitalised and unchanged — renaming the coach is a product decision, not a translation one. |
| **Premium** | The paid tier. **Founder decision, final:** the tier is **FormAI Premium** on every user-visible surface, in every language. The copy used to say Premium in 13 keys and Pro in 6, and a plan badge said "PRO required" — a user could be sold Premium and then told they needed PRO. The RevenueCat **entitlement id** is still the literal string `FormAI Pro` (`kProEntitlementId`); that is a dashboard-matched technical identifier and is never rendered. Do not "fix" it. |
| **AI** | Used as a badge and in headings. Turkish copy uses both "AI" and "Yapay Zeka"; that is deliberate — the badge is short, the sentence is not. Follow the same rule: whichever form the target language actually uses in consumer fitness apps. |
| **XP** | The points unit. Short, understood, and joined by analytics. |
| **kcal**, **g**, **cm**, **kg**, **dk / min** | Unit symbols. Convert the *value* through `core/utils/unit_system.dart`; never translate the symbol. |
| **Six-Pack** | A fitness term the Turkish copy already keeps in English. |
| `formai://r/{code}` | The referral deep link. It appears mid-sentence in share copy. If it breaks, the referral does. |

---

## Fixed translations

One concept, one word — every time. Translators drifting between
synonyms is how a product starts sounding like three products.

| concept | Turkish | note |
| --- | --- | --- |
| workout session | **antrenman** | not "egzersiz" — that is a single exercise |
| a single exercise | **egzersiz** | |
| repetition | **tekrar** | |
| set | **set** | |
| streak | **seri** | |
| plan / program | **program** | "plan" is used for the noun the user receives ("planın") |
| goal | **hedef** | |
| level | **seviye** | |
| badge | **rozet** | |
| form (posture) | **form** | collides with the coach's name in isolation; always used in a phrase ("formun bozulduğunda") |
| rest | **dinlenme** | |
| calories | **kalori** | the unit stays `kcal` |
| macros | **makro** | |
| meal | **öğün** | |
| recipe | **tarif** | |

---

## English variety

**American.** `program`, not `programme`. `analyze`, `personalized`,
`optimize`, `favorites`, `meters`, `liters`, `center`, `catalog`,
`canceled`. (`cancellation` keeps both l's in American English too.)

Not a stylistic preference — a consistency requirement. The Phase 6
draft mixed both varieties: 24 keys said "programme" while ten said
"program", and "analyses" sat next to "optimise". Either variety reads
fine; the mixture reads like nobody proofread it.

American is the default because the largest English-speaking market is
the US and American spellings are legible everywhere, while British ones
read as foreign to an American user. `tool/arb_coverage.dart` does not
police this — a reviewer does, and this paragraph is what they check
against.

Units are the exception and are not spelling: `kcal`, `g`, `cm`, `kg`
stay as symbols in every locale, and the metric/imperial *value*
conversion is `core/utils/unit_system.dart`'s job.

---

## Register

Turkish copy addresses the user with the **informal second person**
(`sen`, `-sın`), throughout, including the legal and paywall surfaces.
That is a deliberate product voice: Form is a coach, not a bank.

Two exceptions, both pre-existing and both in form validation
("anlatırsanız", "yazın") — they read as slightly formal and should be
brought into line the next time that copy is touched.

The coach never scolds. Look at `onbPainFeedback*` and
`nameCaptureAck*`: the pattern is name the difficulty back to the user,
then say what the plan does about it. A translation that turns
"Motivasyon dalgalanır — sistem dalgalanmaz" into an instruction has
lost the point.

---

## Claims that are legally load-bearing

Do not soften, strengthen, or drop these. Each has a written
`description` in `app_en.arb` saying so.

| key | why |
| --- | --- |
| `consentHealthDisclaimer` | The Play Console health declaration attests this is shown during onboarding. |
| `consentIntro` | Contains the "both start switched off" promise. KVKK Article 5 requires explicit opt-in; the consent screen's own test asserts the default. |
| `paywallRenewalWithPrice`, `paywallRenewalNoPrice` | Auto-renewal disclosure required by Apple 3.1.2 and Play subscription policy. |
| `paywallTrialOpening`, `paywallTrialCancelNote`, `paywallCancelAnytime` | Trial and cancellation terms. Only ever shown when the store SKU really carries a trial. |
| `showcaseFormProof`, `socialProofPrivacyBody` | "Runs entirely on your device — your video never leaves it." A factual claim about the app's behaviour. It is true; keep it true. |
| `onbGoalFeedback` | Carries "Sonuçlar bireysel çabaya ve tutarlılığa bağlıdır" — the results disclaimer. |

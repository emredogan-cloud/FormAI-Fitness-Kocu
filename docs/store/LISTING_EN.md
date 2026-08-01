# Store listing copy (EN) — FormAI

Roadmap Phase 6. Written against the same rules as `LISTING_TR.md` — do
not regress them when editing:

- No fabricated numbers, testimonials or social proof.
- No outcome quantification. "Lose X lbs in Y weeks" is forbidden, and so
  is every softer version of it.
- No generative-AI implication. The "AI" claim is limited to what ships:
  on-device pose analysis plus rule-based coaching. The chat coach is a
  real LLM, but the *headline* claim stays on the camera because that is
  the differentiator and the one that is trivially verifiable.
- Every number is an undersell of the real figure.

Character limits: Play title 30 / short 80 / full 4000 · ASC name 30 /
subtitle 30 / keywords 100.

**American English**, per `docs/i18n/GLOSSARY.md`. The listing and the
app have to agree; a store page written in British English above an app
that says "program" reads as two products.

## App name / title

- Play title & ASC name: **FormAI — Fitness Coach** (22)
- ASC subtitle (pick one, ≤30):
  1. **Fix your form with a camera** (27) ← recommended
  2. On-device form analysis (24)
  3. Voice coach · 30-day plan (26)

## Play short description (≤80; pick one)

1. **Open your camera: AI analyzes your form on your phone and calls out fixes.** (~78) ← recommended
2. On-device form analysis, voice coaching, a 30-day plan and a nutrition guide. (~78)
3. Train at home: camera-based form analysis and a personal 30-day program. (~74)

## Full description (Play "Full description" / ASC "Description")

**FormAI — the AI fitness coach that works through your camera.**

Prop your phone up and start moving. FormAI watches you in real time,
counts your reps, and tells you out loud the moment your form slips —
the way a coach standing next to you would.

🎯 REAL-TIME FORM ANALYSIS
• Your camera feed never leaves your phone. The analysis runs entirely
  on the device with Google ML Kit. No frame is ever uploaded.
• Rep counting and form cues across 130+ exercises, from squats to planks
• Voice coaching: pacing on a good rep, an immediate warning on a bad one

📅 A 30-DAY PROGRAM BUILT FOR YOU
• Personalized to your goal, your level and the equipment you have
• Daily tasks, streak tracking, XP and badges
• A home-screen widget that keeps today's workout in front of you

🥗 NUTRITION GUIDE
• Hundreds of recipes suggested for your goal and your taste
• Calories and macros, favorites, and a shopping list

🔒 PRIVACY COMES FIRST
• No ads, no tracking, no data sales
• Body data like your height and weight stays on your device
• Analytics and crash reporting are entirely optional (default: off)

⭐ FORMAI PRO
The full 30-day program, the premium exercises and the nutrition module
unlock with a FormAI Pro subscription. Unless canceled, it renews
automatically at the end of each period; you can cancel any time from
your store account. Prices are shown on the purchase screen.

—
FormAI offers general fitness guidance; it is not medical advice. If you
have a health condition, talk to your doctor before you start training.
The app is for ages 18 and over.

Privacy Policy: https://d2srybp77lgcpy.cloudfront.net/privacy.html
Terms of Use: https://d2srybp77lgcpy.cloudfront.net/terms.html

## ASC keywords (≤100 chars, comma-separated)

`fitness,workout,exercise,form,coach,gym,home,squat,plank,nutrition,diet,recipe,plan,weight,muscle` (96)

## ASC promotional text (≤170, updateable without review)

`Open your camera and fix your form: on-device AI analysis, voice coaching, and a 30-day plan built for you.` (~106)

## Claim discipline (why this wording)

Same ledger as the Turkish listing, restated because a translator will
read this file and not that one:

- "AI analyzes your form on your phone" = ML Kit BlazePose on-device.
  Verified: there is no frame-upload path in the codebase. No chat or
  generative wording anywhere in the headline claims.
- "130+ exercises" = 138 analyzer-routed slugs in code. Undersell.
- "Hundreds of recipes" = 293 in the catalogue. Undersell.
- "Unless canceled, it renews automatically…" is the required auto-renewal
  disclosure and matches `paywallRenewalNoPrice` in the app word for word
  in substance. If one changes, change both.
- The medical disclaimer matches `consentHealthDisclaimer`.
- No transformation promises, no timeframe-outcome claims, no invented
  social proof — consistent with the in-app honesty pass and with Play's
  Misleading Claims policy / Apple 2.3.1.

## Still outstanding (founder-side)

These are not writing tasks and are not done:

1. **English screenshots.** Eight Play slots, regenerated from the real
   English UI — the Turkish frames cannot be reused, and a screenshot
   showing Turkish chrome under an English listing is a rejection risk as
   well as a conversion one. The device build for this is `1.0.0+26`.
2. **English feature graphic** (1024×500).
3. **Play Console → Store listing → Manage translations → add English**,
   then paste the blocks above. Play keeps per-language listings; adding
   English does not touch the Turkish one.
4. **Native-speaker read.** The app copy is a reviewed draft (Phase 6),
   not a professionally proofread one. The listing is the highest-leverage
   place to spend an hour of a native reader's time, because it is what
   someone reads *before* they install.

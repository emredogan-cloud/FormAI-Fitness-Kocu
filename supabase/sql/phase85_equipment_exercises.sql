-- =============================================================================
-- Phase 85 · Ekipmanlı Egzersizler — 10 new equipment-only exercises
-- =============================================================================
-- Replaces the four "Sınırlarını Zorla" core plan cards with seven
-- muscle-group cards in the new "Ekipmanlı Egzersizler" dashboard strip.
-- The existing 41-exercise catalogue had ~17 equipment movements, but
-- distribution was uneven: only 1 each for legs (leg_press) and core
-- (hanging_leg_raise), 2 each for biceps and triceps. This migration
-- bumps every muscle group to ≥3 equipment exercises so each new card
-- can carry a realistic 3–5-movement plan instead of looking thin.
--
-- Distribution after this migration (equipment-only counts):
--   Göğüs (chest)   3 → 4   (+ incline_bench_press)
--   Sırt (back)     4 → 4   unchanged
--   Omuz (shoulders) 4 → 4  unchanged
--   Kol — biceps    2 → 3   (+ concentration_curl)
--   Triceps         2 → 3   (+ skull_crusher)
--   Bacak (legs)    1 → 5   (+ barbell_squat, romanian_deadlift,
--                            leg_extension, leg_curl)
--   Karın (core)    1 → 4   (+ cable_crunch, weighted_russian_twist,
--                            ab_wheel_rollout)
--
-- Schema unchanged from Phase 50A. Same column set, same ON CONFLICT
-- (slug) DO NOTHING idempotency. Re-running this file is safe.
--
-- video_url values follow the Phase 75 convention: PascalCase
-- filename derived from the slug (e.g. `concentration_curl` →
-- `ConcentrationCurl.mp4`). The actual .mp4 files must be uploaded
-- to the `exercises` Storage bucket separately; until they are, the
-- exercise card falls back to the existing player empty state.
-- =============================================================================

-- ----------------------------- Chest (+1) -----------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'incline_bench_press', 'Yokuş Yukarı Bench Press', 'repBased', 'chest',
  'intermediate', ARRAY['upper_body'],
  10, NULL, 3, 60, false,
  'Yatış açısı 30–45° eğik bench üzerine sırtüstü uzan, dambılları omuz hizasında tut ve göğsünden kollarını tam açana kadar yukarı it.',
  'Dirseğini kilitlemeden üst noktada kontrol et.',
  'InclineBenchPress.mp4'
)
ON CONFLICT (slug) DO NOTHING;

-- ----------------------------- Arms — Biceps (+1) ---------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'concentration_curl', 'Konsantrasyon Curl', 'repBased', 'arms',
  'intermediate', ARRAY['upper_body'],
  12, NULL, 3, 45, false,
  'Bench üzerine otur, bir dambılı tek elle tut ve dirseğini iç bacağına dayayarak omuz hizasına kadar kontrollü kaldır.',
  'Dirseği sabit tut, sadece ön kol hareket etsin.',
  'ConcentrationCurl.mp4'
)
ON CONFLICT (slug) DO NOTHING;

-- ----------------------------- Arms — Triceps (+1) --------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'skull_crusher', 'Skull Crusher', 'repBased', 'arms',
  'intermediate', ARRAY['upper_body'],
  10, NULL, 3, 50, false,
  'Sırtüstü bench üzerine uzan, EZ bar veya dambılları omuz hizasında düz tut ve dirseklerini sabit tutarak alın hizasına indir.',
  'Üst kolu sabit, sadece ön kol oynasın.',
  'SkullCrusher.mp4'
)
ON CONFLICT (slug) DO NOTHING;

-- ----------------------------- Legs (+4) ------------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'barbell_squat', 'Barbell Squat', 'repBased', 'legs',
  'intermediate', ARRAY['lower_body'],
  10, NULL, 4, 75, false,
  'Bar omuz arkasında, ayakların omuz genişliğinde, dizlerin parmak ucu hizasında bükülecek şekilde kalçandan oturarak çök ve topuktan iterek kalk.',
  'Dizini içe bırakma, göğsünü dik tut.',
  'BarbellSquat.mp4'
),
(
  'romanian_deadlift', 'Romen Deadlift', 'repBased', 'legs',
  'intermediate', ARRAY['lower_body'],
  10, NULL, 3, 60, false,
  'Bar veya dambıllar elinde, dizler hafif bükük, sırtın düz; kalçandan menteşe gibi öne eğil ve hamstring gerilimini hissettiğin noktadan kalçanı öne iterek doğrul.',
  'Beli yuvarlama, hareket kalçadan gelsin.',
  'RomanianDeadlift.mp4'
),
(
  'leg_extension', 'Leg Extension', 'repBased', 'legs',
  'beginner', ARRAY['lower_body'],
  12, NULL, 3, 45, false,
  'Leg extension makinesine otur, ayak bileklerini ped altına yerleştir ve quadricepsi sıkıştırarak bacaklarını tam düzleştirip kontrollü indir.',
  'Üst noktada bir saniye sıkıştır.',
  'LegExtension.mp4'
),
(
  'leg_curl', 'Leg Curl', 'repBased', 'legs',
  'beginner', ARRAY['lower_body'],
  12, NULL, 3, 45, false,
  'Leg curl makinesine yüzükoyun uzan, topukları ped altına yerleştir ve hamstringi sıkıştırarak topuklarını kalçana doğru çek.',
  'Kalçayı pedden kaldırma.',
  'LegCurl.mp4'
)
ON CONFLICT (slug) DO NOTHING;

-- ----------------------------- Core / Karın (+3) ----------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'cable_crunch', 'Kablo Mekik', 'repBased', 'core',
  'intermediate', ARRAY['core'],
  15, NULL, 3, 40, false,
  'Kablo makinesinin önünde diz çök, ipi kulak hizasında tut ve karnını kasarak gövdeni dizlerine doğru yuvarla.',
  'Çekiş kollardan değil karnından gelsin.',
  'CableCrunch.mp4'
),
(
  'weighted_russian_twist', 'Ağırlıklı Rus Dönüşü', 'repBased', 'core',
  'intermediate', ARRAY['core'],
  20, NULL, 3, 40, false,
  'Otur, dizleri bük, plate veya dambılı göğüs önünde tut, hafifçe geri yaslan ve gövdeni sağdan sola tempolu biçimde çevir.',
  'Sırtın yere düşmesin, karın sıkı.',
  'WeightedRussianTwist.mp4'
),
(
  'ab_wheel_rollout', 'Ab Wheel Rollout', 'repBased', 'core',
  'advanced', ARRAY['core'],
  10, NULL, 3, 60, false,
  'Diz üstü dur, ab wheel kollarını omuz hizasında tut ve karnını kasarak ileriye doğru yuvarlanıp aynı tempoyla başlangıç noktasına dön.',
  'Beli çukurlaştırma, karın gergin kalsın.',
  'AbWheelRollout.mp4'
)
ON CONFLICT (slug) DO NOTHING;

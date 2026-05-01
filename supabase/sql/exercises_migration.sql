-- =============================================================================
-- Phase 50A · Supabase exercises catalogue migration
-- =============================================================================
-- Lifts the 41 exercises previously hard-coded in
-- `lib/features/workout/data/workout_repository.dart` into a database-backed
-- catalogue so the freelance content team (and future admin panel) can
-- author and update movements without shipping a new Dart build.
--
-- Run order:
--   1. supabase_exercises_migration.sql  (this file — DDL + seed)
--   2. supabase_rls_policies.sql         (admin write + public read RLS)
--
-- Idempotency: every statement is safe to re-run.
--   • `CREATE TABLE IF NOT EXISTS` for the schema.
--   • `ON CONFLICT (slug) DO NOTHING` on every INSERT — re-running leaves
--     existing rows untouched, only fills in slugs that aren't there yet.
--   • Indexes use `CREATE INDEX IF NOT EXISTS`.
--
-- Schema notes:
--   • `id` is the directive's `uuid` primary key, but lookups go through
--     `slug` (e.g. 'crunch', 'push_up') because the Dart code references
--     exercises by slug in the static plan templates and any user-saved
--     plan caches written before this migration.
--   • `target_muscles` is `text[]` per the directive even though the Dart
--     `Exercise.targetMuscle` field is currently a single string. The
--     Flutter mapping in workout_repository.dart reads element [0] back as
--     `targetMuscle` and ignores the rest, so seeding with a one-item
--     array preserves backwards-compatibility while leaving headroom for
--     "secondary muscle" tagging once the admin panel ships.
--   • `video_url` stores a FILENAME ('Crunch.mp4') in this seed because
--     the existing Storage bucket sits at:
--         {SUPABASE_URL}/storage/v1/object/public/exercises/{filename}
--     The Dart fetch layer (workout_repository.dart::_composeVideoUrl)
--     prepends the project URL when the value isn't already an http(s)
--     URL. Future admin entries CAN paste a full http(s) URL directly
--     (e.g. an external CDN) and the same resolver will use it as-is.
--
-- Counts: 9 core + 6 chest + 6 legs + 5 back + 5 shoulders + 5 arms
--         + 5 cardio/full-body = 41 exercises.
-- =============================================================================


-- =============================================================================
-- SECTION 1 · Table DDL
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.exercises (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                        text UNIQUE NOT NULL,
  name                        text NOT NULL,
  type                        text NOT NULL
                                CHECK (type IN ('repBased', 'timeBased')),
  category                    text NOT NULL
                                CHECK (category IN (
                                  'core', 'chest', 'legs', 'back',
                                  'arms', 'shoulders', 'fullBody'
                                )),
  difficulty                  text NOT NULL
                                CHECK (difficulty IN (
                                  'beginner', 'intermediate', 'advanced'
                                )),
  target_muscles              text[] NOT NULL DEFAULT '{}',
  target_reps                 int,
  target_duration_in_seconds  int,
  sets                        int NOT NULL DEFAULT 3,
  rest_duration_in_seconds    int NOT NULL DEFAULT 30,
  is_cardio                   boolean NOT NULL DEFAULT false,
  instructions                text NOT NULL DEFAULT '',
  short_tip                   text NOT NULL DEFAULT '',
  video_url                   text,
  thumbnail_url               text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS exercises_slug_idx
  ON public.exercises (slug);
CREATE INDEX IF NOT EXISTS exercises_category_idx
  ON public.exercises (category);
CREATE INDEX IF NOT EXISTS exercises_difficulty_idx
  ON public.exercises (difficulty);
CREATE INDEX IF NOT EXISTS exercises_target_muscles_idx
  ON public.exercises USING GIN (target_muscles);

-- Auto-bump `updated_at` on UPDATE so the admin panel + client cache
-- reconciler can use it as a monotonic version key.
CREATE OR REPLACE FUNCTION public.exercises_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS exercises_touch_updated_at ON public.exercises;
CREATE TRIGGER exercises_touch_updated_at
  BEFORE UPDATE ON public.exercises
  FOR EACH ROW
  EXECUTE FUNCTION public.exercises_touch_updated_at();


-- =============================================================================
-- SECTION 2 · Seed data — 41 exercises lifted from workout_repository.dart
-- =============================================================================
-- Order mirrors the in-app rotation: core → chest → legs → back → shoulders
-- → arms → cardio/full-body. Slugs match the Dart `Exercise.id` strings
-- exactly (including the legacy `situp` without underscore) so plan caches
-- written before this migration still resolve cleanly.
-- =============================================================================

-- ----------------------------- Core (9) -------------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'crunch', 'Mekik', 'repBased', 'core', 'beginner', ARRAY['core'],
  12, NULL, 3, 30, false,
  'Sırt üstü uzan, dizlerini bük ve omuzlarını kontrollü olarak yukarı kaldır.',
  'Boyuna asma, karnınla çek.',
  'Crunch.mp4'
),
(
  'situp', 'Sit-up', 'repBased', 'core', 'beginner', ARRAY['core'],
  12, NULL, 3, 35, false,
  'Sırt üstü uzan, gövdeni dizlerine kadar tam olarak kaldır ve kontrollü in.',
  'Karnını sık, hızı abartma.',
  'SitUp.mp4'
),
(
  'plank', 'Plank', 'timeBased', 'core', 'beginner', ARRAY['core'],
  NULL, 40, 3, 45, false,
  'Dirseklerin üstünde sabit dur, vücudunu omuzdan topuğa düz bir çizgi tut.',
  'Kalçanı düşürme.',
  'Plank.mp4'
),
(
  'leg_raise', 'Bacak Kaldırma', 'repBased', 'core', 'beginner', ARRAY['core'],
  12, NULL, 3, 30, false,
  'Sırt üstü uzan, bacaklarını düz tutarak yavaşça 90 dereceye kadar kaldır.',
  'Belini yere bastır.',
  'LegRaise_demo.mp4'
),
(
  'hanging_leg_raise', 'Asılı Bacak Kaldırma', 'repBased', 'core', 'advanced',
  ARRAY['core'],
  10, NULL, 3, 45, false,
  'Bara tutun, bacaklarını birleştirip kontrollü olarak göğsüne doğru çek.',
  'Salınımdan kaçın.',
  'HangingLegRaise.mp4'
),
(
  'russian_twist', 'Rus Dönüşü', 'repBased', 'core', 'beginner', ARRAY['core'],
  20, NULL, 3, 30, false,
  'Otur, hafifçe geri yaslan ve gövdeni sağdan sola tempolu biçimde döndür.',
  'Karnını sıkı tut.',
  'RussianTwist.mp4'
),
(
  'mountain_climber', 'Mountain Climber', 'repBased', 'core', 'intermediate',
  ARRAY['core'],
  30, NULL, 3, 30, true,
  'Plank pozisyonunda kal, dizlerini sırayla göğsüne hızla çekiştir.',
  'Kalçayı sabit tut.',
  'MountainClimber.mp4'
),
(
  'bicycle_crunch', 'Bisiklet Mekiği', 'repBased', 'core', 'beginner',
  ARRAY['core'],
  16, NULL, 3, 30, false,
  'Sırt üstü uzan, karşıt dirsek ve dizini havada birleştir, taraf değiştir.',
  'Tempolu ama kontrollü.',
  'BicycleCrunch.mp4'
),
(
  'flutter_kick', 'Flutter Kick', 'timeBased', 'core', 'intermediate',
  ARRAY['core'],
  NULL, 30, 3, 30, false,
  'Sırt üstü uzan, bacaklarını kısa ve hızlı kanat çırpar gibi değiştir.',
  'Karnını gevşetme.',
  'FlutterKick.mp4'
)
ON CONFLICT (slug) DO NOTHING;


-- ----------------------------- Chest (6) ------------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'push_up', 'Şınav', 'repBased', 'chest', 'intermediate', ARRAY['upper_body'],
  12, NULL, 3, 45, false,
  'Eller omuz hizasında, gövdeni düz tutarak yere kadar in ve geri it.',
  'Dirseğini gövdene yakın tut.',
  'PushUp.mp4'
),
(
  'incline_push_up', 'Yokuş Yukarı Şınav', 'repBased', 'chest', 'beginner',
  ARRAY['upper_body'],
  14, NULL, 3, 45, false,
  'Ellerini yüksek bir yüzeye dayalı tutarak şınav hareketini uygula.',
  'Sırtını düz tut.',
  'InclinePushUp.mp4'
),
(
  'decline_push_up', 'Yokuş Aşağı Şınav', 'repBased', 'chest', 'advanced',
  ARRAY['upper_body'],
  10, NULL, 3, 50, false,
  'Ayaklarını yüksek bir yere koy, üst göğsünü hedefleyerek şınav yap.',
  'Yavaş in, hızlı çık.',
  'DeclinePushUp.mp4'
),
(
  'chest_dip', 'Göğüs Dip', 'repBased', 'chest', 'advanced',
  ARRAY['upper_body'],
  10, NULL, 3, 60, false,
  'Paralel barlarda göğsünü öne eğ, dirseklerini kontrollü olarak büküp aşağı in.',
  'Omuzları çukurlaştırma.',
  'ChestDip.mp4'
),
(
  'bench_press', 'Dambıl Bench Press', 'repBased', 'chest', 'intermediate',
  ARRAY['upper_body'],
  12, NULL, 3, 60, false,
  'Sırtın bench üstünde, dambılları göğsünden başlayıp yukarı doğru kontrollü it.',
  'Bilek düz, dirsek 45°.',
  'DumbellBenchPress.mp4'
),
(
  'chest_fly', 'Chest Fly', 'repBased', 'chest', 'intermediate',
  ARRAY['upper_body'],
  12, NULL, 3, 50, false,
  'Sırt üstü uzan, kollarını yana aç ve göğsünün üstünde kontrollü olarak kapat.',
  'Dirseğin hafif bükülü kalsın.',
  'ChestFly.mp4'
)
ON CONFLICT (slug) DO NOTHING;


-- ----------------------------- Legs (6) -------------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'squat', 'Squat', 'repBased', 'legs', 'beginner', ARRAY['lower_body'],
  15, NULL, 3, 45, false,
  'Ayakların omuz hizasında; kalçanı geriye it, dizlerini büküp aşağı in ve kalk.',
  'Topuklarından güç al.',
  'Squat.mp4'
),
(
  'lunge', 'Lunge', 'repBased', 'legs', 'beginner', ARRAY['lower_body'],
  12, NULL, 3, 45, false,
  'Geniş bir adım at, ön dizini 90 dereceye kadar büküp kontrollü olarak kalk.',
  'Ön diz parmak ucunu geçmesin.',
  'Lunge.mp4'
),
(
  'bulgarian_split_squat', 'Bulgar Split Squat', 'repBased', 'legs', 'advanced',
  ARRAY['lower_body'],
  10, NULL, 3, 50, false,
  'Arka ayağını yüksek bir yere koy, ön bacakla aşağı in ve patlayıcı şekilde kalk.',
  'Gövdeni dik tut.',
  'BulgarianSplitSquat.mp4'
),
(
  'leg_press', 'Leg Press', 'repBased', 'legs', 'intermediate',
  ARRAY['lower_body'],
  12, NULL, 3, 60, false,
  'Sırtını desteğe yasla, ayaklarını platforma sabitle ve dizleri kilitlemeden it.',
  'Topuklarını basılı tut.',
  'Legpress.mp4'
),
(
  'calf_raise', 'Calf Raise', 'timeBased', 'legs', 'beginner',
  ARRAY['lower_body'],
  NULL, 35, 3, 30, false,
  'Kalf kaldırma. Parmak uçlarında yüksel ve baldırlarını sık.',
  'Tepe noktasında 1 saniye sık.',
  'CalfRaise.mp4'
),
(
  'wall_sit', 'Wall Sit', 'timeBased', 'legs', 'beginner', ARRAY['lower_body'],
  NULL, 45, 3, 45, false,
  'Duvara oturuş. Sırtını duvara daya ve dizlerini doksan derece bükerek bekle.',
  'Topuğunla bas, çakılı kal.',
  'WallSit.mp4'
)
ON CONFLICT (slug) DO NOTHING;


-- ----------------------------- Back (5) -------------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'pull_up', 'Pull-up', 'repBased', 'back', 'advanced', ARRAY['upper_body'],
  8, NULL, 3, 60, false,
  'Bara avuçlar dışta tutun, kürek kemiklerini sıkarak çeneni bara çek.',
  'Önce kürekten çek.',
  'PullUp.mp4'
),
(
  'chin_up', 'Chin-up', 'repBased', 'back', 'advanced', ARRAY['upper_body'],
  8, NULL, 3, 60, false,
  'Avuç içlerin sana dönük, çeneni bara doğru kontrollü çek ve yavaşça in.',
  'Salınımdan kaçın.',
  'ChinUp.mp4'
),
(
  'lat_pulldown', 'Lat Pulldown', 'repBased', 'back', 'intermediate',
  ARRAY['upper_body'],
  12, NULL, 3, 50, false,
  'Otur, barı göğüs hizasına çek ve kürek kemiklerini birbirine sıkıştır.',
  'Önce sırt, sonra dirsek.',
  'LatPulldown.mp4'
),
(
  'barbell_row', 'Barbell Row', 'repBased', 'back', 'intermediate',
  ARRAY['upper_body'],
  12, NULL, 3, 60, false,
  'Sırtın nötr ve düz, halteri göbek hizana doğru kontrollü olarak çek.',
  'Sırtın yuvarlanmasın.',
  'BarbellRow.mp4'
),
(
  'superman', 'Superman', 'timeBased', 'back', 'beginner', ARRAY['upper_body'],
  NULL, 25, 3, 30, false,
  'Superman. Karın üstü yat, kollarını ve bacaklarını aynı anda havaya kaldır.',
  'Boynunu nötr tut.',
  'Superman.mp4'
)
ON CONFLICT (slug) DO NOTHING;


-- --------------------------- Shoulders (5) ----------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'shoulder_press', 'Shoulder Press', 'repBased', 'shoulders', 'intermediate',
  ARRAY['upper_body'],
  12, NULL, 3, 60, false,
  'Dambılları omuz hizasından kontrollü olarak tam yukarı it ve geri indir.',
  'Çekirdek sıkı, bilek nötr.',
  'ShoulderPress.mp4'
),
(
  'lateral_raise', 'Lateral Raise', 'repBased', 'shoulders', 'beginner',
  ARRAY['upper_body'],
  12, NULL, 3, 45, false,
  'Kollarını yana doğru omuz seviyesine kadar düz hâlde kontrollü kaldır.',
  'Trapeze değil, omuza yükle.',
  'LateralRaise.mp4'
),
(
  'front_raise', 'Front Raise', 'repBased', 'shoulders', 'beginner',
  ARRAY['upper_body'],
  12, NULL, 3, 45, false,
  'Kollarını öne doğru omuz seviyesine kadar düz hâlde kontrollü kaldır.',
  'Bel yaylanmasın.',
  'FrontRaise.mp4'
),
(
  'arnold_press', 'Arnold Press', 'repBased', 'shoulders', 'intermediate',
  ARRAY['upper_body'],
  10, NULL, 3, 60, false,
  'Dambılları yukarı iterken avuç içlerini içeriden dışarıya doğru çevir.',
  'Dirseğini kilitleme.',
  'ArnoldPress.mp4'
),
(
  'pike_push_up', 'Pike Şınav', 'repBased', 'shoulders', 'advanced',
  ARRAY['upper_body'],
  8, NULL, 3, 60, false,
  'Kalçanı yukarı kaldır, başını iki elin arasında inip çıkacak şekilde itele.',
  'Omuza odaklan, gövdeyi devirme.',
  'PikePushUp.mp4'
)
ON CONFLICT (slug) DO NOTHING;


-- ----------------------------- Arms (5) -------------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'biceps_curl', 'Biceps Curl', 'repBased', 'arms', 'beginner',
  ARRAY['upper_body'],
  12, NULL, 3, 45, false,
  'Dirseklerini gövdene sabitle, dambılı omuzuna doğru kontrollü olarak çek.',
  'Salınma, biceps çalışsın.',
  'BicepsCurl.mp4'
),
(
  'hammer_curl', 'Hammer Curl', 'repBased', 'arms', 'beginner',
  ARRAY['upper_body'],
  12, NULL, 3, 45, false,
  'Avuç içlerin içeriye dönük, dambılı omuza doğru kontrollü olarak çek.',
  'Bilek nötr kalsın.',
  'HammerCurl.mp4'
),
(
  'triceps_dip', 'Triceps Dip', 'repBased', 'arms', 'intermediate',
  ARRAY['upper_body'],
  10, NULL, 3, 60, false,
  'Sandalye/bar kenarında ellerin destekli; dirseklerini bükerek aşağı in ve geri kalk.',
  'Dirsek geriye, dışarı değil.',
  'TricepsDip.mp4'
),
(
  'triceps_pushdown', 'Triceps Pushdown', 'repBased', 'arms', 'beginner',
  ARRAY['upper_body'],
  12, NULL, 3, 50, false,
  'Dirseklerin gövdene sabit, halatı veya barı kontrollü olarak aşağı it.',
  'Sadece ön kol çalışsın.',
  'TricepsPushdown.mp4'
),
(
  'close_grip_push_up', 'Yakın Tutuş Şınav', 'repBased', 'arms', 'intermediate',
  ARRAY['upper_body'],
  10, NULL, 3, 60, false,
  'Ellerini daralt, dirseklerini gövdene yakın tutarak şınav hareketini uygula.',
  'Dirsek dışa kaçmasın.',
  'CloseGripPushUp.mp4'
)
ON CONFLICT (slug) DO NOTHING;


-- --------------------- Cardio & Full Body (5) -------------------------------
INSERT INTO public.exercises (
  slug, name, type, category, difficulty, target_muscles,
  target_reps, target_duration_in_seconds, sets, rest_duration_in_seconds,
  is_cardio, instructions, short_tip, video_url
) VALUES
(
  'burpee', 'Burpee', 'repBased', 'fullBody', 'advanced', ARRAY['full_body'],
  10, NULL, 3, 50, true,
  'Aşağı in, ellerin yere değdiğinde plank al, ayaklarını öne çekip patlayıcı zıpla.',
  'Sürekli ritim, mola yok.',
  'Burpee.mp4'
),
(
  'jumping_jack', 'Jumping Jack', 'timeBased', 'fullBody', 'beginner',
  ARRAY['cardio'],
  NULL, 30, 3, 30, true,
  'Aç-kapat hareketiyle aynı anda kollarını yukarı kaldırıp ritmik şekilde zıpla.',
  'Yumuşak ayak, sıkı çekirdek.',
  'JumpingJack.mp4'
),
(
  'high_knees', 'High Knees', 'timeBased', 'fullBody', 'beginner',
  ARRAY['cardio'],
  NULL, 30, 3, 30, true,
  'Diz çekme. Olduğun yerde dizlerini göğsüne doğru olabildiğince yüksek çek.',
  'Kollarını da çalıştır.',
  'HighKness.mp4'
),
(
  'jump_squat', 'Jump Squat', 'repBased', 'fullBody', 'intermediate',
  ARRAY['full_body'],
  12, NULL, 3, 45, true,
  'Squat pozisyonuna in, patlayıcı biçimde havaya zıpla ve yumuşak iniş yap.',
  'Sessiz iniş, sıkı çekirdek.',
  'JumpSquat.mp4'
),
(
  'skipping_rope', 'İp Atlama', 'timeBased', 'fullBody', 'beginner',
  ARRAY['cardio'],
  NULL, 45, 3, 30, true,
  'İp atlama. Temponu koru ve ayak uçlarında zıpla.',
  'Diz hafif bükülü, ip kısa.',
  'SkippingRope.mp4'
)
ON CONFLICT (slug) DO NOTHING;


-- =============================================================================
-- VERIFICATION QUERIES (optional — uncomment + run after applying)
-- =============================================================================
-- Confirm 41 rows landed:
--   SELECT count(*) FROM public.exercises;
--
-- Spot-check distribution per category:
--   SELECT category, count(*) FROM public.exercises GROUP BY category ORDER BY 1;
--
-- List all advanced movements:
--   SELECT slug, name, category FROM public.exercises
--    WHERE difficulty = 'advanced' ORDER BY category, slug;
--
-- Tail of inserted rows (sanity-check the trigger fired):
--   SELECT slug, updated_at FROM public.exercises ORDER BY updated_at DESC LIMIT 5;

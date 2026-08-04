-- ============================================================
-- 025 · The rotating challenge library
-- ============================================================
--
-- Roadmap Phase 14, feature 3: "beyond the single 30-day program:
-- 7-day kickstarts, 21-day habit builders, 60-day transformations,
-- body-part focuses, equipment-specific tracks."
--
-- `021` shipped six launch challenges, all of them open-ended windows
-- running to 2027. Those are the permanent floor. These seven are the
-- ROTATION: shorter windows, staggered starts, and a shape content ops
-- can copy monthly without asking an engineer anything.
--
-- ------------------------------------------------------------
-- WHAT IS AND IS NOT HERE, AND WHY
-- ------------------------------------------------------------
--
-- The roadmap's list has five kinds of challenge in it. Three of them
-- this engine can measure and two it cannot, and `021`'s header already
-- made that argument at length. Repeating the conclusion because it is
-- the part that matters:
--
--   * **7-day kickstarts** — `sessions` over a week. Measurable. ✅
--   * **21-day habit builders** — `streak`, which is exactly the habit
--     claim. Measurable. ✅
--   * **60-day transformations** — `sessions` over sixty days.
--     Measurable. ✅
--   * **Body-part focuses** — "three leg days a week" needs the engine
--     to know which muscle group a session trained. It does not: a
--     session is a session. ❌
--   * **Equipment-specific tracks** — same shape. Nothing records which
--     equipment a completed session used. ❌
--
-- The two refused ones are NOT dropped as ideas. They are the reason
-- `content_drops.target_levels` and `content_drops.requires_equipment`
-- exist in `024`: a body-part or equipment track ships as a **content
-- drop pointing at a plan**, which is an announcement the app can make
-- honestly, rather than as a challenge whose progress bar would never
-- move. A challenge that cannot count what it promised to count is
-- worse than no challenge — it tells the user they did nothing.
--
-- ------------------------------------------------------------
-- WHY THE WINDOWS ARE STAGGERED
-- ------------------------------------------------------------
--
-- Six challenges all starting on the first of the month means a user who
-- joins on the 20th has missed most of every one of them. The starts
-- below are spread across the quarter so somebody opening the screen on
-- any given week finds something that has only just begun.
--
-- Ending one early means moving `ends_at` into the past. NEVER delete
-- the row: `challenge_participants` cascades, and deleting erases the
-- record that people finished it.
--
-- Times are +03:00 (Europe/Istanbul), matching `021`.

insert into public.challenges
  (slug, kind, target, starts_at, ends_at, copy, badge_id, squad_scope)
values
  -- ---- 7-day kickstarts ------------------------------------
  (
    'kickstart_august',
    'sessions',
    4,
    '2026-08-05T00:00:00+03:00',
    '2026-08-12T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', '7-day kickstart',
        'body',  'Four sessions in seven days. Short enough to finish, long enough to feel.'
      ),
      'tr', jsonb_build_object(
        'title', '7 günlük başlangıç',
        'body',  'Yedi günde dört antrenman. Bitirebileceğin kadar kısa, hissettirecek kadar uzun.'
      )
    ),
    null,
    false
  ),
  (
    'kickstart_september',
    'sessions',
    4,
    '2026-09-02T00:00:00+03:00',
    '2026-09-09T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'Back-to-routine week',
        'body',  'Four sessions in seven days. September is the second January.'
      ),
      'tr', jsonb_build_object(
        'title', 'Rutine dönüş haftası',
        'body',  'Yedi günde dört antrenman. Eylül, yılın ikinci ocak ayıdır.'
      )
    ),
    null,
    false
  ),

  -- ---- 21-day habit builders -------------------------------
  --
  -- `streak`, not `sessions`. The claim of a habit builder is
  -- consecutive days, and counting sessions instead would let somebody
  -- do twenty-one workouts in a fortnight and call it a habit.
  (
    'habit_21_days',
    'streak',
    21,
    '2026-08-10T00:00:00+03:00',
    '2026-09-21T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', '21-day habit',
        'body',  'Twenty-one days in a row. Not the hardest challenge here — the one that changes what you are.'
      ),
      'tr', jsonb_build_object(
        'title', '21 günlük alışkanlık',
        'body',  'Üst üste yirmi bir gün. Buradaki en zor meydan okuma değil — seni değiştiren o.'
      )
    ),
    null,
    false
  ),
  (
    'habit_21_autumn',
    'streak',
    21,
    '2026-10-01T00:00:00+03:00',
    '2026-11-15T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'Autumn habit',
        'body',  'Twenty-one consecutive days, through the darkest part of the year.'
      ),
      'tr', jsonb_build_object(
        'title', 'Sonbahar alışkanlığı',
        'body',  'Yılın en karanlık kısmında üst üste yirmi bir gün.'
      )
    ),
    null,
    false
  ),

  -- ---- 60-day transformation -------------------------------
  (
    'transformation_60',
    'sessions',
    40,
    '2026-08-15T00:00:00+03:00',
    '2026-10-14T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', '60-day transformation',
        'body',  'Forty sessions in sixty days. This is the one people photograph the before for.'
      ),
      'tr', jsonb_build_object(
        'title', '60 günlük dönüşüm',
        'body',  'Altmış günde kırk antrenman. İnsanların "öncesi" fotoğrafını çektiği meydan okuma bu.'
      )
    ),
    null,
    false
  ),

  -- ---- Consistency, as a squad event -----------------------
  --
  -- The only squad-scoped one. Consistency is a ratio, so a squad of
  -- three training three days out of three beats a squad of twelve
  -- training five out of seven — which is the whole reason Phase 13
  -- declared it first in the metric enum.
  (
    'squad_consistency_autumn',
    'consistency',
    70,
    '2026-09-15T00:00:00+03:00',
    '2026-10-15T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'Squad consistency month',
        'body',  'Seventy percent, together. A small squad that shows up beats a big one that does not.'
      ),
      'tr', jsonb_build_object(
        'title', 'Takım tutarlılığı ayı',
        'body',  'Yüzde yetmiş, birlikte. Gelen küçük bir takım, gelmeyen büyük bir takımı yener.'
      )
    ),
    null,
    true
  ),

  -- ---- Seasonal --------------------------------------------
  (
    'new_year_2027',
    'sessions',
    12,
    '2027-01-01T00:00:00+03:00',
    '2027-01-31T23:59:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'January twelve',
        'body',  'Twelve sessions in January. Most resolutions die in week two; this one is built to survive it.'
      ),
      'tr', jsonb_build_object(
        'title', 'Ocak on iki',
        'body',  'Ocak ayında on iki antrenman. Kararların çoğu ikinci haftada ölür; bu onu atlatmak için kuruldu.'
      )
    ),
    null,
    false
  )
on conflict (slug) do update set
  -- Re-runnable. `slug` is unique, so a corrected window or a fixed
  -- typo is a re-run of this file rather than a hand-written UPDATE
  -- somebody has to get right at midnight. The same idempotence rule
  -- the recipe pipeline follows.
  kind        = excluded.kind,
  target      = excluded.target,
  starts_at   = excluded.starts_at,
  ends_at     = excluded.ends_at,
  copy        = excluded.copy,
  badge_id    = excluded.badge_id,
  squad_scope = excluded.squad_scope;

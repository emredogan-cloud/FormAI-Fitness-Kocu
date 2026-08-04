-- ============================================================
-- Launch challenges · Phase 14 (roadmap C25)
-- ============================================================
--
-- Run this once from the SQL editor. It is idempotent — `on conflict
-- (slug)` updates copy and targets, so re-running after an edit is the
-- normal way to change wording.
--
-- ------------------------------------------------------------
-- WHAT WAS *NOT* SEEDED, AND WHY IT MATTERS MORE THAN WHAT WAS
-- ------------------------------------------------------------
--
-- The brief suggested: First Workout · 7 Day Consistency · 30 Day
-- Transformation · Weekly Cardio · Strength Builder · Mobility Week ·
-- High Protein Week · Water Intake · Daily Stretch · Recovery Week.
--
-- **Six of those ten cannot be measured by this app**, and shipping them
-- anyway would put a progress bar on screen that never moves:
--
--   Weekly Cardio    needs per-exercise modality on a session. Sessions
--                    are logged as a day, not as a set of tagged
--                    movements.
--   Strength Builder needs load or volume per movement. `SessionLog`
--                    carries duration and exercise ids, not weight.
--   Mobility Week    same as cardio — needs a movement taxonomy.
--   Daily Stretch    same, plus a session type the programme does not
--                    emit.
--   High Protein Week needs logged intake. Nutrition ships recipes and
--                    plans; it does not record what was eaten.
--   Water Intake     there is no water tracker anywhere in the app.
--
-- The challenge engine measures exactly four things — `consistency`,
-- `sessions`, `streak`, `xp` — because those are the four the client can
-- state truthfully. **A challenge the app cannot track is a lie with a
-- progress bar**, and this codebase refuses that trade everywhere else:
-- an unresolvable badge id drops its feed row, a challenge with no
-- usable copy is dropped rather than shown as a slug, and the outcome
-- report will not claim a body change it was never told about.
--
-- What each of the six would need is written above so the decision is
-- reversible rather than forgotten. **Recovery Week** is the cheapest to
-- add later: it wants "sessions ≤ N", an inverted target, which is a
-- new `kind` rather than new tracking.
--
-- ------------------------------------------------------------
-- THE SIX THAT SHIPPED
-- ------------------------------------------------------------
--
-- Ordered by when a user meets them, not by importance.
--
--   1. first_workout      sessions 1     — activation. The single
--                                          highest-leverage moment in
--                                          the app; a user who finishes
--                                          one workout is a different
--                                          user from one who has not.
--   2. seven_day_streak   streak 7       — the habit threshold. Named
--                                          by the roadmap and already a
--                                          badge, so the challenge
--                                          reinforces rather than
--                                          competes.
--   3. twelve_this_month  sessions 12    — three a week, which is what
--                                          the programme actually asks
--                                          for. Achievable while
--                                          missing four days, which is
--                                          the point.
--   4. steady_sixty       consistency 60 — the beginner-winnable one.
--                                          Consistency is a ratio, so
--                                          somebody early in the
--                                          programme can lead it.
--   5. thousand_xp        xp 1000        — rewards breadth rather than
--                                          streaks, so a user whose
--                                          streak broke still has
--                                          something live.
--   6. full_programme     sessions 30    — the long arc. Deliberately
--                                          runs a full quarter so it
--                                          never expires under somebody
--                                          mid-way.
--
-- **Why six.** Enough that every kind of user has one they can win
-- today; few enough that the screen is a short list rather than a
-- catalogue. Four of the six are winnable in the first fortnight.
--
-- **No badge_id on any of them.** `badge_id` must match the client's
-- `kBadgeCatalog`, and inventing ids here would silently drop the award
-- (the client refuses an id it does not know). Wire real badges in a
-- release that adds them to the catalogue, then set the column.
--
-- **Windows are generous on purpose.** A challenge that ends while a
-- user is halfway through teaches them not to join the next one.

insert into public.challenges
  (slug, kind, target, starts_at, ends_at, copy, badge_id, squad_scope)
values
  (
    'first_workout',
    'sessions',
    1,
    '2026-08-01T00:00:00+03:00',
    '2027-08-01T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'Your first workout',
        'body',  'One session. That is the whole challenge — and it is the one that changes the most.'
      ),
      'tr', jsonb_build_object(
        'title', 'İlk antrenmanın',
        'body',  'Tek bir antrenman. Meydan okumanın tamamı bu — ve en çok fark yaratan da bu.'
      )
    ),
    null,
    false
  ),
  (
    'seven_day_streak',
    'streak',
    7,
    '2026-08-01T00:00:00+03:00',
    '2027-08-01T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'Seven in a row',
        'body',  'A week without a gap. This is where training stops being a decision you make every morning.'
      ),
      'tr', jsonb_build_object(
        'title', 'Üst üste yedi gün',
        'body',  'Arasız bir hafta. Antrenmanın her sabah yeniden karar verilen bir şey olmaktan çıktığı yer burası.'
      )
    ),
    null,
    false
  ),
  (
    'twelve_this_month',
    'sessions',
    12,
    '2026-08-01T00:00:00+03:00',
    '2026-12-01T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'Twelve this month',
        'body',  'Three a week, give or take. You can miss four days and still finish this.'
      ),
      'tr', jsonb_build_object(
        'title', 'Bu ay on iki',
        'body',  'Haftada üç, aşağı yukarı. Dört gün kaçırsan da bunu bitirebilirsin.'
      )
    ),
    null,
    false
  ),
  (
    'steady_sixty',
    'consistency',
    60,
    '2026-08-01T00:00:00+03:00',
    '2027-08-01T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'Sixty percent steady',
        'body',  'Train on three days out of five. Consistency is a ratio, so this is winnable from your first week.'
      ),
      'tr', jsonb_build_object(
        'title', 'Yüzde altmış istikrar',
        'body',  'Beş günün üçünde antrenman yap. İstikrar bir oran, yani ilk haftandan itibaren kazanılabilir.'
      )
    ),
    null,
    false
  ),
  (
    'thousand_xp',
    'xp',
    1000,
    '2026-08-01T00:00:00+03:00',
    '2027-08-01T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'A thousand XP',
        'body',  'Every workout, badge and milestone counts toward it. A broken streak does not set this back.'
      ),
      'tr', jsonb_build_object(
        'title', 'Bin XP',
        'body',  'Her antrenman, rozet ve kilometre taşı buna sayılır. Serinin bozulması bunu geri almaz.'
      )
    ),
    null,
    false
  ),
  (
    'full_programme',
    'sessions',
    30,
    '2026-08-01T00:00:00+03:00',
    '2027-08-01T00:00:00+03:00',
    jsonb_build_object(
      'en', jsonb_build_object(
        'title', 'The full thirty',
        'body',  'Every day of the programme. No deadline worth worrying about — take the year if you need it.'
      ),
      'tr', jsonb_build_object(
        'title', 'Otuzun tamamı',
        'body',  'Programın her günü. Endişelenecek bir son tarih yok — gerekirse bir yılını al.'
      )
    ),
    null,
    false
  )
on conflict (slug) do update
  set kind        = excluded.kind,
      target      = excluded.target,
      copy        = excluded.copy,
      starts_at   = excluded.starts_at,
      ends_at     = excluded.ends_at,
      squad_scope = excluded.squad_scope;

-- ------------------------------------------------------------
-- SEASONAL EVENTS — recommendations, not scheduled
-- ------------------------------------------------------------
--
-- All of these fit the existing engine. None is seeded, because when to
-- run one is a marketing decision with a date attached, and a challenge
-- sitting in the table three months early is clutter on a screen whose
-- whole virtue is being a short list.
--
--   New Year Reset      Jan 1 – Jan 31. `sessions`, target 15.
--                       The strongest of these by far — intent is
--                       already high and the app's job is to catch it.
--                       Frame it as a start, never as making up for
--                       anything.
--
--   Summer Cut          Jun 1 – Aug 31. `consistency`, target 70.
--                       CAREFUL. Name it after the behaviour, not the
--                       body. "Summer consistency" is the same
--                       challenge without the implied promise, and the
--                       store-compliance rule in
--                       `ai_personalization_engine.dart` already
--                       forbids quantified outcome claims. A challenge
--                       called "cut" that measures sessions is the same
--                       category of dishonesty this file refuses above.
--
--   Winter Bulk         Same caution, same fix: measure training, do
--                       not imply mass.
--
--   Ramadan             Whole month. `consistency`, target 40, and a
--                       LOWER target than usual on purpose. Training
--                       fasted is harder and the honest supportive move
--                       is a bar somebody can clear, not one that
--                       makes a hard month feel like a failure. Dates
--                       move ~11 days earlier each year — do not
--                       hardcode a recurring window.
--
--   Holiday Fitness     Dec 20 – Jan 2. `sessions`, target 4.
--                       Deliberately tiny. The goal over the holidays
--                       is not to lose the habit, and a demanding
--                       target is one people abandon and then feel bad
--                       about.
--
--   Anniversary         Around the app's launch date. `xp`, target
--                       2026 (the year). A number with a reason is more
--                       memorable than a round one.
--
--   Black Friday        DO NOT. A discount is not a challenge, and
--                       putting a commercial event on a surface whose
--                       currency is effort spends the trust that makes
--                       the other challenges work. Run the promotion
--                       through the paywall, where a user expects it.
--
-- One rule for all of them: **a seasonal challenge must be winnable by
-- somebody who joins on the last day it makes sense to join.** Otherwise
-- it is decoration, and users learn to ignore the shelf.

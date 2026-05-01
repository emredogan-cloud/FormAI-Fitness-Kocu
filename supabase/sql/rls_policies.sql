-- =============================================================================
-- Phase 43 (Phase 50A revision) · Supabase Row Level Security policies
-- =============================================================================
-- Locks the app's production tables down so that:
--
--   • `public.recipes`        — world-readable catalogue. Mutation is
--                               admin-only via a JWT app_metadata claim
--                               (Phase 50A) — service_role still bypasses
--                               RLS for backend scripts.
--   • `public.exercises`      — world-readable catalogue (Phase 50A). Mutation
--                               is admin-only via the same JWT claim.
--   • `public.user_progress`  — strictly self-scoped; `auth.uid()` must
--                               equal `user_id` on every read and write.
--
-- Copy this entire file into the Supabase SQL Editor and run once. It is
-- idempotent: every policy is preceded by a matching `DROP POLICY IF EXISTS`
-- so re-running replaces rather than duplicates. Safe to execute as
-- often as needed.
--
-- ROLE MODEL (Supabase default):
--   • `anon`          — API-key-only requests, no JWT. We DO let these read
--                       recipes + exercises (public catalogue), but NOT
--                       user_progress.
--   • `authenticated` — any valid JWT, including Supabase anonymous auth
--                       users. Primary readers of all three tables.
--   • `service_role`  — server-side scripts. Bypasses RLS entirely by
--                       default, so we do not declare policies for it.
--
-- ADMIN ROLE (Phase 50A):
--   Catalogue mutations (insert / update / delete recipes + exercises) are
--   gated on a JWT app_metadata claim:
--
--       auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'
--
--   To grant admin to a user from the Supabase dashboard:
--
--       Auth → Users → (pick user) → Raw user app metadata → JSON edit
--       Set: { "role": "admin" }
--
--   `app_metadata` (NOT `user_metadata`) is required because user_metadata
--   is user-mutable from the client, which would let any user grant
--   themselves admin. `app_metadata` can only be edited from a trusted
--   server context (dashboard, service_role calls, migrations) so it is
--   safe to gate mutations on it.
--
-- ROLLBACK: to revert to the fully-open state, run the `DISABLE ROW LEVEL
-- SECURITY` block at the bottom of this file (commented out by default).
-- =============================================================================


-- =============================================================================
-- SECTION 1 · public.recipes
-- =============================================================================
-- Read: open to everyone (anon + authenticated).
-- Write (Phase 50A): admin-only via JWT app_metadata claim. service_role
--   still bypasses RLS, so seed scripts (`supabase_seed_recipes.sql`,
--   etc.) keep working without a JWT.
-- =============================================================================

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recipes_public_read"  ON public.recipes;
DROP POLICY IF EXISTS "recipes_admin_insert" ON public.recipes;
DROP POLICY IF EXISTS "recipes_admin_update" ON public.recipes;
DROP POLICY IF EXISTS "recipes_admin_delete" ON public.recipes;

CREATE POLICY "recipes_public_read"
  ON public.recipes
  FOR SELECT
  TO authenticated, anon
  USING (true);

CREATE POLICY "recipes_admin_insert"
  ON public.recipes
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "recipes_admin_update"
  ON public.recipes
  FOR UPDATE
  TO authenticated
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  )
  WITH CHECK (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "recipes_admin_delete"
  ON public.recipes
  FOR DELETE
  TO authenticated
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );


-- =============================================================================
-- SECTION 2 · public.exercises (Phase 50A — new table)
-- =============================================================================
-- Mirrors the recipes policy: anyone can read the catalogue, admins
-- (JWT app_metadata role = 'admin') can author. Run
-- `supabase_exercises_migration.sql` first to create the table.
-- =============================================================================

ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "exercises_public_read"  ON public.exercises;
DROP POLICY IF EXISTS "exercises_admin_insert" ON public.exercises;
DROP POLICY IF EXISTS "exercises_admin_update" ON public.exercises;
DROP POLICY IF EXISTS "exercises_admin_delete" ON public.exercises;

CREATE POLICY "exercises_public_read"
  ON public.exercises
  FOR SELECT
  TO authenticated, anon
  USING (true);

CREATE POLICY "exercises_admin_insert"
  ON public.exercises
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "exercises_admin_update"
  ON public.exercises
  FOR UPDATE
  TO authenticated
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  )
  WITH CHECK (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

CREATE POLICY "exercises_admin_delete"
  ON public.exercises
  FOR DELETE
  TO authenticated
  USING (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );


-- =============================================================================
-- SECTION 3 · public.user_progress
-- =============================================================================
-- Every row is scoped to `user_id`. Supabase "anonymous auth" users get a
-- real `auth.uid()` when they call `signInAnonymously()`, so the same
-- `auth.uid() = user_id` predicate works for both guests and registered
-- users — they simply cannot see each other's rows.
--
-- `TO authenticated` deliberately omits the `anon` Postgres role, so
-- API-key-only requests (no JWT) are fully blocked from user_progress —
-- they can't leak another user's completion ledger.
-- =============================================================================

ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_progress_own_select" ON public.user_progress;
DROP POLICY IF EXISTS "user_progress_own_insert" ON public.user_progress;
DROP POLICY IF EXISTS "user_progress_own_update" ON public.user_progress;
DROP POLICY IF EXISTS "user_progress_own_delete" ON public.user_progress;

CREATE POLICY "user_progress_own_select"
  ON public.user_progress
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_progress_own_insert"
  ON public.user_progress
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_progress_own_update"
  ON public.user_progress
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_progress_own_delete"
  ON public.user_progress
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);


-- =============================================================================
-- SECTION 4 · Future schema — public.user_metrics (NOT YET APPLIED)
-- =============================================================================
-- Wizard output (weight, height, goal, activity level, diet prefs) is
-- currently kept in SharedPreferences on-device. Roadmap Phase 43 note:
-- multi-device sync + KVKK portability eventually need a server-side
-- copy. When we make that move we'll uncomment the block below. Schema
-- + policies are written here so the contract is reviewable now; the
-- Dart migration itself is deferred to a later phase so we don't ship
-- a half-finished sync path.
--
-- Notes on the schema:
--   • `user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`
--     — one row per user, auto-deleted when the account goes away (ties
--     the KVKK "delete my data" path to the auth.users row cleanup).
--   • `text` columns for everything free-form so we don't have to ship
--     enum migrations every time a wizard option is renamed.
--   • `updated_at` is maintained by the trigger at the bottom of the
--     block; the client can always `UPSERT` without worrying about it.
-- =============================================================================

/*
CREATE TABLE IF NOT EXISTS public.user_metrics (
  user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  gender           text,
  age              int,
  height_cm        int,
  weight_kg        int,
  current_physique text,
  target_physique  text,
  activity_level   text,
  diet_preference  text,
  allergies        text,
  meal_frequency   text,
  prep_time        text,
  created_at       timestamptz DEFAULT now(),
  updated_at       timestamptz DEFAULT now()
);

ALTER TABLE public.user_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_metrics_own_select" ON public.user_metrics;
DROP POLICY IF EXISTS "user_metrics_own_insert" ON public.user_metrics;
DROP POLICY IF EXISTS "user_metrics_own_update" ON public.user_metrics;
DROP POLICY IF EXISTS "user_metrics_own_delete" ON public.user_metrics;

CREATE POLICY "user_metrics_own_select"
  ON public.user_metrics
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "user_metrics_own_insert"
  ON public.user_metrics
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_metrics_own_update"
  ON public.user_metrics
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_metrics_own_delete"
  ON public.user_metrics
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Auto-bump `updated_at` on every UPDATE so the client's cache reconciler
-- has something monotonic to key against.
CREATE OR REPLACE FUNCTION public.user_metrics_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS user_metrics_touch_updated_at ON public.user_metrics;
CREATE TRIGGER user_metrics_touch_updated_at
  BEFORE UPDATE ON public.user_metrics
  FOR EACH ROW
  EXECUTE FUNCTION public.user_metrics_touch_updated_at();
*/


-- =============================================================================
-- VERIFICATION QUERIES (optional — uncomment and run after applying)
-- =============================================================================
-- List every policy currently attached to our tables:
--
--   SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
--   FROM pg_policies
--   WHERE schemaname = 'public'
--     AND tablename IN ('recipes', 'exercises', 'user_progress');
--
-- Confirm RLS is ON for all three tables:
--
--   SELECT relname, relrowsecurity
--   FROM pg_class
--   WHERE relname IN ('recipes', 'exercises', 'user_progress');
--
-- Smoke test from the Supabase SQL editor (runs as service_role, so the
-- expected result is all rows regardless of user_id):
--
--   SELECT count(*) FROM public.recipes;
--   SELECT count(*) FROM public.exercises;
--   SELECT count(*) FROM public.user_progress;
--
-- Verify the admin-claim guard works as expected (run as a non-admin
-- authenticated user — should error with "new row violates row-level
-- security policy"):
--
--   INSERT INTO public.exercises (slug, name, type, category, difficulty,
--     target_muscles, sets, rest_duration_in_seconds)
--     VALUES ('test_admin_block', 'should fail', 'repBased', 'core',
--             'beginner', ARRAY['core'], 3, 30);


-- =============================================================================
-- ROLLBACK BLOCK (emergency use only — leaves tables fully open)
-- =============================================================================
-- Uncomment every line in this block, then run. Re-applying the file above
-- restores the policies.
--
-- ALTER TABLE public.recipes       DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.exercises     DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.user_progress DISABLE ROW LEVEL SECURITY;
-- DROP POLICY IF EXISTS "recipes_public_read"        ON public.recipes;
-- DROP POLICY IF EXISTS "recipes_admin_insert"       ON public.recipes;
-- DROP POLICY IF EXISTS "recipes_admin_update"       ON public.recipes;
-- DROP POLICY IF EXISTS "recipes_admin_delete"       ON public.recipes;
-- DROP POLICY IF EXISTS "exercises_public_read"      ON public.exercises;
-- DROP POLICY IF EXISTS "exercises_admin_insert"     ON public.exercises;
-- DROP POLICY IF EXISTS "exercises_admin_update"     ON public.exercises;
-- DROP POLICY IF EXISTS "exercises_admin_delete"     ON public.exercises;
-- DROP POLICY IF EXISTS "user_progress_own_select"   ON public.user_progress;
-- DROP POLICY IF EXISTS "user_progress_own_insert"   ON public.user_progress;
-- DROP POLICY IF EXISTS "user_progress_own_update"   ON public.user_progress;
-- DROP POLICY IF EXISTS "user_progress_own_delete"   ON public.user_progress;

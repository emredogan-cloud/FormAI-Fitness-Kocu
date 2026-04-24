-- =============================================================================
-- Phase 43 · Supabase Row Level Security policies for SixPack AI
-- =============================================================================
-- Locks the app's two production tables down so that:
--
--   • `public.recipes`      — world-readable catalogue, mutation is
--                             service_role-only (admin panel / seed scripts).
--   • `public.user_progress` — strictly self-scoped; `auth.uid()` must
--                              equal `user_id` on every read and write.
--
-- Copy this entire file into the Supabase SQL Editor and run once. It is
-- idempotent: every policy is preceded by a matching `DROP POLICY IF EXISTS`
-- so re-running replaces rather than duplicates. Safe to execute as
-- often as needed.
--
-- ROLE MODEL (Supabase default):
--   • `anon`          — API-key-only requests, no JWT. We DO let these read
--                       recipes (public catalogue), but NOT user_progress.
--   • `authenticated` — any valid JWT, including Supabase anonymous auth
--                       users. These are the primary users of both tables.
--   • `service_role`  — server-side scripts. Bypasses RLS entirely by
--                       default, so we do not declare policies for it;
--                       admin mutations on `recipes` use this role.
--
-- ROLLBACK: to revert to the fully-open state, run the `DISABLE ROW LEVEL
-- SECURITY` block at the bottom of this file (commented out by default).
-- =============================================================================


-- =============================================================================
-- SECTION 1 · public.recipes
-- =============================================================================
-- Read: open to everyone.
-- Write: blocked for authenticated + anon (no matching policy). service_role
--        bypasses RLS so our seed scripts and future admin panel still work.
-- =============================================================================

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "recipes_public_read" ON public.recipes;

CREATE POLICY "recipes_public_read"
  ON public.recipes
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Note: no INSERT / UPDATE / DELETE policies are defined for authenticated
-- or anon. Without a matching permissive policy, Postgres denies the
-- operation. Admin writes must come from service_role (which bypasses
-- RLS) — that's the current `supabase_seed_recipes.sql` +
-- `supabase_seed_categories.sql` invocation model.


-- =============================================================================
-- SECTION 2 · public.user_progress
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
-- SECTION 3 · Future schema — public.user_metrics (NOT YET APPLIED)
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
--     AND tablename IN ('recipes', 'user_progress');
--
-- Confirm RLS is ON for both tables:
--
--   SELECT relname, relrowsecurity
--   FROM pg_class
--   WHERE relname IN ('recipes', 'user_progress');
--
-- Smoke test from the Supabase SQL editor (runs as service_role, so the
-- expected result is all rows regardless of user_id):
--
--   SELECT count(*) FROM public.recipes;
--   SELECT count(*) FROM public.user_progress;


-- =============================================================================
-- ROLLBACK BLOCK (emergency use only — leaves tables fully open)
-- =============================================================================
-- Uncomment every line in this block, then run. Re-applying the file above
-- restores the policies.
--
-- ALTER TABLE public.recipes       DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.user_progress DISABLE ROW LEVEL SECURITY;
-- DROP POLICY IF EXISTS "recipes_public_read"        ON public.recipes;
-- DROP POLICY IF EXISTS "user_progress_own_select"   ON public.user_progress;
-- DROP POLICY IF EXISTS "user_progress_own_insert"   ON public.user_progress;
-- DROP POLICY IF EXISTS "user_progress_own_update"   ON public.user_progress;
-- DROP POLICY IF EXISTS "user_progress_own_delete"   ON public.user_progress;

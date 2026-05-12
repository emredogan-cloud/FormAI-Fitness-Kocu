-- SixPack AI · phase 138 B-6 — admin storage RLS hardening
--
-- BACKGROUND
-- Table-level RLS on `public.recipes` and `public.exercises` is already
-- declared in `supabase/sql/rls_policies.sql` (Phase 50A) and gates
-- INSERT / UPDATE / DELETE on the JWT `app_metadata.role = 'admin'`
-- claim. That covers DATA mutations.
--
-- But the admin forms (`admin_recipe_form.dart`,
-- `admin_exercise_form.dart`) also upload IMAGES + VIDEOS to three
-- Supabase Storage buckets:
--   • recipes_images   — recipe hero photos
--   • exercises_media  — exercise videos / preview images
--   • exercises        — legacy exercise media bucket
--
-- Storage objects live in their own `storage.objects` table with its
-- own RLS. Phase 74's `fix_video_storage_rls.sql` opened SELECT (so
-- the player can read videos without auth), but it never gated
-- WRITE. As a result any authenticated user — including an
-- anonymous Supabase auth user — could `uploadBinary` into the
-- admin buckets and inject arbitrary recipe / exercise media.
--
-- This migration closes that gap by adding admin-gated INSERT /
-- UPDATE / DELETE policies on `storage.objects` for the three
-- buckets. SELECT stays public (videos / images must keep loading
-- for non-admins).
--
-- ROLLBACK: each policy uses `DROP POLICY IF EXISTS` so re-running
-- this file is safe; to remove the gate entirely, drop the four
-- write policies declared below.

begin;

-- =============================================================================
-- 1. Re-assert table-level admin policies (defensive, idempotent)
-- =============================================================================
-- These mirror `supabase/sql/rls_policies.sql`. Re-stating them here
-- means a clean DB whose only migration history is this file still
-- ends up with the right gates — handy if a future contributor
-- forgets to apply rls_policies.sql separately.
-- =============================================================================

alter table if exists public.recipes enable row level security;
alter table if exists public.exercises enable row level security;

drop policy if exists "recipes_admin_insert" on public.recipes;
create policy "recipes_admin_insert"
  on public.recipes
  for insert
  to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "recipes_admin_update" on public.recipes;
create policy "recipes_admin_update"
  on public.recipes
  for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "recipes_admin_delete" on public.recipes;
create policy "recipes_admin_delete"
  on public.recipes
  for delete
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "exercises_admin_insert" on public.exercises;
create policy "exercises_admin_insert"
  on public.exercises
  for insert
  to authenticated
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "exercises_admin_update" on public.exercises;
create policy "exercises_admin_update"
  on public.exercises
  for update
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists "exercises_admin_delete" on public.exercises;
create policy "exercises_admin_delete"
  on public.exercises
  for delete
  to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');


-- =============================================================================
-- 2. Storage RLS — admin-only write to admin buckets
-- =============================================================================
-- The Storage subsystem evaluates RLS on `storage.objects` rather than
-- on bucket-level flags. SELECT stays open (see Phase 74's
-- `fix_video_storage_rls.sql`) because the app must serve images and
-- videos to anon callers. WRITE is restricted to admins via the same
-- `app_metadata.role` claim as the table policies.
-- =============================================================================

-- Ensure the three admin buckets exist and are public for reads. The
-- ON CONFLICT branch keeps `public = true` consistent if the bucket
-- already exists with a different flag value.
insert into storage.buckets (id, name, public) values
  ('recipes_images', 'recipes_images', true),
  ('exercises_media', 'exercises_media', true),
  ('exercises', 'exercises', true)
on conflict (id) do update set public = true;

-- INSERT
drop policy if exists "admin_buckets_insert" on storage.objects;
create policy "admin_buckets_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id in ('recipes_images', 'exercises_media', 'exercises')
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

-- UPDATE
drop policy if exists "admin_buckets_update" on storage.objects;
create policy "admin_buckets_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id in ('recipes_images', 'exercises_media', 'exercises')
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  )
  with check (
    bucket_id in ('recipes_images', 'exercises_media', 'exercises')
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

-- DELETE
drop policy if exists "admin_buckets_delete" on storage.objects;
create policy "admin_buckets_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id in ('recipes_images', 'exercises_media', 'exercises')
    and (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

-- Re-state the Phase 74 public SELECT policy so this file is
-- self-contained for someone running migrations from scratch.
drop policy if exists "Public read exercise videos" on storage.objects;
create policy "Public read exercise videos"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id in ('exercises', 'exercises_media'));

drop policy if exists "Public read recipe images" on storage.objects;
create policy "Public read recipe images"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'recipes_images');

commit;

-- =============================================================================
-- Verification (run separately, NOT inside the transaction)
-- =============================================================================
-- 1. As a non-admin authenticated user, the following must fail with
--    "new row violates row-level security policy":
--
--      INSERT INTO public.exercises (id, name) VALUES ('rls_test', 'x');
--
-- 2. As a non-admin authenticated user, the following must fail with
--    a similar RLS rejection:
--
--      INSERT INTO storage.objects (bucket_id, name, owner)
--      VALUES ('exercises_media', 'rls_test.mp4', auth.uid());
--
-- 3. As the same user but with app_metadata.role='admin' on the JWT,
--    both inserts must succeed. Grant admin via:
--
--      Supabase Studio → Authentication → Users → (pick user) →
--      Raw user app metadata → JSON edit → { "role": "admin" }
--
-- 4. SELECT from `storage.objects` (and reads through the public
--    URL) must keep working as anon — exercise videos and recipe
--    images stay loading for unauthenticated users.
-- =============================================================================

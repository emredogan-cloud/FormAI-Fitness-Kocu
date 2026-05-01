-- =============================================================================
-- Phase 74 · open public read access on the exercise-video Storage buckets.
-- =============================================================================
-- Background: the PM reports workout video animations are not playing in
-- the app. The Flutter player path is fine — `video_player` is wired
-- through `VideoPlayerController.networkUrl` with a `flutter_cache_manager`
-- read-through cache and a loading/error UI in
-- `lib/features/workout/presentation/widgets/exercise_guide_player.dart`.
-- The most likely cause is that the Storage buckets the videos live in
-- are not marked public, so Supabase Storage returns 403 to the
-- anon-keyed network request the player makes.
--
-- Two buckets are in play:
--   • `exercises`        — legacy bucket the Phase 51 `MediaUrl.resolve`
--                          composes URLs against for catalogue rows
--                          whose `video_url` column stores a bare filename.
--   • `exercises_media`  — Phase 50 admin-form bucket used for
--                          PM-uploaded videos (full URLs land in the
--                          `video_url` column instead of bare filenames).
--
-- Both must be world-readable for unauthenticated playback to work.
--
-- How to run: paste this file into the Supabase SQL Editor and execute.
-- =============================================================================

BEGIN;

-- 1. Ensure both buckets exist and are flagged public. The bucket-level
--    `public` flag is the primary lever — when it's true, Supabase serves
--    objects through `/storage/v1/object/public/<bucket>/<path>` without
--    any auth header.
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('exercises', 'exercises', true),
  ('exercises_media', 'exercises_media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Belt-and-braces RLS policy on `storage.objects`. The bucket-level
--    public flag is the canonical path, but in some Supabase versions
--    a stale row-level policy on storage.objects can still 403 the
--    request. An explicit SELECT policy makes the intent unambiguous
--    and is idempotent thanks to the DROP IF EXISTS.
DROP POLICY IF EXISTS "Public read exercise videos" ON storage.objects;
CREATE POLICY "Public read exercise videos"
  ON storage.objects FOR SELECT
  TO anon, authenticated
  USING (bucket_id IN ('exercises', 'exercises_media'));

COMMIT;

-- =============================================================================
-- Sanity check (run separately after COMMIT):
-- =============================================================================
-- SELECT id, public FROM storage.buckets
-- WHERE id IN ('exercises', 'exercises_media');
-- -- both rows should show public = true
--
-- Then in a terminal try:
--   curl -I https://<project>.supabase.co/storage/v1/object/public/exercises/<filename>
-- -- should return 200, not 403/401.

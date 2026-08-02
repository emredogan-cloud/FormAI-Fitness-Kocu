-- FormAI — progress photo METADATA. Never the photograph.
--
-- Roadmap Phase 10 (C2, P6) · "private on-device progress photos with
-- before/after compare".
--
-- WHY THIS IS 018 AND NOT 014
--
-- The roadmap calls this file `014_progress_photos_meta.sql`. 014 is
-- taken — it is Phase 7's `recipe_ingredients`, applied to production —
-- as are 013 and 015. 016 is RESERVED for the deliberately unwritten
-- `016_drop_legacy_tags.sql`, which four documents describe by that
-- exact filename as "not written on purpose", and 017 is Phase 9's
-- `body_metrics`. Renumbering to close a gap would break every one of
-- those references and invite somebody to think the drop had been done.
-- The gap is cheaper than the confusion. Same reasoning as 017's header.
--
-- WHAT THIS TABLE IS FOR, AND WHAT IT IS NOT FOR
--
-- The feature is complete WITHOUT this migration. Photos live in the
-- app's private documents directory and their index lives in
-- SharedPreferences; `ProgressPhotoRepository` has no network code at
-- all, and a test refuses to let any appear. Nothing on the device needs
-- a server round trip to capture, list, compare or delete a photo.
--
-- This table exists so that a user who has EXPLICITLY opted into cross-
-- device carry can be told, on a new handset, that eleven photographs
-- exist and which handset has them. It stores:
--
--   • when the photo was taken
--   • which pose it is
--   • a HASH of the local filename
--
-- and it stores no image bytes, no file path, no thumbnail, no
-- dimensions, no EXIF, and no reference to a storage bucket. There is no
-- bucket. `cloud_ref` is nullable and stays null unless and until an
-- opt-in backup feature is built, at which point it names an object in a
-- bucket the user asked for — and that feature belongs in a separate
-- service, never as a branch inside the repository.
--
-- `local_name_hash` is a hash rather than the name because the name
-- encodes a timestamp and a pose, and a row that already carries both
-- would gain nothing from repeating them in a form that also survives
-- being read by somebody who should not be reading it. Its only job is
-- to let a device answer "do I already have this one?".
--
-- APPLYING THIS IS OPTIONAL AND SEPARATE
--
-- Like 017, this is written and NOT applied. The app does not read or
-- write it yet. Applying it is a safe, independent step whenever the
-- founder wants the cross-device notice; nothing regresses if it never
-- happens.

create table if not exists public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,

  -- A moment, not a date. Three poses can be captured a minute apart and
  -- a comparison wants them ordered. (Contrast `body_metrics`, where
  -- `recorded_on` is a date because a body weight is a daily
  -- observation.)
  recorded_at timestamptz not null,

  -- 'front' | 'side' | 'back'. Constrained rather than an enum type so
  -- adding a pose later is a one-line alter rather than a type
  -- migration; the app treats an unknown token as 'front'.
  pose text not null check (pose in ('front', 'side', 'back')),

  -- Identifies the local file without disclosing it. See the header.
  local_name_hash text not null,

  -- Null forever unless the user opts into a backup that does not exist
  -- yet. Present now so that adding it later is not a migration on a
  -- table users already have rows in.
  cloud_ref text,

  created_at timestamptz not null default now(),

  -- One row per photo. Re-registering the same local file is an update,
  -- not a duplicate — the same idempotency rule the recipe seeds use.
  unique (user_id, local_name_hash)
);

create index if not exists progress_photos_user_recorded_idx
  on public.progress_photos (user_id, recorded_at desc);

alter table public.progress_photos enable row level security;

-- Four separate policies rather than one `for all`: a photograph is the
-- most sensitive row this schema holds, and "which operations is a user
-- allowed" should be legible one line at a time.
drop policy if exists progress_photos_select_own on public.progress_photos;
create policy progress_photos_select_own
  on public.progress_photos for select
  using (auth.uid() = user_id);

drop policy if exists progress_photos_insert_own on public.progress_photos;
create policy progress_photos_insert_own
  on public.progress_photos for insert
  with check (auth.uid() = user_id);

drop policy if exists progress_photos_update_own on public.progress_photos;
create policy progress_photos_update_own
  on public.progress_photos for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists progress_photos_delete_own on public.progress_photos;
create policy progress_photos_delete_own
  on public.progress_photos for delete
  using (auth.uid() = user_id);

comment on table public.progress_photos is
  'Progress photo METADATA only. Image bytes never leave the device; '
  'there is no storage bucket. See the migration header.';
comment on column public.progress_photos.local_name_hash is
  'Hash of the on-device filename. Lets a device answer "do I have this '
  'one?" without disclosing anything about the photograph.';
comment on column public.progress_photos.cloud_ref is
  'Null unless the user has explicitly opted into a backup feature that '
  'does not exist yet.';

-- ACCOUNT DELETION
--
-- `on delete cascade` on `user_id` is what removes these rows when
-- `delete_user` deletes the auth row, so `006_delete_user.sql` needs no
-- change. The half it CANNOT reach is the handset: the documents
-- directory survives both the RPC and `prefs.clear()`. That is why
-- `AuthController.deleteAccount` calls
-- `ProgressPhotoRepository.deleteEverything()`, and why
-- `auth_delete_account_test.dart` asserts it does.

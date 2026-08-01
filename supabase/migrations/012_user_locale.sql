-- FormAI — carry the language choice across a reinstall
--
-- Roadmap Phase 6 (R3.2, "smart default + override memory"). The device
-- copy in SharedPreferences stays authoritative for the running app;
-- this column exists for exactly one case — a user who picked English,
-- reinstalled, and landed on a Turkish-locale phone. Without it their
-- choice is gone and they have to make it again.
--
-- Lives on `user_metrics` rather than a new table because that row
-- already exists per user, is already RLS'd to its owner, and is
-- already upserted on `user_id` by the referral service. A second
-- one-column table would need its own policies and its own migration
-- discipline to say the same thing.

alter table public.user_metrics
  add column if not exists locale text;

-- 'system' is a real, storable value, not a null stand-in: it records
-- "this user explicitly chose to follow their device", which must not
-- be re-adopted as a language on the next install. Null means the user
-- has never been asked. The check keeps a typo in a future client from
-- writing a value `LocaleNotifier.decode` will silently discard.
alter table public.user_metrics
  drop constraint if exists user_metrics_locale_supported;
alter table public.user_metrics
  add constraint user_metrics_locale_supported
  check (locale is null or locale in ('system', 'tr', 'en'));

comment on column public.user_metrics.locale is
  'Language preference: ''system'' (follow device), or a supported '
  'language code. Null = never chosen. Mirrors sixpack.locale on device; '
  'the device copy wins while the app is running.';

-- No index. The column is only ever read by `select locale where
-- user_id = ?`, which the existing unique constraint on user_id already
-- serves.

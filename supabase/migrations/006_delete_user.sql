-- 006 · delete_user() RPC — in-app account deletion (KVKK Art.7 /
-- GDPR Art.17 / Apple 5.1.1(v) / Google Play data-deletion).
--
-- Called by AuthController.deleteAccount()
-- (lib/features/auth/providers/auth_provider.dart) via
-- `rpc('delete_user')`. Deletes the caller's own auth.users row;
-- ON DELETE CASCADE on user-scoped tables (user_progress,
-- user_metrics, feedback, referrals, video-analysis tables) removes
-- the user's data with it.
--
-- SECURITY: definer function, locked to the caller's own uid; EXECUTE
-- revoked from public and granted to authenticated only.
--
-- NOTE · shipping this file makes the function part of the migration
-- history; it must ALSO be applied to the production project
-- (supabase db push / SQL editor) before release — the client already
-- calls it, and without it "Hesabımı Sil" fails at runtime.

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_user() from public;
grant execute on function public.delete_user() to authenticated;

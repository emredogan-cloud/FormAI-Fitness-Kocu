-- 007 · referrals table + redeem_referral() RPC.
--
-- Called by ReferralService.redeem()
-- (lib/features/referral/services/referral_service.dart) via
-- `rpc('redeem_referral', params: {'referrer_code': ...})`. Records
-- who invited whom; each invitee can redeem exactly one code.
--
-- Reward delivery (Pro entitlement grant to both sides) is
-- intentionally NOT part of this migration — it happens post-launch
-- via RevenueCat promotional entitlements (manual or webhook-driven).
-- Client copy was updated to promise only what this table delivers:
-- the code is recorded, rewards follow when the program activates.
--
-- NOTE · must be applied to the production project before release —
-- the client already calls the RPC.

create table if not exists public.referrals (
  id            uuid primary key default gen_random_uuid(),
  referrer_id   uuid not null references auth.users(id) on delete cascade,
  invitee_id    uuid not null references auth.users(id) on delete cascade,
  referrer_code text not null,
  redeemed_at   timestamptz not null default now(),
  unique (invitee_id) -- each invitee may redeem only one code
);

alter table public.referrals enable row level security;

create policy "referrals_self_read"
  on public.referrals
  for select
  to authenticated
  using (auth.uid() = referrer_id or auth.uid() = invitee_id);

-- Invitee records the referrer's code. Raises:
--   invalid_code   — no user owns that code
--   self_referral  — user tried their own code
--   unique_violation (23505) — invitee already redeemed a code
create or replace function public.redeem_referral(referrer_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer uuid;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  select id into v_referrer
  from auth.users
  where (raw_user_meta_data ->> 'referral_code')
        = upper(redeem_referral.referrer_code)
  limit 1;

  if v_referrer is null then
    raise exception 'invalid_code';
  end if;

  if v_referrer = auth.uid() then
    raise exception 'self_referral';
  end if;

  insert into public.referrals (referrer_id, invitee_id, referrer_code)
  values (v_referrer, auth.uid(), upper(redeem_referral.referrer_code));
end;
$$;

revoke all on function public.redeem_referral(text) from public;
grant execute on function public.redeem_referral(text) to authenticated;

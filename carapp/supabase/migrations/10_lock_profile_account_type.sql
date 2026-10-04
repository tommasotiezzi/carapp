-- 10_lock_profile_account_type.sql
--
-- profiles_update_own lets a user update their own row, account_type
-- included (known gap in 04_rls.sql). account_type must change only
-- server-side (dealer-signup Edge Function, service role). This trigger
-- rejects the change when it comes from the app (anon / authenticated).
-- Run once in the Supabase SQL editor.

create or replace function public.protect_profile_account_type()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.account_type is distinct from old.account_type
     and current_user in ('anon', 'authenticated') then
    raise exception 'account_type can only be changed by the server'
      using errcode = '42501';  -- insufficient_privilege, like an RLS refusal
  end if;
  return new;
end;
$$;

drop trigger if exists protect_account_type on public.profiles;

create trigger protect_account_type
  before update on public.profiles
  for each row execute function public.protect_profile_account_type();

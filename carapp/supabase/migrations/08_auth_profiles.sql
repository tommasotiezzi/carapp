-- 08_auth_profiles.sql
-- Creates a profile row automatically for every new user (email login included).
-- Run once in the SQL editor.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Users created before this trigger existed (e.g. dev@carfeed.test)
insert into public.profiles (id)
select id from auth.users
on conflict (id) do nothing;
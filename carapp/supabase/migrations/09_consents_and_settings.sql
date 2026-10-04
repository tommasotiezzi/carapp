-- 09_consents_and_settings.sql
--
-- Legal consents (proof of acceptance), optional profile info for the
-- settings screen, versions of the legal documents.
-- Run once in the Supabase SQL editor.

-- ---------------------------------------------------------------------
-- Consents: append-only log. Each row is one decision, with the version
-- of the document shown. The latest row per kind is the current state.
-- ---------------------------------------------------------------------

create type public.consent_kind as enum (
  'terms',            -- Termini e condizioni (required to sign up)
  'privacy',          -- Informativa privacy read (required to sign up)
  'age_14',           -- declares to be at least 14 (required to sign up)
  'marketing_email'   -- promotional emails (optional, off by default)
);

create table public.user_consents (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  kind public.consent_kind not null,
  granted boolean not null,
  document_version text,
  platform public.platform,
  created_at timestamptz not null default now()
);

create index user_consents_profile_kind_idx
  on public.user_consents (profile_id, kind, created_at desc);

alter table public.user_consents enable row level security;

create policy "user_consents: read own"
  on public.user_consents for select
  using (profile_id = (select auth.uid()));

create policy "user_consents: insert own"
  on public.user_consents for insert
  with check (profile_id = (select auth.uid()));

-- No update / delete policy: the log is the proof, it is never rewritten.

-- Latest decision per kind (RLS of user_consents applies).
create view public.current_consents
  with (security_invoker = true) as
  select distinct on (profile_id, kind)
    profile_id, kind, granted, document_version, created_at
  from public.user_consents
  order by profile_id, kind, created_at desc;

-- ---------------------------------------------------------------------
-- Optional profile info (settings screen, never required).
-- ---------------------------------------------------------------------

create type public.gender as enum ('female', 'male', 'other', 'undisclosed');

alter table public.profiles
  add column birth_date date,
  add column gender public.gender,
  add constraint profiles_birth_date_range check (birth_date is null or birth_date >= date '1900-01-01');

-- ---------------------------------------------------------------------
-- Legal documents: URLs (placeholders until the real ones exist) and
-- versions. Bump a version when its text changes: signed-in users are
-- asked to accept again. Existing URLs are kept.
-- ---------------------------------------------------------------------

insert into public.app_config (key, value, is_public)
values (
  'legal',
  jsonb_build_object(
    'terms_url', 'https://carfeed.app/termini',
    'privacy_policy_url', 'https://carfeed.app/privacy',
    'support_email', 'supporto@carfeed.app',
    'terms_version', '1',
    'privacy_version', '1'
  ),
  true
)
on conflict (key) do update
  set value = jsonb_build_object(
        'terms_url', 'https://carfeed.app/termini',
        'privacy_policy_url', 'https://carfeed.app/privacy',
        'support_email', 'supporto@carfeed.app'
      )
      || public.app_config.value
      || jsonb_build_object('terms_version', '1', 'privacy_version', '1');

update public.app_config
  set value = to_jsonb((value #>> '{}')::int + 1)
  where key = 'config_version';

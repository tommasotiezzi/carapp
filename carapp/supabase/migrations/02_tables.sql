-- 02_tables.sql
-- Tables, in foreign-key order. Run after 01_enums.sql.

create extension if not exists postgis with schema extensions;
create extension if not exists moddatetime with schema extensions;

-- ============================================================
-- USERS
-- ============================================================

-- One row per registered person (consumer or dealer staff)
create table public.profiles (
  id                       uuid primary key references auth.users (id) on delete cascade,
  account_type             public.account_type not null default 'consumer',
  intent                   public.user_intent,
  display_name             text check (char_length(display_name) <= 60),
  avatar_path              text,
  phone                    text,
  whatsapp_public          boolean not null default false,
  city                     text,
  location                 extensions.geography(point, 4326),
  locale                   text not null default 'it',
  onboarding_completed_at  timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

-- Optional buyer preferences from onboarding, editable from the profile.
-- Everything nullable: the user can skip all of it.
create table public.buyer_preferences (
  profile_id        uuid primary key references public.profiles (id) on delete cascade,
  category_ids      text[],
  make_ids          uuid[],
  price_min_cents   integer check (price_min_cents >= 0),
  price_max_cents   integer check (price_max_cents >= 0),
  year_min          smallint,
  mileage_max_km    integer check (mileage_max_km >= 0),
  fuel_types        public.fuel_type[],
  max_distance_km   integer check (max_distance_km > 0),
  novice_driver     boolean,
  updated_at        timestamptz not null default now()
);

-- ============================================================
-- DEALERS
-- ============================================================

create table public.dealers (
  id               uuid primary key default gen_random_uuid(),
  legal_name       text not null,
  display_name     text not null,
  vat_number       text not null unique,
  vat_verified_at  timestamptz,
  vies_payload     jsonb,
  address          text,
  city             text,
  province         text,
  location         extensions.geography(point, 4326),
  phone            text,
  whatsapp         text,
  website          text,
  logo_path        text,
  description      text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table public.dealer_members (
  dealer_id   uuid not null references public.dealers (id) on delete cascade,
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  role        public.dealer_role not null default 'seller',
  created_at  timestamptz not null default now(),
  primary key (dealer_id, profile_id)
);

-- ============================================================
-- PLANS & SUBSCRIPTIONS (ready from day 0, billing off via app_config)
-- ============================================================

create table public.plans (
  id           text primary key,              -- 'base', 'pro'
  name         text not null,
  price_cents  integer,                       -- null = price not decided yet
  currency     text not null default 'EUR',
  limits       jsonb not null default '{}',   -- see 05_seed.sql
  is_active    boolean not null default true,
  sort_order   smallint not null default 0
);

create table public.subscriptions (
  id                     uuid primary key default gen_random_uuid(),
  dealer_id              uuid not null unique references public.dealers (id) on delete cascade,
  plan_id                text not null references public.plans (id),
  status                 public.subscription_status not null default 'trial',
  trial_started_at       timestamptz not null default now(),
  trial_ends_at          timestamptz,
  conditional_ends_at    timestamptz,
  contact_threshold      integer,             -- total contacts since signup that end the conditional period
  founder_price_cents    integer,             -- locked price for founding dealers
  is_founder             boolean not null default false,
  billing_method         public.billing_method not null default 'manual_invoice',
  current_period_start   timestamptz,
  current_period_end     timestamptz,
  canceled_at            timestamptz,
  notes                  text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

-- ============================================================
-- CATALOGUE
-- ============================================================

-- Adding a category = one row, no app release
create table public.vehicle_categories (
  id                 text primary key,           -- 'car', 'motorcycle'
  name_key           text not null,              -- i18n key used by the app
  attributes_schema  jsonb not null default '{}',
  capture_steps      jsonb not null default '[]',
  is_visible         boolean not null default true,
  sort_order         smallint not null default 0
);

create table public.makes (
  id           uuid primary key default gen_random_uuid(),
  category_id  text not null references public.vehicle_categories (id),
  name         text not null,
  slug         text not null,
  is_popular   boolean not null default false,
  unique (category_id, slug)
);

create table public.models (
  id       uuid primary key default gen_random_uuid(),
  make_id  uuid not null references public.makes (id) on delete cascade,
  name     text not null,
  slug     text not null,
  unique (make_id, slug)
);

-- ============================================================
-- LISTINGS
-- ============================================================

create table public.listings (
  id                   uuid primary key default gen_random_uuid(),
  seller_type          public.seller_type not null,
  owner_id             uuid not null references public.profiles (id) on delete cascade,
  dealer_id            uuid references public.dealers (id) on delete cascade,
  category_id          text not null references public.vehicle_categories (id),
  make_id              uuid references public.makes (id),
  model_id             uuid references public.models (id),
  version              text,
  year                 smallint check (year between 1900 and 2100),
  mileage_km           integer check (mileage_km >= 0),
  price_cents          integer check (price_cents >= 0),
  currency             text not null default 'EUR',
  fuel_type            public.fuel_type,
  transmission         public.transmission_type,
  power_kw             smallint check (power_kw >= 0),
  euro_class           smallint check (euro_class between 0 and 6),
  color                text,
  owners_count         smallint check (owners_count >= 0),
  has_service_history  boolean,
  warranty_months      smallint check (warranty_months >= 0),
  attributes           jsonb not null default '{}',   -- category-specific fields
  description          text check (char_length(description) <= 3000),
  city                 text,
  province             text,
  location             extensions.geography(point, 4326),
  whatsapp_enabled     boolean not null default false,
  status               public.listing_status not null default 'draft',
  published_at         timestamptz,
  last_confirmed_at    timestamptz,
  expires_at           timestamptz,
  sold_at              timestamptz,
  sponsored_until      timestamptz,
  cover_path           text,
  video_path           text,
  video_duration_ms    integer,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  constraint listings_seller_consistency check (
    (seller_type = 'dealer'  and dealer_id is not null) or
    (seller_type = 'private' and dealer_id is null)
  )
);

create table public.listing_media (
  id            uuid primary key default gen_random_uuid(),
  listing_id    uuid not null references public.listings (id) on delete cascade,
  kind          public.media_kind not null,
  capture_step  text,                 -- matches vehicle_categories.capture_steps[].id
  storage_path  text not null,        -- random UUID path, never derived from user ids
  width         integer,
  height        integer,
  duration_ms   integer,
  size_bytes    bigint,
  sort_order    smallint not null default 0,
  created_at    timestamptz not null default now()
);

-- Drives price-drop notifications and the "below average" badge
create table public.listing_price_history (
  id           bigint generated always as identity primary key,
  listing_id   uuid not null references public.listings (id) on delete cascade,
  price_cents  integer not null,
  changed_at   timestamptz not null default now()
);

-- Q&A: questions arrive privately, the seller can make an answer public
create table public.listing_questions (
  id           uuid primary key default gen_random_uuid(),
  listing_id   uuid not null references public.listings (id) on delete cascade,
  asker_id     uuid references public.profiles (id) on delete set null,
  question     text not null check (char_length(question) <= 500),
  answer       text check (char_length(answer) <= 1000),
  answered_at  timestamptz,
  is_public    boolean not null default false,
  created_at   timestamptz not null default now()
);

-- ============================================================
-- BUYER ACTIONS
-- ============================================================

create table public.favorites (
  profile_id            uuid not null references public.profiles (id) on delete cascade,
  listing_id            uuid not null references public.listings (id) on delete cascade,
  price_cents_at_save   integer,
  created_at            timestamptz not null default now(),
  primary key (profile_id, listing_id)
);

create table public.saved_searches (
  id                uuid primary key default gen_random_uuid(),
  profile_id        uuid not null references public.profiles (id) on delete cascade,
  name              text,
  filters           jsonb not null,
  notify            boolean not null default true,
  last_notified_at  timestamptz,
  created_at        timestamptz not null default now()
);

-- ============================================================
-- CHAT
-- ============================================================

create table public.conversations (
  id                   uuid primary key default gen_random_uuid(),
  listing_id           uuid not null references public.listings (id) on delete cascade,
  buyer_id             uuid not null references public.profiles (id) on delete cascade,
  seller_id            uuid not null references public.profiles (id) on delete cascade,
  dealer_id            uuid references public.dealers (id) on delete cascade,
  last_message_at      timestamptz,
  buyer_last_read_at   timestamptz,
  seller_last_read_at  timestamptz,
  created_at           timestamptz not null default now(),
  unique (listing_id, buyer_id),
  check (buyer_id <> seller_id)
);

create table public.messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  sender_id        uuid not null references public.profiles (id) on delete cascade,
  body             text not null check (char_length(body) between 1 and 2000),
  created_at       timestamptz not null default now()
);

-- ============================================================
-- TRUST
-- ============================================================

-- Only buyers who actually contacted the dealer can review
create table public.reviews (
  id               uuid primary key default gen_random_uuid(),
  dealer_id        uuid not null references public.dealers (id) on delete cascade,
  author_id        uuid not null references public.profiles (id) on delete cascade,
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  rating           smallint not null check (rating between 1 and 5),
  body             text check (char_length(body) <= 1000),
  created_at       timestamptz not null default now(),
  unique (dealer_id, author_id)
);

-- Notice-and-action for listings (DSA)
create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  listing_id   uuid not null references public.listings (id) on delete cascade,
  reporter_id  uuid references public.profiles (id) on delete set null,
  reason       public.report_reason not null,
  details      text check (char_length(details) <= 1000),
  status       public.report_status not null default 'open',
  created_at   timestamptz not null default now(),
  reviewed_at  timestamptz
);

-- ============================================================
-- ANALYTICS
-- ============================================================

-- Append-only, sent by the app in batches. Never read by the app directly.
create table public.events (
  id          bigint generated always as identity primary key,
  listing_id  uuid references public.listings (id) on delete cascade,
  profile_id  uuid references public.profiles (id) on delete set null,
  anon_id     uuid,
  session_id  uuid,
  type        public.event_type not null,
  value       numeric,                 -- e.g. watch time in ms
  platform    public.platform,
  created_at  timestamptz not null default now()
);

-- Nightly aggregates: the dealer dashboard reads only this
create table public.listing_stats_daily (
  listing_id         uuid not null references public.listings (id) on delete cascade,
  day                date not null,
  impressions        integer not null default 0,
  views              integer not null default 0,
  unique_viewers     integer not null default 0,
  watch_time_ms      bigint  not null default 0,
  zooms              integer not null default 0,
  detail_opens       integer not null default 0,
  saves              integer not null default 0,
  shares             integer not null default 0,
  contacts_chat      integer not null default 0,
  contacts_whatsapp  integer not null default 0,
  primary key (listing_id, day)
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  type        public.notification_type not null,
  listing_id  uuid references public.listings (id) on delete cascade,
  payload     jsonb not null default '{}',
  read_at     timestamptz,
  pushed_at   timestamptz,               -- set when push delivery is added
  created_at  timestamptz not null default now()
);

-- Missing row = enabled (default on)
create table public.notification_preferences (
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  type        public.notification_type not null,
  enabled     boolean not null default true,
  primary key (profile_id, type)
);

-- device_tokens comes later, together with push delivery.

-- ============================================================
-- APP CONFIG
-- ============================================================

-- Key/value config fetched once at startup and cached;
-- the app re-fetches only when 'config_version' changes.
create table public.app_config (
  key          text primary key,
  value        jsonb not null,
  is_public    boolean not null default true,
  description  text,
  updated_at   timestamptz not null default now()
);

-- ============================================================
-- updated_at triggers
-- ============================================================

create trigger set_updated_at before update on public.profiles
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger set_updated_at before update on public.buyer_preferences
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger set_updated_at before update on public.dealers
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger set_updated_at before update on public.subscriptions
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger set_updated_at before update on public.listings
  for each row execute procedure extensions.moddatetime (updated_at);
create trigger set_updated_at before update on public.app_config
  for each row execute procedure extensions.moddatetime (updated_at);
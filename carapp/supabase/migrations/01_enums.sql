-- 01_enums.sql
-- Enum types. Run first.

create type public.account_type as enum ('consumer', 'dealer_member');

-- What the user said they want to do during onboarding
create type public.user_intent as enum ('buy', 'sell', 'browse', 'dealer');

create type public.seller_type as enum ('private', 'dealer');

create type public.listing_status as enum ('draft', 'active', 'sold', 'expired', 'removed');

create type public.media_kind as enum ('video', 'photo', 'cover');

create type public.fuel_type as enum (
  'petrol', 'diesel', 'hybrid', 'plugin_hybrid', 'electric', 'lpg', 'cng', 'other'
);

create type public.transmission_type as enum ('manual', 'automatic', 'semi_automatic');

create type public.dealer_role as enum ('owner', 'seller');

-- trial            = months 1-3, free for everyone
-- conditional_free = months 4-6, free unless the monthly contact threshold is exceeded
-- active           = paying
create type public.subscription_status as enum (
  'trial', 'conditional_free', 'active', 'past_due', 'canceled'
);

create type public.billing_method as enum ('manual_invoice', 'card');

create type public.event_type as enum (
  'impression', 'view', 'watch_time', 'zoom', 'open_detail',
  'save', 'unsave', 'share', 'contact_chat', 'contact_whatsapp'
);

create type public.notification_type as enum (
  'new_message', 'price_drop', 'listing_sold', 'saved_search_match',
  'new_contact', 'listing_expiring'
);

create type public.report_reason as enum (
  'scam', 'misleading_info', 'already_sold', 'inappropriate', 'other'
);

create type public.report_status as enum ('open', 'reviewed', 'actioned', 'dismissed');

create type public.platform as enum ('ios', 'android', 'web');
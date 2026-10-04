-- 03_indexes.sql
-- Indexes. Run after 02_tables.sql.
-- Feed/search indexes are partial on active listings: drafts and sold cars stay out.

-- listings: feed and filters
create index listings_active_published_idx on public.listings (published_at desc)
  where status = 'active';
create index listings_active_category_price_idx on public.listings (category_id, price_cents)
  where status = 'active';
create index listings_active_make_model_idx on public.listings (make_id, model_id)
  where status = 'active';
create index listings_active_year_idx on public.listings (year)
  where status = 'active';
create index listings_active_mileage_idx on public.listings (mileage_km)
  where status = 'active';
create index listings_location_idx on public.listings using gist (location);
create index listings_active_sponsored_idx on public.listings (sponsored_until)
  where status = 'active' and sponsored_until is not null;

-- listings: owner views and housekeeping
create index listings_owner_idx on public.listings (owner_id, created_at desc);
create index listings_dealer_idx on public.listings (dealer_id, created_at desc)
  where dealer_id is not null;
create index listings_active_expires_idx on public.listings (expires_at)
  where status = 'active';

-- media, prices, Q&A
create index listing_media_listing_idx on public.listing_media (listing_id, sort_order);
create index listing_price_history_listing_idx on public.listing_price_history (listing_id, changed_at desc);
create index listing_questions_listing_idx on public.listing_questions (listing_id, created_at desc);

-- buyers
create index favorites_listing_idx on public.favorites (listing_id);
create index saved_searches_profile_idx on public.saved_searches (profile_id);
create index saved_searches_notify_idx on public.saved_searches (last_notified_at)
  where notify;

-- chat
create index conversations_buyer_idx on public.conversations (buyer_id, last_message_at desc);
create index conversations_seller_idx on public.conversations (seller_id, last_message_at desc);
create index conversations_dealer_idx on public.conversations (dealer_id, last_message_at desc)
  where dealer_id is not null;
create index messages_conversation_idx on public.messages (conversation_id, created_at desc);

-- dealers
create index dealer_members_profile_idx on public.dealer_members (profile_id);
create index dealers_location_idx on public.dealers using gist (location);
create index subscriptions_status_idx on public.subscriptions (status);
create index reviews_dealer_idx on public.reviews (dealer_id, created_at desc);

-- catalogue
create index makes_category_idx on public.makes (category_id, is_popular desc, name);
create index models_make_idx on public.models (make_id, name);

-- moderation
create index reports_open_idx on public.reports (created_at)
  where status = 'open';

-- analytics: btree for per-listing reads, BRIN for the nightly time-range scan
create index events_listing_created_idx on public.events (listing_id, created_at);
create index events_created_brin_idx on public.events using brin (created_at);

-- notifications
create index notifications_profile_idx on public.notifications (profile_id, created_at desc);
create index notifications_unread_idx on public.notifications (profile_id)
  where read_at is null;
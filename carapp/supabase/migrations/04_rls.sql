-- 04_rls.sql
-- Row Level Security. Run after 03_indexes.sql.
--
-- Rules of thumb:
--  * every table has RLS on; no policy = no access from the app
--  * (select auth.uid()) instead of auth.uid() so Postgres evaluates it once per query
--  * sensitive writes (publishing, subscriptions, notifications, stats, dealer staff)
--    have no client policy: they will go through database functions / Edge Functions
--  * subqueries on other tables inherit those tables' RLS, which keeps policies short

alter table public.profiles                 enable row level security;
alter table public.buyer_preferences        enable row level security;
alter table public.dealers                  enable row level security;
alter table public.dealer_members           enable row level security;
alter table public.plans                    enable row level security;
alter table public.subscriptions            enable row level security;
alter table public.vehicle_categories       enable row level security;
alter table public.makes                    enable row level security;
alter table public.models                   enable row level security;
alter table public.listings                 enable row level security;
alter table public.listing_media            enable row level security;
alter table public.listing_price_history    enable row level security;
alter table public.listing_questions        enable row level security;
alter table public.favorites                enable row level security;
alter table public.saved_searches           enable row level security;
alter table public.conversations            enable row level security;
alter table public.messages                 enable row level security;
alter table public.reviews                  enable row level security;
alter table public.reports                  enable row level security;
alter table public.events                   enable row level security;
alter table public.listing_stats_daily      enable row level security;
alter table public.notifications            enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.app_config               enable row level security;

-- ============================================================
-- PROFILES
-- ============================================================

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

-- Chat partners can see each other's profile
create policy profiles_select_chat_partner on public.profiles
  for select to authenticated
  using (exists (
    select 1 from public.conversations c
    where c.buyer_id = profiles.id or c.seller_id = profiles.id
  ));

create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy buyer_preferences_all_own on public.buyer_preferences
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- ============================================================
-- DEALERS
-- ============================================================

create policy dealers_select_public on public.dealers
  for select to anon, authenticated
  using (true);

create policy dealers_update_owner on public.dealers
  for update to authenticated
  using (exists (
    select 1 from public.dealer_members m
    where m.dealer_id = dealers.id
      and m.profile_id = (select auth.uid())
      and m.role = 'owner'
  ));
-- Dealer creation + first owner membership: done by a function (onboarding).

-- Own memberships only (a policy reading dealer_members on itself would recurse)
create policy dealer_members_select_own on public.dealer_members
  for select to authenticated
  using (profile_id = (select auth.uid()));

-- ============================================================
-- PLANS & SUBSCRIPTIONS (read-only from the app)
-- ============================================================

create policy plans_select_active on public.plans
  for select to anon, authenticated
  using (is_active);

create policy subscriptions_select_member on public.subscriptions
  for select to authenticated
  using (exists (
    select 1 from public.dealer_members m
    where m.dealer_id = subscriptions.dealer_id
      and m.profile_id = (select auth.uid())
  ));

-- ============================================================
-- CATALOGUE (public)
-- ============================================================

create policy vehicle_categories_select_visible on public.vehicle_categories
  for select to anon, authenticated
  using (is_visible);

create policy makes_select_public on public.makes
  for select to anon, authenticated
  using (true);

create policy models_select_public on public.models
  for select to anon, authenticated
  using (true);

-- ============================================================
-- LISTINGS
-- ============================================================

-- Active listings are public; drafts/sold/expired only for the seller
create policy listings_select_visible on public.listings
  for select to anon, authenticated
  using (
    status = 'active'
    or owner_id = (select auth.uid())
    or (dealer_id is not null and exists (
      select 1 from public.dealer_members m
      where m.dealer_id = listings.dealer_id
        and m.profile_id = (select auth.uid())
    ))
  );

-- New listings start as drafts; publishing goes through a function
create policy listings_insert_draft on public.listings
  for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and status = 'draft'
    and (
      (seller_type = 'private' and dealer_id is null)
      or (seller_type = 'dealer' and exists (
        select 1 from public.dealer_members m
        where m.dealer_id = listings.dealer_id
          and m.profile_id = (select auth.uid())
      ))
    )
  );

create policy listings_update_seller on public.listings
  for update to authenticated
  using (
    owner_id = (select auth.uid())
    or (dealer_id is not null and exists (
      select 1 from public.dealer_members m
      where m.dealer_id = listings.dealer_id
        and m.profile_id = (select auth.uid())
    ))
  )
  with check (
    owner_id = (select auth.uid())
    or (dealer_id is not null and exists (
      select 1 from public.dealer_members m
      where m.dealer_id = listings.dealer_id
        and m.profile_id = (select auth.uid())
    ))
  );
-- TODO with functions: lock status/published_at/sponsored_until/expires_at to server-side changes.

create policy listings_delete_own_draft on public.listings
  for delete to authenticated
  using (owner_id = (select auth.uid()) and status = 'draft');

-- Media / price history follow the visibility of their listing (inherited RLS)
create policy listing_media_select_visible on public.listing_media
  for select to anon, authenticated
  using (exists (select 1 from public.listings l where l.id = listing_media.listing_id));

create policy listing_media_write_seller on public.listing_media
  for all to authenticated
  using (exists (
    select 1 from public.listings l
    where l.id = listing_media.listing_id
      and (l.owner_id = (select auth.uid())
        or (l.dealer_id is not null and exists (
          select 1 from public.dealer_members m
          where m.dealer_id = l.dealer_id and m.profile_id = (select auth.uid()))))
  ))
  with check (exists (
    select 1 from public.listings l
    where l.id = listing_media.listing_id
      and (l.owner_id = (select auth.uid())
        or (l.dealer_id is not null and exists (
          select 1 from public.dealer_members m
          where m.dealer_id = l.dealer_id and m.profile_id = (select auth.uid()))))
  ));

create policy listing_price_history_select_visible on public.listing_price_history
  for select to anon, authenticated
  using (exists (select 1 from public.listings l where l.id = listing_price_history.listing_id));
-- Written by a trigger later.

-- ============================================================
-- Q&A
-- ============================================================

create policy listing_questions_select on public.listing_questions
  for select to anon, authenticated
  using (
    (is_public and answer is not null)
    or asker_id = (select auth.uid())
    or exists (
      select 1 from public.listings l
      where l.id = listing_questions.listing_id
        and (l.owner_id = (select auth.uid())
          or (l.dealer_id is not null and exists (
            select 1 from public.dealer_members m
            where m.dealer_id = l.dealer_id and m.profile_id = (select auth.uid()))))
    )
  );

create policy listing_questions_insert_asker on public.listing_questions
  for insert to authenticated
  with check (
    asker_id = (select auth.uid())
    and answer is null
    and is_public = false
  );

create policy listing_questions_answer_seller on public.listing_questions
  for update to authenticated
  using (exists (
    select 1 from public.listings l
    where l.id = listing_questions.listing_id
      and (l.owner_id = (select auth.uid())
        or (l.dealer_id is not null and exists (
          select 1 from public.dealer_members m
          where m.dealer_id = l.dealer_id and m.profile_id = (select auth.uid()))))
  ));

-- ============================================================
-- BUYER ACTIONS
-- ============================================================

create policy favorites_all_own on public.favorites
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy saved_searches_all_own on public.saved_searches
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- ============================================================
-- CHAT
-- ============================================================

create policy conversations_select_participant on public.conversations
  for select to authenticated
  using (
    buyer_id = (select auth.uid())
    or seller_id = (select auth.uid())
    or (dealer_id is not null and exists (
      select 1 from public.dealer_members m
      where m.dealer_id = conversations.dealer_id
        and m.profile_id = (select auth.uid())
    ))
  );

-- A buyer opens a chat on an active listing that is not theirs
create policy conversations_insert_buyer on public.conversations
  for insert to authenticated
  with check (
    buyer_id = (select auth.uid())
    and exists (
      select 1 from public.listings l
      where l.id = conversations.listing_id
        and l.status = 'active'
        and l.owner_id = conversations.seller_id
        and l.owner_id <> (select auth.uid())
        and l.dealer_id is not distinct from conversations.dealer_id
    )
  );

-- Participants update read markers (tightened with functions later)
create policy conversations_update_participant on public.conversations
  for update to authenticated
  using (
    buyer_id = (select auth.uid())
    or seller_id = (select auth.uid())
    or (dealer_id is not null and exists (
      select 1 from public.dealer_members m
      where m.dealer_id = conversations.dealer_id
        and m.profile_id = (select auth.uid())
    ))
  );

-- Messages follow conversation visibility (inherited RLS)
create policy messages_select_participant on public.messages
  for select to authenticated
  using (exists (select 1 from public.conversations c where c.id = messages.conversation_id));

create policy messages_insert_participant on public.messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and exists (select 1 from public.conversations c where c.id = messages.conversation_id)
  );

-- ============================================================
-- TRUST
-- ============================================================

create policy reviews_select_public on public.reviews
  for select to anon, authenticated
  using (true);

-- Only a buyer who chatted with that dealer
create policy reviews_insert_verified on public.reviews
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = reviews.conversation_id
        and c.buyer_id = (select auth.uid())
        and c.dealer_id = reviews.dealer_id
    )
  );

create policy reviews_update_own on public.reviews
  for update to authenticated
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));

create policy reviews_delete_own on public.reviews
  for delete to authenticated
  using (author_id = (select auth.uid()));

create policy reports_insert_any on public.reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()) and status = 'open');

-- ============================================================
-- ANALYTICS
-- ============================================================

-- Write-only from the app; anonymous viewers send profile_id = null
create policy events_insert on public.events
  for insert to anon, authenticated
  with check (profile_id is null or profile_id = (select auth.uid()));

create policy listing_stats_daily_select_seller on public.listing_stats_daily
  for select to authenticated
  using (exists (
    select 1 from public.listings l
    where l.id = listing_stats_daily.listing_id
      and (l.owner_id = (select auth.uid())
        or (l.dealer_id is not null and exists (
          select 1 from public.dealer_members m
          where m.dealer_id = l.dealer_id and m.profile_id = (select auth.uid()))))
  ));

-- ============================================================
-- NOTIFICATIONS
-- ============================================================

create policy notifications_select_own on public.notifications
  for select to authenticated
  using (profile_id = (select auth.uid()));

-- Mark as read
create policy notifications_update_own on public.notifications
  for update to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

create policy notification_preferences_all_own on public.notification_preferences
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- ============================================================
-- APP CONFIG
-- ============================================================

create policy app_config_select_public on public.app_config
  for select to anon, authenticated
  using (is_public);

-- ============================================================
-- STORAGE
-- ============================================================
-- listing-drafts (private): the seller uploads into their own folder,
--   path = {auth.uid}/{random uuid}.{ext}
-- listing-media (public, CDN): written only server-side on publish,
--   path = {random uuid}/{random uuid}.{ext} -> unguessable, no user id in the URL
-- avatars (public): path = {auth.uid}/{random uuid}.{ext}

create policy drafts_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'listing-drafts'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy drafts_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'listing-drafts'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy drafts_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'listing-drafts'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy drafts_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'listing-drafts'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text);
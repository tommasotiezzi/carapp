-- ============================================================
-- 16: chat archive, offers to the people who saved a listing,
--     "I miei annunci" stats, price history on price changes.
-- Safe to run twice.
-- ============================================================

-- ---------------------------------------------------------------------
-- Chat archive: each side archives for itself (a dealer's chats are
-- archived for the whole dealer). A new message brings the chat back.
-- ---------------------------------------------------------------------

alter table public.conversations
  add column if not exists buyer_archived_at  timestamptz,
  add column if not exists seller_archived_at timestamptz,
  -- Opened by an offer to the people who saved the listing: the seller
  -- does not see it (nor who saved) until the buyer writes.
  add column if not exists hidden_from_seller boolean not null default false;

-- ---------------------------------------------------------------------
-- Offer messages: written only by `offer_to_savers()`. The body is the
-- readable text (Inbox preview, older apps); the prices drive the card.
-- ---------------------------------------------------------------------

alter table public.messages
  add column if not exists kind text not null default 'text',
  add column if not exists offer_price_cents integer,
  add column if not exists offer_list_price_cents integer;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'messages_kind_check') then
    alter table public.messages add constraint messages_kind_check check (
      (kind = 'text' and offer_price_cents is null and offer_list_price_cents is null)
      or (kind = 'offer' and offer_price_cents > 0 and offer_list_price_cents > offer_price_cents)
    );
  end if;
end;
$$;

-- The client writes plain text messages only.
drop policy if exists messages_insert_participant on public.messages;
create policy messages_insert_participant on public.messages
  for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and kind = 'text'
    and exists (select 1 from public.conversations c where c.id = messages.conversation_id)
  );

-- The seller side does not see chats still hidden by an offer.
drop policy if exists conversations_select_participant on public.conversations;
create policy conversations_select_participant on public.conversations
  for select to authenticated
  using (
    buyer_id = (select auth.uid())
    or (not hidden_from_seller and (
      seller_id = (select auth.uid())
      or (dealer_id is not null and exists (
        select 1 from public.dealer_members m
        where m.dealer_id = conversations.dealer_id
          and m.profile_id = (select auth.uid())
      ))
    ))
  );

create table if not exists public.listing_offers (
  id                    uuid primary key default gen_random_uuid(),
  listing_id            uuid not null references public.listings (id) on delete cascade,
  sender_id             uuid references public.profiles (id) on delete set null,
  price_cents           integer not null check (price_cents > 0),
  list_price_cents      integer not null,
  recipients            integer not null,
  created_at            timestamptz not null default now()
);

create index if not exists listing_offers_listing_idx on public.listing_offers (listing_id, created_at desc);

alter table public.listing_offers enable row level security;

-- Read by the seller side; written only by offer_to_savers().
drop policy if exists listing_offers_select_seller on public.listing_offers;
create policy listing_offers_select_seller on public.listing_offers
  for select to authenticated
  using (exists (
    select 1 from public.listings l
     where l.id = listing_offers.listing_id
       and (l.owner_id = (select auth.uid())
            or (l.dealer_id is not null and exists (
                  select 1 from public.dealer_members m
                   where m.dealer_id = l.dealer_id and m.profile_id = (select auth.uid()))))
  ));

-- Every new message moves the conversation up, marks it read for the
-- sender's side and takes it out of the archive for both sides. The
-- buyer's first message in a chat opened by an offer shows it to the
-- seller and counts as a contact.
create or replace function public.messages_touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conv public.conversations%rowtype;
begin
  select * into v_conv from public.conversations where id = new.conversation_id;

  if v_conv.hidden_from_seller and new.sender_id = v_conv.buyer_id then
    insert into public.events (listing_id, profile_id, type)
    values (v_conv.listing_id, new.sender_id, 'contact_chat');
  end if;

  update public.conversations c
     set last_message_at     = new.created_at,
         buyer_last_read_at  = case when new.sender_id = c.buyer_id
                                    then new.created_at else c.buyer_last_read_at end,
         seller_last_read_at = case when new.sender_id <> c.buyer_id
                                    then new.created_at else c.seller_last_read_at end,
         buyer_archived_at   = null,
         seller_archived_at  = null,
         hidden_from_seller  = c.hidden_from_seller and new.sender_id <> c.buyer_id
   where c.id = new.conversation_id;
  return new;
end;
$$;

-- Archive (true) or bring back (false) a chat, for the caller's side.
create or replace function public.archive_conversation(p_conversation_id uuid, p_archived boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_at timestamptz := case when p_archived then now() end;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  update public.conversations
     set buyer_archived_at = v_at
   where id = p_conversation_id and buyer_id = v_user;
  if found then return; end if;

  update public.conversations c
     set seller_archived_at = v_at
   where c.id = p_conversation_id
     and not c.hidden_from_seller
     and public.is_seller_side(c.seller_id, c.dealer_id);
end;
$$;

-- The Inbox (see 11): now without the archived chats, or only those
-- with p_archived. A single chat (p_conversation_id) comes back either
-- way, with `archived` saying where it belongs. The seller side never
-- gets chats still hidden by an offer. `last_message_kind` = 'text' |
-- 'offer'.
drop function if exists public.my_conversations(uuid, timestamptz, int);
drop function if exists public.my_conversations(uuid, timestamptz, int, boolean);
create function public.my_conversations(
  p_conversation_id uuid default null,
  p_before timestamptz default null,
  p_limit int default 30,
  p_archived boolean default false
)
returns table (
  id uuid,
  listing_id uuid,
  is_buyer boolean,
  buyer_id uuid,
  other_name text,
  other_is_dealer boolean,
  listing_title text,
  listing_cover_path text,
  listing_price_cents int,
  listing_status public.listing_status,
  last_message_body text,
  last_message_mine boolean,
  last_message_kind text,
  last_message_at timestamptz,
  activity_at timestamptz,
  unread boolean,
  archived boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select c.*, (c.buyer_id = auth.uid()) as is_buyer
      from public.conversations c
     -- Written so the (buyer_id | seller_id | dealer_id, last_message_at)
     -- indexes are used: no scan of everyone's chats.
     where (c.buyer_id = auth.uid()
            or (not c.hidden_from_seller
                and (c.seller_id = auth.uid()
                     or c.dealer_id in (select dm.dealer_id from public.dealer_members dm
                                         where dm.profile_id = auth.uid()))))
       and (p_conversation_id is null or c.id = p_conversation_id)
       and (p_conversation_id is not null
            or coalesce(p_archived, false) = ((case when c.buyer_id = auth.uid()
                                                    then c.buyer_archived_at
                                                    else c.seller_archived_at end) is not null))
       and (p_before is null or coalesce(c.last_message_at, c.created_at) < p_before)
     order by coalesce(c.last_message_at, c.created_at) desc
     limit least(greatest(coalesce(p_limit, 30), 1), 100)
  )
  select
    m.id,
    m.listing_id,
    m.is_buyer,
    m.buyer_id,
    case when m.is_buyer and d.id is not null then d.display_name
         when m.is_buyer then seller.display_name
         else buyer.display_name end,
    (m.is_buyer and d.id is not null),
    nullif(concat_ws(' ', mk.name, md.name), ''),
    l.cover_path,
    l.price_cents,
    l.status,
    last.body,
    case when m.is_buyer then last.sender_id = m.buyer_id
         else last.sender_id <> m.buyer_id end,
    last.kind,
    m.last_message_at,
    coalesce(m.last_message_at, m.created_at),
    coalesce(m.last_message_at > coalesce(
      case when m.is_buyer then m.buyer_last_read_at else m.seller_last_read_at end,
      '-infinity'::timestamptz), false),
    (case when m.is_buyer then m.buyer_archived_at else m.seller_archived_at end) is not null
  from mine m
  join public.listings l on l.id = m.listing_id
  left join public.makes mk on mk.id = l.make_id
  left join public.models md on md.id = l.model_id
  left join public.dealers d on d.id = m.dealer_id
  left join public.profiles seller on seller.id = m.seller_id
  left join public.profiles buyer on buyer.id = m.buyer_id
  left join lateral (
    select msg.body, msg.sender_id, msg.kind
      from public.messages msg
     where msg.conversation_id = m.id
     order by msg.created_at desc
     limit 1
  ) last on true
  order by coalesce(m.last_message_at, m.created_at) desc;
$$;

-- How many chats the caller has archived ("Archiviate (3)").
create or replace function public.archived_conversations_count()
returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
    from public.conversations c
   where (c.buyer_id = auth.uid() and c.buyer_archived_at is not null)
      or (c.buyer_id <> auth.uid()
          and not c.hidden_from_seller
          and c.seller_archived_at is not null
          and (c.seller_id = auth.uid()
               or c.dealer_id in (select dm.dealer_id from public.dealer_members dm
                                   where dm.profile_id = auth.uid())));
$$;

-- ---------------------------------------------------------------------
-- "Fai un'offerta a chi l'ha salvato": a lower price reserved to the
-- people who saved the listing. Each of them gets a message in the
-- Inbox ("<seller> ha abbassato il prezzo per te") and can answer at
-- once; the seller never learns who they are until they write (the
-- chat stays hidden from the seller side). The public price does not
-- change. One offer per listing every 24 h, at least half the price.
-- Returns how many people got it.
-- Errors: not_authenticated / not_seller (42501), listing_unavailable,
-- offer_not_lower, offer_too_low, offer_too_soon, no_savers.
-- ---------------------------------------------------------------------

create or replace function public.offer_to_savers(p_listing_id uuid, p_price_cents int)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_listing public.listings%rowtype;
  v_saver uuid;
  v_conv uuid;
  v_count int := 0;
  v_body text;
  v_offer_id uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select * into v_listing from public.listings
   where id = p_listing_id and status = 'active'
   for update;
  if not found then
    raise exception 'listing_unavailable';
  end if;
  if not public.is_seller_side(v_listing.owner_id, v_listing.dealer_id) then
    raise exception 'not_seller' using errcode = '42501';
  end if;
  if p_price_cents is null or p_price_cents >= v_listing.price_cents then
    raise exception 'offer_not_lower';
  end if;
  if p_price_cents * 2 < v_listing.price_cents then
    raise exception 'offer_too_low';
  end if;
  if exists (select 1 from public.listing_offers o
              where o.listing_id = p_listing_id
                and o.created_at > now() - interval '24 hours') then
    raise exception 'offer_too_soon';
  end if;

  v_body := 'Ha abbassato il prezzo per te: € '
         || replace(to_char(p_price_cents / 100, 'FM999,999,999'), ',', '.')
         || ' invece di € '
         || replace(to_char(v_listing.price_cents / 100, 'FM999,999,999'), ',', '.');

  for v_saver in
    select f.profile_id
      from public.favorites f
     where f.listing_id = p_listing_id
       and f.profile_id <> v_listing.owner_id
       and not exists (select 1 from public.dealer_members m
                        where m.dealer_id = v_listing.dealer_id and m.profile_id = f.profile_id)
  loop
    insert into public.conversations (listing_id, buyer_id, seller_id, dealer_id, hidden_from_seller)
    values (v_listing.id, v_saver, v_listing.owner_id, v_listing.dealer_id, true)
    on conflict (listing_id, buyer_id) do nothing
    returning id into v_conv;
    if v_conv is null then
      select id into v_conv from public.conversations
       where listing_id = v_listing.id and buyer_id = v_saver;
    end if;

    insert into public.messages (conversation_id, sender_id, body, kind, offer_price_cents, offer_list_price_cents)
    values (v_conv, v_user, v_body, 'offer', p_price_cents, v_listing.price_cents);

    -- For push, when it exists.
    insert into public.notifications (profile_id, type, listing_id, payload)
    values (v_saver, 'price_drop', v_listing.id,
            jsonb_build_object('offer', true, 'conversation_id', v_conv,
                               'price_cents', p_price_cents, 'list_price_cents', v_listing.price_cents));
    v_count := v_count + 1;
    v_conv := null;
  end loop;

  if v_count = 0 then
    raise exception 'no_savers';
  end if;

  insert into public.listing_offers (listing_id, sender_id, price_cents, list_price_cents, recipients)
  values (p_listing_id, v_user, p_price_cents, v_listing.price_cents, v_count)
  returning id into v_offer_id;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------
-- "I miei annunci": the caller's listings (own, or their dealer's) with
-- what the seller may know: how many saved it (never who), chats, the
-- last offer. Newest first; p_status filters (null = all but removed).
-- ---------------------------------------------------------------------

drop function if exists public.my_listings(public.listing_status);
create function public.my_listings(p_status public.listing_status default null)
returns table (
  id uuid,
  status public.listing_status,
  category_id text,
  title text,
  version text,
  year int,
  mileage_km int,
  price_cents int,
  cover_path text,
  city text,
  published_at timestamptz,
  created_at timestamptz,
  saves int,
  chats int,
  last_offer_at timestamptz,
  last_offer_price_cents int
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    l.id,
    l.status,
    l.category_id,
    nullif(concat_ws(' ', mk.name, md.name), ''),
    l.version,
    l.year,
    l.mileage_km,
    l.price_cents,
    l.cover_path,
    l.city,
    l.published_at,
    l.created_at,
    (select count(*)::int from public.favorites f
      where f.listing_id = l.id
        and f.profile_id <> l.owner_id
        and not exists (select 1 from public.dealer_members m
                         where m.dealer_id = l.dealer_id and m.profile_id = f.profile_id)),
    (select count(*)::int from public.conversations c
      where c.listing_id = l.id and not c.hidden_from_seller),
    o.created_at,
    o.price_cents
  from public.listings l
  left join public.makes mk on mk.id = l.make_id
  left join public.models md on md.id = l.model_id
  left join lateral (
    select lo.created_at, lo.price_cents from public.listing_offers lo
     where lo.listing_id = l.id
     order by lo.created_at desc
     limit 1
  ) o on true
  where (l.owner_id = auth.uid()
         or l.dealer_id in (select dm.dealer_id from public.dealer_members dm
                             where dm.profile_id = auth.uid()))
    and (case when p_status is null then l.status <> 'removed' else l.status = p_status end)
  order by coalesce(l.published_at, l.created_at) desc
  limit 200;
$$;

-- ---------------------------------------------------------------------
-- A new price on an online listing goes into its history (the first
-- row is written by publish-listing).
-- ---------------------------------------------------------------------

create or replace function public.listings_price_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'active' and new.price_cents is distinct from old.price_cents then
    insert into public.listing_price_history (listing_id, price_cents)
    values (new.id, new.price_cents);
  end if;
  return new;
end;
$$;

drop trigger if exists listings_price_history on public.listings;
create trigger listings_price_history
  after update of price_cents on public.listings
  for each row execute function public.listings_price_history();

revoke execute on function public.listings_price_history() from public, anon, authenticated;
revoke execute on function public.archive_conversation(uuid, boolean) from public, anon;
revoke execute on function public.my_conversations(uuid, timestamptz, int, boolean) from public, anon;
revoke execute on function public.archived_conversations_count() from public, anon;
revoke execute on function public.offer_to_savers(uuid, int) from public, anon;
revoke execute on function public.my_listings(public.listing_status) from public, anon;
grant execute on function public.archive_conversation(uuid, boolean) to authenticated;
grant execute on function public.my_conversations(uuid, timestamptz, int, boolean) to authenticated;
grant execute on function public.archived_conversations_count() to authenticated;
grant execute on function public.offer_to_savers(uuid, int) to authenticated;
grant execute on function public.my_listings(public.listing_status) to authenticated;

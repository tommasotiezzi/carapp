-- 11_chat.sql
--
-- Contact: in-app chat (conversations + messages over Realtime) and the
-- WhatsApp button. Writes that need rules beyond "is a participant" go
-- through security definer functions; the client keeps plain reads and
-- the insert of follow-up messages (RLS).
-- Run once in the Supabase SQL editor.

-- ---------------------------------------------------------------------
-- Privacy: a chat partner used to read the whole `profiles` row (phone,
-- birth date, gender). Names now come only from `my_conversations()`.
-- ---------------------------------------------------------------------

drop policy if exists profiles_select_chat_partner on public.profiles;

-- ---------------------------------------------------------------------
-- Conversations are created by `start_conversation()` (always with the
-- first buyer message, so an empty chat never reaches the seller) and
-- read markers are set by `mark_conversation_read()`. The client can no
-- longer insert or update rows directly (it could rewrite any column).
-- ---------------------------------------------------------------------

drop policy if exists conversations_insert_buyer on public.conversations;
drop policy if exists conversations_update_participant on public.conversations;

-- Every new message moves the conversation up and marks it read for
-- the side that sent it (buyer, or seller / any member of the dealer).
create or replace function public.messages_touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations c
     set last_message_at     = new.created_at,
         buyer_last_read_at  = case when new.sender_id = c.buyer_id
                                    then new.created_at else c.buyer_last_read_at end,
         seller_last_read_at = case when new.sender_id <> c.buyer_id
                                    then new.created_at else c.seller_last_read_at end
   where c.id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
  after insert on public.messages
  for each row execute function public.messages_touch_conversation();

-- True when the signed-in user is the seller side of a listing / chat:
-- the owner, or a member of the dealer.
create or replace function public.is_seller_side(p_owner_id uuid, p_dealer_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_owner_id = auth.uid()
      or (p_dealer_id is not null and exists (
            select 1 from public.dealer_members m
             where m.dealer_id = p_dealer_id and m.profile_id = auth.uid()));
$$;

-- "Contatta" on a listing: opens the chat with the first message, or
-- adds the message to the chat that already exists. Returns its id.
-- A new chat is a contact: one `contact_chat` event is written here.
-- Errors (message text): not_authenticated, listing_unavailable,
-- own_listing, empty_message.
create or replace function public.start_conversation(p_listing_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_listing public.listings%rowtype;
  v_id uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if v_body = '' then
    raise exception 'empty_message';
  end if;

  select * into v_listing from public.listings
   where id = p_listing_id and status = 'active';
  if not found then
    raise exception 'listing_unavailable';
  end if;
  if public.is_seller_side(v_listing.owner_id, v_listing.dealer_id) then
    raise exception 'own_listing' using errcode = '42501';
  end if;

  insert into public.conversations (listing_id, buyer_id, seller_id, dealer_id)
  values (v_listing.id, v_user, v_listing.owner_id, v_listing.dealer_id)
  on conflict (listing_id, buyer_id) do nothing
  returning id into v_id;

  if v_id is not null then
    insert into public.events (listing_id, profile_id, type)
    values (v_listing.id, v_user, 'contact_chat');
  else
    select id into v_id from public.conversations
     where listing_id = v_listing.id and buyer_id = v_user;
  end if;

  insert into public.messages (conversation_id, sender_id, body)
  values (v_id, v_user, v_body);

  return v_id;
end;
$$;

-- Opening a chat marks it read for the user's side.
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  update public.conversations
     set buyer_last_read_at = now()
   where id = p_conversation_id and buyer_id = v_user;
  if found then return; end if;

  update public.conversations c
     set seller_last_read_at = now()
   where c.id = p_conversation_id
     and public.is_seller_side(c.seller_id, c.dealer_id);
end;
$$;

-- The Inbox: the user's chats, newest activity first, with what the
-- list shows (other side's name, listing, last message, unread). Pass
-- p_conversation_id for a single chat (chat header, Realtime refresh);
-- p_before (the last row's `activity_at`) for the next page.
-- The other side is the dealer's name for a dealer listing, else the
-- profile's display name (null if not set). Nothing else of a profile
-- is ever returned.
drop function if exists public.my_conversations(uuid, timestamptz, int);
create function public.my_conversations(
  p_conversation_id uuid default null,
  p_before timestamptz default null,
  p_limit int default 30
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
  last_message_at timestamptz,
  activity_at timestamptz,
  unread boolean
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
            or c.seller_id = auth.uid()
            or c.dealer_id in (select dm.dealer_id from public.dealer_members dm
                                where dm.profile_id = auth.uid()))
       and (p_conversation_id is null or c.id = p_conversation_id)
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
    m.last_message_at,
    coalesce(m.last_message_at, m.created_at),
    coalesce(m.last_message_at > coalesce(
      case when m.is_buyer then m.buyer_last_read_at else m.seller_last_read_at end,
      '-infinity'::timestamptz), false)
  from mine m
  join public.listings l on l.id = m.listing_id
  left join public.makes mk on mk.id = l.make_id
  left join public.models md on md.id = l.model_id
  left join public.dealers d on d.id = m.dealer_id
  left join public.profiles seller on seller.id = m.seller_id
  left join public.profiles buyer on buyer.id = m.buyer_id
  left join lateral (
    select msg.body, msg.sender_id
      from public.messages msg
     where msg.conversation_id = m.id
     order by msg.created_at desc
     limit 1
  ) last on true
  order by coalesce(m.last_message_at, m.created_at) desc;
$$;

-- The WhatsApp button: the seller's number, only to a signed-in user,
-- only when the listing is active and has WhatsApp on. Dealers: their
-- `whatsapp`; private sellers: their `phone` if `whatsapp_public`.
-- null = no number to show. Each call is a contact (`contact_whatsapp`
-- event; dashboards count distinct users).
create or replace function public.seller_whatsapp(p_listing_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_number text;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  select case when l.dealer_id is not null then d.whatsapp
              when p.whatsapp_public then p.phone end
    into v_number
    from public.listings l
    left join public.dealers d on d.id = l.dealer_id
    left join public.profiles p on p.id = l.owner_id
   where l.id = p_listing_id
     and l.status = 'active'
     and l.whatsapp_enabled;

  v_number := nullif(btrim(v_number), '');
  if v_number is not null then
    insert into public.events (listing_id, profile_id, type)
    values (p_listing_id, v_user, 'contact_whatsapp');
  end if;
  return v_number;
end;
$$;

-- Callable by signed-in users only (the two helpers by nobody: they run
-- inside the functions above).
revoke execute on function public.messages_touch_conversation() from public, anon, authenticated;
revoke execute on function public.is_seller_side(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.start_conversation(uuid, text) from public, anon;
revoke execute on function public.mark_conversation_read(uuid) from public, anon;
revoke execute on function public.my_conversations(uuid, timestamptz, int) from public, anon;
revoke execute on function public.seller_whatsapp(uuid) from public, anon;
grant execute on function public.start_conversation(uuid, text) to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.my_conversations(uuid, timestamptz, int) to authenticated;
grant execute on function public.seller_whatsapp(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Realtime: new messages (open chat) and conversation changes (Inbox,
-- unread badge). Realtime applies the same RLS: each user only receives
-- rows of their own chats.
-- ---------------------------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and schemaname = 'public'
                    and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and schemaname = 'public'
                    and tablename = 'conversations') then
    alter publication supabase_realtime add table public.conversations;
  end if;
end;
$$;

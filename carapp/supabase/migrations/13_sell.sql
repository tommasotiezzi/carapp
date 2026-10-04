-- 13_sell.sql
--
-- Sell flow. The app creates the listing as a draft and uploads the media
-- to `listing-drafts`; the Edge Function `publish-listing` (service role)
-- checks it, moves the media to `listing-media` and makes it active.
-- From here on the app cannot set what only publishing may set.
-- Run once in the Supabase SQL editor.

-- Private sellers declare to be 18+, or to sell with a parent's consent.
alter type public.consent_kind add value if not exists 'seller_age';

-- ---------------------------------------------------------------------
-- Listings: fields only server-side roles may set (publish-listing, the
-- SQL editor, future jobs). The app may edit the vehicle data and price,
-- and move a listing active -> sold / removed, sold -> active,
-- draft -> removed. Publishing (draft -> active), media paths, dates and
-- sponsoring go through functions.
-- ---------------------------------------------------------------------

create or replace function public.protect_listing_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('anon', 'authenticated') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'draft'
       or new.published_at is not null or new.last_confirmed_at is not null
       or new.expires_at is not null or new.sold_at is not null
       or new.sponsored_until is not null
       or new.video_path is not null or new.cover_path is not null
       or new.video_duration_ms is not null then
      raise exception 'listing_field_locked' using errcode = '42501';
    end if;
    return new;
  end if;

  if new.owner_id is distinct from old.owner_id
     or new.dealer_id is distinct from old.dealer_id
     or new.seller_type is distinct from old.seller_type
     or new.published_at is distinct from old.published_at
     or new.last_confirmed_at is distinct from old.last_confirmed_at
     or new.expires_at is distinct from old.expires_at
     or new.sponsored_until is distinct from old.sponsored_until
     or new.video_path is distinct from old.video_path
     or new.cover_path is distinct from old.cover_path
     or new.video_duration_ms is distinct from old.video_duration_ms then
    raise exception 'listing_field_locked' using errcode = '42501';
  end if;

  if new.status is distinct from old.status then
    if not ((old.status = 'active' and new.status in ('sold', 'removed'))
         or (old.status = 'sold' and new.status = 'active')
         or (old.status = 'draft' and new.status = 'removed')) then
      raise exception 'listing_status_locked' using errcode = '42501';
    end if;
    new.sold_at := case when new.status = 'sold' then now() end;
  elsif new.sold_at is distinct from old.sold_at then
    raise exception 'listing_field_locked' using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists protect_listing_fields on public.listings;
create trigger protect_listing_fields
  before insert or update on public.listings
  for each row execute function public.protect_listing_fields();

-- ---------------------------------------------------------------------
-- listing_media: written only by publish-listing (paths must point to
-- files it moved into `listing-media`, never to an arbitrary URL).
-- ---------------------------------------------------------------------

drop policy if exists listing_media_write_seller on public.listing_media;

-- ============================================================
-- 17: change the video and photos of an online listing.
-- The Edge Function update-listing-media moves the new files to the
-- public bucket, then calls apply_listing_media() so the rows change
-- all together (or not at all). Service role only.
-- Safe to run twice.
-- ============================================================

-- p_video_path / p_cover_path: the new video and cover (both, or both
-- null to keep the current ones). p_photos: the whole carousel in order,
-- each item {"media_id": "<kept photo>"} or {"path": "<new file>",
-- "step": "<slot>"}. Photos not listed are dropped. Returns the storage
-- paths no longer used (to delete from the bucket).
-- Errors: listing_not_found, bad_photo (P0001).
create or replace function public.apply_listing_media(
  p_listing_id uuid,
  p_video_path text,
  p_cover_path text,
  p_video_duration_ms int,
  p_photos jsonb
)
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_removed text[] := '{}';
  v_item jsonb;
  v_order int := 0;
  v_kept uuid[] := '{}';
  v_id uuid;
begin
  perform 1 from public.listings where id = p_listing_id for update;
  if not found then
    raise exception 'listing_not_found';
  end if;

  -- Kept photos must be this listing's photos, each once.
  for v_item in select * from jsonb_array_elements(coalesce(p_photos, '[]'::jsonb)) loop
    if v_item ? 'media_id' then
      v_id := (v_item ->> 'media_id')::uuid;
      if v_id = any (v_kept) or not exists (
        select 1 from public.listing_media
         where id = v_id and listing_id = p_listing_id and kind = 'photo'
      ) then
        raise exception 'bad_photo';
      end if;
      v_kept := v_kept || v_id;
    elsif coalesce(v_item ->> 'path', '') = '' then
      raise exception 'bad_photo';
    end if;
  end loop;

  -- Photos dropped.
  with gone as (
    delete from public.listing_media
     where listing_id = p_listing_id and kind = 'photo' and not (id = any (v_kept))
    returning storage_path
  )
  select v_removed || coalesce(array_agg(storage_path), '{}') into v_removed from gone;

  -- The carousel in the new order.
  for v_item in select * from jsonb_array_elements(coalesce(p_photos, '[]'::jsonb)) loop
    v_order := v_order + 1;
    if v_item ? 'media_id' then
      update public.listing_media set sort_order = v_order
       where id = (v_item ->> 'media_id')::uuid;
    else
      insert into public.listing_media (listing_id, kind, capture_step, storage_path, sort_order)
      values (p_listing_id, 'photo', nullif(v_item ->> 'step', ''), v_item ->> 'path', v_order);
    end if;
  end loop;

  -- A new video replaces video and cover.
  if p_video_path is not null and p_cover_path is not null then
    with gone as (
      delete from public.listing_media
       where listing_id = p_listing_id and kind in ('video', 'cover')
      returning storage_path
    )
    select v_removed || coalesce(array_agg(storage_path), '{}') into v_removed from gone;

    insert into public.listing_media (listing_id, kind, storage_path, duration_ms, sort_order)
    values (p_listing_id, 'video', p_video_path, p_video_duration_ms, 0),
           (p_listing_id, 'cover', p_cover_path, null, 0);

    update public.listings
       set video_path = p_video_path,
           cover_path = p_cover_path,
           video_duration_ms = p_video_duration_ms
     where id = p_listing_id;
  end if;

  return v_removed;
end;
$$;

revoke execute on function public.apply_listing_media(uuid, text, text, int, jsonb) from public, anon, authenticated;
grant execute on function public.apply_listing_media(uuid, text, text, int, jsonb) to service_role;

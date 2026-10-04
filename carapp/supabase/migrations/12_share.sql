-- 12_share.sql
--
-- Share links. `base_url` is the share site (folder `site/`, e.g.
-- https://carfeed.pages.dev): the app shares <base_url>/l/<listing id>.
-- While it is null the app shares the app link carfeed://app/listing/<id>.
-- Run once in the Supabase SQL editor. After the site is online:
--   update public.app_config
--     set value = jsonb_build_object('base_url', 'https://<your site>')
--     where key = 'share';
--   update public.app_config set value = to_jsonb((value #>> '{}')::int + 1)
--     where key = 'config_version';

insert into public.app_config (key, value, description)
values ('share', '{"base_url": null}', 'Share links: base URL of the share site (https, no trailing slash)')
on conflict (key) do nothing;

update public.app_config
  set value = to_jsonb((value #>> '{}')::int + 1)
  where key = 'config_version';

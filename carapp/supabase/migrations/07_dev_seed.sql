-- 07_dev_seed.sql
-- DEV ONLY: test data for the feed. Do not run in production.
--
-- Before running: Supabase dashboard > Authentication > Users > Add user
--   email: dev@carfeed.test   (any password, "Auto confirm" on)
--
-- Videos are public Google sample clips (landscape, the app crops them):
-- just placeholders until real listings exist.

do $$
declare
  v_uid     uuid;
  v_dealer  uuid;
begin
  select id into v_uid from auth.users where email = 'dev@carfeed.test';
  if v_uid is null then
    raise exception 'Create the user dev@carfeed.test in Authentication > Users first';
  end if;

  -- profile + dealer + membership
  insert into public.profiles (id, account_type, intent, display_name, city)
  values (v_uid, 'dealer_member', 'dealer', 'Dev', 'Milano')
  on conflict (id) do nothing;

  insert into public.dealers (legal_name, display_name, vat_number, vat_verified_at, city, province)
  values ('Auto Bianchi Srl', 'Auto Bianchi', 'IT00000000001', now(), 'Milano', 'MI')
  on conflict (vat_number) do update set display_name = excluded.display_name
  returning id into v_dealer;

  insert into public.dealer_members (dealer_id, profile_id, role)
  values (v_dealer, v_uid, 'owner')
  on conflict do nothing;

  -- a few models
  insert into public.models (make_id, name, slug)
  select m.id, x.name, x.slug
  from (values
    ('car', 'volkswagen', 'Golf', 'golf'),
    ('car', 'fiat', '500', '500'),
    ('car', 'fiat', 'Panda', 'panda'),
    ('car', 'toyota', 'Yaris', 'yaris'),
    ('motorcycle', 'yamaha', 'MT-07', 'mt-07')
  ) as x(category_id, make_slug, name, slug)
  join public.makes m on m.category_id = x.category_id and m.slug = x.make_slug
  on conflict (make_id, slug) do nothing;

  -- listings
  insert into public.listings (
    seller_type, owner_id, dealer_id, category_id, make_id, model_id, version,
    year, mileage_km, price_cents, fuel_type, transmission, power_kw, euro_class,
    description, city, province, status, published_at, last_confirmed_at, expires_at,
    video_path
  )
  select
    x.seller_type::public.seller_type,
    v_uid,
    case when x.seller_type = 'dealer' then v_dealer end,
    x.category_id,
    mk.id,
    md.id,
    x.version,
    x.year, x.km, x.price_cents,
    x.fuel::public.fuel_type,
    x.gearbox::public.transmission_type,
    x.kw, x.euro,
    x.descr, 'Milano', 'MI',
    'active', now() - x.age, now() - x.age, now() - x.age + interval '21 days',
    x.video
  from (values
    ('dealer',  'car',        'volkswagen', 'golf',  '1.6 TDI Life',     2019, 78400,  1490000, 'diesel', 'manual',    85, 6,
     'Unico proprietario, tagliandi in rete Volkswagen, gomme nuove.', interval '10 minutes',
     'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4'),
    ('dealer',  'car',        'fiat',       '500',   '1.0 Hybrid Dolcevita', 2021, 32100, 1140000, 'hybrid', 'manual',  51, 6,
     'Perfetta per la città, ok neopatentati. Garanzia 12 mesi.', interval '1 hour',
     'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4'),
    ('dealer',  'car',        'toyota',     'yaris', '1.5 Hybrid Active', 2020, 54800,  1230000, 'hybrid', 'automatic', 85, 6,
     'Cambio automatico, consumi bassissimi, Area B ok.', interval '3 hours',
     'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4'),
    ('private', 'motorcycle', 'yamaha',     'mt-07', null,               2018, 21500,   540000, 'petrol', 'manual',    55, 4,
     'Depotenziabile A2, tagliando fatto a giugno.', interval '1 day',
     'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4'),
    ('dealer',  'car',        'fiat',       'panda', '1.2 Easy',         2017, 96000,   690000, 'petrol', 'manual',    51, 6,
     'Prima auto ideale, bassi costi di gestione.', interval '2 days',
     'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4')
  ) as x(seller_type, category_id, make_slug, model_slug, version, year, km, price_cents,
         fuel, gearbox, kw, euro, descr, age, video)
  join public.makes mk on mk.category_id = x.category_id and mk.slug = x.make_slug
  join public.models md on md.make_id = mk.id and md.slug = x.model_slug;
end $$;
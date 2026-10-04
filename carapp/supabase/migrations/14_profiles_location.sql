-- 14_profiles_location.sql
--
-- Where users and listings are: the province capital (capoluogo) they
-- pick, with its coordinates. "Entro X km" compares capitals: precise
-- enough for a used-vehicle market, no geocoding service needed.
-- Public seller profiles: what anyone may see of a private seller.
-- Run once in the Supabase SQL editor.

-- ---------------------------------------------------------------------
-- Province capitals (same list as the app: lib/core/geo/italian_capitals.dart)
-- ---------------------------------------------------------------------

create table if not exists public.province_capitals (
  code  text primary key,           -- 'SI', as in listings.province
  name  text not null,
  lat   double precision not null,
  lng   double precision not null
);

alter table public.province_capitals enable row level security;

drop policy if exists province_capitals_select_all on public.province_capitals;
create policy province_capitals_select_all on public.province_capitals
  for select to anon, authenticated
  using (true);

-- 106 province capitals (generated, same list as lib/core/geo/italian_capitals.dart)
insert into public.province_capitals (code, name, lat, lng) values
  ('AG', 'Agrigento', 37.30971, 13.58457),
  ('AL', 'Alessandria', 44.91297, 8.61540),
  ('AN', 'Ancona', 43.61676, 13.51888),
  ('AO', 'Aosta', 45.73750, 7.32015),
  ('AR', 'Arezzo', 43.46643, 11.88229),
  ('AP', 'Ascoli Piceno', 42.85322, 13.57691),
  ('AT', 'Asti', 44.89913, 8.20414),
  ('AV', 'Avellino', 40.91405, 14.79529),
  ('BA', 'Bari', 41.12560, 16.86737),
  ('BT', 'Barletta', 41.31956, 16.27718),
  ('BL', 'Belluno', 46.13838, 12.21704),
  ('BN', 'Benevento', 41.12970, 14.78152),
  ('BG', 'Bergamo', 45.69441, 9.66842),
  ('BI', 'Biella', 45.56651, 8.05408),
  ('BO', 'Bologna', 44.49437, 11.34172),
  ('BZ', 'Bolzano', 46.49933, 11.35662),
  ('BS', 'Brescia', 45.53993, 10.21910),
  ('BR', 'Brindisi', 40.63849, 17.94602),
  ('CA', 'Cagliari', 39.21531, 9.11062),
  ('CL', 'Caltanissetta', 37.49213, 14.06185),
  ('CB', 'Campobasso', 41.55775, 14.65916),
  ('CE', 'Caserta', 41.07466, 14.33240),
  ('CT', 'Catania', 37.50288, 15.08705),
  ('CZ', 'Catanzaro', 38.90598, 16.59440),
  ('CH', 'Chieti', 42.35103, 14.16755),
  ('CO', 'Como', 45.80999, 9.08516),
  ('CS', 'Cosenza', 39.29309, 16.25610),
  ('CR', 'Cremona', 45.13337, 10.02421),
  ('KR', 'Crotone', 39.08037, 17.12539),
  ('CN', 'Cuneo', 44.39330, 7.55117),
  ('EN', 'Enna', 37.56706, 14.27909),
  ('FM', 'Fermo', 43.16059, 13.71840),
  ('FE', 'Ferrara', 44.83599, 11.61869),
  ('FI', 'Firenze', 43.76923, 11.25589),
  ('FG', 'Foggia', 41.46227, 15.54305),
  ('FC', 'Forlì', 44.22269, 12.04069),
  ('FR', 'Frosinone', 41.63965, 13.35117),
  ('GE', 'Genova', 44.41149, 8.93270),
  ('GO', 'Gorizia', 45.94150, 13.62213),
  ('GR', 'Grosseto', 42.76027, 11.11356),
  ('IM', 'Imperia', 43.88571, 8.02785),
  ('IS', 'Isernia', 41.58801, 14.22575),
  ('AQ', 'L''Aquila', 42.35122, 13.39844),
  ('SP', 'La Spezia', 44.10705, 9.82819),
  ('LT', 'Latina', 41.46759, 12.90368),
  ('LE', 'Lecce', 40.35354, 18.17191),
  ('LC', 'Lecco', 45.85576, 9.39339),
  ('LI', 'Livorno', 43.55235, 10.30868),
  ('LO', 'Lodi', 45.31441, 9.50372),
  ('LU', 'Lucca', 43.84432, 10.50151),
  ('MC', 'Macerata', 43.30024, 13.45307),
  ('MN', 'Mantova', 45.15727, 10.79277),
  ('MS', 'Massa', 44.03674, 10.14174),
  ('MT', 'Matera', 40.66751, 16.59793),
  ('ME', 'Messina', 38.19396, 15.55572),
  ('MI', 'Milano', 45.46679, 9.19035),
  ('MO', 'Modena', 44.64600, 10.92615),
  ('MB', 'Monza', 45.58439, 9.27358),
  ('NA', 'Napoli', 40.83957, 14.25085),
  ('NO', 'Novara', 45.44589, 8.62192),
  ('NU', 'Nuoro', 40.32319, 9.33030),
  ('OR', 'Oristano', 39.90381, 8.59118),
  ('PD', 'Padova', 45.40693, 11.87609),
  ('PA', 'Palermo', 38.11570, 13.36236),
  ('PR', 'Parma', 44.80107, 10.32835),
  ('PV', 'Pavia', 45.18509, 9.16016),
  ('PG', 'Perugia', 43.10676, 12.38825),
  ('PU', 'Pesaro', 43.91014, 12.91346),
  ('PE', 'Pescara', 42.46458, 14.21365),
  ('PC', 'Piacenza', 45.05193, 9.69263),
  ('PI', 'Pisa', 43.71553, 10.40127),
  ('PT', 'Pistoia', 43.93346, 10.91734),
  ('PN', 'Pordenone', 45.95444, 12.66003),
  ('PZ', 'Potenza', 40.63947, 15.80515),
  ('PO', 'Prato', 43.88062, 11.09703),
  ('RG', 'Ragusa', 36.92509, 14.73070),
  ('RA', 'Ravenna', 44.41722, 12.19914),
  ('RC', 'Reggio Calabria', 38.10923, 15.64345),
  ('RE', 'Reggio Emilia', 44.69735, 10.63008),
  ('RI', 'Rieti', 42.40488, 12.86206),
  ('RN', 'Rimini', 44.06090, 12.56563),
  ('RM', 'Roma', 41.89277, 12.48367),
  ('RO', 'Rovigo', 45.07107, 11.79007),
  ('SA', 'Salerno', 40.67822, 14.75940),
  ('SS', 'Sassari', 40.72668, 8.55967),
  ('SV', 'Savona', 44.30750, 8.48111),
  ('SI', 'Siena', 43.31816, 11.33191),
  ('SR', 'Siracusa', 37.05992, 15.29333),
  ('SO', 'Sondrio', 46.17099, 9.87147),
  ('TA', 'Taranto', 40.47355, 17.23238),
  ('TE', 'Teramo', 42.65892, 13.70440),
  ('TR', 'Terni', 42.56071, 12.64669),
  ('TO', 'Torino', 45.07327, 7.68069),
  ('TP', 'Trapani', 38.01850, 12.51366),
  ('TN', 'Trento', 46.06894, 11.12123),
  ('TV', 'Treviso', 45.66755, 12.24507),
  ('TS', 'Trieste', 45.64944, 13.76814),
  ('UD', 'Udine', 46.06256, 13.23484),
  ('VA', 'Varese', 45.81702, 8.82287),
  ('VE', 'Venezia', 45.43490, 12.33845),
  ('VB', 'Verbania', 45.92145, 8.55108),
  ('VC', 'Vercelli', 45.32398, 8.42323),
  ('VR', 'Verona', 45.43839, 10.99353),
  ('VV', 'Vibo Valentia', 38.67624, 16.10158),
  ('VI', 'Vicenza', 45.54750, 11.54597),
  ('VT', 'Viterbo', 42.41738, 12.10473)
on conflict (code) do update set name = excluded.name, lat = excluded.lat, lng = excluded.lng;

-- ---------------------------------------------------------------------
-- The user's capital and contact choices (Settings / onboarding)
-- ---------------------------------------------------------------------

alter table public.profiles
  add column if not exists province text references public.province_capitals (code),
  add column if not exists phone_public boolean not null default false;

-- ---------------------------------------------------------------------
-- `location` follows the province: the capital's point. Listings and
-- profiles get it from their province (set by the app), so distances can
-- also be computed in the database (e.g. saved-search alerts, later).
-- ---------------------------------------------------------------------

create or replace function public.location_from_province()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.province is null then
    new.location := null;
  else
    new.province := upper(btrim(new.province));
    select extensions.st_setsrid(extensions.st_makepoint(c.lng, c.lat), 4326)::extensions.geography
      into new.location
      from public.province_capitals c
     where c.code = new.province;
  end if;
  return new;
end;
$$;

drop trigger if exists listings_location_from_province on public.listings;
create trigger listings_location_from_province
  before insert or update of province on public.listings
  for each row execute function public.location_from_province();

drop trigger if exists profiles_location_from_province on public.profiles;
create trigger profiles_location_from_province
  before insert or update of province on public.profiles
  for each row execute function public.location_from_province();

-- Existing rows.
update public.listings set province = province where province is not null;

-- "Entro X km" filters listings by the provinces in range.
create index if not exists listings_active_province_idx
  on public.listings (province, published_at desc)
  where status = 'active';

-- ---------------------------------------------------------------------
-- Public seller profile: only users who sell as private sellers (an
-- active or sold listing), only these fields. Phone and WhatsApp only if
-- the user made them public, and only to signed-in users (no scraping);
-- has_phone / has_whatsapp tell guests there is something behind login.
-- A view with its owner's rights: `profiles` itself stays private.
-- ---------------------------------------------------------------------

create or replace view public.public_profiles as
select
  p.id,
  p.display_name,
  p.avatar_path,
  coalesce(c.name, p.city) as city,
  p.province,
  (p.phone_public and p.phone is not null) as has_phone,
  (p.whatsapp_public and p.phone is not null) as has_whatsapp,
  case when p.phone_public and (select auth.uid()) is not null then p.phone end as phone,
  case when p.whatsapp_public and (select auth.uid()) is not null then p.phone end as whatsapp,
  p.created_at as member_since
from public.profiles p
left join public.province_capitals c on c.code = p.province
where exists (
  select 1 from public.listings l
   where l.owner_id = p.id
     and l.seller_type = 'private'
     and l.status in ('active', 'sold')
);

revoke all on public.public_profiles from public;
grant select on public.public_profiles to anon, authenticated;

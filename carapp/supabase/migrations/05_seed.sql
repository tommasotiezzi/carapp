-- 05_seed.sql
-- Initial data. Run after 04_rls.sql. Safe to re-run (on conflict do nothing / update).

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('listing-media',  'listing-media',  true,  104857600, array['video/mp4', 'image/jpeg', 'image/webp']),
  ('listing-drafts', 'listing-drafts', false, 104857600, array['video/mp4', 'image/jpeg', 'image/webp']),
  ('avatars',        'avatars',        true,  5242880,   array['image/jpeg', 'image/webp', 'image/png'])
on conflict (id) do nothing;

-- ============================================================
-- VEHICLE CATEGORIES
-- attributes_schema: category-specific fields stored in listings.attributes
-- capture_steps: guided capture, in order. plate_tip = show "cover the plate" hint
-- ============================================================

insert into public.vehicle_categories (id, name_key, attributes_schema, capture_steps, is_visible, sort_order) values
(
  'car',
  'category.car',
  '{
    "body_type":   {"type": "enum", "options": ["city_car", "hatchback", "sedan", "station_wagon", "suv", "coupe", "convertible", "minivan", "van", "pickup"], "filterable": true},
    "doors":       {"type": "int", "min": 2, "max": 5},
    "seats":       {"type": "int", "min": 2, "max": 9},
    "novice_ok":   {"type": "bool", "filterable": true}
  }',
  '[
    {"id": "front_three_quarter", "kind": "video", "seconds": 5, "silhouette": "car_front_3q", "plate_tip": true,  "required": true},
    {"id": "right_side",          "kind": "video", "seconds": 5, "silhouette": "car_side_r",   "plate_tip": false, "required": true},
    {"id": "left_side",           "kind": "video", "seconds": 5, "silhouette": "car_side_l",   "plate_tip": false, "required": true},
    {"id": "rear",                "kind": "video", "seconds": 5, "silhouette": "car_rear",     "plate_tip": true,  "required": true},
    {"id": "interior_dashboard",  "kind": "video", "seconds": 5, "silhouette": null, "hint": "engine_running_show_km", "required": true},
    {"id": "engine_bay",          "kind": "video", "seconds": 5, "silhouette": null, "required": false},
    {"id": "defects",             "kind": "video", "seconds": 5, "silhouette": null, "required": false}
  ]',
  true,
  1
),
(
  'motorcycle',
  'category.motorcycle',
  '{
    "moto_type":       {"type": "enum", "options": ["naked", "sport", "touring", "adventure", "enduro", "cross", "custom", "scooter", "motard"], "filterable": true},
    "displacement_cc": {"type": "int", "min": 49, "max": 2500, "filterable": true},
    "license_class":   {"type": "enum", "options": ["AM", "A1", "A2", "A"], "filterable": true}
  }',
  '[
    {"id": "left_side",       "kind": "video", "seconds": 5, "silhouette": "moto_side_l", "plate_tip": false, "required": true},
    {"id": "right_side",      "kind": "video", "seconds": 5, "silhouette": "moto_side_r", "plate_tip": false, "required": true},
    {"id": "rear",            "kind": "video", "seconds": 5, "silhouette": "moto_rear",   "plate_tip": true,  "required": true},
    {"id": "tank_dashboard",  "kind": "video", "seconds": 5, "silhouette": null, "hint": "engine_running_show_km", "required": true},
    {"id": "chain_tyres",     "kind": "video", "seconds": 5, "silhouette": null, "required": false},
    {"id": "exhaust",         "kind": "video", "seconds": 5, "silhouette": null, "required": false},
    {"id": "defects",         "kind": "video", "seconds": 5, "silhouette": null, "required": false}
  ]',
  true,
  2
)
on conflict (id) do nothing;

-- ============================================================
-- PLANS
-- limits.max_active_listings: null = unlimited
-- Pro price and sponsor credits: decided after the pilot (null)
-- ============================================================

insert into public.plans (id, name, price_cents, limits, is_active, sort_order) values
(
  'base', 'Base', 2900,
  '{"max_active_listings": 30, "analytics_level": "basic", "monthly_sponsor_credits": 0, "seats": 1, "search_priority": false, "highlighted_badge": false}',
  true, 1
),
(
  'pro', 'Pro', null,
  '{"max_active_listings": null, "analytics_level": "advanced", "monthly_sponsor_credits": null, "seats": null, "search_priority": true, "highlighted_badge": true}',
  true, 2
)
on conflict (id) do nothing;

-- ============================================================
-- APP CONFIG
-- Bump config_version whenever any other key changes: the app re-fetches only then.
-- ============================================================

insert into public.app_config (key, value, description) values
  ('config_version',       '1',
   'Bump on every config change; clients re-fetch app_config only when this changes'),
  ('app_versions',         '{"ios": {"min": "1.0.0", "latest": "1.0.0"}, "android": {"min": "1.0.0", "latest": "1.0.0"}}',
   'Below min = forced update screen; below latest = soft prompt'),
  ('legal',                '{"privacy_policy_url": null, "terms_url": null, "support_email": null}',
   'Filled once the domain exists'),
  ('feature_flags',        '{"billing_enabled": false, "ai_search_enabled": false, "push_enabled": false, "whatsapp_contact_enabled": true, "reviews_enabled": true}',
   'Kill switches / progressive rollout'),
  ('onboarding',           '{"login_nudge_after_listings": 5, "second_nudge_after_listings": 4, "preferences_nudge_after_listings": 8}',
   'Lazy-user flow: when to nudge login and preferences'),
  ('dealer_trial',         '{"trial_months": 3, "conditional_free_months": 3, "contact_threshold_total": 30, "founder_price_cents": 2900}',
   'Free period; in months 4-6 billing starts once total contacts since signup reach the threshold'),
  ('contact_definition',   '{"chat_min_buyer_messages": 1, "count_whatsapp_click": true}',
   'What counts as a contact for dashboards and the threshold'),
  ('listing_lifecycle',    '{"confirm_every_days": 21, "expire_after_days_without_confirm": 7}',
   'Same for every plan'),
  ('feed',                 '{"page_size": 10, "prefetch_next_videos": 2, "prefetch_seconds": 3}',
   'Feed paging and video prefetch'),
  ('media',                '{"clip_seconds": 5, "video_max_height": 1920, "video_min_height": 720, "video_bitrate_kbps": 4500, "video_fps": 30, "photo_max_long_side": 4000}',
   'Capture and on-device encoding targets')
on conflict (key) do nothing;

-- ============================================================
-- MAKES (models imported later from a full dataset)
-- ============================================================

insert into public.makes (category_id, name, slug, is_popular)
select 'car', v.name,
       trim(both '-' from regexp_replace(lower(translate(v.name, 'ëéè', 'eee')), '[^a-z0-9]+', '-', 'g')),
       v.popular
from (values
  ('Abarth', false), ('Alfa Romeo', false), ('Audi', true), ('BMW', true), ('BYD', false),
  ('Citroën', false), ('Cupra', false), ('Dacia', false), ('DS', false), ('Fiat', true),
  ('Ford', true), ('Honda', false), ('Hyundai', false), ('Jaguar', false), ('Jeep', false),
  ('Kia', false), ('Lancia', true), ('Land Rover', false), ('Lexus', false), ('Mazda', false),
  ('Mercedes-Benz', false), ('MG', false), ('Mini', false), ('Mitsubishi', false), ('Nissan', false),
  ('Opel', true), ('Peugeot', true), ('Porsche', false), ('Renault', true), ('Seat', false),
  ('Skoda', false), ('Smart', false), ('Subaru', false), ('Suzuki', false), ('Tesla', false),
  ('Toyota', true), ('Volkswagen', true), ('Volvo', false)
) as v(name, popular)
on conflict (category_id, slug) do nothing;

insert into public.makes (category_id, name, slug, is_popular)
select 'motorcycle', v.name,
       trim(both '-' from regexp_replace(lower(v.name), '[^a-z0-9]+', '-', 'g')),
       v.popular
from (values
  ('Aprilia', false), ('Benelli', false), ('BMW', true), ('Ducati', true), ('Harley-Davidson', false),
  ('Honda', true), ('Husqvarna', false), ('Kawasaki', true), ('KTM', false), ('Kymco', false),
  ('Moto Guzzi', false), ('MV Agusta', false), ('Piaggio', true), ('Royal Enfield', false),
  ('Suzuki', false), ('SYM', false), ('Triumph', false), ('Vespa', false), ('Yamaha', true)
) as v(name, popular)
on conflict (category_id, slug) do nothing;
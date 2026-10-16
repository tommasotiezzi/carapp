-- ============================================================
-- 18: car capture = one continuous 360° walk-around video (guided by
-- the phone's rotation, stops by itself), then front interiors with the
-- dashboard (engine on, km readable) and rear interiors. Engine bay and
-- defects stay optional. Motorcycles are unchanged.
-- The app knows the old step ids for drafts started before.
-- Safe to run twice.
-- ============================================================

update public.vehicle_categories
set capture_steps = '[
  {"id": "walkaround",     "kind": "video", "seconds": 90, "guide": "walkaround", "silhouette": "car_front", "plate_tip": true, "required": true},
  {"id": "interior_front", "kind": "video", "seconds": 8,  "silhouette": null, "hint": "engine_running_show_km", "required": true},
  {"id": "interior_rear",  "kind": "video", "seconds": 5,  "silhouette": null, "required": true},
  {"id": "engine_bay",     "kind": "video", "seconds": 5,  "silhouette": null, "required": false},
  {"id": "defects",        "kind": "video", "seconds": 5,  "silhouette": null, "required": false}
]'::jsonb
where id = 'car';

-- ============================================================
-- 15: first car capture step = straight front view ("Frontale")
-- The 3/4 view was hard to frame; a front view with a filled shadow
-- (silhouette 'car_front') is clearer. Only the first step changes;
-- the app still knows 'front_three_quarter' for drafts and old media.
-- Safe to run twice.
-- ============================================================

update public.vehicle_categories
set capture_steps = jsonb_set(
  capture_steps,
  '{0}',
  '{"id": "front", "kind": "video", "seconds": 5, "silhouette": "car_front", "plate_tip": true, "required": true}'::jsonb
)
where id = 'car'
  and capture_steps -> 0 ->> 'id' = 'front_three_quarter';

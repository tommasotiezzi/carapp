-- 06_contact_threshold_total.sql
-- Dealer trial: 30 total contacts since signup instead of 10 per month.

update public.app_config
set value = '{"trial_months": 3, "conditional_free_months": 3, "contact_threshold_total": 30, "founder_price_cents": 2900}',
    description = 'Free period; in months 4-6 billing starts once total contacts since signup reach the threshold'
where key = 'dealer_trial';

-- bump config_version so the apps re-fetch the config
update public.app_config
set value = to_jsonb((value #>> '{}')::int + 1)
where key = 'config_version';
# Carfeed (code name)

TikTok-style vertical video feed to buy and sell used vehicles (cars incl. vans, motorcycles incl. scooters), dealers and private sellers in one feed. Target: Gen Z buying a first vehicle, Italy first (Milan pilot with one dealer). Brand name not decided yet: the visible name lives only in `appName` in the ARB file.

## Product decisions (already taken)

- **App lands on the feed.** Onboarding is never forced: it opens over the feed after 4 listings viewed (`app_config.onboarding.show_after_listings`) or at the first tap on Save / Share / Contact / filters, until completed or skipped.
- **Everything real.** No AI retouching of videos or photos. Photos optional. Zoom happens on the video itself (pinch / double tap pauses and zooms the frame, release resumes).
- **Video:** 5 s clips per guided-capture step, 1080p H.264 30 fps ~4-5 Mbps, encoded on the phone. Single version for the MVP (1440p zoom version only if pilot data shows heavy zoom use). Feed keeps max 3 players (prev/current/next).
- **No likes, no public comments.** Save (with price-drop alerts), Share, Contact (in-app chat + optional WhatsApp). Q&A answers can be made public by the seller.
- **Plates:** no in-app blurring; the capture flow just tells users to cover the plate.
- **Navbar:** always dark, same on every tab. Feed dark, other screens white/premium, accent blue `#1D4ED8`, system font.
- **Login:** email OTP code only for now (Google later, Apple required before iOS release if Google is offered).
- **Dealers:** VAT verified with VIES. Pricing: months 1-3 free; months 4-6 free until 30 total contacts since signup; then €29/month locked (founder price). Manual invoicing, no card at signup. Base / Pro plans configurable from DB. A "contact" = chat with ≥1 buyer message or a WhatsApp click.
- **Ads:** only sponsored listings (labelled) and coherent partners (financing, insurance). No generic banners.

## Stack

- Flutter (Riverpod, go_router, video_player, cached_network_image, shared_preferences, intl, uuid, supabase_flutter)
- Supabase only: Postgres, Auth, Storage + CDN, Realtime, Edge Functions. External: VIES (VAT), later Claude API (AI search), APNs/FCM (push).

## Conventions

- Database: everything in **English** (tables, columns, enums, functions).
- UI copy: **Italian**, only in `lib/l10n/app_it.arb` (never hard-coded). After editing: `flutter gen-l10n`.
- Feature-first folders: `lib/features/<feature>/{data,state,ui}`, shared code in `lib/core`.
- No unnecessary requests: config cached and re-fetched only when `config_version` changes; feed uses cursor pagination; analytics sent in batches.
- Every schema change = a new numbered migration file with only the change.
- Bundle ID currently Flutter default; set `com.tommasotiezzi.carfeed` before configuring Google OAuth / publishing.

## Run

```bash
# env.json in project root (gitignored)
# { "SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "..." }
flutter pub get
flutter gen-l10n
flutter run --dart-define-from-file=env.json
```

Supabase setup: Auth > Emails > "Magic Link" and "Confirm signup" templates must contain `{{ .Token }}` (6-digit code login).

## Flutter structure (done)

```
lib/
  main.dart                 Supabase init, SharedPreferences, ProviderScope
  app.dart                  MaterialApp.router, theme, l10n, warms config + tracker
  core/
    config/env.dart         --dart-define keys
    config/app_config.dart  app_config fetch + local cache (version check)
    storage/preferences.dart  SharedPreferences provider + all PrefKeys
    supabase/supabase_client.dart  client, authStateProvider, currentUserProvider
    theme/tokens.dart, app_theme.dart  design tokens + ThemeData
    router/routes.dart, app_router.dart, main_shell.dart  routes, shell, dark navbar
    analytics/event_tracker.dart  batched events (20 / 15 s / app paused)
    media/media_url.dart    storage path -> public URL (http URLs pass through)
    utils/formatters.dart   € / km / CV / fuel labels
    widgets/pill.dart, placeholder_screen.dart
  features/
    feed/      data (FeedItem, FeedRepository), state (FeedController), ui (FeedScreen, FeedVideoView, FeedOverlay)
    auth/      AuthRepository (email OTP), login_sheet.dart (reusable bottom sheet)
    onboarding/ BuyerPreferences, makesProvider, OnboardingController (local first, synced on login),
               IntentScreen, PreferencesScreen (also edit mode from profile), DealerSignupScreen, exitOnboarding()
    dealer/    DealerRepository (calls dealer-signup edge function)
    profile/   ProfileScreen (minimal: login/logout, "Cosa cerco" gated behind signup)
  l10n/app_it.arb (+ gen/)
```

Routes: tabs `/feed /search /inbox /profile` (shell); full screen `/onboarding`, `/onboarding/preferences[?edit=1]`, `/onboarding/dealer`, `/sell`, `/listing/:id`, `/chat/:id`, `/dealer`; share link `/l/:id` -> `/listing/:id`. Deep links: custom scheme `carfeed://app/<path>` (see SETUP.md); https links once a domain exists.

## Database

Migrations in order: `01_enums`, `02_tables`, `03_indexes`, `04_rls`, `05_seed`, `06_contact_threshold_total`, `07_dev_seed` (dev only, needs auth user `dev@carfeed.test`), `08_auth_profiles`.

### Enums
`account_type` consumer | dealer_member · `user_intent` buy | sell | browse | dealer · `seller_type` private | dealer · `listing_status` draft | active | sold | expired | removed · `media_kind` video | photo | cover · `fuel_type` petrol | diesel | hybrid | plugin_hybrid | electric | lpg | cng | other · `transmission_type` manual | automatic | semi_automatic · `dealer_role` owner | seller · `subscription_status` trial | conditional_free | active | past_due | canceled · `billing_method` manual_invoice | card · `event_type` impression | view | watch_time | zoom | open_detail | save | unsave | share | contact_chat | contact_whatsapp · `notification_type` new_message | price_drop | listing_sold | saved_search_match | new_contact | listing_expiring · `report_reason` scam | misleading_info | already_sold | inappropriate | other · `report_status` open | reviewed | actioned | dismissed · `platform` ios | android | web

### Tables (key columns)
- **profiles** id (= auth.users), account_type, intent, display_name, avatar_path, phone, whatsapp_public, city, location (geography), locale, onboarding_completed_at. Row created by trigger `on_auth_user_created`.
- **buyer_preferences** profile_id PK, category_ids[], make_ids[], price_min/max_cents, year_min, mileage_max_km, fuel_types[], max_distance_km, novice_driver
- **dealers** legal_name, display_name, vat_number (unique, `IT…`), vat_verified_at, vies_payload, address, city, province, location, phone, whatsapp, website, logo_path, description
- **dealer_members** (dealer_id, profile_id) PK, role
- **plans** id text ('base','pro'), price_cents (null = TBD), limits jsonb (max_active_listings, analytics_level, monthly_sponsor_credits, seats, search_priority, highlighted_badge)
- **subscriptions** dealer_id unique, plan_id, status, trial_started/ends_at, conditional_ends_at, contact_threshold (total since signup), founder_price_cents, is_founder, billing_method, current_period_*
- **vehicle_categories** id ('car','motorcycle'), name_key, attributes_schema jsonb, capture_steps jsonb (guided capture), is_visible
- **makes** (category_id, slug) unique, is_popular · **models** (make_id, slug) unique
- **listings** seller_type, owner_id, dealer_id (required iff dealer), category_id, make_id, model_id, version, year, mileage_km, price_cents, fuel_type, transmission, power_kw, euro_class 0-6, color, owners_count, has_service_history, warranty_months, attributes jsonb, description, city, province, location, whatsapp_enabled, status, published_at, last_confirmed_at, expires_at, sold_at, sponsored_until, cover_path, video_path, video_duration_ms
- **listing_media** listing_id, kind, capture_step, storage_path, width, height, duration_ms, size_bytes, sort_order
- **listing_price_history** listing_id, price_cents, changed_at
- **listing_questions** listing_id, asker_id, question, answer, answered_at, is_public
- **favorites** (profile_id, listing_id) PK, price_cents_at_save
- **saved_searches** profile_id, name, filters jsonb, notify, last_notified_at
- **conversations** listing_id, buyer_id, seller_id, dealer_id, last_message_at, buyer/seller_last_read_at; unique (listing_id, buyer_id)
- **messages** conversation_id, sender_id, body (1-2000)
- **reviews** dealer_id, author_id, conversation_id (must have chatted), rating 1-5, body; unique (dealer_id, author_id)
- **reports** listing_id, reporter_id, reason, details, status
- **events** append-only analytics (listing_id, profile_id, anon_id, session_id, type, value, platform)
- **listing_stats_daily** (listing_id, day) PK, impressions, views, unique_viewers, watch_time_ms, zooms, detail_opens, saves, shares, contacts_chat, contacts_whatsapp
- **notifications** profile_id, type, listing_id, payload, read_at, pushed_at · **notification_preferences** (profile_id, type) PK, enabled (missing row = on)
- **app_config** key PK, value jsonb, is_public

Extensions: postgis (geography + GIST indexes), moddatetime (`updated_at` triggers). Feed indexes are partial on `status = 'active'`.

### RLS (summary)
RLS on every table. Active listings, media, price history, dealers, reviews, catalogue, active plans and public config are readable by anon. Drafts / sold / expired only by owner or dealer members. Users manage their own profile, preferences, favorites, saved searches, notification prefs. Chat visible only to participants (buyer, seller, dealer members). Reviews only by buyers who chatted with that dealer. Events: insert-only (anon allowed). Stats: seller only. **No client write policy** for: dealer creation/membership, subscriptions, publishing, notifications, stats, price history: these go through functions / Edge Functions.

### Storage
- `listing-drafts` (private): `{auth.uid}/{uuid}.ext`, owner-only
- `listing-media` (public, CDN): `{uuid}/{uuid}.ext`, written only server-side on publish (unguessable, no user id in URLs)
- `avatars` (public): `{auth.uid}/{uuid}.ext`

### app_config keys
`config_version` (bump on every change) · `app_versions` {ios/android: {min, latest}} · `legal` {privacy_policy_url, terms_url, support_email} · `feature_flags` {billing_enabled, ai_search_enabled, push_enabled, whatsapp_contact_enabled, reviews_enabled} · `onboarding` {login_nudge_after_listings, second_nudge_after_listings, preferences_nudge_after_listings, show_after_listings (default 4 in app)} · `dealer_trial` {trial_months 3, conditional_free_months 3, contact_threshold_total 30, founder_price_cents 2900} · `contact_definition` · `listing_lifecycle` {confirm_every_days 21, expire_after_days_without_confirm 7} · `feed` {page_size 10, prefetch_next_videos 2, prefetch_seconds 3} · `media` {clip_seconds 5, video_max_height 1920, video_min_height 720, video_bitrate_kbps 4500, video_fps 30, photo_max_long_side 4000}

## Edge Functions

- **dealer-signup** (`supabase/functions/dealer-signup/index.ts`): authenticated user + `{vat_number, display_name}` → normalizes IT VAT → rejects if already registered (409 `vat_taken`) → checks VIES REST (`vies_unavailable` 503 / `vat_invalid` 422) → with service role creates dealer, owner membership, `base` subscription in `trial` (dates and threshold from `app_config.dealer_trial`), sets profile `account_type = dealer_member`. Rolls back the dealer on partial failure.

## Database functions

- `handle_new_user()` trigger on `auth.users` insert → creates `profiles` row.

## Status

Done: schema, RLS, seed, core app (config, theme, router, deep-link routes, analytics), feed (real data, video players, zoom, overlay, loading/empty/error), email OTP login sheet, onboarding (intent, preferences, dealer signup via VIES), minimal profile. Designs for all screens and states exist in the Claude canvas mockup.

## Next (in order)

1. **Listing detail** (`/listing/:id`): video on top, photos, price, total cost estimate, specs, description, Q&A, seller + reviews, sticky Contact.
2. **Save** + profile "Salvati" (favorites, price_cents_at_save; login sheet when guest).
3. **Filters**: per-pill bottom sheets on the feed + full Search screen; filtered feed query; saved searches. Preferences pre-fill filters.
4. **Contact**: conversations + messages with Realtime, Inbox, WhatsApp button (needs a security-definer function to expose seller contact).
5. **Share**: listing link + web fallback page.
6. **Polish**: login nudges, price vs market badge, feed function returning private seller names (profiles are not readable by others).

Later: sell flow (guided capture with silhouettes, on-device encoding, drafts bucket → publish function), dealer dashboard (reads `listing_stats_daily`), nightly stats aggregation, listing expiry job, notifications + push (FCM/APNs, `device_tokens`), AI search (Claude via Edge Function, filters only from DB data), Google/Apple login.
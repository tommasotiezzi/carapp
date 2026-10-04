# Carfeed (code name)

TikTok-style vertical video feed to buy and sell used vehicles (cars incl. vans, motorcycles incl. scooters), dealers and private sellers in one feed. Target: Gen Z buying a first vehicle, Italy first (Milan pilot with one dealer). Brand name not decided yet: the visible name lives only in `appName` in the ARB file.

## Product decisions (already taken)

- **App lands on the feed.** Onboarding is never forced: it opens over the feed after 4 listings viewed (`app_config.onboarding.show_after_listings`) or at the first tap on Save / Share / Contact / filters, until completed or skipped.
- **Everything real.** No AI retouching of videos or photos. Photos optional. Zoom happens on the video itself (pinch / double tap pauses and zooms the frame, release resumes).
- **Video:** one 5 s clip (or a photo) per guided-capture step, each retakeable on its own; the clips are joined on the phone with a 600 ms cross-dissolve into one 1080p H.264 30 fps ~4.5 Mbps MP4 (`pro_video_editor`: Media3 / AVFoundation); photos form the carousel. Single version for the MVP (1440p zoom version only if pilot data shows heavy zoom use). Feed keeps max 3 players (prev/current/next).
- **No likes, no public comments.** Save (with price-drop alerts), Share, Contact (in-app chat + optional WhatsApp). Q&A answers can be made public by the seller.
- **Plates:** no in-app blurring; the capture flow just tells users to cover the plate.
- **Navbar:** always dark, same on every tab. Feed dark, other screens white/premium, accent blue `#1D4ED8`, system font.
- **Age and consents:** the app is for **14+** (Italian age of digital consent; AM licence at 14, A1 at 16 are part of the target). Sign up requires two ticks: "Ho almeno 14 anni e accetto i Termini e condizioni" and "Ho letto l'Informativa privacy" (the privacy notice is read, not "accepted"); promotional emails are an optional tick, off by default. Minors buy with a parent's consent (stated in the Termini); the sell flow asks private sellers once to declare 18+ or a parent's consent (`seller_age`). Birth date and gender are **never asked in onboarding**: optional in Settings (data minimisation). All to be reviewed with lawyers before launch.
- **Login:** email + password for now (sign in / create account in the same sheet). Email OTP codes are paused because emails cannot be received yet; bring them back once email delivery works. Google later, Apple required before iOS release if Google is offered.
- **Dealers:** VAT verified with VIES. Pricing: months 1-3 free; months 4-6 free until 30 total contacts since signup; then €29/month locked (founder price). Manual invoicing, no card at signup. Base / Pro plans configurable from DB. A "contact" = chat with ≥1 buyer message or a WhatsApp click.
- **Ads:** only sponsored listings (labelled) and coherent partners (financing, insurance). No generic banners.

## Stack

- Flutter (Riverpod, go_router, video_player, cached_network_image, shared_preferences, intl, uuid, supabase_flutter, camera, pro_video_editor, path_provider, share_plus, url_launcher)
- Supabase only: Postgres, Auth, Storage + CDN, Realtime, Edge Functions. External: VIES (VAT), later Claude API (AI search), APNs/FCM (push).

## Conventions

- Database: everything in **English** (tables, columns, enums, functions).
- UI copy: **Italian**, only in `lib/l10n/app_it.arb` (never hard-coded). After editing: `flutter gen-l10n`.
- Feature-first folders: `lib/features/<feature>/{data,state,ui}`, shared code in `lib/core`.
- No unnecessary requests: config cached and re-fetched only when `config_version` changes; feed uses cursor pagination; analytics sent in batches.
- Every schema change = a new numbered migration file with only the change.
- Riverpod 3: never use `ref` in `dispose()` or after an `await` in a widget (it throws once the widget is unmounted). Read what you need (notifier, repository, tracker, container) into a local or a field first. In notifiers, check `ref.mounted` after every `await` before touching `state`.
- Bundle ID currently Flutter default; set `com.tommasotiezzi.carfeed` before configuring Google OAuth / publishing.

## Run

```bash
# env.json in project root (gitignored)
# { "SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "..." }
flutter pub get
flutter gen-l10n
flutter run --dart-define-from-file=env.json
flutter analyze && flutter test   # before every push
```

Supabase setup: run the migrations not run yet (09 → 13) in the SQL editor; deploy the Edge Functions `delete-account` and `publish-listing` (Verify JWT on). Auth > Sign In / Providers > Email: keep **"Confirm email" off** while emails cannot be received (otherwise sign up ends on "conferma la tua email" and the account stays unusable). Minimum password length in the app: 8. When OTP codes come back: "Magic Link" and "Confirm signup" templates must contain `{{ .Token }}`.

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
    media/shared_video.dart  ref-counted video player (feed lends it to the listing page)
    utils/formatters.dart   € / km / CV
    l10n/vehicle_labels.dart  ARB labels for DB enums (fuel_type, transmission_type)
    widgets/pill.dart, placeholder_screen.dart
  features/
    feed/      data (FeedItem, FeedRepository, FeedFilters), state (FeedController, FeedFiltersController),
               ui (FeedScreen, FeedVideoView, FeedOverlay with filter pills, FilterSheet + FilterSections,
               ListingCard grid card, filterChips() / describeFilters() / priceLabel / yearLabel)
    search/    data (Catalog: all makes + models loaded once, QueryParser, suggest(), RecentSearches,
               SavedSearch + repository), state (savedSearches), ui (SearchScreen)
    auth/      AuthRepository (email + password, Supabase error codes -> AuthFailure), login_sheet.dart
               (reusable bottom sheet: sign in / create account, confirm-email step if Supabase requires it)
    onboarding/ BuyerPreferences, makesProvider, OnboardingController (local first, synced on login),
               IntentScreen, PreferencesScreen (also edit mode from profile), DealerSignupScreen, exitOnboarding()
    dealer/    DealerRepository (calls dealer-signup edge function)
    listing/   data (ListingDetail + photos/dealer, ListingQuestion, DealerReviews, ListingRepository,
               TransferCostRules), state (listingDetail / listingQuestions / dealerReviews providers),
               ui (ListingScreen, ListingVideoHeader, photo strip + viewer, sections, Q&A + ask sheet)
    saved/     FavoritesRepository + SavedListing (price drop since save), SavedController (ids, optimistic,
               rolls back on error), toggleSave() (login sheet for guests), SavedSection (profile grid)
    legal/     consents (ConsentKind, consentNeeded(), ConsentRepository: user_consents log, pending choices
               when sign up waits for email confirmation), ConsentChecks (the 3 ticks), ConsentGate (wraps the
               shell: non-dismissible sheet when a signed-in user lacks the current Termini/Privacy)
    settings/  AccountRepository (profile extras, email/password change after re-auth, delete account,
               notification_preferences), SettingsScreen (/settings, gear in the profile), account sheets
    chat/      data (ConversationSummary, ChatMessage, ChatRepository: RPCs + Realtime streams), state (InboxController:
               live Inbox + unread badge; ChatController: one chat, optimistic send, catch-up after reconnect),
               ui (InboxScreen, ChatScreen for /chat/:id and /chat/new/:listingId, contactSeller() / openWhatsapp())
    sell/      data (CaptureStep from vehicle_categories.capture_steps, SellDraft + Shot + SellDetails, SellMedia:
               draft folder / thumbnails / render with pro_video_editor, SellRepository: draft row, uploads,
               publish-listing), state (SellController: draft on the phone, background render + upload, publish),
               ui (SellStartScreen, CaptureScreen + Silhouette painter, ShotsScreen, SellDetailsScreen, SellDoneScreen)
    share/     listingShareLink() (share site or app link), listingShareSummary(), shareListing() (share sheet + `share` event)
    profile/   ProfileScreen (login, "Cosa cerco" gated behind signup, "Salvati", gear -> settings)
  l10n/app_it.arb (+ gen/)
site/       share site (Cloudflare Pages): /l/:id rendered on the server with preview tags; see site/README.md
test/       query parser, suggestions, recents, chips, logicFilter, transfer cost, feed filters, SavedController;
            widget tests (fake data): listing, Salvati, login, filter sheet, Search, Inbox, chat (new chat, contact bar);
            chat logic with a fake repository (optimistic send, Realtime echo, retry, catch-up, Inbox refresh);
            share (links, share sheet text, tracking); sell (draft model, controller with fake media/repository:
            render order, uploads, retakes, publish; start, shots, details, done screens)
```

Feed and listing video play only when visible: `TickerMode.valuesOf(context).enabled` is false on inactive tabs and under full-screen routes; app lifecycle and user pause are combined in one `_updatePlayback()`.

Routes: tabs `/feed /search /inbox /profile` (shell); full screen `/onboarding`, `/onboarding/preferences[?edit=1]`, `/onboarding/dealer`, `/sell` (+ `/sell/capture?step=&single=1`, `/sell/shots`, `/sell/shots/details`, `/sell/done/:id`), `/listing/:id`, `/chat/:id`, `/chat/new/:listingId`, `/dealer`; share link `/l/:id` -> `/listing/:id`. Deep links: custom scheme `carfeed://app/<path>` (Android intent filter with `flutter_deeplinking_enabled`, iOS `CFBundleURLTypes` + `FlutterDeepLinkingEnabled`; go_router opens `<path>`). https App Links / Universal Links once a final domain exists (see `site/README.md`).

## Database

Migrations in order: `01_enums`, `02_tables`, `03_indexes`, `04_rls`, `05_seed`, `06_contact_threshold_total`, `07_dev_seed` (dev only, needs auth user `dev@carfeed.test`), `08_auth_profiles`, `09_consents_and_settings`, `10_lock_profile_account_type`, `11_chat`, `12_share`, `13_sell`. All in `supabase/migrations/`; run new ones in the SQL editor. The whole chain 01→13 has been run on Postgres 16 + PostGIS with a stand-in for Supabase's `auth`/`storage` schemas, and the app's queries replayed through PostgREST 12 (anon and authenticated).

### Enums
`account_type` consumer | dealer_member · `user_intent` buy | sell | browse | dealer · `seller_type` private | dealer · `listing_status` draft | active | sold | expired | removed · `media_kind` video | photo | cover · `fuel_type` petrol | diesel | hybrid | plugin_hybrid | electric | lpg | cng | other · `transmission_type` manual | automatic | semi_automatic · `dealer_role` owner | seller · `subscription_status` trial | conditional_free | active | past_due | canceled · `billing_method` manual_invoice | card · `event_type` impression | view | watch_time | zoom | open_detail | save | unsave | share | contact_chat | contact_whatsapp · `notification_type` new_message | price_drop | listing_sold | saved_search_match | new_contact | listing_expiring · `report_reason` scam | misleading_info | already_sold | inappropriate | other · `report_status` open | reviewed | actioned | dismissed · `platform` ios | android | web · `consent_kind` terms | privacy | age_14 | marketing_email | seller_age · `gender` female | male | other | undisclosed

### Tables (key columns)
Column defaults worth knowing: all UUID PKs `gen_random_uuid()`; `created_at`/`updated_at` default `now()`; listings `status` default `draft`, `currency` `EUR`, `attributes` `{}`; profiles `account_type` default `consumer`, `whatsapp_public` false, `locale` `it`; subscriptions `status` default `trial`, `billing_method` `manual_invoice`; saved_searches `notify` true; listing_questions `is_public` false; notification_preferences `enabled` true. `events` and `listing_price_history` use bigint identity PKs.
- **profiles** id (= auth.users), account_type, intent, display_name, avatar_path, phone, whatsapp_public, city, location (geography), locale, onboarding_completed_at, birth_date (optional, ≥ 1900; the app allows 14+ only), gender (optional). Row created by trigger `on_auth_user_created`.
- **user_consents** (09) bigint identity PK, profile_id (CASCADE), kind, granted, document_version, platform, created_at. **Append-only** proof of consent: RLS select/insert own, no update/delete. View **current_consents** (security_invoker): latest row per (profile_id, kind).
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
- **favorites** (profile_id, listing_id) PK, price_cents_at_save, created_at
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

### Foreign keys and ON DELETE behaviour

`CASCADE` = child rows are deleted with the parent · `SET NULL` = child kept, column nulled · `NO ACTION` = delete of the parent fails while children exist.

| Child column | References | On delete |
|---|---|---|
| profiles.id | auth.users.id | CASCADE |
| buyer_preferences.profile_id | profiles | CASCADE |
| dealer_members.dealer_id | dealers | CASCADE |
| dealer_members.profile_id | profiles | CASCADE |
| subscriptions.dealer_id | dealers | CASCADE |
| subscriptions.plan_id | plans | NO ACTION |
| makes.category_id | vehicle_categories | NO ACTION |
| models.make_id | makes | CASCADE |
| listings.owner_id | profiles | CASCADE |
| listings.dealer_id | dealers | CASCADE |
| listings.category_id / make_id / model_id | vehicle_categories / makes / models | NO ACTION |
| listing_media.listing_id | listings | CASCADE |
| listing_price_history.listing_id | listings | CASCADE |
| listing_questions.listing_id | listings | CASCADE |
| listing_questions.asker_id | profiles | SET NULL |
| favorites.profile_id / listing_id | profiles / listings | CASCADE / CASCADE |
| saved_searches.profile_id | profiles | CASCADE |
| conversations.listing_id / buyer_id / seller_id / dealer_id | listings / profiles / profiles / dealers | CASCADE (all) |
| messages.conversation_id / sender_id | conversations / profiles | CASCADE / CASCADE |
| reviews.dealer_id / author_id / conversation_id | dealers / profiles / conversations | CASCADE (all) |
| reports.listing_id | listings | CASCADE |
| reports.reporter_id | profiles | SET NULL |
| events.listing_id | listings | CASCADE |
| events.profile_id | profiles | SET NULL |
| listing_stats_daily.listing_id | listings | CASCADE |
| notifications.profile_id / listing_id | profiles / listings | CASCADE / CASCADE |
| notification_preferences.profile_id | profiles | CASCADE |

Consequences to keep in mind:
- **Deleting an auth user** removes the profile and, through it, the user's listings, favorites, searches, conversations, messages, reviews and notifications. Reports and events survive with a null user.
- **Deleting a dealer** removes its memberships, subscription, listings (and their media, chats, stats) and reviews.
- **Catalogue rows in use cannot be deleted** (makes/models/categories referenced by listings, plans referenced by subscriptions): deactivate instead (`is_visible`, `is_active`).
- Hard deletes of listings also wipe their analytics; normal lifecycle uses `status` (`sold`, `expired`, `removed`), not DELETE.

### Constraints (beyond NOT NULL / PK)

- **Unique:** dealers.vat_number · subscriptions.dealer_id (one per dealer) · makes (category_id, slug) · models (make_id, slug) · conversations (listing_id, buyer_id) · reviews (dealer_id, author_id)
- **Checks:** listings `listings_seller_consistency` (dealer ⇔ dealer_id not null; private ⇔ dealer_id null) · listings year 1900-2100, mileage/price/power/owners/warranty ≥ 0, euro_class 0-6, description ≤ 3000 · conversations buyer_id ≠ seller_id · messages body 1-2000 chars · reviews rating 1-5, body ≤ 1000 · listing_questions question ≤ 500, answer ≤ 1000 · reports details ≤ 1000 · profiles display_name ≤ 60 · buyer_preferences numeric fields ≥ 0 (max_distance_km > 0)

### Triggers

- `set_updated_at` (moddatetime) before update on: profiles, buyer_preferences, dealers, subscriptions, listings, app_config
- `on_auth_user_created` after insert on auth.users → `handle_new_user()` (security definer) inserts the `profiles` row

### RLS (summary)
RLS on every table. Active listings, media, price history, dealers, reviews, catalogue, active plans and public config are readable by anon. Drafts / sold / expired only by owner or dealer members. Users manage their own profile, preferences, favorites, saved searches, notification prefs. Chat visible only to participants (buyer, seller, dealer members). Reviews only by buyers who chatted with that dealer. Events: insert-only (anon allowed). Stats: seller only. **No client write policy** for: dealer creation/membership, subscriptions, publishing, notifications, stats, price history: these go through functions / Edge Functions.

### RLS policies (exact)

"member" = exists a `dealer_members` row for that dealer with `profile_id = auth.uid()`. Policies use `(select auth.uid())`. Subqueries on other tables inherit those tables' RLS.

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| profiles | own only (chat partners get the name through `my_conversations()`, never the row: phone, birth date, gender stay private) | own id | own (not `account_type`) | — |
| buyer_preferences | own | own | own | own |
| dealers | anon + auth, all | — (edge function) | members with role owner | — |
| dealer_members | own rows only (avoids recursion) | — | — | — |
| plans | anon + auth, `is_active` | — | — | — |
| subscriptions | members | — | — | — |
| vehicle_categories | anon + auth, `is_visible` | — | — | — |
| makes, models | anon + auth, all | — | — | — |
| listings | `status = active`, or owner, or member | owner, `status = draft`, private ⇒ no dealer_id, dealer ⇒ member (trigger: no paths/dates) | owner or member (trigger `protect_listing_fields`: data and price yes; status only active→sold/removed, sold→active, draft→removed; never paths, dates, owner) | owner, only drafts |
| listing_media | if parent listing visible | — (publish-listing) | — | — |
| listing_price_history | if parent listing visible | — (trigger later) | — | — |
| listing_questions | public answered, or asker, or listing owner/member | asker = self, no answer, not public | listing owner/member | — |
| favorites, saved_searches, notification_preferences | own | own | own | own |
| conversations | buyer, seller, or member of dealer | — (`start_conversation()`) | — (`mark_conversation_read()`, trigger on messages) | — |
| messages | if conversation visible | sender = self and conversation visible | — | — |
| reviews | anon + auth, all | author = self and own conversation with that dealer | own | own |
| reports | — | reporter = self, status open | — | — |
| events | — | anon + auth, profile_id null or self | — | — |
| listing_stats_daily | listing owner/member | — | — | — |
| notifications | own | — | own (mark read) | — |
| app_config | anon + auth, `is_public` | — | — | — |

Storage policies: `listing-drafts` select/insert/update/delete only when first folder = `auth.uid()`; `avatars` insert/update/delete same rule (public read); `listing-media` no client write policy (public read via bucket flag).

No known loose spots left in the client write policies: listings are locked by `protect_listing_fields` (migration 13), conversations are written only by functions (migration 11), profiles `account_type` is locked by the trigger `protect_account_type` from migration 10: only server-side roles can change it.)

### Indexes

listings: partial `where status = 'active'` on (published_at desc), (category_id, price_cents), (make_id, model_id), (year), (mileage_km), (expires_at), (sponsored_until) where not null; GIST (location); (owner_id, created_at desc); (dealer_id, created_at desc) where dealer_id not null · listing_media (listing_id, sort_order) · listing_price_history (listing_id, changed_at desc) · listing_questions (listing_id, created_at desc) · favorites (listing_id) · saved_searches (profile_id), (last_notified_at) where notify · conversations (buyer_id | seller_id | dealer_id, last_message_at desc) · messages (conversation_id, created_at desc) · dealer_members (profile_id) · dealers GIST (location) · subscriptions (status) · reviews (dealer_id, created_at desc) · makes (category_id, is_popular desc, name) · models (make_id, name) · reports (created_at) where open · events (listing_id, created_at) + BRIN (created_at) · notifications (profile_id, created_at desc), (profile_id) where unread

### Storage
- `listing-drafts` (private): `{auth.uid}/{uuid}.ext`, owner-only
- `listing-media` (public, CDN): `{uuid}/{uuid}.ext`, written only server-side on publish (unguessable, no user id in URLs)
- `avatars` (public): `{auth.uid}/{uuid}.ext`

### app_config keys
`config_version` (bump on every change) · `app_versions` {ios/android: {min, latest}} · `legal` {privacy_policy_url, terms_url, support_email, terms_version, privacy_version} (bump a version when its text changes: signed-in users must accept again; URLs are placeholders until the real documents exist) · `feature_flags` {billing_enabled, ai_search_enabled, push_enabled, whatsapp_contact_enabled, reviews_enabled} · `onboarding` {login_nudge_after_listings, second_nudge_after_listings, preferences_nudge_after_listings, show_after_listings (default 4 in app)} · `dealer_trial` {trial_months 3, conditional_free_months 3, contact_threshold_total 30, founder_price_cents 2900} · `contact_definition` · `listing_lifecycle` {confirm_every_days 21, expire_after_days_without_confirm 7} · `feed` {page_size 10, prefetch_next_videos 2, prefetch_seconds 3} · `media` {clip_seconds 5, video_max_height 1920, video_min_height 720, video_bitrate_kbps 4500, video_fps 30, photo_max_long_side 4000} · `share` {base_url} (share site, https, no trailing slash; null = the app shares `carfeed://app/listing/<id>`) · `transfer_costs` (optional, app defaults if missing) {ipt_base_cents 15081, ipt_base_max_kw 53, ipt_per_kw_cents 351.19, provincial_surcharge_pct 30, fixed_fees_cents 8520}

## Edge Functions

### dealer-signup (`supabase/functions/dealer-signup/index.ts`)

Input: `POST { vat_number, display_name }` with the user's JWT. Uses the anon client to identify the user and a service-role client for writes (bypasses RLS).

Flow (sequential, no Promise.all):
1. Auth check → 401 `unauthorized`. Body validation (11-digit IT VAT, non-empty name ≤ 60) → 400 `bad_request`.
2. `dealers.vat_number = 'IT' || vat` already exists → 409 `vat_taken`.
3. VIES REST `GET https://ec.europa.eu/taxation_customs/vies/rest-api/ms/IT/vat/{vat}` (8 s timeout). Network/HTTP error → 503 `vies_unavailable`; `isValid = false` → 422 `vat_invalid`. VIES name/address `"---"` treated as missing (legal_name falls back to display_name).
4. Reads `app_config.dealer_trial` for trial dates and threshold.
5. Insert **dealer** (vat_verified_at = now, vies_payload stored). A unique violation (`23505`, same VAT registered concurrently since step 2) → 409 `vat_taken`.
6. Insert **dealer_members** (owner).
7. Insert **subscriptions** (plan `base`, status `trial`, trial_ends_at = now + trial_months, conditional_ends_at = trial_ends_at + conditional_free_months, contact_threshold = contact_threshold_total, founder price, is_founder = true).
8. Update **profiles** (`account_type = dealer_member`, `intent = dealer`) — deliberately the **last** write.

Rollback: any failure in steps 6-8 deletes subscriptions, then dealer_members, then the dealer, **explicitly** (does not rely on CASCADE). Because the profile update is last, a failure never leaves the profile as `dealer_member` without a dealer; if step 8 itself fails the profile is unchanged. Returns 500 `server_error`. Not wrapped in a DB transaction: if atomicity becomes critical, move steps 5-8 into a `security definer` SQL function called via RPC.

Known gap: VAT is trusted from VIES only at signup (no periodic re-check).

### publish-listing (`supabase/functions/publish-listing/index.ts`)

`POST { listing_id, video_duration_ms? }` with the user's JWT; service role inside. The app has inserted the draft row (id = draft id) and uploaded to `listing-drafts/<owner id>/<listing id>/`: `video.mp4` and `cover.jpg` (required), `photo-<NN>-<step>.jpg` (carousel, NN = order). Checks the caller is the owner or a member of the listing's dealer (else 404 `not_found`), status `draft` (already `active` → 200, a retry; else 409 `not_draft`), required data make, model, year, km, price, fuel, city (400 `incomplete` + `fields`), required files (409 `missing_media`). Moves the files (`storage.move` with `destinationBucket`) to `listing-media/<listing id>/<uuid>.<ext>`, inserts `listing_media` (video, cover, photos with `capture_step`), sets the listing `active` with `published_at` / `last_confirmed_at` = now, `video_path`, `cover_path`, `video_duration_ms`, then the first `listing_price_history` row. Any failure after the move moves the files back (draft can be published again) → 500 `server_error`. Type-checked with `tsc` against supabase-js types (no Deno here).

### delete-account (`supabase/functions/delete-account/index.ts`)

`POST` with the user's JWT (the app re-authenticates with the password first). Removes the user's files in `listing-drafts` and `avatars` (best effort), then `auth.admin.deleteUser`: the database cascades profile, preferences, favorites, saved searches, consents, the user's listings, chats, messages, reviews, notifications. A dealer whose only owner is deleted stays without members. Errors: 401 `unauthorized`, 500 `server_error`.

## Database functions

- `handle_new_user()` trigger function on `auth.users` insert → creates `profiles` row (`security definer`, `search_path = ''`, `on conflict do nothing`). Migration `08_auth_profiles.sql` also backfills profiles for pre-existing users.
- `protect_account_type()` trigger (migration 10): `account_type` changes only from server-side roles.
- `protect_listing_fields()` trigger (migration 13, before insert/update on listings, only for anon/authenticated): inserts only as plain drafts; updates never touch owner, dealer, seller type, published/confirmed/expiry/sponsored dates, video/cover paths or duration; status moves only active → sold/removed, sold → active, draft → removed (`sold_at` set/cleared by the trigger). Error `listing_field_locked` / `listing_status_locked` (42501).
- Chat (migration 11, all `security definer`, `search_path = ''`, callable by `authenticated` only):
  - `start_conversation(p_listing_id, p_body) → uuid`: the first "Contatta" message. Listing must be active and not the user's (owner or dealer member); creates the conversation (`on conflict` reuses it) and inserts the message in one call, so a seller never sees an empty chat. A new chat writes one `contact_chat` event (= one contact). Errors by message: `not_authenticated` / `own_listing` (42501, HTTP 403), `listing_unavailable` / `empty_message` (P0001, HTTP 400).
  - `mark_conversation_read(p_conversation_id)`: sets `buyer_last_read_at` or `seller_last_read_at` for the caller's side.
  - `my_conversations(p_conversation_id?, p_before?, p_limit = 30)`: Inbox rows, newest activity first: id, listing_id, is_buyer, buyer_id, other_name (dealer name, else the other profile's display_name), other_is_dealer, listing title / cover / price / status, last message body + `last_message_mine`, last_message_at, `activity_at` (page cursor), `unread` (last message after the caller's read marker). One id = one row (chat header, Realtime refresh). Filter written for the conversations indexes.
  - `seller_whatsapp(p_listing_id) → text | null`: the number only for an active listing with `whatsapp_enabled`; dealer → `dealers.whatsapp`, private → `profiles.phone` when `whatsapp_public`. Each answer with a number writes a `contact_whatsapp` event (dashboards count distinct users).
  - Trigger `messages_touch_conversation` (after insert on messages): sets `last_message_at` and the sender side's read marker.
- Realtime publication `supabase_realtime`: `messages`, `conversations` (Realtime applies RLS: each user only receives their own chats).
- Planned: feed RPC (returns listings + seller display info, since profiles are not readable by others), dealer entitlements (max active listings per plan, checked in publish-listing), price-history trigger, nightly stats aggregation (contacts = conversations + distinct `contact_whatsapp` users), listing expiry, push on new message.

## Status

Done: schema, RLS, seed, core app (config, theme, router, deep-link routes, analytics), feed (real data, video players, zoom, overlay, loading/empty/error), email + password login sheet, onboarding (intent, preferences, dealer signup via VIES), minimal profile, listing detail, save, feed filters, search + saved searches, consents (sign up + gate), settings, contact (chat + Inbox + WhatsApp), share (share sheet + share site), sell flow (capture → summary → details → publish). Designs for all screens and states exist in the Claude canvas mockup.

Listing detail (`/listing/:id`): video header (same tap/zoom as the feed, pauses when scrolled away or covered; opened from the feed it receives the feed's `SharedVideo` through go_router `extra` and continues it, no second download — the feed stops driving that player until the page closes; from a link or a grid it creates its own), title/version/price/facts/location, total cost (price + ownership transfer estimate, cars only: IPT fixed ≤ 53 kW or per kW above, +30% provincial surcharge, + 85.20 fixed fees; motorcycles not estimated until their IPT rules are confirmed), photo strip + full-screen viewer, specs grid, collapsible description, seller (dealer with VAT-verified badge and reviews when `reviews_enabled`; private sellers anonymous), Q&A (public answered + own pending; ask = login sheet then insert), sticky price + Contatta (+ WhatsApp when on). Unavailable listing (sold/removed, hidden by RLS) shows a dedicated state; back falls back to the feed when opened from a link.

Settings (`/settings`): email change and password change (both after re-entering the current password), display name, optional birth date (date picker ends 14 years ago) and gender, per-type notification switches (`notification_preferences`, missing row = on; buyer and seller groups), push switch shown as "In arrivo" until `push_enabled`, promotional emails (a `marketing_email` consent row), Termini / Privacy (open in the browser, with the acceptance date), support email, sign out, delete account (password + `delete-account`).

Save: bookmark on the feed and on the listing screen; guests get the login sheet, then the listing is saved (never un-saved by that tap). `favorites` upsert with `ignoreDuplicates` keeps the first `price_cents_at_save`. Profile "Salvati": two-column grid newest first (orders by `favorites.created_at`), "Sceso di € X" badge when the price dropped since saving, "Non più disponibile" card when RLS hides the listing (remove from the bookmark). Events `save` / `unsave` tracked. The "Salvati" list is loaded once and then kept in step locally (save adds the card from the listing data already on screen, unsave removes it): no request per tap. Price-drop push alerts come with notifications.

Feed filters: `FeedFilters` (category, price min/max, makes, models, year min/max, mileage max, fuel types, transmission, novice driver, province, free words; same names as `listings` columns, stored as is in `saved_searches.filters`). **One shared state** for the feed pills, the filter sheet and Search. Novice = cars the seller marked `attributes.novice_ok = true`, or, when the seller said nothing, cars ≤ 105 kW (legal limit; the 75 kW/t rule cannot be checked, listings have no weight); motorcycles are not filtered (licence classes AM/A1/A2 live in `attributes.license_class`, a future filter); free words and novice go into one PostgREST `or=(and(...))` built by `logicFilter()`. Pills over the video (Prezzo, Marca, Anno, Km) open their section of `FilterSheet`; the tune button opens all sections and shows how many are active. The sheet edits a draft and applies on "Mostra annunci", so the feed reloads once (`FeedController` watches the filters; cursor pagination unchanged). Feed list: cursor pagination on (published_at, id), so listings sharing a timestamp are never skipped. Each first page has a `generation`; the pager is keyed by it, so new filters or a refresh build a new pager (players are kept by position and must not be reused across lists), and a "load more" answered after the list changed is dropped. The feed pager creates video players and tracks `view` only while visible (Search changes the filters while the feed tab is hidden). Filters are stored on the phone (`PrefKeys.feedFilters`); until the user applies any, they follow the onboarding preferences (novice driver is not a filter). No results with filters → "Rimuovi i filtri" / "Modifica filtri".

Search tab (`/search`): a search box understood locally by `QueryParser` (catalog of every make and model loaded once per session, paginated past PostgREST's 1000-row cap; makes come from `allMakesProvider`, the single makes request of the session, also behind `makesProvider(category)` used by onboarding and the filter sheet). **No request while typing**: suggestions (`suggest()`) are computed in memory on each keystroke; the query is applied on submit or after a 400 ms pause (waits for the catalog if it is still loading). Parsing: province capitals → `province`; makes (aliases: vw, alfa, mercedes) and models, longest word sequence first, bare numbers ("500", "2008") or 1–2 letter names only next to their make; 4 digits 1950–this year = year ("dal" = min, "fino al" = max, alone = exact); "8000", "8k", "8mila", "sotto 10mila" = max price ("da", "sopra", "oltre", "tra" = min); "100k km" / "100.000 km" = max km; auto/moto, automatica/manuale, neopatentato, fuel synonyms (benzina, gasolio, gpl, metano, ibrida, plug-in, elettrica). Unknown words are searched in version/description **only if nothing structured was recognized**, otherwise ignored and shown as "Parole non usate". What was understood shows as removable chips (+ "Filtri" opens the sheet); changing filters elsewhere clears the box. Before typing: recent searches (phone only, last 10, also for guests), saved searches, popular brands. Results = the feed's own list as a grid (tap opens the listing; "Carica altri"); "Guarda nel feed" switches tab on the same results. Zero results → "Prova senza «last chip»" or "Salva ricerca e avvisami". Saved searches only for signed-in users (login sheet for guests), named with `describeFilters()`, newest first (`created_at`); `name` is nullable in the table; bell for `notify` only when `feature_flags.push_enabled`.

Contact: "Contatta" on the listing (guests sign in first; the seller sees "Il tuo annuncio" instead). An existing chat about that listing is found in the loaded Inbox (else one lookup) and opened; otherwise `/chat/new/:listingId` shows the seller, a safety tip (no deposits before seeing the vehicle) and quick replies; the first message calls `start_conversation()` and the same screen continues as that chat. Chat: latest 40 messages, older pages on scroll, new ones through Realtime (channel per chat, filtered on `conversation_id`); send is optimistic ("Invio…", "Non inviato · tocca per riprovare" with retry / delete), the Realtime echo of an own message never duplicates it; read marker set on open and on incoming messages (at most every 2 s); after a reconnect only messages newer than the last one are fetched. Inbox tab (`/inbox`): one `my_conversations()` call per login (first page, more on scroll), then Realtime on `conversations` says which chat changed and only that row is fetched again (changes coalesced over 300 ms); unread dot and bold rows, "Tu: …" for own last message, "Il tuo annuncio" for seller-side chats, "Venduto" when the listing is gone; the tab icon shows the number of unread chats. Both wait for the Realtime subscription (max 3 s) before the first load, so nothing falls between. WhatsApp: shown next to Contatta when the listing has `whatsapp_enabled` and `feature_flags.whatsapp_contact_enabled`; signed-in users only, `seller_whatsapp()` gives the number, opens `wa.me/<digits>` with a first message ("Ciao! Ti scrivo per … visto su …"); Italian numbers without prefix get +39. No push yet (needs FCM/APNs).

Share: button on the feed and the listing → the phone's share sheet (`share_plus`) with "Volkswagen Golf · 2019 · € 14.900 · Milano\nGuarda l'annuncio su Carfeed: <link>"; the link is `<share.base_url>/l/<id>` or, while the site is not online, `carfeed://app/listing/<id>`. `share` event tracked unless the sheet was dismissed. Share site (`site/`, Cloudflare Pages): `/l/<id>` queries Supabase REST with the anon key (RLS: active listings only) and returns a script-free page with Open Graph / Twitter tags (title + price, km · fuel · gearbox · city, cover image), the listing, "Apri nell'app" (`carfeed://app/listing/<id>`) and store buttons when `IOS_APP_URL` / `ANDROID_APP_URL` are set; gone listing or bad id → 404 page, Supabase down → 503; cache 5 min; strict CSP. Tested with `node --test`, also against the local PostgREST.

Sell flow (`+` tab → `/sell`): (1) Auto / Moto, tips, "Inizia le riprese" (guests sign in first); a draft left on the phone shows "Riprendi" / "Ricomincia" (another category asks before dropping it). (2) Capture: steps from `vehicle_categories.capture_steps` (built-in copy if offline), "Step N di M" + segments, step title and instruction, dashed silhouette over the full-screen camera (`Silhouette` painter, replaceable by real SVGs later), plate tip, torch, Video 5 s / Foto toggle, shutter with a 5 s ring (stops by itself), "Salta", last-shot thumbnail "N/M" → summary, "Prossimo: …". Camera 1080p, 30 fps, bitrate from `app_config.media`, audio on (engine sound), portrait locked; an interrupted clip is dropped; permission denied → message + retry. After a shot it moves to the next missing step (then the summary); `single=1` (retake) goes back. (3) "Le tue riprese": each step with thumbnail, "Video · 5 s" / "Foto", check; "Da fare" for missing required ones; dashed "+" rows for optional ones ("Difetti visibili · aumenta la fiducia"); tap → Rifai / Elimina (optional only); "Crea il video" needs every required step and at least one video. (4) "Dati e prezzo": the video is made and uploaded in the background meanwhile ("Stiamo preparando il video · N%": render 0-70%, uploads 70-100%; a retake restarts it; failure → tap to retry); make / model pickers from the catalog, year, km (thousands dots), fuel chips, "+ Altri dettagli" (version, gearbox, kW with ≈ CV, owners, Euro class, colour, service history, body type + novice ok / moto type, cc, licence), price, description, city (a province capital fills the province) + province, WhatsApp switch (private: phone saved to the profile with `whatsapp_public`; dealer: the dealer's number), 18+ / parental-consent tick for private sellers (`seller_age` consent, asked once). "Pubblica annuncio": saves the draft row (upsert, dealer listing when the user is a dealer member), waits for the media, calls `publish-listing`, then deletes the phone copy and refreshes the feed. (5) "La tua Golf è online", next confirmation in `confirm_every_days / 7` weeks, listing card, "Condividi il link", "Vedi l'annuncio". The draft (`PrefKeys.sellDraft` + `<documents>/sell/<id>/`) is saved after every change; uploads are tracked per file and source, so only what changed is uploaded again and stale ones are removed. Not built and not testable here: the native render on a real phone (package tested upstream).

## Next (in order)

1. **My listings**: list in the profile (active / draft / sold), mark sold, remove, edit price and data, "è ancora disponibile?" confirmation.
2. **Polish**: login nudges, price vs market badge, feed function returning private seller names (profiles are not readable by others).

Later: dealer dashboard (reads `listing_stats_daily`), nightly stats aggregation, listing expiry job, notifications + push (FCM/APNs, `device_tokens`), AI search (Claude via Edge Function, filters only from DB data), Google/Apple login.

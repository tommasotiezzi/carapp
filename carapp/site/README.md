# Share site

The page a shared link opens: `https://<site>/l/<listing id>`.

- Rendered on the server, so WhatsApp, Telegram, iMessage, Instagram and X show a preview (cover photo, "Volkswagen Golf 2019 · € 14.900", km · fuel · city). No JavaScript on the page.
- Shows the listing and an "Apri nell'app" button (`carfeed://app/listing/<id>`), plus store buttons once the store links exist.
- Only active listings (the anon key goes through RLS). A sold or removed listing → 404 "Annuncio non più disponibile".
- Short cache (5 minutes), so price changes show up quickly.

Hosted on **Cloudflare Pages** (free, `*.pages.dev` address, no domain needed). The logic lives in `src/listing_page.js` (plain `fetch` / `Response`), so moving it to another host means rewriting only `functions/l/[id].js`.

```
public/              static files (home page, robots.txt, security headers)
functions/l/[id].js  GET /l/:id -> src/listing_page.js
src/listing_page.js  query to Supabase + HTML
test/                node --test (npm test)
```

## Deploy (once)

1. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** → **Connect to Git** → repository `tommasotiezzi/carapp`.
2. Build settings:
   - Production branch: `main`
   - Framework preset: **None**
   - Build command: *(empty)*
   - Build output directory: `public`
   - Root directory (advanced): `carapp/site`
3. **Environment variables** (Production):
   - `SUPABASE_URL` = `https://<project>.supabase.co`
   - `SUPABASE_ANON_KEY` = the anon / publishable key (the same one the app uses; it is public)
   - optional: `APP_NAME` (default `Carfeed`), `IOS_APP_URL`, `ANDROID_APP_URL`
4. **Save and Deploy**. The site is at `https://<project name>.pages.dev`.
5. Check it: open `https://<project name>.pages.dev/l/<id of an active listing>`.
6. Tell the app to share these links (Supabase SQL editor):
   ```sql
   update public.app_config
     set value = jsonb_build_object('base_url', 'https://<project name>.pages.dev')
     where key = 'share';
   update public.app_config set value = to_jsonb((value #>> '{}')::int + 1)
     where key = 'config_version';
   ```
   Until then the app shares `carfeed://app/listing/<id>`, which works only on phones with the app installed.

Every push to `main` deploys the site again.

## Test

```bash
cd carapp/site
npm test
# against a local PostgREST with the app schema:
LOCAL_POSTGREST=http://localhost:3001 LOCAL_LISTING_ID=<id> npm test
```

## Later: https links that open the app directly

With a final domain, `https://<domain>/l/<id>` can open the app without the page (Android App Links, iOS Universal Links):
- serve `/.well-known/assetlinks.json` (package name + SHA-256 of the signing certificate) and `/.well-known/apple-app-site-association` (Team ID + bundle ID) from `public/`;
- add an `https` intent filter with `android:autoVerify="true"` and the iOS Associated Domains entitlement `applinks:<domain>`.

This needs the final bundle ID (`com.tommasotiezzi.carfeed`) and the signing keys, so it waits for the release setup.

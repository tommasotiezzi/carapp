import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handleListing, formatPrice, isListingId, escapeHtml } from '../src/listing_page.js';

const ID = '608044f2-ccdf-413a-b3c0-3cbc47100b3d';
const env = { SUPABASE_URL: 'https://proj.supabase.co/', SUPABASE_ANON_KEY: 'sb_publishable_abc' };
const request = { url: `https://carfeed.pages.dev/l/${ID}` };

const row = {
  id: ID,
  seller_type: 'dealer',
  version: '1.6 TDI <script>alert(1)</script>',
  year: 2019,
  mileage_km: 78400,
  price_cents: 1490000,
  fuel_type: 'diesel',
  transmission: 'manual',
  city: 'Milano',
  province: 'MI',
  cover_path: 'abc/cover 1.jpg',
  make: { name: 'Volkswagen' },
  model: { name: 'Golf' },
  dealer: { display_name: 'Auto "Bianchi"', vat_verified_at: '2026-01-01T00:00:00Z' },
};

const fakeFetch = (rows, status = 200) => {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url, init });
    return new Response(JSON.stringify(rows), { status });
  };
  return { impl, calls };
};

test('price and id helpers', () => {
  assert.equal(formatPrice(1490000), '€ 14.900');
  assert.equal(formatPrice(123456789), '€ 1.234.567');
  assert.equal(formatPrice(null), '');
  assert.ok(isListingId(ID));
  assert.ok(!isListingId('1 or 1=1'));
  assert.equal(escapeHtml(`<a href="x">'&`), '&lt;a href=&quot;x&quot;&gt;&#39;&amp;');
});

test('a listing: preview tags, escaped text, app link, cache', async () => {
  const f = fakeFetch([row]);
  const res = await handleListing({ id: ID, env, request, fetchImpl: f.impl });
  const html = await res.text();

  assert.equal(res.status, 200);
  assert.match(res.headers.get('Content-Type'), /text\/html/);
  assert.equal(res.headers.get('Cache-Control'), 'public, max-age=300');
  assert.ok(html.includes('<meta property="og:title" content="Volkswagen Golf 2019 · € 14.900 | Carfeed">'));
  assert.ok(html.includes('<meta property="og:description" content="78.400 km · Diesel · Manuale · Milano (MI)">'));
  assert.ok(html.includes('content="https://proj.supabase.co/storage/v1/object/public/listing-media/abc/cover%201.jpg"'));
  assert.ok(html.includes('href="carfeed://app/listing/' + ID + '"'));
  assert.ok(html.includes('Auto &quot;Bianchi&quot;'));
  assert.ok(html.includes('P. IVA verificata'));
  assert.ok(!html.includes('<script>'), 'no script, and the version is escaped');
  assert.ok(html.includes('&lt;script&gt;'));

  const { url, init } = f.calls[0];
  assert.ok(url.startsWith('https://proj.supabase.co/rest/v1/listings?select='));
  assert.ok(url.endsWith(`&id=eq.${ID}&limit=1`));
  assert.equal(init.headers.apikey, 'sb_publishable_abc');
  assert.equal(init.headers.Authorization, undefined, 'publishable keys are not sent as Bearer');
});

test('legacy anon JWT also goes in Authorization; store buttons when set', async () => {
  const f = fakeFetch([{ ...row, dealer: null, seller_type: 'private', cover_path: null }]);
  const res = await handleListing({
    id: ID,
    env: { ...env, SUPABASE_ANON_KEY: 'eyJhbGciOi.x.y', IOS_APP_URL: 'https://apps.apple.com/app/id1' },
    request,
    fetchImpl: f.impl,
  });
  const html = await res.text();
  assert.equal(f.calls[0].init.headers.Authorization, 'Bearer eyJhbGciOi.x.y');
  assert.ok(html.includes('Venditore privato'));
  assert.ok(html.includes('Scarica per iPhone'));
  assert.ok(!html.includes('Scarica per Android'));
  assert.ok(!html.includes('og:image'));
  assert.ok(html.includes('name="twitter:card" content="summary"'));
});

test('gone listing = 404; bad id = 404 without a request; Supabase down = 503', async () => {
  const empty = fakeFetch([]);
  let res = await handleListing({ id: ID, env, request, fetchImpl: empty.impl });
  assert.equal(res.status, 404);
  assert.ok((await res.text()).includes('Annuncio non più disponibile'));

  const none = fakeFetch([]);
  res = await handleListing({ id: '../admin', env, request, fetchImpl: none.impl });
  assert.equal(res.status, 404);
  assert.equal(none.calls.length, 0);

  const down = fakeFetch({ message: 'boom' }, 500);
  res = await handleListing({ id: ID, env, request, fetchImpl: down.impl });
  assert.equal(res.status, 503);
  assert.equal(res.headers.get('Cache-Control'), 'no-store');
  assert.ok((await res.text()).includes('Non riusciamo a caricare'));
});

// Runs the real query against a local PostgREST with the app schema when
// LOCAL_POSTGREST is set (e.g. http://localhost:3001).
test('the select works on the real schema', { skip: !process.env.LOCAL_POSTGREST }, async () => {
  const local = async (url, init) => {
    const target = url.replace('https://proj.supabase.co/rest/v1', process.env.LOCAL_POSTGREST);
    return fetch(target, init);
  };
  const res = await handleListing({ id: process.env.LOCAL_LISTING_ID ?? ID, env, request, fetchImpl: local });
  const html = await res.text();
  assert.equal(res.status, 200, html.slice(0, 300));
  assert.ok(html.includes('og:title'));
});

// Share page of a listing: /l/<id>. Rendered on the server so chat apps
// (WhatsApp, Telegram, iMessage, Instagram) read the preview tags: they do
// not run JavaScript. The page itself has no script at all.
//
// Environment (Cloudflare Pages > Settings > Variables):
//   SUPABASE_URL        https://<project>.supabase.co
//   SUPABASE_ANON_KEY   anon / publishable key (public, read-only by RLS)
//   APP_NAME            optional, default "Carfeed"
//   APP_SCHEME          optional, default "carfeed" (app link carfeed://app/...)
//   IOS_APP_URL         optional, App Store link (button hidden if missing)
//   ANDROID_APP_URL     optional, Play Store link (button hidden if missing)

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const SELECT =
  'id,seller_type,version,year,mileage_km,price_cents,fuel_type,transmission,' +
  'city,province,cover_path,make:makes(name),model:models(name),' +
  'dealer:dealers(display_name,vat_verified_at)';

const FUEL = {
  petrol: 'Benzina',
  diesel: 'Diesel',
  hybrid: 'Ibrida',
  plugin_hybrid: 'Ibrida plug-in',
  electric: 'Elettrica',
  lpg: 'GPL',
  cng: 'Metano',
  other: 'Altro',
};

const TRANSMISSION = {
  manual: 'Manuale',
  automatic: 'Automatico',
  semi_automatic: 'Semiautomatico',
};

export const isListingId = (id) => typeof id === 'string' && UUID.test(id);

export function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

/** 1490000 cents -> "€ 14.900" (same as the app). */
export function formatPrice(cents) {
  if (cents == null) return '';
  return `€ ${thousands(Math.trunc(cents / 100))}`;
}

const thousands = (n) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');

const config = (env) => ({
  supabaseUrl: String(env.SUPABASE_URL || '').replace(/\/+$/, ''),
  key: env.SUPABASE_ANON_KEY || '',
  appName: env.APP_NAME || 'Carfeed',
  scheme: env.APP_SCHEME || 'carfeed',
  iosUrl: env.IOS_APP_URL || '',
  androidUrl: env.ANDROID_APP_URL || '',
});

/** Only active listings come back: RLS hides the others from anon. */
export async function fetchListing(env, id, fetchImpl = fetch) {
  const c = config(env);
  const url = `${c.supabaseUrl}/rest/v1/listings?select=${SELECT}&id=eq.${id}&limit=1`;
  const headers = { apikey: c.key, Accept: 'application/json' };
  // Legacy anon keys are JWTs and go in Authorization too; the new
  // publishable keys must not.
  if (c.key.startsWith('eyJ')) headers.Authorization = `Bearer ${c.key}`;
  const res = await fetchImpl(url, { headers });
  if (!res.ok) throw new Error(`Supabase ${res.status}`);
  const rows = await res.json();
  return rows[0] ?? null;
}

function coverUrl(c, path) {
  if (!path) return null;
  if (/^https?:\/\//.test(path)) return path;
  const encoded = path.split('/').map(encodeURIComponent).join('/');
  return `${c.supabaseUrl}/storage/v1/object/public/listing-media/${encoded}`;
}

/** The texts both the preview tags and the page use. */
export function describe(listing) {
  const title = [listing.make?.name, listing.model?.name].filter(Boolean).join(' ');
  const facts = [
    listing.year,
    listing.mileage_km != null ? `${thousands(listing.mileage_km)} km` : null,
    FUEL[listing.fuel_type],
    TRANSMISSION[listing.transmission],
  ].filter(Boolean);
  const place = listing.city
    ? listing.province ? `${listing.city} (${listing.province})` : listing.city
    : null;
  return { title, price: formatPrice(listing.price_cents), facts, place };
}

const STYLE = `
:root{--ink:#0D0F12;--muted:#5D636B;--line:#E3E7EE;--blue:#1D4ED8;--soft:#F3F5F9}
*{box-sizing:border-box}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:var(--ink);background:var(--soft)}
main{max-width:480px;margin:0 auto;background:#fff;min-height:100vh}
header{padding:14px 16px;background:var(--ink);color:#fff;font-weight:700;font-size:18px}
.cover{display:block;width:100%;aspect-ratio:3/4;object-fit:cover;background:#1B1F25}
.body{padding:20px 16px 32px}
h1{font-size:24px;line-height:1.2;margin:0}
.version{color:var(--muted);margin:4px 0 0}
.price{font-size:28px;font-weight:800;margin:12px 0 0}
.facts,.place,.seller{color:var(--muted);margin:8px 0 0;font-size:15px}
.seller strong{color:var(--ink)}
.badge{display:inline-block;margin-left:6px;padding:1px 6px;border-radius:6px;background:#DCFCE7;color:#166534;font-size:12px}
.actions{margin-top:24px;display:grid;gap:10px}
.btn{display:block;text-align:center;padding:14px;border-radius:12px;font-weight:700;text-decoration:none;font-size:16px}
.primary{background:var(--blue);color:#fff}
.secondary{border:1px solid var(--line);color:var(--ink)}
.note{color:var(--muted);font-size:14px;text-align:center;margin-top:16px}
`;

function page({ c, title, description, image, url, body, robots = 'noindex' }) {
  const meta = [
    `<meta property="og:site_name" content="${escapeHtml(c.appName)}">`,
    `<meta property="og:type" content="website">`,
    `<meta property="og:title" content="${escapeHtml(title)}">`,
    `<meta property="og:description" content="${escapeHtml(description)}">`,
    `<meta property="og:url" content="${escapeHtml(url)}">`,
    `<meta name="description" content="${escapeHtml(description)}">`,
    `<meta name="twitter:card" content="${image ? 'summary_large_image' : 'summary'}">`,
    `<meta name="twitter:title" content="${escapeHtml(title)}">`,
    `<meta name="twitter:description" content="${escapeHtml(description)}">`,
  ];
  if (image) {
    meta.push(`<meta property="og:image" content="${escapeHtml(image)}">`);
    meta.push(`<meta name="twitter:image" content="${escapeHtml(image)}">`);
  }
  return `<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="${robots}">
<meta name="theme-color" content="#0D0F12">
<title>${escapeHtml(title)}</title>
${meta.join('\n')}
<style>${STYLE}</style>
</head>
<body>
<main>
<header>${escapeHtml(c.appName)}</header>
${body}
</main>
</body>
</html>`;
}

function appButtons(c, path) {
  const links = [
    `<a class="btn primary" href="${escapeHtml(`${c.scheme}://app${path}`)}">Apri nell'app</a>`,
  ];
  if (c.iosUrl) links.push(`<a class="btn secondary" href="${escapeHtml(c.iosUrl)}">Scarica per iPhone</a>`);
  if (c.androidUrl) links.push(`<a class="btn secondary" href="${escapeHtml(c.androidUrl)}">Scarica per Android</a>`);
  return `<div class="actions">${links.join('')}</div>`;
}

export function renderListing(env, listing, url) {
  const c = config(env);
  const d = describe(listing);
  const image = coverUrl(c, listing.cover_path);
  const heading = [d.title, listing.year].filter(Boolean).join(' ');
  const title = [heading, d.price].filter(Boolean).join(' · ');
  const description = [...d.facts.filter((f) => f !== listing.year), d.place].filter(Boolean).join(' · ');
  const seller = listing.dealer
    ? `<strong>${escapeHtml(listing.dealer.display_name)}</strong>${listing.dealer.vat_verified_at ? '<span class="badge">P. IVA verificata</span>' : ''}`
    : '<strong>Venditore privato</strong>';

  const body = `
${image ? `<img class="cover" src="${escapeHtml(image)}" alt="${escapeHtml(d.title)}">` : ''}
<div class="body">
<h1>${escapeHtml(d.title)}</h1>
${listing.version ? `<p class="version">${escapeHtml(listing.version)}</p>` : ''}
${d.price ? `<p class="price">${escapeHtml(d.price)}</p>` : ''}
${d.facts.length ? `<p class="facts">${escapeHtml(d.facts.join(' · '))}</p>` : ''}
${d.place ? `<p class="place">${escapeHtml(d.place)}</p>` : ''}
<p class="seller">${seller}</p>
${appButtons(c, `/listing/${listing.id}`)}
<p class="note">Video, foto e chat con il venditore sono nell'app.</p>
</div>`;
  return page({ c, title: `${title} | ${c.appName}`, description, image, url, body });
}

function renderMessage(env, url, heading, text) {
  const c = config(env);
  const body = `
<div class="body">
<h1>${escapeHtml(heading)}</h1>
<p class="facts">${escapeHtml(text)}</p>
${appButtons(c, '/feed')}
</div>`;
  return page({ c, title: `${heading} | ${c.appName}`, description: text, url, body });
}

export const renderGone = (env, url) => renderMessage(env, url,
  'Annuncio non più disponibile',
  "Potrebbe essere stato venduto. Nell'app trovi tanti altri veicoli in video.");

const renderUnavailable = (env, url) => renderMessage(env, url,
  'Non riusciamo a caricare l\'annuncio',
  'Riprova tra poco, oppure aprilo nell\'app.');

const SECURITY = {
  'Content-Type': 'text/html; charset=utf-8',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Content-Security-Policy':
    "default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
};

/** GET /l/<id>: 200 page, 404 when the listing is gone or the id is wrong. */
export async function handleListing({ id, env, request, fetchImpl = fetch }) {
  const url = request.url;
  if (!isListingId(id)) {
    return new Response(renderGone(env, url), {
      status: 404,
      headers: { ...SECURITY, 'Cache-Control': 'public, max-age=300' },
    });
  }
  try {
    const listing = await fetchListing(env, id, fetchImpl);
    if (!listing) {
      return new Response(renderGone(env, url), {
        status: 404,
        headers: { ...SECURITY, 'Cache-Control': 'public, max-age=60' },
      });
    }
    // Short cache: a price change shows up within minutes.
    return new Response(renderListing(env, listing, url), {
      status: 200,
      headers: { ...SECURITY, 'Cache-Control': 'public, max-age=300' },
    });
  } catch {
    return new Response(renderUnavailable(env, url), {
      status: 503,
      headers: { ...SECURITY, 'Cache-Control': 'no-store', 'Retry-After': '30' },
    });
  }
}

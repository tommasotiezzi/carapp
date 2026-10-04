// Cloudflare Pages Function: GET /l/<listing id> (see src/listing_page.js).
import { handleListing } from '../../src/listing_page.js';

export const onRequestGet = ({ params, env, request }) =>
  handleListing({ id: params.id, env, request });

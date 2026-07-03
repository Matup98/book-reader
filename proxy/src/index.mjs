import http from 'node:http';

const PORT = Number(process.env.PORT ?? 8787);
const LIBRETRANSLATE_URL =
  process.env.LIBRETRANSLATE_URL ?? 'http://localhost:5000';
const LIBRETRANSLATE_API_KEY = process.env.LIBRETRANSLATE_API_KEY ?? '';

/**
 * Same JSON contract that LibreTranslate uses. Keeping the shape identical
 * makes the future Cloudflare Worker a straight port of this file.
 */
async function translate(payload) {
  const body = {
    q: payload.q,
    source: payload.source ?? 'en',
    target: payload.target ?? 'es',
    format: payload.format ?? 'text',
  };
  if (LIBRETRANSLATE_API_KEY) body.api_key = LIBRETRANSLATE_API_KEY;

  const upstream = await fetch(`${LIBRETRANSLATE_URL}/translate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  const text = await upstream.text();
  return { status: upstream.status, body: text };
}

function writeCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Max-Age', '86400');
}

async function readJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString('utf-8');
  if (!raw) return {};
  return JSON.parse(raw);
}

const server = http.createServer(async (req, res) => {
  writeCors(res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, upstream: LIBRETRANSLATE_URL }));
    return;
  }

  if (req.method === 'POST' && req.url === '/translate') {
    try {
      const payload = await readJson(req);
      if (typeof payload.q !== 'string' || payload.q.length === 0) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Missing "q" field' }));
        return;
      }
      const upstream = await translate(payload);
      res.writeHead(upstream.status, { 'Content-Type': 'application/json' });
      res.end(upstream.body);
    } catch (err) {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          error: 'Upstream translation service unreachable',
          detail: String(err),
        }),
      );
    }
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`[proxy] listening on http://localhost:${PORT}`);
  console.log(`[proxy] forwarding /translate to ${LIBRETRANSLATE_URL}/translate`);
});

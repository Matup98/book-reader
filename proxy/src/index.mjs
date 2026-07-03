import http from 'node:http';

const PORT = Number(process.env.PORT ?? 8787);
const LIBRETRANSLATE_URL =
  process.env.LIBRETRANSLATE_URL ?? 'http://localhost:5000';
const LIBRETRANSLATE_API_KEY = process.env.LIBRETRANSLATE_API_KEY ?? '';
const NLLB_API_URL = process.env.NLLB_API_URL ?? 'http://localhost:7860';

const SUPPORTED_ENGINES = new Set(['libretranslate', 'nllb']);

/**
 * FLORES-200 codes used by NLLB. We only expose en/es to the app for now.
 */
const NLLB_LANG_MAP = {
  en: 'eng_Latn',
  es: 'spa_Latn',
};

/**
 * LibreTranslate: same JSON contract as upstream. Keeping the shape identical
 * makes the future Cloudflare Worker a straight port of this function.
 */
async function translateLibre(payload) {
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

/**
 * NLLB (winstxnhdw/nllb-api): GET /api/v4/translator with query params.
 * Ignores `format` (only plain text supported). Response is a plain string
 * that we normalize to the LibreTranslate `{ translatedText }` shape.
 */
async function translateNllb(payload) {
  const source = NLLB_LANG_MAP[payload.source ?? 'en'];
  const target = NLLB_LANG_MAP[payload.target ?? 'es'];
  if (!source || !target) {
    return {
      status: 400,
      body: JSON.stringify({
        error: `NLLB does not support source=${payload.source} target=${payload.target}`,
      }),
    };
  }

  const url = new URL(`${NLLB_API_URL}/api/v4/translator`);
  url.searchParams.set('text', payload.q);
  url.searchParams.set('source', source);
  url.searchParams.set('target', target);

  const upstream = await fetch(url, { method: 'GET' });
  const raw = await upstream.text();

  if (!upstream.ok) {
    return { status: upstream.status, body: raw };
  }

  // The API returns the translated string directly (sometimes JSON-quoted).
  let translatedText = raw;
  try {
    const parsed = JSON.parse(raw);
    if (typeof parsed === 'string') {
      translatedText = parsed;
    } else if (parsed && typeof parsed.result === 'string') {
      translatedText = parsed.result;
    }
  } catch {
    // raw was already a plain string; leave it as-is.
  }

  return {
    status: 200,
    body: JSON.stringify({ translatedText }),
  };
}

async function translate(payload) {
  const engine = payload.engine ?? 'libretranslate';
  if (!SUPPORTED_ENGINES.has(engine)) {
    return {
      status: 400,
      body: JSON.stringify({ error: `Unknown engine: ${engine}` }),
    };
  }
  if (engine === 'nllb') return translateNllb(payload);
  return translateLibre(payload);
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
    res.end(
      JSON.stringify({
        ok: true,
        engines: {
          libretranslate: LIBRETRANSLATE_URL,
          nllb: NLLB_API_URL,
        },
      }),
    );
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
  console.log(`[proxy] libretranslate -> ${LIBRETRANSLATE_URL}`);
  console.log(`[proxy] nllb           -> ${NLLB_API_URL}`);
});

# Deploy a producción (opcional)

Esta guía es para la fase posterior al MVP. **No forma parte del setup base**.
El MVP corre entero en local: Docker + proxy Node + Flutter en Chrome/emulador.

Cuando quieras publicar la app web y la traducción en la nube, seguí estos pasos.

## Objetivo

| Componente | Plataforma | Costo |
|------------|------------|-------|
| App web (Flutter) | Cloudflare Pages o Firebase Hosting | Gratis |
| Proxy de traducción | Cloudflare Workers | Gratis (sin cold start) |
| LibreTranslate | Render Free (Docker) | Gratis (cold start ~30–60 s tras 15 min idle) |

## 1. LibreTranslate en Render

1. Crear un servicio **Web Service** en [Render](https://render.com/) tipo *Docker*.
2. Imagen: `libretranslate/libretranslate:latest`.
3. Variables de entorno:
   - `LT_LOAD_ONLY=en,es`
   - `LT_DISABLE_WEB_UI=true`
   - Opcional: `LT_API_KEYS=true` y `LT_REQ_LIMIT=60`.
4. Puerto: `5000`.
5. Free plan: 512 MB RAM. Cargar solo `en,es` es imprescindible para no
   quedarse sin memoria.
6. Anotar la URL pública, por ejemplo
   `https://book-reader-lt.onrender.com`.

Consideraciones:
- Render suspende el servicio tras 15 min sin tráfico. La primera traducción
  después del suspenso puede tardar 30–60 s. Un ping periódico (UptimeRobot,
  cron) mitiga esto, pero consume las 750 h/mes del free tier.

## 2. Proxy en Cloudflare Workers

Portar `proxy/src/index.mjs` a un Worker. La lógica es la misma; solo cambia el
runtime.

Estructura sugerida:

```
proxy-worker/
├── wrangler.toml
└── src/index.ts
```

`wrangler.toml`:

```toml
name = "book-reader-proxy"
main = "src/index.ts"
compatibility_date = "2026-01-01"

[vars]
# Fill via `wrangler secret put LIBRETRANSLATE_URL`
```

`src/index.ts` (esqueleto):

```ts
export interface Env {
  LIBRETRANSLATE_URL: string;
  LIBRETRANSLATE_API_KEY?: string;
  ALLOWED_ORIGIN?: string;
}

const cors = (env: Env) => ({
  'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN ?? '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
});

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    if (req.method === 'OPTIONS') {
      return new Response(null, { headers: cors(env) });
    }
    const url = new URL(req.url);
    if (req.method !== 'POST' || url.pathname !== '/translate') {
      return new Response('Not found', { status: 404, headers: cors(env) });
    }

    const payload = await req.json<{
      q: string;
      source?: string;
      target?: string;
    }>();
    const body: Record<string, string> = {
      q: payload.q,
      source: payload.source ?? 'en',
      target: payload.target ?? 'es',
      format: 'text',
    };
    if (env.LIBRETRANSLATE_API_KEY) body.api_key = env.LIBRETRANSLATE_API_KEY;

    const upstream = await fetch(`${env.LIBRETRANSLATE_URL}/translate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const text = await upstream.text();
    return new Response(text, {
      status: upstream.status,
      headers: { 'Content-Type': 'application/json', ...cors(env) },
    });
  },
};
```

Secretos:

```bash
wrangler secret put LIBRETRANSLATE_URL   # https://book-reader-lt.onrender.com
wrangler secret put LIBRETRANSLATE_API_KEY  # opcional
wrangler deploy
```

Anotar la URL final del Worker, por ejemplo
`https://book-reader-proxy.<user>.workers.dev`.

## 3. App web en Cloudflare Pages

1. Build local:

   ```bash
   flutter build web \
     --release \
     --dart-define=TRANSLATE_API_URL=https://book-reader-proxy.<user>.workers.dev
   ```

2. La salida está en `build/web/`. Subirla a Cloudflare Pages (o Firebase
   Hosting) como sitio estático.

3. Alternativa: conectar el repo a Pages con el comando de build anterior y
   `build/web` como directorio de salida.

## 4. Móvil

- Android: `flutter build apk --release --dart-define=TRANSLATE_API_URL=...`.
- iOS: `flutter build ipa --release --dart-define=TRANSLATE_API_URL=...` (requiere Xcode y firma).

## Variables involucradas

- `TRANSLATE_API_URL`: URL pública del Worker. La consume la app Flutter en
  build time vía `--dart-define`.
- `LIBRETRANSLATE_URL`: URL pública del servicio en Render. Solo la conoce el
  Worker.
- `LIBRETRANSLATE_API_KEY`: opcional si activás API keys en LibreTranslate.

## Riesgos y mitigaciones

- **Cold start de LibreTranslate**: la primera traducción del día puede tardar.
  El overlay muestra un spinner, aceptable para uso personal.
- **Bundle grande de Flutter web**: normal para apps Flutter web; no impacta
  UX una vez cacheado.
- **Rate limits en LibreTranslate**: al ser self-hosted, controlás vos los
  límites vía `LT_REQ_LIMIT`, `LT_CHAR_LIMIT`, etc.

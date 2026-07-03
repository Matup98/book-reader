# Book Reader

Lector de libros en PDF en inglés con traducción contextual al español. Al
seleccionar una palabra o una oración, la app envía **la oración completa** al
servicio de traducción y muestra el resultado como un overlay flotante.

- App: **Flutter** (web, iOS, Android)
- PDF y selección de texto: **[pdfrx](https://pub.dev/packages/pdfrx)**
- Traducción: **[LibreTranslate](https://github.com/LibreTranslate/LibreTranslate)** self-hosted vía Docker
- Proxy de desarrollo: pequeño servidor Node en `proxy/` (necesario por CORS en Flutter web)

Todo el MVP corre en local, sin cuentas ni deploy. El deploy a producción está
documentado en `docs/DEPLOY.md`, pero no es parte del MVP.

## Requisitos

- Flutter 3.11+ (`flutter --version`)
- Docker + Docker Compose
- Node.js 18+ (para el proxy local)

## Levantar el stack local

En tres terminales:

```bash
docker compose up -d
cd proxy && npm run dev
flutter run -d chrome
```

La primera vez, LibreTranslate tarda unos minutos en descargar los modelos
`en` y `es`. Podés seguir el progreso con:

```bash
docker compose logs -f libretranslate
```

Cuando el contenedor esté sano, verificá el proxy:

```bash
curl -X POST http://localhost:8787/translate \
  -H 'Content-Type: application/json' \
  -d '{"q":"Hello, how are you?","source":"en","target":"es"}'
```

## Configuración

Copiá `.env.example` a `.env` si necesitás cambiar puertos u orígenes:

```bash
cp .env.example .env
```

La app Flutter lee `TRANSLATE_API_URL` con `--dart-define` al arrancar:

```bash
flutter run -d chrome --dart-define=TRANSLATE_API_URL=http://localhost:8787
```

Sin `--dart-define`, usa `http://localhost:8787` por defecto.

## Estructura del proyecto

```
book-reader/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── models/translation.dart
│   ├── services/
│   │   ├── text_context.dart          # expandToSentence / expandToParagraph
│   │   └── translation_service.dart   # LibreTranslateProvider
│   ├── screens/
│   │   ├── home_screen.dart           # Abrir PDF local
│   │   └── reader_screen.dart        # pdfrx + onTextSelectionChange
│   └── widgets/translation_overlay.dart
├── proxy/
│   ├── package.json
│   └── src/index.mjs                  # POST /translate → LibreTranslate
├── docker-compose.yml                 # LibreTranslate solo en/es
├── docs/DEPLOY.md                     # Guía de producción (no MVP)
├── test/text_context_test.dart
└── .env.example
```

## Tests

```bash
flutter test
```

## Roadmap

Fuera del MVP, en `docs/DEPLOY.md` está la guía para desplegar de forma gratuita:
Cloudflare Pages para la app, Cloudflare Workers para el proxy y Render (Docker
free tier) para LibreTranslate.

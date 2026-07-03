# Book Reader

Lector de libros en PDF en inglés con traducción al español. Al seleccionar una
palabra o una oración, la app la traduce y muestra el resultado como un overlay
flotante editable.

- App: **Flutter** (web, iOS, Android)
- PDF y selección de texto: **[pdfrx](https://pub.dev/packages/pdfrx)**
- Motores de traducción self-hosted vía Docker:
  - **[LibreTranslate](https://github.com/LibreTranslate/LibreTranslate)** (Argos, rápido)
  - **NLLB-200** (Meta, mejor calidad léxica; servidor propio en `nllb-server/`, compatible con Apple Silicon)
- Proxy de desarrollo: pequeño servidor Node en `proxy/` (necesario por CORS en Flutter web)

Todo el MVP corre en local, sin cuentas ni deploy. El deploy a producción está
documentado en `docs/DEPLOY.md`, pero no es parte del MVP.

## Requisitos

- Flutter 3.11+ (`flutter --version`)
- Docker + Docker Compose
- Node.js 18+ (para el proxy local)
- Aproximadamente **4 GB de RAM** libres si querés correr LibreTranslate y NLLB
  al mismo tiempo (~1 GB para LibreTranslate, ~2 GB para NLLB 600M INT8).

## Levantar el stack local

En tres terminales:

```bash
docker compose up -d
cd proxy && npm run dev
flutter run -d chrome
```

La primera vez, cada contenedor tarda unos minutos en descargar sus modelos:
LibreTranslate baja los packs `en` y `es`, y NLLB baja el modelo distilled
600M INT8 (~600 MB) la primera vez. En **Mac con chip M1/M2/M3** el contenedor
NLLB se construye localmente para `arm64` (la imagen upstream solo soportaba
`amd64`). Podés seguir el progreso con:

```bash
docker compose logs -f libretranslate
docker compose logs -f nllb
```

Cuando los contenedores estén sanos, verificá el proxy:

```bash
# LibreTranslate (default)
curl -X POST http://localhost:8787/translate \
  -H 'Content-Type: application/json' \
  -d '{"q":"Hello, how are you?","source":"en","target":"es"}'

# NLLB
curl -X POST http://localhost:8787/translate \
  -H 'Content-Type: application/json' \
  -d '{"q":"Hello, how are you?","source":"en","target":"es","engine":"nllb"}'
```

## Modos y motores de traducción

Desde el AppBar del lector podés elegir cómo traducir.

**Modo** (cómo se usa la selección):

| Modo | Qué se envía | Qué se muestra |
|------|--------------|----------------|
| **Con contexto** (default) | Oración completa alrededor de la selección | Solo la traducción alineada con la selección |
| **Solo selección** | Únicamente el texto resaltado | La traducción literal completa del texto seleccionado |

Usá **Con contexto** para que el modelo entienda palabras ambiguas
(`bank` → `orilla` en un párrafo sobre ríos). Usá **Solo selección** cuando
quieras la traducción literal exacta, sin sesgo del contexto.

**Motor** (backend que traduce):

| Motor | Calidad | Velocidad | RAM |
|-------|---------|-----------|-----|
| **LibreTranslate** | Correcta para uso general | Rápido (CPU) | ~1 GB |
| **NLLB** | Mejor vocabulario literario | Más lento (CPU) | ~2 GB |

Ambas preferencias se guardan con `shared_preferences`.

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
│   ├── models/translation.dart           # TranslationMode + TranslationEngine
│   ├── services/
│   │   ├── text_context.dart             # expandToSentence, alignSelectionInTranslation
│   │   ├── context_translator.dart       # translateSelection (modos)
│   │   └── translation_service.dart      # ProxyTranslationProvider
│   ├── screens/
│   │   ├── home_screen.dart              # Abrir PDF local
│   │   └── reader_screen.dart            # pdfrx + selectores modo/motor
│   └── widgets/translation_overlay.dart
├── proxy/
│   ├── package.json
│   └── src/index.mjs                     # POST /translate → LibreTranslate | NLLB
├── docker-compose.yml                    # LibreTranslate + NLLB
├── docs/DEPLOY.md                        # Guía de producción (no MVP)
├── test/
│   ├── text_context_test.dart
│   └── context_translator_test.dart
└── .env.example
```

## Tests

```bash
flutter test
```

## Roadmap

- **DeepL API** como motor cloud adicional. La arquitectura ya soporta agregar
  motores nuevos: sumar `deepl` al enum `TranslationEngine`, enrutar en el proxy
  hacia `https://api-free.deepl.com/v2/translate` con `DEEPL_API_KEY`, y ofrecerlo
  en el selector. No requiere cambios en la app más allá del enum y una entrada
  en el dropdown.
- Deploy: `docs/DEPLOY.md` describe cómo publicar la app en Cloudflare Pages,
  el proxy en Cloudflare Workers y LibreTranslate en Render (Docker free tier).
  NLLB necesita más RAM: en producción conviene un plan pago o cambiar por DeepL.

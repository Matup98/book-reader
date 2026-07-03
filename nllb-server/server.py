"""
Minimal NLLB-200 translation API compatible with the book-reader proxy.

Exposes the same endpoints as winstxnhdw/nllb-api:
  GET /api/v4/health
  GET /api/v4/translator?text=...&source=eng_Latn&target=spa_Latn

Uses CTranslate2 INT8 on CPU — works on Apple Silicon (arm64) via Docker.
"""

from __future__ import annotations

import logging
import os
import threading
from contextlib import asynccontextmanager

import ctranslate2
import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import PlainTextResponse
from huggingface_hub import snapshot_download
from transformers import AutoTokenizer

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("nllb-server")

CT2_MODEL_ID = os.getenv(
    "NLLB_CT2_MODEL", "JustFrederik/nllb-200-distilled-600M-ct2-int8"
)
TOKENIZER_MODEL_ID = os.getenv(
    "NLLB_TOKENIZER_MODEL", "facebook/nllb-200-distilled-600M"
)
OMP_THREADS = int(os.getenv("OMP_NUM_THREADS", "4"))

_lock = threading.Lock()
_translator: ctranslate2.Translator | None = None
_tokenizer: AutoTokenizer | None = None


def _load_models() -> None:
    global _translator, _tokenizer
    if _translator is not None and _tokenizer is not None:
        return

    with _lock:
        if _translator is not None and _tokenizer is not None:
            return

        log.info("Downloading CT2 model %s (first run may take a few minutes)…", CT2_MODEL_ID)
        model_path = snapshot_download(CT2_MODEL_ID)
        log.info("Downloading tokenizer %s…", TOKENIZER_MODEL_ID)
        tokenizer_path = snapshot_download(TOKENIZER_MODEL_ID)

        log.info("Loading CTranslate2 translator (OMP_NUM_THREADS=%d)…", OMP_THREADS)
        _translator = ctranslate2.Translator(
            model_path,
            device="cpu",
            inter_threads=1,
            intra_threads=OMP_THREADS,
        )
        _tokenizer = AutoTokenizer.from_pretrained(tokenizer_path)
        log.info("NLLB server ready.")


def _translate(text: str, source: str, target: str) -> str:
    _load_models()
    assert _translator is not None and _tokenizer is not None

    _tokenizer.src_lang = source
    source_tokens = _tokenizer.convert_ids_to_tokens(_tokenizer.encode(text))
    target_prefix = [target]

    results = _translator.translate_batch(
        [source_tokens],
        target_prefix=[target_prefix],
        max_batch_size=1,
        beam_size=4,
    )
    hypothesis = results[0].hypotheses[0]
    # Drop the leading target-language token (e.g. spa_Latn) from the output.
    if hypothesis and hypothesis[0] == target:
        hypothesis = hypothesis[1:]
    return _tokenizer.decode(
        _tokenizer.convert_tokens_to_ids(hypothesis),
        skip_special_tokens=True,
    )


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Warm up in background so /health responds immediately.
    threading.Thread(target=_load_models, daemon=True).start()
    yield


app = FastAPI(title="NLLB Server", lifespan=lifespan)


@app.get("/api/v4/health")
def health() -> dict:
    ready = _translator is not None
    return {"status": "ok" if ready else "loading", "ready": ready}


@app.get("/api/v4/translator", response_class=PlainTextResponse)
def translator(
    text: str = Query(..., min_length=1),
    source: str = Query(...),
    target: str = Query(...),
) -> str:
    if _translator is None:
        raise HTTPException(
            status_code=503,
            detail="Model is still loading; retry in a few minutes.",
        )
    try:
        return _translate(text, source, target)
    except Exception as exc:
        log.exception("Translation failed")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


if __name__ == "__main__":
    port = int(os.getenv("SERVER_PORT", "7860"))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")

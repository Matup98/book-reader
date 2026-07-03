# Multi-arch image (arm64 + amd64) for Apple Silicon and x86.
FROM python:3.11-slim-bookworm

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py .

ENV SERVER_PORT=7860
ENV OMP_NUM_THREADS=4
ENV HF_HOME=/data/huggingface

VOLUME ["/data/huggingface"]

EXPOSE 7860

CMD ["python", "server.py"]

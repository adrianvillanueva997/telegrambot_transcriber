# Builder stage
FROM python:3.12.13-slim-bookworm AS builder

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  build-essential \
  && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir uv

# Install dependencies first (cached unless pyproject.toml changes)
COPY pyproject.toml .
RUN uv sync --no-dev

# Copy source and install the package
COPY . .
RUN uv sync --no-dev

# Final stage
FROM python:3.12.13-slim-bookworm

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ffmpeg \
  curl \
  && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir uv \
  && useradd -m -r app \
  && chown -R app:app /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/src /app/src
COPY pyproject.toml /app/

USER app

EXPOSE 2112

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:2112/metrics || exit 1

ENV VIRTUAL_ENV=/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

CMD ["python", "-m", "transcriber_telegrambot"]

# Build stage
FROM python:3.12.8-slim-bookworm AS builder

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  build-essential \
  && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir uv

COPY . .

# Build wheel in dist directory
RUN uv build

# Final stage
FROM python:3.12.8-slim-bookworm

WORKDIR /app

# Install runtime dependencies
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ffmpeg \
  flac \
  && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir --upgrade pip \
  && pip install --no-cache-dir uv \
  && useradd -m -r app \
  && chown -R app:app /app

# Copy and install wheel from dist
COPY --from=builder /app/dist/*.whl /tmp/
RUN uv venv && uv pip install /tmp/*.whl && rm /tmp/*.whl

USER app

EXPOSE 2112

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:2112/metrics || exit 1

# Activate the virtual environment
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV PYTHONPATH="/app:$PYTHONPATH"

CMD ["/app/.venv/bin/python", "-m", "transcriber_telegrambot"]

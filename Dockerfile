# syntax=docker/dockerfile:1

# -----------------------------
# FastAPI backend + FFmpeg
# -----------------------------
FROM python:3.12-slim AS api

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HISTORY_FILE=/data/local_history.json

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 appuser

COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY moviebox_api ./moviebox_api
COPY moviebox_api_server.py ./moviebox_api_server.py
RUN mkdir -p /data \
    && chown -R appuser:appuser /app /data

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4)" || exit 1

CMD ["uvicorn", "moviebox_api_server:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]


# -----------------------------
# Next.js dependencies/build
# -----------------------------
FROM node:22-bookworm-slim AS web-deps
WORKDIR /app
COPY dashboard/package.json dashboard/package-lock.json ./
RUN npm ci

FROM web-deps AS web-build
ARG NEXT_PUBLIC_API_BASE_URL=/api
ARG API_INTERNAL_URL=http://api:8000
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL} \
    API_INTERNAL_URL=${API_INTERNAL_URL} \
    NEXT_TELEMETRY_DISABLED=1
COPY dashboard/ ./
RUN mkdir -p public && npm run build

# -----------------------------
# Minimal Next.js runtime
# -----------------------------
FROM node:22-bookworm-slim AS web
ENV NODE_ENV=production \
    HOSTNAME=0.0.0.0 \
    PORT=3000 \
    NEXT_TELEMETRY_DISABLED=1
WORKDIR /app
COPY --from=web-build /app/.next/standalone ./
COPY --from=web-build /app/.next/static ./.next/static
COPY --from=web-build /app/public ./public
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]

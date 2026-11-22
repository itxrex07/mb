# syntax=docker/dockerfile:1

FROM python:3.12-slim AS api

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HISTORY_FILE=/data/local_history.json

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg ca-certificates libcap2-bin \
    && setcap 'cap_net_bind_service=+ep' "$(readlink -f "$(command -v python3)")" \
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
EXPOSE 300

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:300/health', timeout=4)" || exit 1

CMD ["uvicorn", "moviebox_api_server:app", "--host", "0.0.0.0", "--port", "300", "--proxy-headers"]

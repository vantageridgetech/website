# syntax=docker/dockerfile:1

FROM python:3.11-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --upgrade pip==26.0.1 wheel==0.46.3 setuptools

COPY requirements.txt /app/requirements.txt
RUN python -m pip install --prefix=/install -r /app/requirements.txt


FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    TMPDIR=/tmp \
    GUNICORN_CMD_ARGS="--worker-tmp-dir /tmp" \
    PYTHONPYCACHEPREFIX=/tmp/pycache \
    APP_ENV=container

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /install /usr/local

COPY app /app/app
COPY wsgi.py /app/wsgi.py

RUN useradd --create-home --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appuser /app

RUN cat > /usr/local/bin/entrypoint.sh <<'EOF' \
  && chmod +x /usr/local/bin/entrypoint.sh
#!/bin/sh
set -eu

mkdir -p /tmp /var/tmp /usr/tmp /tmp/pycache
chmod 1777 /tmp /var/tmp /usr/tmp || true
chmod 777 /tmp/pycache || true

exec gosu appuser "$@"
EOF

EXPOSE 5000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["gunicorn", "-b", "0.0.0.0:5000", "--worker-tmp-dir", "/tmp", "wsgi:app"]

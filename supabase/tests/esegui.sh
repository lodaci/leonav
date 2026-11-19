#!/usr/bin/env bash
# Prova schema, seed e logica su un Postgres usa e getta (serve Docker).
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
docker rm -f leonav-pgtest >/dev/null 2>&1 || true
docker run -d --name leonav-pgtest -e POSTGRES_PASSWORD=x -v "$DIR":/s postgres:16 >/dev/null
until docker exec leonav-pgtest pg_isready -U postgres -q 2>/dev/null; do sleep 1; done
sleep 2
docker exec leonav-pgtest psql -q -U postgres -v ON_ERROR_STOP=1 \
  -f /s/tests/stub_supabase.sql -f /s/migrations/20261119000000_schema.sql -f /s/seed.sql
docker exec leonav-pgtest psql -q -U postgres -v ON_ERROR_STOP=1 -f /s/tests/test_logica.sql
docker rm -f leonav-pgtest >/dev/null

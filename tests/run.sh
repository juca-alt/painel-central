#!/usr/bin/env bash
# Suíte do Painel Central: sintaxe do app + unit da Adega + E2E (Chromium) + migration num Postgres local.
set -e; cd "$(dirname "$0")/.."
echo "== sintaxe (node --check dos scripts inline)"; node tests/syntax.mjs
echo "== unit"; node tests/adega.unit.mjs
echo "== e2e"; node tests/adega.e2e.mjs
echo "== sql"; bash tests/sql_idempotencia.sh
echo "TUDO VERDE"

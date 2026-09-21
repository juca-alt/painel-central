#!/usr/bin/env bash
# Prova a migration painel_adega.sql num Postgres local descartável:
#  - roda 2× → sem erro e mesmo resultado (idempotente)
#  - seed dos 2 vinhos do Notion aparece 1× (não duplica)
#  - anon não lê; RLS ligado; policy presente
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PGBIN=$(ls -d /usr/lib/postgresql/*/bin | head -1)
D=$(mktemp -d); PORT=54329
cleanup(){ "$PGBIN/pg_ctl" -D "$D" stop -m immediate >/dev/null 2>&1 || true; rm -rf "$D"; }
trap cleanup EXIT
run_as(){ if [ "$(id -u)" = 0 ]; then chown -R postgres "$D"; su postgres -c "$*"; else eval "$*"; fi; }
run_as "$PGBIN/initdb -D $D -A trust -U postgres >/dev/null"
run_as "$PGBIN/pg_ctl -D $D -o '-p $PORT -k $D -c listen_addresses=' -l $D/log start >/dev/null"
PSQL="$PGBIN/psql -v ON_ERROR_STOP=1 -q -h $D -p $PORT -U postgres -d postgres"
# --- stub do ambiente Supabase: roles, schema auth, auth.uid(), auth.users ---
$PSQL <<'SQL'
create role anon nologin; create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
insert into auth.users(id,email) values ('11111111-1111-1111-1111-111111111111','juca@segurocomjuca.com');
SQL
$PSQL -f "$ROOT/sql/painel_adega.sql"
$PSQL -f "$ROOT/sql/painel_adega.sql"   # 2ª rodada: tem que passar limpo
n=$($PSQL -tAc "select count(*) from public.painel_adega")
[ "$n" = "2" ] || { echo "FALHA: esperado 2 vinhos após 2 rodadas, veio $n"; exit 1; }
v=$($PSQL -tAc "select string_agg(vinho, ' | ' order by vinho) from public.painel_adega")
echo "$v" | grep -q "Cousiño-Macul Don Luis" || { echo "FALHA: Cousiño-Macul ausente"; exit 1; }
echo "$v" | grep -q "Casas del Toqui" || { echo "FALHA: Casas del Toqui ausente"; exit 1; }
rls=$($PSQL -tAc "select relrowsecurity from pg_class where oid='public.painel_adega'::regclass")
[ "$rls" = "t" ] || { echo "FALHA: RLS desligado"; exit 1; }
pol=$($PSQL -tAc "select count(*) from pg_policies where tablename='painel_adega'")
[ "$pol" = "1" ] || { echo "FALHA: esperado 1 policy, veio $pol"; exit 1; }
anon=$($PSQL -tAc "select has_table_privilege('anon','public.painel_adega','select')")
[ "$anon" = "f" ] || { echo "FALHA: anon consegue ler"; exit 1; }
# dono vê as 2 linhas; outro usuário vê 0 (RLS)
mine=$($PSQL -tAc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select count(*) from public.painel_adega")
[ "$mine" = "2" ] || { echo "FALHA: dono deveria ver 2, viu $mine"; exit 1; }
other=$($PSQL -tAc "set role authenticated; set request.jwt.claim.sub='22222222-2222-2222-2222-222222222222'; select count(*) from public.painel_adega")
[ "$other" = "0" ] || { echo "FALHA: outro usuário vê $other"; exit 1; }
# checks de domínio
if $PSQL -tAc "insert into public.painel_adega(owner,vinho,nota) values ('11111111-1111-1111-1111-111111111111','x',6)" 2>/dev/null; then echo "FALHA: nota 6 aceita"; exit 1; fi
if $PSQL -tAc "insert into public.painel_adega(owner,vinho,ocasiao) values ('11111111-1111-1111-1111-111111111111','x','Outra')" 2>/dev/null; then echo "FALHA: ocasião inválida aceita"; exit 1; fi
echo "SQL OK: migration idempotente, 2 vinhos, RLS/anon/checks corretos"

-- ============================================================================
-- PAINEL · EVENT META — Categoria manual + checklist guiado por evento da agenda
-- App: Painel Central (juca-alt/painel-central). Migration: painel_event_meta (v1)
-- Projeto Supabase: mieqsiojvfiqrhectquc (COMPARTILHADO com Pipe X + central-financeira)
-- REGRA DE OURO: só ADICIONA objetos com prefixo painel_. NÃO altera/dropa/referencia
--   nada de Pipe X nem do central-financeira.
-- Isolamento: schema public, prefixo painel_, RLS owner-isolado (auth.uid()).
--   grant só a `authenticated`, NUNCA a `anon` (repo + anon key são públicos).
-- ENUMs: text + CHECK (não CREATE TYPE) — evita ALTER TYPE irreversível.
-- Rodar: colar no SQL Editor do Supabase e Run. Idempotente.
-- QUANDO RODAR: junto com o deploy da v2.11.0 (edição de eventos + checklist).
-- ============================================================================

-- ----- UP -----

-- Função reutilizável de updated_at (idempotente; mesma do gael_saude/painel_inbox).
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

-- painel_event_meta: metadados do painel por evento do Google Calendar.
--   event_id = id da INSTÂNCIA (agenda lista com singleEvents=true), ou o
--   recurringEventId quando a categoria vale pra série toda (decisão do app:
--   categoria = série; checklist = por ocorrência).
--   cat NULL = sem override (categoria continua vindo da regex de título).
--   checklist = [{"t":"passo","done":false}, ...]
--   PK simples em event_id: app single-user; se um dia houver 2º owner no mesmo
--   projeto, migrar PK para (owner, event_id).
create table if not exists public.painel_event_meta (
  event_id    text primary key,
  owner       uuid not null default auth.uid(),
  cat         text
              check (cat in ('CAMILA','GAEL+FAMÍLIA','PIPELINE','COMERCIAL',
                             'GESTÃO MFB','LEMBRETE','ROTINA','PESSOAL')),
  checklist   jsonb not null default '[]'::jsonb,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
create index if not exists idx_painel_event_meta_owner on public.painel_event_meta(owner);
drop trigger if exists trg_painel_event_meta_updated on public.painel_event_meta;
create trigger trg_painel_event_meta_updated before update on public.painel_event_meta
  for each row execute function set_updated_at();
alter table public.painel_event_meta enable row level security;
drop policy if exists painel_event_meta_all on public.painel_event_meta;
create policy painel_event_meta_all on public.painel_event_meta
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.painel_event_meta to authenticated;

-- ----- DOWN (reversível — não rodar em prod sem querer) -----
-- drop table if exists public.painel_event_meta;

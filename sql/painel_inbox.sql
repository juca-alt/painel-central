-- ============================================================================
-- PAINEL · INBOX — Triagem & roteamento de capturas (email #inbox + Dump)
-- App: Painel Central (juca-alt/painel-central). Migration: painel_inbox (v1)
-- Projeto Supabase: mieqsiojvfiqrhectquc (COMPARTILHADO com Pipe X + central-financeira)
-- REGRA DE OURO: só ADICIONA objetos com prefixo painel_. NÃO altera/dropa/referencia
--   nada de Pipe X nem do central-financeira.
-- Isolamento: schema public, prefixo painel_, RLS owner-isolado (auth.uid()).
--   grant só a `authenticated`, NUNCA a `anon` (repo + anon key são públicos).
-- ENUMs: text + CHECK (não CREATE TYPE) — evita ALTER TYPE irreversível.
-- Rodar: colar no SQL Editor do Supabase e Run. Idempotente.
-- ============================================================================

-- ----- UP -----

-- Função reutilizável de updated_at (idempotente; mesma do gael_saude/central-financeira).
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

-- painel_inbox: ledger único de capturas triadas + roteamento.
--   Uma captura (email #inbox ou linha do Dump) só ganha linha QUANDO é triada.
--   ext_id = id da mensagem Gmail, ou hash estável da linha do Dump.
--   destino direciona onde ela aparece depois (tarefa/insight/referencia/arquivo).
create table if not exists public.painel_inbox (
  id            uuid primary key default gen_random_uuid(),
  owner         uuid not null default auth.uid(),
  fonte         text not null default 'email'
                check (fonte in ('email','dump','manual')),
  ext_id        text,                         -- gmail msg id / hash do dump (dedupe)
  titulo        text not null,
  corpo         text,
  destino       text not null
                check (destino in ('tarefa','insight','referencia','arquivo')),
  status        text not null default 'aberto'
                check (status in ('aberto','feito')),   -- usado quando destino='tarefa'
  prazo         date,
  url           text,
  nota          text,
  tags          text,
  capturado_em  timestamptz,                  -- data original do email/captura
  triado_em     timestamptz not null default now(),
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);
create index if not exists idx_painel_inbox_owner   on public.painel_inbox(owner);
create index if not exists idx_painel_inbox_destino on public.painel_inbox(destino);
-- dedupe: a mesma captura não pode ser triada duas vezes pelo mesmo dono.
create unique index if not exists uq_painel_inbox_owner_ext
  on public.painel_inbox(owner, ext_id) where ext_id is not null;
drop trigger if exists trg_painel_inbox_updated on public.painel_inbox;
create trigger trg_painel_inbox_updated before update on public.painel_inbox
  for each row execute function set_updated_at();
alter table public.painel_inbox enable row level security;
drop policy if exists painel_inbox_all on public.painel_inbox;
create policy painel_inbox_all on public.painel_inbox
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.painel_inbox to authenticated;

-- ----- DOWN (reversível — não rodar em prod sem querer) -----
-- drop table if exists public.painel_inbox;

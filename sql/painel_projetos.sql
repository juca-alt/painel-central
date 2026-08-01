-- ============================================================================
-- PAINEL · PROJETOS META — status, descrição e link por projeto (lista do Google Tasks)
-- App: Painel Central (juca-alt/painel-central). Migration: painel_projetos (v1)
-- Projeto Supabase: mieqsiojvfiqrhectquc (COMPARTILHADO com Pipe X + central-financeira)
-- REGRA DE OURO: só ADICIONA objetos com prefixo painel_. NÃO altera/dropa/referencia
--   nada de Pipe X nem do central-financeira.
-- Isolamento: schema public, prefixo painel_, RLS owner-isolado (auth.uid()).
--   grant só a `authenticated`, NUNCA a `anon` (repo + anon key são públicos).
-- ENUMs: text + CHECK (não CREATE TYPE) — evita ALTER TYPE irreversível.
-- Rodar: colar no SQL Editor do Supabase e Run. Idempotente.
-- QUANDO RODAR: junto com o deploy da v2.17.0 (metadata de projeto).
-- ============================================================================

-- ----- UP -----

-- Função reutilizável de updated_at (idempotente; mesma do painel_event_meta/gael_saude).
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

-- painel_projetos: a CAMADA DE METADADOS do projeto. A fonte da verdade do
--   projeto em si (nome + tarefas) continua sendo a LISTA do Google Tasks —
--   aqui só mora o que o Google Tasks não tem.
--   list_id  = id da tasklist do Google (chave de ligação).
--   status   = ativo | pausado | concluido (sem acento p/ evitar encoding).
--   descricao= o que é o projeto / objetivo.
--   link     = repo, chat do Claude, doc — 1 link principal.
--   Sem linha na tabela = projeto "ativo, sem descrição" (default do app).
--   PK simples em list_id: app single-user; se um dia houver 2º owner no mesmo
--   projeto, migrar PK para (owner, list_id).
create table if not exists public.painel_projetos (
  list_id     text primary key,
  owner       uuid not null default auth.uid(),
  status      text not null default 'ativo'
              check (status in ('ativo','pausado','concluido')),
  descricao   text,
  link        text,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
create index if not exists idx_painel_projetos_owner on public.painel_projetos(owner);
drop trigger if exists trg_painel_projetos_updated on public.painel_projetos;
create trigger trg_painel_projetos_updated before update on public.painel_projetos
  for each row execute function set_updated_at();
alter table public.painel_projetos enable row level security;
drop policy if exists painel_projetos_all on public.painel_projetos;
create policy painel_projetos_all on public.painel_projetos
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.painel_projetos to authenticated;
-- Defesa em profundidade: o Supabase concede privilégios a `anon` por DEFAULT
-- PRIVILEGES em TODA tabela nova do schema public — ou seja, o grant acima não
-- basta pra deixar `anon` de fora. A RLS já barra (owner=auth.uid() é NULL sem
-- login), mas aqui a intenção fica explícita: `anon` não tem NADA nesta tabela.
-- Verificado 01/08: antes disso o anon lia `[]` (200); depois passa a 401/42501.
revoke all on public.painel_projetos from anon;

-- ----- DOWN (reversível — não rodar em prod sem querer) -----
-- drop table if exists public.painel_projetos;

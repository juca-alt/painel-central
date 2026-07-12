-- ============================================================================
-- PAINEL · CONTATOS — Base de contatos (WhatsApp Fase 2)
-- App: Painel Central (juca-alt/painel-central). Migration: painel_contatos (v1)
-- Projeto Supabase: mieqsiojvfiqrhectquc (COMPARTILHADO com Pipe X + central-financeira)
-- REGRA DE OURO: só ADICIONA a tabela public.painel_contatos. NÃO altera/dropa/
--   referencia nada de Pipe X, central-financeira nem gael_*.
-- Isolamento: schema public, prefixo painel_, RLS owner-isolado (auth.uid()).
--   Telefone/email = PII → grant só a `authenticated`, NUNCA a `anon`.
-- ENUMs: text + CHECK (não CREATE TYPE) — evita ALTER TYPE irreversível e colisão global.
-- Fundação da integração WhatsApp: guarda os números que as próximas fases
--   (envio real via wa-send, disparos, atendimento) vão consumir.
-- Rodar: colar no SQL Editor do Supabase e Run. Idempotente.
-- ============================================================================

-- ----- UP -----

-- Função reutilizável de updated_at (idempotente; mesma do central-financeira/gael).
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create table if not exists public.painel_contatos (
  id         uuid primary key default gen_random_uuid(),
  owner      uuid not null default auth.uid(),
  nome       text not null,
  telefone   text,
  categoria  text not null default 'outro'
             check (categoria in ('cliente','lead','fornecedor','equipe','pessoal','outro')),
  relacao    text,
  email      text,
  notas      text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_painel_contatos_owner on public.painel_contatos(owner);
create index if not exists idx_painel_contatos_cat   on public.painel_contatos(categoria);
drop trigger if exists trg_painel_contatos_updated on public.painel_contatos;
create trigger trg_painel_contatos_updated before update on public.painel_contatos
  for each row execute function set_updated_at();
alter table public.painel_contatos enable row level security;
drop policy if exists painel_contatos_all on public.painel_contatos;
create policy painel_contatos_all on public.painel_contatos
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.painel_contatos to authenticated;

-- ----- DOWN (descomentar p/ reverter) -----
-- drop table if exists public.painel_contatos;
-- -- NÃO dropar set_updated_at(): é compartilhada com central-financeira/gael.
-- ============================================================================
-- FIM DA MIGRATION painel_contatos v1
-- ============================================================================

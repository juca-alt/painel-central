-- ============================================================================
-- PAINEL 3.0 · DIMENSÕES → PROJETOS → TAREFAS — Supabase vira a fonte da verdade
-- App: Painel Central (juca-alt/painel-central). Migration: painel_dimensoes_tarefas (v1)
-- Projeto Supabase: mieqsiojvfiqrhectquc (COMPARTILHADO com Pipe X + central-financeira)
-- REGRA DE OURO: só ADICIONA/EVOLUI objetos com prefixo painel_. NÃO altera/dropa/
--   referencia nada de Pipe X nem do central-financeira.
-- Isolamento: schema public, prefixo painel_, RLS owner-isolado (auth.uid()).
--   grant só a `authenticated`, NUNCA a `anon` (repo + anon key são públicos).
-- ENUMs: text + CHECK (não CREATE TYPE) — evita ALTER TYPE irreversível.
-- Rodar: SQL Editor ou MCP apply_migration. Idempotente (DO block guardado na PK).
-- QUANDO RODAR: junto com o deploy da v2.19.0 (F1 da Melhoria 3.0).
-- ============================================================================

-- ----- UP -----

-- Função reutilizável de updated_at (idempotente; mesma do painel_projetos/gael_saude).
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

-- ---------------------------------------------------------------------------
-- 1) painel_dimensoes — as ÁREAS DA VIDA (nível acima de projetos).
--    CRUD 100% pela UI (nome, cor, ícone, ordem). Seed pela UI, nunca por SQL
--    (o SQL Editor roda sem auth.uid() → owner ficaria NULL).
--    cor   = css color ('#639922' ou 'var(--c-pessoal)').
--    icone = classe Tabler ('ti-briefcase').
--    posicao = ordenação fracionária (inserir entre A e B = média; sem renumeração).
-- ---------------------------------------------------------------------------
create table if not exists public.painel_dimensoes (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null default auth.uid(),
  nome        text not null,
  cor         text,
  icone       text,
  posicao     double precision not null default 0,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);
create index if not exists idx_painel_dimensoes_owner on public.painel_dimensoes(owner);
drop trigger if exists trg_painel_dimensoes_updated on public.painel_dimensoes;
create trigger trg_painel_dimensoes_updated before update on public.painel_dimensoes
  for each row execute function set_updated_at();
alter table public.painel_dimensoes enable row level security;
drop policy if exists painel_dimensoes_all on public.painel_dimensoes;
create policy painel_dimensoes_all on public.painel_dimensoes
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.painel_dimensoes to authenticated;
-- Defesa em profundidade (lição 01/08): DEFAULT PRIVILEGES dá grants a `anon`
-- em toda tabela nova do public — revogar explícito.
revoke all on public.painel_dimensoes from anon;

-- ---------------------------------------------------------------------------
-- 2) painel_projetos — EVOLUÇÃO v3. Na 3.0 o projeto NASCE aqui (não mais na
--    lista do Google Tasks). Mudanças:
--    · nova PK `id uuid` (a antiga PK list_id vira VÍNCULO GOOGLE OPCIONAL);
--    · list_id nullable + unique parcial (owner, list_id) — idempotência da
--      importação 1x do Google Tasks;
--    · dimensao_id → painel_dimensoes (on delete set null = projeto vira
--      "Sem dimensão", nunca some);
--    · posicao fracionária.
--    O MCP mcp-painel segue lendo por list_id (coluna permanece); projetos
--    criados na 3.0 sem list_id ficam fora do painel_atualizar_projeto até o
--    ajuste da function (F6).
-- ---------------------------------------------------------------------------
alter table public.painel_projetos add column if not exists id uuid not null default gen_random_uuid();
alter table public.painel_projetos add column if not exists dimensao_id uuid references public.painel_dimensoes(id) on delete set null;
alter table public.painel_projetos add column if not exists posicao double precision not null default 0;

-- Promove a PK list_id → id (guardado: só roda se a PK atual ainda for list_id).
do $$ begin
  if exists (select 1 from pg_constraint
             where conrelid='public.painel_projetos'::regclass and contype='p'
               and pg_get_constraintdef(oid) like '%list_id%') then
    alter table public.painel_projetos drop constraint painel_projetos_pkey;
    alter table public.painel_projetos add primary key (id);
    alter table public.painel_projetos alter column list_id drop not null;
  end if;
end $$;

create unique index if not exists uq_painel_projetos_owner_list
  on public.painel_projetos(owner, list_id) where list_id is not null;
create index if not exists idx_painel_projetos_dim on public.painel_projetos(dimensao_id);

-- ---------------------------------------------------------------------------
-- 3) painel_tarefas — a tarefa NASCE aqui.
--    status  = aberta | feita | nao_feita (✅/❌ NATIVOS — sem carimbo no título).
--    origem  = painel | google_import | inbox (de onde a tarefa veio).
--    gtask_id/gtask_list_id = espelho OPCIONAL no Google Tasks.
--    gcal_event_id = evento OPCIONAL criado na Agenda a partir da tarefa.
--    unique parcial (owner, gtask_id) = idempotência da importação.
--    on delete cascade: apagar projeto apaga as tarefas (UI confirma c/ contagem).
-- ---------------------------------------------------------------------------
create table if not exists public.painel_tarefas (
  id            uuid primary key default gen_random_uuid(),
  owner         uuid not null default auth.uid(),
  projeto_id    uuid not null references public.painel_projetos(id) on delete cascade,
  titulo        text not null,
  nota          text,
  status        text not null default 'aberta'
                check (status in ('aberta','feita','nao_feita')),
  prazo         date,
  concluida_em  timestamptz,
  posicao       double precision not null default 0,
  origem        text not null default 'painel'
                check (origem in ('painel','google_import','inbox')),
  gtask_id      text,
  gtask_list_id text,
  gcal_event_id text,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);
create index if not exists idx_painel_tarefas_owner   on public.painel_tarefas(owner);
create index if not exists idx_painel_tarefas_projeto on public.painel_tarefas(projeto_id);
create unique index if not exists uq_painel_tarefas_owner_gtask
  on public.painel_tarefas(owner, gtask_id) where gtask_id is not null;
drop trigger if exists trg_painel_tarefas_updated on public.painel_tarefas;
create trigger trg_painel_tarefas_updated before update on public.painel_tarefas
  for each row execute function set_updated_at();
alter table public.painel_tarefas enable row level security;
drop policy if exists painel_tarefas_all on public.painel_tarefas;
create policy painel_tarefas_all on public.painel_tarefas
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.painel_tarefas to authenticated;
revoke all on public.painel_tarefas from anon;

-- ----- DOWN (reversível — não rodar em prod sem querer) -----
-- drop table if exists public.painel_tarefas;
-- alter table public.painel_projetos drop column if exists dimensao_id;
-- alter table public.painel_projetos drop column if exists posicao;
-- (PK: recriar em list_id exigiria list_id not null — só faz sentido com a tabela vazia)
-- drop table if exists public.painel_dimensoes;

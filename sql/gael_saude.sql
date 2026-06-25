-- ============================================================================
-- GAEL · SAÚDE — Fundação de dados (módulo de saúde infantil)
-- App: Painel Central (juca-alt/painel-central). Migration: gael_saude (v1)
-- Projeto Supabase: mieqsiojvfiqrhectquc (COMPARTILHADO com Pipe X + central-financeira)
-- REGRA DE OURO: só ADICIONA objetos com prefixo gael_. NÃO altera/dropa/referencia
--   nada de Pipe X nem do central-financeira.
-- Isolamento: schema public, prefixo gael_, RLS owner-isolado (auth.uid()).
--   Dado de SAÚDE DE CRIANÇA → grant só a `authenticated`, NUNCA a `anon`.
-- ENUMs: text + CHECK (não CREATE TYPE) — evita ALTER TYPE irreversível e colisão global.
-- Rodar: colar no SQL Editor do Supabase e Run. Idempotente.
-- ============================================================================

-- ----- UP -----

-- Função reutilizável de updated_at (idempotente; mesma do central-financeira).
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

-- 1) gael_consultas
create table if not exists public.gael_consultas (
  id               uuid primary key default gen_random_uuid(),
  owner            uuid not null default auth.uid(),
  data             date not null,
  local            text,
  profissional     text,
  especialidade    text,
  motivo           text,
  resumo_hipoteses text,
  resumo_condutas  text,
  proximo_retorno  timestamptz,
  anexo_receita    text,
  obs              text,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);
create index if not exists idx_gael_consultas_owner on public.gael_consultas(owner);
create index if not exists idx_gael_consultas_data  on public.gael_consultas(data desc);
drop trigger if exists trg_gael_consultas_updated on public.gael_consultas;
create trigger trg_gael_consultas_updated before update on public.gael_consultas
  for each row execute function set_updated_at();
alter table public.gael_consultas enable row level security;
drop policy if exists gael_consultas_all on public.gael_consultas;
create policy gael_consultas_all on public.gael_consultas
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.gael_consultas to authenticated;

-- 2) gael_diagnosticos
create table if not exists public.gael_diagnosticos (
  id              uuid primary key default gen_random_uuid(),
  owner           uuid not null default auth.uid(),
  condicao        text not null,
  status          text not null default 'ativo'
                  check (status in ('ativo','controlado','descontrolado','em_investigacao','resolvido')),
  identificado_em date,
  profissional    text,
  peso_kg         numeric(5,2),
  altura_cm       numeric(5,2),
  consulta_id     uuid references public.gael_consultas(id) on delete set null,
  notas           text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
create index if not exists idx_gael_diag_owner    on public.gael_diagnosticos(owner);
create index if not exists idx_gael_diag_consulta on public.gael_diagnosticos(consulta_id);
drop trigger if exists trg_gael_diagnosticos_updated on public.gael_diagnosticos;
create trigger trg_gael_diagnosticos_updated before update on public.gael_diagnosticos
  for each row execute function set_updated_at();
alter table public.gael_diagnosticos enable row level security;
drop policy if exists gael_diagnosticos_all on public.gael_diagnosticos;
create policy gael_diagnosticos_all on public.gael_diagnosticos
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.gael_diagnosticos to authenticated;

-- 3) gael_medicamentos  (tipo e status são EIXOS ORTOGONAIS — não fundir)
create table if not exists public.gael_medicamentos (
  id              uuid primary key default gen_random_uuid(),
  owner           uuid not null default auth.uid(),
  nome            text not null,
  principio_ativo text,
  concentracao    text,
  trata           text,
  tipo            text not null default 'rotina'
                  check (tipo in ('rotina','crise','condicional')),
  posologia       text,
  via             text,
  status          text not null default 'em_uso'
                  check (status in ('em_uso','sos','suspenso')),
  controlado      boolean not null default false,
  prescrito_por   text,
  prescrito_em    date,
  consulta_id     uuid references public.gael_consultas(id) on delete set null,
  obs             text,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
create index if not exists idx_gael_med_owner    on public.gael_medicamentos(owner);
create index if not exists idx_gael_med_status   on public.gael_medicamentos(status);
create index if not exists idx_gael_med_consulta on public.gael_medicamentos(consulta_id);
drop trigger if exists trg_gael_medicamentos_updated on public.gael_medicamentos;
create trigger trg_gael_medicamentos_updated before update on public.gael_medicamentos
  for each row execute function set_updated_at();
alter table public.gael_medicamentos enable row level security;
drop policy if exists gael_medicamentos_all on public.gael_medicamentos;
create policy gael_medicamentos_all on public.gael_medicamentos
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.gael_medicamentos to authenticated;

-- 4) gael_exames
create table if not exists public.gael_exames (
  id               uuid primary key default gen_random_uuid(),
  owner            uuid not null default auth.uid(),
  nome             text not null,
  solicitado_em    date,
  realizado_em     date,
  solicitante      text,
  status           text not null default 'solicitado'
                   check (status in ('sugerido','solicitado','agendado','feito')),
  resultado_resumo text,
  preparo          text,
  anexo            text,
  consulta_id      uuid references public.gael_consultas(id) on delete set null,
  obs              text,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);
create index if not exists idx_gael_exames_owner    on public.gael_exames(owner);
create index if not exists idx_gael_exames_status   on public.gael_exames(status);
create index if not exists idx_gael_exames_consulta on public.gael_exames(consulta_id);
drop trigger if exists trg_gael_exames_updated on public.gael_exames;
create trigger trg_gael_exames_updated before update on public.gael_exames
  for each row execute function set_updated_at();
alter table public.gael_exames enable row level security;
drop policy if exists gael_exames_all on public.gael_exames;
create policy gael_exames_all on public.gael_exames
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.gael_exames to authenticated;

-- 5) gael_profissionais  (nome NULLABLE: vários só têm especialidade)
create table if not exists public.gael_profissionais (
  id                uuid primary key default gen_random_uuid(),
  owner             uuid not null default auth.uid(),
  nome              text,
  especialidade     text,
  status            text not null default 'a_procurar'
                    check (status in ('atual','sugerido','a_procurar')),
  registro_conselho text,
  contato           text,
  ultima_consulta   date,
  proxima           timestamptz,
  notas             text,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);
create index if not exists idx_gael_prof_owner  on public.gael_profissionais(owner);
create index if not exists idx_gael_prof_status on public.gael_profissionais(status);
drop trigger if exists trg_gael_profissionais_updated on public.gael_profissionais;
create trigger trg_gael_profissionais_updated before update on public.gael_profissionais
  for each row execute function set_updated_at();
alter table public.gael_profissionais enable row level security;
drop policy if exists gael_profissionais_all on public.gael_profissionais;
create policy gael_profissionais_all on public.gael_profissionais
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.gael_profissionais to authenticated;

-- 6) gael_investigacoes  (status inclui 'em_investigacao' — alinhado com diagnosticos)
create table if not exists public.gael_investigacoes (
  id                uuid primary key default gen_random_uuid(),
  owner             uuid not null default auth.uid(),
  tema              text not null,
  origem            text not null default 'consulta'
                    check (origem in ('consulta','percepcao_pai')),
  status            text not null default 'aberto'
                    check (status in ('aberto','em_discussao','em_investigacao','resolvido')),
  profissional_alvo text,
  consulta_id       uuid references public.gael_consultas(id) on delete set null,
  notas             text,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now()
);
create index if not exists idx_gael_inv_owner    on public.gael_investigacoes(owner);
create index if not exists idx_gael_inv_status   on public.gael_investigacoes(status);
create index if not exists idx_gael_inv_consulta on public.gael_investigacoes(consulta_id);
drop trigger if exists trg_gael_investigacoes_updated on public.gael_investigacoes;
create trigger trg_gael_investigacoes_updated before update on public.gael_investigacoes
  for each row execute function set_updated_at();
alter table public.gael_investigacoes enable row level security;
drop policy if exists gael_investigacoes_all on public.gael_investigacoes;
create policy gael_investigacoes_all on public.gael_investigacoes
  for all using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.gael_investigacoes to authenticated;

-- ----- DOWN (descomentar p/ reverter; ordem inversa por causa das FKs) -----
-- drop table if exists public.gael_investigacoes;
-- drop table if exists public.gael_profissionais;
-- drop table if exists public.gael_exames;
-- drop table if exists public.gael_medicamentos;
-- drop table if exists public.gael_diagnosticos;
-- drop table if exists public.gael_consultas;
-- -- NÃO dropar set_updated_at(): é compartilhada com o central-financeira.
-- ============================================================================
-- FIM DA MIGRATION gael_saude v1
-- ============================================================================

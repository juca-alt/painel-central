-- ============================================================
-- Painel Central · módulo Casa › Funcionários
-- Migration: painel_casa  (v1)
-- Projeto Supabase: REUSA o do central-financeira.
-- Isolamento: tabela com prefixo `painel_` no schema public.
--   (o handoff permite "schema próprio painel OU prefixo painel_";
--    prefixo evita ter que expor schema custom no PostgREST.)
-- Segurança: RLS ligado; cada linha pertence ao dono (auth.uid()).
--   Repo é PÚBLICO e a tabela guarda CPF/nome → sem login ninguém lê.
-- NÃO toca em nada do central-financeira.
-- ============================================================

-- ----- UP -----
create table if not exists public.painel_funcionarios (
  id         text primary key,                       -- id gerado no cliente
  owner      uuid not null default auth.uid(),        -- dono = usuário logado
  nome       text,
  cargo      text,
  ativo      boolean default true,
  data       jsonb not null default '{}'::jsonb,       -- estado completo do funcionário
                                                       -- (ident c/ CPF, sch, carga, vig, ponto, bancoIni)
  updated_at timestamptz default now()
);

alter table public.painel_funcionarios enable row level security;

-- dono vê/insere/edita/remove só o que é dele
drop policy if exists painel_func_all on public.painel_funcionarios;
create policy painel_func_all on public.painel_funcionarios
  for all
  using (owner = auth.uid())
  with check (owner = auth.uid());

-- privilégios: só usuário logado (nunca anon)
grant select, insert, update, delete on public.painel_funcionarios to authenticated;

-- ----- DOWN (reversão) -----
-- drop policy if exists painel_func_all on public.painel_funcionarios;
-- revoke all on public.painel_funcionarios from authenticated;
-- drop table if exists public.painel_funcionarios;

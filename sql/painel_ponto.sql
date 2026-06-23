-- ============================================================
-- Painel Central · Casa › Funcionário — Controle de Ponto (check-in da funcionária)
-- Migration: painel_ponto (v1)  · roda DEPOIS de painel_casa.sql
-- Projeto Supabase: REUSA o do central-financeira. NÃO toca em mais nada.
--
-- Modelo de acesso:
--  - Gustavo (owner) gerencia a funcionária e vê tudo.
--  - A funcionária loga com o email que o Gustavo cadastrou em `invite_email`
--    e enxerga SÓ a própria linha (schedule) + bate o próprio ponto. Via RLS por email.
-- ============================================================

-- ----- UP -----

-- 1) email autorizado da funcionária (quem pode bater o ponto dela)
alter table public.painel_funcionarios add column if not exists invite_email text;

-- a funcionária pode LER (não editar) a própria linha, pra ver o horário planejado
drop policy if exists painel_func_emp_sel on public.painel_funcionarios;
create policy painel_func_emp_sel on public.painel_funcionarios
  for select
  using (invite_email is not null and invite_email = (auth.jwt() ->> 'email'));

-- 2) registros de ponto (1 linha por funcionária por dia)
create table if not exists public.painel_ponto (
  id             text primary key,            -- = funcionario_id || '|' || dia
  funcionario_id text not null,
  dia            date not null,
  ent            time,                         -- entrada
  int_sai        time,                         -- saída do intervalo
  int_vol        time,                         -- volta do intervalo
  sai            time,                         -- saída (fim do expediente)
  locs           jsonb default '{}'::jsonb,    -- localização de cada batida {ent:{lat,lng},...}
  obs            text,
  updated_at     timestamptz default now(),
  unique (funcionario_id, dia)
);

alter table public.painel_ponto enable row level security;

-- dono OU funcionária convidada (por email) acessam os registros daquela funcionária
drop policy if exists painel_ponto_all on public.painel_ponto;
create policy painel_ponto_all on public.painel_ponto
  for all
  using (
    funcionario_id in (
      select f.id from public.painel_funcionarios f
      where f.owner = auth.uid()
         or f.invite_email = (auth.jwt() ->> 'email')
    )
  )
  with check (
    funcionario_id in (
      select f.id from public.painel_funcionarios f
      where f.owner = auth.uid()
         or f.invite_email = (auth.jwt() ->> 'email')
    )
  );

grant select, insert, update, delete on public.painel_ponto to authenticated;

-- ----- DOWN (reversão) -----
-- drop policy if exists painel_ponto_all on public.painel_ponto;
-- revoke all on public.painel_ponto from authenticated;
-- drop table if exists public.painel_ponto;
-- drop policy if exists painel_func_emp_sel on public.painel_funcionarios;
-- alter table public.painel_funcionarios drop column if exists invite_email;

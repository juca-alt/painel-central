-- ============================================================================
-- PAINEL CENTRAL · 🍷 ADEGA JUCÁ — histórico de vinhos (dimensão Pessoal)
-- App: Painel Central (juca-alt/painel-central). Migration: painel_adega (v1)
-- Projeto Supabase: mieqsiojvfiqrhectquc (COMPARTILHADO com Pipe X + central-financeira)
-- REGRA DE OURO: só ADICIONA objetos com prefixo painel_. NÃO altera/dropa/referencia
--   nada de Pipe X nem do central-financeira.
-- Origem do modelo: base Notion "🍷 Adega Jucá" (collection fda5a751-…), alimentada pelo
--   skill Sommelier Jucá. Os 10 campos do Notion viram as 10 colunas de negócio abaixo.
-- Isolamento: schema public, prefixo painel_, RLS owner-isolado (auth.uid()).
--   Grant só a `authenticated`, NUNCA a `anon` (repo é público).
-- ENUMs: text + CHECK (não CREATE TYPE) — evita ALTER TYPE irreversível e colisão global.
-- Rodar: colar no SQL Editor do Supabase e Run. IDEMPOTENTE (rodar 2× = mesmo resultado):
--   DDL com if not exists / or replace / drop if exists; seed com on conflict do nothing.
-- Escrita no app: PostgREST direto (SB.rest), igual Gael/Contatos. Central Financeira
--   NÃO é integrada aqui (fora de escopo do ticket #2) — `custo_medio` fica pronto pra ponte.
-- ============================================================================

-- ----- UP -----

-- Função reutilizável de updated_at (idempotente; mesma do central-financeira / gael_).
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create table if not exists public.painel_adega (
  id              uuid primary key default gen_random_uuid(),
  owner           uuid not null default auth.uid(),
  -- ---- os 10 campos do Notion ----
  vinho           text not null,                          -- Vinho (título)
  produtor        text,                                   -- Produtor/Origem
  uva             text,                                   -- Uva/Tipo
  safra           text,                                   -- Safra (texto: "2025", "NV"…)
  nota            smallint check (nota between 1 and 5),  -- Nota Jucá ★1–5
  harmonizacoes   text,                                   -- Harmonizações
  custo_medio     numeric(10,2) check (custo_medio is null or custo_medio >= 0), -- Custo médio (R$)
  ocasiao         text check (ocasiao is null or ocasiao in ('Dia a dia','Especial/Camila','Presente','Jantar fora')),
  repetir         text check (repetir is null or repetir in ('Sim','Não','Talvez')), -- Repetir?
  notas           text,                                   -- Correlatos/Notas
  data            date,                                   -- Data (quando tomou)
  -- ---- rastreio da migração Notion → Supabase ----
  notion_url      text unique,                            -- url da página no Notion (chave da migração)
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);
create index if not exists idx_painel_adega_owner on public.painel_adega(owner);
create index if not exists idx_painel_adega_data  on public.painel_adega(data desc);
drop trigger if exists trg_painel_adega_updated on public.painel_adega;
create trigger trg_painel_adega_updated before update on public.painel_adega
  for each row execute function set_updated_at();
alter table public.painel_adega enable row level security;
drop policy if exists painel_adega_all on public.painel_adega;
create policy painel_adega_all on public.painel_adega
  for all using (owner = auth.uid()) with check (owner = auth.uid());
revoke all on public.painel_adega from anon;
grant select, insert, update, delete on public.painel_adega to authenticated;

-- ----- SEED: os 2 registros que já existem na base Notion -----
-- No SQL Editor auth.uid() é NULL, então o dono é resolvido pelo email do Gustavo.
-- Se o usuário ainda não existir em auth.users, o seed não insere nada (e não quebra);
-- rode de novo depois do 1º login. `on conflict (notion_url) do nothing` = idempotente.
insert into public.painel_adega
  (owner, vinho, produtor, uva, safra, nota, harmonizacoes, custo_medio, ocasiao, repetir, notas, data, notion_url)
select u.id, v.*
from (values
  ('Cousiño-Macul Don Luis, Sauvignon Blanc 2025',
   'Cousiño-Macul, Vale do Maipo (Chile)',
   'Sauvignon Blanc, sem barrica',
   '2025',
   3,
   'Cabra fresco, minas frescal/ricota temperada, coalho grelhado, peixe branco grelhado, camarão na chapa, sushi/sashimi, burrata',
   null::numeric,
   'Dia a dia',
   'Talvez',
   'Linha de entrada, 12,5%. Branco de terça-feira — fresco, sem complexidade pra guardar. Servir 6–8°C.',
   date '2026-09-19',
   'https://app.notion.com/p/3e2681f952bc8178a8fad4d7d05cfb3e'),
  ('Casas del Toqui, Semillon Barrel Series',
   'Casas del Toqui, Vale do Cachapoal (Chile)',
   'Semillon, com barrica de carvalho',
   null,
   4,
   'Camarão + bisque de coco, atum selado no gergelim, polvo grelhado, risoto de muhammara, entrada com brie/cogumelo trufado',
   180::numeric,
   'Especial/Camila',
   'Sim',
   'Levado ao Ariano (Recife) com Camila, jantar Duo Gourmet. Corpo, cremoso, baunilha e tostado da barrica. Servir 10–12°C, arejar 10min antes.',
   date '2026-06-10',
   'https://app.notion.com/p/3e2681f952bc810c8d72ca5fe5317f32')
) as v(vinho, produtor, uva, safra, nota, harmonizacoes, custo_medio, ocasiao, repetir, notas, data, notion_url)
join auth.users u on lower(u.email) = 'juca@segurocomjuca.com'
on conflict (notion_url) do nothing;

-- ----- DOWN (reversão) -----
-- drop trigger if exists trg_painel_adega_updated on public.painel_adega;
-- drop policy if exists painel_adega_all on public.painel_adega;
-- revoke all on public.painel_adega from authenticated;
-- drop table if exists public.painel_adega;

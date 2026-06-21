# Painel Central — Handoff pro Claude Code: módulo **Casa › Funcionários**

Documento de transição Cowork → Code. Foi prototipado no Cowork (`casa-debora.html`, já no repo e no ar); agora vira **módulo de verdade dentro do `index.html`**, com persistência em **Supabase**. Cole o prompt do final no Claude Code.

> Voz do projeto: single-file, sem build, sem deps, dual-mode, tema claro. Mesmas regras do `HANDOFF_PARA_CODE.md`. Trabalhar incremental, sem overengineering.

---

## O que é (a tarefa)
Adicionar um novo módulo **🏠 Casa** ao painel, começando pelo submódulo **Funcionários**. Primeiro funcionário: **Débora** (Empregada Doméstica, admissão 01/04/2025). **Victoria** entra depois — então a estrutura tem que ser **data-driven por funcionário**, não hardcode de uma pessoa só.

Cada funcionário tem dois sub-submódulos (já prototipados):
1. **Carga & Horário** — distribui a carga mensal por dia, em **cenários por mês** (Junho/Julho/Agosto…), conforme a rotina da família/férias. Mostra horas/dia, semana, planejado no mês e saldo vs carga. Calendário do mês + "quadro pra mandar pra Débora" (texto WhatsApp).
2. **Cartão de Ponto** — réplica do modelo da **contabilidade** dele: identificação (empregador, CPF, funcionária, função, admissão) + colunas **Entrada / Saída / Entrada / Saída** + **Hora Extra (Ent./Saí.)** + assinatura, **imprimível**. Calcula trabalhadas, previstas, extras, saldo do mês e **banco de horas** acumulado.

**Carga contratual de referência da Débora:** 8h48/dia · 44h/semana · **220h/mês** (seg–sex; horário-base 09:12–13:00 / 14:00–19:00).

## Protótipo de referência (porta a lógica daqui)
- Arquivo: **`casa-debora.html`** (já no repo, no ar em `/painel-central/casa-debora.html`). Standalone, hoje em `localStorage` (chave `casa_debora_v2`), identificação **em branco** (privacidade).
- Tem toda a UI e os cálculos já prontos pra portar: `dayMins`, `plannedMonth`, `weekdaysInMonth`, `workedMins`, `extraMins`, banco, gerador do "quadro", e o cartão de ponto com CSS de impressão (`@media print`).
- **Reaproveite a lógica de cálculo e o layout**, mas reescreva a camada de dados (localStorage → Supabase) e encaixe na identidade visual + padrão de módulo do `index.html`.

---

## Integração no `index.html` (padrão do painel)
- Adicionar **🏠 Casa** ao array de módulos da sidebar (gaveta lateral no mobile, `side-open` + overlay <880px).
- Casa renderiza a lista de **Funcionários** (Débora; slot "Victoria — em breve"). Clicar abre o funcionário com 2 abas: **Carga & Horário** e **Cartão de Ponto**.
- Reusar a identidade visual aprovada (tema claro, cards, mesmos componentes do painel).
- **Dual-mode:** Supabase é HTTPS REST puro → funciona **igual no standalone (github.io) e no Cowork**. Não depende de `window.cowork`. Manter o app rodável offline para o que não exige rede (cálculos), e degradar com mensagem clara se o Supabase não responder.
- **Sem novas deps se possível:** preferir **Supabase REST (PostgREST) + GoTrue via `fetch`** pra manter o single-file/no-deps. `supabase-js` via CDN é aceitável se simplificar muito — decisão sua, mas REST cru é mais fiel ao projeto.
- Ao mexer em assets/SW, bumpar `CACHE` no `sw.js` (hoje `painel-central-v2`).

---

## Persistência: **Supabase reusando o `central-financeira`** (decisão do Gustavo)

### ⚠️ Privacidade é o ponto crítico (repo é PÚBLICO)
O `index.html` vai no repo público com só a **anon key**. A tabela de funcionários guarda **CPF e nome** → **RLS + Supabase Auth são obrigatórios**: sem login, ninguém (mesmo com a anon key) pode ler/escrever. **Nada de PII no repo/HTML.**

### Regras inegociáveis (do `HANDOFF_PARA_CODE.md`)
1. **NÃO criar projeto Supabase novo.** Reusar o **mesmo** do `central-financeira` (free tier = 2 projetos; já no limite).
2. **Isolar:** tabelas do painel em schema próprio **`painel`** (ou prefixo `painel_`). Nunca criar/alterar/dropar nada do `central-financeira`.
3. **Não tocar** em dados/tabelas/funções/cron do `central-financeira` (sync Organizze→Supabase). Read-only mental.
4. **RLS ligado** em toda tabela nova; nada sem policy.
5. **Service key NUNCA** no front nem no repo. No client, só **anon key** + JWT do usuário logado.
6. **Migrations versionadas e reversíveis** (ex.: `/sql/painel_casa.sql`); testar em branch, conferir colisão antes do DDL no projeto compartilhado.
- **Bônus do reuso:** o cron de keep-alive do `central-financeira` (free pausa após 7 dias) já mantém o projeto acordado → **não precisa de Action nova**.

### Auth (decisão pequena, mas necessária)
- **Recomendado:** Supabase Auth com **provider Google** (casa com o login Google que o painel já usa). RLS por `auth.uid()`.
- Alternativa mais simples: magic-link por email (1 usuário). Evitar senha em texto.
- O que precisa do Gustavo: **URL do projeto Supabase + anon key** (NÃO a service key), e habilitar o provider de auth escolhido.

### Schema sugerido (lean, ajuste à vontade — jsonb pra não explodir em 30 linhas/mês)
```sql
-- schema isolado
create schema if not exists painel;

create table painel.funcionarios (
  id uuid primary key default gen_random_uuid(),
  empregador text, cpf text, endereco text,
  nome text not null, cargo text, admissao date,
  ativo boolean default true,
  owner uuid not null default auth.uid(),
  created_at timestamptz default now()
);

create table painel.horario (
  id uuid primary key default gen_random_uuid(),
  funcionario_id uuid references painel.funcionarios(id) on delete cascade,
  cenario text not null,            -- 'jun' | 'jul' | 'ago' | ou 'YYYY-MM'
  vigencia text,
  carga_mensal_min int,             -- ex.: 220h = 13200
  dias jsonb not null,              -- {seg:{on,e,s,alm}, ter:{...}, ...}
  owner uuid not null default auth.uid(),
  unique (funcionario_id, cenario)
);

create table painel.cartao_ponto (
  id uuid primary key default gen_random_uuid(),
  funcionario_id uuid references painel.funcionarios(id) on delete cascade,
  mes text not null,                -- 'YYYY-MM'
  banco_inicial_min int default 0,
  dias jsonb not null default '{}', -- {1:{e1,sa,va,s2,he,hs,obs}, ...}
  owner uuid not null default auth.uid(),
  unique (funcionario_id, mes)
);

-- RLS em todas
alter table painel.funcionarios enable row level security;
alter table painel.horario     enable row level security;
alter table painel.cartao_ponto enable row level security;
-- policy padrão: dono só vê/edita o que é dele
create policy own_funcionarios on painel.funcionarios using (owner = auth.uid()) with check (owner = auth.uid());
create policy own_horario      on painel.horario      using (owner = auth.uid()) with check (owner = auth.uid());
create policy own_ponto        on painel.cartao_ponto using (owner = auth.uid()) with check (owner = auth.uid());
```
- Salvar com **debounce** ao editar (não a cada tecla).
- Migrar o estado atual do protótipo (se houver algo no `localStorage` do device) é opcional — provavelmente começa limpo no Supabase.

---

## Critérios de pronto
- [ ] **🏠 Casa** aparece na sidebar; Funcionários → **Débora** abre as 2 abas.
- [ ] **Carga & Horário:** cenários Jun/Jul/Ago editáveis, carga calculada, calendário, quadro WhatsApp — **persistido no Supabase e sincronizando entre iPhone/iPad/desktop**.
- [ ] **Cartão de Ponto:** modelo da contabilidade (Entrada/Saída/Entrada/Saída + H.E. + assinatura), imprimível, banco de horas — persistido no Supabase.
- [ ] **Auth + RLS verificados:** deslogado / só anon key **não lê** `painel.funcionarios`; logado como Gustavo lê/escreve só o dele.
- [ ] Reusa o projeto `central-financeira`; tabelas isoladas no schema `painel`; `central-financeira` **intocado**.
- [ ] Sem service key no repo; só anon key; **zero PII no HTML/repo**.
- [ ] **Victoria** adicionável **sem mexer no código** (lista de funcionários vem do banco).
- [ ] Roda no standalone (github.io) e não quebra no Cowork.
- [ ] Migration SQL versionada no repo; testada sem colidir com o central-financeira.
- [ ] Decidir destino do `casa-debora.html`: remover após integrar, ou manter só como atalho (continua sem PII).

## Como continuar no Claude Code
```bash
git clone https://github.com/juca-alt/painel-central.git
cd painel-central
# criar /sql/painel_casa.sql ; editar index.html (módulo Casa) ; sw.js (bump CACHE)
git add -A && git commit -m "feat: módulo Casa › Funcionários (Débora) + Supabase"
git push   # Pages rebuilda sozinho em ~1 min
```

---

## PROMPT PRA COLAR NO CLAUDE CODE
> Você é meu time de engenharia. Projeto: **Painel Central** (PWA single-file). Repo `juca-alt/painel-central` (já clonado), no ar em `https://juca-alt.github.io/painel-central/`. Tudo vive em `index.html` (sem build, sem deps, dual-mode: detecta `window.cowork`, tema claro, gaveta lateral <880px).
>
> **Tarefa:** criar o módulo **🏠 Casa › Funcionários**, começando pela funcionária **Débora** (Empregada Doméstica). Estrutura **data-driven por funcionário** (Victoria entra depois sem mexer no código). Dois sub-submódulos por funcionário: **Carga & Horário** (cenários por mês — Jun/Jul/Ago — pra distribuir a carga de 8h48/dia·44h/sem·220h/mês conforme a rotina da família) e **Cartão de Ponto** (modelo da contabilidade: Entrada/Saída/Entrada/Saída + Hora Extra + assinatura, imprimível; banco de horas, saldo, extras).
>
> **Protótipo pronto pra portar:** `casa-debora.html` (no repo). Reaproveite a UI e os cálculos (`dayMins`, `plannedMonth`, `weekdaysInMonth`, `workedMins`, `extraMins`, banco, gerador do "quadro", CSS de impressão). Encaixe na identidade visual e no padrão de módulo do `index.html`.
>
> **Persistência = Supabase reusando o projeto do `central-financeira`** (NÃO criar projeto novo). Tabelas isoladas no schema `painel` (`funcionarios`, `horario`, `cartao_ponto` — schema sugerido no handoff). **RLS + Supabase Auth obrigatórios** (repo é público, só anon key no front): provider Google de preferência, RLS por `auth.uid()`. **Service key nunca no repo. Zero PII (CPF/nome) no HTML** — só no Supabase, atrás de RLS. Não tocar em nada do `central-financeira`. Migration SQL versionada e reversível em `/sql/`.
>
> Preciso te passar: a **URL do Supabase + a anon key** do projeto central-financeira, e habilitar o provider de auth. Pergunte se não tiver.
>
> Trabalhe incremental, sem overengineering. Entregue rodável, sincronizando entre celular e desktop. Commit + push (Pages rebuilda sozinho). Critérios de pronto no `HANDOFF_CASA_DEBORA.md`.

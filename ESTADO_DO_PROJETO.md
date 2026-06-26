# 📌 ESTADO DO PROJETO — Painel Central
**Última atualização:** 2026-06-25 · Leia isto primeiro ao retomar.

## 1. O que é
PWA single-file do Gustavo (Jucá2.0) — painel único (Agenda, Tarefas, Inbox, **Casa › Feira + Funcionário**, Saúde, Provas Camila, Atalhos, Configuração, Fôlego). Tudo em `index.html` (sem build/deps). Dual-mode (Cowork via MCP / standalone via OAuth GIS). No ar em https://juca-alt.github.io/painel-central/ · repo `juca-alt/painel-central` (`main`). Produção atual: **v2.5.1** — reskin "Basil" do shell + módulo **Saúde · Gael** (ver §2).

## 2. O que mudou na sessão (25/06) — reskin + módulo Gael
**Reskin "Basil" do shell (v2.4.0, commit `124e289`):** sidebar antes ESCURA virou CLARA; accent azul→**Basil verde `#639922`**; fonte **Inter** + ícones **Tabler webfont** (cdnjs **v3.34.0** — a `2.47.0/iconfont` dá 404; classes `ti ti-*`); brand com dot verde; nav ativo em tint Basil. Mexe SÓ em tokens `:root` + bloco da sidebar/nav + troca dos emojis do nav por `<i class="ti">`; **layout interno dos módulos intacto** (só recolore via `var(--accent)`). Gustavo preferiu essa cara à antiga.

**Módulo Saúde · Gael (v2.5.0/2.5.1, commits `2c24d42`/`dec7a1b`):** histórico vivo de saúde do Gael. Nova view `view-gael` / nav `nav-gael` (ti-heart) — SEPARADA da "Saúde" existente (esta é pendência de tarefa via planilha). Engine **Table-CRUD config-driven** (IIFE `GAEL`, objeto `SCHEMA` no fim do `<script>`) p/ 6 entidades (consultas, diagnósticos, medicamentos, exames, equipe, investigações); listas com badges de status + chips de tipo + flag `controlado` (cadeado); add/editar/excluir via modal próprio (`.gael-modal-*`); plugado no `SB.rest`. **Login não-redundante:** logado abre tela direto (sem banner); deslogado mostra aviso slim "Conectar uma vez" (mesmo login do painel; sessão persiste). Mantém RLS owner-isolado — repo + anon key são PÚBLICOS, sem auth os dados de saúde do Gael ficariam world-readable.

**Fundação de dados (commit `358f0ee`):** `/sql/gael_saude.sql` (6 tabelas `gael_*`, RLS `owner=auth.uid()`, grant authenticated, `text+CHECK`) + `/sql/gael_saude_seed.sql` (consulta 05/06/2026 Dr. Gustavo Almeida/Conecta; idempotente, owner via subquery em `auth.users`; contagens 1/10/21/2/9/7). Schema travado com 6 ajustes vs. briefing (local; registro_conselho+nome nullable; TEA+TDAH+Depressão+AH em 4 linhas + peso/altura; flag controlado; status 'sugerido'+preparo em exames; 'em_investigacao' em investigacoes).

## (histórico 21/06) Casa › Funcionário
Implementado o submódulo **Casa › 👥 Funcionário** (que na produção era só placeholder), portando o protótipo `casa-debora.html` pra dentro do `index.html`, dentro de `view-funcionario`.
> ⚠️ **Cuidado registrado:** meu clone local estava velho. A produção remota já tinha avançado pra v2.2.0 (Casa como subnav). Em vez de atropelar, **resetei pro remoto e re-portei** o módulo em cima da v2.2.0 — nada da v2.2.0 foi perdido.

- **Data-driven:** lista de funcionários nasce vazia; adicionar/remover/renomear pela UI (Victoria entra sem código). **Zero PII hardcoded no repo.**
- **2 abas:** Carga & Horário (cenários Jun/Jul/Ago, quadro semanal, calendário, "quadro pra WhatsApp", 8h48/dia·44h/sem·220h/mês) e Cartão de Ponto (E/S/E/S + H.E. + assinatura, imprimível, banco de horas). Cálculos validados no preview (jun/2026 = 193h36; saldo −26h24 vs 220h).
- **Persistência 2 camadas com PII protegida:** dados **operacionais** (horários, ponto, carga) ficam no `localStorage` (`painel_casa_v1`) pra uso offline; **PII (nome, CPF, endereço, admissão) NUNCA toca o localStorage** — vive só no **Supabase** atrás de RLS, quando logado. Função `scrub()` remove a PII antes de gravar local. Deslogado, a identificação some no reload (o app avisa). Decisão do Gustavo (recado Cowork: "CPF e nome só no Supabase").
- **Portado nos DOIS arquivos:** `index.html` (produção) **e** `index-next.html` (staging) — pra uma futura promoção staging→prod não apagar o módulo. `index-backup-2026-06-20.html` deixado intocado.
- **Supabase (módulo `SB` no `index.html`):** auth magic-link por email + REST (PostgREST) via `fetch`, client-side. **Dormente até preencher URL/anon key** — sem isso roda 100% local (barra "Sincronização desligada"). Não há outra integração Supabase no app.
- **Migration:** `/sql/painel_casa.sql` — `public.painel_funcionarios` (prefixo `painel_`, jsonb), RLS por `auth.uid()`, grant só `authenticated`, reversível. NÃO toca em nada do central-financeira.
- `sw.js`: cache `v2` → `v3`.

## 3. Decisões (com o porquê)
- **Re-portar em vez de force-push** — a produção v2.2.0 estava à frente; clobberar seria perda. Resetei e integrei no placeholder `view-funcionario`.
- **Prefixo `painel_` no schema `public`** (não schema custom) — evita expor schema no PostgREST. Handoff permitia.
- **1 tabela `data jsonb`** (não 3 normalizadas) — bate 1:1 com o cliente; sync = 1 upsert/funcionário.
- **Login magic-link por email** (não Google provider) — simples p/ 1 usuário, não mexe no fluxo GIS existente.
- **Lista vazia + add pela UI** — atende "Victoria sem código" E "zero PII no HTML".
- **anon key no repo é OK** (pública por design; RLS protege CPF/nome). Service key NUNCA.

## 4. Estado atual
- ✅ Submódulo Funcionário completo, no ar (v2.2.0), sem erros. Roda offline (localStorage) p/ dados operacionais.
- ✅ Supabase **ativo e configurado** (credenciais + tabelas + RLS + redirect). Verificado: anon lê zero.
- ✅ **Controle de ponto da funcionária NO AR** (commit `a7261ad`): visão dela com 2 abas (Ponto do dia / Mês imprimível), bater ponto com **validação por GPS**, admin cadastra email de acesso (RLS por email) + local de trabalho. Migration `painel_ponto.sql` já rodada.
- ✅ **v2.3.1**: **botão 🔄 atualizar** na sidebar (acompanha versões) + **Local de trabalho por endereço** (add/editar/excluir, geocodifica via OSM; endereço NÃO fica no repo, só no Supabase).
- ✅ **v2.3.2** (commit `30738b0`): **fix mobile** — tabelas largas do Funcionário rolam dentro do card (não estouram mais a página no celular). Mobile = mesmo index.html responsivo.
- 🟡 **PENDENTE — testar Casa/ponto (Gustavo):** login admin → cadastrar email de teste na Débora → definir endereço do Local de trabalho → logar com esse email noutro navegador → bater ponto → conferir em "Ponto real".
- ✅ **v2.4.0 reskin Basil** + **v2.5.0/2.5.1 módulo Saúde·Gael** no ar (Table-CRUD das 6 entidades; UI verificada no preview com dados fake — porta nova 8799 p/ fugir do cache de SW; sintaxe validada via `osascript -l JavaScript`, não há `node` no ambiente).
- ✅ **SQL RODADO (2026-06-25, via Chrome MCP no SQL Editor):** migração + seed executados; contagens **1/10/21/2/9/7** (Rodada 1 PROVADA — schema aguentou a consulta real). Verificado: anon lê `[]` (RLS owner protege). **Resta só:** Gustavo logar 1x no app (magic-link) → a tela Saúde·Gael mostra os dados.

## 5. Mapa dos arquivos (`~/Documents/painel-central`)
| Arquivo | O que é |
|---|---|
| `index.html` | App inteiro (v2.2.0 + módulos `SB` e `CASA` no fim do `<script>`; view `view-funcionario`). |
| `sql/painel_casa.sql` | Migration RLS Casa (rodar no Supabase). |
| `sql/gael_saude.sql` | Migration das 6 tabelas `gael_*` (RLS owner). **Rodar no Supabase.** |
| `sql/gael_saude_seed.sql` | Seed da consulta 05/06/2026. **Rodar após a migration.** |
| `sw.js` | Service worker (cache `v3`). |
| `casa-debora.html` | Protótipo original (referência; já no repo). |
| `HANDOFF_CASA_DEBORA.md` | Spec do módulo. |

Config Supabase: topo do bloco `var SB=(function(){ var URL=""; var ANON=""; ...` no `index.html`.

## 6. Ativação Supabase — FEITA (21/06)
Sync **ligada e no ar**. Tudo já executado:
1. ✅ **Credenciais:** URL `https://mieqsiojvfiqrhectquc.supabase.co` + anon key (reuso do central-financeira) coladas no bloco `SB` (index.html + index-next.html), deployadas (commit `e86d2c7`).
2. ✅ **Migration rodada** no SQL Editor → tabela `public.painel_funcionarios` criada (RLS + policy `owner=auth.uid()` + grant authenticated). Verificado por REST: anon recebe `[]` (lê zero dado).
3. ✅ **Redirect URL** `https://juca-alt.github.io/painel-central/**` adicionada (Site URL `localhost:3000` intocada — compartilhada com Pipe X). Email provider já ativo.
4. ✅ App ao vivo confirmado em modo configurado (barra "🔒 Conecte pra sincronizar").

**ÚNICO passo restante (só o Gustavo):** abrir Casa › Funcionário, digitar o email `juca@segurocomjuca.com`, clicar **Enviar link**, e clicar no link que chega no email → loga e a sync entre aparelhos passa a valer. (Eu não pude disparar o email — a trava de segurança bloqueia envio em nome do usuário.) Mesmo `auth.uid` do central-financeira, então é o mesmo login.

## 7. Pendência antiga (sem relação com Casa)
- 🔴 Tarefas/Saúde ao vivo no standalone: ativar Google Sheets API em `painel-central-499400` + reconectar Google. Código já deployado e inerte.

---
**Como retomar:** "li o ESTADO_DO_PROJETO, bora no passo X". **Próximo natural:** logar 1x no app (magic-link) → conferir a tela Saúde·Gael com os dados reais (SQL **já rodado** — 1/10/21/2/9/7). Versões: v2.2.0→v2.3.2 (Casa/ponto) → v2.4.0 (reskin Basil) → v2.5.1 (módulo Gael).

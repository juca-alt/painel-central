# 📌 ESTADO DO PROJETO — Painel Central
**Última atualização:** 2026-06-21 · Leia isto primeiro ao retomar.

## 1. O que é
PWA single-file do Gustavo (Jucá2.0) — painel único (Agenda, Tarefas, Inbox, **Casa › Feira + Funcionário**, Saúde, Provas Camila, Atalhos, Configuração, Fôlego). Tudo em `index.html` (sem build/deps). Dual-mode (Cowork via MCP / standalone via OAuth GIS). No ar em https://juca-alt.github.io/painel-central/ · repo `juca-alt/painel-central` (`main`). Produção atual: **v2.2.0** (mobile, login Google persistente, Configuração, Histórico).

## 2. O que mudou nesta sessão (21/06)
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
- 🟡 **PENDENTE — testar (Gustavo):** login admin → cadastrar email de teste na Débora → definir o endereço do Local de trabalho (digitar + "Localizar endereço") → logar com o email de teste noutro navegador → bater ponto (permite GPS) → conferir em "Ponto real". Depois: dados reais + email da Débora.

## 5. Mapa dos arquivos (`~/Documents/painel-central`)
| Arquivo | O que é |
|---|---|
| `index.html` | App inteiro (v2.2.0 + módulos `SB` e `CASA` no fim do `<script>`; view `view-funcionario`). |
| `sql/painel_casa.sql` | Migration RLS (rodar no Supabase). |
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
**Como retomar:** "li o ESTADO_DO_PROJETO, bora no passo X". Próximo natural: **ligar a sync do Supabase** (item 6) quando tiver as credenciais.

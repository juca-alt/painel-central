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
- ✅ Submódulo Funcionário completo, verificado no preview sobre a v2.2.0, sem erros. Roda offline (localStorage).
- ✅ Código Supabase escrito e dormente (liga sozinho após os passos do item 6).
- 🟡 Sync entre aparelhos: ainda NÃO ativa (depende do item 6).

## 5. Mapa dos arquivos (`~/Documents/painel-central`)
| Arquivo | O que é |
|---|---|
| `index.html` | App inteiro (v2.2.0 + módulos `SB` e `CASA` no fim do `<script>`; view `view-funcionario`). |
| `sql/painel_casa.sql` | Migration RLS (rodar no Supabase). |
| `sw.js` | Service worker (cache `v3`). |
| `casa-debora.html` | Protótipo original (referência; já no repo). |
| `HANDOFF_CASA_DEBORA.md` | Spec do módulo. |

Config Supabase: topo do bloco `var SB=(function(){ var URL=""; var ANON=""; ...` no `index.html`.

## 6. Próximos passos (só o Gustavo, pra ligar a sync)
1. **Supabase → Settings → API:** colar **Project URL** + **anon/public key** (NUNCA service key) em `URL`/`ANON` no bloco `SB`.
2. **Supabase → SQL Editor:** rodar `/sql/painel_casa.sql`.
3. **Supabase → Authentication:** Email ligado em Providers; em URL Configuration adicionar `https://juca-alt.github.io/painel-central/` em Site URL + Redirect URLs.
4. Redeploy, abrir o app em Casa › Funcionário, "Enviar link", entrar pelo email → testar sync em 2 aparelhos.

## 7. Pendência antiga (sem relação com Casa)
- 🔴 Tarefas/Saúde ao vivo no standalone: ativar Google Sheets API em `painel-central-499400` + reconectar Google. Código já deployado e inerte.

---
**Como retomar:** "li o ESTADO_DO_PROJETO, bora no passo X". Próximo natural: **ligar a sync do Supabase** (item 6) quando tiver as credenciais.

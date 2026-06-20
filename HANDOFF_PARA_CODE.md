# Painel Central — Handoff pro Claude Code

Documento de transição: sai do fluxo "upload pela web do GitHub" (usado no Cowork) e entra no fluxo de **código de verdade** (clone local + git + push). Cole o prompt do final no Claude Code.

---

## O que é
Painel único do Gustavo ("tudo é uma coisa só"): agenda, tarefas, inbox, feira, saúde, provas, atalhos. HTML único, sem dependências (só emoji + JS puro). Tema claro.

## Onde está (fonte canônica = o repo)
- **Repo:** `https://github.com/juca-alt/painel-central` (público)
- **No ar (PWA):** `https://juca-alt.github.io/painel-central/`
- **Cowork artifact** `painel-central`: agora é só um **espelho** do desktop. Canônico = o repo. Editar no repo; se quiser refletir no Cowork, re-subir o HTML lá.
- Arquivos: `index.html` (tudo), `manifest.json`, `sw.js`, `icon-192.png`, `icon-512.png`.

## Arquitetura (regras do código)
- **Single-file:** toda a lógica em `index.html`. Sem build, sem framework.
- **Dual-mode:** detecta `window.cowork`. No Cowork → conectores via `window.cowork.callMcpTool` (ao vivo). No github.io → degrada com `liveStub()`/`connectPanel()`; nunca quebra.
- **PWA:** `sw.js` é **network-first pro HTML** (index atualiza sozinho online; cai pro cache offline) e cache-first pros assets. Ao mudar assets, bumpar `CACHE` (hoje `painel-central-v2`).
- **Mobile:** menu vira **gaveta lateral** (`☰`, classe `side-open` + overlay) abaixo de 880px.
- **localStorage:** `feira_estoque_v1` (estoque da feira), `folego_v1` (Fôlego), `gtok` (sessionStorage, access token Google).

## Estado atual (o que está vivo)
- ✅ **Feira + Fôlego:** 100% no standalone (localStorage). Feira: 21 itens semeados, 14 a repor, estimativa R$338,47.
- ✅ **Agenda + Provas + Inbox:** ao vivo no standalone via **OAuth Google client-side (GIS)** — privado, só após login. Botão "Conectar Google".
- ⬜ **Tarefas + Saúde:** ainda em `liveStub` no standalone. **Esta é a próxima tarefa.**

## OAuth Google (já configurado — não refazer)
- **Projeto Google Cloud:** `painel-central-499400` (org `segurocomjuca.com`), consent **Interno**.
- **APIs ativadas:** Google Calendar API, Gmail API.
- **OAuth Client (Web):** `63708753663-92us3rgem9s1j6rapi86b8uerc5440fr.apps.googleusercontent.com`
  - Origem JS autorizada: `https://juca-alt.github.io`
- **Escopos:** `calendar.readonly` + `gmail.readonly`.
- Client ID é **público por design** (pode ficar no repo). **Client secret NÃO é usada** no client-side e NUNCA deve ser commitada.
- Token fica em `sessionStorage.gtok`; expira ~1h → reconecta.

## Próxima tarefa: Tarefas + Saúde ao vivo no standalone
Duas formas:
1. **Sheets API via o mesmo OAuth** (recomendado p/ manter privado): ativar Google Sheets API no projeto `painel-central-499400`, somar escopo `spreadsheets.readonly` ao `GCAL_SCOPE`, e ler a planilha por REST.
2. (alternativa sem OAuth) publicar a planilha como CSV — mais simples, porém deixa os dados legíveis por link.
- **Planilha Central de Tarefas:** id `1Am0Z2e4qoYPpy8eUNIzpPBn_30f9Fzsl64CwS1IVx9M` (abas: Backlog, Arquivo, Dump, Bússola).
- ⚠️ **Parser:** no Cowork a planilha chega como **markdown** (parser atual `parseCentral`). Fora do Cowork ela vem como **values/CSV** → **precisa de um parser novo** (não dá pra reusar o de markdown). Mapear colunas: status por emoji (✅❌⏱❇⏳▶), prazo `dd/mm[/aaaa]`, prioridade = nº de `!`.
- `loadCentral` alimenta Tarefas, Saúde, Dump e os cards do "Hoje" — religar os 4 de uma vez.

## REGRAS SUPABASE (inegociáveis — não misturar nem bagunçar)
> O painel HOJE **não precisa de Supabase** (OAuth + localStorage cobrem o que está vivo). Supabase só entra pra features futuras: histórico de preço da feira, estado compartilhado, automações. Quando chegar nisso, valem estas regras:

1. **NÃO criar projeto Supabase novo.** Reusar o **mesmo** projeto do `central-financeira`. (Free tier = 2 projetos ativos; já no limite — um 3º quebra.)
2. **Isolar as tabelas do painel:** schema próprio `painel` (ou prefixo `painel_`). **Nunca** criar/alterar/dropar nada que o `central-financeira` usa.
3. **Não tocar** nos dados/tabelas/funções/cron do `central-financeira` (o sync Organizze→Supabase). Trate como read-only mental.
4. **RLS ligado** em toda tabela nova. Nada exposto sem policy.
5. **Service key NUNCA** no front nem no repo público. No client, só a anon key — e só as tabelas do painel.
6. **Migrations versionadas e reversíveis.** Testar em branch antes de aplicar no projeto compartilhado; conferir que nenhum DDL colide com o central-financeira.

## Padrão a seguir (o que o Gustavo gosta)
`central-financeira`: PWA estático no GitHub Pages + Supabase + GitHub Actions (cron mantém o Supabase acordado — free pausa após 7 dias). Repos dele: `crm-captacao`, `central-financeira`, `my-sheet-buddy-20`, e agora `painel-central`.

## Como continuar no Claude Code
```bash
git clone https://github.com/juca-alt/painel-central.git
cd painel-central
# editar index.html / sw.js etc.
git add -A && git commit -m "feat: tarefas+saude ao vivo (sheets api)"
git push
# GitHub Pages rebuilda sozinho em ~1 min
```

---

## PROMPT PRA COLAR NO CLAUDE CODE
> Você é meu time de engenharia. Projeto: **Painel Central** (PWA single-file). Repo `juca-alt/painel-central` (já clonado), no ar em `https://juca-alt.github.io/painel-central/`. Tudo vive em `index.html` (sem build, sem deps, dual-mode: detecta `window.cowork`).
>
> Já está vivo: Feira+Fôlego (localStorage); Agenda+Provas+Inbox via OAuth Google client-side (GIS) — projeto Google Cloud `painel-central-499400`, Client ID `63708753663-92us3rgem9s1j6rapi86b8uerc5440fr.apps.googleusercontent.com`, escopos `calendar.readonly`+`gmail.readonly`.
>
> **Tarefa:** religar **Tarefas + Saúde** ao vivo no standalone. Use Sheets API via o mesmo OAuth (ativar Sheets API no projeto, somar escopo `spreadsheets.readonly`), planilha id `1Am0Z2e4qoYPpy8eUNIzpPBn_30f9Fzsl64CwS1IVx9M` (abas Backlog/Arquivo/Dump/Bússola). **Escreva um parser de values novo** (o `parseCentral` atual é de markdown e NÃO serve pra values/CSV). `loadCentral` alimenta Tarefas, Saúde, Dump e os cards do Hoje.
>
> **Regras Supabase (se/quando entrar):** não criar projeto novo — reusar o do central-financeira; tabelas isoladas (schema/prefixo `painel`); nunca tocar nas tabelas do central-financeira; RLS ligado; service key nunca no front. Mas: o painel não precisa de Supabase agora — só OAuth + localStorage.
>
> Trabalhe incremental, sem overengineering. Entregue rodável, commit + push (Pages rebuilda sozinho).

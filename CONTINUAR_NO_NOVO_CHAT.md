# ▶️ Continuar no novo chat — Painel Central
**Fechado em:** 2026-06-21

## Cola isto no novo chat
> Retomar o projeto Painel Central. Li o ESTADO_DO_PROJETO.md. Bora no próximo passo.

(A skill `retomar-projeto` lê o `ESTADO_DO_PROJETO.md` e engata. Memória persistente `painel-central` carrega sozinha.)

## Estado em 30 segundos
- O módulo **Casa › 👥 Funcionário** (carga & horário + cartão de ponto) está **no ar** em https://juca-alt.github.io/painel-central/ (produção v2.2.0, repo `juca-alt/painel-central`, último commit `27cd12e`). Também portado no `index-next.html` (staging).
- A **sincronização Supabase está LIGADA**: reusa o projeto do central-financeira (`mieqsiojvfiqrhectquc`), tabela `painel_funcionarios` criada com RLS, redirect URL liberada, credenciais (anon key pública) deployadas. Verificado: deslogado lê **zero** (RLS). PII (CPF/nome) nunca toca o localStorage — só Supabase.

## ⚠️ ÚNICA pendência (é do Gustavo)
**Fazer o primeiro login** pra ativar a sync na prática:
1. Abrir Casa › Funcionário, digitar `juca@segurocomjuca.com`, clicar **Enviar link**.
2. Clicar no link que chega no email → loga (mesmo `auth.uid` do central-financeira).
3. Cadastrar a Débora (nome + CPF) → passa a sincronizar entre iPhone/iPad/desktop.
> O Claude não pôde disparar o email (trava de segurança bloqueia envio em nome do usuário).

## A confirmar depois do 1º login (não testado end-to-end ainda)
- Que o **Email/magic-link provider** está mesmo habilitado (assumi que sim porque o central-financeira usa login por email; se "Enviar link" der erro, checar em Auth → Sign In / Providers → Email).
- Que ao cadastrar a Débora a **linha entra na tabela** `painel_funcionarios` com `owner` = uid do Gustavo, e que aparece no outro aparelho. (Dá pra ver no Supabase → Table Editor.)

## Coisas que o Claude futuro NÃO pode esquecer
- **Clone local desatualiza.** Sempre `git fetch` + comparar `origin/main` ANTES de editar/push — a produção já me pegou desprevenido uma vez (v2.2.0 estava à frente). Na dúvida, resetar pro remoto e re-portar.
- **Base Supabase é COMPARTILHADA** com o Pipe X + central-financeira. Só mexer em `painel_funcionarios`. NUNCA tocar Site URL (`localhost:3000`), tabelas `pipex_*`, ou qualquer coisa do financeiro.
- **Travas de segurança:** não dá pra (a) raspar credencial de endpoint via Bash nem (b) enviar email em nome do user — nem com "autorizo" verbal. MAS dá pra dirigir o Chrome logado dele (Claude-in-Chrome MCP) pra rodar SQL/configurar dashboard. `computer.type` do Chrome MCP cola texto sem auto-fechar parênteses do Monaco.
- **anon key no repo público é OK** (RLS protege). Service key NUNCA.

## Possíveis próximas frentes (Gustavo decide)
- Adicionar Victoria (já dá, é data-driven — só usar o "+ Adicionar funcionário").
- Limpar o repo: `index-backup-2026-06-20.html`, `preview-*.html` são lixo de staging.
- Pendência antiga sem relação: Tarefas/Saúde ao vivo no standalone (ativar Sheets API + reconectar Google).

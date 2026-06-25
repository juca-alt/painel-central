# ▶️ Continuar no novo chat — Painel Central
**Fechado em:** 2026-06-24 · versão no ar: **v2.3.2**

## Cola isto no novo chat
> Retomar o projeto **Painel Central** (juca-alt/painel-central, PWA single-file, no ar em https://juca-alt.github.io/painel-central/). Li o ESTADO_DO_PROJETO.md e o CONTINUAR_NO_NOVO_CHAT.md em `~/Documents/painel-central/`. Bora evoluir.
>
> ANTES de editar qualquer coisa: `git fetch origin` e comparar com `origin/main` — meu clone local desatualiza e a produção pode estar à frente. Na dúvida, resetar pro remoto e re-portar.
>
> Estado: v2.3.2 no ar. Módulo **Casa › Funcionário** completo (Carga & Horário, Cartão de Ponto manual, e **controle de ponto da funcionária**: check-in geolocalizado com 2 abas — Ponto do dia + Mês imprimível). **Sync Supabase ligada** (reusa o projeto do central-financeira `mieqsiojvfiqrhectquc`; base compartilhada com Pipe X — NÃO tocar). Botão 🔄 atualizar na sidebar. Mobile já ajustado (tabelas rolam dentro do card).
>
> **Pendência principal (minha, Gustavo):** ainda preciso TESTAR o fluxo real — login admin pelo meu email → cadastrar email + endereço da Débora → logar como ela noutro navegador → bater ponto → conferir em "Ponto real". Pergunta se eu já testei antes de evoluir em cima disso.
>
> Próxima frente que eu quero: **[escreva aqui o que vai fazer]**. Trabalha como time de engenharia (skill construir-time-engenharia-ia), incremental, e me mostra no preview antes de deployar (deploy = `git push` na main; produção exige meu OK explícito "pode subir" porque mexe na base compartilhada).

## Estado em 30 segundos
- **No ar (v2.3.2):** Casa › Funcionário com controle de ponto da funcionária (visão dela = login por email/RLS → cai direto em bater ponto; valida GPS/local de trabalho; banco de horas; Mês modelo contador imprimível). Sync Supabase ativa. Mobile responsivo OK.
- **Repo:** `juca-alt/painel-central`. `index.html` = produção; `index-next.html` = staging (mantê-los em sync). `/sql/*.sql` = migrations (painel_casa.sql + painel_ponto.sql, ambas JÁ rodadas no Supabase).
- **Supabase:** projeto `mieqsiojvfiqrhectquc` (reuso central-financeira). Tabelas `painel_funcionarios` + `painel_ponto`, RLS por `auth.uid()` e por email. anon key no repo é OK (RLS protege); service key NUNCA.

## ⚠️ Pendência única (do Gustavo) — testar
1. Abrir Casa › Funcionário, logar com meu email (Enviar link → clicar no email).
2. Abrir a Débora → cadastrar email de acesso de teste + definir Local de trabalho (digitar endereço `Rua Izabel Magalhães, 127 - Boa Viagem, Recife` + CEP `51030-330` → "Localizar endereço").
3. Logar com o email de teste noutro navegador → cair na tela de bater ponto → bater (permite GPS).
4. Conferir como admin no card "Ponto real". Deu certo → trocar pelos dados reais da Débora.

## Coisas que o Claude futuro NÃO pode esquecer
- **git fetch ANTES de editar** — clone local desatualiza; produção já me pegou desprevenido (resetar pro remoto e re-portar quando preciso).
- **Base Supabase é COMPARTILHADA** (Pipe X + central-financeira). Só mexer em `painel_*`. NUNCA tocar Site URL (`localhost:3000`), tabelas `pipex_*`, financeiro.
- **Ações de produção exigem OK explícito** ("pode subir"). A trava de segurança bloqueia: raspar credencial via Bash, enviar email em nome do user, e rodar migration/deploy sem OK. PERMITE dirigir o Chrome logado dele (Claude-in-Chrome MCP) pra rodar SQL — `computer.type` cola sem auto-fechar parênteses do Monaco.
- **Zero PII no repo público** (CPF, nome, endereço da casa) — só no Supabase atrás de RLS. `scrub()` tira PII do localStorage.
- **Versionar:** ao subir mudança, bump `APP_VERSION` (index + index-next) + `CACHE` no sw.js, e sincronizar staging. Mobile/desktop = mesmo index.html responsivo (`@media(max-width:880px)`; flex item precisa `min-width:0` pra tabela larga não estourar).

## Possíveis próximas frentes (Gustavo decide)
- Adicionar Victoria (já dá — "+ Adicionar funcionário", é data-driven).
- Notificação push real (lembrete de bater ponto com app fechado — hoje só com app aberto; precisa VAPID/servidor).
- Estender cenários de horário além de Jun/Jul/Ago.
- Limpar resíduos do repo (`index-backup-2026-06-20.html`, `preview-*.html`).
- Pendência antiga sem relação: Tarefas/Saúde ao vivo no standalone (ativar Sheets API + reconectar Google).

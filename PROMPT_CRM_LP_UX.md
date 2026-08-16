# Prompt pra levar a UX do Jucá 2.0 pro CRM LP

> Gerado na sessão de 16/08/2026 do Painel Central (Jucá 2.0), a pedido do Gustavo.
> **Cole o bloco abaixo inteiro** numa sessão nova do projeto **CRM LP**.
> Ele foi escrito pra ser autossuficiente: descreve o padrão, o método e o critério de aceite,
> sem depender de ninguém ter visto o Jucá.

---

```
Sessão do CRM LP. Quero trazer pra cá a experiência que a gente acertou no meu outro app
(Painel Central / Jucá 2.0, PWA single-file no GitHub Pages). Lá o app ficou bonito, organizado
e — o que mais importa — RÁPIDO e LEVE, no navegador e no celular. Aqui no CRM LP está o oposto:
o desktop é pesado (o Dashboard demora e "carrega pra abrir") e o mobile é praticamente
inutilizável, cheio de erro de layout.

A palavra que resume o que eu quero é FLUIDEZ.

=====================================================================
0) COMO EU QUERO QUE VOCÊ TRABALHE (isto vale pra sessão inteira)
=====================================================================
- NÃO refaça o CRM do zero e não troque a stack. A base e a visão do CRM continuam as mesmas.
  Toda mudança é em cima do que já existe.
- Prefira ENVELOPAR (wrap) função existente a reescrevê-la. Se `render()` já pinta a tela, mantenha
  `render()` e adicione uma camada que decora/observa o resultado. Isso mantém o rollback barato e
  evita quebrar o que funciona.
- Trabalhe em branch, com preview local, e me mostre SCREENSHOT em 390px (celular) e 1280px
  (desktop) antes de subir. Console limpo e zero overflow horizontal são obrigatórios.
- NÃO suba em produção sem meu OK explícito no chat.
- Antes de mexer, LEIA o estado/README do projeto e faça `git fetch`.
- Entregue em fatias que dá pra revisar (uma frente por vez), não num commit gigante.
- Me diga sempre o que ficou de fora e por quê. Não invente que está pronto o que não está.

=====================================================================
1) REGRA PERMANENTE: DESKTOP E MOBILE SÃO DOIS USOS LEGÍTIMOS
=====================================================================
O erro que a gente corrigiu no Jucá foi tratar o mobile como "o desktop encolhido". Aqui vale a
mesma regra, pra sempre:

a) Toda mudança pensa nos DOIS: desktop (mouse, tela larga, hover, teclado, densidade de informação)
   e celular (dedo, tela estreita, toque longo, safe-area, botão voltar do Android). Se a solução
   só serve a um, não está pronta.
b) Isole por mídia, não com remendo. O que é de celular vive num bloco `@media` próprio / numa
   camada isolada; o que é de desktop fica fora dela. Nunca "empurre com margem" o que deveria ser
   resolvido na origem (z-index, layout, posição).
c) Verifique nos dois ANTES de subir: 390px e 1280px, screenshot dos dois, console limpo.
d) Feature nova = feature nos dois. O comportamento pode diferir (no celular vira folha inferior,
   no desktop vira modal), a CAPACIDADE não.

=====================================================================
2) O PADRÃO DE UX QUE FUNCIONOU (copie a ideia, não o pixel)
=====================================================================
No celular, o app inteiro fala o idioma do Google Agenda / Google Tasks:

- BARRA DE APP FIXA no topo (56px + safe-area-inset-top): ☰/← + título da tela + ⋯ + avatar.
  Sombra só depois que a página rola. O título da tela vive NA BARRA — o `h1` da página some no
  celular (ganha uma tela inteira de altura útil).
- Nas telas que NÃO são destino da barra inferior, o ☰ vira ← e volta pra tela anterior.
- BARRA INFERIOR com 4 destinos + um botão de ação central. Os contadores da barra são ESPELHO dos
  badges do menu (uma fonte de verdade só; nada de contar duas vezes).
- O botão de ação central mora DENTRO da barra, não flutuando por cima — flutuando ele tapa a
  última linha da lista.
- GAVETA no formato Google: item ativo em pílula (border-radius 0 26px 26px 0), alvo de 48px, abre
  puxando da borda esquerda e fecha arrastando. A gaveta ROLA (senão o rodapé dela fica inalcançável
  em tela curta) e o scroll dela não vaza pra página de trás.
- TOQUE LONGO numa linha entra em MODO SELEÇÃO: a barra do topo fica colorida com "N selecionados",
  checkbox redondo aparece, os botões inline somem, e a barra vira uma régua de AÇÕES EM LOTE.
- TOQUE SIMPLES abre uma FOLHA INFERIOR (bottom sheet) com as 4-6 ações que você realmente faz
  naquele item, com alvos de 48px+ — e um "Editar tudo" que cai no formulário completo pra quando
  precisar do resto.
- BOTÃO VOLTAR DO ANDROID fecha folha → menu → seleção → gaveta, nessa ordem, antes de sair do app.
  (Cada camada aberta empilha uma entrada de histórico; o popstate fecha a de cima.)
- KPIs em 3 colunas no celular, texto de apoio limitado a 2 linhas com toque pra expandir.
- Listas longas viram TÓPICOS que abrem e fecham, com contador no cabeçalho e "recolher tudo".
  Ordem dos tópicos ajustável pelo usuário e persistida.

No desktop nada disso aparece: a camada mobile inteira fica `display:none` e o comportamento
antigo (sidebar fixa, modal, hover, densidade maior) segue igual.

=====================================================================
3) FLUIDEZ E VELOCIDADE — a parte que mais me incomoda hoje
=====================================================================
Hoje o Dashboard do CRM LP demora e "carrega pra abrir". Quero atacar isso de frente, em TODOS os
módulos. Faça nesta ordem:

3.1 MEÇA ANTES DE MEXER (e me mostre os números)
    - Tempo até a primeira tela útil e até interativo, no desktop e no celular (throttling de rede
      e CPU ligado — celular real não é desktop).
    - Quantas requisições saem ao abrir cada módulo, quais são sequenciais (cascata) e quais
      poderiam ser paralelas.
    - Peso do bundle/HTML/CSS/JS e o que é carregado sem ser usado naquela tela.
    - Quantas queries o Dashboard dispara e quanto cada uma demora.
    Sem esse "antes" a gente não sabe se melhorou. Repita a medição no "depois" e mostre lado a lado.

3.2 REGRAS DE FLUIDEZ (aplicar onde couber, explicando o porquê em cada caso)
    - NADA de tela branca esperando: pinte o esqueleto/layout na hora e preencha quando o dado
      chegar. Percepção de velocidade é metade do problema.
    - Mostre o que já está em cache primeiro e revalide por trás (stale-while-revalidate). Abrir um
      módulo pela segunda vez tem que ser instantâneo.
    - Mate a CASCATA de requisições: o que não depende um do outro sai em paralelo.
    - O Dashboard não pode depender de "carregar tudo pra abrir": traga primeiro os números do topo,
      e os blocos pesados (gráficos, listas longas) entram depois, cada um por conta própria.
    - Agregue no BANCO, não no cliente. Se o Dashboard soma/conta/agrupa em JavaScript sobre milhares
      de linhas, isso vira view/RPC no banco e volta pronto.
    - Só traga as colunas e as linhas que a tela mostra. Paginação/virtualização em lista grande.
    - Escrita OTIMISTA: a UI reflete a ação na hora e reconcilia com o servidor depois; se falhar,
      desfaz e avisa. Nada de travar a tela esperando resposta.
    - Um caminho de gravação só. Nada de duas funções diferentes escrevendo a mesma coisa.
    - Debounce em busca/filtro; não refaça a query a cada tecla.
    - Não recarregue a tela inteira pra mudar um item — repinte só o que mudou.
    - Cuide do cache do app (service worker / versão) pra atualização não deixar o usuário preso numa
      versão velha, e pra abrir offline no que der.

3.3 CRITÉRIO DE ACEITE (é isto que eu vou olhar)
    - Abrir o app e trocar de módulo parece INSTANTÂNEO, inclusive no celular.
    - O Dashboard mostra algo útil em menos de 1s e completa sem travar a tela.
    - Rolagem sem engasgo (60fps) nas listas grandes.
    - Nenhum erro no console, em nenhum módulo, nos dois tamanhos.
    - Zero overflow horizontal no celular, em TODOS os módulos.
    - Todo alvo de toque com pelo menos 44-48px.

=====================================================================
4) COMO EU QUERO QUE VOCÊ COMECE (não saia codando)
=====================================================================
Passo 1 — DIAGNÓSTICO. Varra o CRM LP inteiro e me entregue:
  (a) a lista de módulos/telas e, pra cada um, o que está quebrado ou ruim NO CELULAR
      (com screenshot em 390px — quero ver o estado real, não a descrição);
  (b) as medições de performance do 3.1, com o Dashboard em destaque;
  (c) os 10 problemas que, resolvidos, dão o maior ganho percebido — ordenados por
      (impacto ÷ esforço), dizendo o que cada um custa.

Passo 2 — PLANO em fases, com o que entra em cada uma e o que NÃO entra. Me pergunte o que for
  ambíguo ANTES de começar (principalmente: o que é essencial em cada tela no celular, já que lá
  não cabe tudo). Espere meu OK no plano.

Passo 3 — EXECUÇÃO fase a fase: branch, preview, screenshots 390 + 1280, medição antes/depois,
  e só sobe com meu OK.

=====================================================================
5) O QUE NÃO FAZER
=====================================================================
- Não trocar a stack, não reescrever do zero, não "modernizar" o que já funciona.
- Não mudar a lógica de negócio do CRM (pipeline, status, regras) — isto aqui é UX + performance.
- Não deixar o desktop pior pra melhorar o celular (nem o contrário).
- Não instalar biblioteca pesada pra resolver o que CSS + um punhado de JS resolve. O Jucá é
  single-file, sem build e sem dependência, e é justamente por isso que ele é leve e rápido — não
  precisa ser single-file aqui, mas o espírito é esse: só carregue o que a tela precisa.
- Não dar por pronto sem ter olhado nos dois tamanhos.
```

---

## Nota pra mim (Gustavo)

Se a sessão do CRM LP perguntar "o que exatamente o Jucá faz na tela X?", a resposta curta é:
**barra de app fixa em cima, barra de navegação em baixo, toque longo pra selecionar vários,
toque simples pra abrir uma folha com as ações, e o resto só aparece quando você pede.**
O resto é consequência disso.

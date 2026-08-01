// ============================================================================
// Painel Central — Edge Function `mcp-painel`
// Servidor MCP (Model Context Protocol) do Painel: dá ao Claude (claude.ai,
// Cowork, Claude Code, Desktop) acesso direto aos dados do Painel que moram no
// Supabase — Projetos, Contatos e Inbox triado.
//
// TRANSPORTE: Streamable HTTP — um único endpoint, POST, resposta JSON simples
//   (a spec permite responder application/json em vez de SSE). Stateless: não
//   emitimos nem exigimos Mcp-Session-Id. GET/DELETE respondem 405, como manda
//   a revisão 2026-07-28.
// VERSÃO: ecoamos de volta o protocolVersion que o cliente pediu (negociação
//   conservadora) — clientes hoje falam de 2025-03-26 a 2026-07-28.
//
// AUTENTICAÇÃO (v1): token fixo no header `Authorization: Bearer <MCP_TOKEN>`
//   (o claude.ai chama isso de "Request headers"; Claude Code usa --header).
//   Comparação em tempo constante. Se um dia quisermos login por conta, a troca
//   é só nesta função `autorizado()` — a camada de ferramentas não muda.
//
// ACESSO AO BANCO: usa a SERVICE ROLE (que ignora RLS) e por isso TODA query é
//   forçadamente filtrada por `owner = OWNER_UID`. A service role NUNCA sai
//   daqui — não existe no app nem no repo, só no secret da função.
//
// ESCRITA: as ferramentas que alteram dado exigem `confirmar: true` explícito,
//   além da aprovação que o próprio cliente MCP já pede. Duas trancas de
//   propósito: o Gustavo pediu "ler tudo, escrever com confirmação".
//
// FORA DE ESCOPO (v1): Agenda e Google Tasks. O app fala com o Google pelo
//   navegador dele (token GIS client-side); um servidor não tem essas
//   credenciais. Entra numa 2ª onda, com refresh token server-side.
//
// Secrets (Supabase -> Edge Functions -> mcp-painel -> Secrets):
//   MCP_TOKEN                  token secreto que o Claude manda no header  [obrigatório]
//   OWNER_UID                  auth.uid do Gustavo — escopo de TODA query  [obrigatório]
//   SUPABASE_URL               (injetado pela plataforma)
//   SUPABASE_SERVICE_ROLE_KEY  (injetado pela plataforma)
//
// Deploy:  supabase functions deploy mcp-painel --no-verify-jwt
//   (--no-verify-jwt é obrigatório: quem autentica é o MCP_TOKEN, não um JWT
//    do Supabase. Sem isso a plataforma barra o Claude antes de chegar aqui.)
// ============================================================================

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const MCP_TOKEN = Deno.env.get("MCP_TOKEN") ?? "";
const OWNER_UID = Deno.env.get("OWNER_UID") ?? "";

const SERVER_INFO = { name: "painel-central", title: "Painel Central (Jucá 2.0)", version: "1.0.0" };
const FALLBACK_PROTOCOL = "2025-06-18";

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-api-key, content-type, mcp-protocol-version, mcp-method, mcp-name, mcp-session-id, accept",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function httpJson(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
function rpcOk(id: unknown, result: unknown): Response {
  return httpJson({ jsonrpc: "2.0", id, result });
}
function rpcErr(id: unknown, code: number, message: string, status = 200): Response {
  return httpJson({ jsonrpc: "2.0", id, error: { code, message } }, status);
}

// Comparação em tempo constante: não vaza o token por diferença de tempo.
function tokensBatem(a: string, b: string): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
function autorizado(req: Request): boolean {
  if (!MCP_TOKEN) return false; // sem secret configurado, ninguém entra
  const auth = req.headers.get("authorization") || "";
  const bearer = auth.replace(/^Bearer\s+/i, "").trim();
  const apiKey = (req.headers.get("x-api-key") || "").trim();
  return tokensBatem(bearer, MCP_TOKEN) || tokensBatem(apiKey, MCP_TOKEN);
}

// ---------------------------------------------------------------- PostgREST
// Toda leitura/alteração passa por aqui com owner=eq.OWNER_UID grudado na URL —
// a service role ignora RLS, então este filtro é a ÚNICA coisa que impede o
// servidor de tocar em linha de outro dono. No POST (insert) filtro não se
// aplica: lá o dono vai explícito no corpo (`owner: OWNER_UID`).
async function db(method: string, path: string, body?: unknown, prefer?: string): Promise<any> {
  const escopo = method === "POST" ? "" : `${path.includes("?") ? "&" : "?"}owner=eq.${encodeURIComponent(OWNER_UID)}`;
  const url = `${SUPABASE_URL}/rest/v1/${path}${escopo}`;
  const headers: Record<string, string> = {
    apikey: SERVICE_KEY,
    Authorization: `Bearer ${SERVICE_KEY}`,
    "Content-Type": "application/json",
  };
  if (prefer) headers["Prefer"] = prefer;
  const r = await fetch(url, { method, headers, body: body != null ? JSON.stringify(body) : undefined });
  const txt = await r.text();
  if (!r.ok) throw new Error(`Supabase ${r.status}: ${txt.slice(0, 300)}`);
  return txt ? JSON.parse(txt) : null;
}

// Texto é o formato que o modelo lê melhor; devolvemos linhas legíveis, não JSON cru.
function texto(s: string) {
  return { content: [{ type: "text", text: s }] };
}
function erroTool(msg: string) {
  return { content: [{ type: "text", text: `Erro: ${msg}` }], isError: true };
}
function precisaConfirmar(o: string) {
  return texto(
    `Nada foi alterado — falta confirmação.\n\nEsta ação ${o}. Reenvie a mesma chamada com "confirmar": true depois de o Gustavo dizer que pode.`,
  );
}

// ------------------------------------------------------------------- TOOLS
const STATUS_PROJETO = ["ativo", "pausado", "concluido"];
const CATEGORIAS_CONTATO = ["cliente", "lead", "fornecedor", "equipe", "pessoal", "outro"];
const DESTINOS_INBOX = ["tarefa", "insight", "referencia", "arquivo"]; // bate o CHECK da painel_inbox

const TOOLS = [
  {
    name: "painel_resumo",
    title: "Resumo do Painel",
    description:
      "Visão geral do Painel Central do Gustavo: quantos projetos por status, quantos contatos por categoria e quantas capturas triadas no Inbox por destino. Use como primeira chamada quando ele perguntar algo amplo ('como estão minhas coisas?', 'o que tenho em aberto?') pra saber onde procurar. NÃO cobre agenda nem tarefas do Google Tasks — essas vivem no Google, não neste servidor.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
    annotations: { readOnlyHint: true, title: "Resumo do Painel" },
  },
  {
    name: "painel_listar_projetos",
    title: "Listar projetos",
    description:
      "Lista os projetos do Gustavo com status (ativo/pausado/concluido), descrição e link (repo, chat, doc). Cada projeto corresponde a uma lista do Google Tasks; aqui vêm os metadados que o Google não guarda. As TAREFAS de cada projeto não estão neste servidor.",
    inputSchema: {
      type: "object",
      properties: {
        status: { type: "string", enum: STATUS_PROJETO, description: "Filtra por status. Omita pra trazer todos." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, title: "Listar projetos" },
  },
  {
    name: "painel_listar_contatos",
    title: "Buscar contatos",
    description:
      "Busca na base de contatos do Gustavo (nome, telefone/WhatsApp, empresa, email, categoria, notas). Use quando ele pedir o contato/telefone de alguém ou quiser ver quem está numa categoria.",
    inputSchema: {
      type: "object",
      properties: {
        busca: { type: "string", description: "Texto livre — casa com nome, empresa/relação ou email." },
        categoria: { type: "string", enum: CATEGORIAS_CONTATO, description: "Filtra por categoria." },
        limite: { type: "integer", minimum: 1, maximum: 100, description: "Máximo de contatos (padrão 30)." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, title: "Buscar contatos" },
  },
  {
    name: "painel_listar_inbox",
    title: "Listar Inbox triado",
    description:
      "Lista as capturas que o Gustavo já triou no Inbox do Painel, por destino: tarefa, insight, referencia ou arquivo. Use quando ele perguntar 'o que eu salvei sobre X', 'quais insights eu guardei', 'minhas referências'.",
    inputSchema: {
      type: "object",
      properties: {
        destino: { type: "string", enum: DESTINOS_INBOX, description: "Filtra por destino. Omita pra trazer todos menos os arquivados." },
        limite: { type: "integer", minimum: 1, maximum: 100, description: "Máximo de itens (padrão 30)." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: true, title: "Listar Inbox" },
  },
  {
    name: "painel_atualizar_projeto",
    title: "Atualizar projeto",
    description:
      "Altera status, descrição e/ou link de um projeto existente. ESCRITA: só execute depois de o Gustavo confirmar, e mande confirmar: true. Chame painel_listar_projetos antes pra pegar o list_id certo — nunca invente um.",
    inputSchema: {
      type: "object",
      properties: {
        list_id: { type: "string", description: "Id da lista do Google Tasks (vem do painel_listar_projetos)." },
        status: { type: "string", enum: STATUS_PROJETO },
        descricao: { type: "string", description: "Nova descrição. Mande string vazia pra limpar." },
        link: { type: "string", description: "Novo link. Mande string vazia pra limpar." },
        confirmar: { type: "boolean", description: "Precisa ser true. O Gustavo tem que ter confirmado a mudança." },
      },
      required: ["list_id"],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, title: "Atualizar projeto" },
  },
  {
    name: "painel_salvar_contato",
    title: "Salvar contato",
    description:
      "Cria um contato novo, ou atualiza um existente se vier o id. ESCRITA: só execute depois de o Gustavo confirmar, e mande confirmar: true. Antes de criar, busque com painel_listar_contatos pra não duplicar alguém que já existe.",
    inputSchema: {
      type: "object",
      properties: {
        id: { type: "string", description: "Id do contato a atualizar. Omita pra criar um novo." },
        nome: { type: "string", description: "Obrigatório ao criar." },
        telefone: { type: "string", description: "Telefone/WhatsApp." },
        categoria: { type: "string", enum: CATEGORIAS_CONTATO },
        relacao: { type: "string", description: "Empresa ou como o Gustavo conhece a pessoa." },
        email: { type: "string" },
        notas: { type: "string" },
        confirmar: { type: "boolean", description: "Precisa ser true." },
      },
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, title: "Salvar contato" },
  },
  {
    name: "painel_capturar",
    title: "Capturar no Inbox",
    description:
      "Guarda algo no Inbox do Painel já triado — uma referência, um insight ou uma tarefa que surgiu na conversa. ESCRITA: só execute depois de o Gustavo confirmar, e mande confirmar: true. Aparece pra ele no módulo Inbox do app.",
    inputSchema: {
      type: "object",
      properties: {
        texto: { type: "string", description: "O conteúdo da captura, do jeito que ele vai querer reler depois." },
        destino: { type: "string", enum: DESTINOS_INBOX, description: "Onde arquivar (padrão: referencia)." },
        confirmar: { type: "boolean", description: "Precisa ser true." },
      },
      required: ["texto"],
      additionalProperties: false,
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, title: "Capturar no Inbox" },
  },
];

// ------------------------------------------------------------ implementação
function fmtProjeto(p: any): string {
  const nome = p.nome || `(sem nome — list_id ${p.list_id})`;
  const partes = [`• ${nome} [${p.status || "ativo"}]`];
  if (p.descricao) partes.push(`  ${p.descricao}`);
  if (p.link) partes.push(`  link: ${p.link}`);
  partes.push(`  list_id: ${p.list_id}`);
  return partes.join("\n");
}
function fmtContato(c: any): string {
  const extra = [c.relacao, c.email].filter(Boolean).join(" · ");
  return `• ${c.nome} [${c.categoria || "outro"}]${c.telefone ? ` — ${c.telefone}` : ""}${extra ? ` (${extra})` : ""}${c.notas ? `\n  notas: ${c.notas}` : ""}\n  id: ${c.id}`;
}
function fmtInbox(i: any): string {
  const quando = (i.triado_em || i.created_at || "").slice(0, 10);
  const feito = i.destino === "tarefa" && i.status === "feito" ? " ✅" : "";
  const corpo = i.corpo && i.corpo !== i.titulo ? `\n  ${String(i.corpo).slice(0, 300)}` : "";
  return `• [${i.destino}]${feito} ${String(i.titulo || "(sem título)").slice(0, 200)}${quando ? ` — ${quando}` : ""}${corpo}`;
}

async function chamarTool(nome: string, args: any) {
  switch (nome) {
    case "painel_resumo": {
      const [projetos, contatos, inbox] = await Promise.all([
        db("GET", "painel_projetos?select=status,nome"),
        db("GET", "painel_contatos?select=categoria"),
        db("GET", "painel_inbox?select=destino"),
      ]);
      const conta = (rows: any[], campo: string) => {
        const m: Record<string, number> = {};
        for (const r of rows || []) {
          const k = r[campo] || "(vazio)";
          m[k] = (m[k] || 0) + 1;
        }
        return Object.entries(m).map(([k, v]) => `${k}: ${v}`).join(" · ") || "nenhum";
      };
      return texto(
        [
          "PAINEL CENTRAL — resumo",
          "",
          `Projetos (${(projetos || []).length}) — ${conta(projetos, "status")}`,
          `Contatos (${(contatos || []).length}) — ${conta(contatos, "categoria")}`,
          `Inbox triado (${(inbox || []).length}) — ${conta(inbox, "destino")}`,
          "",
          "Obs.: agenda e tarefas do Google Tasks não passam por este servidor (ficam na conta Google do Gustavo).",
        ].join("\n"),
      );
    }

    case "painel_listar_projetos": {
      let q = "painel_projetos?select=list_id,nome,status,descricao,link&order=status.asc,nome.asc";
      if (args?.status) q += `&status=eq.${encodeURIComponent(args.status)}`;
      const rows = await db("GET", q);
      if (!rows?.length) return texto("Nenhum projeto encontrado com esse filtro.");
      return texto(`${rows.length} projeto(s):\n\n${rows.map(fmtProjeto).join("\n\n")}`);
    }

    case "painel_listar_contatos": {
      const limite = Math.min(Math.max(args?.limite || 30, 1), 100);
      let q = `painel_contatos?select=id,nome,telefone,categoria,relacao,email,notas&order=nome.asc&limit=${limite}`;
      if (args?.categoria) q += `&categoria=eq.${encodeURIComponent(args.categoria)}`;
      if (args?.busca) {
        // PostgREST: vírgula separa os OR; escapa vírgula/parêntese pra não quebrar o filtro.
        const t = String(args.busca).replace(/[(),]/g, " ").trim();
        if (t) q += `&or=(nome.ilike.*${encodeURIComponent(t)}*,relacao.ilike.*${encodeURIComponent(t)}*,email.ilike.*${encodeURIComponent(t)}*)`;
      }
      const rows = await db("GET", q);
      if (!rows?.length) return texto("Nenhum contato encontrado com esse filtro.");
      return texto(`${rows.length} contato(s):\n\n${rows.map(fmtContato).join("\n\n")}`);
    }

    case "painel_listar_inbox": {
      const limite = Math.min(Math.max(args?.limite || 30, 1), 100);
      let q = `painel_inbox?select=id,destino,titulo,corpo,status,triado_em&order=triado_em.desc&limit=${limite}`;
      if (args?.destino) q += `&destino=eq.${encodeURIComponent(args.destino)}`;
      else q += `&destino=neq.arquivo`;
      const rows = await db("GET", q);
      if (!rows?.length) return texto("Nada no Inbox com esse filtro.");
      return texto(`${rows.length} item(ns):\n\n${rows.map(fmtInbox).join("\n")}`);
    }

    case "painel_atualizar_projeto": {
      if (!args?.confirmar) return precisaConfirmar("altera um projeto do Painel");
      if (!args?.list_id) return erroTool("falta o list_id — pegue com painel_listar_projetos.");
      const atual = await db("GET", `painel_projetos?select=*&list_id=eq.${encodeURIComponent(args.list_id)}`);
      if (!atual?.length) return erroTool(`projeto ${args.list_id} não existe no Painel. Liste os projetos e use um list_id de verdade.`);
      const patch: Record<string, unknown> = {};
      if (args.status) patch.status = args.status;
      if (typeof args.descricao === "string") patch.descricao = args.descricao.trim() || null;
      if (typeof args.link === "string") patch.link = args.link.trim() || null;
      if (!Object.keys(patch).length) return erroTool("nada pra mudar — mande status, descricao ou link.");
      await db("PATCH", `painel_projetos?list_id=eq.${encodeURIComponent(args.list_id)}`, patch, "return=minimal");
      const depois = await db("GET", `painel_projetos?select=list_id,nome,status,descricao,link&list_id=eq.${encodeURIComponent(args.list_id)}`);
      return texto(`Projeto atualizado ✓\n\n${fmtProjeto(depois[0])}`);
    }

    case "painel_salvar_contato": {
      if (!args?.confirmar) return precisaConfirmar(args?.id ? "altera um contato do Gustavo" : "cria um contato novo na base do Gustavo");
      const campos = ["nome", "telefone", "categoria", "relacao", "email", "notas"];
      const body: Record<string, unknown> = {};
      for (const c of campos) if (typeof args[c] === "string") body[c] = args[c].trim() || null;
      if (args.id) {
        const existe = await db("GET", `painel_contatos?select=id&id=eq.${encodeURIComponent(args.id)}`);
        if (!existe?.length) return erroTool(`contato ${args.id} não existe.`);
        if (!Object.keys(body).length) return erroTool("nada pra mudar.");
        await db("PATCH", `painel_contatos?id=eq.${encodeURIComponent(args.id)}`, body, "return=minimal");
        const d = await db("GET", `painel_contatos?select=*&id=eq.${encodeURIComponent(args.id)}`);
        return texto(`Contato atualizado ✓\n\n${fmtContato(d[0])}`);
      }
      if (!body.nome) return erroTool("pra criar um contato o nome é obrigatório.");
      if (!body.categoria) body.categoria = "outro";
      body.owner = OWNER_UID; // service role não tem auth.uid(): o default da coluna não resolve
      const criado = await db("POST", "painel_contatos?select=*", body, "return=representation");
      return texto(`Contato criado ✓\n\n${fmtContato(Array.isArray(criado) ? criado[0] : criado)}`);
    }

    case "painel_capturar": {
      if (!args?.confirmar) return precisaConfirmar("grava uma captura no Inbox do Painel");
      const txt = String(args?.texto || "").trim();
      if (!txt) return erroTool("texto vazio.");
      const destino = DESTINOS_INBOX.includes(args?.destino) ? args.destino : "referencia";
      const body = {
        owner: OWNER_UID,          // service role não tem auth.uid(): o default da coluna não resolve
        fonte: "manual",           // o CHECK só aceita email|dump|manual
        ext_id: `mcp:${crypto.randomUUID()}`, // dedupe é por (owner, ext_id): o prefixo marca a origem
        destino,
        titulo: txt.slice(0, 120),
        corpo: txt.length > 120 ? txt : null,
        nota: "capturado pelo Claude via MCP",
      };
      await db("POST", "painel_inbox", body, "return=minimal");
      return texto(`Capturado no Inbox como "${destino}" ✓\n\n${txt.slice(0, 300)}`);
    }
  }
  return erroTool(`ferramenta desconhecida: ${nome}`);
}

// ------------------------------------------------------------------ JSON-RPC
async function tratar(msg: any): Promise<Response | null> {
  const { id, method, params } = msg || {};

  if (method === "initialize") {
    // Eco do protocolVersion pedido: aceita clientes de 2025-03-26 a 2026-07-28.
    const pedida = params?.protocolVersion || params?._meta?.["io.modelcontextprotocol/protocolVersion"];
    return rpcOk(id, {
      protocolVersion: pedida || FALLBACK_PROTOCOL,
      capabilities: { tools: { listChanged: false } },
      serverInfo: SERVER_INFO,
      instructions:
        "Painel Central do Gustavo Jucá. Ferramentas de LEITURA podem ser usadas à vontade. As de ESCRITA (atualizar projeto, salvar contato, capturar no Inbox) só depois de ele confirmar explicitamente, e com confirmar: true. Agenda e Google Tasks NÃO estão aqui.",
    });
  }
  if (method === "notifications/initialized" || method?.startsWith?.("notifications/")) {
    return new Response(null, { status: 202, headers: CORS });
  }
  if (method === "ping") return rpcOk(id, {});
  if (method === "tools/list") return rpcOk(id, { tools: TOOLS });
  if (method === "resources/list") return rpcOk(id, { resources: [] });
  if (method === "prompts/list") return rpcOk(id, { prompts: [] });

  if (method === "tools/call") {
    const nome = params?.name;
    try {
      return rpcOk(id, await chamarTool(nome, params?.arguments || {}));
    } catch (e) {
      // Erro de execução vai como resultado isError (o modelo consegue reagir),
      // não como erro de protocolo.
      return rpcOk(id, erroTool(String((e as Error)?.message || e).slice(0, 400)));
    }
  }
  return rpcErr(id, -32601, `Method not found: ${method}`, 404);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") {
    // Revisão 2026-07-28: sem stream GET, sem sessão pra deletar.
    return rpcErr(null, -32601, "Só POST — este servidor fala Streamable HTTP sem stream GET.", 405);
  }
  if (!MCP_TOKEN || !OWNER_UID || !SERVICE_KEY) {
    return rpcErr(null, -32603, "Servidor mal configurado: faltam os secrets MCP_TOKEN / OWNER_UID.", 500);
  }
  if (!autorizado(req)) {
    return new Response(JSON.stringify({ jsonrpc: "2.0", id: null, error: { code: -32001, message: "Não autorizado" } }), {
      status: 401,
      headers: { ...CORS, "Content-Type": "application/json", "WWW-Authenticate": "Bearer" },
    });
  }
  let msg: any;
  try {
    msg = await req.json();
  } catch {
    return rpcErr(null, -32700, "JSON inválido", 400);
  }
  // Lote (array) não é usado pelos clientes atuais, mas responder direito é barato.
  if (Array.isArray(msg)) {
    const saidas: unknown[] = [];
    for (const m of msg) {
      const r = await tratar(m);
      if (r) {
        const t = await r.text();
        if (t) saidas.push(JSON.parse(t));
      }
    }
    return httpJson(saidas);
  }
  return (await tratar(msg)) ?? new Response(null, { status: 202, headers: CORS });
});

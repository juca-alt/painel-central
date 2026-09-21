// E2E da aba Adega (Playwright + Chromium local). Sem rede externa: Supabase é stubado.
// Roda: node tests/adega.e2e.mjs
import { createRequire } from 'node:module';
const req = createRequire(import.meta.url);
let pw; try { pw = req('playwright'); } catch { pw = req('/opt/node22/lib/node_modules/playwright'); }
const { chromium } = pw;
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MIME = { '.html':'text/html', '.js':'text/javascript', '.json':'application/json', '.png':'image/png' };
const srv = http.createServer((req, res) => {
  let f = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  if (f.endsWith('/')) f += 'index.html';
  fs.readFile(f, (e, b) => { if (e) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); res.end(b); });
});
await new Promise(r => srv.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${srv.address().port}/index.html`;

const SEED = [
  { id:'a1', vinho:'Cousiño-Macul Don Luis, Sauvignon Blanc 2025', produtor:'Cousiño-Macul, Vale do Maipo (Chile)', uva:'Sauvignon Blanc, sem barrica', safra:'2025', nota:3, harmonizacoes:'Cabra fresco, coalho grelhado', custo_medio:null, ocasiao:'Dia a dia', repetir:'Talvez', notas:'Linha de entrada, 12,5%.', data:'2026-09-19', created_at:'2026-09-21T00:00:00Z' },
  { id:'a2', vinho:'Casas del Toqui, Semillon Barrel Series', produtor:'Casas del Toqui, Vale do Cachapoal (Chile)', uva:'Semillon, com barrica de carvalho', safra:null, nota:4, harmonizacoes:'Camarão + bisque de coco', custo_medio:180, ocasiao:'Especial/Camila', repetir:'Sim', notas:'Ariano com Camila.', data:'2026-06-10', created_at:'2026-09-21T00:00:00Z' },
  { id:'a3', vinho:'Vinho Teste Presente', produtor:'X', uva:'Malbec', safra:'2022', nota:5, harmonizacoes:'', custo_medio:95.5, ocasiao:'Presente', repetir:'Sim', notas:'', data:'2026-08-01', created_at:'2026-09-21T00:00:00Z' },
];
let rows = SEED.map(r => ({ ...r }));
const writes = [];

let fails = 0;
const ok = (c, m) => { console.log((c ? '  ✓ ' : '  ✗ ') + m); if (!c) fails++; };

const browser = await chromium.launch();
async function run(viewport, label) {
  console.log(`\n[${label} ${viewport.width}px]`);
  const ctx = await browser.newContext({ viewport, hasTouch: viewport.width < 880, serviceWorkers: 'block' }); // SW fora: o stub do Supabase precisa ver toda requisição
  const errors = [];
  const page = await ctx.newPage();
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.route('**/*', async route => {
    const u = route.request().url();
    if (u.startsWith(base.replace('/index.html', ''))) return route.continue();
    const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*', 'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE,OPTIONS' };
    const m = route.request().method();
    if (m === 'OPTIONS') return route.fulfill({ status: 204, headers: CORS, body: '' });
    if (u.includes('/auth/v1/user')) return route.fulfill({ headers: CORS, json: { id: '11111111-1111-1111-1111-111111111111', email: 'juca@segurocomjuca.com' } });
    if (u.includes('/rest/v1/painel_adega')) {
      if (m === 'GET') return route.fulfill({ headers: CORS, json: rows });
      if (m === 'POST') { const b = route.request().postDataJSON(); writes.push({ m, b }); rows.push({ id: 'n' + rows.length, created_at: '2026-09-22T00:00:00Z', ...b }); return route.fulfill({ status: 201, headers: CORS, body: '' }); }
      if (m === 'PATCH') { const b = route.request().postDataJSON(); writes.push({ m, b, u }); return route.fulfill({ status: 204, headers: CORS, body: '' }); }
      if (m === 'DELETE') { writes.push({ m, u }); return route.fulfill({ status: 204, headers: CORS, body: '' }); }
    }
    if (u.includes('/rest/v1/')) return route.fulfill({ headers: CORS, json: [] });
    return route.abort(); // Google, CDN etc. — fora do escopo
  });
  await page.addInitScript(() => {
    localStorage.setItem('painel_sb_session', JSON.stringify({ access_token: 'fake', refresh_token: '', user: { id: '11111111-1111-1111-1111-111111111111', email: 'juca@segurocomjuca.com' } }));
  });
  await page.goto(base, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => nav('adega'));
  await page.waitForSelector('#view-adega .g-row');

  // 1) aba renderiza, nav ativo, os 2 vinhos do Notion aparecem
  ok(await page.isVisible('#view-adega'), 'view-adega visível');
  ok(await page.$eval('#nav-adega', e => e.classList.contains('active')), 'nav-adega ativo');
  let names = await page.$$eval('#view-adega .g-row .g-pri', els => els.map(e => e.textContent));
  ok(names.length === 3, `lista com ${names.length} vinhos`);
  ok(names.some(n => n.includes('Cousiño-Macul Don Luis')), 'Cousiño-Macul Don Luis na lista');
  ok(names.some(n => n.includes('Casas del Toqui')), 'Casas del Toqui Semillon na lista');
  ok(names[0].includes('Cousiño'), 'ordenado por data desc (mais recente 1º)');
  ok((await page.textContent('#view-adega')).includes('★★★★☆'), 'estrelas ★★★★☆ do Toqui');
  ok((await page.textContent('#view-adega')).includes('Harmoniza:'), 'harmonizações visíveis');
  ok((await page.textContent('#view-adega')).includes('Vale do Maipo'), 'produtor visível');

  // 2) KPI de custo: últimos 5 com custo = (180 + 95.5)/2 = 137,75 ; total 275,50
  const medio = await page.textContent('#ad-k-medio');
  ok(medio.replace(/\s/g, ' ').includes('137,75'), `gasto médio últimos = ${medio}`);
  const total = await page.textContent('#ad-k-total');
  ok(total.includes('275,50'), `gasto total = ${total}`);

  // 3) filtro por Ocasião
  await page.click('#ad-f-oc .g-pill[data-v="Especial/Camila"]');
  names = await page.$$eval('#view-adega .g-row .g-pri', els => els.map(e => e.textContent));
  ok(names.length === 1 && names[0].includes('Toqui'), 'filtro Ocasião=Especial/Camila → só o Toqui');
  await page.click('#ad-f-oc .g-pill[data-v="todos"]');
  // 4) filtro por Repetir?
  await page.click('#ad-f-rep .g-pill[data-v="Sim"]');
  names = await page.$$eval('#view-adega .g-row .g-pri', els => els.map(e => e.textContent));
  ok(names.length === 2 && !names.some(n => n.includes('Cousiño')), 'filtro Repetir=Sim → 2 (sem o Cousiño)');
  // 5) combinação dos dois filtros
  await page.click('#ad-f-oc .g-pill[data-v="Presente"]');
  names = await page.$$eval('#view-adega .g-row .g-pri', els => els.map(e => e.textContent));
  ok(names.length === 1 && names[0].includes('Presente'), 'Ocasião=Presente + Repetir=Sim → 1');
  await page.click('#ad-f-oc .g-pill[data-v="todos"]'); await page.click('#ad-f-rep .g-pill[data-v="todos"]');

  // 6) novo vinho → POST com os campos certos (nota inteira, custo numérico)
  await page.click('#view-adega .btn.primary');
  await page.waitForSelector('#ad-modal-bg');
  await page.fill('#ad-f-vinho', 'Teste E2E Tannat');
  await page.selectOption('#ad-f-nota', '5');
  await page.fill('#ad-f-custo_medio', '120,5'.replace(',', '.'));
  await page.selectOption('#ad-f-ocasiao', 'Jantar fora');
  await page.selectOption('#ad-f-repetir', 'Sim');
  await page.click('#ad-modal-bg .btn.primary');
  await page.waitForFunction(() => document.querySelectorAll('#view-adega .g-row').length === 4);
  const w = writes.find(x => x.m === 'POST');
  ok(w && w.b.vinho === 'Teste E2E Tannat' && w.b.nota === 5 && w.b.custo_medio === 120.5 && w.b.ocasiao === 'Jantar fora' && w.b.repetir === 'Sim', 'POST painel_adega com {vinho,nota:5,custo_medio:120.5,ocasiao,repetir}');
  ok(!('id' in w.b) && !('owner' in w.b), 'POST não manda id/owner (defaults do banco)');
  ok(await page.$('#ad-modal-bg') === null, 'modal fecha após salvar');

  // 7) layout: sem overflow horizontal + chrome certo por mídia
  const over = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
  ok(!over, 'sem overflow horizontal');
  if (viewport.width < 880) {
    ok(await page.$eval('#view-adega .g-right', e => getComputedStyle(e).flexDirection === 'row'), 'mobile: custo + ações em linha');
  } else {
    ok(await page.$eval('.side', e => getComputedStyle(e).display !== 'none'), 'desktop: sidebar visível');
  }
  // 8) console limpo (ignora falhas de rede das APIs abortadas de propósito)
  const real = errors.filter(e => !/ERR_FAILED|Failed to load resource|net::|Failed to fetch|NetworkError|ServiceWorker|sw\.js/i.test(e));
  ok(real.length === 0, 'console sem erros' + (real.length ? ': ' + real.join(' | ') : ''));
  await page.screenshot({ path: `/tmp/claude-0/-home-user-painel-central/c22fc18f-371c-571c-8eaa-606fcf6abb12/scratchpad/adega-${viewport.width}.png`, fullPage: true });
  await ctx.close();
  rows = SEED.map(r => ({ ...r })); writes.length = 0;
}
await run({ width: 390, height: 844 }, 'mobile');
await run({ width: 1280, height: 800 }, 'desktop');
await browser.close(); srv.close();
console.log(fails ? `\n${fails} FALHA(S)` : '\nE2E OK');
process.exit(fails ? 1 : 0);

// Unit da lógica pura da Adega (agregação de custo, estrelas, leitura do form) — sem browser.
// Roda: node tests/adega.unit.mjs   (carrega o IIFE ADEGA do index.html num contexto mínimo)
import fs from 'node:fs'; import vm from 'node:vm'; import path from 'node:path'; import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
const m = html.match(/var ADEGA=\(function\(\)\{[\s\S]*?\n\}\)\(\);/);
assert(m, 'IIFE ADEGA encontrado no index.html');
const ctx = { $: () => null, esc: s => String(s ?? ''), hbrl: n => 'R$ ' + Number(n).toFixed(2).replace('.', ','), isoLocal: () => '2026-09-21', SB: {}, toast(){}, confirm: () => false, document: {}, console };
vm.createContext(ctx); vm.runInContext(m[0], ctx);
const A = ctx.ADEGA;

// agg: últimos 5 com custo, ignora null, total, nota média, repetir
const rows = [
  { custo_medio: 100, nota: 4, repetir: 'Sim', data: '2026-09-06' },
  { custo_medio: null, nota: 3, repetir: 'Talvez', data: '2026-09-05' },
  { custo_medio: 50, nota: 5, repetir: 'Sim', data: '2026-09-04' },
  { custo_medio: 70, nota: null, repetir: 'Não', data: '2026-09-03' },
  { custo_medio: 80, nota: 2, repetir: 'Sim', data: '2026-09-02' },
  { custo_medio: 90, nota: 4, repetir: 'Não', data: '2026-09-01' },
  { custo_medio: 999, nota: 1, repetir: 'Não', data: '2025-01-01' }, // 6º com custo → fora dos "últimos 5"
];
const a = A.agg(rows, 5);
assert.equal(a.n, 7); assert.equal(a.ultN, 5);
assert.equal(a.medioUlt, (100 + 50 + 70 + 80 + 90) / 5);
assert.equal(a.total, 100 + 50 + 70 + 80 + 90 + 999); assert.equal(a.comCusto, 6);
assert.equal(a.notaMedia, (4 + 3 + 5 + 2 + 4 + 1) / 6); assert.equal(a.repetir, 3);
const z = A.agg([], 5); assert.equal(z.medioUlt, 0); assert.equal(z.ultN, 0); assert.equal(z.total, 0);
console.log('  ✓ agg: média dos últimos 5 com custo, total, nota média, repetir');

// stars
assert.equal(A.stars(4), '★★★★☆'); assert.equal(A.stars(1), '★☆☆☆☆'); assert.equal(A.stars(5), '★★★★★'); assert.equal(A.stars(null), '');
console.log('  ✓ stars 1–5');

// readForm: nota vira inteiro 1–5, custo aceita vírgula, vazio → null
const f = { vinho: 'X', nota: '4', custo_medio: '89,90', ocasiao: '', repetir: 'Sim', safra: '', data: '2026-09-21' };
const b = A.readForm(k => (k in f ? f[k] : null));
assert.equal(b.nota, 4); assert.equal(b.custo_medio, 89.9); assert.equal(b.ocasiao, null); assert.equal(b.safra, null); assert.equal(b.repetir, 'Sim');
assert.equal(A.readForm(k => (k === 'nota' ? '9' : null)).nota, null, 'nota fora de 1–5 → null');
assert.equal(A.readForm(k => (k === 'custo_medio' ? 'abc' : null)).custo_medio, null);
console.log('  ✓ readForm: nota int, custo com vírgula, vazio → null');

// filtered: Ocasião × Repetir e ordenação por data desc
A._setRows([{ id: 1, ocasiao: 'Dia a dia', repetir: 'Sim', data: '2026-01-01' }, { id: 2, ocasiao: 'Presente', repetir: 'Sim', data: '2026-03-01' }, { id: 3, ocasiao: 'Presente', repetir: 'Não', data: '2026-02-01' }]);
assert.deepEqual(A._state().rows.map(r => r.id), [2, 3, 1], 'mais recente primeiro');
assert.equal(A.filtered().length, 3);
A.setFilter('oc', 'Presente'); assert.deepEqual(A.filtered().map(r => r.id), [2, 3]);
A.setFilter('rep', 'Sim'); assert.deepEqual(A.filtered().map(r => r.id), [2]);
A.setFilter('oc', 'todos'); assert.deepEqual(A.filtered().map(r => r.id), [2, 1]);
console.log('  ✓ filtered: Ocasião × Repetir?, ordenação por data');

// 10 campos do Notion presentes no form
const html10 = ['vinho', 'produtor', 'uva', 'safra', 'nota', 'harmonizacoes', 'custo_medio', 'ocasiao', 'repetir', 'notas', 'data'];
for (const k of html10) assert(m[0].includes(`k:'${k}'`), 'campo ' + k);
console.log('  ✓ 11 colunas (10 do Notion + Data) no formulário');
console.log('UNIT OK');

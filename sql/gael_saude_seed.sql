-- ============================================================================
-- GAEL · SAÚDE — SEED da consulta 05/06/2026 (Conecta, Recife-PE). Idempotente.
-- Roda DEPOIS da migration gael_saude.sql.
-- owner vem de subquery (no SQL Editor do Supabase auth.uid() é NULL).
-- PRÉ-CONDIÇÃO: o usuário 'juca@segurocomjuca.com' precisa existir em auth.users
--   (ter logado ao menos 1x no Supabase). Senão owner=NULL e o insert falha
--   (proposital: falha barulhenta em vez de dado órfão).
-- Datas parciais ("abr/26") → dia 01 do mês + granularidade real em notas.
-- ============================================================================

-- 0) CONSULTA-ÂNCORA (chave natural: owner + data + profissional)
insert into public.gael_consultas
  (owner, data, local, profissional, especialidade, motivo,
   resumo_hipoteses, resumo_condutas, proximo_retorno, obs)
select
  (select id from auth.users where email = 'juca@segurocomjuca.com'),
  date '2026-06-05',
  'Conecta — Centro de Atenção à Criança e ao Adolescente (Boa Viagem, Recife-PE)',
  'Dr. Gustavo Almeida', 'Pediatra',
  'Consulta de acompanhamento (eutrofia, rinite/asma, neuro, constipação, enurese)',
  'Rinite/asma descontroladas; arsenal de rinite esgotado; investigar SII + enxaqueca abdominal; avaliar adenoidectomia e imunoterapia.',
  'Ajuste de Seretide (1->2 jatos); troca Allegra->Zyxem; manter Aripiprazol; solicitar exames laboratoriais; sugerir Prick Test e Alergoped/Otorrino.',
  timestamptz '2026-11-27 16:30',
  'Dr. Gustavo Almeida — CRM-PE 22.790 · RQE 11.591.'
where not exists (
  select 1 from public.gael_consultas
  where owner = (select id from auth.users where email = 'juca@segurocomjuca.com')
    and data = date '2026-06-05' and profissional = 'Dr. Gustavo Almeida'
);

-- 1) DIAGNÓSTICOS (bloco TEA quebrado em 4 linhas)
insert into public.gael_diagnosticos
  (owner, condicao, status, identificado_em, profissional, peso_kg, altura_cm, consulta_id, notas)
select k.owner, x.condicao, x.status, k.identificado_em, k.profissional,
       x.peso_kg, x.altura_cm, k.consulta_id, x.notas
from (
  values
  ('Escolar eutrófico','ativo',27.3,130.5,'Peso 27,3 kg / est. 130,5 cm (aferido 05/06/2026).'),
  ('Rinite alérgica persistente moderada-grave + hipertrofia de adenoide (~50%)','descontrolado',null,null,'Arsenal de rinite esgotado; avaliar imunoterapia e adenoidectomia.'),
  ('Asma','descontrolado',null,null,'Seretide aumentado de 1 para 2 jatos.'),
  ('Dermatite atópica + alergia a picada de inseto','ativo',null,null,null),
  ('TEA nível 1 de suporte (sem DI)','ativo',null,null,'Investigação para AH (altas habilidades) em curso.'),
  ('TDAH','controlado',null,null,'Associado ao TEA; controlado com Aripiprazol; avaliar subir p/ 10mg.'),
  ('Depressão','controlado',null,null,'Associada ao quadro neuro; controlada.'),
  ('Altas habilidades (AH)','em_investigacao',null,null,'Investigação a cargo de Neuroped/Psicólogo.'),
  ('Constipação funcional — suspeita de SII + Enxaqueca Abdominal','em_investigacao',null,null,'Confirmar SII + enxaqueca abdominal (Pediatra/Gastro).'),
  ('Enurese diurna e noturna','ativo',null,null,'Avaliar necessidade de medicação (Uropediatra).')
) as x(condicao, status, peso_kg, altura_cm, notas)
cross join lateral (
  select (select id from auth.users where email='juca@segurocomjuca.com') as owner,
         date '2026-06-05' as identificado_em,
         'Dr. Gustavo Almeida' as profissional,
         (select id from public.gael_consultas
            where owner=(select id from auth.users where email='juca@segurocomjuca.com')
              and data=date '2026-06-05' and profissional='Dr. Gustavo Almeida' limit 1) as consulta_id
) k
where not exists (
  select 1 from public.gael_diagnosticos d where d.owner = k.owner and d.condicao = x.condicao
);

-- 2) MEDICAMENTOS  (controlado=true só no Aripiprazol)
insert into public.gael_medicamentos
  (owner, nome, principio_ativo, concentracao, trata, tipo, posologia, via, status,
   controlado, prescrito_por, prescrito_em, consulta_id, obs)
select k.owner, x.nome, x.principio_ativo, x.concentracao, x.trata, x.tipo, x.posologia,
       x.via, x.status, x.controlado, 'Dr. Gustavo Almeida', date '2026-06-05', k.consulta_id, x.obs
from (
  values
  ('Dymista','azelastina + fluticasona',null,'rinite','rotina','2 jatos em cada narina manhã e noite','nasal','em_uso',false,null),
  ('Zyxem','levocetirizina','gotas','rinite','rotina','10 gotas manhã e noite','oral','em_uso',false,'Novo — substituiu Allegra.'),
  ('Seretide','salmeterol + fluticasona','25/125','asma','rotina','2 jatos manhã e noite com espaçador + máscara','inalatória','em_uso',false,'Aumentou de 1 para 2 jatos.'),
  ('Aripiprazol','aripiprazol','10mg','TDAH/TEA','rotina','½ comprimido 1x/dia','oral','em_uso',true,'Controlado (receita azul). Avaliar subir p/ 10mg.'),
  ('PEG 4000 sem eletrólitos','macrogol',null,'constipação','rotina','10g 1x/dia','oral','em_uso',false,null),
  ('Probióticos (manipulado)',null,null,'SII','rotina','contínuo','oral','em_uso',false,'Falta fórmula.'),
  ('Atoderm','Bioderma (hidratante)',null,'dermatite','rotina','após os banhos','tópica','em_uso',false,null),
  ('Lavagem nasal','soro fisiológico',null,'rinite','rotina','>=1x/dia','nasal','em_uso',false,null),
  ('Allegra pediátrico','fexofenadina',null,'crise rinite','crise','10 ml manhã e noite','oral','sos',false,null),
  ('Hixizine','hidroxizina','xarope','rinite','crise','6 ml ao dormir, máx 7 dias','oral','sos',false,null),
  ('Patanol S','olopatadina','colírio','coceira ocular','crise','1 gota até 6/6h','oftálmica','sos',false,null),
  ('Flutinol','fluorometolona','colírio','vermelhidão ocular','crise','1 gota até 6/6h','oftálmica','sos',false,null),
  ('Aerolin','salbutamol',null,'crise asma','crise','8 jatos 4/4h por 2 dias, depois 6/6h por 3 dias','inalatória','sos',false,null),
  ('Atrovent N','ipratrópio',null,'crise asma','crise','mesmo esquema do Aerolin se após 24h não resolver','inalatória','sos',false,null),
  ('Prednisolona','prednisolona','3mg/ml','crise asma/tosse','crise','9 ml 1x/dia por 5 dias','oral','sos',false,null),
  ('Pulmicort','budesonida','0,5mg/ml','tosse laríngea','crise','1 ampola + 2 ml soro, nebulizar manhã e noite por 5-7 dias','nebulização','sos',false,'Confirmar concentração.'),
  ('Luftal','simeticona','75mg/ml','distensão abdominal','crise','28 gotas 6/6h','oral','sos',false,null),
  ('Diprosone','betametasona','pomada','lesões no corpo','crise','2x/dia até 7 dias','tópica','sos',false,null),
  ('Hidrocortisona','hidrocortisona','10mg/g','lesões no rosto','crise','2x/dia até 7 dias','tópica','sos',false,null),
  ('Exposis infantil','repelente (gel)',null,'proteção contra inseto','condicional','quando exposto','tópica','em_uso',false,null),
  ('Avamys','furoato de fluticasona',null,'rinite (preparo Prick Test)','condicional','substitui Dymista no preparo do teste','nasal','suspenso',false,'Só se Prick Test for agendado.')
) as x(nome, principio_ativo, concentracao, trata, tipo, posologia, via, status, controlado, obs)
cross join lateral (
  select (select id from auth.users where email='juca@segurocomjuca.com') as owner,
         (select id from public.gael_consultas
            where owner=(select id from auth.users where email='juca@segurocomjuca.com')
              and data=date '2026-06-05' and profissional='Dr. Gustavo Almeida' limit 1) as consulta_id
) k
where not exists (
  select 1 from public.gael_medicamentos m where m.owner = k.owner and m.nome = x.nome and m.trata = x.trata
);

-- 3) EXAMES
insert into public.gael_exames
  (owner, nome, solicitado_em, solicitante, status, preparo, consulta_id, obs)
select k.owner, x.nome, x.solicitado_em, 'Dr. Gustavo Almeida', x.status, x.preparo, k.consulta_id, x.obs
from (
  values
  ('Exames laboratoriais completos', date '2026-06-05', 'solicitado', null, 'Solicitados nesta consulta.'),
  ('Prick Test', null, 'sugerido', 'Suspender Allegra/Zyxem 1 semana antes e Dymista 2 dias antes.', 'Mapear alergias; preparo substitui Dymista por Avamys.')
) as x(nome, solicitado_em, status, preparo, obs)
cross join lateral (
  select (select id from auth.users where email='juca@segurocomjuca.com') as owner,
         (select id from public.gael_consultas
            where owner=(select id from auth.users where email='juca@segurocomjuca.com')
              and data=date '2026-06-05' and profissional='Dr. Gustavo Almeida' limit 1) as consulta_id
) k
where not exists (select 1 from public.gael_exames e where e.owner = k.owner and e.nome = x.nome);

-- 4) PROFISSIONAIS  (nome NULL onde só há especialidade; datas parciais → dia 01)
insert into public.gael_profissionais
  (owner, nome, especialidade, status, registro_conselho, ultima_consulta, proxima, notas)
select k.owner, x.nome, x.especialidade, x.status, x.registro_conselho, x.ultima_consulta, x.proxima, x.notas
from (
  values
  ('Dr. Gustavo Almeida','Pediatra (Conecta)','atual','CRM-PE 22.790 / RQE 11.591', date '2026-06-05', timestamptz '2026-11-27 16:30','Retorno em 27/11/2026 16:30.'),
  ('Adriana Azoubel','Alergopediatra','sugerido',null,null,null,'Para imunoterapia.'),
  ('Pâmella Marletti','Otorrinopediatra','sugerido',null,null,null,'Avaliar adenoidectomia.'),
  ('Desirreé Louise','Neuropediatra','atual',null, date '2026-04-01', null,'Consulta em abr/2026; acompanhamento semestral.'),
  ('Dr. Adriano Calado','Uropediatra','sugerido',null,null,null,'Para enurese.'),
  (null,'Oftalmopediatra','atual',null, date '2026-06-01', null,'Rotina jun/2026; passa de semestral para anual.'),
  (null,'Odontopediatra','atual',null, date '2025-12-01', null,'Consulta em dez/2025.'),
  (null,'Psicólogo','a_procurar',null,null,null,'Frequência alvo: 2h/semana.'),
  (null,'Psicomotricista','a_procurar',null,null,null,'Frequência alvo: 1h/semana.')
) as x(nome, especialidade, status, registro_conselho, ultima_consulta, proxima, notas)
cross join lateral (
  select (select id from auth.users where email='juca@segurocomjuca.com') as owner
) k
where not exists (
  select 1 from public.gael_profissionais p
  where p.owner = k.owner and p.especialidade = x.especialidade
    and coalesce(p.nome,'') = coalesce(x.nome,'')
);

-- 5) INVESTIGAÇÕES
insert into public.gael_investigacoes
  (owner, tema, origem, status, profissional_alvo, consulta_id, notas)
select k.owner, x.tema, 'consulta', x.status, x.profissional_alvo, k.consulta_id, x.notas
from (
  values
  ('Imunoterapia p/ rinite (arsenal esgotado)','aberto','Alergopediatra',null),
  ('Necessidade de adenoidectomia','aberto','Otorrinopediatra',null),
  ('Prick Test (mapear alergias)','aberto','Alergopediatra','Preparo: suspender Allegra/Zyxem 1 sem e Dymista 2 dias.'),
  ('Aumentar Aripiprazol p/ 10mg','aberto','Pediatra / Neuropediatra',null),
  ('Confirmar SII + Enxaqueca Abdominal','em_investigacao','Pediatra / Gastro',null),
  ('Enurese — precisa de medicação?','aberto','Uropediatra',null),
  ('AH / altas habilidades','aberto','Neuropediatra / Psicólogo',null)
) as x(tema, status, profissional_alvo, notas)
cross join lateral (
  select (select id from auth.users where email='juca@segurocomjuca.com') as owner,
         (select id from public.gael_consultas
            where owner=(select id from auth.users where email='juca@segurocomjuca.com')
              and data=date '2026-06-05' and profissional='Dr. Gustavo Almeida' limit 1) as consulta_id
) k
where not exists (select 1 from public.gael_investigacoes i where i.owner = k.owner and i.tema = x.tema);

-- ============================================================================
-- VERIFICAÇÃO (rodar separado depois)
--   select 'consultas' t, count(*) from public.gael_consultas
--   union all select 'diagnosticos', count(*) from public.gael_diagnosticos
--   union all select 'medicamentos', count(*) from public.gael_medicamentos
--   union all select 'exames', count(*) from public.gael_exames
--   union all select 'profissionais', count(*) from public.gael_profissionais
--   union all select 'investigacoes', count(*) from public.gael_investigacoes;
--   -- esperado: 1 / 10 / 21 / 2 / 9 / 7
-- ============================================================================
-- FIM DO SEED (consulta 05/06/2026)
-- ============================================================================

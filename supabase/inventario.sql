-- Inventário de leitura para identificar o contrato do app antigo.
-- O resultado contém metadados, sem registros de campanhas ou contas.
select
  'coluna' as tipo,
  table_name as objeto,
  column_name as nome,
  udt_name as detalhe
from information_schema.columns
where table_schema = 'public' and left(table_name, 4) = 'rpg_'

union all

select
  'função',
  n.nspname,
  p.proname,
  pg_catalog.oidvectortypes(p.proargtypes)
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and left(p.proname, 4) = 'rpg_'

union all

select
  'política',
  schemaname || '.' || tablename,
  policyname,
  cmd
from pg_catalog.pg_policies
where (schemaname = 'public' and left(tablename, 4) = 'rpg_')
   or (schemaname = 'storage' and tablename = 'objects')

order by tipo, objeto, nome
limit 1000;

-- Contrato público das funções que a primeira versão Flutter vai consumir.
-- A consulta lê apenas catálogos PostgreSQL e não executa nenhuma RPC.
select
  p.proname as funcao,
  pg_catalog.pg_get_function_identity_arguments(p.oid) as argumentos,
  pg_catalog.pg_get_function_result(p.oid) as retorno
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and p.proname in (
    'rpg_app_capabilities', 'rpg_campaign_people', 'rpg_create_campaign',
    'rpg_create_invite', 'rpg_join_campaign_code', 'rpg_read_notebook',
    'rpg_poll_notebook_v3', 'rpg_save_notebook_v3', 'rpg_gm_list_v2',
    'rpg_gm_save_visual'
  )
order by funcao, argumentos;

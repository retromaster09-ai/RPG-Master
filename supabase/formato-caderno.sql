-- Devolve tipos e nomes de campos de entradas, sem títulos, corpos ou IDs.
-- Use após conferir que as chaves dos objetos são nomes de campos.
select
  jsonb_typeof(entries) as formato,
  count(*) as cadernos
from public.rpg_notebooks
group by 1
order by 1;

with registros as (
  select elemento.registro
  from public.rpg_notebooks
  cross join lateral jsonb_array_elements(
    case when jsonb_typeof(entries) = 'array' then entries else '[]'::jsonb end
  ) as elemento(registro)
)
select distinct campo.nome, jsonb_typeof(registro -> campo.nome) as tipo
from registros
cross join lateral jsonb_object_keys(
  case when jsonb_typeof(registro) = 'object' then registro else '{}'::jsonb end
) as campo(nome)
where campo.nome in (
  'id', 'title', 'name', 'body', 'text', 'summary', 'date', 'session',
  'kind', 'type', 'category', 'section', 'confidence', 'status',
  'blocks', 'content', 'description', 'deletedAt'
)
order by campo.nome, tipo;

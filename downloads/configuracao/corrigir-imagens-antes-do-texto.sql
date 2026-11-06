-- Correção: imagens antes do primeiro parágrafo usam a posição -1 no aplicativo.
-- Mantém as regras de acesso, notas, imagens e filas pendentes. Não é necessário refazer a transferência.
begin;
create or replace function rpg_private.valid_notes(p_entries jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare e jsonb; item jsonb; a record; field text; v_len bigint; v_start bigint; v_end bigint;
begin
  if p_entries is null or jsonb_typeof(p_entries)<>'array' or octet_length(p_entries::text)>8388608 or jsonb_array_length(p_entries)>10000 then return false;end if;
  if (select count(*)<>count(distinct v->>'id') from jsonb_array_elements(p_entries) v) then return false;end if;
  for e in select * from jsonb_array_elements(p_entries) loop
    if jsonb_typeof(e)<>'object' or (e->>'id') is null or (e->>'id') !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' then return false;end if;
    foreach field in array array['title','category','body','source','confidence','answer','paper','resolution','priority'] loop
      if jsonb_typeof(e->field) is distinct from 'string' then return false;end if;
    end loop;
    if e->>'category' not in ('Sessão','Personagem','Lugar','Objeto','Investigação','Missão','Carta') then return false;end if;
    foreach field in array array['completed','started'] loop
      if jsonb_typeof(e->field) is distinct from 'boolean' then return false;end if;
    end loop;
    foreach field in array array['dates','history','pictures','steps','bodyMarks','answerMarks'] loop
      if jsonb_typeof(e->field) is distinct from 'array' then return false;end if;
    end loop;
    for item in select * from jsonb_array_elements(e->'history') loop if jsonb_typeof(item)<>'string' then return false;end if;end loop;
    for item in select * from jsonb_array_elements(e->'dates') loop
      if jsonb_typeof(item)<>'string' or (item#>>'{}') !~ '^\d{4}-\d{2}-\d{2}T' then return false;end if;
      perform (item#>>'{}')::timestamptz;
    end loop;
    if e->>'imagePath' is not null and (e->>'imagePath') !~ '^rpg-media:[0-9a-f]{64}$' then return false;end if;
    for item in select * from jsonb_array_elements(e->'pictures') loop
      if jsonb_typeof(item)<>'object' or (item->>'path') is null or (item->>'path') !~ '^rpg-media:[0-9a-f]{64}$' or jsonb_typeof(item->'caption') is distinct from 'string' or jsonb_typeof(item->'afterParagraph') is distinct from 'number' or (item->>'afterParagraph') !~ '^(-1|[0-9]+)$' then return false;end if;
    end loop;
    for item in select * from jsonb_array_elements(e->'steps') loop
      if jsonb_typeof(item->'title') is distinct from 'string' or jsonb_typeof(item->'details') is distinct from 'string' or jsonb_typeof(item->'completed') is distinct from 'boolean' then return false;end if;
    end loop;
    foreach field in array array['thumbLook','pageLook'] loop
      if jsonb_typeof(e->field) is distinct from 'object' then return false;end if;
      if exists(select 1 from jsonb_each(e->field) x where x.key in ('zoom','x','y') and jsonb_typeof(x.value)<>'number') then return false;end if;
    end loop;
    foreach field in array array['bodyMarks','answerMarks'] loop
      select coalesce(sum(case when ascii(c)>65535 then 2 else 1 end),0) into v_len from regexp_split_to_table(case when field='bodyMarks' then e->>'body' else e->>'answer' end,'') c where c<>'';
      for item in select * from jsonb_array_elements(e->field) loop
        if jsonb_typeof(item->'start') is distinct from 'number' or jsonb_typeof(item->'end') is distinct from 'number' or (item->>'start') !~ '^\d+$' or (item->>'end') !~ '^\d+$' or jsonb_typeof(item->'attributes') is distinct from 'object' then return false;end if;
        v_start:=(item->>'start')::bigint;v_end:=(item->>'end')::bigint;
        if v_end<=v_start or v_end>v_len then return false;end if;
        for a in select * from jsonb_each(item->'attributes') loop
          if a.key in ('bold','italic') and jsonb_typeof(a.value)='boolean' then continue;end if;
          if a.key='heading' and a.value::text in ('0','1','2') then continue;end if;
          if a.key='color' and a.value#>>'{}' in ('theme','wine','blue','teal','purple') then continue;end if;
          if a.key='highlight' and a.value#>>'{}' in ('none','gold','rose','mint') then continue;end if;
          return false;
        end loop;
      end loop;
    end loop;
  end loop;
  return true;
exception when others then return false;
end $$;
revoke all on function rpg_private.valid_notes(jsonb) from public,anon,authenticated;

notify pgrst,'reload schema';
commit;

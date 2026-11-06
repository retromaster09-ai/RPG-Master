-- RPG Master 0.9: notas compartilhadas e imagens privadas da campanha.
-- Requer preparar-campanhas.sql. Não envia o caderno local automaticamente.
begin;
create table if not exists public.rpg_notebooks (
  campaign_id uuid primary key references public.rpg_campaigns(id) on delete cascade,
  revision bigint not null default 0 check(revision>=0),
  entries jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  check(jsonb_typeof(entries)='array' and octet_length(entries::text)<=8388608)
);
create table if not exists public.rpg_notebook_versions (
  campaign_id uuid not null references public.rpg_campaigns(id) on delete cascade,
  revision bigint not null,
  entries jsonb not null,
  saved_at timestamptz not null default now(),
  saved_by uuid references auth.users(id) on delete set null,
  primary key(campaign_id,revision)
);
revoke all on public.rpg_notebooks,public.rpg_notebook_versions from public,anon,authenticated;
grant select on public.rpg_notebooks,public.rpg_notebook_versions to authenticated;
alter table public.rpg_notebooks enable row level security;
alter table public.rpg_notebook_versions enable row level security;
drop policy if exists rpg_notes_read on public.rpg_notebooks;
create policy rpg_notes_read on public.rpg_notebooks for select to authenticated using(rpg_private.is_member(campaign_id));
drop policy if exists rpg_versions_read on public.rpg_notebook_versions;
create policy rpg_versions_read on public.rpg_notebook_versions for select to authenticated using(rpg_private.is_member(campaign_id));

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
      if jsonb_typeof(item)<>'object' or (item->>'path') is null or (item->>'path') !~ '^rpg-media:[0-9a-f]{64}$' or jsonb_typeof(item->'caption') is distinct from 'string' or jsonb_typeof(item->'afterParagraph') is distinct from 'number' or (item->>'afterParagraph') !~ '^\d+$' then return false;end if;
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

create or replace function public.rpg_read_notebook(p_campaign uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado à campanha.' using errcode='42501';end if;
 select jsonb_build_object('revision',revision,'entries',entries) into result from public.rpg_notebooks where campaign_id=p_campaign;
 return coalesce(result,jsonb_build_object('revision',0,'entries','[]'::jsonb));
end $$;
-- Return only the revision when unchanged, avoiding repeated downloads of the whole notebook.
create or replace function public.rpg_poll_notebook(p_campaign uuid,p_known bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado à campanha.' using errcode='42501';end if;
 select jsonb_build_object('revision',revision,'entries',case when revision=p_known then null else entries end) into result from public.rpg_notebooks where campaign_id=p_campaign;
 return coalesce(result,jsonb_build_object('revision',0,'entries',case when p_known=0 then null else '[]'::jsonb end));
end $$;
create or replace function public.rpg_save_notebook(p_campaign uuid,p_expected bigint,p_entries jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_revision bigint;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado à campanha.' using errcode='42501';end if;
 if not rpg_private.valid_notes(p_entries) then raise exception 'Formato de notas inválido.' using errcode='22023';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 update public.rpg_notebooks set entries=p_entries,revision=revision+1,updated_at=now(),updated_by=auth.uid() where campaign_id=p_campaign and revision=p_expected returning revision into v_revision;
 if not found then raise exception 'A campanha mudou. Recarregue e preserve as duas versões.' using errcode='40001';end if;
 insert into public.rpg_notebook_versions(campaign_id,revision,entries,saved_by) values(p_campaign,v_revision,p_entries,auth.uid());
 delete from public.rpg_notebook_versions where campaign_id=p_campaign and revision<=v_revision-20;
 return v_revision;
end $$;
revoke all on function public.rpg_read_notebook(uuid),public.rpg_poll_notebook(uuid,bigint),public.rpg_save_notebook(uuid,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.rpg_read_notebook(uuid),public.rpg_poll_notebook(uuid,bigint),public.rpg_save_notebook(uuid,bigint,jsonb) to authenticated;

-- Private, immutable images. Only members of the corresponding campaign can read or add.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('rpg-notes','rpg-notes',false,20971520,array['image/png']) on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create or replace function rpg_private.can_read_image(p_name text) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
 if p_name !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}/[0-9a-f]{64}\.png$' then return false;end if;
 return rpg_private.is_member(split_part(p_name,'/',1)::uuid);
end $$;
revoke all on function rpg_private.can_read_image(text) from public,anon,authenticated;
grant execute on function rpg_private.can_read_image(text) to authenticated;
drop policy if exists rpg_image_read on storage.objects;
create policy rpg_image_read on storage.objects for select to authenticated using(bucket_id='rpg-notes' and rpg_private.can_read_image(name));
drop policy if exists rpg_image_add on storage.objects;
create policy rpg_image_add on storage.objects for insert to authenticated with check(bucket_id='rpg-notes' and rpg_private.can_read_image(name));
notify pgrst,'reload schema';
commit;

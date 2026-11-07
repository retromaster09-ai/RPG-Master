-- RPG Master Set: apresentação e imagens privadas do Roteiro do Mestre.
-- Requer roteiro-do-mestre.sql. Não publica nem transfere notas ou imagens compartilhadas.
begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('rpg-gm-private','rpg-gm-private',false,10485760,array['image/png'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=array['image/png'];

create or replace function rpg_private.gm_image_allowed(p_name text) returns boolean
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or p_name !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}/[0-9a-f]{64}\.png$' then return false;end if;
 return exists(select 1 from public.rpg_campaigns where id=split_part(p_name,'/',1)::uuid and created_by=auth.uid());
end $$;
revoke all on function rpg_private.gm_image_allowed(text) from public,anon,authenticated;
grant execute on function rpg_private.gm_image_allowed(text) to authenticated;
drop policy if exists rpg_gm_image_read on storage.objects;
create policy rpg_gm_image_read on storage.objects for select to authenticated using(bucket_id='rpg-gm-private' and rpg_private.gm_image_allowed(name));
drop policy if exists rpg_gm_image_add on storage.objects;
create policy rpg_gm_image_add on storage.objects for insert to authenticated with check(bucket_id='rpg-gm-private' and rpg_private.gm_image_allowed(name));

create or replace function rpg_private.valid_gm_presentation(p jsonb,body_length integer) returns boolean
language plpgsql immutable set search_path='' as $$
declare m jsonb; pic jsonb; a record; look jsonb;
begin
 if p is null or jsonb_typeof(p)<>'object' or octet_length(p::text)>131072 then return false;end if;
 if p='{}'::jsonb then return true;end if;
 if not (p ?& array['paper','marks','cover','coverLook','pictures']) then return false;end if;
 if p->>'paper' not in ('Pergaminho','Diário de Baróvia','Futurista','Leitura simples') or jsonb_typeof(p->'paper') is distinct from 'string' then return false;end if;
 if jsonb_typeof(p->'marks') is distinct from 'array' or jsonb_array_length(p->'marks')>1500 then return false;end if;
 for m in select * from jsonb_array_elements(p->'marks') loop
  if jsonb_typeof(m->'start') is distinct from 'number' or jsonb_typeof(m->'end') is distinct from 'number' or (m->>'start')::integer<0 or (m->>'end')::integer<=(m->>'start')::integer or (m->>'end')::integer>body_length or jsonb_typeof(m->'attributes') is distinct from 'object' then return false;end if;
  for a in select * from jsonb_each(m->'attributes') loop
   if a.key in ('bold','italic') then if jsonb_typeof(a.value)<>'boolean' then return false;end if;
   elsif a.key='color' then if jsonb_typeof(a.value) is distinct from 'string' or a.value#>>'{}' not in ('theme','wine','blue','teal','purple') then return false;end if;
   elsif a.key='highlight' then if jsonb_typeof(a.value) is distinct from 'string' or a.value#>>'{}' not in ('none','gold','rose','mint') then return false;end if;
   elsif a.key='heading' then if jsonb_typeof(a.value) is distinct from 'number' or a.value#>>'{}' not in ('0','1','2') then return false;end if;
   else return false;end if;
  end loop;
 end loop;
 if p->'cover'<>'null'::jsonb and (jsonb_typeof(p->'cover') is distinct from 'string' or p->>'cover' !~ '^[0-9a-f]{64}$') then return false;end if;
 look:=p->'coverLook';
 if not (look ?& array['shape','fill','border','zoom','x','y']) then return false;end if;
 if jsonb_typeof(look) is distinct from 'object' or look->>'shape' not in ('rounded','rectangle','square','circle') or jsonb_typeof(look->'fill') is distinct from 'boolean' or jsonb_typeof(look->'border') is distinct from 'boolean' then return false;end if;
 if jsonb_typeof(look->'zoom') is distinct from 'number' or (look->>'zoom')::numeric not between 1 and 3 or jsonb_typeof(look->'x') is distinct from 'number' or (look->>'x')::numeric not between -1 and 1 or jsonb_typeof(look->'y') is distinct from 'number' or (look->>'y')::numeric not between -1 and 1 then return false;end if;
 if jsonb_typeof(p->'pictures') is distinct from 'array' or jsonb_array_length(p->'pictures')>12 then return false;end if;
 for pic in select * from jsonb_array_elements(p->'pictures') loop
  if jsonb_typeof(pic->'hash') is distinct from 'string' or pic->>'hash' !~ '^[0-9a-f]{64}$' or jsonb_typeof(pic->'caption') is distinct from 'string' or length(pic->>'caption')>1000 or jsonb_typeof(pic->'afterParagraph') is distinct from 'number' or (pic->>'afterParagraph')::integer not between -1 and 100000 then return false;end if;
 end loop;
 return true;
exception when others then return false;
end $$;
revoke all on function rpg_private.valid_gm_presentation(jsonb,integer) from public,anon,authenticated;
alter table public.rpg_gm_notes add column if not exists presentation jsonb not null default '{}'::jsonb;
create or replace function public.rpg_gm_save(p_campaign uuid,p_id uuid,p_expected bigint,p_note jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_revision bigint; v_presentation jsonb; v_hash text;
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then
 raise exception 'Roteiro restrito ao criador da campanha.' using errcode='42501';end if;
 if p_note is null or jsonb_typeof(p_note)<>'object' or
 jsonb_typeof(p_note->'title') is distinct from 'string' or
 jsonb_typeof(p_note->'body') is distinct from 'string' or
 jsonb_typeof(p_note->'section') is distinct from 'string' or
 jsonb_typeof(p_note->'state') is distinct from 'string' or
 jsonb_typeof(p_note->'tags') is distinct from 'string' or
 jsonb_typeof(p_note->'cue') is distinct from 'string' or
 jsonb_typeof(p_note->'music') is distinct from 'string' or
 jsonb_typeof(p_note->'next_session') is distinct from 'boolean' then
 raise exception 'Anotação inválida.' using errcode='22023';end if;

 if p_note ? 'presentation' then
  v_presentation:=p_note->'presentation';
  if not rpg_private.valid_gm_presentation(v_presentation,length(p_note->>'body') + (select count(*)::integer from regexp_matches(p_note->>'body', U&'[\+010000-\+10FFFF]', 'g'))) then raise exception 'Apresentação inválida.' using errcode='22023';end if;
  for v_hash in select v_presentation->>'cover' where v_presentation->>'cover' is not null
    union select value->>'hash' from jsonb_array_elements(coalesce(v_presentation->'pictures','[]'::jsonb)) loop
   if not exists(select 1 from storage.objects where bucket_id='rpg-gm-private' and name=p_campaign::text||'/'||v_hash||'.png') then
    raise exception 'Imagem privada ausente nesta campanha.' using errcode='22023';end if;
  end loop;
 end if;
 if p_expected=0 then
 insert into public.rpg_gm_notes(id,campaign_id,title,body,section,state,tags,cue,music,next_session,presentation)
 values(p_id,p_campaign,btrim(p_note->>'title'),p_note->>'body',p_note->>'section',p_note->>'state',p_note->>'tags',p_note->>'cue',p_note->>'music',(p_note->>'next_session')::boolean,coalesce(v_presentation,'{}'::jsonb))
 on conflict(id) do nothing returning revision into v_revision;
 else
 update public.rpg_gm_notes set title=btrim(p_note->>'title'),body=p_note->>'body',section=p_note->>'section',state=p_note->>'state',tags=p_note->>'tags',cue=p_note->>'cue',music=p_note->>'music',next_session=(p_note->>'next_session')::boolean,presentation=coalesce(v_presentation,presentation),revision=revision+1,updated_at=now()
 where id=p_id and campaign_id=p_campaign and revision=p_expected returning revision into v_revision;
 end if;
 if v_revision is null then raise exception 'Esta nota mudou. Atualize antes de substituir.' using errcode='40001';end if;
 return v_revision;
end $$;
revoke all on function public.rpg_gm_save(uuid,uuid,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.rpg_gm_save(uuid,uuid,bigint,jsonb) to authenticated;
-- New RPC avoids silent loss of presentation when a new app meets an older database.
create or replace function public.rpg_gm_save_visual(p_campaign uuid,p_id uuid,p_expected bigint,p_note jsonb) returns bigint
language sql security invoker set search_path='' as $$
 select public.rpg_gm_save(p_campaign,p_id,p_expected,p_note);
$$;
revoke all on function public.rpg_gm_save_visual(uuid,uuid,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.rpg_gm_save_visual(uuid,uuid,bigint,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

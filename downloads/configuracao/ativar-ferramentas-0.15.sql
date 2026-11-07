-- RPG Master Set: estilos de imagem e reset protegido por geração.
begin;
create or replace function rpg_private.valid_image_style(p jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
begin
 if jsonb_typeof(p) is distinct from 'object' then return false;end if;
 if p ? 'shape' and (jsonb_typeof(p->'shape') is distinct from 'string' or p->>'shape' not in ('rectangle','rounded','square','circle','oval')) then return false;end if;
 if p ? 'zoom' and (jsonb_typeof(p->'zoom') is distinct from 'number' or (p->>'zoom')::numeric not between 1 and 3) then return false;end if;
 if p ? 'x' and (jsonb_typeof(p->'x') is distinct from 'number' or (p->>'x')::numeric not between -1 and 1) then return false;end if;
 if p ? 'y' and (jsonb_typeof(p->'y') is distinct from 'number' or (p->>'y')::numeric not between -1 and 1) then return false;end if;
 if p ? 'fill' and jsonb_typeof(p->'fill') is distinct from 'boolean' then return false;end if;
 if p ? 'border' and jsonb_typeof(p->'border') is distinct from 'boolean' then return false;end if;
 if p ? 'size' and (jsonb_typeof(p->'size') is distinct from 'number' or (p->>'size')::numeric not between 0.25 and 1) then return false;end if;
 if p ? 'turns' and (jsonb_typeof(p->'turns') is distinct from 'number' or p->>'turns' !~ '^[0-3]$') then return false;end if;
 if p ? 'align' and (jsonb_typeof(p->'align') is distinct from 'string' or p->>'align' not in ('left','center','right')) then return false;end if;
 if p ? 'borderWidth' and (jsonb_typeof(p->'borderWidth') is distinct from 'number' or (p->>'borderWidth')::numeric not between 1 and 8) then return false;end if;
 if p ? 'borderColor' and (jsonb_typeof(p->'borderColor') is distinct from 'string' or p->>'borderColor' not in ('gold','wine','white','black')) then return false;end if;
 if p ? 'mirror' and jsonb_typeof(p->'mirror') is distinct from 'boolean' then return false;end if;
 if p ? 'shadow' and jsonb_typeof(p->'shadow') is distinct from 'boolean' then return false;end if;
 return true;
exception when others then return false;
end $$;
revoke all on function rpg_private.valid_image_style(jsonb) from public,anon,authenticated;
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
 if jsonb_typeof(look) is distinct from 'object' or look->>'shape' not in ('rounded','rectangle','square','circle','oval') or jsonb_typeof(look->'fill') is distinct from 'boolean' or jsonb_typeof(look->'border') is distinct from 'boolean' then return false;end if;
 if jsonb_typeof(look->'zoom') is distinct from 'number' or (look->>'zoom')::numeric not between 1 and 3 or jsonb_typeof(look->'x') is distinct from 'number' or (look->>'x')::numeric not between -1 and 1 or jsonb_typeof(look->'y') is distinct from 'number' or (look->>'y')::numeric not between -1 and 1 then return false;end if;
 if jsonb_typeof(p->'pictures') is distinct from 'array' or jsonb_array_length(p->'pictures')>12 then return false;end if;
 if not rpg_private.valid_image_style(look) then return false;end if;
 for pic in select * from jsonb_array_elements(p->'pictures') loop
  if pic ? 'look' and not rpg_private.valid_image_style(pic->'look') then return false;end if;
  if jsonb_typeof(pic->'hash') is distinct from 'string' or pic->>'hash' !~ '^[0-9a-f]{64}$' or jsonb_typeof(pic->'caption') is distinct from 'string' or length(pic->>'caption')>1000 or jsonb_typeof(pic->'afterParagraph') is distinct from 'number' or (pic->>'afterParagraph')::integer not between -1 and 100000 then return false;end if;
 end loop;
 return true;
exception when others then return false;
end $$;
revoke all on function rpg_private.valid_gm_presentation(jsonb,integer) from public,anon,authenticated;

alter table public.rpg_notebooks add column if not exists epoch bigint not null default 0;
create or replace function public.rpg_save_notebook(p_campaign uuid,p_expected bigint,p_entries jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_revision bigint;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado à campanha.' using errcode='42501';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 perform 1 from public.rpg_notebooks where campaign_id=p_campaign for update;
 if exists(select 1 from public.rpg_notebooks where campaign_id=p_campaign and epoch>0) then raise exception 'Atualize o aplicativo para esta campanha reiniciada.' using errcode='42501';end if;
 if not rpg_private.valid_notes(p_entries) then raise exception 'Formato de notas inválido.' using errcode='22023';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 update public.rpg_notebooks set entries=p_entries,revision=revision+1,updated_at=now(),updated_by=auth.uid() where campaign_id=p_campaign and revision=p_expected returning revision into v_revision;
 if not found then raise exception 'A campanha mudou. Recarregue e preserve as duas versões.' using errcode='40001';end if;
 insert into public.rpg_notebook_versions(campaign_id,revision,entries,saved_by) values(p_campaign,v_revision,p_entries,auth.uid());
 delete from public.rpg_notebook_versions where campaign_id=p_campaign and revision<=v_revision-20;
 return v_revision;
end $$;

create or replace function public.rpg_poll_notebook(p_campaign uuid,p_known bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado.' using errcode='42501';end if;
 select jsonb_build_object('revision',revision,'epoch',epoch,'entries',case when revision=p_known then null else entries end) into r from public.rpg_notebooks where campaign_id=p_campaign;
 return coalesce(r,jsonb_build_object('revision',0,'epoch',0,'entries','[]'::jsonb));
end $$;
create or replace function public.rpg_save_notebook_v2(p_campaign uuid,p_expected bigint,p_epoch bigint,p_entries jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_revision bigint;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado.' using errcode='42501';end if;
 if not rpg_private.valid_notes(p_entries) then raise exception 'Notas inválidas.' using errcode='22023';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 update public.rpg_notebooks set entries=p_entries,revision=revision+1,updated_at=now(),updated_by=auth.uid() where campaign_id=p_campaign and revision=p_expected and epoch=p_epoch returning revision into v_revision;
 if not found then raise exception 'A campanha mudou.' using errcode='40001';end if;
 insert into public.rpg_notebook_versions(campaign_id,revision,entries,saved_by) values(p_campaign,v_revision,p_entries,auth.uid());
 delete from public.rpg_notebook_versions where campaign_id=p_campaign and revision<=v_revision-20;
 return v_revision;
end $$;
create or replace function public.rpg_reset_preview(p_campaign uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then raise exception 'Somente o criador da campanha.' using errcode='42501';end if;
 return jsonb_build_object('revision',coalesce((select revision from public.rpg_notebooks where campaign_id=p_campaign),0),'shared',coalesce((select jsonb_array_length(entries) from public.rpg_notebooks where campaign_id=p_campaign),0),'private',(select count(*) from public.rpg_gm_notes where campaign_id=p_campaign));
end $$;
create or replace function public.rpg_reset_campaign(p_campaign uuid,p_expected bigint,p_private boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then raise exception 'Somente o criador da campanha.' using errcode='42501';end if;
 if p_private is null then raise exception 'Escolha o alcance da limpeza.' using errcode='22023';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 update public.rpg_notebooks set entries='[]'::jsonb,revision=revision+1,epoch=epoch+1,updated_at=now(),updated_by=auth.uid() where campaign_id=p_campaign and revision=p_expected;
 if not found then raise exception 'A campanha mudou. Confira novamente.' using errcode='40001';end if;
 delete from public.rpg_notebook_versions where campaign_id=p_campaign;
 if p_private then delete from public.rpg_gm_notes where campaign_id=p_campaign;end if;
end $$;
revoke all on function public.rpg_save_notebook_v2(uuid,bigint,bigint,jsonb),public.rpg_reset_preview(uuid),public.rpg_reset_campaign(uuid,bigint,boolean) from public,anon,authenticated;
grant execute on function public.rpg_save_notebook_v2(uuid,bigint,bigint,jsonb),public.rpg_reset_preview(uuid),public.rpg_reset_campaign(uuid,bigint,boolean) to authenticated;
notify pgrst,'reload schema';
commit;

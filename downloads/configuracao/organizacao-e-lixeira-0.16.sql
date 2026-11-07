-- RPG Master Set 0.16: organização, lixeira e proteção de clientes antigos.
-- Requer a configuração 0.15. Não move, exclui nem reordena notas existentes.
begin;
alter table public.rpg_notebooks add column if not exists organizer_enabled boolean not null default false;
alter table public.rpg_notebooks add column if not exists purged_ids jsonb not null default '[]'::jsonb;
alter table public.rpg_gm_notes add column if not exists orders jsonb not null default '{}'::jsonb;
alter table public.rpg_gm_notes add column if not exists deleted_at timestamptz;
create table if not exists rpg_private.gm_purged(campaign_id uuid not null references public.rpg_campaigns(id) on delete cascade,id uuid not null,primary key(campaign_id,id));
revoke all on rpg_private.gm_purged from public,anon,authenticated;
alter table rpg_private.gm_purged enable row level security;
create or replace function rpg_private.valid_orders(p jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare pair record;v jsonb;
begin
 if jsonb_typeof(p) is distinct from 'object' or octet_length(p::text)>32768 then return false;end if;
 for pair in select * from jsonb_each(p) loop
  v:=pair.value;
  if length(pair.key)>100 or jsonb_typeof(v) is distinct from 'object' or jsonb_typeof(v->'index') is distinct from 'number' or v->>'index' !~ '^[0-9]+$' or (v->>'index')::numeric>100000 or jsonb_typeof(v->'clock') is distinct from 'number' or v->>'clock' !~ '^[0-9]+$' or (v->>'clock')::numeric>9000000000000 or jsonb_typeof(v->'op') is distinct from 'string' or v->>'op' !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' then return false;end if;
 end loop;
 return true;
exception when others then return false;
end $$;
revoke all on function rpg_private.valid_orders(jsonb) from public,anon,authenticated;
create or replace function public.rpg_save_notebook(p_campaign uuid,p_expected bigint,p_entries jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_revision bigint;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado à campanha.' using errcode='42501';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 perform 1 from public.rpg_notebooks where campaign_id=p_campaign for update;
 if exists(select 1 from public.rpg_notebooks where campaign_id=p_campaign and (epoch>0 or organizer_enabled)) then raise exception 'Atualize o aplicativo para esta campanha reiniciada.' using errcode='42501';end if;
 if not rpg_private.valid_notes(p_entries) then raise exception 'Formato de notas inválido.' using errcode='22023';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 update public.rpg_notebooks set entries=p_entries,revision=revision+1,updated_at=now(),updated_by=auth.uid() where campaign_id=p_campaign and revision=p_expected returning revision into v_revision;
 if not found then raise exception 'A campanha mudou. Recarregue e preserve as duas versões.' using errcode='40001';end if;
 insert into public.rpg_notebook_versions(campaign_id,revision,entries,saved_by) values(p_campaign,v_revision,p_entries,auth.uid());
 delete from public.rpg_notebook_versions where campaign_id=p_campaign and revision<=v_revision-20;
 return v_revision;
end $$;

create or replace function public.rpg_save_notebook_v2(p_campaign uuid,p_expected bigint,p_epoch bigint,p_entries jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_revision bigint;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado.' using errcode='42501';end if;
 if exists(select 1 from public.rpg_notebooks where campaign_id=p_campaign and organizer_enabled) then raise exception 'Atualize o aplicativo para a organização desta campanha.' using errcode='42501';end if;
 if not rpg_private.valid_notes(p_entries) then raise exception 'Notas inválidas.' using errcode='22023';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 update public.rpg_notebooks set entries=p_entries,revision=revision+1,updated_at=now(),updated_by=auth.uid() where campaign_id=p_campaign and revision=p_expected and epoch=p_epoch and not organizer_enabled returning revision into v_revision;
 if not found then raise exception 'A campanha mudou.' using errcode='40001';end if;
 insert into public.rpg_notebook_versions(campaign_id,revision,entries,saved_by) values(p_campaign,v_revision,p_entries,auth.uid());
 delete from public.rpg_notebook_versions where campaign_id=p_campaign and revision<=v_revision-20;
 return v_revision;
end $$;

create or replace function public.rpg_poll_notebook(p_campaign uuid,p_known bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado.' using errcode='42501';end if;
 if exists(select 1 from public.rpg_notebooks where campaign_id=p_campaign and organizer_enabled) then raise exception 'Atualize o aplicativo para ver organização e lixeira.' using errcode='42501';end if;
 select jsonb_build_object('revision',revision,'epoch',epoch,'entries',case when revision=p_known then null else entries end) into r from public.rpg_notebooks where campaign_id=p_campaign;
 return coalesce(r,jsonb_build_object('revision',0,'epoch',0,'entries','[]'::jsonb));
end $$;
create or replace function public.rpg_read_notebook(p_campaign uuid) returns jsonb
language sql security invoker set search_path='' as $$ select public.rpg_poll_notebook(p_campaign,-1); $$;
create or replace function public.rpg_poll_notebook_v3(p_campaign uuid,p_known bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r jsonb;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado.' using errcode='42501';end if;
 select jsonb_build_object('revision',revision,'epoch',epoch,'purged',purged_ids,'entries',case when revision=p_known then null else entries end) into r from public.rpg_notebooks where campaign_id=p_campaign;
 return coalesce(r,jsonb_build_object('revision',0,'epoch',0,'purged','[]'::jsonb,'entries','[]'::jsonb));
end $$;
create or replace function public.rpg_save_notebook_v3(p_campaign uuid,p_expected bigint,p_epoch bigint,p_entries jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare previous public.rpg_notebooks%rowtype;e jsonb;missing jsonb;clean jsonb;new_purged jsonb;v_revision bigint;is_owner boolean;
begin
 if auth.uid() is null or not rpg_private.is_member(p_campaign) then raise exception 'Acesso negado.' using errcode='42501';end if;
 if not rpg_private.valid_notes(p_entries) then raise exception 'Notas inválidas.' using errcode='22023';end if;
 insert into public.rpg_notebooks(campaign_id) values(p_campaign) on conflict do nothing;
 select * into previous from public.rpg_notebooks where campaign_id=p_campaign for update;
 if previous.revision<>p_expected or previous.epoch<>p_epoch then raise exception 'A campanha mudou.' using errcode='40001';end if;
 is_owner:=exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid());
 new_purged:=previous.purged_ids;
 for e in select * from jsonb_array_elements(p_entries) loop
  if not rpg_private.valid_orders(coalesce(e->'orders','{}'::jsonb)) then raise exception 'Ordem inválida.' using errcode='22023';end if;
  if e->>'deletedAt' is not null then
   if jsonb_typeof(e->'deletedAt') is distinct from 'string' or length(e->>'deletedAt')>80 then raise exception 'Lixeira inválida.' using errcode='22023';end if;
   perform (e->>'deletedAt')::timestamptz;
  end if;
 end loop;
 for missing in select * from jsonb_array_elements(previous.entries) old where not exists(select 1 from jsonb_array_elements(p_entries) incoming where incoming->>'id'=old->>'id') loop
  if not is_owner then raise exception 'Somente o criador exclui definitivamente.' using errcode='42501';end if;
  if missing->>'deletedAt' is null then raise exception 'Mova para a lixeira antes de excluir definitivamente.' using errcode='22023';end if;
  if not new_purged ? (missing->>'id') then new_purged:=new_purged||jsonb_build_array(missing->>'id');end if;
 end loop;
 select coalesce(jsonb_agg(value),'[]'::jsonb) into clean from jsonb_array_elements(p_entries) where not new_purged ? (value->>'id');
 update public.rpg_notebooks set entries=clean,purged_ids=new_purged,organizer_enabled=true,revision=revision+1,updated_at=now(),updated_by=auth.uid() where campaign_id=p_campaign returning revision into v_revision;
 update public.rpg_notebook_versions v set entries=coalesce((select jsonb_agg(value) from jsonb_array_elements(v.entries) where not new_purged ? (value->>'id')),'[]'::jsonb) where campaign_id=p_campaign;
 insert into public.rpg_notebook_versions(campaign_id,revision,entries,saved_by) values(p_campaign,v_revision,clean,auth.uid());
 delete from public.rpg_notebook_versions where campaign_id=p_campaign and revision<=v_revision-20;
 return v_revision;
end $$;
create or replace function rpg_private.gm_purge_marker() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if TG_OP='DELETE' then if exists(select 1 from public.rpg_campaigns where id=old.campaign_id) then insert into rpg_private.gm_purged values(old.campaign_id,old.id) on conflict do nothing;end if;return old;end if;
 if exists(select 1 from rpg_private.gm_purged where campaign_id=new.campaign_id and id=new.id) then raise exception 'Nota excluída definitivamente.' using errcode='40001';end if;
 return new;
end $$;
revoke all on function rpg_private.gm_purge_marker() from public,anon,authenticated;
drop trigger if exists rpg_gm_purge_marker on public.rpg_gm_notes;
create trigger rpg_gm_purge_marker before insert or delete on public.rpg_gm_notes for each row execute function rpg_private.gm_purge_marker();
create or replace function public.rpg_gm_list(p_campaign uuid) returns setof public.rpg_gm_notes
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then raise exception 'Somente o criador.' using errcode='42501';end if;
 return query select * from public.rpg_gm_notes where campaign_id=p_campaign and deleted_at is null order by updated_at desc,id;
end $$;
create or replace function public.rpg_gm_list_v2(p_campaign uuid) returns setof public.rpg_gm_notes
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then raise exception 'Somente o criador.' using errcode='42501';end if;
 return query select * from public.rpg_gm_notes where campaign_id=p_campaign order by updated_at desc,id;
end $$;
create or replace function public.rpg_gm_trash(p_campaign uuid,p_id uuid,p_expected bigint,p_deleted boolean) returns bigint
language plpgsql security definer set search_path='' as $$
declare v bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then raise exception 'Somente o criador.' using errcode='42501';end if;
 if p_deleted is null then raise exception 'Ação inválida.' using errcode='22023';end if;
 update public.rpg_gm_notes set deleted_at=case when p_deleted then now() else null end,revision=revision+1 where campaign_id=p_campaign and id=p_id and revision=p_expected returning revision into v;
 if v is null then raise exception 'Esta nota mudou.' using errcode='40001';end if;
 return v;
end $$;
create or replace function public.rpg_gm_organize(p_campaign uuid,p_ids uuid[],p_view text,p_clock bigint,p_op text) returns void
language plpgsql security definer set search_path='' as $$
declare item uuid;i integer:=0;
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then raise exception 'Somente o criador.' using errcode='42501';end if;
 if p_ids is null or cardinality(p_ids)>10000 or p_view is null or p_view not in ('idea','scene','backstage','next') or p_clock is null or p_clock not between 0 and 9000000000000 or p_op is null or p_op !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' or (select count(distinct id) from unnest(p_ids) id)<>cardinality(p_ids) then raise exception 'Ordem inválida.' using errcode='22023';end if;
 perform 1 from public.rpg_gm_notes where campaign_id=p_campaign and id=any(p_ids) order by id for update;
 if (select count(*) from public.rpg_gm_notes where campaign_id=p_campaign and id=any(p_ids) and deleted_at is null and (case when p_view='next' then next_session else section=p_view end))<>cardinality(p_ids) then raise exception 'As notas mudaram. Atualize.' using errcode='40001';end if;
 foreach item in array p_ids loop
  update public.rpg_gm_notes set orders=orders||jsonb_build_object(p_view,jsonb_build_object('index',i,'clock',p_clock,'op',p_op)) where campaign_id=p_campaign and id=item;i:=i+1;
 end loop;
end $$;
create or replace function public.rpg_gm_delete(p_campaign uuid,p_id uuid,p_expected bigint) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then raise exception 'Somente o criador.' using errcode='42501';end if;
 delete from public.rpg_gm_notes where campaign_id=p_campaign and id=p_id and revision=p_expected and deleted_at is not null;
 if not found then raise exception 'Atualize a nota e mova para a lixeira antes de excluir.' using errcode='40001';end if;
end $$;
revoke all on function public.rpg_poll_notebook_v3(uuid,bigint),public.rpg_save_notebook_v3(uuid,bigint,bigint,jsonb),public.rpg_gm_list_v2(uuid),public.rpg_gm_trash(uuid,uuid,bigint,boolean),public.rpg_gm_organize(uuid,uuid[],text,bigint,text) from public,anon,authenticated;
grant execute on function public.rpg_poll_notebook_v3(uuid,bigint),public.rpg_save_notebook_v3(uuid,bigint,bigint,jsonb),public.rpg_gm_list_v2(uuid),public.rpg_gm_trash(uuid,uuid,bigint,boolean),public.rpg_gm_organize(uuid,uuid[],text,bigint,text) to authenticated;
notify pgrst,'reload schema';
commit;

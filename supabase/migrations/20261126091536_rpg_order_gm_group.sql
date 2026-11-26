-- Save the order of one private group against the order the master saw.
create function public.rpg_order_gm_group(
  p_campaign uuid, p_group text, p_ids uuid[], p_previous jsonb
) returns boolean
language plpgsql
security definer set search_path = ''
as $$
declare
  current_order jsonb;
  stamp bigint := floor(extract(epoch from clock_timestamp()) * 1000);
  operation_id uuid := gen_random_uuid();
begin
  if auth.uid() is null then
    raise exception 'Somente o criador.' using errcode = '42501';
  end if;
  perform 1 from public.rpg_campaigns
    where id = p_campaign and created_by = auth.uid() for update;
  if not found then
    raise exception 'Somente o criador.' using errcode = '42501';
  end if;
  if p_group is null or p_group not in ('idea','scene','backstage','character','kingdom','organization')
     or p_ids is null or cardinality(p_ids) > 10000
     or jsonb_typeof(p_previous) is distinct from 'object'
     or (select count(distinct id) from unnest(p_ids) id) <> cardinality(p_ids) then
    raise exception 'Ordem inválida.' using errcode = '22023';
  end if;
  perform 1 from public.rpg_gm_notes
    where campaign_id = p_campaign order by id for update;
  select coalesce(jsonb_object_agg(id, coalesce(orders->p_group, 'null'::jsonb)), '{}'::jsonb)
    into current_order
    from public.rpg_gm_notes
    where campaign_id = p_campaign and deleted_at is null
      and case when presentation->>'entryKind' in ('character','kingdom','organization')
        then presentation->>'entryKind' else section end = p_group;
  if current_order <> p_previous
     or cardinality(p_ids) <> (select count(*) from jsonb_object_keys(current_order))
     or exists(select 1 from unnest(p_ids) id where not current_order ? id::text) then
    return false;
  end if;
  update public.rpg_gm_notes n
    set orders = n.orders || jsonb_build_object(
      p_group, jsonb_build_object('index', positions.position - 1, 'clock', stamp, 'op', operation_id)
    )
    from unnest(p_ids) with ordinality as positions(id, position)
    where n.campaign_id = p_campaign and n.id = positions.id;
  return true;
end;
$$;

revoke all on function public.rpg_order_gm_group(uuid,text,uuid[],jsonb)
  from public, anon, authenticated;
grant execute on function public.rpg_order_gm_group(uuid,text,uuid[],jsonb)
  to authenticated;

notify pgrst, 'reload schema';

-- Return a conflict without making PostgREST retry a stale revision.
create function public.rpg_try_set_gm_trash(
  p_campaign uuid, p_id uuid, p_expected bigint, p_deleted boolean
) returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.rpg_gm_trash(p_campaign, p_id, p_expected, p_deleted);
exception
  when serialization_failure then return null;
end;
$$;

revoke all on function public.rpg_try_set_gm_trash(uuid,uuid,bigint,boolean)
  from public, anon, authenticated;
grant execute on function public.rpg_try_set_gm_trash(uuid,uuid,bigint,boolean)
  to authenticated;

notify pgrst, 'reload schema';

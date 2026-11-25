-- Treat a stale cover revision as a normal conflict for PostgREST.
create function public.rpg_try_set_campaign_cover(
  p_campaign uuid, p_expected bigint, p_hash text, p_layout jsonb
) returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.rpg_set_campaign_cover(p_campaign, p_expected, p_hash, p_layout);
exception
  when serialization_failure then return null;
end;
$$;

revoke all on function public.rpg_try_set_campaign_cover(uuid,bigint,text,jsonb)
  from public, anon, authenticated;
grant execute on function public.rpg_try_set_campaign_cover(uuid,bigint,text,jsonb)
  to authenticated;

notify pgrst, 'reload schema';

-- Traduz conflitos de revisão sem disparar novas tentativas do PostgREST.
create or replace function public.rpg_try_save_gm_note(
  p_campaign uuid,
  p_id uuid,
  p_expected bigint,
  p_note jsonb
) returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.rpg_gm_save_visual(p_campaign, p_id, p_expected, p_note);
exception
  when serialization_failure then
    return null;
end;
$$;

revoke all on function public.rpg_try_save_gm_note(uuid, uuid, bigint, jsonb)
  from public, anon, authenticated;
grant execute on function public.rpg_try_save_gm_note(uuid, uuid, bigint, jsonb)
  to authenticated;

notify pgrst, 'reload schema';

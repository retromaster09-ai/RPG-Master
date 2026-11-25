-- O PostgREST repete uma transação abortada com SQLSTATE 40001 sem conhecer
-- a nova revisão. O cliente da reconstrução trata null como conflito.
create or replace function public.rpg_try_save_notebook_v3(
  p_campaign uuid,
  p_expected bigint,
  p_epoch bigint,
  p_entries jsonb
) returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
begin
  return public.rpg_save_notebook_v3(p_campaign, p_expected, p_epoch, p_entries);
exception
  when serialization_failure then
    return null;
end;
$$;

revoke all on function public.rpg_try_save_notebook_v3(uuid, bigint, bigint, jsonb)
  from public, anon, authenticated;
grant execute on function public.rpg_try_save_notebook_v3(uuid, bigint, bigint, jsonb)
  to authenticated;

notify pgrst, 'reload schema';

-- Executar em um banco descartável com as migrações já aplicadas.
-- As contas e a campanha fictícia são revertidas ao final.
begin;

insert into auth.users (id, email) values
  ('10000000-0000-4000-8000-000000000001', 'mestre@example.com'),
  ('10000000-0000-4000-8000-000000000002', 'jogador@example.com');

insert into public.rpg_campaigns (id, name, created_by) values
  ('20000000-0000-4000-8000-000000000001', 'Campanha fictícia',
   '10000000-0000-4000-8000-000000000001');

insert into public.rpg_members (campaign_id, user_id, role) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'gm'),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'player');

insert into public.rpg_notebooks (campaign_id, organizer_enabled, entries) values
  ('20000000-0000-4000-8000-000000000001',
   true,
   '[{"title":"Uma pista","category":"Investigação"},{"title":"Primeira sessão","category":"Sessão"}]');

insert into public.rpg_gm_notes (id, campaign_id, title) values
  ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   'Nota privada fictícia');

insert into storage.objects (bucket_id, name)
select bucket, '20000000-0000-4000-8000-000000000001/' || repeat('a', 64) || '.png'
from (values ('rpg-notes'), ('rpg-gm-private')) as buckets(bucket);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

do $$
declare
  campaign constant uuid := '20000000-0000-4000-8000-000000000001';
begin
  if (select count(*) from public.rpg_gm_list_v2(campaign)) <> 1 then
    raise exception 'Mestre sem acesso ao roteiro privado';
  end if;
  if (select count(*) from public.rpg_gm_notes where campaign_id = campaign) <> 1 then
    raise exception 'Mestre sem acesso à nota pelas regras da tabela';
  end if;
  if (select count(*) from storage.objects where bucket_id = 'rpg-gm-private'
      and name like campaign::text || '/%') <> 1 then
    raise exception 'Mestre sem acesso ao objeto privado';
  end if;
  if jsonb_array_length(public.rpg_poll_notebook_v3(campaign,-1)->'entries') is distinct from 2 then
    raise exception 'Mestre sem acesso ao caderno e à crônica';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

do $$
declare
  campaign constant uuid := '20000000-0000-4000-8000-000000000001';
begin
  if jsonb_array_length(public.rpg_poll_notebook_v3(campaign,-1)->'entries') is distinct from 2 then
    raise exception 'Jogador sem acesso ao caderno e à crônica';
  end if;
  if exists (select 1 from public.rpg_gm_notes where campaign_id = campaign) then
    raise exception 'Nota privada visível pela tabela ao jogador';
  end if;
  begin
    perform public.rpg_gm_list_v2(campaign);
    raise exception 'Roteiro visível pela função ao jogador';
  exception when insufficient_privilege then
    null;
  end;
  if exists (select 1 from storage.objects where bucket_id = 'rpg-gm-private'
      and name like campaign::text || '/%') then
    raise exception 'Objeto privado visível ao jogador';
  end if;
  if (select count(*) from storage.objects where bucket_id = 'rpg-notes'
      and name like campaign::text || '/%') <> 1 then
    raise exception 'Objeto compartilhado invisível ao jogador';
  end if;
end $$;

reset role;
do $$
begin
  if (select public from storage.buckets where id = 'rpg-gm-private')
      is distinct from false then
    raise exception 'O bucket do mestre precisa ser privado';
  end if;
end $$;

rollback;

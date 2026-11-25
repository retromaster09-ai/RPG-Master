-- RPG Master 0.11: capa da campanha, escolhida pelo criador e visível aos membros.
-- Requer os SQLs de contas e notas/imagens já utilizados. Não altera anotações ou senhas.
begin;
alter table public.rpg_campaigns add column if not exists cover_hash text check(cover_hash is null or cover_hash ~ '^[0-9a-f]{64}$');
alter table public.rpg_campaigns add column if not exists cover_layout jsonb not null default '{"fill":true,"zoom":1,"x":0,"y":0}'::jsonb;
alter table public.rpg_campaigns add column if not exists cover_revision bigint not null default 0 check(cover_revision>=0);

create or replace function public.rpg_set_campaign_cover(p_campaign uuid,p_expected bigint,p_hash text,p_layout jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_revision bigint; field text; v_layout jsonb;
begin
  if auth.uid() is null or not exists(select 1 from public.rpg_campaigns c where c.id=p_campaign and c.created_by=auth.uid()) then
    raise exception 'Somente o criador da campanha pode alterar a capa.' using errcode='42501';
  end if;
  if p_hash is not null and p_hash !~ '^[0-9a-f]{64}$' then raise exception 'Imagem inválida.' using errcode='22023';end if;
  if jsonb_typeof(p_layout) is distinct from 'object' or jsonb_typeof(p_layout->'fill') is distinct from 'boolean' then raise exception 'Enquadramento inválido.' using errcode='22023';end if;
  foreach field in array array['zoom','x','y'] loop
    if jsonb_typeof(p_layout->field) is distinct from 'number' then raise exception 'Enquadramento inválido.' using errcode='22023';end if;
  end loop;
  if (p_layout->>'zoom')::numeric not between 1 and 3 or (p_layout->>'x')::numeric not between -1 and 1 or (p_layout->>'y')::numeric not between -1 and 1 then raise exception 'Enquadramento inválido.' using errcode='22023';end if;
  if p_hash is not null and not exists(select 1 from storage.objects o where o.bucket_id='rpg-notes' and o.name=p_campaign::text||'/'||p_hash||'.png') then raise exception 'Envie a imagem antes de salvar a capa.' using errcode='22023';end if;
  v_layout:=jsonb_build_object('fill',(p_layout->>'fill')::boolean,'zoom',(p_layout->>'zoom')::numeric,'x',(p_layout->>'x')::numeric,'y',(p_layout->>'y')::numeric);
  update public.rpg_campaigns set cover_hash=p_hash,cover_layout=v_layout,cover_revision=cover_revision+1 where id=p_campaign and cover_revision=p_expected returning cover_revision into v_revision;
  if not found then raise exception 'A capa mudou em outro aparelho. Atualize a lista.' using errcode='40001';end if;
  return v_revision;
end $$;
revoke all on function public.rpg_set_campaign_cover(uuid,bigint,text,jsonb) from public,anon,authenticated;
grant execute on function public.rpg_set_campaign_cover(uuid,bigint,text,jsonb) to authenticated;
notify pgrst,'reload schema';
commit;

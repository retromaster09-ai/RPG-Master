-- RPG Master: contas, campanhas e convites. Não armazena notas ou segredos nesta etapa.
-- Executar uma vez no SQL Editor do projeto. Pode ser reaplicado sem apagar dados.
begin;
create schema if not exists rpg_private;
revoke all on schema rpg_private from public, anon, authenticated;
grant usage on schema rpg_private to authenticated;

create table if not exists public.rpg_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 100),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.rpg_members (
  campaign_id uuid not null references public.rpg_campaigns(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('gm','player')),
  primary key(campaign_id,user_id)
);
create index if not exists rpg_members_user_idx on public.rpg_members(user_id,campaign_id);
create table if not exists rpg_private.invites (
  token_hash text primary key,
  campaign_id uuid not null references public.rpg_campaigns(id) on delete cascade,
  expires_at timestamptz not null default now() + interval '7 days',
  claimed_by uuid references auth.users(id) on delete cascade
);
revoke all on public.rpg_campaigns, public.rpg_members, rpg_private.invites from public, anon, authenticated;
grant select on public.rpg_campaigns, public.rpg_members to authenticated;
alter table public.rpg_campaigns enable row level security;
alter table public.rpg_members enable row level security;
alter table rpg_private.invites enable row level security;

create or replace function rpg_private.is_member(p_campaign uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.rpg_members m where m.campaign_id=p_campaign and m.user_id=(select auth.uid()));
$$;
revoke all on function rpg_private.is_member(uuid) from public, anon, authenticated;
grant execute on function rpg_private.is_member(uuid) to authenticated;
drop policy if exists rpg_campaign_read on public.rpg_campaigns;
create policy rpg_campaign_read on public.rpg_campaigns for select to authenticated using (rpg_private.is_member(id));
drop policy if exists rpg_members_read on public.rpg_members;
create policy rpg_members_read on public.rpg_members for select to authenticated using (rpg_private.is_member(campaign_id));

create or replace function public.rpg_create_campaign(p_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_name is null or length(btrim(p_name)) not between 1 and 100 then raise exception 'Nome inválido.' using errcode='22023'; end if;
  insert into public.rpg_campaigns(name,created_by) values(btrim(p_name),v_user) returning id into v_id;
  insert into public.rpg_members(campaign_id,user_id,role) values(v_id,v_user,'gm');
  return v_id;
end $$;
create or replace function public.rpg_create_invite(p_campaign uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare v_token text;
begin
  if auth.uid() is null or not exists(select 1 from public.rpg_campaigns c where c.id=p_campaign and c.created_by=auth.uid()) then
    raise exception 'Somente o mestre pode convidar jogadores.' using errcode='42501';
  end if;
  v_token := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  insert into rpg_private.invites(token_hash,campaign_id) values(encode(sha256(convert_to(v_token,'UTF8')),'hex'),p_campaign);
  return v_token;
end $$;
create or replace function public.rpg_join_campaign(p_token text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_invite rpg_private.invites%rowtype; v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'Entre na sua conta.' using errcode='42501'; end if;
  if p_token is null or p_token !~ '^[0-9a-fA-F]{64}$' then raise exception 'Convite inválido ou expirado.' using errcode='22023'; end if;
  select * into v_invite from rpg_private.invites where token_hash=encode(sha256(convert_to(lower(p_token),'UTF8')),'hex') for update;
  if not found or v_invite.expires_at <= now() or (v_invite.claimed_by is not null and v_invite.claimed_by<>v_user) then
    raise exception 'Convite inválido ou expirado.' using errcode='22023';
  end if;
  insert into public.rpg_members(campaign_id,user_id,role) values(v_invite.campaign_id,v_user,'player') on conflict do nothing;
  update rpg_private.invites set claimed_by=v_user where token_hash=v_invite.token_hash;
  return v_invite.campaign_id;
end $$;
revoke all on function public.rpg_create_campaign(text),public.rpg_create_invite(uuid),public.rpg_join_campaign(text) from public,anon,authenticated;
grant execute on function public.rpg_create_campaign(text),public.rpg_create_invite(uuid),public.rpg_join_campaign(text) to authenticated;
commit;

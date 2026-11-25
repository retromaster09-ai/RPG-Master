create table if not exists rpg_private.account_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9][a-z0-9_.-]{2,23}$'),
  recovery_campaign_id uuid references public.rpg_campaigns(id) on delete set null,
  backup_hash bytea,
  attempts integer not null default 0,
  attempts_until timestamptz
);

create table if not exists rpg_private.account_recovery (
  user_id uuid primary key references rpg_private.account_profiles(user_id) on delete cascade,
  id uuid not null unique default gen_random_uuid(),
  campaign_id uuid not null references public.rpg_campaigns(id) on delete cascade,
  code_hash bytea,
  expires_at timestamptz not null
);

alter table rpg_private.account_profiles enable row level security;
alter table rpg_private.account_recovery enable row level security;
grant usage on schema rpg_private to service_role;
revoke all on rpg_private.account_profiles, rpg_private.account_recovery from public, anon, authenticated;
grant select, insert, update, delete on rpg_private.account_profiles, rpg_private.account_recovery to service_role;
grant select on public.rpg_campaigns, public.rpg_members to service_role;

-- Called only by the Edge Function after authenticating protected actions.
-- The service role is never exposed to the app.
create or replace function public.rpg_account(p_action text, p_actor uuid, p_data jsonb)
returns jsonb
language plpgsql security invoker set search_path = ''
as $$
declare
  profile rpg_private.account_profiles%rowtype;
  request_row rpg_private.account_recovery%rowtype;
  username_input text := lower(btrim(p_data->>'username'));
  selected_campaign uuid;
  recovery_hash bytea;
  found_user uuid;
begin
  if p_action = 'target' then
    select user_id into found_user from rpg_private.account_profiles
      where username = username_input;
    return jsonb_build_object('user_id', found_user);
  end if;

  if p_action in ('settings','setup','backup','approve') and p_actor is null then
    raise exception 'Entre na sua conta.' using errcode='42501';
  end if;

  if p_action = 'settings' then
    select * into profile from rpg_private.account_profiles where user_id=p_actor;
    return jsonb_build_object(
      'username', profile.username,
      'recovery_campaign_id', profile.recovery_campaign_id,
      'has_backup', profile.backup_hash is not null,
      'campaigns', coalesce((
        select jsonb_agg(jsonb_build_object('id',c.id,'name',c.name) order by c.name)
        from public.rpg_campaigns c join public.rpg_members m on m.campaign_id=c.id
        where m.user_id=p_actor and m.role='player' and c.created_by<>p_actor
      ),'[]'::jsonb),
      'pending', coalesce((
        select jsonb_agg(jsonb_build_object('id',r.id,'username',p.username,'campaign',c.name)
          order by r.expires_at)
        from rpg_private.account_recovery r
        join rpg_private.account_profiles p on p.user_id=r.user_id and p.recovery_campaign_id=r.campaign_id
        join public.rpg_campaigns c on c.id=r.campaign_id and c.created_by=p_actor
        join public.rpg_members m on m.campaign_id=c.id and m.user_id=p.user_id and m.role='player'
        where r.code_hash is null and r.expires_at>now()
      ),'[]'::jsonb)
    );
  end if;

  if p_action = 'setup' then
    selected_campaign := (p_data->>'campaign_id')::uuid;
    if username_input is null or username_input !~ '^[a-z0-9][a-z0-9_.-]{2,23}$' then
      return jsonb_build_object('error','invalid_username');
    end if;
    if selected_campaign is not null and not exists (
      select 1 from public.rpg_campaigns c join public.rpg_members m on m.campaign_id=c.id
      where c.id=selected_campaign and m.user_id=p_actor and m.role='player' and c.created_by<>p_actor
    ) then
      raise exception 'Campanha inválida para recuperação.' using errcode='42501';
    end if;
    begin
      insert into rpg_private.account_profiles(user_id,username,recovery_campaign_id)
        values(p_actor,username_input,selected_campaign)
      on conflict (user_id) do update
        set username=excluded.username,recovery_campaign_id=excluded.recovery_campaign_id;
    exception when unique_violation then
      return jsonb_build_object('error','username_taken');
    end;
    delete from rpg_private.account_recovery where user_id=p_actor
      and campaign_id is distinct from selected_campaign;
    return jsonb_build_object('ok',true);
  end if;

  if p_action = 'backup' then
    update rpg_private.account_profiles set backup_hash=decode(p_data->>'hash','hex')
      where user_id=p_actor;
    return jsonb_build_object('ok',found);
  end if;

  if p_action = 'request' then
    select * into profile from rpg_private.account_profiles where username=username_input for update;
    if found and exists (
      select 1 from public.rpg_members m where m.campaign_id=profile.recovery_campaign_id
        and m.user_id=profile.user_id and m.role='player'
    ) then
      insert into rpg_private.account_recovery(user_id,campaign_id,expires_at)
        values(profile.user_id,profile.recovery_campaign_id,now()+interval '24 hours')
      on conflict (user_id) do update set id=gen_random_uuid(),campaign_id=excluded.campaign_id,
        expires_at=excluded.expires_at,code_hash=null
      where account_recovery.expires_at<=now();
    end if;
    return jsonb_build_object('ok',true);
  end if;

  if p_action = 'approve' then
    select user_id into found_user from rpg_private.account_recovery
      where id=(p_data->>'request_id')::uuid;
    select * into profile from rpg_private.account_profiles where user_id=found_user for update;
    update rpg_private.account_recovery r set code_hash=decode(p_data->>'hash','hex'),
      expires_at=now()+interval '15 minutes'
    where r.id=(p_data->>'request_id')::uuid and r.user_id=profile.user_id
      and r.campaign_id=profile.recovery_campaign_id and r.code_hash is null and r.expires_at>now()
      and exists(
        select 1 from public.rpg_campaigns c join public.rpg_members m on m.campaign_id=c.id
        where c.id=r.campaign_id and c.created_by=p_actor and m.user_id=r.user_id and m.role='player'
      );
    return jsonb_build_object('ok',found);
  end if;

  if p_action = 'claim' then
    select * into profile from rpg_private.account_profiles where username=username_input for update;
    if not found or (profile.attempts_until>now() and profile.attempts>=5) then
      return jsonb_build_object('user_id',null);
    end if;
    recovery_hash := decode(p_data->>'hash','hex');
    select r.* into request_row from rpg_private.account_recovery r
      join public.rpg_members m on m.campaign_id=r.campaign_id and m.user_id=r.user_id and m.role='player'
      where r.user_id=profile.user_id and r.campaign_id=profile.recovery_campaign_id and r.expires_at>now();
    if recovery_hash=profile.backup_hash or recovery_hash=request_row.code_hash then
      -- Burn before the Auth API call. Concurrent requests cannot reuse it.
      update rpg_private.account_profiles set backup_hash=null,attempts=0,attempts_until=null
        where user_id=profile.user_id;
      delete from rpg_private.account_recovery where user_id=profile.user_id;
      return jsonb_build_object('user_id',profile.user_id);
    end if;
    update rpg_private.account_profiles set
      attempts=case when attempts_until>now() then attempts+1 else 1 end,
      attempts_until=case when attempts_until>now() then attempts_until else now()+interval '15 minutes' end
      where user_id=profile.user_id;
    return jsonb_build_object('user_id',null);
  end if;

  raise exception 'Operação desconhecida.' using errcode='22023';
end;
$$;

revoke all on function public.rpg_account(text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.rpg_account(text, uuid, jsonb) to service_role;
notify pgrst, 'reload schema';

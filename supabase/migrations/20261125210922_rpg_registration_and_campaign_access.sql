create table rpg_private.registration_window (
  singleton boolean primary key default true check (singleton),
  started_at timestamptz not null,
  attempts integer not null
);

alter table rpg_private.registration_window enable row level security;
revoke all on rpg_private.registration_window from public, anon, authenticated;

create function public.rpg_take_registration_slot()
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  request_at timestamptz := clock_timestamp();
begin
  insert into rpg_private.registration_window(singleton, started_at, attempts)
    values (true, request_at, 1)
    on conflict (singleton) do update
      set started_at = case when registration_window.started_at < request_at - interval '15 minutes'
          then request_at else registration_window.started_at end,
          attempts = case when registration_window.started_at < request_at - interval '15 minutes'
          then 1 else registration_window.attempts + 1 end
      where registration_window.attempts < 40
         or registration_window.started_at < request_at - interval '15 minutes';
  return found;
end;
$$;

revoke all on function public.rpg_take_registration_slot() from public, anon, authenticated;
grant execute on function public.rpg_take_registration_slot() to service_role;

-- Only Auth administrators can set app metadata on a new account.
-- A duplicate username aborts the Auth user insert in the same transaction.
create function rpg_private.register_account_profile()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.raw_app_meta_data ? 'rpg_registration_username' then
    insert into rpg_private.account_profiles(user_id, username)
      values (new.id, new.raw_app_meta_data->>'rpg_registration_username');
  end if;
  return new;
end;
$$;

revoke all on function rpg_private.register_account_profile() from public, anon, authenticated;
create trigger rpg_register_account_profile
after insert on auth.users
for each row execute function rpg_private.register_account_profile();

create function public.rpg_create_campaign_with_id(p_id uuid, p_name text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  owner_id uuid := auth.uid();
  campaign_name text := btrim(p_name);
begin
  if owner_id is null then
    raise exception 'Entre na sua conta.' using errcode = '42501';
  end if;
  if p_id is null or campaign_name is null or length(campaign_name) not between 1 and 100 then
    raise exception 'Nome inválido.' using errcode = '22023';
  end if;
  insert into public.rpg_campaigns(id, name, created_by)
    values (p_id, campaign_name, owner_id) on conflict (id) do nothing;
  if not exists (
    select 1 from public.rpg_campaigns
    where id = p_id and created_by = owner_id and name = campaign_name
  ) then
    raise exception 'Identificador de campanha já utilizado.' using errcode = '23505';
  end if;
  insert into public.rpg_members(campaign_id, user_id, role)
    values (p_id, owner_id, 'gm') on conflict (campaign_id, user_id) do nothing;
  return p_id;
end;
$$;

create function public.rpg_campaign_access(p_campaign uuid)
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.rpg_campaigns where id = p_campaign and created_by = auth.uid()
  ) then
    raise exception 'Somente o mestre pode consultar esta lista.' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'codeEnabled', exists(select 1 from rpg_private.campaign_codes where campaign_id = p_campaign),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('name', names.name, 'role', m.role)
        order by m.role, names.name)
      from public.rpg_members m
      join auth.users u on u.id = m.user_id
      left join rpg_private.account_profiles p on p.user_id = u.id
      cross join lateral (select coalesce(p.username, u.email, 'Participante') as name) names
      where m.campaign_id = p_campaign
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.rpg_create_campaign_with_id(uuid,text),
  public.rpg_campaign_access(uuid) from public, anon, authenticated;
grant execute on function public.rpg_create_campaign_with_id(uuid,text),
  public.rpg_campaign_access(uuid) to authenticated;

notify pgrst, 'reload schema';

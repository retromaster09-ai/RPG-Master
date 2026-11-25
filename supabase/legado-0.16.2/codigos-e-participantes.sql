-- RPG Master Set: código compartilhado escolhido pelo mestre e participantes.
-- Não remove notas, contas, capas ou convites antigos.
begin;
create table if not exists rpg_private.campaign_codes (
 campaign_id uuid primary key references public.rpg_campaigns(id) on delete cascade,
 code_hash text not null unique
);
create table if not exists rpg_private.code_attempts (
 user_id uuid primary key references auth.users(id) on delete cascade,
 started_at timestamptz not null,
 attempts integer not null
);
alter table rpg_private.campaign_codes enable row level security;
alter table rpg_private.code_attempts enable row level security;
revoke all on rpg_private.campaign_codes,rpg_private.code_attempts from public,anon,authenticated;

create or replace function public.rpg_set_campaign_code(p_campaign uuid,p_code text) returns boolean
language plpgsql security definer set search_path='' as $$
declare v_code text := lower(btrim(p_code));
begin
 perform 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid() for update;
 if not found then raise exception 'Somente o mestre pode alterar o código.' using errcode='42501'; end if;
 if p_code is null then
   delete from rpg_private.campaign_codes where campaign_id=p_campaign;
   return false;
 end if;
 if v_code !~ '^[a-z0-9_-]{10,48}$' then raise exception 'Use 10 a 48 letras sem acentos, números, hífen ou sublinhado.' using errcode='22023'; end if;
 begin
 insert into rpg_private.campaign_codes(campaign_id,code_hash)
 values(p_campaign,encode(sha256(convert_to(v_code,'UTF8')),'hex'))
 on conflict(campaign_id) do update set code_hash=excluded.code_hash;
 exception when unique_violation then
 raise exception 'Escolha outro código.' using errcode='23505';
 end;
 return true;
end $$;

create or replace function public.rpg_join_campaign_code(p_code text) returns text
language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_attempt rpg_private.code_attempts%rowtype; v_campaign uuid; v_code text:=lower(btrim(p_code));
begin
 if v_user is null then raise exception 'Entre na conta.' using errcode='42501'; end if;
 insert into rpg_private.code_attempts values(v_user,clock_timestamp(),0) on conflict do nothing;
 select * into v_attempt from rpg_private.code_attempts where user_id=v_user for update;
 if v_attempt.started_at <= clock_timestamp()-interval '15 minutes' then
   update rpg_private.code_attempts set started_at=clock_timestamp(),attempts=0 where user_id=v_user;
   v_attempt.attempts:=0;
 end if;
 if v_attempt.attempts>=5 then return 'limited'; end if;
 -- Retornar um status, sem exception, mantém a contagem de tentativas inválidas.
 update rpg_private.code_attempts set attempts=attempts+1 where user_id=v_user;
 if v_code is null or v_code !~ '^[a-z0-9_-]{10,48}$' then return 'invalid'; end if;
 select campaign_id into v_campaign from rpg_private.campaign_codes
 where code_hash=encode(sha256(convert_to(v_code,'UTF8')),'hex') for share;
 if not found then return 'invalid'; end if;
 insert into public.rpg_members(campaign_id,user_id,role) values(v_campaign,v_user,'player') on conflict do nothing;
 return 'joined';
end $$;

create or replace function public.rpg_campaign_people(p_campaign uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then
 raise exception 'Somente o mestre pode consultar esta lista.' using errcode='42501'; end if;
 return jsonb_build_object('codeEnabled',exists(select 1 from rpg_private.campaign_codes where campaign_id=p_campaign),
 'members',coalesce((select jsonb_agg(jsonb_build_object('email',u.email,'role',m.role) order by m.role,u.email)
 from public.rpg_members m join auth.users u on u.id=m.user_id where m.campaign_id=p_campaign),'[]'::jsonb));
end $$;
revoke all on function public.rpg_set_campaign_code(uuid,text),public.rpg_join_campaign_code(text),public.rpg_campaign_people(uuid) from public,anon,authenticated;
grant execute on function public.rpg_set_campaign_code(uuid,text),public.rpg_join_campaign_code(text),public.rpg_campaign_people(uuid) to authenticated;
notify pgrst,'reload schema';
commit;

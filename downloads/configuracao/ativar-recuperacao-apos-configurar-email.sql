-- APLICAR SOMENTE DEPOIS de configurar SMTP e o modelo de e-mail com {{ .Token }}.
-- Ativa o fluxo de recuperação nos aplicativos 0.10+. Não altera senhas ou campanhas.
begin;
create table if not exists rpg_private.app_settings (
  id boolean primary key default true check(id),
  password_recovery_enabled boolean not null default false
);
alter table rpg_private.app_settings enable row level security;
revoke all on rpg_private.app_settings from public,anon,authenticated;
insert into rpg_private.app_settings(id,password_recovery_enabled) values(true,true)
on conflict(id) do update set password_recovery_enabled=true;
create or replace function public.rpg_app_capabilities() returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('passwordRecovery',coalesce((select password_recovery_enabled from rpg_private.app_settings where id=true),false));
$$;
revoke all on function public.rpg_app_capabilities() from public,anon,authenticated;
grant execute on function public.rpg_app_capabilities() to anon,authenticated;
notify pgrst,'reload schema';
commit;

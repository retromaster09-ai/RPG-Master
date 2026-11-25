-- Auth writes administrator-provided app metadata after the user insert,
-- within the same transaction that creates the account.
create trigger rpg_register_account_profile_on_metadata
after update of raw_app_meta_data on auth.users
for each row
when (
  not coalesce(old.raw_app_meta_data ? 'rpg_registration_username', false)
  and new.raw_app_meta_data ? 'rpg_registration_username'
)
execute function rpg_private.register_account_profile();

insert into rpg_private.account_profiles(user_id, username)
select u.id, u.raw_app_meta_data->>'rpg_registration_username'
from auth.users u
where u.email like 'rpg-%@accounts.rpgmaster.invalid'
  and (u.raw_app_meta_data->>'rpg_registration_username') ~ '^[a-z0-9][a-z0-9_.-]{2,23}$'
on conflict do nothing;

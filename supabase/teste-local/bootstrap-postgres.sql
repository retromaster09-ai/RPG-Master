-- Estrutura mínima de Auth/Storage para testar as políticas em um
-- PostgreSQL vazio. O teste das APIs usa o Supabase completo.
begin;

create schema auth;
create schema storage;
create role anon;
create role authenticated;
create role service_role;

create table auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb
);

create function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table storage.objects (
  bucket_id text not null references storage.buckets(id),
  name text not null
);

alter table storage.objects enable row level security;
grant usage on schema auth, storage to authenticated;
grant select, insert on storage.objects to authenticated;

commit;

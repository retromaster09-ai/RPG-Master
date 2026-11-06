-- RPG Master Set: roteiro privado, separado integralmente das notas compartilhadas.
begin;
create table if not exists public.rpg_gm_notes (
 id uuid primary key,
 campaign_id uuid not null references public.rpg_campaigns(id) on delete cascade,
 title text not null check(length(btrim(title)) between 1 and 200),
 body text not null default '' check(length(body)<=100000),
 section text not null default 'idea' check(section in ('idea','scene','backstage')),
 state text not null default 'idea' check(state in ('idea','ready','used','discarded')),
 tags text not null default '' check(length(tags)<=1000),
 cue text not null default '' check(length(cue)<=4000),
 music text not null default '' check(length(music)<=2048),
 next_session boolean not null default false,
 revision bigint not null default 1 check(revision>0),
 updated_at timestamptz not null default now()
);
create index if not exists rpg_gm_campaign_idx on public.rpg_gm_notes(campaign_id,updated_at desc);
alter table public.rpg_gm_notes enable row level security;
revoke all on public.rpg_gm_notes from public,anon,authenticated;
grant select on public.rpg_gm_notes to authenticated;
drop policy if exists rpg_gm_owner_read on public.rpg_gm_notes;
create policy rpg_gm_owner_read on public.rpg_gm_notes for select to authenticated using(
 exists(select 1 from public.rpg_campaigns c where c.id=campaign_id and c.created_by=(select auth.uid()))
);
create or replace function public.rpg_gm_list(p_campaign uuid) returns setof public.rpg_gm_notes
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then
 raise exception 'Roteiro restrito ao criador da campanha.' using errcode='42501';end if;
 return query select * from public.rpg_gm_notes where campaign_id=p_campaign order by updated_at desc,id;
end $$;
create or replace function public.rpg_gm_save(p_campaign uuid,p_id uuid,p_expected bigint,p_note jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare v_revision bigint;
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then
 raise exception 'Roteiro restrito ao criador da campanha.' using errcode='42501';end if;
 if p_note is null or jsonb_typeof(p_note)<>'object' or
 jsonb_typeof(p_note->'title') is distinct from 'string' or
 jsonb_typeof(p_note->'body') is distinct from 'string' or
 jsonb_typeof(p_note->'section') is distinct from 'string' or
 jsonb_typeof(p_note->'state') is distinct from 'string' or
 jsonb_typeof(p_note->'tags') is distinct from 'string' or
 jsonb_typeof(p_note->'cue') is distinct from 'string' or
 jsonb_typeof(p_note->'music') is distinct from 'string' or
 jsonb_typeof(p_note->'next_session') is distinct from 'boolean' then
 raise exception 'Anotação inválida.' using errcode='22023';end if;
 if p_expected=0 then
 insert into public.rpg_gm_notes(id,campaign_id,title,body,section,state,tags,cue,music,next_session)
 values(p_id,p_campaign,btrim(p_note->>'title'),p_note->>'body',p_note->>'section',p_note->>'state',p_note->>'tags',p_note->>'cue',p_note->>'music',(p_note->>'next_session')::boolean)
 on conflict(id) do nothing returning revision into v_revision;
 else
 update public.rpg_gm_notes set title=btrim(p_note->>'title'),body=p_note->>'body',section=p_note->>'section',state=p_note->>'state',tags=p_note->>'tags',cue=p_note->>'cue',music=p_note->>'music',next_session=(p_note->>'next_session')::boolean,revision=revision+1,updated_at=now()
 where id=p_id and campaign_id=p_campaign and revision=p_expected returning revision into v_revision;
 end if;
 if v_revision is null then raise exception 'Esta nota mudou. Atualize antes de substituir.' using errcode='40001';end if;
 return v_revision;
end $$;
create or replace function public.rpg_gm_delete(p_campaign uuid,p_id uuid,p_expected bigint) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.rpg_campaigns where id=p_campaign and created_by=auth.uid()) then
 raise exception 'Roteiro restrito ao criador da campanha.' using errcode='42501';end if;
 delete from public.rpg_gm_notes where id=p_id and campaign_id=p_campaign and revision=p_expected;
 if not found then raise exception 'Esta nota mudou. Atualize antes de excluir.' using errcode='40001';end if;
end $$;
revoke all on function public.rpg_gm_list(uuid),public.rpg_gm_save(uuid,uuid,bigint,jsonb),public.rpg_gm_delete(uuid,uuid,bigint) from public,anon,authenticated;
grant execute on function public.rpg_gm_list(uuid),public.rpg_gm_save(uuid,uuid,bigint,jsonb),public.rpg_gm_delete(uuid,uuid,bigint) to authenticated;
notify pgrst,'reload schema';
commit;

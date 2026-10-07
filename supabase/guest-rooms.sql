-- Guest capabilities: 256-bit browser secret, only its SHA-256 stored server-side.
-- No identity, ownership or membership is inferred from a display name.
-- The legacy project is empty; abandon institutional invitations and auth FKs.
do $$ declare p record; begin
 for p in select schemaname,tablename,policyname from pg_policies where schemaname='public' and tablename in ('profiles','rooms','memberships','invitations','assignments','submissions','reviews') loop
 execute format('drop policy %I on %I.%I',p.policyname,p.schemaname,p.tablename);
 end loop;
end $$;
drop trigger membership_email on public.memberships;
drop function private.membership_email();
drop function private.invited(uuid);
drop function private.is_teacher();
drop function private.verified_email();
drop table public.invitations;
alter table public.memberships drop column email;
alter table public.profiles drop constraint profiles_id_fkey;
create table private.guests (
 id uuid primary key default gen_random_uuid(),
 token_hash bytea unique not null,
 created_at timestamptz not null default now(),
 join_window timestamptz not null default now(),
 join_attempts integer not null default 0
);
revoke all on private.guests from public,anon,authenticated;
alter table private.guests enable row level security;
alter table public.profiles add constraint profiles_guest_fkey foreign key(id) references private.guests(id);
alter table public.memberships add column display_name text not null default 'Participante' check(length(btrim(display_name)) between 1 and 80);
create unique index membership_names_unique on public.memberships(room_id,lower(btrim(display_name)));
create table private.removed_members (
 room_id uuid references public.rooms(id) on delete cascade,
 user_id uuid references private.guests(id) on delete cascade,
 primary key(room_id,user_id)
);
revoke all on private.removed_members from public,anon,authenticated;
alter table private.removed_members enable row level security;
alter table public.rooms add column join_code text not null default upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)) unique;

create function private.token_hash() returns bytea language sql stable set search_path='' as $$
 select case when (current_setting('request.headers',true)::jsonb->>'x-guest-token') ~ '^[a-f0-9]{64}$'
 then sha256(convert_to(current_setting('request.headers',true)::jsonb->>'x-guest-token','UTF8')) else null end
$$;
create function private.guest_id() returns uuid language sql stable security definer set search_path='' as $$
 select id from private.guests where token_hash=private.token_hash()
$$;
alter table public.rooms alter column owner_id set default private.guest_id();
alter table public.memberships alter column user_id set default private.guest_id();
alter table public.submissions alter column student_id set default private.guest_id();

create function private.start_guest(display_name text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid; h bytea:=private.token_hash(); n text:=btrim(display_name);
begin
 if h is null then raise exception 'Este navegador no pudo guardar tu acceso privado.'; end if;
 if n is null or length(n) not between 1 and 80 then raise exception 'Escribe un nombre de 1 a 80 caracteres.'; end if;
 insert into private.guests(token_hash) values(h) on conflict(token_hash) do nothing;
 select id into uid from private.guests where token_hash=h;
 insert into public.profiles(id,display_name) values(uid,n) on conflict(id) do nothing;
 return (select to_jsonb(p) from public.profiles p where p.id=uid);
end $$;
create function public.start_guest(display_name text) returns jsonb language sql security invoker set search_path='' as $$ select private.start_guest(display_name) $$;

create function private.create_room(room_name text,room_description text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.guest_id(); r public.rooms;
begin
 if uid is null then raise exception 'Introduce tu nombre para crear una sala.'; end if;
 perform 1 from private.guests where id=uid for update;
 if (select count(*) from public.rooms where owner_id=uid and created_at>now()-interval '1 day')>=10 then raise exception 'Puedes crear hasta 10 salas al dÃ­a. Intenta maÃ±ana.'; end if;
 loop
  begin
   insert into public.rooms(owner_id,name,description) values(uid,btrim(room_name),coalesce(room_description,'')) returning * into r;
   exit;
  exception when unique_violation then null;
  end;
 end loop;
 return to_jsonb(r);
end $$;
create function public.create_room(room_name text,room_description text default '') returns jsonb language sql security invoker set search_path='' as $$ select private.create_room(room_name,room_description) $$;

create function private.join_room(code text,participant_name text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.guest_id(); r public.rooms; attempts integer; n text:=btrim(participant_name);
begin
 if uid is null then raise exception 'Introduce tu nombre para entrar.'; end if;
 if n is null or length(n) not between 1 and 80 then return jsonb_build_object('error','Escribe un nombre de 1 a 80 caracteres.'); end if;
 update private.guests set join_attempts=case when join_window<now()-interval '1 minute' then 1 else join_attempts+1 end,
 join_window=case when join_window<now()-interval '1 minute' then now() else join_window end where id=uid returning join_attempts into attempts;
 if attempts>10 then return jsonb_build_object('error','Demasiados intentos. Espera un minuto y vuelve a intentar.'); end if;
 select * into r from public.rooms where join_code=upper(btrim(code)) for update;
 if r.id is null or r.archived then return jsonb_build_object('error','El cÃ³digo no existe o la sala estÃ¡ cerrada.'); end if;
 if r.owner_id=uid then return to_jsonb(r); end if;
 if exists(select 1 from private.removed_members where room_id=r.id and user_id=uid) then return jsonb_build_object('error','El anfitriÃ³n retirÃ³ tu acceso a esta sala.'); end if;
 if exists(select 1 from public.memberships where room_id=r.id and user_id=uid) then return to_jsonb(r); end if;
 if exists(select 1 from public.memberships where room_id=r.id and lower(btrim(display_name))=lower(n)) then return jsonb_build_object('error','Ese nombre ya estÃ¡ en la sala. Agrega tu apellido u otro identificador.'); end if;
 insert into public.memberships(room_id,user_id,display_name) values(r.id,uid,n);
 return to_jsonb(r);
end $$;
create function public.join_room(code text,participant_name text) returns jsonb language sql security invoker set search_path='' as $$ select private.join_room(code,participant_name) $$;

create function private.remember_removal() returns trigger language plpgsql security definer set search_path='' as $$ begin
 insert into private.removed_members(room_id,user_id) values(old.room_id,old.user_id) on conflict do nothing;
 return old;
end $$;
create trigger remember_removal before delete on public.memberships for each row execute function private.remember_removal();

revoke all on public.profiles,public.rooms,public.memberships,public.assignments,public.submissions,public.reviews from anon,authenticated;
-- Remove historical column grants too (table REVOKE does not remove these).
do $$ declare g record; begin
 for g in select table_name,column_name,privilege_type,grantee from information_schema.column_privileges where table_schema='public' and grantee in ('anon','authenticated') and table_name in ('profiles','rooms','memberships','assignments','submissions','reviews') loop
 execute format('revoke %s (%I) on public.%I from %I',g.privilege_type,g.column_name,g.table_name,g.grantee);
 end loop;
end $$;
grant usage on schema private to anon;
grant select on public.profiles,public.rooms,public.memberships,public.assignments,public.submissions,public.reviews to anon;
grant update(name,description,archived) on public.rooms to anon;
grant delete on public.memberships to anon;
grant insert(room_id,title,description,starter_code,source_language,language,published,due_at),update(title,description,starter_code,source_language,language,published,due_at) on public.assignments to anon;
grant insert(assignment_id,student_id,source,source_language,language,status),update(source,source_language,language,status) on public.submissions to anon;
grant insert(assignment_id,student_id,score,feedback),update(score,feedback) on public.reviews to anon;

create or replace function private.owns_room(rid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.rooms where id=rid and owner_id=private.guest_id())
$$;
create or replace function private.in_room(rid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.guest_id() is not null and exists(select 1 from public.memberships where room_id=rid and user_id=private.guest_id())
$$;
create or replace function private.teaches_student(uid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships m join public.rooms r on r.id=m.room_id where m.user_id=uid and r.owner_id=private.guest_id())
$$;
create or replace function private.can_work(aid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.guest_id() is not null and exists(select 1 from public.assignments a join public.rooms r on r.id=a.room_id
 where a.id=aid and a.published and not r.archived and (a.due_at is null or a.due_at>now()) and private.in_room(a.room_id))
$$;
create or replace function private.can_review(aid uuid,uid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.guest_id() is not null and exists(select 1 from public.assignments a join public.submissions s on s.assignment_id=a.id
 where a.id=aid and s.student_id=uid and s.status='submitted' and private.owns_room(a.room_id))
$$;

create policy profiles_read on public.profiles for select to anon using(id=(select private.guest_id()));
create policy rooms_read on public.rooms for select to anon using(owner_id=(select private.guest_id()) or private.in_room(id));

create policy rooms_update on public.rooms for update to anon using(owner_id=(select private.guest_id())) with check(owner_id=(select private.guest_id()));
create policy memberships_read on public.memberships for select to anon using(user_id=(select private.guest_id()) or private.owns_room(room_id));
create policy memberships_delete on public.memberships for delete to anon using(private.owns_room(room_id));
create policy assignments_read on public.assignments for select to anon using(private.owns_room(room_id) or (published and private.in_room(room_id)));
create policy assignments_insert on public.assignments for insert to anon with check(private.owns_room(room_id));
create policy assignments_update on public.assignments for update to anon using(private.owns_room(room_id)) with check(private.owns_room(room_id));
create policy submissions_read on public.submissions for select to anon using(
 (student_id=(select private.guest_id()) and exists(select 1 from public.assignments a where a.id=assignment_id and private.in_room(a.room_id)))
 or (status='submitted' and exists(select 1 from public.assignments a where a.id=assignment_id and private.owns_room(a.room_id)))
);
create policy submissions_insert on public.submissions for insert to anon with check(student_id=(select private.guest_id()) and private.can_work(assignment_id));
create policy submissions_update on public.submissions for update to anon using(student_id=(select private.guest_id()) and status='draft' and private.can_work(assignment_id)) with check(student_id=(select private.guest_id()) and private.can_work(assignment_id));
create policy reviews_read on public.reviews for select to anon using(exists(select 1 from public.submissions s where s.assignment_id=reviews.assignment_id and s.student_id=reviews.student_id));
create policy reviews_insert on public.reviews for insert to anon with check(private.can_review(assignment_id,student_id));
create policy reviews_update on public.reviews for update to anon using(private.can_review(assignment_id,student_id)) with check(private.can_review(assignment_id,student_id));

revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function private.token_hash(),private.guest_id(),private.start_guest(text),private.create_room(text,text),private.join_room(text,text),private.owns_room(uuid),private.in_room(uuid),private.teaches_student(uuid),private.can_work(uuid),private.can_review(uuid,uuid) to anon;
revoke all on function public.start_guest(text),public.create_room(text,text),public.join_room(text,text) from public,anon,authenticated;
grant execute on function public.start_guest(text),public.create_room(text,text),public.join_room(text,text) to anon;

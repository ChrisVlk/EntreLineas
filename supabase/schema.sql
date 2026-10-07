-- Private classrooms. Authorization is enforced in PostgreSQL, not in the UI.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (length(btrim(display_name)) between 1 and 80)
);
create table public.rooms (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references public.profiles(id),
 name text not null check (length(btrim(name)) between 1 and 100),
 description text not null default '' check (length(description)<=2000),
 archived boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.memberships (
 room_id uuid not null references public.rooms(id) on delete cascade,
 user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
 email text not null default '',
 joined_at timestamptz not null default now(),
 primary key(room_id,user_id)
);
create table public.invitations (
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.rooms(id) on delete cascade,
 email text not null check (email=lower(btrim(email)) and email ~ '^[^[:space:]@]+@est\.ulsa\.edu\.ni$' and length(email)<=254),
 expires_at timestamptz not null default now()+interval '7 days',
 revoked boolean not null default false,
 created_at timestamptz not null default now(),
 unique(room_id,email)
);
create table public.assignments (
 id uuid primary key default gen_random_uuid(),
 room_id uuid not null references public.rooms(id) on delete cascade,
 title text not null check (length(btrim(title)) between 1 and 160),
 description text not null default '' check(length(description)<=12000),
 starter_code text not null default 'Algoritmo MiSolucion
    Escribir "Hola, mundo"
FinAlgoritmo' check(length(starter_code)<=50000),
 language text not null default 'python' check(language in ('python','javascript','c')),
 published boolean not null default false,
 due_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.submissions (
 assignment_id uuid not null references public.assignments(id) on delete cascade,
 student_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
 source text not null default '' check(length(source)<=50000),
 language text not null default 'python' check(language in ('python','javascript','c')),
 status text not null default 'draft' check(status in ('draft','submitted')),
 submitted_at timestamptz,
 updated_at timestamptz not null default now(),
 primary key(assignment_id,student_id)
);
create table public.reviews (
 assignment_id uuid not null,
 student_id uuid not null,
 score numeric(5,2) not null check(score between 0 and 100),
 feedback text not null default '' check(length(feedback)<=12000),
 updated_at timestamptz not null default now(),
 primary key(assignment_id,student_id),
 foreign key(assignment_id,student_id) references public.submissions(assignment_id,student_id) on delete cascade
);
create index rooms_owner_idx on public.rooms(owner_id);
create index memberships_user_idx on public.memberships(user_id);
create index invitations_email_idx on public.invitations(email);
create index assignments_room_idx on public.assignments(room_id);
create index submissions_student_idx on public.submissions(student_id);
create index reviews_student_idx on public.reviews(student_id);

-- These narrowly scoped private helpers avoid recursive RLS checks.
-- They always bind authorization to auth.uid(), never client-supplied metadata.
create function private.verified_email() returns text language sql stable security definer set search_path='' as $$
 select lower(u.email) from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null
 and split_part(lower(u.email),'@',2) in ('est.ulsa.edu.ni','ac.ulsa.edu.ni','ulsa.edu.ni')
 and exists(select 1 from auth.identities i where i.user_id=u.id and i.provider='google' and lower(i.identity_data->>'email')=lower(u.email))
$$;
create function private.is_teacher() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and split_part(private.verified_email(),'@',2) in ('ac.ulsa.edu.ni','ulsa.edu.ni')
$$;
create function private.owns_room(rid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_teacher() and exists(select 1 from public.rooms where id=rid and owner_id=auth.uid())
$$;
create function private.in_room(rid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.verified_email() is not null and exists(select 1 from public.memberships where room_id=rid and user_id=auth.uid())
$$;
create function private.invited(rid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.invitations i join public.rooms r on r.id=i.room_id
 where i.room_id=rid and i.email=private.verified_email() and not i.revoked and i.expires_at>now() and not r.archived)
$$;
create function private.teaches_student(uid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_teacher() and exists(select 1 from public.memberships m join public.rooms r on r.id=m.room_id where m.user_id=uid and r.owner_id=auth.uid())
$$;
create function private.can_work(aid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.assignments a join public.rooms r on r.id=a.room_id
 where a.id=aid and a.published and not r.archived and (a.due_at is null or a.due_at>now()) and private.in_room(a.room_id))
$$;
create function private.can_review(aid uuid,uid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.assignments a join public.submissions s on s.assignment_id=a.id
 where a.id=aid and s.student_id=uid and s.status='submitted' and private.owns_room(a.room_id))
$$;
revoke all on all functions in schema private from public,anon;
grant execute on all functions in schema private to authenticated;

alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.memberships enable row level security;
alter table public.invitations enable row level security;
alter table public.assignments enable row level security;
alter table public.submissions enable row level security;
alter table public.reviews enable row level security;
revoke all on public.profiles,public.rooms,public.memberships,public.invitations,public.assignments,public.submissions,public.reviews from anon,authenticated;
grant select on public.profiles,public.rooms,public.memberships,public.invitations,public.assignments,public.submissions,public.reviews to authenticated;
grant insert(id,display_name),update(display_name) on public.profiles to authenticated;
grant insert(name,description),update(name,description,archived) on public.rooms to authenticated;
grant insert(room_id,user_id),delete on public.memberships to authenticated;
grant insert(room_id,email,expires_at),update(revoked,expires_at) on public.invitations to authenticated;
grant insert(room_id,title,description,starter_code,language,published,due_at),update(title,description,starter_code,language,published,due_at) on public.assignments to authenticated;
grant insert(assignment_id,student_id,source,language,status),update(source,language,status) on public.submissions to authenticated;
grant insert(assignment_id,student_id,score,feedback),update(score,feedback) on public.reviews to authenticated;

create policy profiles_read on public.profiles for select to authenticated using(id=(select auth.uid()) or private.teaches_student(id));
create policy profiles_insert on public.profiles for insert to authenticated with check(id=(select auth.uid()) and private.verified_email() is not null);
create policy profiles_update on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy rooms_read on public.rooms for select to authenticated using(owner_id=(select auth.uid()) or private.in_room(id) or private.invited(id));
create policy rooms_insert on public.rooms for insert to authenticated with check(owner_id=(select auth.uid()) and private.is_teacher());
create policy rooms_update on public.rooms for update to authenticated using(owner_id=(select auth.uid())) with check(owner_id=(select auth.uid()));
create policy memberships_read on public.memberships for select to authenticated using(user_id=(select auth.uid()) or private.owns_room(room_id));
create policy memberships_insert on public.memberships for insert to authenticated with check(user_id=(select auth.uid()) and private.invited(room_id) and not private.owns_room(room_id));
create policy memberships_delete on public.memberships for delete to authenticated using(private.owns_room(room_id));
create policy invitations_read on public.invitations for select to authenticated using(private.owns_room(room_id) or (email=private.verified_email() and not revoked and expires_at>now()));
create policy invitations_insert on public.invitations for insert to authenticated with check(private.owns_room(room_id) and expires_at>now() and expires_at<=now()+interval '30 days');
create policy invitations_update on public.invitations for update to authenticated using(private.owns_room(room_id)) with check(private.owns_room(room_id) and expires_at<=now()+interval '30 days');
create policy assignments_read on public.assignments for select to authenticated using(private.owns_room(room_id) or (published and private.in_room(room_id)));
create policy assignments_insert on public.assignments for insert to authenticated with check(private.owns_room(room_id));
create policy assignments_update on public.assignments for update to authenticated using(private.owns_room(room_id)) with check(private.owns_room(room_id));
create policy submissions_read on public.submissions for select to authenticated using(
 (student_id=(select auth.uid()) and exists(select 1 from public.assignments a where a.id=assignment_id and private.in_room(a.room_id)))
 or (status='submitted' and exists(select 1 from public.assignments a where a.id=assignment_id and private.owns_room(a.room_id)))
);
create policy submissions_insert on public.submissions for insert to authenticated with check(student_id=(select auth.uid()) and private.can_work(assignment_id));
create policy submissions_update on public.submissions for update to authenticated using(student_id=(select auth.uid()) and status='draft' and private.can_work(assignment_id)) with check(student_id=(select auth.uid()) and private.can_work(assignment_id));
create policy reviews_read on public.reviews for select to authenticated using(exists(select 1 from public.submissions s where s.assignment_id=reviews.assignment_id and s.student_id=reviews.student_id));
create policy reviews_insert on public.reviews for insert to authenticated with check(private.can_review(assignment_id,student_id));
create policy reviews_update on public.reviews for update to authenticated using(private.can_review(assignment_id,student_id)) with check(private.can_review(assignment_id,student_id));

create function private.submission_times() returns trigger language plpgsql set search_path='' as $$
 begin
 if TG_OP='UPDATE' and OLD.status='submitted' then raise exception 'La entrega ya está cerrada.'; end if;
 NEW.updated_at=now();
 NEW.submitted_at=case when NEW.status='submitted' then now() else null end;
 return NEW;
 end;
$$;
create trigger submission_times before insert or update on public.submissions for each row execute function private.submission_times();
create function private.review_time() returns trigger language plpgsql set search_path='' as $$ begin NEW.updated_at=now(); return NEW; end; $$;
create trigger review_time before insert or update on public.reviews for each row execute function private.review_time();
create function private.membership_email() returns trigger language plpgsql set search_path='' as $$ begin NEW.email=private.verified_email(); return NEW; end; $$;
create trigger membership_email before insert on public.memberships for each row execute function private.membership_email();
revoke all on function private.membership_email() from public,anon,authenticated;
revoke all on function private.submission_times(),private.review_time() from public,anon,authenticated;

-- Accept and leave membership changes to normal RLS; no public elevated RPCs.

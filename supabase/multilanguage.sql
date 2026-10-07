alter table public.assignments add column source_language text not null default 'pseint' check(source_language in ('pseint','python','javascript','c'));
alter table public.submissions add column source_language text not null default 'pseint' check(source_language in ('pseint','python','javascript','c'));
alter table public.assignments drop constraint assignments_language_check;
alter table public.assignments add constraint assignments_language_check check(language in ('pseint','python','javascript','c'));
alter table public.submissions drop constraint submissions_language_check;
alter table public.submissions add constraint submissions_language_check check(language in ('pseint','python','javascript','c'));
grant insert(source_language),update(source_language) on public.assignments,public.submissions to authenticated;

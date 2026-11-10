-- ONLY run this if you ALREADY ran the old schema.sql (the 72-hour version) in this Supabase project.
-- If you are starting fresh, just run schema.sql instead — it already includes these changes.
-- Safe to run more than once.

-- 1) Raise the per-entry check from 72 to 720 hours.
alter table public.yap_hours drop constraint if exists yap_hours_hours_check;
alter table public.yap_hours add constraint yap_hours_hours_check check (hours > 0 and hours <= 720);

-- 2) Raise the total-per-student ceiling to 720 hours.
create or replace function public.enforce_yap_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare existing_total numeric;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.student_id::text, 42));
  if not exists (select 1 from public.students where id = new.student_id and program = 'YAP' and archived_at is null) then
    raise exception 'Only active YAP students can receive hour entries';
  end if;
  select coalesce(sum(hours), 0) into existing_total from public.yap_hours where student_id = new.student_id;
  if existing_total + new.hours > 720 then
    raise exception 'YAP hour limit is 720. Current: %, attempted additional: %', existing_total, new.hours;
  end if;
  return new;
end; $$;
revoke all on function public.enforce_yap_limit() from public, anon, authenticated;

-- 3) Security fix: supervisors could see/add hours for students NOT assigned to them.
drop policy if exists "teacher and assigned supervisor read hours" on public.yap_hours;
create policy "teacher and assigned supervisor read hours" on public.yap_hours for select to authenticated
  using (
    exists (select 1 from public.students s where s.id = yap_hours.student_id and s.owner_id = (select auth.uid()))
    or exists (select 1 from public.supervisor_assignments a where a.student_id = yap_hours.student_id and a.supervisor_user_id = (select auth.uid()))
  );
drop policy if exists "teacher or assigned supervisor adds hours" on public.yap_hours;
create policy "teacher or assigned supervisor adds hours" on public.yap_hours for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and (
      exists (select 1 from public.students s where s.id = yap_hours.student_id and s.owner_id = (select auth.uid()) and s.program = 'YAP' and s.archived_at is null)
      or exists (select 1 from public.supervisor_assignments a where a.student_id = yap_hours.student_id and a.supervisor_user_id = (select auth.uid()))
    )
  );

-- Timestamp WBL/YAP web app database; run ONCE in a new Supabase project SQL editor.
-- Never put your service_role key in the browser or source code.
-- Every exposed table has Row Level Security (RLS).

create extension if not exists pgcrypto;

create table public.teachers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  retention_enabled boolean not null default true,
  acknowledged_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.teachers(user_id) on delete cascade,
  first_name text not null check (length(trim(first_name)) > 0),
  last_name text not null check (length(trim(last_name)) > 0),
  graduation_year integer check (graduation_year between 1900 and 2100),
  grade text not null default '',
  program text not null default 'WBL' check (program in ('WBL','YAP')),
  employer text not null default '',
  address text not null default '',
  phone text not null default '',
  archived_at timestamptz,
  created_at timestamptz not null default now()
);
create index students_owner_archive on public.students(owner_id, archived_at);
create index students_owner_grad on public.students(owner_id, graduation_year);

create table public.student_notes (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index notes_student on public.student_notes(student_id, created_at desc);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.teachers(user_id) on delete cascade,
  trip_date date not null,
  origin text not null default '',
  round_trip boolean not null default true,
  estimated_miles numeric(9,2),
  actual_miles numeric(9,2) check (actual_miles is null or actual_miles >= 0),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);
create index trips_owner_date on public.trips(owner_id, trip_date desc);

create table public.trip_stops (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  visit_kind text not null check (visit_kind in ('In person','Zoom','Phone call','Message')),
  stop_order integer not null,
  visited_at timestamptz,
  unique(trip_id, student_id)
);
create index trip_stops_trip on public.trip_stops(trip_id, stop_order);
create index trip_stops_student on public.trip_stops(student_id);

create table public.visits (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  trip_id uuid references public.trips(id) on delete set null,
  stop_id uuid unique references public.trip_stops(id) on delete set null,
  kind text not null check (kind in ('In person','Zoom','Phone call','Message')),
  visited_at timestamptz not null default now(),
  note text not null default '',
  created_by uuid not null references auth.users(id)
);
create index visits_student_time on public.visits(student_id, visited_at desc);
create index visits_trip on public.visits(trip_id);

create table public.supervisor_assignments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  supervisor_user_id uuid not null references auth.users(id) on delete cascade,
  supervisor_email text not null,
  created_at timestamptz not null default now(),
  unique(student_id, supervisor_user_id)
);
create index supervisor_lookup on public.supervisor_assignments(supervisor_user_id, student_id);

create table public.yap_hours (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  hours numeric(5,2) not null check (hours > 0 and hours <= 720),
  performed_on date not null,
  note text not null default '',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index yap_hours_student_date on public.yap_hours(student_id, performed_on desc);

-- Central authorization: teacher owns roster; supervisors only access assigned YAP hour rows.
alter table public.teachers enable row level security;
alter table public.students enable row level security;
alter table public.student_notes enable row level security;
alter table public.trips enable row level security;
alter table public.trip_stops enable row level security;
alter table public.visits enable row level security;
alter table public.supervisor_assignments enable row level security;
alter table public.yap_hours enable row level security;

create policy "teacher reads own settings" on public.teachers for select to authenticated
  using (user_id = (select auth.uid()));
create policy "teacher updates own settings" on public.teachers for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "teacher reads roster" on public.students for select to authenticated
  using (owner_id = (select auth.uid()));
create policy "teacher creates roster" on public.students for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy "teacher updates roster" on public.students for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "teacher deletes roster" on public.students for delete to authenticated
  using (owner_id = (select auth.uid()));

create policy "teacher reads notes" on public.student_notes for select to authenticated
  using (exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())));
create policy "teacher inserts notes" on public.student_notes for insert to authenticated
  with check (created_by = (select auth.uid()) and exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())));
create policy "teacher edits notes" on public.student_notes for update to authenticated
  using (exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())));
create policy "teacher deletes notes" on public.student_notes for delete to authenticated
  using (exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())));

create policy "teacher reads trips" on public.trips for select to authenticated
  using (owner_id = (select auth.uid()));
create policy "teacher inserts trips" on public.trips for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy "teacher updates trips" on public.trips for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "teacher deletes trips" on public.trips for delete to authenticated
  using (owner_id = (select auth.uid()));

create policy "teacher reads trip stops" on public.trip_stops for select to authenticated
  using (exists (select 1 from public.trips t where t.id = trip_id and t.owner_id = (select auth.uid())));
create policy "teacher inserts trip stops" on public.trip_stops for insert to authenticated
  with check (
    exists (select 1 from public.trips t where t.id = trip_id and t.owner_id = (select auth.uid()))
    and exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid()) and s.archived_at is null)
  );
create policy "teacher deletes trip stops" on public.trip_stops for delete to authenticated
  using (exists (select 1 from public.trips t where t.id = trip_id and t.owner_id = (select auth.uid())));

create policy "teacher reads visits" on public.visits for select to authenticated
  using (exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())));
create policy "teacher adds manual visits" on public.visits for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and stop_id is null
    and (trip_id is null)
    and exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid()))
  );
create policy "teacher deletes visits" on public.visits for delete to authenticated
  using (exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())));

create policy "teacher or assigned supervisor reads assignments" on public.supervisor_assignments for select to authenticated
  using (supervisor_user_id = (select auth.uid())
    or exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())));
-- Assignment inserts/removals use secure RPCs, not direct table writes.

create policy "teacher and assigned supervisor read hours" on public.yap_hours for select to authenticated
  using (
    exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid()))
    or exists (select 1 from public.supervisor_assignments a where a.student_id = yap_hours.student_id and a.supervisor_user_id = (select auth.uid()))
  );
create policy "teacher or assigned supervisor adds hours" on public.yap_hours for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and (
      exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid()) and s.program = 'YAP' and s.archived_at is null)
      or exists (select 1 from public.supervisor_assignments a where a.student_id = yap_hours.student_id and a.supervisor_user_id = (select auth.uid()))
    )
  );
create policy "teacher deletes incorrect hours" on public.yap_hours for delete to authenticated
  using (exists (select 1 from public.students s where s.id = student_id and s.owner_id = (select auth.uid())));

-- Database-enforced 720-hour maximum (serializes concurrent additions for same student).
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
create trigger check_yap_hour_ceiling before insert on public.yap_hours for each row execute function public.enforce_yap_limit();

-- Archiving pauses a YAP placement and immediately revokes external supervisor access.
-- Teachers can restore the student next year and re-assign a supervisor.
create or replace function public.revoke_archived_yap_access()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.archived_at is null and new.archived_at is not null then
    delete from public.supervisor_assignments where student_id = new.id;
  end if;
  return new;
end; $$;
create trigger revoke_on_archive after update of archived_at on public.students
for each row execute function public.revoke_archived_yap_access();

-- Authenticated role discovery; must not expose anyone else's account list.
create or replace function public.account_role()
returns text language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'Not signed in'; end if;
  if exists (select 1 from public.teachers t where t.user_id = (select auth.uid())) then return 'teacher'; end if;
  if exists (select 1 from public.supervisor_assignments a where a.supervisor_user_id = (select auth.uid())) then return 'supervisor'; end if;
  return 'pending';
end; $$;

-- Teachers assign an already-registered, email-verified supervisor account by its exact email.
create or replace function public.assign_supervisor(p_student_id uuid, p_email text)
returns void language plpgsql security definer set search_path = '' as $$
declare supervisor_id uuid; trimmed_email text;
begin
  if (select auth.uid()) is null then raise exception 'Not signed in'; end if;
  if not exists (select 1 from public.students s where s.id = p_student_id and s.owner_id = (select auth.uid()) and s.program = 'YAP') then
    raise exception 'Only the teacher of a YAP student can add supervisors';
  end if;
  trimmed_email := lower(trim(p_email));
  if length(trimmed_email) < 3 then raise exception 'Enter a valid supervisor email'; end if;
  select id into supervisor_id from auth.users where lower(email) = trimmed_email and email_confirmed_at is not null limit 1;
  if supervisor_id is null then raise exception 'Supervisor must sign up and confirm their email first'; end if;
  if supervisor_id = (select auth.uid()) then raise exception 'Teacher does not need supervisor access'; end if;
  insert into public.supervisor_assignments(student_id, supervisor_user_id, supervisor_email)
    values(p_student_id, supervisor_id, trimmed_email)
    on conflict (student_id, supervisor_user_id) do nothing;
end; $$;

create or replace function public.remove_supervisor(p_assignment_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'Not signed in'; end if;
  delete from public.supervisor_assignments a
  using public.students s
  where a.id = p_assignment_id and a.student_id = s.id and s.owner_id = (select auth.uid());
end; $$;

-- Dedicated limited-data view via RPC; supervisors never SELECT students' phone/address/notes.
create or replace function public.my_yap_students()
returns table(student_id uuid, full_name text, graduation_year integer, total_hours numeric)
language sql security definer set search_path = '' as $$
  select s.id, trim(s.first_name || ' ' || s.last_name), s.graduation_year,
         coalesce((select sum(y.hours) from public.yap_hours y where y.student_id = s.id), 0)
  from public.supervisor_assignments a
  join public.students s on s.id = a.student_id
  where a.supervisor_user_id = (select auth.uid()) and s.program = 'YAP' and s.archived_at is null
  order by s.last_name, s.first_name;
$$;

-- Atomic mark-as-visited: no half-completed stop or double-recorded visit.
create or replace function public.complete_trip_stop(p_stop_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare st record;
begin
  if (select auth.uid()) is null then raise exception 'Not signed in'; end if;
  select ts.*, t.owner_id, t.completed_at into st
  from public.trip_stops ts join public.trips t on t.id = ts.trip_id
  where ts.id = p_stop_id for update of ts;
  if not found then raise exception 'Stop not found'; end if;
  if st.owner_id <> (select auth.uid()) then raise exception 'Access denied'; end if;
  if st.completed_at is not null then raise exception 'Session already completed'; end if;
  if st.visited_at is not null then return; end if;
  update public.trip_stops set visited_at = now() where id = st.id;
  insert into public.visits(student_id, trip_id, stop_id, kind, visited_at, created_by)
    values(st.student_id, st.trip_id, st.id, st.visit_kind, now(), (select auth.uid()));
end; $$;

-- Expired means JULY 1 OF THE YEAR AFTER graduation_year; does not erase exports.
create or replace function public.preview_retention()
returns integer language sql security definer set search_path = '' as $$
  select count(*)::integer from public.students s
  where s.owner_id = (select auth.uid()) and s.graduation_year is not null
    and pg_catalog.make_date(s.graduation_year + 1, 7, 1) <= current_date;
$$;

create or replace function public.apply_retention()
returns integer language plpgsql security definer set search_path = '' as $$
declare ids uuid[]; deleted_count integer;
begin
  if (select auth.uid()) is null then raise exception 'Not signed in'; end if;
  if not exists (select 1 from public.teachers t where t.user_id = (select auth.uid()) and t.retention_enabled and t.acknowledged_at is not null) then
    return 0;
  end if;
  select coalesce(array_agg(s.id), '{}'::uuid[]) into ids from public.students s
  where s.owner_id = (select auth.uid()) and s.graduation_year is not null
    and pg_catalog.make_date(s.graduation_year + 1, 7, 1) <= current_date;
  deleted_count := cardinality(ids);
  if deleted_count = 0 then return 0; end if;
  -- Trip route/address info would retain expired student context: remove whole linked trips.
  delete from public.trips t where t.owner_id = (select auth.uid()) and exists (
    select 1 from public.trip_stops st where st.trip_id = t.id and st.student_id = any(ids)
  );
  delete from public.students where owner_id = (select auth.uid()) and id = any(ids);
  return deleted_count;
end; $$;

-- Teacher-initiated full reset: delete own students, their linked records, and trips.
create or replace function public.reset_my_data()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or not exists
    (select 1 from public.teachers t where t.user_id = (select auth.uid())) then
      raise exception 'Teacher authorization required';
  end if;
  delete from public.trips where owner_id = (select auth.uid());
  delete from public.students where owner_id = (select auth.uid());
end; $$;

-- Explicit, narrow API privileges (new Supabase projects do not auto-expose SQL objects).
revoke all on public.teachers, public.students, public.student_notes, public.trips, public.trip_stops,
  public.visits, public.supervisor_assignments, public.yap_hours from anon, authenticated;
grant usage on schema public to authenticated;
grant select, update on public.teachers to authenticated;
grant select, insert, update, delete on public.students to authenticated;
grant select, insert, update, delete on public.student_notes to authenticated;
grant select, insert, update, delete on public.trips to authenticated;
grant select, insert, delete on public.trip_stops to authenticated;
grant select, insert, delete on public.visits to authenticated;
grant select on public.supervisor_assignments to authenticated;
grant select, insert, delete on public.yap_hours to authenticated;

revoke all on function public.enforce_yap_limit(), public.account_role(), public.assign_supervisor(uuid, text),
 public.remove_supervisor(uuid), public.my_yap_students(), public.complete_trip_stop(uuid),
 public.preview_retention(), public.apply_retention(), public.reset_my_data(), public.revoke_archived_yap_access() from public, anon, authenticated;
grant execute on function public.account_role(), public.assign_supervisor(uuid, text),
 public.remove_supervisor(uuid), public.my_yap_students(), public.complete_trip_stop(uuid),
 public.preview_retention(), public.apply_retention(), public.reset_my_data() to authenticated;
-- enforce_yap_limit is invoked only by its trigger.

-- Confirm dashboard → Integrations → Data API exposes public schema / tables, if disabled.
-- NEXT: the teacher signs up, then run this ONE-TIME authorization separately:
-- insert into public.teachers(user_id)
-- select id from auth.users where lower(email) = lower('teacher@example.edu')
-- on conflict do nothing;

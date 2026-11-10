-- Run in Supabase → SQL Editor AFTER the teacher's account exists
-- (Authentication → Users → Add user, or the teacher signed up on the site).
-- Replace the email below with the teacher's real email, then click Run.

insert into public.teachers(user_id)
select id from auth.users
where lower(email) = lower('teacher@school.edu')
on conflict do nothing;

-- Check it worked (should show 1 row with the teacher's email):
select u.email, t.created_at
from public.teachers t join auth.users u on u.id = t.user_id;

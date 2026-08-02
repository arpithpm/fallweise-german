-- Fallweise learning foundation
-- User-owned learning data is protected by RLS and cascades on account deletion.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text check (char_length(display_name) <= 80),
  current_level text not null default 'A1' check (current_level in ('A1', 'A2', 'B1')),
  weekly_goal_minutes integer not null default 35 check (weekly_goal_minutes between 5 and 1400),
  timezone text not null default 'Europe/Berlin' check (char_length(timezone) between 1 and 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  speech_rate numeric(4,2) not null default 0.88 check (speech_rate in (0.72, 0.88, 1.00)),
  daily_review_limit integer not null default 15 check (daily_review_limit between 5 and 100),
  sound_enabled boolean not null default true,
  reduced_motion boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id text not null check (char_length(lesson_id) between 1 and 120),
  status text not null default 'not_started' check (status in ('not_started', 'in_progress', 'completed')),
  mastery numeric(5,4) not null default 0 check (mastery between 0 and 1),
  current_step integer not null default 0 check (current_step >= 0),
  total_steps integer not null default 0 check (total_steps >= 0),
  started_at timestamptz,
  completed_at timestamptz,
  last_activity_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, lesson_id),
  check (current_step <= total_steps or total_steps = 0)
);

create table public.skill_mastery (
  user_id uuid not null references auth.users(id) on delete cascade,
  skill_id text not null check (char_length(skill_id) between 1 and 160),
  level text not null check (level in ('A1', 'A2', 'B1')),
  domain text not null check (domain in ('vocabulary', 'grammar', 'listening', 'speaking', 'reading', 'writing', 'pronunciation')),
  mastery numeric(5,4) not null default 0 check (mastery between 0 and 1),
  attempts integer not null default 0 check (attempts >= 0),
  correct_attempts integer not null default 0 check (correct_attempts between 0 and attempts),
  current_streak integer not null default 0 check (current_streak >= 0),
  last_practised_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, skill_id)
);

create table public.review_items (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id text not null check (char_length(item_id) between 1 and 180),
  skill_id text not null check (char_length(skill_id) between 1 and 160),
  item_type text not null check (item_type in ('meaning', 'article', 'plural', 'spelling', 'listening', 'grammar', 'sentence', 'speaking')),
  interval_days integer not null default 0 check (interval_days between 0 and 3650),
  ease_factor numeric(4,2) not null default 2.50 check (ease_factor between 1.30 and 3.50),
  repetitions integer not null default 0 check (repetitions >= 0),
  lapses integer not null default 0 check (lapses >= 0),
  due_at timestamptz not null default now(),
  last_reviewed_at timestamptz,
  suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, item_id)
);

create table public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_type text not null default 'lesson' check (session_type in ('lesson', 'review', 'practice', 'assessment')),
  level text check (level in ('A1', 'A2', 'B1')),
  lesson_id text check (lesson_id is null or char_length(lesson_id) between 1 and 120),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  items_attempted integer not null default 0 check (items_attempted >= 0),
  correct_count integer not null default 0 check (correct_count between 0 and items_attempted),
  created_at timestamptz not null default now(),
  check (ended_at is null or ended_at >= started_at)
);

create table public.exercise_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid references public.study_sessions(id) on delete set null,
  exercise_id text not null check (char_length(exercise_id) between 1 and 180),
  skill_id text not null check (char_length(skill_id) between 1 and 160),
  lesson_id text check (lesson_id is null or char_length(lesson_id) between 1 and 120),
  exercise_type text not null check (exercise_type in ('choice', 'fill_blank', 'word_order', 'matching', 'listening', 'dictation', 'speaking', 'sentence_builder', 'correction')),
  answer jsonb not null default '{}'::jsonb,
  correct boolean not null,
  hints_used integer not null default 0 check (hints_used >= 0),
  response_ms integer check (response_ms is null or response_ms >= 0),
  misconception text check (misconception is null or char_length(misconception) <= 120),
  attempted_at timestamptz not null default now()
);

create index lesson_progress_activity_idx on public.lesson_progress (user_id, last_activity_at desc);
create index skill_mastery_weak_idx on public.skill_mastery (user_id, mastery, last_practised_at);
create index review_items_due_idx on public.review_items (user_id, due_at) where not suspended;
create index exercise_attempts_history_idx on public.exercise_attempts (user_id, attempted_at desc);
create index exercise_attempts_skill_idx on public.exercise_attempts (user_id, skill_id, attempted_at desc);
create index study_sessions_history_idx on public.study_sessions (user_id, started_at desc);

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger user_settings_set_updated_at before update on public.user_settings
for each row execute function public.set_updated_at();
create trigger lesson_progress_set_updated_at before update on public.lesson_progress
for each row execute function public.set_updated_at();
create trigger skill_mastery_set_updated_at before update on public.skill_mastery
for each row execute function public.set_updated_at();
create trigger review_items_set_updated_at before update on public.review_items
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'name'));
  insert into public.user_settings (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.skill_mastery enable row level security;
alter table public.review_items enable row level security;
alter table public.study_sessions enable row level security;
alter table public.exercise_attempts enable row level security;

create policy "profiles_select_own" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "profiles_update_own" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "settings_select_own" on public.user_settings for select to authenticated using ((select auth.uid()) = user_id);
create policy "settings_update_own" on public.user_settings for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "lesson_progress_all_own" on public.lesson_progress for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "skill_mastery_all_own" on public.skill_mastery for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "review_items_all_own" on public.review_items for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "study_sessions_all_own" on public.study_sessions for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "exercise_attempts_all_own" on public.exercise_attempts for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create or replace function public.get_daily_review(requested_limit integer default 15)
returns setof public.review_items
language sql
stable
security invoker
set search_path = ''
as $$
  select r.*
  from public.review_items r
  where r.user_id = (select auth.uid())
    and not r.suspended
    and r.due_at <= now()
  order by r.due_at asc
  limit least(greatest(requested_limit, 1), 100);
$$;

revoke all on function public.get_daily_review(integer) from public;
grant execute on function public.get_daily_review(integer) to authenticated;

create or replace view public.learning_dashboard
with (security_invoker = true)
as
select
  p.id as user_id,
  p.current_level,
  p.weekly_goal_minutes,
  count(distinct lp.lesson_id) filter (where lp.status = 'completed') as completed_lessons,
  coalesce(avg(sm.mastery), 0)::numeric(5,4) as average_mastery,
  count(distinct ri.item_id) filter (where not ri.suspended and ri.due_at <= now()) as reviews_due
from public.profiles p
left join public.lesson_progress lp on lp.user_id = p.id
left join public.skill_mastery sm on sm.user_id = p.id
left join public.review_items ri on ri.user_id = p.id
where p.id = (select auth.uid())
group by p.id, p.current_level, p.weekly_goal_minutes;

grant select on public.learning_dashboard to authenticated;

comment on table public.skill_mastery is 'Mastery is tracked independently per stable skill ID on a 0–1 scale.';
comment on table public.review_items is 'Spaced-repetition state for one user/item pair.';
comment on table public.exercise_attempts is 'Append-only learning evidence used to update mastery and diagnose misconceptions.';

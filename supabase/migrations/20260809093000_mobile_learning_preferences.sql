create table public.learner_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current_level text not null default 'A1' check (current_level in ('A1', 'A2', 'B1')),
  weekly_goal_minutes integer not null default 35 check (weekly_goal_minutes between 5 and 1400),
  learning_goals text[] not null default array['dailyLife', 'conversation']::text[],
  reminder_enabled boolean not null default false,
  reminder_hour integer not null default 19 check (reminder_hour between 0 and 23),
  reminder_minute integer not null default 0 check (reminder_minute between 0 and 59),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger learner_preferences_set_updated_at before update on public.learner_preferences
for each row execute function public.set_updated_at();

alter table public.learner_preferences enable row level security;

create policy "learner_preferences_all_own" on public.learner_preferences
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

comment on table public.learner_preferences is 'Mobile learning goals and local-reminder preferences; notification delivery remains on device.';

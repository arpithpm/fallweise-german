-- Cross-device daily practice evidence for the native consistency calendar.
create table public.practice_days (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  attempts integer not null default 0 check (attempts >= 0),
  correct_attempts integer not null default 0 check (correct_attempts between 0 and attempts),
  lesson_steps integer not null default 0 check (lesson_steps >= 0),
  completed_lessons integer not null default 0 check (completed_lessons >= 0),
  focused_seconds integer not null default 0 check (focused_seconds >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

create trigger practice_days_set_updated_at before update on public.practice_days
for each row execute function public.set_updated_at();

create or replace function public.preserve_practice_day()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.attempts = greatest(old.attempts, new.attempts);
  new.correct_attempts = greatest(old.correct_attempts, new.correct_attempts);
  new.lesson_steps = greatest(old.lesson_steps, new.lesson_steps);
  new.completed_lessons = greatest(old.completed_lessons, new.completed_lessons);
  new.focused_seconds = greatest(old.focused_seconds, new.focused_seconds);
  return new;
end;
$$;

create trigger practice_days_preserve_progress before update on public.practice_days
for each row execute function public.preserve_practice_day();

alter table public.practice_days enable row level security;

create policy "practice_days_all_own" on public.practice_days
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create index practice_days_history_idx on public.practice_days (user_id, day desc);

comment on table public.practice_days is
'Monotonic daily learning evidence. A meaningful day is one completed lesson or at least five retrieval attempts.';

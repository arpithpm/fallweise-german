-- Lesson progress is monotonic across devices and out-of-order network writes.
create or replace function public.preserve_lesson_progress()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.status = 'completed' and new.status <> 'completed' then
    new.status := old.status;
    new.current_step := old.current_step;
    new.mastery := old.mastery;
    new.completed_at := old.completed_at;
  elsif new.status <> 'completed' and new.current_step < old.current_step then
    new.current_step := old.current_step;
    new.mastery := greatest(old.mastery, new.mastery);
  end if;
  new.total_steps := greatest(old.total_steps, new.total_steps);
  new.last_activity_at := greatest(old.last_activity_at, new.last_activity_at);
  return new;
end;
$$;

drop trigger if exists lesson_progress_preserve_progress on public.lesson_progress;
create trigger lesson_progress_preserve_progress
before update on public.lesson_progress
for each row execute function public.preserve_lesson_progress();

comment on function public.preserve_lesson_progress() is
  'Prevents delayed or cross-device writes from moving a learner backward or reopening a completed lesson.';

-- Skycast: saved cities backup. Run once in Supabase → SQL Editor.
-- Also enable Authentication → Sign In / Providers → "Allow anonymous sign-ins".

create table if not exists public.saved_cities (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  -- Same JSON list the app keeps in shared_preferences (CityDto).
  cities jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.saved_cities enable row level security;

-- Each (anonymous) user sees and writes only their own row.
create policy "own row: select" on public.saved_cities
  for select to authenticated using (user_id = (select auth.uid()));
create policy "own row: insert" on public.saved_cities
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "own row: update" on public.saved_cities
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

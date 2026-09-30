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

-- Push alerts: one row per anonymous user, written by the app
-- (alerts_sync_ds.dart) and read by the check-alerts Edge Function with the
-- service role. Setup steps: supabase/functions/check-alerts/README.md.
create table if not exists public.alert_subscriptions (
  user_id uuid primary key default auth.uid()
    references auth.users (id) on delete cascade,
  fcm_token text not null,
  -- Rounded to 2 decimals (~1 km) by the app.
  lat double precision not null,
  lon double precision not null,
  -- 'vi' or 'en', for the notification text.
  locale text not null default 'vi',
  fahrenheit boolean not null default false,
  -- AlertType names: rain, uv, air, heat.
  types text[] not null default '{rain,uv,air,heat}',
  -- HealthProfile names (respiratory, children, elderly): lower thresholds.
  health text[] not null default '{}',
  -- Alert type → last time it was sent, for the per-type cooldown.
  last_sent jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.alert_subscriptions enable row level security;

create policy "own row: select" on public.alert_subscriptions
  for select to authenticated using (user_id = (select auth.uid()));
create policy "own row: insert" on public.alert_subscriptions
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "own row: update" on public.alert_subscriptions
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "own row: delete" on public.alert_subscriptions
  for delete to authenticated using (user_id = (select auth.uid()));

-- Added with health profiles; a no-op on tables created from this file.
alter table public.alert_subscriptions
  add column if not exists health text[] not null default '{}';

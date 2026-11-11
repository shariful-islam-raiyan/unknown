-- UNKNOWN Phase 1 database setup
-- Run this entire file in Supabase Dashboard > SQL Editor > New query.
-- It creates a private player profile for each Supabase Auth user.
-- Never put the Supabase service_role key in frontend code.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique
    check (char_length(username) between 3 and 20)
    check (username ~ '^[A-Za-z0-9_]+$'),
  total_score bigint not null default 0 check (total_score >= 0),
  events_completed integer not null default 0 check (events_completed >= 0),
  mysteries_solved integer not null default 0 check (mysteries_solved >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Only the authenticated owner can read their own profile in Phase 1.
drop policy if exists "Players can read own profile" on public.profiles;
create policy "Players can read own profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) = id);

-- The browser may create/update only the signed-in user's own profile.
drop policy if exists "Players can insert own profile" on public.profiles;
create policy "Players can insert own profile"
on public.profiles for insert
to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "Players can update own profile" on public.profiles;
create policy "Players can update own profile"
on public.profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

grant select, insert, update on public.profiles to authenticated;
revoke all on public.profiles from anon;

-- Automatically create a profile after successful Auth signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_username text;
begin
  requested_username := coalesce(
    new.raw_user_meta_data ->> 'username',
    split_part(new.email, '@', 1)
  );

  insert into public.profiles (id, username)
  values (new.id, requested_username);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Keep updated_at current.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

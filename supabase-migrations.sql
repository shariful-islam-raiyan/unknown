-- d:/Unknown/supabase-migrations.sql
-- Run this file in Supabase → SQL editor → New query → Paste/Upload → Run
-- ------------------------------------------------------------
-- সমস্ত টেবিল গেম UNKNOWN‑এর জন্য (Phases 2‑6)
-- ------------------------------------------------------------

-- 1️⃣ PLAYER GAME STATE (JSONB) – একটিমাত্র রো প্রতি ইউজার
create table if not exists public.game_saves (
  id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.game_saves enable row level security;

-- select
create policy "Players can read own save"
  on public.game_saves for select
  to authenticated
  using (auth.uid() = id);

-- insert
create policy "Players can insert own save"
  on public.game_saves for insert
  to authenticated
  with check (auth.uid() = id);

-- update
create policy "Players can update own save"
  on public.game_saves for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant select, insert, update on public.game_saves to authenticated;
revoke all on public.game_saves from anon;

-----------------------------------------------------------------
-- 2️⃣ STORY EVENTS – ইমমিটেবল লগ
-----------------------------------------------------------------
create table if not exists public.story_events (
  event_id uuid primary key default gen_random_uuid(),
  player_id uuid references auth.users(id) on delete cascade,
  timestamp timestamptz not null default now(),
  event_index integer not null,
  image_url text,
  title text not null,
  description text not null,
  question text not null,
  choices jsonb not null,               -- [{id:"A",text:"…"}]
  player_choice text,
  outcome jsonb,
  is_mystery boolean not null default false,
  foreign key (player_id) references auth.users(id)
);
alter table public.story_events enable row level security;

create policy "Players see own events"
  on public.story_events for select
  to authenticated
  using (auth.uid() = player_id);

grant select on public.story_events to authenticated;
revoke all on public.story_events from anon;

-----------------------------------------------------------------
-- 3️⃣ INVENTORY – key/value bag
-----------------------------------------------------------------
create table if not exists public.inventory (
  player_id uuid primary key references auth.users(id) on delete cascade,
  items jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.inventory enable row level security;

-- select
create policy "Players can read own inventory"
  on public.inventory for select
  to authenticated
  using (auth.uid() = player_id);

-- insert
create policy "Players can insert own inventory"
  on public.inventory for insert
  to authenticated
  with check (auth.uid() = player_id);

-- update
create policy "Players can update own inventory"
  on public.inventory for update
  to authenticated
  using (auth.uid() = player_id)
  with check (auth.uid() = player_id);

grant select, insert, update on public.inventory to authenticated;
revoke all on public.inventory from anon;

-----------------------------------------------------------------
-- 4️⃣ MYSTERIES – মিস্ট্রি মেটাডেটা
-----------------------------------------------------------------
create table if not exists public.mysteries (
  mystery_id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  created_at timestamptz not null default now()
);
grant select on public.mysteries to authenticated;
revoke all on public.mysteries from anon;

-----------------------------------------------------------------
-- 5️⃣ ACHIEVEMENTS & PLAYER‑ACHIEVEMENTS
-----------------------------------------------------------------
create table if not exists public.achievements (
  achievement_id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null,
  points integer not null,
  icon_url text
);
create table if not exists public.player_achievements (
  player_id uuid references auth.users(id) on delete cascade,
  achievement_id uuid references public.achievements(achievement_id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (player_id, achievement_id)
);
alter table public.player_achievements enable row level security;

-- select
create policy "Players view own achievements"
  on public.player_achievements for select
  to authenticated
  using (auth.uid() = player_id);

-- insert
create policy "Players can earn achievements"
  on public.player_achievements for insert
  to authenticated
  with check (auth.uid() = player_id);

grant select, insert on public.player_achievements to authenticated;
revoke all on public.player_achievements from anon;

-----------------------------------------------------------------
-- 6️⃣ SCORE TRANSACTIONS – অপরিবর্তনীয় লেজার
-----------------------------------------------------------------
create table if not exists public.score_transactions (
  txn_id uuid primary key default gen_random_uuid(),
  player_id uuid references auth.users(id) on delete cascade,
  amount bigint not null check (amount <> 0),
  description text not null,
  created_at timestamptz not null default now()
);
alter table public.score_transactions enable row level security;

-- select
create policy "Players read own score txns"
  on public.score_transactions for select
  to authenticated
  using (auth.uid() = player_id);

-- insert – কেবল service_role (Edge Function) লিখতে পারবে
create policy "Server can insert txns"
  on public.score_transactions for insert
  to service_role
  with check (true);

grant select on public.score_transactions to authenticated;
revoke all on public.score_transactions from anon;

-----------------------------------------------------------------
-- 7️⃣ MULTIPLAYER ROOMS (Realtime)
-----------------------------------------------------------------
create table if not exists public.multiplayer_rooms (
  room_id uuid primary key default gen_random_uuid(),
  host_id uuid references auth.users(id) on delete set null,
  room_code text unique not null,
  state jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  last_active timestamptz not null default now()
);
alter table public.multiplayer_rooms enable row level security;

create policy "Room access (host or participant)"
  on public.multiplayer_rooms
  for select, update, delete
  to authenticated
  using (
    auth.uid() = host_id
    or (state -> 'players')::jsonb ? auth.uid()::text
  );

grant select, update, delete on public.multiplayer_rooms to authenticated;
revoke all on public.multiplayer_rooms from anon;

-----------------------------------------------------------------
-- 8️⃣ MULTIPLAYER ROOM PLAYERS (junction table)
-----------------------------------------------------------------
create table if not exists public.multiplayer_room_players (
  room_id uuid references public.multiplayer_rooms(room_id) on delete cascade,
  player_id uuid references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (room_id, player_id)
);
alter table public.multiplayer_room_players enable row level security;

-- select
create policy "Room members can read their entry"
  on public.multiplayer_room_players for select
  to authenticated
  using (auth.uid() = player_id);

-- insert
create policy "Room members can join (insert)"
  on public.multiplayer_room_players for insert
  to authenticated
  with check (auth.uid() = player_id);

-- delete
create policy "Room members can leave (delete)"
  on public.multiplayer_room_players for delete
  to authenticated
  using (auth.uid() = player_id);

grant select, insert, delete on public.multiplayer_room_players to authenticated;
revoke all on public.multiplayer_room_players from anon;

-----------------------------------------------------------------
-- 9️⃣ GROUP SESSIONS (same‑screen groups)
-----------------------------------------------------------------
create table if not exists public.group_sessions (
  group_id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete cascade,
  session_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.group_sessions enable row level security;

-- select
create policy "Group owners can read own group"
  on public.group_sessions for select
  to authenticated
  using (auth.uid() = owner_id);

-- update
create policy "Group owners can update own group"
  on public.group_sessions for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- delete
create policy "Group owners can delete own group"
  on public.group_sessions for delete
  to authenticated
  using (auth.uid() = owner_id);

-- insert
create policy "Group owners can create own group"
  on public.group_sessions for insert
  to authenticated
  with check (auth.uid() = owner_id);

grant select, insert, update, delete on public.group_sessions to authenticated;
revoke all on public.group_sessions from anon;

-----------------------------------------------------------------
-- 10️⃣ LEADERBOARD (materialized view)
-----------------------------------------------------------------
create materialized view if not exists public.leaderboard as
select
  p.id as player_id,
  p.username,
  p.total_score,
  p.events_completed,
  p.mysteries_solved,
  row_number() over (order by p.total_score desc) as rank
from public.profiles p
order by p.total_score desc;

grant select on public.leaderboard to authenticated;
revoke all on public.leaderboard from anon;

-- নোট:
-- স্কোর পরিবর্তনের পরে materialized view রিফ্রেশ করতে:
--   REFRESH MATERIALIZED VIEW CONCURRENTLY public.leaderboard;
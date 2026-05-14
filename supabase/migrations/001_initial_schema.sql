create extension if not exists "uuid-ossp";

create table public.users (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  avatar_url text,
  discord_id text,
  created_at timestamptz default now()
);

create table public.games (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  status text not null default 'coming_soon'
    check (status in ('coming_soon', 'live', 'retired')),
  launched_at date
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id),
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  prize_label text not null
);

create table public.scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  game_id uuid not null references public.games(id),
  season_id uuid references public.seasons(id),
  score integer not null check (score >= 0 and score <= 1000000),
  mode text not null check (mode in ('solo', 'local', 'online')),
  created_at timestamptz default now()
);

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  game_id uuid not null references public.games(id),
  type text not null,
  label text not null,
  awarded_at timestamptz default now()
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id),
  player1_id uuid not null references public.users(id),
  player2_id uuid references public.users(id),
  winner_id uuid references public.users(id),
  mode text not null check (mode in ('solo', 'local', 'online')),
  created_at timestamptz default now()
);

-- Indexes
create index scores_game_score_idx on public.scores(game_id, score desc);
create index scores_user_idx on public.scores(user_id);
create index seasons_game_idx on public.seasons(game_id);
create index matches_game_idx on public.matches(game_id);

-- RLS
alter table public.users enable row level security;
alter table public.games enable row level security;
alter table public.scores enable row level security;
alter table public.seasons enable row level security;
alter table public.achievements enable row level security;
alter table public.matches enable row level security;

create policy "public read games" on public.games for select using (true);
create policy "public read scores" on public.scores for select using (true);
create policy "public read seasons" on public.seasons for select using (true);
create policy "public read achievements" on public.achievements for select using (true);
create policy "public read matches" on public.matches for select using (true);
create policy "public read users" on public.users for select using (true);
create policy "users update own" on public.users for update using (auth.uid() = id);
create policy "auth insert matches" on public.matches
  for insert with check (auth.uid() = player1_id);

-- Sync auth.users → public.users on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, username, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name',
      split_part(new.email, '@', 1)
    ),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

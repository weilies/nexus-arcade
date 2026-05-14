-- Allow admins to delete a game and its game-owned records cleanly.
-- The admin UI also deletes these rows explicitly for older environments,
-- but the database should enforce the same ownership model.

alter table if exists public.scores
  drop constraint if exists scores_season_id_fkey;
alter table if exists public.scores
  add constraint scores_season_id_fkey
  foreign key (season_id) references public.seasons(id) on delete cascade;

alter table if exists public.seasons
  drop constraint if exists seasons_game_id_fkey;
alter table if exists public.seasons
  add constraint seasons_game_id_fkey
  foreign key (game_id) references public.games(id) on delete cascade;

alter table if exists public.scores
  drop constraint if exists scores_game_id_fkey;
alter table if exists public.scores
  add constraint scores_game_id_fkey
  foreign key (game_id) references public.games(id) on delete cascade;

alter table if exists public.achievements
  drop constraint if exists achievements_game_id_fkey;
alter table if exists public.achievements
  add constraint achievements_game_id_fkey
  foreign key (game_id) references public.games(id) on delete cascade;

alter table if exists public.matches
  drop constraint if exists matches_game_id_fkey;
alter table if exists public.matches
  add constraint matches_game_id_fkey
  foreign key (game_id) references public.games(id) on delete cascade;

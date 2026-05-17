-- Store game mode + timer on room so lobby can display them without extra joins.
alter table public.game_rooms
    add column if not exists game_mode   text not null default 'classic'
        check (game_mode in ('classic', 'ultimate', 'ephemeral')),
    add column if not exists timer_label text not null default 'OFF'
        check (timer_label in ('OFF', 'BLITZ', 'CASUAL', 'CHILL'));

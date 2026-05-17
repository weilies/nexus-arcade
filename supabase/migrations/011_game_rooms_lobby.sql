-- Add lobby fields to game_rooms: room name, public/private, optional password.
-- Password is plaintext (POC-grade; rooms aren't sensitive auth boundary).

alter table public.game_rooms
    add column if not exists room_name  text        not null default 'Room',
    add column if not exists is_private boolean     not null default false,
    add column if not exists password   text;

-- Min length 4 enforced on client + DB. Null password = public room.
alter table public.game_rooms
    drop constraint if exists game_rooms_password_len;
alter table public.game_rooms
    add  constraint game_rooms_password_len
        check (password is null or char_length(password) >= 4);

-- Private rooms must have a password; public rooms must not.
alter table public.game_rooms
    drop constraint if exists game_rooms_private_pwd;
alter table public.game_rooms
    add  constraint game_rooms_private_pwd
        check (
            (is_private = true  and password is not null) or
            (is_private = false and password is null)
        );

create index if not exists game_rooms_slug_status_waiting
    on public.game_rooms(game_slug, status)
    where status = 'waiting';

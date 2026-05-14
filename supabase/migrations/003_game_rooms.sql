create table if not exists public.game_rooms (
    id          uuid primary key default gen_random_uuid(),
    game_slug   text not null,
    room_code   text unique not null,
    host_id     uuid references auth.users on delete set null,
    guest_id    uuid references auth.users on delete set null,
    status      text not null default 'waiting'
                    check (status in ('waiting', 'active', 'finished')),
    state       jsonb not null default
                    '{"board":["","","","","","","","",""],"turn":"X","winner":""}',
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

create index if not exists game_rooms_slug_status
    on public.game_rooms(game_slug, status);

alter table public.game_rooms enable row level security;

create policy "anyone can read rooms"
    on public.game_rooms for select using (true);

create policy "auth users can create rooms"
    on public.game_rooms for insert
    with check (auth.uid() = host_id);

create policy "host or guest can update room"
    on public.game_rooms for update
    using (auth.uid() = host_id or auth.uid() = guest_id);

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger game_rooms_updated_at
    before update on public.game_rooms
    for each row execute function public.touch_updated_at();

-- Enable Realtime
alter publication supabase_realtime add table public.game_rooms;

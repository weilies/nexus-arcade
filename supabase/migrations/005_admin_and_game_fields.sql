-- Add description and thumbnail to games
alter table public.games
  add column if not exists description text,
  add column if not exists thumbnail_url text;

-- Platform admin roles table
create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('platform_admin')),
  created_at timestamptz default now(),
  unique (user_id, role)
);

alter table public.user_roles enable row level security;

-- Users can read their own role
create policy "users read own role" on public.user_roles
  for select using (auth.uid() = user_id);

-- Only platform_admins can manage roles
create policy "admins manage roles" on public.user_roles
  for all using (
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = auth.uid() and ur.role = 'platform_admin'
    )
  );

-- Allow platform_admins to insert/update/delete games
create policy "admins insert games" on public.games
  for insert with check (
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = auth.uid() and ur.role = 'platform_admin'
    )
  );

create policy "admins update games" on public.games
  for update using (
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = auth.uid() and ur.role = 'platform_admin'
    )
  );

create policy "admins delete games" on public.games
  for delete using (
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = auth.uid() and ur.role = 'platform_admin'
    )
  );

-- Seed platform_admin for weilies.chok@gmail.com
-- Uses a DO block to gracefully handle if user doesn't exist yet
do $$
declare
  v_user_id uuid;
begin
  select id into v_user_id from auth.users where email = 'weilies.chok@gmail.com';
  if v_user_id is not null then
    insert into public.user_roles (user_id, role)
    values (v_user_id, 'platform_admin')
    on conflict (user_id, role) do nothing;
  end if;
end;
$$;

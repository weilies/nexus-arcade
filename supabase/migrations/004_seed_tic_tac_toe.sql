insert into public.games (slug, name, status, launched_at)
values ('tic-tac-toe', 'Tic Tac Toe', 'live', '2026-05-01')
on conflict (slug) do update set status = 'live', launched_at = '2026-05-01';

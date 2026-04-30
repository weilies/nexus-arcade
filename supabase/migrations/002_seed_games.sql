insert into public.games (slug, name, status, launched_at)
values ('ultimate-ttt', 'Ultimate Tic Tac Toe', 'live', '2026-05-01')
on conflict (slug) do nothing;

insert into public.seasons (game_id, name, starts_at, ends_at, prize_label)
values (
  (select id from public.games where slug = 'ultimate-ttt'),
  'Q2 2026',
  '2026-04-01T00:00:00Z',
  '2026-06-30T23:59:59Z',
  'Q2 2026 Champion'
);

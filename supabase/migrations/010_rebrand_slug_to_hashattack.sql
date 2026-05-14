-- 010_rebrand_slug_to_hashattack.sql
-- Rename game slug from 'tic-tac-toe' to 'hashattack' to align with rebrand.
-- Display name '#HashAttack!' was already set in migration 007.
-- After this migration, code references GAME_SLUG="hashattack" will resolve.

UPDATE public.games SET slug = 'hashattack' WHERE slug = 'tic-tac-toe';

-- Update any game_rooms.game_slug references (online matches in flight)
UPDATE public.game_rooms SET game_slug = 'hashattack' WHERE game_slug = 'tic-tac-toe';

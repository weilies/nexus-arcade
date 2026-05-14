-- 007_membership_scoring.sql

-- Rebrand
UPDATE public.games SET name = '#HashAttack!' WHERE slug = 'tic-tac-toe';

-- member_points: denormalized balance
CREATE TABLE IF NOT EXISTS public.member_points (
  user_id      uuid PRIMARY KEY REFERENCES public.users ON DELETE CASCADE,
  total_points int NOT NULL DEFAULT 0,
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- point_transactions: immutable audit log
CREATE TABLE IF NOT EXISTS public.point_transactions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES public.users ON DELETE CASCADE,
  game_id    uuid NOT NULL REFERENCES public.games ON DELETE CASCADE,
  game_mode  text NOT NULL DEFAULT 'classic',
  source     text NOT NULL CHECK (source IN ('ai_win', 'online_win', 'bonus')),
  amount     int NOT NULL,
  streak_at  int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- consecutive_wins: per user × game × mode
CREATE TABLE IF NOT EXISTS public.consecutive_wins (
  user_id        uuid REFERENCES public.users ON DELETE CASCADE,
  game_id        uuid REFERENCES public.games ON DELETE CASCADE,
  game_mode      text NOT NULL DEFAULT 'classic',
  current_streak int NOT NULL DEFAULT 0,
  best_streak    int NOT NULL DEFAULT 0,
  last_win_at    timestamptz,
  PRIMARY KEY (user_id, game_id, game_mode)
);

-- point_tiers: admin-configured, no seeds
-- NULL game_id/game_mode = global fallback
CREATE TABLE IF NOT EXISTS public.point_tiers (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id    uuid REFERENCES public.games ON DELETE CASCADE,
  game_mode  text,
  min_streak int NOT NULL,
  max_streak int,
  multiplier numeric(5,2) NOT NULL,
  UNIQUE (game_id, game_mode, min_streak)
);

-- game_mode_stars: base value per game × mode
CREATE TABLE IF NOT EXISTS public.game_mode_stars (
  game_id    uuid REFERENCES public.games ON DELETE CASCADE,
  game_mode  text NOT NULL DEFAULT 'classic',
  base_stars int NOT NULL DEFAULT 1,
  PRIMARY KEY (game_id, game_mode)
);

-- Seed: classic = 1 star
INSERT INTO public.game_mode_stars (game_id, game_mode, base_stars)
SELECT id, 'classic', 1 FROM public.games WHERE slug = 'tic-tac-toe'
ON CONFLICT DO NOTHING;

-- event_multipliers: time-gated bonus (UI in Sprint 2)
CREATE TABLE IF NOT EXISTS public.event_multipliers (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id  uuid REFERENCES public.seasons ON DELETE CASCADE,
  game_id    uuid,
  game_mode  text,
  multiplier numeric(5,2) NOT NULL DEFAULT 1.0,
  starts_at  timestamptz NOT NULL,
  ends_at    timestamptz NOT NULL
);

-- RLS
ALTER TABLE public.member_points      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consecutive_wins   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_tiers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_mode_stars    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_multipliers  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users read own points"       ON public.member_points      FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users read own transactions" ON public.point_transactions  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users read own streaks"      ON public.consecutive_wins    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "public read tiers"           ON public.point_tiers         FOR SELECT USING (true);
CREATE POLICY "public read mode stars"      ON public.game_mode_stars     FOR SELECT USING (true);
CREATE POLICY "public read event mults"     ON public.event_multipliers   FOR SELECT USING (true);

-- Admin policies (reuse pattern from migration 005)
CREATE POLICY "admins manage tiers" ON public.point_tiers FOR ALL USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins manage mode stars" ON public.game_mode_stars FOR ALL USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins manage event mults" ON public.event_multipliers FOR ALL USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins read all points" ON public.member_points FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins read all transactions" ON public.point_transactions FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));
CREATE POLICY "admins read all streaks" ON public.consecutive_wins FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = auth.uid() AND role = 'platform_admin'));

-- RPC: award_win_points
CREATE OR REPLACE FUNCTION public.award_win_points(
  p_user_id   uuid,
  p_game_id   uuid,
  p_game_mode text,
  p_source    text DEFAULT 'ai_win'
) RETURNS int LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_streak     int;
  v_base_stars int;
  v_multiplier numeric;
  v_event_mult numeric;
  v_pts        int;
BEGIN
  INSERT INTO public.consecutive_wins (user_id, game_id, game_mode, current_streak, best_streak, last_win_at)
  VALUES (p_user_id, p_game_id, p_game_mode, 1, 1, now())
  ON CONFLICT (user_id, game_id, game_mode) DO UPDATE
    SET current_streak = consecutive_wins.current_streak + 1,
        best_streak    = GREATEST(consecutive_wins.best_streak, consecutive_wins.current_streak + 1),
        last_win_at    = now()
  RETURNING current_streak INTO v_streak;

  SELECT COALESCE((SELECT base_stars FROM public.game_mode_stars
    WHERE game_id = p_game_id AND game_mode = p_game_mode), 1) INTO v_base_stars;

  SELECT multiplier INTO v_multiplier FROM public.point_tiers
  WHERE (game_id = p_game_id OR game_id IS NULL)
    AND (game_mode = p_game_mode OR game_mode IS NULL)
    AND min_streak <= v_streak
    AND (max_streak IS NULL OR max_streak >= v_streak)
  ORDER BY (game_id IS NOT NULL)::int DESC, (game_mode IS NOT NULL)::int DESC, min_streak DESC
  LIMIT 1;

  IF v_multiplier IS NULL THEN RETURN 0; END IF;

  SELECT COALESCE((SELECT multiplier FROM public.event_multipliers
    WHERE now() BETWEEN starts_at AND ends_at
      AND (game_id = p_game_id OR game_id IS NULL)
      AND (game_mode = p_game_mode OR game_mode IS NULL)
    ORDER BY (game_id IS NOT NULL)::int DESC, (game_mode IS NOT NULL)::int DESC
    LIMIT 1), 1.0) INTO v_event_mult;

  v_pts := ROUND(v_base_stars * v_multiplier * v_event_mult)::int;

  INSERT INTO public.point_transactions (user_id, game_id, game_mode, source, amount, streak_at)
  VALUES (p_user_id, p_game_id, p_game_mode, p_source, v_pts, v_streak);

  INSERT INTO public.member_points (user_id, total_points, updated_at) VALUES (p_user_id, v_pts, now())
  ON CONFLICT (user_id) DO UPDATE
    SET total_points = member_points.total_points + v_pts, updated_at = now();

  RETURN v_pts;
END;
$$;

-- RPC: reset_win_streak
CREATE OR REPLACE FUNCTION public.reset_win_streak(
  p_user_id uuid, p_game_id uuid, p_game_mode text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.consecutive_wins SET current_streak = 0
  WHERE user_id = p_user_id AND game_id = p_game_id AND game_mode = p_game_mode;
END;
$$;

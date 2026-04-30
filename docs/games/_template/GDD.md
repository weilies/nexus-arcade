# [Game Title] — Game Design Document

> **Status:** `draft` | `in-development` | `live` | `retired`
> **Engine:** Godot 4
> **Target quarter:** Q? 20??
> **Slug:** `game-slug` (used in URLs + DB)

---

## 1. Concept

**One-liner:** _What is this game in one sentence?_

**Elevator pitch:** _2-3 sentences. What makes it fun? Why will people share it?_

**Inspiration:** _What existing game(s) inspired this? What are we remixing/improving?_

**Genre tags:** e.g. `strategy`, `puzzle`, `action`, `casual`, `multiplayer`

---

## 2. Core Mechanics

**Primary mechanic:** _The one thing the player does repeatedly._

**Win condition:** _How do you win a match?_

**Lose condition:** _How do you lose?_

**Match length:** _Estimated time per game (e.g. 2-5 min)._

**Skill ceiling:** _Is this pure luck, pure skill, or a mix? What separates a good player from a bad one?_

---

## 3. Game Modes

### Solo (vs AI)
- AI difficulty levels: _e.g. Easy / Medium / Hard_
- AI behavior notes: _What makes each difficulty distinct?_

### Local 2P (same screen)
- Turn structure: _Simultaneous or alternating?_
- Any special local-only rules?

### Online 2P
- Matchmaking: _Random queue or invite link?_
- Reconnect behavior: _What happens if opponent disconnects?_
- Turn timer: _How long per turn before auto-forfeit?_

---

## 4. UI / Screens

List the screens inside the Godot game (not the portal):

- `MainMenu` — _description_
- `GameBoard` — _description_
- `GameOver` — _description_
- `Settings` — _description_

---

## 5. Portal Bridge (postMessage API)

Events the Godot web export sends to the NextJS portal:

```js
// Game ready — portal can show UI
{ type: "game_ready" }

// Match ended — submit score
{ type: "match_end", score: 1420, winner: "player" | "opponent" | "draw", mode: "solo" | "local" | "online" }

// Request auth token (for leaderboard submit)
{ type: "auth_request" }
```

Events the portal sends to Godot:

```js
// Auth token after login
{ type: "auth_token", token: "jwt_string" }

// Season/event info
{ type: "season_info", name: "Q2 2026", ends_at: "2026-06-30" }
```

---

## 6. Art Direction

**Visual style:** _e.g. Retro pixel, 8-bit, flat vector, hand-drawn_

**Color palette:** _Primary / secondary / accent hex codes or description_

**Key assets needed:**
- [ ] Game board / background
- [ ] Player pieces / sprites
- [ ] UI elements (buttons, panels)
- [ ] Sound effects (list key SFX)
- [ ] Background music (mood/tempo)

**Animation notes:** _What "juice" effects matter most? e.g. screen shake on win, particle burst on capture_

---

## 7. Seasonal Events

**Season tie-in:** _How does this game participate in the quarterly season?_

**Seasonal challenge examples:** _e.g. "Win 10 games without using center tile"_

**Season reward / achievement:** _e.g. "Q2 2026 Champion" medal_

---

## 8. Monetization

**Ads:** _Where do ads appear? e.g. interstitial between matches, banner on game over screen_

**Premium (future):** _What would premium unlock? e.g. no ads, exclusive skins, extra AI difficulty_

---

## 9. Leaderboard & Scoring

**Score calculation:** _How is score computed? e.g. base win points + speed bonus + difficulty multiplier_

**Leaderboard type:** _Global only, or per-mode? Reset per season or all-time?_

**Anti-cheat notes:** _Any server-side validation needed?_

---

## 10. Out of Scope (this version)

_List features explicitly NOT in v1 to prevent scope creep._

- [ ] 
- [ ] 

---

## Changelog

| Date | Author | Summary |
|------|--------|---------|
| YYYY-MM-DD | @username | Initial draft |

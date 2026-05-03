# Hangman — Nexus Arcade

## Summary
Classic Hangman word-guessing game built in Godot 4.x, exported as WebGL, embedded in Next.js portal.

## Tech
| Layer | Choice |
|-------|--------|
| Engine | Godot 4.6 (GL Compatibility renderer) |
| Export | WebGL, `portal/public/games/hangman/` |
| Portal | Next.js app router page with iframe embed |
| Backend | None — single-player, no persistence |

## Gameplay
1. Game picks random word from built-in pool (~50 common English words, 4-8 letters)
2. Player sees blanks: `_ _ _ _ _`
3. Player clicks letter buttons A-Z to guess
4. Correct guess → reveal letter in word
5. Wrong guess → advance hangman drawing (7 stages)
6. All letters revealed → WIN state
7. Hangman complete (7 wrong) → LOSE state, reveal word
8. Reset button to play again

## Hangman Drawing (7 stages)
1. Base (horizontal line)
2. Pole (vertical line)
3. Rope (top hook)
4. Head (circle)
5. Body (vertical torso)
6. Arms (diagonal lines)
7. Legs (diagonal lines)

Drawn progressively using `draw_*` methods on a `Control` node (no sprite assets needed).

## Layout (720×960 portrait)
```
┌─────────────────┐
│  HANGMAN        │ <- Title label
│                 │
│  [hangman draw] │ <- Drawing area (Control node)
│                 │
│   _ _ _ _ _     │ <- Word display (Label)
│                 │
│  A B C D E F G  │
│  H I J K L M N  │ <- Letter buttons
│  O P Q R S T U  │
│  V W X Y Z      │
│                 │
│  [Reset]        │ <- Button
│                 │
│  Guessed: X     │ <- Wrong guesses display
└─────────────────┘
```

## Scenes
- `Main.tscn` — single scene, everything in one canvas

## Scripts
- `scripts/Main.gd` — all game logic

## States
| State | Behavior |
|-------|----------|
| playing | Letters clickable, check guesses |
| won | Show "You Win!", disable letters, pause, offer reset |
| lost | Show "Game Over! Word: XYZ", disable letters, offer reset |

## Juice
- Letter button: scale tween on press (0.9 → 1.0)
- Win: green flash, scale-up text
- Lose: red flash, shake effect
- Wrong guess: brief screen shake

## Portal Integration
- Route: `portal/app/games/hangman/page.tsx`
- Nav link in games listing
- Standard iframe embed matching existing pattern

## Out of Scope (v1)
- No multiplayer
- No Supabase persistence
- No word categories/difficulty
- No animations beyond basic tween

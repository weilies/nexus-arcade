# Codex Operating Guide

Nexus Arcade is Claude Code first, Codex second. Behave like a careful guest in
the workshop: use the existing project context, avoid config churn, and keep
changes scoped to the user request.

## Project Map

- `portal/` - Next.js 14 App Router portal, Tailwind CSS, Supabase SSR auth.
- `games/hashattack/` - Godot 4.x game project and GUT tests.
- `portal/public/games/hashattack/` - Godot web export consumed by the portal.
- `supabase/migrations/` - database schema and seed migrations.
- `docs/style/nexus-arcade-style-guide.md` - visual source of truth.
- `.claude/skills/` - project-local Claude persona skills.

## Startup Checklist

1. Read root `CLAUDE.md` for project architecture and commands.
2. If working in the portal, read `portal/CLAUDE.md`.
3. If working on the Godot game, read `games/hashattack/CLAUDE.md`.
4. If visuals are involved, read `docs/style/nexus-arcade-style-guide.md`.
5. Check `git status --short` before edits and preserve user changes.

## Boundaries

- Claude owns `.claude/`.
- Codex owns `.codex/`.
- Do not edit Claude MCP/settings files from Codex setup tasks.
- Do not normalize portal/game neon colors; the split is intentional.
- Do not re-enable Godot web thread support without explicit user approval.
- Do not run destructive git commands.

## MCP

Codex-side MCP config lives in `.codex/mcp.json`.

The mirrored server is:

- `gemini-gems` - Gemini-powered game art generation MCP.

If a future Codex runtime supports loading project MCP configs, point it at
`.codex/mcp.json`. If MCP is unavailable in-session, use normal repo tools and
document the limitation.

## Skills

Codex can read and apply `.claude/skills/*/SKILL.md` as project-local guidance.
These are not active tools by themselves. Use them when the user invokes the
persona by name or when the task clearly matches the role.

See `skill-bridge.md`.

## Verification Preferences

- Portal: run `npm run test` and/or `npm run build` from `portal/` when relevant.
- Godot: use GUT tests when Godot is available and the change touches game logic.
- Docs/config-only changes: verify by reading files and checking `git status`.

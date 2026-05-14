# Codex Support Layer

This directory is the Codex-only home for Nexus Arcade.

Claude Code remains the primary workflow for this project. Codex must not edit
`.claude/` configuration, portal runtime code, Godot project files, or Supabase
migrations just to configure itself.

## Purpose

- Give future Codex sessions a stable project entry point.
- Mirror MCP configuration without changing Claude's `.claude/mcp.json`.
- Document how Codex can reuse the project-local Claude skills safely.
- Keep all Codex-specific notes out of the working portal and game.

## Files

- `CODEX.md` - operating guide for Codex sessions in this repo.
- `mcp.json` - Codex-side MCP config mirror for `gemini-gems`.
- `skill-bridge.md` - how to use `.claude/skills/*/SKILL.md` from Codex.

## Non-Impact Rules

- Do not modify `.claude/mcp.json` unless the user explicitly asks.
- Do not edit `.claude/settings*.json` from Codex setup work.
- Do not touch `portal/`, `games/`, or `supabase/` for Codex setup.
- Keep generated temporary Codex notes under `.codex/`.
- Treat existing uncommitted portal/game changes as user work.

## Current MCP Status

The repo contains a Claude MCP config for `gemini-gems`, and `.codex/mcp.json`
mirrors it for Codex launchers that support project MCP config.

In the current Codex session, no MCP resources or templates were exposed through
the active tool interface. That means the config exists on disk, but the MCP is
not connected to this running session yet.

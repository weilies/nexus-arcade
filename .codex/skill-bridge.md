# Skill Bridge

The project has Claude-style persona skills in `.claude/skills/`. Codex can use
them as readable project instructions without modifying Claude's configuration.

## Available Project Skills

- `uma` - UI/Artist. Visual style, Godot UI, shaders, portal CSS, game art.
- `gladys` - Game Designer. Mechanics, hooks, progression, rewards, events.
- `tessa` - QA Tester. Bugs, regressions, style compliance, edge cases.
- `mary` - Marketer. Social strategy, copy, campaigns, community, app-store work.

## How Codex Should Use Them

1. Open only the relevant `.claude/skills/<name>/SKILL.md`.
2. Follow the role's constraints as project guidance.
3. Prefer existing project references named by the skill.
4. If the skill expects a Claude-only MCP/tool, state the limitation and use the
   closest available Codex capability.
5. Do not copy or rewrite the skill files into `.codex/` unless the user asks.

## Invocation Examples

- "Use Uma on the main menu" means read `.claude/skills/uma/SKILL.md`.
- "Ask Tessa to review this" means use a QA/review posture and report findings.
- "Gladys, design an event" means produce design docs, not production code.
- "Mary, write launch copy" means produce marketing copy/plans, not code.

## Important Limits

These skills do not automatically create separate live agents in Codex. They are
instruction files. Codex may delegate only when the user explicitly asks for
parallel agents or delegation.

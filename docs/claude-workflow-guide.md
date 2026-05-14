# Working with Claude — Nexus Arcade Workflow Guide

> Practical guide for getting the best results from Claude Code in VS Code.
> Written from real sessions on this project. Update when patterns emerge.

---

## 1. How Claude Sees Your Files

Claude runs as a VS Code extension and reads files directly from `C:\Projects\claude\nexus-arcade\`.
It does NOT browse GitHub — it reads your local disk.

**What Claude loads at session start:**
- `CLAUDE.md` (root) — always loaded
- `nexus-arcade/CLAUDE.md` — always loaded
- `games/hashattack/CLAUDE.md` — loaded when working on that game
- Memory files from `~/.claude/projects/.../memory/` — always loaded

**What Claude does NOT auto-load:**
- Files in `docs/superpowers/` — must be referenced or attached
- Large GDScript files — loaded on demand
- Old plan/spec files — loaded only if referenced

**Implication:** Keep `CLAUDE.md` lean and pointer-based. Heavy content belongs in docs that Claude reads only when needed.

---

## 2. Token Budget — Why It Matters

Each message costs tokens: input (everything Claude reads) + output (Claude's response).

| Source | Token cost |
|--------|-----------|
| CLAUDE.md (root + game) | ~2,000 |
| Memory files | ~500 |
| Each attached doc | 500–5,000 |
| Session history | Grows per turn |
| Large GDScript file | 3,000–8,000 |

**Token budget warning signs:**
- Responses become vague or repeat earlier work → context too full
- Claude "forgets" something from earlier in the session → compaction kicked in
- Claude invents code that contradicts the spec → stale context

**Rules to stay under budget:**

1. **One concern per session.** Auth bug fix = one session. AI tuning = different session.
2. **Attach only what's needed.** Don't paste entire files — reference specific sections.
3. **Use DeepSeek for heavy drafts.** Long spec-writing or large refactors → swap to DeepSeek, bring output back to Claude for review.
4. **Commit and close.** Each completed concern → commit → new session. Don't chain 5 fixes in one session.
5. **Archive old plans.** `docs/superpowers/plans/` grows over time. Completed plans go into `docs/superpowers/archive/` so they don't bloat CLAUDE.md context.

---

## 3. Document Hierarchy — Single Source of Truth

Conflicts between docs cause wrong implementations. Claude follows the hierarchy strictly.

```
ai-algorithms.md (LOCKED)
    ↓ referenced by
GDD.md (product intent)
    ↓ referenced by
auth-flow-reference.md (derived from code)
    ↓ reflected in
Code
```

**Rules:**
- `LOCKED` docs cannot be changed without explicit `# LOCKED` status update in that file
- GDD = product vision only — no algorithm detail (that lives in ai-algorithms.md)
- auth-flow-reference.md = describes code as-built; update it AFTER code changes, not before
- Style guide > GDD on all visual values — never embed colors/fonts in GDD

**When Claude sees a conflict between docs:**
Claude will flag it and ask which doc wins, not pick one silently. If you want Claude to just proceed, tell it which doc takes precedence.

---

## 4. Why Style Guide Is Separate from GDD

The style guide (`docs/style/nexus-arcade-style-guide.md`) lives outside any game folder because:

- Colors, typography, animation values apply to ALL games — future games inherit them
- GDD is game-specific; style guide is platform-wide
- If colors lived in GDD, every new game would duplicate them → drift → inconsistency

**The rule:** GDD may say "uses neon cyan for X marks" but must NOT define the hex value. That lives in the style guide. GDD references the style guide.

---

## 5. Effective Prompting Patterns

### Pattern A — Bug fix

```
Bug: [exact symptom]. Happens when [condition].
File: [path]. Relevant lines: [n–m].
Fix only that. Don't refactor anything else.
```

### Pattern B — New feature

Use `/gladys` first to get a spec, then implement. Never skip straight to code for new features — you'll get something that doesn't match the design intent.

```
/gladys  ← design session
→ spec output
→ new session: implement from spec
```

### Pattern C — Batch bugs

Group 3–5 bugs in same area (e.g. all AI bugs, or all auth bugs). Not mixed categories.

```
3 bugs in AI system:
1. [bug + file + symptom]
2. [bug + file + symptom]
3. [bug + file + symptom]
Fix in order. Commit after each one.
```

### Pattern D — Docs out of sync

```
Sync [file A] to match current code in [file B].
Do not change the code. Only update the doc.
```

### Anti-patterns to avoid:

| What you say | Why it fails |
|-------------|-------------|
| "Fix all the bugs" | Too vague; Claude guesses scope |
| "Refactor and also fix the auth bug" | Mixed concerns = hallucination risk |
| "Just make it work" | No spec = Claude invents behavior |
| 6+ unrelated issues in one message | Context overload; first issues get forgotten |

---

## 6. Agent Skills — When to Invoke

Invoke with `/skillname` at the start of your message.

| Skill | Use when |
|-------|---------|
| `/uma` | Visual changes, shader tweaks, CSS, image gen |
| `/gladys` | Designing new mechanics, events, scoring rules |
| `/tessa` | QA pass, style guide compliance check, regression |
| `/mary` | Social posts, marketing copy, store listings |

**Rule:** If your request is about HOW something looks or feels → Uma. How it works mechanically → Gladys. Whether it works correctly → Tessa.

Don't call Uma for logic bugs. Don't call Gladys for CSS. Wrong agent = generic output.

---

## 7. Memory System

Claude saves memories across sessions in `~/.claude/projects/.../memory/`.

**What gets saved automatically:**
- Patterns where you corrected Claude ("don't do X")
- Approaches you confirmed worked ("yes, exactly like that")
- Project decisions with non-obvious context

**What to explicitly ask Claude to save:**
- "Remember that we always commit between bug batches"
- "Save a memory: the admin page requires service role key, not anon key"

**What NOT to save as memory:**
- File structure (read it from disk)
- Current task state (use a plan file)
- PR content or activity logs

---

## 8. Git Discipline

One commit per concern. Not one commit per session.

```
Session flow:
  Fix auth bug → commit
  Fix AI bug → commit
  Update GDD → commit
  Close session
```

Commit messages Claude writes follow Conventional Commits:
- `fix:` — bug fix
- `feat:` — new feature
- `docs:` — doc-only change
- `refactor:` — code restructure, no behavior change
- `test:` — test files only

---

## 9. Deploying Game Updates (Godot → Railway)

WASM stored in Git LFS — Railway pulls on deploy. Flow:

```
Export from Godot
  → index.wasm lands in portal/public/games/hashattack/
  → git add portal/public/games/hashattack/
  → git commit -m "chore(hashattack): export vX.Y"
  → git push
  → GitHub stores WASM in LFS (not bloating git history)
  → Railway auto-deploys, pulls LFS files
  → Users hit Railway, get latest WASM
```

Never skip `git push` — Railway only deploys on push, not on local commit.

---

## 10. Growing Docs/Superpowers Folder

`docs/superpowers/plans/` and `specs/` grow with every sprint. Left unchecked, they bloat the context Claude loads.

**Strategy:**
- After a plan is fully executed, move it to `docs/superpowers/archive/`
- CLAUDE.md should never list every spec/plan — only the active ones
- Completed specs are reference-only; link from memory or changelog, not CLAUDE.md

**Warning signs a plan is stale:**
- Code no longer matches the plan's task list
- More than 4 weeks since last task was completed
- A newer spec supersedes it

---

## 10. Recurring Mistakes Claude Watches For

These are saved in memory and checked every session:

| Mistake | Guard |
|---------|-------|
| Doc drift between GDD, ai-algorithms, auth-flow-reference | Claude flags conflict before coding |
| 6+ bugs in one prompt | Claude interrupts, suggests batching |
| Using `/home/user/...` Linux paths in Bash tool | Claude uses relative paths from repo root |
| Heavy work without swapping to DeepSeek | Claude alerts before large drafts |

---

## Changelog

| Date | Author | Summary |
|------|--------|---------|
| 2026-05-13 | Claude + @weilies | Initial guide from real session learnings |

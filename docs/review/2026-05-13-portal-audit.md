# Portal Code Audit — 2026-05-13

> **Reviewer:** Claude Sonnet 4.6 (1M)
> **Scope:** All portal source files — components, API routes, data layer, middleware
> **Mode:** Read + fix. Fixes applied inline where safe.

---

## Summary Table

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | **HIGH** | `lib/data/games-admin.ts` | Dead file — unused, browser client used for write ops, RLS would block it |
| 2 | **MED** | `app/api/scores/route.ts` | `winner` field not validated — any string accepted |
| 3 | **MED** | `app/api/scores/route.ts` | Admin client created inline — use `server-admin.ts` factory |
| 4 | **MED** | `lib/data/leaderboard.ts` | `row: any` loses type safety, `row.users.username` can crash if null |
| 5 | **MED** | `app/leaderboard/[slug]/page.tsx` | Stub page — emoji, no data, misleading route for users |
| 6 | **LOW** | `lib/data/admin-actions.ts` | `deleteGameAction` — sequential deletes, no transaction safety |
| 7 | **LOW** | `middleware.ts` | No route protection — admin pages guarded at page level only |
| 8 | **INFO** | `app/profile/page.tsx` | `(streaks as any[])`, `(transactions as any[])` — typed as any |

---

## Detailed Findings

### 1. HIGH — Dead file `games-admin.ts` uses browser client for write ops

[portal/lib/data/games-admin.ts](../../portal/lib/data/games-admin.ts) — **zero imports across entire portal**. Nobody uses it.

Worse: it imports from `@/lib/supabase/browser` (anon key). `createGame`, `updateGame`, `deleteGame` called with anon key → Supabase RLS would block writes unless admin row-level policy is misconfigured. If RLS were ever relaxed, this file would allow unauthenticated game manipulation.

**Fix:** Delete the file. Admin CRUD is correctly handled by `admin-actions.ts` (server actions with service role key).

---

### 2. MED — `winner` field unvalidated in scores API [app/api/scores/route.ts:13](../../portal/app/api/scores/route.ts#L13)

```typescript
const { slug, score, winner, mode } = await req.json()
// score + mode validated below — winner is not
```

`winner` is stored in `scores` table with no whitelist check. A client could send `winner: "hacked"` or any arbitrary string.

**Fix:**
```typescript
if (!['player', 'opponent', 'draw'].includes(winner)) {
  return NextResponse.json({ error: 'Invalid winner value' }, { status: 400 })
}
```

---

### 3. MED — Admin Supabase client created inline [app/api/scores/route.ts:24](../../portal/app/api/scores/route.ts#L24)

```typescript
import { createClient as createAdminClient } from '@supabase/supabase-js'
// ...
const admin = createAdminClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)
```

`server-admin.ts` factory exists precisely for this. Bypassing it means env var validation and cookie handling config aren't shared. Also creates raw `@supabase/supabase-js` client instead of the SSR-aware one.

**Fix:** Replace with `createClient` from `@/lib/supabase/server-admin`.

---

### 4. MED — `leaderboard.ts` any-cast, unsafe null access [lib/data/leaderboard.ts:31](../../portal/lib/data/leaderboard.ts#L31)

```typescript
return (data ?? []).map((row: any, i) => ({
  rank: i + 1,
  username: row.users.username,   // ← crashes if users join returns null
  score: row.score,
  user_id: row.user_id,
}))
```

If a score row has no matching `users` record (deleted user), `row.users` is `null` → `row.users.username` throws. The `!inner` join in the query should prevent this, but the type cast hides it.

**Fix:**
```typescript
username: (row.users as { username: string } | null)?.username ?? 'Unknown',
```

---

### 5. MED — Leaderboard portal page is a stub [app/leaderboard/[slug]/page.tsx](../../portal/app/leaderboard/%5Bslug%5D/page.tsx)

Renders "Full leaderboard — coming soon." with a 🏆 emoji. Users navigating to `/leaderboard/hashattack` see a placeholder. Not a code bug — product gap. Flag to backlog.

---

### 6. LOW — `deleteGameAction` sequential deletes, no transaction [lib/data/admin-actions.ts:127](../../portal/lib/data/admin-actions.ts#L127)

```typescript
const childDeletes = [
  supabase.from('scores').delete().eq('game_id', id),
  supabase.from('achievements').delete().eq('game_id', id),
  supabase.from('matches').delete().eq('game_id', id),
  supabase.from('seasons').delete().eq('game_id', id),
]
for (const deleteQuery of childDeletes) {
  const { error } = await deleteQuery  // if this fails mid-loop, prior deletes are committed
  if (error) return { error: error.message }
}
```

If `achievements` delete fails after `scores` is already deleted, data is inconsistent. Migration 008 (`cascade_game_deletes`) adds FK CASCADE DELETE — verify it covers all these tables. If yes, the child deletes are redundant.

**Check:** Run against Supabase to verify migration 008 cascade covers scores + achievements + matches + seasons. If it does, simplify to just deleting the game row.

---

### 7. LOW — No middleware route protection

`middleware.ts` only refreshes the Supabase session — it doesn't redirect unauthenticated users or non-admins. Admin protection is at page level (`isPlatformAdmin()` check in `app/admin/page.tsx`).

This is acceptable but means a failed or slow `isPlatformAdmin()` call (DB timeout) would show a blank page rather than a clean redirect. Low risk for a single-admin project.

If admin surface grows, move protection to middleware using a fast session check + role cookie.

---

### 8. INFO — `any` casts in profile page

`(streaks as any[])` and `(transactions as any[])` in `profile/page.tsx`. The Supabase join returns nested objects Supabase's TS types don't fully infer — `as any[]` is a common workaround. Acceptable for now but consider typed interfaces when the profile page matures.

---

## What's Clean (positive findings)

- **`scores/route.ts`** — auth check before any write ✓; score range validation ✓
- **`admin-actions.ts`** — correctly uses service role key for all admin writes ✓
- **`middleware.ts`** — session refresh on every request (Supabase SSR requirement) ✓
- **`auth/callback/route.ts`** — OAuth code exchange + safe `return_to` redirect ✓
- **Admin page protection** — `isPlatformAdmin()` checked before rendering ✓
- **Client factories separated** — `server.ts`, `browser.ts`, `server-admin.ts` all distinct ✓
- **`uploadThumbnail`** — validates MIME type + size before upload ✓; extension sanitized ✓
- **`signout/route.ts`** — POST method (not GET), prevents CSRF ✓

---

## Fixes Applied This Session

- [x] Deleted `games-admin.ts` (dead file, browser client for admin ops)
- [x] Added `winner` validation in `scores/route.ts`
- [x] Replaced inline admin client with `createClient` from `server-admin`
- [x] Fixed `leaderboard.ts` null-safe username access

---

## Next Session

All 4 review sessions complete. Recommend:
1. Run portal tests: `cd portal && npm run test`
2. Apply migration 010 (slug rename) to Supabase cloud
3. Open Godot, verify MainMenu renders with corrected font sizes
4. Verify online mode reconnects after WS drop (SupabaseClient fix #1)

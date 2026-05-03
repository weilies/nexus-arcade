---
title: Portal — Homepage Image, Auth UX, Font Overhaul
date: 2026-05-03
status: approved
---

## Scope

Four changes to the Nexus Arcade portal:

1. Orbitron font replacing Pixelify Sans
2. Arcade cabinet image on homepage (right side)
3. Explicit "SIGN OUT" button in nav
4. Admin role seeded for platform admin (SQL already applied)

---

## 1. Font Overhaul

**Problem:** Pixelify Sans hard to read at small sizes.

**Solution:** Replace with [Orbitron](https://fonts.google.com/specimen/Orbitron) (weights 400/700/900). Orbitron is geometric, readable at small sizes, retains arcade/80s sci-fi aesthetic.

**Changes:**
- `portal/app/globals.css`: swap Google Fonts import from Pixelify Sans → Orbitron; also update hardcoded `font-family: 'Pixelify Sans'` in `.btn-primary` and `.btn-secondary` to `'Orbitron'`
- `portal/tailwind.config.ts`: change `font-pixel` alias from `"Pixelify Sans"` → `"Orbitron"`
- Components using `font-pixel` class update automatically via tailwind alias
- Body text (`html, body`) stays `system-ui` — Orbitron applies to headings, nav labels, buttons only

---

## 2. Homepage Arcade Cabinet Image

**Image:** Pixel art arcade cabinet — save to `portal/public/images/arcade-cabinet.png`

**Layout — desktop (`md:` and up):**
- Two-column flex row
- Left column: existing card (pantun + -INSERT COIN-)
- Right column: arcade cabinet image, `object-contain`, max-height ~480px
- Image gets neon cyan drop-shadow: `drop-shadow(0 0 24px rgba(0,229,255,0.35))`

**Layout — mobile:**
- Single column, flex-col
- Image below the card, max-width ~280px, centered
- Same drop-shadow

**File:** `portal/app/page.tsx` — restructure to two-column wrapper on desktop

---

## 3. Sign-Out Button

**Problem:** Signed-in state shows username; clicking signs out but is not obvious.

**Solution:** Replace username text with explicit "SIGN OUT" label in both locations.

**Changes in `portal/components/BottomTabBar.tsx`:**
- Desktop nav (signed-in button): label → `SIGN OUT`
- Mobile header (signed-in button): label → `SIGN OUT`
- No dropdown, no other changes

---

## 4. Admin Role (SQL — already applied)

Migration `007_seed_admin_role.sql` manually applied to Supabase cloud:

```sql
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'platform_admin'
FROM auth.users
WHERE email = 'weilies.chok@gmail.com'
ON CONFLICT (user_id, role) DO NOTHING;
```

No portal code change needed. Admin nav link already exists in BottomTabBar and admin page already exists at `/admin`.

---

## Files Changed

| File | Change |
|------|--------|
| `portal/app/globals.css` | Swap font import Pixelify Sans → Orbitron |
| `portal/tailwind.config.ts` | `font-pixel` alias → Orbitron |
| `portal/app/page.tsx` | Two-column layout, arcade cabinet image |
| `portal/components/BottomTabBar.tsx` | SIGN OUT label in desktop + mobile |
| `portal/public/images/arcade-cabinet.png` | New image asset |

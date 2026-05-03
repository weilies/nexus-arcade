-- Fix infinite recursion in user_roles RLS
-- "admins manage roles" used "for all" including SELECT, with subquery on user_roles itself.
-- Postgres evaluates the policy for the subquery too → infinite recursion.
-- Fix: drop the "for all" policy, replace with INSERT/UPDATE/DELETE-only policies.
-- SELECT is already covered by "users read own role".

drop policy if exists "admins manage roles" on public.user_roles;

create policy "admins insert roles" on public.user_roles
  for insert with check (
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = auth.uid() and ur.role = 'platform_admin'
    )
  );

create policy "admins update roles" on public.user_roles
  for update using (
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = auth.uid() and ur.role = 'platform_admin'
    )
  );

create policy "admins delete roles" on public.user_roles
  for delete using (
    exists (
      select 1 from public.user_roles ur
      where ur.user_id = auth.uid() and ur.role = 'platform_admin'
    )
  );

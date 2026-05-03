import { createClient } from '@/lib/supabase/server'

export async function isPlatformAdmin(): Promise<boolean> {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return false

  const { data } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .eq('role', 'platform_admin')
    .maybeSingle()

  return data !== null
}

import { isPlatformAdmin } from '@/lib/data/admin'
import { redirect } from 'next/navigation'
import { AdminDashboard } from './AdminDashboard'

export default async function AdminPage() {
  const isAdmin = await isPlatformAdmin()
  if (!isAdmin) redirect('/login')

  return <AdminDashboard />
}

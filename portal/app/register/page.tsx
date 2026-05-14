import { AuthCard } from '@/components/AuthCard'

export const dynamic = 'force-dynamic'

export default function RegisterPage() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4 py-8 bg-retro-glow">
      <AuthCard mode="register" />
    </div>
  )
}

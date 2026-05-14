import { AuthCard } from '@/components/AuthCard'
import { Suspense } from 'react'

export const dynamic = 'force-dynamic'

function LoginContent() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-4 py-8 bg-retro-glow">
      <AuthCard mode="signin" />
    </div>
  )
}

export default function LoginPage() {
  return (
    <Suspense fallback={null}>
      <LoginContent />
    </Suspense>
  )
}

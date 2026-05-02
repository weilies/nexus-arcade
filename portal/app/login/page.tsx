import { AuthCard } from '@/components/AuthCard'
import { Suspense } from 'react'

export const dynamic = 'force-dynamic'

function LoginContent() {
  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center px-4 py-8"
      style={{
        background: 'linear-gradient(180deg, #87CEEB 0%, #82c45d 40%, #f4d03f 70%, #8B5E3C 100%)',
      }}
    >
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

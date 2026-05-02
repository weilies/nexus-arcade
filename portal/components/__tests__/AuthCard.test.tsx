import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { AuthCard } from '../AuthCard'

vi.mock('@/lib/supabase/browser', () => ({
  createClient: () => ({
    auth: {
      signInWithPassword: vi.fn(),
      signUp: vi.fn(),
      signInWithOAuth: vi.fn(),
    },
  }),
}))

describe('AuthCard', () => {
  it('renders sign in form when mode is signin', () => {
    render(<AuthCard mode="signin" />)
    expect(screen.getByText('SIGN IN')).toBeDefined()
    expect(screen.getByPlaceholderText('📧 Email')).toBeDefined()
    expect(screen.getByPlaceholderText('🔒 Password')).toBeDefined()
  })

  it('renders register form when mode is register', () => {
    render(<AuthCard mode="register" />)
    expect(screen.getByText('REGISTER')).toBeDefined()
    expect(screen.getByPlaceholderText('👤 Username')).toBeDefined()
    expect(screen.getByPlaceholderText('📧 Email')).toBeDefined()
    expect(screen.getByPlaceholderText('🔒 Password')).toBeDefined()
  })

  it('renders Google and Discord SSO buttons', () => {
    render(<AuthCard mode="signin" />)
    expect(screen.getByText('🔵 Google')).toBeDefined()
    expect(screen.getByText('🟣 Discord')).toBeDefined()
  })

  it('shows register link in signin mode', () => {
    render(<AuthCard mode="signin" />)
    const link = screen.getByText('📝 Register here')
    expect(link.closest('a')?.getAttribute('href')).toBe('/register')
  })

  it('shows sign in link in register mode', () => {
    render(<AuthCard mode="register" />)
    const link = screen.getByText('🔑 Sign in')
    expect(link.closest('a')?.getAttribute('href')).toBe('/login')
  })
})

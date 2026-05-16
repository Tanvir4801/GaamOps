import { useState } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { ADMIN_EMAILS } from '../utils/constants'

export default function LoginPage() {
  const { user, loading, loginWithGoogle, logout } = useAuth()
  const [error, setError] = useState('')
  const [signingIn, setSigningIn] = useState(false)

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-sidebar">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-brand border-t-transparent" />
      </div>
    )
  }

  if (user) {
    const isAdmin = ADMIN_EMAILS.includes((user.email || '').toLowerCase())
    if (isAdmin) return <Navigate to="/dashboard" replace />
    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-sidebar p-6">
        <div className="w-full max-w-sm rounded-2xl bg-white p-8 text-center shadow-2xl">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-rose-100">
            <span className="text-3xl">🚫</span>
          </div>
          <h2 className="text-xl font-bold text-slate-800">Access Denied</h2>
          <p className="mt-2 text-sm text-slate-500">
            <strong>{user.email}</strong> is not authorized to access GaamOps.
          </p>
          <p className="mt-1 text-xs text-slate-400">Contact the GaamRide team to get admin access.</p>
          <button type="button" onClick={logout} className="btn-primary mt-6 w-full">
            Sign out &amp; try another account
          </button>
        </div>
      </div>
    )
  }

  const handleGoogleLogin = async () => {
    setError('')
    setSigningIn(true)
    try {
      await loginWithGoogle()
    } catch (err) {
      setError(err.message || 'Sign-in failed. Please try again.')
    } finally {
      setSigningIn(false)
    }
  }

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-sidebar p-6">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center">
          <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-brand text-2xl font-bold text-white shadow-lg">
            G
          </div>
          <h1 className="text-2xl font-bold text-white">GaamOps</h1>
          <p className="mt-1 text-sm text-slate-400">Admin Panel — GaamRide &amp; GaamHaul</p>
        </div>

        <div className="rounded-2xl bg-white p-8 shadow-2xl">
          <h2 className="mb-1 text-lg font-bold text-slate-800">Welcome back</h2>
          <p className="mb-6 text-sm text-slate-500">Sign in with your authorized Google admin account.</p>

          {error && (
            <div className="mb-4 rounded-lg bg-rose-50 px-4 py-3 text-sm text-rose-700">{error}</div>
          )}

          <button
            type="button"
            onClick={handleGoogleLogin}
            disabled={signingIn}
            className="flex w-full items-center justify-center gap-3 rounded-xl border-2 border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700 transition hover:border-brand hover:bg-brand/5 disabled:cursor-not-allowed disabled:opacity-60"
          >
            <svg width="18" height="18" viewBox="0 0 18 18" xmlns="http://www.w3.org/2000/svg">
              <g fill="none" fillRule="evenodd">
                <path d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844a4.14 4.14 0 01-1.796 2.716v2.259h2.908c1.702-1.567 2.684-3.875 2.684-6.615z" fill="#4285F4"/>
                <path d="M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 009 18z" fill="#34A853"/>
                <path d="M3.964 10.71A5.41 5.41 0 013.682 9c0-.593.102-1.17.282-1.71V4.958H.957A8.996 8.996 0 000 9c0 1.452.348 2.827.957 4.042l3.007-2.332z" fill="#FBBC05"/>
                <path d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 00.957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z" fill="#EA4335"/>
              </g>
            </svg>
            {signingIn ? 'Signing in…' : 'Continue with Google'}
          </button>

          <p className="mt-5 text-center text-xs text-slate-400">
            Access is restricted to authorized GaamRide admins only.
          </p>
        </div>
      </div>
    </div>
  )
}

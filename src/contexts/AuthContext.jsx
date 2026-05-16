import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import {
  GoogleAuthProvider,
  onAuthStateChanged,
  signInWithPopup,
  signOut,
} from 'firebase/auth'
import { auth, isFirebaseConfigured } from '../firebase'
import { ADMIN_EMAILS } from '../utils/constants'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [loading, setLoading] = useState(isFirebaseConfigured)

  useEffect(() => {
    if (!auth) {
      setLoading(false)
      return () => {}
    }

    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser)
      setLoading(false)
    })

    return unsubscribe
  }, [])

  const isAdmin = useMemo(() => {
    if (!user?.email) return false
    return ADMIN_EMAILS.includes(user.email.toLowerCase())
  }, [user])

  const value = useMemo(
    () => ({
      user,
      loading,
      isAdmin,
      loginWithGoogle: () => {
        if (!auth) return Promise.reject(new Error('Firebase is not configured'))
        const provider = new GoogleAuthProvider()
        return signInWithPopup(auth, provider)
      },
      logout: () => {
        if (!auth) return Promise.resolve()
        return signOut(auth)
      },
    }),
    [loading, user, isAdmin],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}

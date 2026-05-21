import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { onAuthStateChanged } from 'firebase/auth'
import { auth } from '../firebase'
import Spinner from './Spinner.jsx'

export default function ProtectedRoute({ children }) {
  const [user, setUser] = useState(undefined)

  useEffect(() => {
    if (!auth) {
      setUser(null)
      return
    }
    return onAuthStateChanged(auth, (u) => setUser(u))
  }, [])

  if (user === undefined) return <Spinner fullPage />
  if (!user) return <Navigate to="/login" replace />
  return children
}

import { useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { signOut } from 'firebase/auth'
import { auth } from '../firebase'
import Sidebar from './Sidebar.jsx'

const PAGE_TITLES = {
  '/dashboard': 'Dashboard',
  '/users': 'Users',
  '/saathis': 'Saathis',
  '/rides': 'Rides',
  '/haul-bookings': 'Haul Bookings',
  '/haul-vehicles': 'Haul Vehicles',
  '/villages': 'Villages',
  '/app-settings': 'App Settings',
}

export default function AppLayout() {
  const [mobileOpen, setMobileOpen] = useState(false)
  const location = useLocation()
  const title = PAGE_TITLES[location.pathname] || 'GaamOps'

  const handleLogout = () => {
    if (auth) signOut(auth)
  }

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar mobileOpen={mobileOpen} onCloseMobile={() => setMobileOpen(false)} />

      <div className="flex flex-1 flex-col md:ml-60">
        <header className="sticky top-0 z-20 flex h-14 items-center justify-between border-b border-gray-100 bg-white px-4">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => setMobileOpen(true)}
              className="rounded-lg p-1.5 text-gray-500 hover:bg-gray-100 md:hidden"
            >
              ☰
            </button>
            <h1 className="text-base font-semibold text-gray-800">{title}</h1>
          </div>
          <div className="flex items-center gap-3">
            <span className="hidden text-xs text-gray-500 sm:block">
              {auth?.currentUser?.email}
            </span>
            <button
              type="button"
              onClick={handleLogout}
              className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-700 hover:bg-gray-50"
            >
              Logout
            </button>
          </div>
        </header>

        <main className="flex-1 p-4 md:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}

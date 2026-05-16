import { LogOut, Menu, Bell } from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'
import { useLocation } from 'react-router-dom'

const PAGE_TITLES = {
  '/dashboard': 'Dashboard',
  '/live-rides': 'Live Rides',
  '/saathi': 'All Saathi',
  '/ride-history': 'Ride History',
  '/live-hauls': 'Live Hauls',
  '/vehicles': 'All Vehicles',
  '/haul-history': 'Haul History',
  '/users': 'All Users',
  '/verifications': 'Verifications',
  '/villages': 'Village Manager',
  '/revenue': 'Revenue',
  '/settings': 'App Settings',
  '/analytics': 'Analytics',
  '/bookings': 'Bookings',
  '/pricing': 'Pricing',
}

export default function Topbar({ onToggleMobileMenu }) {
  const { user, logout } = useAuth()
  const location = useLocation()
  const adminName = user?.displayName || user?.email?.split('@')[0] || 'Admin'
  const pageTitle = PAGE_TITLES[location.pathname] || 'GaamOps'

  return (
    <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-slate-200 bg-white/95 px-6 backdrop-blur">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={onToggleMobileMenu}
          className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 text-slate-600 md:hidden"
          aria-label="Open menu"
        >
          <Menu size={18} />
        </button>
        <h2 className="text-lg font-bold text-slate-800">{pageTitle}</h2>
      </div>

      <div className="flex items-center gap-3">
        <div className="hidden flex-col items-end sm:flex">
          <span className="text-sm font-semibold text-slate-700">{adminName}</span>
          <span className="text-xs text-slate-400">Administrator</span>
        </div>
        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-brand text-sm font-bold text-white">
          {adminName.charAt(0).toUpperCase()}
        </div>
        <button
          type="button"
          onClick={logout}
          className="inline-flex items-center gap-1.5 rounded-lg border border-slate-200 px-3 py-1.5 text-sm font-medium text-slate-600 transition hover:bg-slate-50"
        >
          <LogOut size={14} />
          <span className="hidden sm:inline">Logout</span>
        </button>
      </div>
    </header>
  )
}

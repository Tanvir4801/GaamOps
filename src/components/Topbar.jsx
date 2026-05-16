import { LogOut, Menu } from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'

export default function Topbar({ onToggleMobileMenu }) {
  const { user, logout } = useAuth()
  const adminName = user?.displayName || user?.email?.split('@')[0] || 'Admin'

  return (
    <header className="sticky top-0 z-20 flex items-center justify-between border-b border-slate-200 bg-surface/95 px-6 py-4 backdrop-blur">
      <div className="flex items-start gap-3">
        <button
          type="button"
          onClick={onToggleMobileMenu}
          className="mt-1 inline-flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 bg-white text-slate-700 md:hidden"
          aria-label="Open menu"
        >
          <Menu size={18} />
        </button>
        <div>
          <h2 className="text-xl font-bold text-slate-800">Admin Panel</h2>
          <p className="hidden text-sm text-slate-500 md:block">Manage Saathi, bookings, villages, and pricing</p>
        </div>
      </div>
      <div className="flex items-center gap-3">
        <div className="hidden rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm font-semibold text-slate-700 sm:block">
          {adminName}
        </div>
        <button
          type="button"
          onClick={logout}
          className="btn-secondary inline-flex items-center gap-2"
        >
          <LogOut size={16} />
          Logout
        </button>
      </div>
    </header>
  )
}

import {
  BarChart3,
  Car,
  IndianRupee,
  LayoutDashboard,
  MapPin,
  Truck,
  X,
} from 'lucide-react'
import { NavLink } from 'react-router-dom'

export const navItems = [
  { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/saathi', label: 'Saathi', icon: Car },
  { to: '/bookings', label: 'Bookings', icon: Truck },
  { to: '/villages', label: 'Villages', icon: MapPin },
  { to: '/pricing', label: 'Pricing', icon: IndianRupee },
  { to: '/analytics', label: 'Analytics', icon: BarChart3 },
]

export default function Sidebar({ mobileOpen = false, onCloseMobile = () => {} }) {
  const navItemClass = ({ isActive }) =>
    `flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-semibold transition ${
      isActive ? 'bg-brand text-white shadow' : 'text-slate-600 hover:bg-slate-100'
    }`

  return (
    <>
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 border-r border-slate-200 bg-white px-5 py-6 md:block">
        <div className="mb-8 rounded-xl bg-brand/10 p-4">
          <p className="text-xs font-semibold uppercase tracking-wider text-brand">Gaam Platform</p>
          <h1 className="mt-1 text-lg font-bold text-slate-800">GaamRide & GaamHaul</h1>
        </div>
        <nav className="space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon
            return (
              <NavLink key={item.to} to={item.to} className={navItemClass}>
                <Icon size={18} />
                <span>{item.label}</span>
              </NavLink>
            )
          })}
        </nav>
      </aside>

      {mobileOpen ? (
        <div className="fixed inset-0 z-40 bg-slate-900/35 md:hidden" onClick={onCloseMobile} />
      ) : null}

      <aside
        className={`fixed inset-y-0 left-0 z-50 w-64 border-r border-slate-200 bg-white px-5 py-6 transition-transform duration-200 md:hidden ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="mb-6 flex items-center justify-between">
          <div className="rounded-xl bg-brand/10 p-3">
            <p className="text-xs font-semibold uppercase tracking-wider text-brand">Gaam Platform</p>
            <h1 className="mt-1 text-base font-bold text-slate-800">GaamRide & GaamHaul</h1>
          </div>
          <button
            type="button"
            onClick={onCloseMobile}
            className="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 bg-white text-slate-700"
            aria-label="Close menu"
          >
            <X size={18} />
          </button>
        </div>
        <nav className="space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon
            return (
              <NavLink
                key={item.to}
                to={item.to}
                className={navItemClass}
                onClick={onCloseMobile}
              >
                <Icon size={18} />
                <span>{item.label}</span>
              </NavLink>
            )
          })}
        </nav>
      </aside>
    </>
  )
}

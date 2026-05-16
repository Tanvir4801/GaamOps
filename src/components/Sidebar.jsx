import {
  BarChart3,
  LayoutDashboard,
  MapPin,
  Settings,
  Truck,
  Users,
  Car,
  History,
  Activity,
  ChevronDown,
  X,
  IndianRupee,
  ShieldCheck,
} from 'lucide-react'
import { useState } from 'react'
import { NavLink, useLocation } from 'react-router-dom'

const sections = [
  {
    label: 'OVERVIEW',
    items: [
      { to: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
    ],
  },
  {
    label: 'GAAMRIDE',
    items: [
      { to: '/live-rides', label: 'Live Rides', icon: Activity },
      { to: '/saathi', label: 'All Saathi', icon: Car },
      { to: '/ride-history', label: 'Ride History', icon: History },
    ],
  },
  {
    label: 'GAAMHAUL',
    items: [
      { to: '/live-hauls', label: 'Live Hauls', icon: Truck },
      { to: '/vehicles', label: 'All Vehicles', icon: Truck },
      { to: '/haul-history', label: 'Haul History', icon: History },
    ],
  },
  {
    label: 'USERS',
    items: [
      { to: '/users', label: 'All Users', icon: Users },
      { to: '/verifications', label: 'Verifications', icon: ShieldCheck },
    ],
  },
  {
    label: 'VILLAGES',
    items: [
      { to: '/villages', label: 'Village Manager', icon: MapPin },
    ],
  },
  {
    label: 'EARNINGS',
    items: [
      { to: '/revenue', label: 'Revenue', icon: IndianRupee },
    ],
  },
  {
    label: 'SETTINGS',
    items: [
      { to: '/settings', label: 'App Settings', icon: Settings },
      { to: '/analytics', label: 'Analytics', icon: BarChart3 },
    ],
  },
]

function SidebarContent({ onClose }) {
  const location = useLocation()

  const navLinkClass = ({ isActive }) =>
    `flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
      isActive
        ? 'bg-brand text-white shadow-sm'
        : 'text-slate-300 hover:bg-white/10 hover:text-white'
    }`

  return (
    <div className="flex h-full flex-col overflow-y-auto">
      <div className="mb-6 flex items-center justify-between px-4 pt-5">
        <div>
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand text-white text-xs font-bold">G</div>
            <span className="text-lg font-bold text-white">GaamOps</span>
          </div>
          <p className="mt-0.5 text-xs text-slate-400">Admin Panel</p>
        </div>
        {onClose && (
          <button type="button" onClick={onClose} className="rounded-lg p-1 text-slate-400 hover:text-white md:hidden">
            <X size={18} />
          </button>
        )}
      </div>

      <nav className="flex-1 space-y-5 px-3 pb-6">
        {sections.map((section) => (
          <div key={section.label}>
            <p className="mb-1.5 px-3 text-[10px] font-bold uppercase tracking-widest text-slate-500">
              {section.label}
            </p>
            <div className="space-y-0.5">
              {section.items.map((item) => {
                const Icon = item.icon
                return (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    className={navLinkClass}
                    onClick={onClose}
                  >
                    <Icon size={16} />
                    <span>{item.label}</span>
                  </NavLink>
                )
              })}
            </div>
          </div>
        ))}
      </nav>
    </div>
  )
}

export default function Sidebar({ mobileOpen = false, onCloseMobile = () => {} }) {
  return (
    <>
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 bg-sidebar md:block">
        <SidebarContent />
      </aside>

      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 md:hidden"
          onClick={onCloseMobile}
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-50 w-60 bg-sidebar transition-transform duration-200 md:hidden ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <SidebarContent onClose={onCloseMobile} />
      </aside>
    </>
  )
}

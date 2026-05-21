import { NavLink } from 'react-router-dom'

const NAV_ITEMS = [
  { to: '/dashboard', label: 'Dashboard', icon: '🏠' },
  { to: '/users', label: 'Users', icon: '👥' },
  { to: '/saathis', label: 'Saathis', icon: '🚗' },
  { to: '/rides', label: 'Rides', icon: '🛵' },
  { to: '/haul-bookings', label: 'Haul Bookings', icon: '🚛' },
  { to: '/haul-vehicles', label: 'Haul Vehicles', icon: '🏗️' },
  { to: '/villages', label: 'Villages', icon: '📍' },
  { to: '/app-settings', label: 'App Settings', icon: '⚙️' },
]

function SidebarContent({ onClose }) {
  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-gray-100 px-5 py-4">
        <span className="text-xl font-bold" style={{ color: '#f97316' }}>
          GaamRide
        </span>
        <p className="text-xs text-gray-400">Admin Panel</p>
      </div>
      <nav className="flex-1 overflow-y-auto p-3">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            onClick={onClose}
            className={({ isActive }) =>
              `mb-0.5 flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                isActive
                  ? 'border-l-4 border-orange-500 bg-orange-50 text-orange-600'
                  : 'text-gray-600 hover:bg-gray-100'
              }`
            }
          >
            <span>{item.icon}</span>
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  )
}

export default function Sidebar({ mobileOpen = false, onCloseMobile = () => {} }) {
  return (
    <>
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 border-r border-gray-100 bg-white md:block">
        <SidebarContent />
      </aside>

      {mobileOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 md:hidden"
          onClick={onCloseMobile}
        />
      )}

      <aside
        className={`fixed inset-y-0 left-0 z-50 w-60 border-r border-gray-100 bg-white transition-transform duration-200 md:hidden ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <SidebarContent onClose={onCloseMobile} />
      </aside>
    </>
  )
}

import { NavLink } from 'react-router-dom'
import { navItems } from './Sidebar'

export default function MobileNav() {
  return (
    <nav className="sticky top-[89px] z-10 border-b border-slate-200 bg-white px-2 py-2 md:hidden">
      <div className="flex gap-1 overflow-x-auto">
        {navItems.map((item) => {
          const Icon = item.icon
          return (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `inline-flex min-w-max items-center gap-2 rounded-lg px-3 py-2 text-xs font-semibold ${
                  isActive ? 'bg-brand text-white' : 'bg-slate-100 text-slate-600'
                }`
              }
            >
              <Icon size={14} />
              <span>{item.label}</span>
            </NavLink>
          )
        })}
      </div>
    </nav>
  )
}

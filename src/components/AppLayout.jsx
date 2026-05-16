import { useState } from 'react'
import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar'
import Topbar from './Topbar'

export default function AppLayout() {
  const [mobileSidebarOpen, setMobileSidebarOpen] = useState(false)

  return (
    <div className="min-h-screen bg-surface">
      <Sidebar
        mobileOpen={mobileSidebarOpen}
        onCloseMobile={() => setMobileSidebarOpen(false)}
      />
      <div className="min-h-screen md:ml-60">
        <Topbar onToggleMobileMenu={() => setMobileSidebarOpen((prev) => !prev)} />
        <main className="p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}

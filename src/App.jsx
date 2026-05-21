import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { isFirebaseConfigured } from './firebase.js'
import FirebaseConfigNotice from './components/FirebaseConfigNotice.jsx'
import ProtectedRoute from './components/ProtectedRoute.jsx'
import AppLayout from './components/AppLayout.jsx'
import LoginPage from './pages/LoginPage.jsx'
import DashboardPage from './pages/DashboardPage.jsx'
import AllUsersPage from './pages/AllUsersPage.jsx'
import AllSaathiPage from './pages/AllSaathiPage.jsx'
import LiveRidesPage from './pages/LiveRidesPage.jsx'
import LiveHaulsPage from './pages/LiveHaulsPage.jsx'
import AllVehiclesPage from './pages/AllVehiclesPage.jsx'
import VillageManagerPage from './pages/VillageManagerPage.jsx'
import AppSettingsPage from './pages/AppSettingsPage.jsx'

const router = createBrowserRouter([
  { path: '/login', element: <LoginPage /> },
  {
    element: (
      <ProtectedRoute>
        <AppLayout />
      </ProtectedRoute>
    ),
    children: [
      { path: '/', element: <Navigate to="/dashboard" replace /> },
      { path: '/dashboard', element: <DashboardPage /> },
      { path: '/users', element: <AllUsersPage /> },
      { path: '/saathis', element: <AllSaathiPage /> },
      { path: '/rides', element: <LiveRidesPage /> },
      { path: '/haul-bookings', element: <LiveHaulsPage /> },
      { path: '/haul-vehicles', element: <AllVehiclesPage /> },
      { path: '/villages', element: <VillageManagerPage /> },
      { path: '/app-settings', element: <AppSettingsPage /> },
    ],
  },
  { path: '*', element: <Navigate to="/dashboard" replace /> },
])

export default function App() {
  if (!isFirebaseConfigured) return <FirebaseConfigNotice />
  return (
    <>
      <RouterProvider router={router} />
      <Toaster position="top-right" toastOptions={{ duration: 3000 }} />
    </>
  )
}

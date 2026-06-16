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
import SaathiPage from './pages/SaathiPage.jsx'
import LiveRidesPage from './pages/LiveRidesPage.jsx'
import LiveHaulsPage from './pages/LiveHaulsPage.jsx'
import AllVehiclesPage from './pages/AllVehiclesPage.jsx'
import VillageManagerPage from './pages/VillageManagerPage.jsx'
import VillagesPage from './pages/VillagesPage.jsx'
import AppSettingsPage from './pages/AppSettingsPage.jsx'
import RevenuePage from './pages/RevenuePage.jsx'
import AnalyticsPage from './pages/AnalyticsPage.jsx'
import RideHistoryPage from './pages/RideHistoryPage.jsx'
import HaulHistoryPage from './pages/HaulHistoryPage.jsx'
import BookingsPage from './pages/BookingsPage.jsx'
import VerificationsPage from './pages/VerificationsPage.jsx'
import PricingPage from './pages/PricingPage.jsx'
import WalletManagementPage from './pages/WalletManagementPage.jsx'

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
      { path: '/saathi-pending', element: <VerificationsPage /> },
      { path: '/saathi-list', element: <SaathiPage /> },
      { path: '/rides', element: <LiveRidesPage /> },
      { path: '/ride-history', element: <RideHistoryPage /> },
      { path: '/bookings', element: <BookingsPage /> },
      { path: '/haul-bookings', element: <LiveHaulsPage /> },
      { path: '/haul-history', element: <HaulHistoryPage /> },
      { path: '/haul-vehicles', element: <AllVehiclesPage /> },
      { path: '/villages', element: <VillageManagerPage /> },
      { path: '/villages-list', element: <VillagesPage /> },
      { path: '/revenue', element: <RevenuePage /> },
      { path: '/analytics', element: <AnalyticsPage /> },
      { path: '/pricing', element: <PricingPage /> },
      { path: '/wallet', element: <WalletManagementPage /> },
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

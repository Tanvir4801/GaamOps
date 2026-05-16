import { Navigate, Route, Routes } from 'react-router-dom'
import AppLayout from './components/AppLayout.jsx'
import FirebaseConfigNotice from './components/FirebaseConfigNotice.jsx'
import ProtectedRoute from './components/ProtectedRoute.jsx'
import { isFirebaseConfigured } from './firebase.js'

import LoginPage from './pages/LoginPage.jsx'
import DashboardPage from './pages/DashboardPage.jsx'
import LiveRidesPage from './pages/LiveRidesPage.jsx'
import AllSaathiPage from './pages/AllSaathiPage.jsx'
import RideHistoryPage from './pages/RideHistoryPage.jsx'
import LiveHaulsPage from './pages/LiveHaulsPage.jsx'
import AllVehiclesPage from './pages/AllVehiclesPage.jsx'
import HaulHistoryPage from './pages/HaulHistoryPage.jsx'
import AllUsersPage from './pages/AllUsersPage.jsx'
import VerificationsPage from './pages/VerificationsPage.jsx'
import VillageManagerPage from './pages/VillageManagerPage.jsx'
import RevenuePage from './pages/RevenuePage.jsx'
import AppSettingsPage from './pages/AppSettingsPage.jsx'
import AnalyticsPage from './pages/AnalyticsPage.jsx'

function App() {
  if (!isFirebaseConfigured) {
    return <FirebaseConfigNotice />
  }

  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route path="/dashboard" element={<DashboardPage />} />

        <Route path="/live-rides" element={<LiveRidesPage />} />
        <Route path="/saathi" element={<AllSaathiPage />} />
        <Route path="/ride-history" element={<RideHistoryPage />} />

        <Route path="/live-hauls" element={<LiveHaulsPage />} />
        <Route path="/vehicles" element={<AllVehiclesPage />} />
        <Route path="/haul-history" element={<HaulHistoryPage />} />

        <Route path="/users" element={<AllUsersPage />} />
        <Route path="/verifications" element={<VerificationsPage />} />

        <Route path="/villages" element={<VillageManagerPage />} />

        <Route path="/revenue" element={<RevenuePage />} />

        <Route path="/settings" element={<AppSettingsPage />} />
        <Route path="/analytics" element={<AnalyticsPage />} />
      </Route>

      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  )
}

export default App

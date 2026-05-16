import { Navigate, Route, Routes } from 'react-router-dom'
import AppLayout from './components/AppLayout.jsx'
import FirebaseConfigNotice from './components/FirebaseConfigNotice.jsx'
import ProtectedRoute from './components/ProtectedRoute.jsx'
import { isFirebaseConfigured } from './firebase.js'
import AnalyticsPage from './pages/AnalyticsPage.jsx'
import BookingsPage from './pages/BookingsPage.jsx'
import DashboardPage from './pages/DashboardPage.jsx'
import LoginPage from './pages/LoginPage.jsx'
import PricingPage from './pages/PricingPage.jsx'
import SaathiPage from './pages/SaathiPage.jsx'
import VillagesPage from './pages/VillagesPage.jsx'

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
        <Route path="/saathi" element={<SaathiPage />} />
        <Route path="/bookings" element={<BookingsPage />} />
        <Route path="/villages" element={<VillagesPage />} />
        <Route path="/pricing" element={<PricingPage />} />
        <Route path="/analytics" element={<AnalyticsPage />} />
      </Route>
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  )
}

export default App

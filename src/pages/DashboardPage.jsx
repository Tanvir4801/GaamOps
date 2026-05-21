import { useEffect, useState } from 'react'
import {
  collection, onSnapshot, query, where, orderBy, limit, Timestamp, doc, updateDoc,
} from 'firebase/firestore'
import { db } from '../firebase'
import { useDoc } from '../hooks/useDoc.js'
import { useCollection } from '../hooks/useCollection.js'
import StatusBadge from '../components/StatusBadge.jsx'
import Spinner from '../components/Spinner.jsx'

const formatDate = (ts) => {
  if (!ts) return '—'
  if (ts?.toDate) return ts.toDate().toLocaleString('en-IN')
  if (ts instanceof Date) return ts.toLocaleString('en-IN')
  return '—'
}
const formatMoney = (n) => (n != null ? '₹' + Number(n).toLocaleString('en-IN') : '—')

function StatCard({ label, value, borderColor, loading }) {
  return (
    <div
      className="rounded-xl border border-gray-100 bg-white p-5 shadow-sm"
      style={{ borderLeft: `4px solid ${borderColor}` }}
    >
      {loading ? (
        <div className="flex h-10 items-center"><Spinner /></div>
      ) : (
        <p className="text-3xl font-bold text-gray-800">{value ?? '—'}</p>
      )}
      <p className="mt-1 text-sm text-gray-500">{label}</p>
    </div>
  )
}

export default function DashboardPage() {
  const [totalUsers, setTotalUsers] = useState(null)
  const [totalSaathis, setTotalSaathis] = useState(null)
  const [onlineSaathis, setOnlineSaathis] = useState(null)
  const [activeRides, setActiveRides] = useState(null)
  const [completedToday, setCompletedToday] = useState(null)
  const [haulBookings, setHaulBookings] = useState(null)

  const { data: settings } = useDoc('app_settings', 'config')
  const { data: recentRides, loading: ridesLoading } = useCollection(
    'rides', orderBy('createdAt', 'desc'), limit(10),
  )
  const { data: recentHauls, loading: haulsLoading } = useCollection(
    'haul_bookings', orderBy('createdAt', 'desc'), limit(10),
  )

  useEffect(() => {
    if (!db) return
    const unsubs = []
    unsubs.push(onSnapshot(collection(db, 'users'), (s) => setTotalUsers(s.size)))
    unsubs.push(onSnapshot(collection(db, 'saathis'), (s) => setTotalSaathis(s.size)))
    unsubs.push(onSnapshot(
      query(collection(db, 'saathis'), where('isOnline', '==', true)),
      (s) => setOnlineSaathis(s.size),
    ))
    unsubs.push(onSnapshot(
      query(collection(db, 'rides'), where('status', 'in', ['searching', 'accepted', 'arriving', 'started'])),
      (s) => setActiveRides(s.size),
    ))
    const todayMidnight = new Date()
    todayMidnight.setHours(0, 0, 0, 0)
    unsubs.push(onSnapshot(
      query(
        collection(db, 'rides'),
        where('status', '==', 'completed'),
        where('completedAt', '>=', Timestamp.fromDate(todayMidnight)),
      ),
      (s) => setCompletedToday(s.size),
    ))
    unsubs.push(onSnapshot(collection(db, 'haul_bookings'), (s) => setHaulBookings(s.size)))
    return () => unsubs.forEach((u) => u())
  }, [])

  const handleDisableMaintenance = async () => {
    try {
      await updateDoc(doc(db, 'app_settings', 'config'), { maintenanceMode: false })
    } catch (e) {
      console.error(e)
    }
  }

  const stats = [
    { label: 'Total Users', value: totalUsers, borderColor: '#3b82f6' },
    { label: 'Total Saathis', value: totalSaathis, borderColor: '#8b5cf6' },
    { label: 'Online Saathis', value: onlineSaathis, borderColor: '#10b981' },
    { label: 'Active Rides', value: activeRides, borderColor: '#f97316' },
    { label: 'Completed Today', value: completedToday, borderColor: '#06b6d4' },
    { label: 'Haul Bookings', value: haulBookings, borderColor: '#f59e0b' },
  ]

  return (
    <div className="space-y-6">
      {settings?.maintenanceMode && (
        <div className="flex items-center justify-between rounded-lg bg-red-500 px-4 py-3 text-white">
          <span className="text-sm font-medium">
            ⚠️ App is in maintenance mode. Users cannot book rides.
          </span>
          <button
            type="button"
            onClick={handleDisableMaintenance}
            className="rounded-lg bg-white px-3 py-1 text-xs font-semibold text-red-600 hover:bg-red-50"
          >
            Disable
          </button>
        </div>
      )}

      <div className="grid grid-cols-2 gap-4 md:grid-cols-3">
        {stats.map((s) => (
          <StatCard key={s.label} {...s} loading={s.value === null} />
        ))}
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
          <div className="border-b border-gray-100 px-5 py-4">
            <h2 className="text-sm font-semibold text-gray-700">Recent Rides</h2>
          </div>
          <div className="overflow-x-auto">
            {ridesLoading ? (
              <div className="flex justify-center p-6"><Spinner /></div>
            ) : recentRides.length === 0 ? (
              <p className="p-6 text-center text-sm text-gray-400">No records found</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    {['ID', 'Customer', 'Route', 'Status', 'Fare', 'Time'].map((h) => (
                      <th key={h} className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {recentRides.map((r, i) => (
                    <tr key={r.id} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                      <td className="px-4 py-2.5 font-mono text-xs text-gray-500">{(r.rideId || r.id).slice(0, 8)}</td>
                      <td className="px-4 py-2.5">{r.customerName || '—'}</td>
                      <td className="px-4 py-2.5 text-xs text-gray-500">{r.pickupVillage} → {r.destinationVillage}</td>
                      <td className="px-4 py-2.5"><StatusBadge status={r.status} /></td>
                      <td className="px-4 py-2.5">{formatMoney(r.fare)}</td>
                      <td className="px-4 py-2.5 text-xs text-gray-400">{formatDate(r.createdAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>

        <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
          <div className="border-b border-gray-100 px-5 py-4">
            <h2 className="text-sm font-semibold text-gray-700">Recent Haul Bookings</h2>
          </div>
          <div className="overflow-x-auto">
            {haulsLoading ? (
              <div className="flex justify-center p-6"><Spinner /></div>
            ) : recentHauls.length === 0 ? (
              <p className="p-6 text-center text-sm text-gray-400">No records found</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    {['ID', 'Customer', 'Vehicle', 'Pickup', 'Status', 'Commission', 'Time'].map((h) => (
                      <th key={h} className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {recentHauls.map((h, i) => (
                    <tr key={h.id} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                      <td className="px-4 py-2.5 font-mono text-xs text-gray-500">{(h.bookingId || h.id).slice(0, 8)}</td>
                      <td className="px-4 py-2.5">{h.customerName || '—'}</td>
                      <td className="px-4 py-2.5 text-xs">{h.vehicleType || '—'}</td>
                      <td className="px-4 py-2.5 text-xs text-gray-500">{h.pickupVillage || '—'}</td>
                      <td className="px-4 py-2.5"><StatusBadge status={h.status} /></td>
                      <td className="px-4 py-2.5 text-xs">₹75</td>
                      <td className="px-4 py-2.5 text-xs text-gray-400">{formatDate(h.createdAt)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

import { useEffect, useState, useRef } from 'react'
import {
  collection, onSnapshot, query, where, orderBy, limit, Timestamp, doc, updateDoc,
} from 'firebase/firestore'
import { db } from '../firebase'
import { useDoc } from '../hooks/useDoc.js'
import StatusBadge from '../components/StatusBadge.jsx'
import Spinner from '../components/Spinner.jsx'

const fmtDate = (ts) => {
  if (!ts) return '—'
  const d = ts?.toDate ? ts.toDate() : ts instanceof Date ? ts : null
  if (!d) return '—'
  const diff = Math.floor((Date.now() - d.getTime()) / 1000)
  if (diff < 60) return `${diff}s ago`
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString('en-IN')
}

const fmtMoney = (n) => (n != null ? '₹' + Number(n).toLocaleString('en-IN') : '—')

function TrendBadge({ trend }) {
  if (trend == null) return null
  const up = trend >= 0
  return (
    <span className={`mt-1 inline-flex items-center gap-0.5 text-xs font-semibold ${up ? 'text-green-600' : 'text-red-500'}`}>
      {up ? '↑' : '↓'} {Math.abs(trend)}% vs yesterday
    </span>
  )
}

function StatCard({ label, value, borderColor, loading, trend }) {
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
      <TrendBadge trend={trend} />
    </div>
  )
}

function ActivityDot({ type }) {
  return (
    <span
      className="mt-1.5 h-2 w-2 shrink-0 rounded-full"
      style={{ backgroundColor: type === 'haul' ? '#f97316' : '#10b981' }}
    />
  )
}

function ActivityFeed({ rideEvents, haulEvents }) {
  const feedRef = useRef(null)

  const combined = [
    ...rideEvents.map(d => ({ ...d.data(), _id: d.id, _type: 'ride' })),
    ...haulEvents.map(d => ({ ...d.data(), _id: d.id, _type: 'haul' })),
  ].sort((a, b) => {
    const ta = a.createdAt?.toDate?.()?.getTime() || 0
    const tb = b.createdAt?.toDate?.()?.getTime() || 0
    return tb - ta
  }).slice(0, 10)

  useEffect(() => {
    if (feedRef.current) feedRef.current.scrollTop = 0
  }, [rideEvents, haulEvents])

  const describe = (item) => {
    if (item._type === 'haul') return `GaamHaul: ${item.pickupVillage || '?'} → ${item.destinationVillage || '?'} (${item.vehicleType || 'vehicle'})`
    return `Ride: ${item.pickupVillage || '?'} → ${item.destinationVillage || '?'} — ${item.customerName || 'customer'}`
  }

  if (combined.length === 0) {
    return <p className="p-6 text-center text-sm text-gray-400">No recent activity</p>
  }

  return (
    <div ref={feedRef} className="max-h-80 divide-y divide-gray-50 overflow-y-auto">
      {combined.map((item) => (
        <div key={item._id} className="flex items-start gap-3 px-5 py-3 hover:bg-gray-50">
          <ActivityDot type={item._type} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm text-gray-700">{describe(item)}</p>
            <div className="mt-0.5 flex items-center gap-2">
              <StatusBadge status={item.status} />
              <span className="text-xs text-gray-400">{fmtDate(item.createdAt)}</span>
            </div>
          </div>
        </div>
      ))}
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
  const [rideEvents, setRideEvents] = useState([])
  const [haulEvents, setHaulEvents] = useState([])

  const { data: settings } = useDoc('app_settings', 'config')

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

    unsubs.push(onSnapshot(
      query(collection(db, 'rides'), orderBy('createdAt', 'desc'), limit(5)),
      (snap) => setRideEvents(snap.docs),
    ))
    unsubs.push(onSnapshot(
      query(collection(db, 'haul_bookings'), orderBy('createdAt', 'desc'), limit(5)),
      (snap) => setHaulEvents(snap.docs),
    ))

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
    { label: 'Total Users', value: totalUsers, borderColor: '#3b82f6', trend: null },
    { label: 'Total Saathis', value: totalSaathis, borderColor: '#8b5cf6', trend: null },
    { label: 'Online Saathis', value: onlineSaathis, borderColor: '#10b981', trend: null },
    { label: 'Active Rides', value: activeRides, borderColor: '#f97316', trend: null },
    { label: 'Completed Today', value: completedToday, borderColor: '#06b6d4', trend: null },
    { label: 'Haul Bookings', value: haulBookings, borderColor: '#f59e0b', trend: null },
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
          <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4">
            <h2 className="text-sm font-semibold text-gray-700">Live Activity Feed</h2>
            <div className="flex items-center gap-3 text-xs text-gray-400">
              <span className="flex items-center gap-1"><span className="inline-block h-2 w-2 rounded-full bg-emerald-500" />GaamRide</span>
              <span className="flex items-center gap-1"><span className="inline-block h-2 w-2 rounded-full bg-orange-500" />GaamHaul</span>
            </div>
          </div>
          <ActivityFeed rideEvents={rideEvents} haulEvents={haulEvents} />
        </div>

        <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
          <div className="border-b border-gray-100 px-5 py-4">
            <h2 className="text-sm font-semibold text-gray-700">Recent Rides</h2>
          </div>
          <div className="overflow-x-auto">
            {rideEvents.length === 0 ? (
              <p className="p-6 text-center text-sm text-gray-400">No records found</p>
            ) : (
              <table className="w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    {['Customer', 'Route', 'Status', 'Fare', 'Time'].map((h) => (
                      <th key={h} className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {rideEvents.map((d, i) => {
                    const r = d.data()
                    return (
                      <tr key={d.id} className={i % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                        <td className="px-4 py-2.5">{r.customerName || '—'}</td>
                        <td className="px-4 py-2.5 text-xs text-gray-500">{r.pickupVillage} → {r.destinationVillage}</td>
                        <td className="px-4 py-2.5"><StatusBadge status={r.status} /></td>
                        <td className="px-4 py-2.5">{fmtMoney(r.fare)}</td>
                        <td className="px-4 py-2.5 text-xs text-gray-400">{fmtDate(r.createdAt)}</td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

import { useEffect, useState, useRef } from 'react'
import {
  collection, onSnapshot, query, where, orderBy, limit, Timestamp, doc, updateDoc,
} from 'firebase/firestore'
import { db } from '../firebase'
import { useDoc } from '../hooks/useDoc.js'
import StatusBadge from '../components/StatusBadge.jsx'
import Spinner from '../components/Spinner.jsx'
import { Users, Truck, Activity, CheckCircle, AlertCircle, TrendingUp, Clock, Zap } from 'lucide-react'

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

function StatCard({ label, value, icon: Icon, color, bgColor, borderColor, loading, sub }) {
  return (
    <div
      className="flex items-center gap-4 rounded-2xl border bg-white p-5 shadow-sm"
      style={{ borderColor: borderColor || '#e5e7eb' }}
    >
      <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl" style={{ backgroundColor: bgColor }}>
        <Icon size={22} style={{ color }} />
      </div>
      <div className="min-w-0">
        {loading ? (
          <div className="mb-1 h-7 w-16 animate-pulse rounded-lg bg-gray-100" />
        ) : (
          <p className="text-2xl font-bold text-gray-800">{value ?? '—'}</p>
        )}
        <p className="text-sm text-gray-500">{label}</p>
        {sub && <p className="mt-0.5 text-xs text-gray-400">{sub}</p>}
      </div>
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
    return `${item.pickupVillage || '?'} → ${item.destinationVillage || '?'} · ${item.customerName || 'customer'}`
  }

  if (combined.length === 0) {
    return (
      <div className="flex flex-col items-center gap-2 p-8 text-gray-400">
        <Zap size={28} className="opacity-30" />
        <p className="text-sm">No recent activity</p>
      </div>
    )
  }

  return (
    <div ref={feedRef} className="max-h-80 divide-y divide-gray-50 overflow-y-auto">
      {combined.map((item) => (
        <div key={item._id} className="flex items-start gap-3 px-5 py-3 hover:bg-gray-50">
          <ActivityDot type={item._type} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-gray-700">{describe(item)}</p>
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
  const [pendingSaathis, setPendingSaathis] = useState(null)
  const [pendingHaulVehicles, setPendingHaulVehicles] = useState(null)
  const [onlineHaulOwners, setOnlineHaulOwners] = useState(null)
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
      ),
      (s) => {
        const count = s.docs.filter(d => {
          const ts = d.data().completedAt
          if (!ts) return false
          const dt = ts?.toDate ? ts.toDate() : null
          return dt && dt >= todayMidnight
        }).length
        setCompletedToday(count)
      },
    ))
    unsubs.push(onSnapshot(collection(db, 'haul_bookings'), (s) => setHaulBookings(s.size)))

    // Pending verifications
    unsubs.push(onSnapshot(
      query(collection(db, 'saathis'), where('status', '==', 'pending')),
      (s) => setPendingSaathis(s.size),
    ))
    unsubs.push(onSnapshot(
      query(collection(db, 'haul_vehicles'), where('status', '==', 'pending')),
      (s) => setPendingHaulVehicles(s.size),
    ))
    unsubs.push(onSnapshot(
      query(collection(db, 'haul_vehicles'), where('isAvailable', '==', true)),
      (s) => setOnlineHaulOwners(s.size),
    ))

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

  const totalPending = (pendingSaathis ?? 0) + (pendingHaulVehicles ?? 0)

  return (
    <div className="space-y-6">
      {/* ── Maintenance Banner ── */}
      {settings?.maintenanceMode && (
        <div className="flex items-center justify-between rounded-xl bg-red-500 px-5 py-3.5 text-white shadow-sm">
          <div className="flex items-center gap-2">
            <AlertCircle size={18} />
            <span className="text-sm font-medium">App is in maintenance mode — users cannot book rides.</span>
          </div>
          <button
            type="button"
            onClick={handleDisableMaintenance}
            className="rounded-lg bg-white px-3 py-1 text-xs font-bold text-red-600 hover:bg-red-50"
          >
            Disable
          </button>
        </div>
      )}

      {/* ── Pending Verification Alert ── */}
      {totalPending > 0 && (
        <div className="flex items-center justify-between rounded-xl border border-amber-200 bg-amber-50 px-5 py-3.5">
          <div className="flex items-center gap-2">
            <Clock size={18} className="text-amber-600" />
            <span className="text-sm font-semibold text-amber-800">
              {totalPending} pending verification{totalPending > 1 ? 's' : ''}
              {pendingSaathis > 0 && ` — ${pendingSaathis} Saathi`}
              {pendingHaulVehicles > 0 && ` — ${pendingHaulVehicles} Vahan Saathi`}
            </span>
          </div>
          <a href="/saathi-pending"
            className="rounded-lg bg-amber-500 px-3 py-1 text-xs font-bold text-white hover:bg-amber-600">
            Review
          </a>
        </div>
      )}

      {/* ── KPI Grid ── */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <StatCard
          label="Total Users" value={totalUsers} loading={totalUsers === null}
          icon={Users} color="#3b82f6" bgColor="#eff6ff" borderColor="#bfdbfe"
          sub="Registered customers"
        />
        <StatCard
          label="Total Saathis" value={totalSaathis} loading={totalSaathis === null}
          icon={Activity} color="#8b5cf6" bgColor="#f5f3ff" borderColor="#ddd6fe"
          sub="Registered drivers"
        />
        <StatCard
          label="Online Saathis" value={onlineSaathis} loading={onlineSaathis === null}
          icon={Zap} color="#10b981" bgColor="#ecfdf5" borderColor="#a7f3d0"
          sub="Currently accepting rides"
        />
        <StatCard
          label="Active Rides" value={activeRides} loading={activeRides === null}
          icon={TrendingUp} color="#f97316" bgColor="#fff7ed" borderColor="#fed7aa"
          sub="In progress right now"
        />
        <StatCard
          label="Completed Today" value={completedToday} loading={completedToday === null}
          icon={CheckCircle} color="#06b6d4" bgColor="#ecfeff" borderColor="#a5f3fc"
          sub="Rides finished today"
        />
        <StatCard
          label="Haul Bookings" value={haulBookings} loading={haulBookings === null}
          icon={Truck} color="#f59e0b" bgColor="#fffbeb" borderColor="#fde68a"
          sub="All GaamHaul bookings"
        />
        <StatCard
          label="Available Haul Vehicles" value={onlineHaulOwners} loading={onlineHaulOwners === null}
          icon={Truck} color="#5D4037" bgColor="#EFEBE9" borderColor="#BCAAA4"
          sub="Ready for haul bookings"
        />
        <StatCard
          label="Pending Verifications" value={totalPending} loading={pendingSaathis === null}
          icon={Clock} color={totalPending > 0 ? '#d97706' : '#9ca3af'}
          bgColor={totalPending > 0 ? '#fffbeb' : '#f9fafb'}
          borderColor={totalPending > 0 ? '#fde68a' : '#e5e7eb'}
          sub={totalPending > 0 ? 'Needs attention' : 'All clear'}
        />
      </div>

      {/* ── Activity + Recent Rides ── */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Live Activity Feed */}
        <div className="overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-sm">
          <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4">
            <h2 className="font-semibold text-gray-700">Live Activity Feed</h2>
            <div className="flex items-center gap-3 text-xs text-gray-400">
              <span className="flex items-center gap-1.5">
                <span className="h-2 w-2 rounded-full bg-emerald-400" />GaamRide
              </span>
              <span className="flex items-center gap-1.5">
                <span className="h-2 w-2 rounded-full bg-orange-400" />GaamHaul
              </span>
            </div>
          </div>
          <ActivityFeed rideEvents={rideEvents} haulEvents={haulEvents} />
        </div>

        {/* Recent Rides */}
        <div className="overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-sm">
          <div className="border-b border-gray-100 px-5 py-4">
            <h2 className="font-semibold text-gray-700">Recent Rides</h2>
          </div>
          <div className="overflow-x-auto">
            {rideEvents.length === 0 ? (
              <div className="flex flex-col items-center gap-2 p-8 text-gray-400">
                <Activity size={28} className="opacity-30" />
                <p className="text-sm">No rides yet</p>
              </div>
            ) : (
              <table className="w-full text-sm">
                <thead className="bg-gray-50">
                  <tr>
                    {['Customer', 'Route', 'Status', 'Fare', 'Time'].map((h) => (
                      <th key={h} className="px-4 py-2.5 text-left text-xs font-semibold uppercase tracking-wide text-gray-400">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-50">
                  {rideEvents.map((d) => {
                    const r = d.data()
                    return (
                      <tr key={d.id} className="hover:bg-gray-50">
                        <td className="px-4 py-2.5 font-medium text-gray-800">{r.customerName || '—'}</td>
                        <td className="px-4 py-2.5 text-xs text-gray-500">{r.pickupVillage} → {r.destinationVillage}</td>
                        <td className="px-4 py-2.5"><StatusBadge status={r.status} /></td>
                        <td className="px-4 py-2.5 font-semibold text-green-700">{fmtMoney(r.fare)}</td>
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

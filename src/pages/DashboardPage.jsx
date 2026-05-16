import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts'
import { db } from '../firebase'
import { toDate, formatCurrency, isSameDay, formatTimeAgo, firstNonEmpty } from '../utils/formatters'
import { VILLAGES } from '../utils/constants'

function StatCard({ title, value, sub, icon, accent, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="panel-card flex items-center gap-4 p-5 text-left transition hover:-translate-y-0.5 hover:shadow-md w-full"
    >
      <div className={`flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-xl text-2xl ${accent}`}>
        {icon}
      </div>
      <div>
        <p className="text-sm text-slate-500">{title}</p>
        <p className="mt-0.5 text-2xl font-bold text-slate-800">{value}</p>
        {sub && <p className="mt-0.5 text-xs text-slate-400">{sub}</p>}
      </div>
    </button>
  )
}

function ActivityItem({ event }) {
  const icons = {
    ride: '🛵', haul: '🚛', user: '👤', completed: '✅', cancelled: '❌',
  }
  const type = event.type === 'GaamHaul' ? 'haul' : 'ride'
  const status = String(event.status || '').toLowerCase()
  const icon = status === 'completed' ? icons.completed : status === 'cancelled' ? icons.cancelled : event.isUser ? icons.user : icons[type]

  const from = firstNonEmpty(event.pickupVillage, event.pickupLocation, event.pickup, event.fromVillage) || '?'
  const to = firstNonEmpty(event.dropLocation, event.drop, event.toVillage, event.destinationVillage) || '?'

  return (
    <div className="flex items-start gap-3 py-3">
      <span className="text-xl">{icon}</span>
      <div className="flex-1 min-w-0">
        {event.isUser ? (
          <p className="text-sm text-slate-700">New user registered — <strong>{event.displayName || event.name || 'User'}</strong></p>
        ) : (
          <p className="text-sm text-slate-700">
            <span className="capitalize">{status || 'New'}</span> {type === 'haul' ? 'haul booking' : 'ride'} — {from} → {to}
          </p>
        )}
        <p className="text-xs text-slate-400">{formatTimeAgo(event.timestamp || event.createdAt)}</p>
      </div>
    </div>
  )
}

function VillageHeatmap({ bookings, saathi }) {
  const villageStats = useMemo(() => {
    const today = new Date()
    return VILLAGES.map((v) => {
      const ridesCount = bookings.filter((b) => {
        const d = toDate(b.timestamp || b.createdAt)
        return d && isSameDay(d, today) &&
          (b.pickupVillage === v.name || b.fromVillage === v.name || b.fromVillageName === v.name)
      }).length

      const saathiOnline = saathi.filter(
        (s) => (s.village === v.name) && String(s.status || '').toLowerCase() === 'active'
      ).length

      let statusLabel = '🔴 Inactive'
      let statusClass = 'text-red-500'
      if (ridesCount > 0 && saathiOnline > 0) { statusLabel = '🟢 Active'; statusClass = 'text-green-600' }
      else if (saathiOnline > 0) { statusLabel = '🟡 No Rides'; statusClass = 'text-amber-600' }
      else if (ridesCount > 0) { statusLabel = '🟡 No Saathi'; statusClass = 'text-amber-600' }

      return { ...v, ridesCount, saathiOnline, statusLabel, statusClass }
    })
  }, [bookings, saathi])

  return (
    <div className="overflow-x-auto">
      <table className="min-w-full text-sm">
        <thead className="bg-slate-50 text-slate-600">
          <tr>
            <th className="px-4 py-2.5 text-left font-semibold">Village</th>
            <th className="px-4 py-2.5 text-center font-semibold">Rides Today</th>
            <th className="px-4 py-2.5 text-center font-semibold">Saathi Online</th>
            <th className="px-4 py-2.5 text-left font-semibold">Status</th>
          </tr>
        </thead>
        <tbody>
          {villageStats.map((v) => (
            <tr key={v.id} className="border-t border-slate-100 hover:bg-slate-50">
              <td className="px-4 py-2.5 font-medium text-slate-800">
                {v.gujarati} <span className="text-slate-400">({v.name})</span>
              </td>
              <td className="px-4 py-2.5 text-center font-semibold text-brand">{v.ridesCount}</td>
              <td className="px-4 py-2.5 text-center font-semibold text-slate-700">{v.saathiOnline}</td>
              <td className={`px-4 py-2.5 text-sm font-medium ${v.statusClass}`}>{v.statusLabel}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default function DashboardPage() {
  const navigate = useNavigate()
  const [saathi, setSaathi] = useState([])
  const [bookings, setBookings] = useState([])
  const [users, setUsers] = useState([])

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'saathi'), (snap) => setSaathi(snap.docs.map((d) => ({ id: d.id, ...d.data() })))),
      onSnapshot(collection(db, 'bookings'), (snap) => setBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))),
      onSnapshot(collection(db, 'users'), (snap) => setUsers(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
      ),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  const now = new Date()

  const todayBookings = useMemo(() =>
    bookings.filter((b) => {
      const d = toDate(b.timestamp || b.createdAt)
      return d && isSameDay(d, now)
    }), [bookings])

  const activeSaathi = useMemo(() =>
    saathi.filter((s) => String(s.status || '').toLowerCase() === 'active'), [saathi])

  const onlineSaathi = useMemo(() =>
    saathi.filter((s) => s.isOnline === true || String(s.onlineStatus || '').toLowerCase() === 'online'), [saathi])

  const todayRideRevenue = useMemo(() =>
    todayBookings
      .filter((b) => String(b.status || '').toLowerCase() === 'completed' && b.type !== 'GaamHaul')
      .reduce((sum, b) => sum + Number(b.fare || b.amount || 0), 0), [todayBookings])

  const rideBookingsToday = useMemo(() =>
    todayBookings.filter((b) => b.type !== 'GaamHaul'), [todayBookings])

  const haulBookingsToday = useMemo(() =>
    todayBookings.filter((b) => b.type === 'GaamHaul'), [todayBookings])

  const completedRidesToday = useMemo(() =>
    rideBookingsToday.filter((b) => String(b.status || '').toLowerCase() === 'completed'), [rideBookingsToday])

  const completedHaulsToday = useMemo(() =>
    haulBookingsToday.filter((b) => String(b.status || '').toLowerCase() === 'completed'), [haulBookingsToday])

  const haulRevenue = completedHaulsToday.length * 75

  const revenueChartData = useMemo(() => {
    const days = []
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now)
      d.setDate(now.getDate() - i)
      d.setHours(0, 0, 0, 0)
      const key = d.toISOString().slice(0, 10)
      const label = d.toLocaleDateString('en-IN', { weekday: 'short' })
      const dayBookings = bookings.filter((b) => {
        const bd = toDate(b.timestamp || b.createdAt)
        return bd && bd.toISOString().slice(0, 10) === key
      })
      const ride = dayBookings
        .filter((b) => b.type !== 'GaamHaul' && String(b.status || '').toLowerCase() === 'completed')
        .reduce((s, b) => s + Number(b.fare || b.amount || 0), 0)
      const haul = dayBookings
        .filter((b) => b.type === 'GaamHaul' && String(b.status || '').toLowerCase() === 'completed')
        .length * 75
      days.push({ label, GaamRide: ride, GaamHaul: haul })
    }
    return days
  }, [bookings])

  const activityFeed = useMemo(() => {
    const allBookings = [...bookings]
      .sort((a, b) => (toDate(b.timestamp || b.createdAt)?.getTime() || 0) - (toDate(a.timestamp || a.createdAt)?.getTime() || 0))
      .slice(0, 7)
      .map((b) => ({ ...b, isUser: false }))
    const allUsers = [...users]
      .sort((a, b) => (toDate(b.createdAt)?.getTime() || 0) - (toDate(a.createdAt)?.getTime() || 0))
      .slice(0, 3)
      .map((u) => ({ ...u, isUser: true }))
    return [...allBookings, ...allUsers]
      .sort((a, b) => (toDate(b.timestamp || b.createdAt)?.getTime() || 0) - (toDate(a.timestamp || a.createdAt)?.getTime() || 0))
      .slice(0, 10)
  }, [bookings, users])

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="Users Today" value={users.length} icon="👥"
          accent="bg-blue-100" sub="Total registered"
          onClick={() => navigate('/users')}
        />
        <StatCard
          title="Active Saathi" value={onlineSaathi.length} icon="🛵"
          accent="bg-brand-light" sub={`${activeSaathi.length} approved total`}
          onClick={() => navigate('/saathi')}
        />
        <StatCard
          title="Rides Today" value={todayBookings.length} icon="📋"
          accent="bg-emerald-100" sub={`${completedRidesToday.length} completed`}
          onClick={() => navigate('/ride-history')}
        />
        <StatCard
          title="Revenue Today" value={formatCurrency(todayRideRevenue + haulRevenue)} icon="💰"
          accent="bg-amber-100" sub="GaamRide + GaamHaul"
          onClick={() => navigate('/revenue')}
        />
      </div>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div className="rounded-xl border-2 border-brand bg-brand/5 p-5">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-lg">🛵</span>
            <h3 className="font-bold text-brand text-base">GaamRide Today</h3>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div><p className="text-xs text-slate-500">Rides</p><p className="text-xl font-bold text-slate-800">{rideBookingsToday.length}</p></div>
            <div><p className="text-xs text-slate-500">Active Saathi</p><p className="text-xl font-bold text-slate-800">{onlineSaathi.length}</p></div>
            <div><p className="text-xs text-slate-500">Completed</p><p className="text-xl font-bold text-brand">{completedRidesToday.length}</p></div>
            <div><p className="text-xs text-slate-500">Revenue</p><p className="text-xl font-bold text-slate-800">{formatCurrency(todayRideRevenue)}</p></div>
          </div>
        </div>

        <div className="rounded-xl border-2 border-haul bg-haul/5 p-5">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-lg">🚛</span>
            <h3 className="font-bold text-haul text-base">GaamHaul Today</h3>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div><p className="text-xs text-slate-500">Bookings</p><p className="text-xl font-bold text-slate-800">{haulBookingsToday.length}</p></div>
            <div><p className="text-xs text-slate-500">Active Vehicles</p><p className="text-xl font-bold text-slate-800">—</p></div>
            <div><p className="text-xs text-slate-500">Completed</p><p className="text-xl font-bold text-haul">{completedHaulsToday.length}</p></div>
            <div><p className="text-xs text-slate-500">Revenue</p><p className="text-xl font-bold text-slate-800">{formatCurrency(haulRevenue)}</p></div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
        <div className="panel-card p-5 xl:col-span-2">
          <h3 className="mb-4 font-bold text-slate-800">Revenue — Last 7 Days</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={revenueChartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="label" tick={{ fontSize: 12 }} />
                <YAxis tick={{ fontSize: 12 }} tickFormatter={(v) => `₹${v}`} />
                <Tooltip formatter={(v) => `₹${v}`} />
                <Legend />
                <Line type="monotone" dataKey="GaamRide" stroke="#2E7D32" strokeWidth={2.5} dot={{ r: 4 }} />
                <Line type="monotone" dataKey="GaamHaul" stroke="#E65100" strokeWidth={2.5} dot={{ r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="panel-card p-5">
          <h3 className="mb-3 font-bold text-slate-800">Live Activity</h3>
          <div className="divide-y divide-slate-100">
            {activityFeed.length === 0 && (
              <p className="py-4 text-sm text-slate-400">No recent activity yet.</p>
            )}
            {activityFeed.map((event) => (
              <ActivityItem key={event.id} event={event} />
            ))}
          </div>
        </div>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="section-header">
          <h3 className="font-bold text-slate-800">Village Activity — Today</h3>
        </div>
        <VillageHeatmap bookings={bookings} saathi={saathi} />
      </div>
    </div>
  )
}

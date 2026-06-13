import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import {
  Bar, BarChart, CartesianGrid, Cell, Legend,
  Line, LineChart, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts'
import { TrendingUp, Map, Trophy, IndianRupee } from 'lucide-react'
import { db } from '../firebase'

const PIE_COLORS = ['#1D9E75', '#5AA8FF']

function toDate(value) {
  if (!value) return null
  if (typeof value?.toDate === 'function') return value.toDate()
  if (typeof value === 'object' && value.seconds != null)
    return new Date(Number(value.seconds) * 1000)
  if (value instanceof Date) return value
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

function shortDay(date) {
  return date.toLocaleDateString('en-IN', { weekday: 'short' })
}

function StatBadge({ label, value, icon: Icon, color }) {
  return (
    <div className="panel-card p-4 flex items-center gap-4">
      <div className={`flex h-10 w-10 items-center justify-center rounded-xl ${color}`}>
        <Icon size={20} className="text-white" />
      </div>
      <div>
        <p className="text-2xl font-bold text-slate-800">{value}</p>
        <p className="text-xs text-slate-500">{label}</p>
      </div>
    </div>
  )
}

export default function AnalyticsPage() {
  const [rides, setRides] = useState([])
  const [saathi, setSaathi] = useState([])
  const [haulBookings, setHaulBookings] = useState([])

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'rides'), (snap) =>
        setRides(snap.docs.map((d) => ({ id: d.id, ...d.data() })))),
      onSnapshot(collection(db, 'saathis'), (snap) =>
        setSaathi(snap.docs.map((d) => ({ id: d.id, ...d.data() })))),
      onSnapshot(collection(db, 'haul_bookings'), (snap) =>
        setHaulBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  const last7Days = useMemo(() => {
    const days = []
    const today = new Date()
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today)
      d.setHours(0, 0, 0, 0)
      d.setDate(today.getDate() - i)
      days.push({ key: d.toISOString().slice(0, 10), label: shortDay(d), rides: 0, revenue: 0 })
    }
    const map = Object.fromEntries(days.map((d) => [d.key, d]))
    rides.forEach((r) => {
      const date = toDate(r.createdAt)
      if (!date) return
      const key = date.toISOString().slice(0, 10)
      if (map[key]) {
        map[key].rides += 1
        map[key].revenue += Number(r.fare) || 0
      }
    })
    return days
  }, [rides])

  const rideSplit = useMemo(() => [
    { name: 'GaamRide', value: rides.length },
    { name: 'GaamHaul', value: haulBookings.length },
  ], [rides, haulBookings])

  const topRoutes = useMemo(() => {
    const counts = {}
    rides.forEach((r) => {
      if (!r.pickupVillage || !r.destinationVillage) return
      const key = `${r.pickupVillage} → ${r.destinationVillage}`
      counts[key] = (counts[key] || 0) + 1
    })
    return Object.entries(counts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 7)
      .map(([route, count]) => ({ route, count }))
  }, [rides])

  const saathiLeaderboard = useMemo(() => {
    const rideCounts = {}
    const fareTotal = {}
    rides.forEach((r) => {
      if (!r.saathiId) return
      rideCounts[r.saathiId] = (rideCounts[r.saathiId] || 0) + 1
      fareTotal[r.saathiId] = (fareTotal[r.saathiId] || 0) + (Number(r.fare) || 0)
    })
    return saathi
      .map((s) => ({
        ...s,
        rideCount: rideCounts[s.id] || 0,
        totalEarned: fareTotal[s.id] || 0,
      }))
      .sort((a, b) => b.rideCount - a.rideCount)
      .slice(0, 5)
  }, [rides, saathi])

  const totalRevenue = useMemo(
    () => rides.reduce((sum, r) => sum + (Number(r.fare) || 0), 0),
    [rides]
  )

  const completedRides = useMemo(
    () => rides.filter((r) => r.status === 'completed').length,
    [rides]
  )

  const registrationTrend = useMemo(() => {
    const counts = {}
    saathi.forEach((s) => {
      const date = toDate(s.createdAt || s.registeredAt)
      if (!date) return
      const key = date.toISOString().slice(0, 10)
      counts[key] = (counts[key] || 0) + 1
    })
    return Object.keys(counts).sort().map((key) => ({ date: key.slice(5), count: counts[key] }))
  }, [saathi])

  const medalColors = ['#FFD700', '#C0C0C0', '#CD7F32', '#9E9E9E', '#9E9E9E']

  return (
    <div className="space-y-6">
      {/* KPI strip */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatBadge label="Total Rides" value={rides.length} icon={TrendingUp} color="bg-green-500" />
        <StatBadge label="Completed" value={completedRides} icon={TrendingUp} color="bg-blue-500" />
        <StatBadge label="Total Revenue" value={`₹${Math.round(totalRevenue).toLocaleString('en-IN')}`} icon={IndianRupee} color="bg-amber-500" />
        <StatBadge label="Active Saathis" value={saathi.filter(s => String(s.status).toLowerCase() === 'active').length} icon={Trophy} color="bg-purple-500" />
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        {/* Rides per day */}
        <section className="panel-card p-5">
          <h3 className="text-lg font-bold text-slate-800">Rides Per Day — Last 7 Days</h3>
          <div className="mt-4 h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={last7Days}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="label" />
                <YAxis allowDecimals={false} />
                <Tooltip />
                <Bar dataKey="rides" fill="#1D9E75" radius={[6, 6, 0, 0]} name="Rides" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </section>

        {/* Revenue per day */}
        <section className="panel-card p-5">
          <h3 className="text-lg font-bold text-slate-800">Revenue (₹) — Last 7 Days</h3>
          <div className="mt-4 h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={last7Days}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="label" />
                <YAxis allowDecimals={false} tickFormatter={(v) => `₹${v}`} />
                <Tooltip formatter={(v) => [`₹${v}`, 'Revenue']} />
                <Bar dataKey="revenue" fill="#F59E0B" radius={[6, 6, 0, 0]} name="Revenue ₹" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </section>

        {/* GaamRide vs GaamHaul */}
        <section className="panel-card p-5">
          <h3 className="text-lg font-bold text-slate-800">GaamRide vs GaamHaul</h3>
          <div className="mt-4 h-64">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie data={rideSplit} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={90} label>
                  {rideSplit.map((entry, i) => (
                    <Cell key={entry.name} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </section>

        {/* Saathi registrations */}
        <section className="panel-card p-5">
          <h3 className="text-lg font-bold text-slate-800">New Saathi Registrations</h3>
          {!registrationTrend.length && (
            <p className="mt-2 text-sm text-slate-500">No timestamp data in saathi collection yet.</p>
          )}
          <div className="mt-4 h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={registrationTrend}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis allowDecimals={false} />
                <Tooltip />
                <Line type="monotone" dataKey="count" stroke="#1D9E75" strokeWidth={3} dot={{ r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </section>

        {/* Top routes */}
        <section className="panel-card p-5">
          <div className="flex items-center gap-2 mb-4">
            <Map size={16} className="text-green-600" />
            <h3 className="text-lg font-bold text-slate-800">Top Routes</h3>
          </div>
          {!topRoutes.length ? (
            <p className="text-sm text-slate-400">No completed rides with route data yet.</p>
          ) : (
            <div className="space-y-3">
              {topRoutes.map((r, i) => {
                const maxCount = topRoutes[0].count
                return (
                  <div key={r.route}>
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-sm font-medium text-slate-700 truncate max-w-[70%]">
                        {i + 1}. {r.route}
                      </span>
                      <span className="text-xs font-bold text-green-600">{r.count} rides</span>
                    </div>
                    <div className="h-2 rounded-full bg-slate-100 overflow-hidden">
                      <div
                        className="h-full rounded-full bg-green-500 transition-all"
                        style={{ width: `${(r.count / maxCount) * 100}%` }}
                      />
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </section>

        {/* Saathi leaderboard */}
        <section className="panel-card p-5">
          <div className="flex items-center gap-2 mb-4">
            <Trophy size={16} className="text-amber-500" />
            <h3 className="text-lg font-bold text-slate-800">Saathi Leaderboard</h3>
          </div>
          {!saathiLeaderboard.length ? (
            <p className="text-sm text-slate-400">No saathi data yet.</p>
          ) : (
            <div className="space-y-3">
              {saathiLeaderboard.map((s, i) => (
                <div key={s.id} className="flex items-center gap-3">
                  <div
                    className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full text-xs font-bold text-white"
                    style={{ backgroundColor: medalColors[i] }}
                  >
                    {i + 1}
                  </div>
                  <div className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-slate-100 text-xs font-bold text-slate-600">
                    {(s.name || s.fullName || 'S').charAt(0).toUpperCase()}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold text-slate-800 truncate">
                      {s.name || s.fullName || '—'}
                    </p>
                    <p className="text-xs text-slate-400">{s.village || '—'}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-bold text-green-600">{s.rideCount} rides</p>
                    <p className="text-xs text-slate-400">₹{Math.round(s.totalEarned).toLocaleString('en-IN')}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  )
}

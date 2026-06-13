import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { Download } from 'lucide-react'
import {
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from 'recharts'
import { db } from '../firebase'
import { toDate, formatCurrency } from '../utils/formatters'
import { VILLAGES } from '../utils/constants'

function StatCard({ label, value }) {
  return (
    <div className="panel-card p-5">
      <p className="text-sm text-slate-500">{label}</p>
      <p className="mt-1 text-2xl font-bold text-slate-800">{value}</p>
    </div>
  )
}

export default function RevenuePage() {
  const [rides, setRides] = useState([])
  const [haulBookings, setHaulBookings] = useState([])

  useEffect(() => {
    if (!db) return
    const unsubs = [
      onSnapshot(collection(db, 'rides'), (snap) =>
        setRides(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      ),
      onSnapshot(collection(db, 'haul_bookings'), (snap) =>
        setHaulBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      ),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  const completedRides = useMemo(() =>
    rides.filter((r) => String(r.status || '').toLowerCase() === 'completed'),
    [rides])

  const completedHauls = useMemo(() =>
    haulBookings.filter((h) => String(h.status || '').toLowerCase() === 'completed'),
    [haulBookings])

  const rideRevenue = useMemo(() =>
    completedRides.reduce((s, r) => s + Number(r.fare || 0), 0),
    [completedRides])

  const haulRevenue = useMemo(() =>
    completedHauls.reduce((s, h) => s + Number(h.appCommission || 75), 0),
    [completedHauls])

  const now = new Date()

  const thisMonthRevenue = useMemo(() => {
    const r = completedRides.filter((ride) => {
      const d = toDate(ride.createdAt)
      return d && d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()
    }).reduce((s, r) => s + Number(r.fare || 0), 0)
    const h = completedHauls.filter((haul) => {
      const d = toDate(haul.createdAt)
      return d && d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()
    }).reduce((s, h) => s + Number(h.appCommission || 75), 0)
    return r + h
  }, [completedRides, completedHauls])

  const thisWeekRevenue = useMemo(() => {
    const weekStart = new Date(now)
    weekStart.setDate(now.getDate() - now.getDay())
    weekStart.setHours(0, 0, 0, 0)
    const r = completedRides.filter((ride) => {
      const d = toDate(ride.createdAt)
      return d && d >= weekStart
    }).reduce((s, r) => s + Number(r.fare || 0), 0)
    const h = completedHauls.filter((haul) => {
      const d = toDate(haul.createdAt)
      return d && d >= weekStart
    }).reduce((s, h) => s + Number(h.appCommission || 75), 0)
    return r + h
  }, [completedRides, completedHauls])

  const last30Days = useMemo(() => {
    const days = []
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now)
      d.setDate(now.getDate() - i)
      d.setHours(0, 0, 0, 0)
      const key = d.toISOString().slice(0, 10)
      const label = d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' })

      const rideRev = completedRides.filter((r) => {
        const rd = toDate(r.createdAt)
        return rd && rd.toISOString().slice(0, 10) === key
      }).reduce((s, r) => s + Number(r.fare || 0), 0)

      const haulRev = completedHauls.filter((h) => {
        const hd = toDate(h.createdAt)
        return hd && hd.toISOString().slice(0, 10) === key
      }).reduce((s, h) => s + Number(h.appCommission || 75), 0)

      days.push({ label, GaamRide: rideRev, GaamHaul: haulRev, total: rideRev + haulRev })
    }
    return days
  }, [completedRides, completedHauls])

  const villageRevenue = useMemo(() => {
    const map = {}
    VILLAGES.forEach((v) => { map[v.name] = 0 })
    completedRides.forEach((r) => {
      const village = r.pickupVillage
      if (village && map[village] !== undefined) {
        map[village] += Number(r.fare || 0)
      }
    })
    return Object.entries(map).map(([name, value]) => ({ name, value })).filter((e) => e.value > 0)
  }, [completedRides])

  const topSaathi = useMemo(() => {
    const map = {}
    completedRides.forEach((r) => {
      const name = r.saathiName
      if (name) map[name] = (map[name] || 0) + 1
    })
    return Object.entries(map).sort((a, b) => b[1] - a[1]).slice(0, 5)
  }, [completedRides])

  const topVillages = useMemo(() => {
    const map = {}
    rides.forEach((r) => {
      const v = r.pickupVillage
      if (v) map[v] = (map[v] || 0) + 1
    })
    return Object.entries(map).sort((a, b) => b[1] - a[1]).slice(0, 5)
  }, [rides])

  const exportCSV = () => {
    const rows = last30Days.map((d) => `"${d.label}","${d.GaamRide}","${d.GaamHaul}","${d.total}"`)
    const csv = ['Date,GaamRide,GaamHaul,Total', ...rows].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `revenue-${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const PIE_COLORS = ['#2E7D32', '#388E3C', '#43A047', '#4CAF50', '#66BB6A', '#81C784', '#A5D6A7', '#C8E6C9']

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard label="Total Revenue (All Time)" value={formatCurrency(rideRevenue + haulRevenue)} />
        <StatCard label="This Month" value={formatCurrency(thisMonthRevenue)} />
        <StatCard label="This Week" value={formatCurrency(thisWeekRevenue)} />
      </div>

      <div className="panel-card p-5">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-bold text-slate-800">Daily Revenue — Last 30 Days</h3>
          <button type="button" onClick={exportCSV} className="btn-secondary flex items-center gap-2 text-xs">
            <Download size={13} /> Export
          </button>
        </div>
        <div className="h-72">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={last30Days.filter((_, i) => i % 3 === 0)}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="label" tick={{ fontSize: 11 }} />
              <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => `₹${v}`} />
              <Tooltip formatter={(v) => `₹${v}`} />
              <Legend />
              <Bar dataKey="GaamRide" fill="#2E7D32" radius={[3, 3, 0, 0]} />
              <Bar dataKey="GaamHaul" fill="#E65100" radius={[3, 3, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        {villageRevenue.length > 0 && (
          <div className="panel-card p-5">
            <h3 className="mb-4 font-bold text-slate-800">Revenue by Village</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={villageRevenue} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={80} label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}>
                    {villageRevenue.map((_, i) => (
                      <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(v) => `₹${v}`} />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        <div className="panel-card p-5">
          <h3 className="mb-4 font-bold text-slate-800">Revenue Trend</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={last30Days.filter((_, i) => i % 2 === 0)}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="label" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} tickFormatter={(v) => `₹${v}`} />
                <Tooltip formatter={(v) => `₹${v}`} />
                <Line type="monotone" dataKey="total" stroke="#2E7D32" strokeWidth={2.5} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        <div className="panel-card overflow-hidden">
          <div className="section-header">
            <h3 className="font-bold text-slate-800">Top Saathi by Rides</h3>
          </div>
          <div className="divide-y divide-slate-100">
            {topSaathi.map(([name, count], i) => (
              <div key={name} className="flex items-center justify-between px-5 py-3">
                <div className="flex items-center gap-3">
                  <span className="flex h-7 w-7 items-center justify-center rounded-full bg-brand/10 text-xs font-bold text-brand">
                    {i + 1}
                  </span>
                  <span className="font-medium text-slate-800">{name}</span>
                </div>
                <span className="text-sm font-semibold text-slate-600">{count} rides</span>
              </div>
            ))}
            {topSaathi.length === 0 && <p className="px-5 py-4 text-sm text-slate-400">No data yet.</p>}
          </div>
        </div>

        <div className="panel-card overflow-hidden">
          <div className="section-header">
            <h3 className="font-bold text-slate-800">Top Villages by Activity</h3>
          </div>
          <div className="divide-y divide-slate-100">
            {topVillages.map(([name, count], i) => (
              <div key={name} className="flex items-center justify-between px-5 py-3">
                <div className="flex items-center gap-3">
                  <span className="flex h-7 w-7 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-600">
                    {i + 1}
                  </span>
                  <span className="font-medium text-slate-800">{name}</span>
                </div>
                <span className="text-sm font-semibold text-slate-600">{count} bookings</span>
              </div>
            ))}
            {topVillages.length === 0 && <p className="px-5 py-4 text-sm text-slate-400">No data yet.</p>}
          </div>
        </div>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="section-header flex items-center justify-between">
          <h3 className="font-bold text-slate-800">Revenue Breakdown — Last 30 Days</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-2.5 text-left font-semibold">Date</th>
                <th className="px-4 py-2.5 text-right font-semibold text-brand">GaamRide Rev</th>
                <th className="px-4 py-2.5 text-right font-semibold text-haul">GaamHaul Rev</th>
                <th className="px-4 py-2.5 text-right font-semibold text-slate-800">Total</th>
              </tr>
            </thead>
            <tbody>
              {last30Days.filter((d) => d.GaamRide > 0 || d.GaamHaul > 0).map((row) => (
                <tr key={row.label} className="border-t border-slate-100 hover:bg-slate-50">
                  <td className="px-4 py-2.5 text-slate-600">{row.label}</td>
                  <td className="px-4 py-2.5 text-right text-brand font-medium">{formatCurrency(row.GaamRide)}</td>
                  <td className="px-4 py-2.5 text-right text-haul font-medium">{formatCurrency(row.GaamHaul)}</td>
                  <td className="px-4 py-2.5 text-right font-bold text-slate-800">{formatCurrency(row.total)}</td>
                </tr>
              ))}
              {last30Days.filter((d) => d.GaamRide > 0 || d.GaamHaul > 0).length === 0 && (
                <tr><td colSpan={4} className="px-4 py-4 text-center text-sm text-slate-400">No completed bookings found.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

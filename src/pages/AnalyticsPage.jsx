import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { db } from '../firebase'

const PIE_COLORS = ['#1D9E75', '#5AA8FF']

function toDate(value) {
  if (!value) return null
  if (typeof value?.toDate === 'function') return value.toDate()
  if (typeof value === 'object' && value.seconds != null) {
    const fromSeconds = new Date(Number(value.seconds) * 1000)
    return Number.isNaN(fromSeconds.getTime()) ? null : fromSeconds
  }
  if (typeof value === 'object' && value._seconds != null) {
    const fromSeconds = new Date(Number(value._seconds) * 1000)
    return Number.isNaN(fromSeconds.getTime()) ? null : fromSeconds
  }
  if (value instanceof Date) return value
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

function shortDay(date) {
  return date.toLocaleDateString('en-IN', { weekday: 'short' })
}

export default function AnalyticsPage() {
  const [bookings, setBookings] = useState([])
  const [saathi, setSaathi] = useState([])

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'rides'), (snapshot) => {
        setBookings(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
      onSnapshot(collection(db, 'saathis'), (snapshot) => {
        setSaathi(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
    ]

    return () => unsubs.forEach((unsub) => unsub())
  }, [])

  const bookingsPerDay = useMemo(() => {
    const days = []
    const today = new Date()

    for (let i = 6; i >= 0; i -= 1) {
      const d = new Date(today)
      d.setHours(0, 0, 0, 0)
      d.setDate(today.getDate() - i)
      days.push({
        key: d.toISOString().slice(0, 10),
        label: shortDay(d),
        count: 0,
      })
    }

    const map = Object.fromEntries(days.map((d) => [d.key, d]))

    bookings.forEach((booking) => {
      const date = toDate(booking.timestamp || booking.createdAt)
      if (!date) return
      const key = date.toISOString().slice(0, 10)
      if (map[key]) {
        map[key].count += 1
      }
    })

    return days
  }, [bookings])

  const rideSplit = useMemo(() => {
    return [
      { name: 'GaamRide', value: bookings.length },
      { name: 'GaamHaul', value: saathi.length },
    ]
  }, [bookings, saathi])

  const registrationTrend = useMemo(() => {
    const counts = {}
    saathi.forEach((driver) => {
      const date = toDate(driver.createdAt || driver.registeredAt)
      if (!date) return
      const key = date.toISOString().slice(0, 10)
      counts[key] = (counts[key] || 0) + 1
    })

    return Object.keys(counts)
      .sort()
      .map((key) => ({
        date: key.slice(5),
        count: counts[key],
      }))
  }, [saathi])

  return (
    <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
      <section className="panel-card p-5">
        <h3 className="text-lg font-bold text-slate-800">Bookings per day (Last 7 days)</h3>
        <div className="mt-4 h-72">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={bookingsPerDay}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="label" />
              <YAxis allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="count" fill="#1D9E75" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="panel-card p-5">
        <h3 className="text-lg font-bold text-slate-800">GaamRide vs GaamHaul</h3>
        <div className="mt-4 h-72">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie data={rideSplit} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={90} label>
                {rideSplit.map((entry, index) => (
                  <Cell key={`cell-${entry.name}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                ))}
              </Pie>
              <Tooltip />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="panel-card p-5 xl:col-span-2">
        <h3 className="text-lg font-bold text-slate-800">New Saathi Registrations Over Time</h3>
        {!registrationTrend.length ? (
          <p className="mt-2 text-sm text-slate-500">
            No createdAt/registeredAt timestamps found in the saathi collection yet.
          </p>
        ) : null}
        <div className="mt-4 h-80">
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
    </div>
  )
}

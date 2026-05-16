import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import EmptyTableState from '../components/EmptyTableState'
import StatCard from '../components/StatCard'
import StatusBadge from '../components/StatusBadge'
import { db } from '../firebase'

function toDate(value) {
  if (!value) return null
  if (typeof value?.toDate === 'function') return value.toDate()
  if (value instanceof Date) return value
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

function formatDate(value) {
  const date = toDate(value)
  if (!date) return '-'
  return date.toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function firstNonEmpty(...values) {
  const found = values.find((value) => String(value ?? '').trim() !== '')
  return found ?? null
}

function bookingFromLabel(booking) {
  const direct = firstNonEmpty(
    booking.pickupLocation,
    booking.pickup,
    booking.fromVillage,
    booking.pickupVillage,
  )
  if (direct) return direct

  if (booking.pickupLat != null && booking.pickupLng != null) {
    return `${booking.pickupLat}, ${booking.pickupLng}`
  }

  return '-'
}

function bookingToLabel(booking) {
  return (
    firstNonEmpty(
      booking.dropLocation,
      booking.drop,
      booking.toVillage,
      booking.destinationVillage,
    ) || '-'
  )
}

function isSameDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  )
}

export default function DashboardPage() {
  const navigate = useNavigate()
  const [saathi, setSaathi] = useState([])
  const [bookings, setBookings] = useState([])
  const [villages, setVillages] = useState([])

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'saathi'), (snapshot) => {
        setSaathi(snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })))
      }),
      onSnapshot(collection(db, 'bookings'), (snapshot) => {
        setBookings(snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })))
      }),
      onSnapshot(collection(db, 'villages'), (snapshot) => {
        setVillages(snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })))
      }),
    ]

    return () => unsubs.forEach((unsub) => unsub())
  }, [])

  const now = new Date()
  const totalSaathi = saathi.length
  const bookingsToday = bookings.filter((booking) => {
    const date = toDate(booking.timestamp || booking.createdAt)
    return date ? isSameDay(date, now) : false
  }).length
  const villagesCovered = villages.length
  const gaamHaulRides = bookings.filter((booking) => booking.type === 'GaamHaul').length

  const recentBookings = useMemo(
    () =>
      [...bookings]
        .sort(
          (a, b) =>
            (toDate(b.timestamp || b.createdAt)?.getTime() || 0) -
            (toDate(a.timestamp || a.createdAt)?.getTime() || 0),
        )
        .slice(0, 8),
    [bookings],
  )

  const pendingSaathi = useMemo(
    () => saathi.filter((item) => String(item.status || '').toLowerCase() === 'pending').slice(0, 8),
    [saathi],
  )

  const saathiNameById = useMemo(() => {
    return saathi.reduce((acc, driver) => {
      acc[driver.id] = driver.name || driver.fullName || driver.saathiName || '-'
      return acc
    }, {})
  }, [saathi])

  return (
    <div className="space-y-6">
      <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard title="Total Saathi" value={totalSaathi} onClick={() => navigate('/saathi')} />
        <StatCard title="Bookings Today" value={bookingsToday} onClick={() => navigate('/bookings')} />
        <StatCard title="Villages Covered" value={villagesCovered} onClick={() => navigate('/villages')} />
        <StatCard title="GaamHaul Rides" value={gaamHaulRides} />
      </section>

      <section className="panel-card overflow-hidden">
        <div className="border-b border-slate-200 px-5 py-4">
          <h3 className="text-lg font-bold text-slate-800">Live Bookings</h3>
          <p className="text-sm text-slate-500">Recent ride and haul activity from Firestore</p>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">From</th>
                <th className="px-4 py-3 font-semibold">To</th>
                <th className="px-4 py-3 font-semibold">Type</th>
                <th className="px-4 py-3 font-semibold">Saathi</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Time</th>
              </tr>
            </thead>
            <tbody>
              {recentBookings.map((booking) => (
                <tr key={booking.id} className="border-t border-slate-100">
                  <td className="px-4 py-3">{bookingFromLabel(booking)}</td>
                  <td className="px-4 py-3">{bookingToLabel(booking)}</td>
                  <td className="px-4 py-3">{booking.type || '-'}</td>
                  <td className="px-4 py-3">
                    {firstNonEmpty(
                      booking.saathiName,
                      booking.driverName,
                      booking.assignedDriverName,
                      saathiNameById[booking.assignedDriverId],
                      booking.assignedDriverId,
                    ) || '-'}
                  </td>
                  <td className="px-4 py-3">
                    <StatusBadge status={booking.status} />
                  </td>
                  <td className="px-4 py-3 text-slate-500">{formatDate(booking.timestamp || booking.createdAt)}</td>
                </tr>
              ))}
              {!recentBookings.length ? (
                <tr>
                  <td className="px-4 py-2" colSpan={6}>
                    <EmptyTableState message="No bookings found." />
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>

      <section className="panel-card overflow-hidden">
        <div className="border-b border-slate-200 px-5 py-4">
          <h3 className="text-lg font-bold text-slate-800">Pending Saathi Approvals</h3>
          <p className="text-sm text-slate-500">Drivers waiting for admin approval</p>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Name</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Vehicle</th>
                <th className="px-4 py-3 font-semibold">Status</th>
              </tr>
            </thead>
            <tbody>
              {pendingSaathi.map((driver) => (
                <tr key={driver.id} className="border-t border-slate-100">
                  <td className="px-4 py-3">{driver.name || driver.fullName || '-'}</td>
                  <td className="px-4 py-3">{driver.village || '-'}</td>
                  <td className="px-4 py-3">{driver.vehicle || driver.vehicleType || '-'}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={driver.status || 'pending'} />
                  </td>
                </tr>
              ))}
              {!pendingSaathi.length ? (
                <tr>
                  <td className="px-4 py-2" colSpan={4}>
                    <EmptyTableState message="No Saathi approvals pending." />
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  )
}

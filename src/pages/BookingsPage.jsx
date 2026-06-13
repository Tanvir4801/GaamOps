import { collection, onSnapshot } from 'firebase/firestore'
import { MapPin } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import EmptyTableState from '../components/EmptyTableState'
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
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function firstNonEmpty(...values) {
  const found = values.find((value) => String(value ?? '').trim() !== '')
  return found ?? null
}

function isGeoPointLike(value) {
  return (
    value &&
    typeof value === 'object' &&
    value.latitude != null &&
    value.longitude != null
  )
}

function isLatLngString(value) {
  if (typeof value !== 'string') return false
  const trimmed = value.trim()
  if (!trimmed.includes(',')) return false

  const parts = trimmed.split(',').map((part) => Number(part.trim()))
  if (parts.length !== 2 || parts.some((part) => Number.isNaN(part))) return false

  const [lat, lng] = parts
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}

function bookingFromLabel(booking) {
  const direct = firstNonEmpty(
    booking.pickupVillage,
    booking.fromVillageName,
    booking.pickupLocation,
    booking.pickup,
    booking.fromVillage,
  )

  const hasLatLngPair = booking.pickupLat != null && booking.pickupLng != null
  const pickupGeoPoint = booking.pickup
  const hasGeoPoint = isGeoPointLike(pickupGeoPoint)

  if (isGeoPointLike(direct) || isLatLngString(direct) || hasLatLngPair || hasGeoPoint) {
    return { text: 'Current Location', isCurrentLocation: true }
  }

  if (direct) return { text: String(direct), isCurrentLocation: false }

  return { text: '-', isCurrentLocation: false }
}

function renderFromVillageCell(booking) {
  const from = bookingFromLabel(booking)
  if (!from.isCurrentLocation) return from.text

  return (
    <span className="inline-flex items-center gap-1.5 font-medium text-slate-700">
      <MapPin size={14} className="text-brand" />
      {from.text}
    </span>
  )
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

export default function BookingsPage() {
  const [bookings, setBookings] = useState([])
  const [saathi, setSaathi] = useState([])
  const [users, setUsers] = useState([])
  const [statusFilter, setStatusFilter] = useState('all')
  const [dateFilter, setDateFilter] = useState('')
  const [searchDestination, setSearchDestination] = useState('')

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'rides'), (snapshot) => {
        setBookings(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
      onSnapshot(collection(db, 'saathis'), (snapshot) => {
        setSaathi(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
      onSnapshot(collection(db, 'users'), (snapshot) => {
        setUsers(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
    ]

    return () => unsubs.forEach((unsub) => unsub())
  }, [])

  const saathiNameById = useMemo(() => {
    return saathi.reduce((acc, driver) => {
      acc[driver.id] = driver.name || driver.fullName || driver.saathiName || '-'
      return acc
    }, {})
  }, [saathi])

  const userById = useMemo(() => {
    return users.reduce((acc, user) => {
      acc[user.id] = user
      return acc
    }, {})
  }, [users])

  const resolveSaathiName = (booking) => {
    const assignedId =
      firstNonEmpty(
        booking.assignedDriverId,
        booking.driverId,
        booking.assignedSaathi,
      ) || null

    const resolved = firstNonEmpty(
      booking.saathiName,
      booking.driverName,
      booking.assignedDriverName,
      booking.assignedSaathiName,
      assignedId ? saathiNameById[assignedId] : null,
      assignedId ? userById[assignedId]?.displayName : null,
      assignedId,
    )

    return resolved || 'Unassigned'
  }

  const resolveUserPhone = (booking) => {
    const userId = booking.userId
    const user = userId ? userById[userId] : null

    return (
      firstNonEmpty(
        booking.userPhone,
        booking.customerPhone,
        booking.phone,
        user?.userPhone,
        user?.customerPhone,
        user?.phone,
        user?.phoneNumber,
      ) || '-'
    )
  }

  const filteredBookings = useMemo(
    () =>
      [...bookings]
        .filter((booking) => {
          const destinationText = String(bookingToLabel(booking)).toLowerCase()
          const destinationMatch =
            !searchDestination.trim() ||
            destinationText.includes(searchDestination.trim().toLowerCase())

          const statusMatch =
            statusFilter === 'all' ||
            String(booking.status || '').toLowerCase() === statusFilter.toLowerCase()

          const bookingDate = toDate(booking.timestamp || booking.createdAt)
          const dateMatch =
            !dateFilter ||
            (bookingDate && bookingDate.toISOString().slice(0, 10) === dateFilter)

          return destinationMatch && statusMatch && dateMatch
        })
        .sort(
          (a, b) =>
            (toDate(b.timestamp || b.createdAt)?.getTime() || 0) -
            (toDate(a.timestamp || a.createdAt)?.getTime() || 0),
        ),
    [bookings, dateFilter, searchDestination, statusFilter],
  )

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end gap-3">
        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Search Destination</label>
          <input
            type="text"
            className="input min-w-[240px]"
            placeholder="Search destination village"
            value={searchDestination}
            onChange={(event) => setSearchDestination(event.target.value)}
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Date</label>
          <input
            type="date"
            className="input"
            value={dateFilter}
            onChange={(event) => setDateFilter(event.target.value)}
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Status</label>
          <select
            className="input min-w-[190px]"
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value)}
          >
            <option value="all">All statuses</option>
            <option value="pending">Pending</option>
            <option value="accepted">Accepted</option>
            <option value="rejected">Rejected</option>
            <option value="completed">Completed</option>
          </select>
        </div>
      </div>

      <section className="panel-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">From Village</th>
                <th className="px-4 py-3 font-semibold">To Village</th>
                <th className="px-4 py-3 font-semibold">Type</th>
                <th className="px-4 py-3 font-semibold">Saathi Name</th>
                <th className="px-4 py-3 font-semibold">User Phone</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {filteredBookings.map((booking) => (
                <tr key={booking.id} className="border-t border-slate-100">
                  <td className="px-4 py-3">{renderFromVillageCell(booking)}</td>
                  <td className="px-4 py-3">{bookingToLabel(booking)}</td>
                  <td className="px-4 py-3">{booking.type || '-'}</td>
                  <td className="px-4 py-3">{resolveSaathiName(booking)}</td>
                  <td className="px-4 py-3">{resolveUserPhone(booking)}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={booking.status} />
                  </td>
                  <td className="px-4 py-3 text-slate-500">{formatDate(booking.timestamp || booking.createdAt)}</td>
                </tr>
              ))}
              {!filteredBookings.length ? (
                <tr>
                  <td className="px-4 py-2" colSpan={7}>
                    <EmptyTableState message="No bookings found." />
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

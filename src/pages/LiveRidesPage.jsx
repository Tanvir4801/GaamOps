import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { MapPin, Clock, Navigation } from 'lucide-react'
import { db } from '../firebase'
import { toDate, formatTimeAgo, firstNonEmpty } from '../utils/formatters'
import { VILLAGES } from '../utils/constants'
import EmptyTableState from '../components/EmptyTableState'

const STATUS_CONFIG = {
  searching: { label: 'Searching', dot: 'bg-blue-500', card: 'border-blue-200 bg-blue-50' },
  accepted: { label: 'Accepted', dot: 'bg-amber-400', card: 'border-amber-200 bg-amber-50' },
  started: { label: 'In Progress', dot: 'bg-orange-500', card: 'border-orange-200 bg-orange-50' },
  completed: { label: 'Completed', dot: 'bg-green-500', card: 'border-green-200 bg-green-50' },
  cancelled: { label: 'Cancelled', dot: 'bg-rose-500', card: 'border-rose-200 bg-rose-50' },
}

function StatusPill({ status }) {
  const s = String(status || '').toLowerCase()
  const cfg = STATUS_CONFIG[s] || { label: status || '—', dot: 'bg-slate-300', card: '' }
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-semibold">
      <span className={`h-2 w-2 rounded-full ${cfg.dot}`} />
      {cfg.label}
    </span>
  )
}

function RideCard({ ride, selected, onClick }) {
  const s = String(ride.status || '').toLowerCase()
  const cfg = STATUS_CONFIG[s] || { card: 'border-slate-200 bg-white' }
  const from = firstNonEmpty(ride.pickupVillage, ride.pickupLocation, ride.fromVillage) || '?'
  const to = firstNonEmpty(ride.dropLocation, ride.drop, ride.toVillage, ride.destinationVillage) || '?'
  const customer = firstNonEmpty(ride.customerName, ride.userName) || 'Customer'
  const saathi = firstNonEmpty(ride.saathiName, ride.driverName, ride.assignedDriverName) || 'Unassigned'

  return (
    <button
      type="button"
      onClick={onClick}
      className={`w-full rounded-xl border-2 p-4 text-left transition hover:shadow-md ${
        selected ? 'ring-2 ring-brand ring-offset-1' : ''
      } ${cfg.card}`}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <p className="font-semibold text-slate-800 text-sm truncate">{customer}</p>
          <p className="text-xs text-slate-500 mt-0.5">Saathi: {saathi}</p>
        </div>
        <StatusPill status={ride.status} />
      </div>
      <div className="mt-3 flex items-center gap-2 text-sm">
        <MapPin size={13} className="text-brand flex-shrink-0" />
        <span className="text-slate-600 truncate">{from} → {to}</span>
      </div>
      {(ride.fare || ride.amount) && (
        <div className="mt-2 flex items-center justify-between">
          <span className="text-sm font-bold text-brand">₹{ride.fare || ride.amount}</span>
          <span className="text-xs text-slate-400">{formatTimeAgo(ride.timestamp || ride.createdAt)}</span>
        </div>
      )}
    </button>
  )
}

function MapPlaceholder({ rides }) {
  return (
    <div className="relative h-full min-h-[400px] rounded-xl bg-slate-100 flex flex-col items-center justify-center overflow-hidden border border-slate-200">
      <div className="absolute inset-0 opacity-5">
        <svg width="100%" height="100%">
          <defs>
            <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
              <path d="M 40 0 L 0 0 0 40" fill="none" stroke="currentColor" strokeWidth="1"/>
            </pattern>
          </defs>
          <rect width="100%" height="100%" fill="url(#grid)" />
        </svg>
      </div>
      <div className="relative text-center px-6">
        <div className="text-5xl mb-3">🗺️</div>
        <h3 className="font-bold text-slate-700">Live Map — Mahuva Taluka</h3>
        <p className="mt-1 text-sm text-slate-500">
          Add <code className="rounded bg-slate-200 px-1 text-xs">VITE_GOOGLE_MAPS_KEY</code> to enable live tracking
        </p>
        <div className="mt-4 grid grid-cols-3 gap-2 text-xs">
          {VILLAGES.slice(0, 6).map((v) => (
            <div key={v.id} className="rounded-lg bg-white px-2 py-1.5 shadow-sm">
              <span className="font-semibold text-brand">{v.gujarati}</span>
              <p className="text-slate-400">{v.name}</p>
            </div>
          ))}
        </div>
        <div className="mt-4 flex items-center justify-center gap-4 text-xs text-slate-500">
          <span className="flex items-center gap-1"><span className="h-2.5 w-2.5 rounded-full bg-blue-500" />Customer</span>
          <span className="flex items-center gap-1"><span className="h-2.5 w-2.5 rounded-full bg-green-500" />Saathi</span>
          <span className="flex items-center gap-1"><span className="h-2.5 w-2.5 rounded-full bg-orange-500" />In Progress</span>
        </div>
      </div>
      <div className="absolute bottom-4 right-4 flex flex-col gap-2">
        {rides.slice(0, 5).map((ride, i) => (
          <div key={ride.id} className="flex items-center gap-2 rounded-lg bg-white px-3 py-1.5 shadow-sm text-xs">
            <span className={`h-2 w-2 rounded-full ${STATUS_CONFIG[String(ride.status || '').toLowerCase()]?.dot || 'bg-slate-300'}`} />
            <span className="font-medium">{firstNonEmpty(ride.pickupVillage, ride.fromVillage) || '?'}</span>
            <Navigation size={10} className="text-slate-400" />
            <span>{firstNonEmpty(ride.dropLocation, ride.toVillage) || '?'}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

const FILTERS = ['all', 'searching', 'accepted', 'started', 'completed', 'cancelled']

export default function LiveRidesPage() {
  const [bookings, setBookings] = useState([])
  const [filter, setFilter] = useState('all')
  const [villageFilter, setVillageFilter] = useState('all')
  const [selectedId, setSelectedId] = useState(null)

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'bookings'), (snap) =>
      setBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
    )
    return () => unsub()
  }, [])

  const rideBookings = useMemo(() =>
    bookings.filter((b) => b.type !== 'GaamHaul')
      .sort((a, b) => (toDate(b.timestamp || b.createdAt)?.getTime() || 0) - (toDate(a.timestamp || a.createdAt)?.getTime() || 0)),
    [bookings])

  const activeRides = useMemo(() =>
    rideBookings.filter((b) => ['searching', 'accepted', 'started'].includes(String(b.status || '').toLowerCase())),
    [rideBookings])

  const filtered = useMemo(() =>
    rideBookings.filter((b) => {
      const matchStatus = filter === 'all' || String(b.status || '').toLowerCase() === filter
      const matchVillage = villageFilter === 'all' ||
        b.pickupVillage === villageFilter || b.fromVillage === villageFilter
      return matchStatus && matchVillage
    }), [rideBookings, filter, villageFilter])

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex gap-1.5">
          {FILTERS.map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setFilter(f)}
              className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition capitalize ${
                filter === f ? 'bg-brand text-white' : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              {f === 'all' ? `All (${rideBookings.length})` : f}
            </button>
          ))}
        </div>
        <select className="input ml-auto max-w-[180px]" value={villageFilter} onChange={(e) => setVillageFilter(e.target.value)}>
          <option value="all">All Villages</option>
          {VILLAGES.map((v) => <option key={v.id} value={v.name}>{v.name}</option>)}
        </select>
        <div className="flex items-center gap-2 rounded-lg bg-brand/10 px-3 py-1.5">
          <span className="h-2 w-2 rounded-full bg-brand animate-pulse" />
          <span className="text-xs font-semibold text-brand">{activeRides.length} Active</span>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-5">
        <div className="space-y-3 lg:col-span-2 max-h-[700px] overflow-y-auto pr-1">
          {filtered.length === 0 && (
            <EmptyTableState message="No rides match your filters." />
          )}
          {filtered.map((ride) => (
            <RideCard
              key={ride.id}
              ride={ride}
              selected={selectedId === ride.id}
              onClick={() => setSelectedId(ride.id === selectedId ? null : ride.id)}
            />
          ))}
        </div>

        <div className="lg:col-span-3">
          <MapPlaceholder rides={activeRides} />
        </div>
      </div>
    </div>
  )
}

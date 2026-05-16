import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { MapPin, Truck, Navigation } from 'lucide-react'
import { db } from '../firebase'
import { toDate, formatTimeAgo, firstNonEmpty } from '../utils/formatters'
import { VILLAGES } from '../utils/constants'
import EmptyTableState from '../components/EmptyTableState'

const STATUS_CONFIG = {
  searching: { label: 'Searching', dot: 'bg-blue-500', card: 'border-blue-200 bg-blue-50' },
  accepted: { label: 'Accepted', dot: 'bg-amber-400', card: 'border-amber-200 bg-amber-50' },
  started: { label: 'In Progress', dot: 'bg-orange-500', card: 'border-orange-200 bg-haul/5' },
  completed: { label: 'Completed', dot: 'bg-green-500', card: 'border-green-200 bg-green-50' },
  cancelled: { label: 'Cancelled', dot: 'bg-rose-500', card: 'border-rose-200 bg-rose-50' },
}

function StatusPill({ status }) {
  const s = String(status || '').toLowerCase()
  const cfg = STATUS_CONFIG[s] || { label: status || '—', dot: 'bg-slate-300' }
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-semibold">
      <span className={`h-2 w-2 rounded-full ${cfg.dot}`} />
      {cfg.label}
    </span>
  )
}

function HaulCard({ haul, selected, onClick }) {
  const s = String(haul.status || '').toLowerCase()
  const cfg = STATUS_CONFIG[s] || { card: 'border-slate-200 bg-white' }
  const from = firstNonEmpty(haul.pickupVillage, haul.pickupLocation, haul.fromVillage) || '?'
  const farmer = firstNonEmpty(haul.customerName, haul.userName, haul.farmerName) || 'Farmer'
  const vehicle = firstNonEmpty(haul.vehicleOwnerName, haul.driverName, haul.vehicleType) || 'Vehicle'

  return (
    <button
      type="button"
      onClick={onClick}
      className={`w-full rounded-xl border-2 p-4 text-left transition hover:shadow-md ${
        selected ? 'ring-2 ring-haul ring-offset-1' : ''
      } ${cfg.card}`}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <p className="font-semibold text-slate-800 text-sm">Haul #{haul.id?.slice(-5).toUpperCase()}</p>
          <p className="text-xs text-slate-500 mt-0.5">Farmer: {farmer}</p>
        </div>
        <StatusPill status={haul.status} />
      </div>
      <div className="mt-2.5 flex items-center gap-1.5 text-xs text-slate-500">
        <Truck size={12} className="text-haul" />
        <span>{vehicle}</span>
      </div>
      <div className="mt-2 flex items-center gap-1.5 text-sm">
        <MapPin size={13} className="text-haul flex-shrink-0" />
        <span className="text-slate-600 truncate">{from}</span>
      </div>
      {haul.load && (
        <div className="mt-1.5 text-xs text-slate-500">Load: {haul.load}</div>
      )}
      <div className="mt-2 flex items-center justify-between">
        <span className="text-sm font-bold text-haul">₹75 commission</span>
        <span className="text-xs text-slate-400">{formatTimeAgo(haul.timestamp || haul.createdAt)}</span>
      </div>
    </button>
  )
}

function MapPlaceholder({ hauls }) {
  return (
    <div className="relative h-full min-h-[400px] rounded-xl bg-orange-50 flex flex-col items-center justify-center overflow-hidden border border-orange-200">
      <div className="relative text-center px-6">
        <div className="text-5xl mb-3">🚛</div>
        <h3 className="font-bold text-slate-700">Live Haul Map — Mahuva Taluka</h3>
        <p className="mt-1 text-sm text-slate-500">
          Add <code className="rounded bg-slate-200 px-1 text-xs">VITE_GOOGLE_MAPS_KEY</code> to enable live tracking
        </p>
        <div className="mt-4 grid grid-cols-3 gap-2 text-xs">
          {VILLAGES.slice(0, 6).map((v) => (
            <div key={v.id} className="rounded-lg bg-white px-2 py-1.5 shadow-sm">
              <span className="font-semibold text-haul">{v.gujarati}</span>
              <p className="text-slate-400">{v.name}</p>
            </div>
          ))}
        </div>
        <div className="mt-4 flex items-center justify-center gap-4 text-xs text-slate-500">
          <span className="flex items-center gap-1"><span className="h-2.5 w-2.5 rounded-full bg-orange-400" />Farmer</span>
          <span className="flex items-center gap-1"><span className="h-2.5 w-2.5 rounded-full bg-haul" />Vehicle</span>
        </div>
      </div>
      {hauls.length > 0 && (
        <div className="absolute bottom-4 right-4 flex flex-col gap-2">
          {hauls.slice(0, 4).map((haul) => (
            <div key={haul.id} className="flex items-center gap-2 rounded-lg bg-white px-3 py-1.5 shadow-sm text-xs">
              <span className={`h-2 w-2 rounded-full ${STATUS_CONFIG[String(haul.status || '').toLowerCase()]?.dot || 'bg-slate-300'}`} />
              <span className="font-medium">{firstNonEmpty(haul.pickupVillage, haul.fromVillage) || '?'}</span>
              <Navigation size={10} className="text-slate-400" />
              <span>{haul.vehicleType || 'Tempo'}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

const FILTERS = ['all', 'searching', 'accepted', 'started', 'completed', 'cancelled']

export default function LiveHaulsPage() {
  const [bookings, setBookings] = useState([])
  const [filter, setFilter] = useState('all')
  const [villageFilter, setVillageFilter] = useState('all')
  const [selectedId, setSelectedId] = useState(null)

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'haul_bookings'), (snap) =>
      setBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
    )
    return () => unsub()
  }, [])

  const activeHauls = useMemo(() =>
    bookings.filter((b) => ['searching', 'accepted', 'started'].includes(String(b.status || '').toLowerCase())),
    [bookings])

  const filtered = useMemo(() =>
    [...bookings]
      .filter((b) => {
        const matchStatus = filter === 'all' || String(b.status || '').toLowerCase() === filter
        const matchVillage = villageFilter === 'all' || b.pickupVillage === villageFilter || b.fromVillage === villageFilter
        return matchStatus && matchVillage
      })
      .sort((a, b) => (toDate(b.timestamp || b.createdAt)?.getTime() || 0) - (toDate(a.timestamp || a.createdAt)?.getTime() || 0)),
    [bookings, filter, villageFilter])

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
                filter === f ? 'bg-haul text-white' : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              {f === 'all' ? `All (${bookings.length})` : f}
            </button>
          ))}
        </div>
        <select className="input ml-auto max-w-[180px]" value={villageFilter} onChange={(e) => setVillageFilter(e.target.value)}>
          <option value="all">All Villages</option>
          {VILLAGES.map((v) => <option key={v.id} value={v.name}>{v.name}</option>)}
        </select>
        <div className="flex items-center gap-2 rounded-lg bg-haul/10 px-3 py-1.5">
          <span className="h-2 w-2 rounded-full bg-haul animate-pulse" />
          <span className="text-xs font-semibold text-haul">{activeHauls.length} Active</span>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-5 lg:grid-cols-5">
        <div className="space-y-3 lg:col-span-2 max-h-[700px] overflow-y-auto pr-1">
          {filtered.length === 0 && (
            <EmptyTableState message="No haul bookings found." />
          )}
          {filtered.map((haul) => (
            <HaulCard
              key={haul.id}
              haul={haul}
              selected={selectedId === haul.id}
              onClick={() => setSelectedId(haul.id === selectedId ? null : haul.id)}
            />
          ))}
        </div>
        <div className="lg:col-span-3">
          <MapPlaceholder hauls={activeHauls} />
        </div>
      </div>
    </div>
  )
}

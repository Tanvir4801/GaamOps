import { collection, doc, onSnapshot, updateDoc } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import toast from 'react-hot-toast'
import StatusBadge from '../components/StatusBadge'
import EmptyTableState from '../components/EmptyTableState'
import { db } from '../firebase'

function toDate(value) {
  if (!value) return null
  if (typeof value?.toDate === 'function') return value.toDate()
  if (typeof value === 'object' && value.seconds != null)
    return new Date(Number(value.seconds) * 1000)
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

function formatRegisteredOn(driver) {
  const date = toDate(driver.registeredAt || driver.createdAt)
  if (!date) return '—'
  return date.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
}

function SaathiTable({ drivers, onStatusChange }) {
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full text-left text-sm">
        <thead className="bg-slate-50 text-slate-600">
          <tr>
            {['Name', 'Phone', 'Village', 'Vehicle', 'Registered', 'Status', 'Actions'].map((h) => (
              <th key={h} className="px-4 py-3 font-semibold">{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {drivers.map((driver) => (
            <tr key={driver.id} className="border-t border-slate-100 hover:bg-slate-50">
              <td className="px-4 py-3 font-medium">{driver.name || driver.fullName || '—'}</td>
              <td className="px-4 py-3 text-slate-600">{driver.phone || driver.phoneNumber || '—'}</td>
              <td className="px-4 py-3">{driver.village || '—'}</td>
              <td className="px-4 py-3">{driver.vehicle || driver.vehicleType || '—'}</td>
              <td className="px-4 py-3 text-slate-500 text-xs">{formatRegisteredOn(driver)}</td>
              <td className="px-4 py-3">
                <StatusBadge status={driver.status || 'pending'} />
              </td>
              <td className="px-4 py-3">
                <div className="flex flex-wrap gap-2">
                  <button type="button"
                    className="rounded-md bg-emerald-100 px-2.5 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-200"
                    onClick={() => onStatusChange(driver.id, 'active')}>
                    Approve
                  </button>
                  <button type="button"
                    className="rounded-md bg-rose-100 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-200"
                    onClick={() => onStatusChange(driver.id, 'blocked')}>
                    Block
                  </button>
                  <button type="button"
                    className="rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                    onClick={() => onStatusChange(driver.id, 'deactivated')}>
                    Deactivate
                  </button>
                </div>
              </td>
            </tr>
          ))}
          {drivers.length === 0 && (
            <tr><td colSpan={7} className="px-4 py-2">
              <EmptyTableState message="No Saathi found." />
            </td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}

function SaathiMapView({ drivers }) {
  const online = drivers.filter(d => d.isOnline)
  const offline = drivers.filter(d => !d.isOnline)

  return (
    <div className="p-6">
      <div className="mb-4 flex items-center gap-4 text-sm text-slate-600">
        <span className="flex items-center gap-1.5">
          <span className="h-3 w-3 rounded-full bg-green-500" /> {online.length} Online
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-3 w-3 rounded-full bg-gray-300" /> {offline.length} Offline
        </span>
      </div>
      <div className="mb-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-xs text-amber-800">
        📍 Live map requires Google Maps API. Saathi positions from Firestore — enable Maps API in Firebase project to show map.
      </div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {drivers.map((d) => (
          <div key={d.id} className="flex items-center gap-3 rounded-xl border border-gray-100 bg-white p-4 shadow-sm">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-green-50 text-base font-bold text-green-700">
              {(d.name || d.fullName || '?')[0].toUpperCase()}
            </div>
            <div className="min-w-0">
              <p className="truncate font-semibold text-slate-800">{d.name || d.fullName || '—'}</p>
              <p className="text-xs text-slate-500">{d.vehicle || d.vehicleType || '—'} · {d.village || '—'}</p>
            </div>
            <span className={`ml-auto h-2.5 w-2.5 shrink-0 rounded-full ${d.isOnline ? 'bg-green-500' : 'bg-gray-300'}`} />
          </div>
        ))}
      </div>
      {drivers.length === 0 && (
        <p className="py-10 text-center text-sm text-gray-400">No Saathis registered yet.</p>
      )}
    </div>
  )
}

export default function SaathiPage() {
  const [drivers, setDrivers] = useState([])
  const [villages, setVillages] = useState([])
  const [view, setView] = useState('table')
  const [statusFilter, setStatusFilter] = useState('all')
  const [villageFilter, setVillageFilter] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'saathis'), (snap) => {
        setDrivers(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      }),
      onSnapshot(collection(db, 'villages'), (snap) => {
        setVillages(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      }),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  const filteredDrivers = useMemo(() =>
    drivers.filter((driver) => {
      const q = searchQuery.trim().toLowerCase()
      const name = String(driver.name || driver.fullName || '').toLowerCase()
      const village = String(driver.village || '').toLowerCase()
      const searchMatch = !q || name.includes(q) || village.includes(q)
      const villageMatch = villageFilter === 'all' || driver.village === villageFilter
      const statusMatch = statusFilter === 'all' ||
        String(driver.status || '').toLowerCase() === statusFilter
      return searchMatch && villageMatch && statusMatch
    }),
    [drivers, searchQuery, statusFilter, villageFilter],
  )

  const updateStatus = async (driverId, status) => {
    try {
      await updateDoc(doc(db, 'saathis', driverId), { status })
      toast.success(`Saathi ${status} successfully`)
    } catch (err) {
      toast.error('Failed: ' + err.message)
    }
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end gap-3">
        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Search</label>
          <input
            type="text"
            className="input min-w-[220px]"
            placeholder="Search by name or village"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>
        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Village</label>
          <select
            className="input min-w-[180px]"
            value={villageFilter}
            onChange={(e) => setVillageFilter(e.target.value)}
          >
            <option value="all">All villages</option>
            {villages.map((v) => (
              <option key={v.id} value={v.name}>{v.name}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Status</label>
          <select
            className="input min-w-[160px]"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="all">All statuses</option>
            <option value="active">Active</option>
            <option value="pending">Pending</option>
            <option value="blocked">Blocked</option>
            <option value="deactivated">Deactivated</option>
          </select>
        </div>
        <div className="ml-auto flex overflow-hidden rounded-lg border border-gray-200">
          <button
            type="button"
            onClick={() => setView('table')}
            className={`px-4 py-2 text-sm font-medium transition-colors ${view === 'table' ? 'bg-orange-500 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}
          >
            📋 Table
          </button>
          <button
            type="button"
            onClick={() => setView('map')}
            className={`px-4 py-2 text-sm font-medium transition-colors ${view === 'map' ? 'bg-orange-500 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}
          >
            🗺️ Map
          </button>
        </div>
      </div>

      <section className="panel-card overflow-hidden">
        {view === 'table'
          ? <SaathiTable drivers={filteredDrivers} onStatusChange={updateStatus} />
          : <SaathiMapView drivers={filteredDrivers} />
        }
      </section>
    </div>
  )
}

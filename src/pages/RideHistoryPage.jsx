import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { Download, X } from 'lucide-react'
import { db } from '../firebase'
import { toDate, formatDate, firstNonEmpty, isSameDay } from '../utils/formatters'
import { VILLAGES } from '../utils/constants'
import { SkeletonRows } from '../components/SkeletonRow'
import EmptyTableState from '../components/EmptyTableState'

const STATUS_BADGE = {
  completed: 'badge-green',
  cancelled: 'badge-red',
  accepted: 'badge-yellow',
  started: 'badge-orange',
  searching: 'badge-blue',
}

function StatusBadge({ status }) {
  const s = String(status || '').toLowerCase()
  const cls = STATUS_BADGE[s] || 'badge-gray'
  return <span className={`badge ${cls}`}>{status || '—'}</span>
}

function RideModal({ ride, onClose }) {
  if (!ride) return null
  const from = firstNonEmpty(ride.pickupVillage, ride.pickupLocation, ride.pickup, ride.fromVillage) || '—'
  const to = firstNonEmpty(ride.dropLocation, ride.drop, ride.toVillage, ride.destinationVillage) || '—'
  const customer = firstNonEmpty(ride.customerName, ride.userName, ride.userPhone, ride.userId) || '—'
  const saathi = firstNonEmpty(ride.saathiName, ride.driverName, ride.assignedDriverName) || '—'

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between border-b border-slate-100 p-5">
          <h3 className="font-bold text-slate-800">Ride Details — #{ride.id?.slice(-6).toUpperCase()}</h3>
          <button type="button" onClick={onClose} className="rounded-lg p-1.5 hover:bg-slate-100"><X size={18} /></button>
        </div>
        <div className="grid grid-cols-2 gap-4 p-6">
          {[
            ['Customer', customer],
            ['Saathi', saathi],
            ['Pickup', from],
            ['Destination', to],
            ['Fare', ride.fare || ride.amount ? `₹${ride.fare || ride.amount}` : '—'],
            ['Status', <StatusBadge key="s" status={ride.status} />],
            ['Created', formatDate(ride.timestamp || ride.createdAt)],
            ['Type', ride.type || 'GaamRide'],
          ].map(([label, value]) => (
            <div key={label}>
              <p className="text-xs text-slate-500">{label}</p>
              <p className="mt-0.5 text-sm font-semibold text-slate-800">{value}</p>
            </div>
          ))}
        </div>
        <div className="flex justify-end gap-3 border-t border-slate-100 p-5">
          <button type="button" onClick={onClose} className="btn-secondary">Close</button>
        </div>
      </div>
    </div>
  )
}

function exportCSV(rows) {
  const headers = ['ID', 'Date', 'Customer', 'Saathi', 'From', 'To', 'Status', 'Fare', 'Type']
  const lines = rows.map((r) => [
    r.id,
    formatDate(r.timestamp || r.createdAt),
    firstNonEmpty(r.customerName, r.userName, r.userPhone) || '',
    firstNonEmpty(r.saathiName, r.driverName, r.assignedDriverName) || '',
    firstNonEmpty(r.pickupVillage, r.pickupLocation, r.fromVillage) || '',
    firstNonEmpty(r.dropLocation, r.drop, r.toVillage, r.destinationVillage) || '',
    r.status || '',
    r.fare || r.amount || '',
    r.type || 'GaamRide',
  ].map((v) => `"${String(v).replace(/"/g, '""')}"`).join(','))

  const csv = [headers.join(','), ...lines].join('\n')
  const blob = new Blob([csv], { type: 'text/csv' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `ride-history-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
}

export default function RideHistoryPage() {
  const [bookings, setBookings] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [villageFilter, setVillageFilter] = useState('all')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [selected, setSelected] = useState(null)

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'rides'), (snap) => {
      setBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      setLoading(false)
    })
    return () => unsub()
  }, [])

  const filtered = useMemo(() => {
    return [...bookings]
      .filter((b) => {
        const q = search.trim().toLowerCase()
        const customer = String(firstNonEmpty(b.customerName, b.userName, b.userPhone) || '').toLowerCase()
        const saathi = String(firstNonEmpty(b.saathiName, b.driverName, b.assignedDriverName) || '').toLowerCase()
        const matchSearch = !q || customer.includes(q) || saathi.includes(q)

        const matchStatus = statusFilter === 'all' || String(b.status || '').toLowerCase() === statusFilter
        const matchVillage = villageFilter === 'all' ||
          b.pickupVillage === villageFilter || b.fromVillage === villageFilter ||
          b.dropLocation === villageFilter || b.toVillage === villageFilter

        const d = toDate(b.timestamp || b.createdAt)
        const matchFrom = !dateFrom || (d && d.toISOString().slice(0, 10) >= dateFrom)
        const matchTo = !dateTo || (d && d.toISOString().slice(0, 10) <= dateTo)

        return matchSearch && matchStatus && matchVillage && matchFrom && matchTo
      })
      .sort((a, b) =>
        (toDate(b.timestamp || b.createdAt)?.getTime() || 0) -
        (toDate(a.timestamp || a.createdAt)?.getTime() || 0)
      )
  }, [bookings, search, statusFilter, villageFilter, dateFrom, dateTo])

  return (
    <div className="space-y-5">
      {selected && <RideModal ride={selected} onClose={() => setSelected(null)} />}

      <div className="flex flex-wrap items-end gap-3">
        <input
          type="text" className="input min-w-[220px]" placeholder="Search customer or saathi"
          value={search} onChange={(e) => setSearch(e.target.value)}
        />
        <select className="input min-w-[140px]" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="all">All Status</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled</option>
          <option value="accepted">Accepted</option>
          <option value="searching">Searching</option>
          <option value="started">Started</option>
        </select>
        <select className="input min-w-[150px]" value={villageFilter} onChange={(e) => setVillageFilter(e.target.value)}>
          <option value="all">All Villages</option>
          {VILLAGES.map((v) => <option key={v.id} value={v.name}>{v.name}</option>)}
        </select>
        <div className="flex items-center gap-2">
          <input type="date" className="input" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} />
          <span className="text-slate-400 text-sm">to</span>
          <input type="date" className="input" value={dateTo} onChange={(e) => setDateTo(e.target.value)} />
        </div>
        <button
          type="button"
          className="btn-secondary ml-auto flex items-center gap-2"
          onClick={() => exportCSV(filtered)}
        >
          <Download size={14} /> Export CSV
        </button>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="section-header flex items-center justify-between">
          <h3 className="font-bold text-slate-800">Ride History</h3>
          <span className="text-sm text-slate-500">{filtered.length} records</span>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Ride ID</th>
                <th className="px-4 py-3 font-semibold">Date</th>
                <th className="px-4 py-3 font-semibold">Customer</th>
                <th className="px-4 py-3 font-semibold">Saathi</th>
                <th className="px-4 py-3 font-semibold">Route</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Fare</th>
              </tr>
            </thead>
            <tbody>
              {loading && <SkeletonRows count={8} cols={7} />}
              {!loading && filtered.map((b) => (
                <tr
                  key={b.id}
                  className="border-t border-slate-100 hover:bg-slate-50 cursor-pointer"
                  onClick={() => setSelected(b)}
                >
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">#{b.id?.slice(-6).toUpperCase()}</td>
                  <td className="px-4 py-3 text-slate-600 whitespace-nowrap">
                    {formatDate(b.timestamp || b.createdAt, { year: undefined })}
                  </td>
                  <td className="px-4 py-3">{firstNonEmpty(b.customerName, b.userName, b.userPhone) || '—'}</td>
                  <td className="px-4 py-3">{firstNonEmpty(b.saathiName, b.driverName, b.assignedDriverName) || '—'}</td>
                  <td className="px-4 py-3 text-slate-600">
                    {firstNonEmpty(b.pickupVillage, b.fromVillage) || '?'} → {firstNonEmpty(b.dropLocation, b.toVillage) || '?'}
                  </td>
                  <td className="px-4 py-3"><StatusBadge status={b.status} /></td>
                  <td className="px-4 py-3 font-semibold text-brand">
                    {b.fare || b.amount ? `₹${b.fare || b.amount}` : '—'}
                  </td>
                </tr>
              ))}
              {!loading && filtered.length === 0 && (
                <tr><td colSpan={7} className="px-4 py-2"><EmptyTableState message="No rides found." /></td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

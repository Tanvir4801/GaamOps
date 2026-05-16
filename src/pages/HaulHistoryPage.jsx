import { collection, onSnapshot } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { Download, X } from 'lucide-react'
import { db } from '../firebase'
import { toDate, formatDate, firstNonEmpty } from '../utils/formatters'
import { VILLAGES } from '../utils/constants'
import { SkeletonRows } from '../components/SkeletonRow'
import EmptyTableState from '../components/EmptyTableState'

function StatusBadge({ status }) {
  const s = String(status || '').toLowerCase()
  const map = { completed: 'badge-green', cancelled: 'badge-red', started: 'badge-orange', accepted: 'badge-yellow', searching: 'badge-blue' }
  return <span className={`badge ${map[s] || 'badge-gray'}`}>{status || '—'}</span>
}

function HaulModal({ haul, onClose }) {
  if (!haul) return null
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content max-w-lg" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between border-b border-slate-100 p-5">
          <h3 className="font-bold text-slate-800">Haul #{haul.id?.slice(-6).toUpperCase()}</h3>
          <button type="button" onClick={onClose} className="rounded-lg p-1.5 hover:bg-slate-100"><X size={18} /></button>
        </div>
        <div className="grid grid-cols-2 gap-4 p-6">
          {[
            ['Farmer', firstNonEmpty(haul.customerName, haul.farmerName, haul.userName) || '—'],
            ['Vehicle Owner', firstNonEmpty(haul.vehicleOwnerName, haul.driverName) || '—'],
            ['Pickup', firstNonEmpty(haul.pickupVillage, haul.fromVillage, haul.pickupLocation) || '—'],
            ['Vehicle Type', haul.vehicleType || '—'],
            ['Load', haul.load || haul.goods || '—'],
            ['Commission', '₹75'],
            ['Status', <StatusBadge key="s" status={haul.status} />],
            ['Date', formatDate(haul.timestamp || haul.createdAt)],
          ].map(([label, value]) => (
            <div key={label}>
              <p className="text-xs text-slate-500">{label}</p>
              <p className="mt-0.5 text-sm font-semibold text-slate-800">{value}</p>
            </div>
          ))}
        </div>
        <div className="flex justify-end p-5 border-t border-slate-100">
          <button type="button" onClick={onClose} className="btn-secondary">Close</button>
        </div>
      </div>
    </div>
  )
}

export default function HaulHistoryPage() {
  const [bookings, setBookings] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [villageFilter, setVillageFilter] = useState('all')
  const [selected, setSelected] = useState(null)

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'haul_bookings'), (snap) => {
        setBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
        setLoading(false)
      }),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  const filtered = useMemo(() =>
    [...bookings]
      .filter((b) => {
        const q = search.trim().toLowerCase()
        const farmer = String(firstNonEmpty(b.customerName, b.farmerName, b.userName) || '').toLowerCase()
        const matchSearch = !q || farmer.includes(q)
        const matchStatus = statusFilter === 'all' || String(b.status || '').toLowerCase() === statusFilter
        const matchVillage = villageFilter === 'all' || b.pickupVillage === villageFilter || b.fromVillage === villageFilter
        return matchSearch && matchStatus && matchVillage
      })
      .sort((a, b) => (toDate(b.timestamp || b.createdAt)?.getTime() || 0) - (toDate(a.timestamp || a.createdAt)?.getTime() || 0)),
    [bookings, search, statusFilter, villageFilter])

  const exportCSV = () => {
    const rows = filtered.map((b) => [
      b.id,
      formatDate(b.timestamp || b.createdAt),
      firstNonEmpty(b.customerName, b.farmerName) || '',
      b.vehicleOwnerName || '',
      firstNonEmpty(b.pickupVillage, b.fromVillage) || '',
      b.vehicleType || '',
      b.status || '',
      75,
    ].map((v) => `"${String(v).replace(/"/g, '""')}"`).join(','))
    const csv = ['ID,Date,Farmer,Owner,Pickup,Vehicle,Status,Commission', ...rows].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = `haul-history-${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
  }

  return (
    <div className="space-y-5">
      {selected && <HaulModal haul={selected} onClose={() => setSelected(null)} />}
      <div className="flex flex-wrap items-end gap-3">
        <input type="text" className="input min-w-[200px]" placeholder="Search farmer name"
          value={search} onChange={(e) => setSearch(e.target.value)} />
        <select className="input min-w-[140px]" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="all">All Status</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled</option>
          <option value="started">In Progress</option>
        </select>
        <select className="input min-w-[150px]" value={villageFilter} onChange={(e) => setVillageFilter(e.target.value)}>
          <option value="all">All Villages</option>
          {VILLAGES.map((v) => <option key={v.id} value={v.name}>{v.name}</option>)}
        </select>
        <button type="button" onClick={exportCSV} className="btn-secondary ml-auto flex items-center gap-2">
          <Download size={14} /> Export CSV
        </button>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="section-header">
          <h3 className="font-bold text-slate-800">Haul History</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Haul ID</th>
                <th className="px-4 py-3 font-semibold">Date</th>
                <th className="px-4 py-3 font-semibold">Farmer</th>
                <th className="px-4 py-3 font-semibold">Vehicle Owner</th>
                <th className="px-4 py-3 font-semibold">Pickup</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Commission</th>
              </tr>
            </thead>
            <tbody>
              {loading && <SkeletonRows count={6} cols={7} />}
              {!loading && filtered.map((b) => (
                <tr key={b.id} className="border-t border-slate-100 hover:bg-slate-50 cursor-pointer" onClick={() => setSelected(b)}>
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">#{b.id?.slice(-6).toUpperCase()}</td>
                  <td className="px-4 py-3 text-slate-600 whitespace-nowrap">{formatDate(b.timestamp || b.createdAt, { year: undefined })}</td>
                  <td className="px-4 py-3">{firstNonEmpty(b.customerName, b.farmerName, b.userName) || '—'}</td>
                  <td className="px-4 py-3">{b.vehicleOwnerName || b.driverName || '—'}</td>
                  <td className="px-4 py-3 text-slate-600">{firstNonEmpty(b.pickupVillage, b.fromVillage) || '—'}</td>
                  <td className="px-4 py-3"><StatusBadge status={b.status} /></td>
                  <td className="px-4 py-3 font-semibold text-haul">₹75</td>
                </tr>
              ))}
              {!loading && filtered.length === 0 && (
                <tr><td colSpan={7} className="px-4 py-2"><EmptyTableState message="No haul bookings found." /></td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

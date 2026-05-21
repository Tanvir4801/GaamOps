import { useState } from 'react'
import { doc, updateDoc, deleteDoc, orderBy } from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useCollection } from '../hooks/useCollection.js'
import StatusBadge from '../components/StatusBadge.jsx'
import ConfirmModal from '../components/ConfirmModal.jsx'
import Spinner from '../components/Spinner.jsx'

const formatDate = (ts) => {
  if (!ts) return '—'
  if (ts?.toDate) return ts.toDate().toLocaleString('en-IN')
  if (ts instanceof Date) return ts.toLocaleString('en-IN')
  return '—'
}
const formatMoney = (n) => (n != null ? '₹' + Number(n).toLocaleString('en-IN') : '—')

const ACTIVE_STATUSES = ['searching', 'accepted', 'arriving', 'started']

export default function LiveRidesPage() {
  const { data: rides, loading } = useCollection('rides', orderBy('createdAt', 'desc'))
  const [statusFilter, setStatusFilter] = useState('all')
  const [villageFilter, setVillageFilter] = useState('')
  const [dateFilter, setDateFilter] = useState('')
  const [detail, setDetail] = useState(null)
  const [confirm, setConfirm] = useState(null)
  const [cancelConfirm, setCancelConfirm] = useState(null)

  const filtered = rides.filter((r) => {
    const matchStatus = statusFilter === 'all' || r.status === statusFilter
    const q = villageFilter.toLowerCase()
    const matchVillage = !q ||
      (r.pickupVillage || '').toLowerCase().includes(q) ||
      (r.destinationVillage || '').toLowerCase().includes(q)
    const matchDate = !dateFilter || (() => {
      const d = r.createdAt?.toDate ? r.createdAt.toDate() : null
      return d ? d.toISOString().slice(0, 10) === dateFilter : false
    })()
    return matchStatus && matchVillage && matchDate
  })

  const handleCancel = async (r) => {
    try {
      await updateDoc(doc(db, 'rides', r.id), {
        status: 'cancelled',
        cancelReason: 'Admin cancelled',
      })
      toast.success('Ride cancelled')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
    setCancelConfirm(null)
  }

  const handleDelete = async (id) => {
    try {
      await deleteDoc(doc(db, 'rides', id))
      toast.success('Deleted successfully')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
    setConfirm(null)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <h1 className="text-lg font-bold text-gray-800">Rides</h1>
          <span className="rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-semibold text-gray-600">{filtered.length}</span>
        </div>
        <div className="flex flex-wrap gap-2">
          <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300">
            <option value="all">All Statuses</option>
            {['searching','accepted','arriving','started','completed','cancelled'].map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
          <input type="text" value={villageFilter} onChange={(e) => setVillageFilter(e.target.value)}
            placeholder="Filter by village…"
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300 w-36" />
          <input type="date" value={dateFilter} onChange={(e) => setDateFilter(e.target.value)}
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300" />
        </div>
      </div>

      <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-10"><Spinner /></div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-2 p-10 text-gray-400">
            <span className="text-3xl">🛵</span>
            <p className="text-sm">No records found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  {['Ride ID','Customer','Saathi','Route','Status','Fare','Dist','OTP','Time','Actions'].map((h) => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.map((r, i) => (
                  <tr key={r.id} className={`hover:bg-gray-50 ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                    <td className="px-4 py-3 font-mono text-xs text-gray-500">{(r.rideId || r.id).slice(0,8)}</td>
                    <td className="px-4 py-3">
                      <p className="font-medium">{r.customerName || '—'}</p>
                      <p className="text-xs text-gray-400">{r.customerPhone || ''}</p>
                    </td>
                    <td className="px-4 py-3">
                      {r.saathiName ? (
                        <>
                          <p>{r.saathiName}</p>
                          <p className="text-xs text-gray-400">{r.saathiPhone}</p>
                        </>
                      ) : (
                        <span className="italic text-gray-400">Unassigned</span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-500">{r.pickupVillage} → {r.destinationVillage}</td>
                    <td className="px-4 py-3"><StatusBadge status={r.status} /></td>
                    <td className="px-4 py-3">{formatMoney(r.fare)}</td>
                    <td className="px-4 py-3 text-xs">{r.distance ? `${r.distance} km` : '—'}</td>
                    <td className="px-4 py-3 font-mono text-xs">{r.otp || '—'}</td>
                    <td className="px-4 py-3 text-xs text-gray-400">{formatDate(r.createdAt)}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        <button type="button" title="View" onClick={() => setDetail(r)} className="rounded p-1 hover:bg-gray-100">👁️</button>
                        {ACTIVE_STATUSES.includes(r.status) && (
                          <button type="button" title="Cancel" onClick={() => setCancelConfirm(r)} className="rounded p-1 hover:bg-orange-50">❌</button>
                        )}
                        {['completed','cancelled'].includes(r.status) && (
                          <button type="button" title="Delete" onClick={() => setConfirm(r)} className="rounded p-1 hover:bg-red-50">🗑️</button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {detail && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setDetail(null)}>
          <div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="mb-4 flex items-center justify-between">
              <h3 className="font-semibold text-gray-800">Ride Details</h3>
              <button type="button" onClick={() => setDetail(null)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>
            <div className="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
              {[
                ['Ride ID', detail.rideId || detail.id],
                ['Status', <StatusBadge key="s" status={detail.status} />],
                ['Customer', `${detail.customerName || '—'} (${detail.customerPhone || '—'})`],
                ['Saathi', detail.saathiName ? `${detail.saathiName} (${detail.saathiPhone})` : 'Unassigned'],
                ['Pickup', `${detail.pickupVillage} (${detail.pickupLat}, ${detail.pickupLng})`],
                ['Destination', `${detail.destinationVillage} (${detail.destinationLat}, ${detail.destinationLng})`],
                ['Saathi Location', detail.saathiLat ? `${detail.saathiLat}, ${detail.saathiLng}` : 'no data'],
                ['Fare', formatMoney(detail.fare)],
                ['Distance', detail.distance ? `${detail.distance} km` : '—'],
                ['OTP', detail.otp || '—'],
                ['Rating', detail.rating ?? '—'],
                ['Cancel Reason', detail.cancelReason || '—'],
                ['Created', formatDate(detail.createdAt)],
                ['Accepted', formatDate(detail.acceptedAt)],
                ['Started', formatDate(detail.startedAt)],
                ['Completed', formatDate(detail.completedAt)],
              ].map(([label, value]) => (
                <div key={label}>
                  <p className="text-xs font-semibold uppercase tracking-wide text-gray-400">{label}</p>
                  <p className="mt-0.5 text-gray-700">{value}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      <ConfirmModal
        isOpen={!!cancelConfirm}
        title="Cancel this ride?"
        message="This will set the ride status to cancelled. Admin cancelled reason will be recorded."
        onConfirm={() => handleCancel(cancelConfirm)}
        onCancel={() => setCancelConfirm(null)}
        confirmLabel="Cancel Ride"
      />
      <ConfirmModal
        isOpen={!!confirm}
        title="Delete ride?"
        message="This will permanently delete this ride record."
        onConfirm={() => handleDelete(confirm?.id)}
        onCancel={() => setConfirm(null)}
      />
    </div>
  )
}

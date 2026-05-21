import { useState } from 'react'
import { doc, updateDoc, deleteDoc, serverTimestamp, orderBy } from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useCollection } from '../hooks/useCollection.js'
import StatusBadge from '../components/StatusBadge.jsx'
import ConfirmModal from '../components/ConfirmModal.jsx'
import Spinner from '../components/Spinner.jsx'

const formatDate = (ts) => {
  if (!ts) return 'Never'
  if (ts?.toDate) return ts.toDate().toLocaleString('en-IN')
  if (ts instanceof Date) return ts.toLocaleString('en-IN')
  return '—'
}

export default function AllSaathiPage() {
  const { data: saathis, loading } = useCollection('saathis', orderBy('createdAt', 'desc'))
  const [search, setSearch] = useState('')
  const [vehicleFilter, setVehicleFilter] = useState('all')
  const [confirm, setConfirm] = useState(null)

  const filtered = saathis.filter((s) => {
    const q = search.toLowerCase()
    const matchSearch = !q ||
      (s.name || '').toLowerCase().includes(q) ||
      (s.phone || '').includes(q) ||
      (s.village || '').toLowerCase().includes(q)
    const matchVehicle = vehicleFilter === 'all' || s.vehicleType === vehicleFilter
    return matchSearch && matchVehicle
  })

  const handleToggleBlock = async (s) => {
    try {
      await updateDoc(doc(db, 'saathis', s.id), {
        isBlocked: !s.isBlocked,
        updatedAt: serverTimestamp(),
      })
      toast.success('Updated successfully')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
  }

  const handleToggleAvailable = async (s) => {
    try {
      await updateDoc(doc(db, 'saathis', s.id), {
        isAvailable: !s.isAvailable,
        isOnline: !s.isAvailable,
        updatedAt: serverTimestamp(),
      })
      toast.success('Updated successfully')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
  }

  const handleDelete = async (id) => {
    try {
      await deleteDoc(doc(db, 'saathis', id))
      toast.success('Deleted successfully')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
    setConfirm(null)
  }

  const Dot = ({ on }) => (
    <span className={`text-lg ${on ? 'text-green-500' : 'text-gray-300'}`}>●</span>
  )

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <h1 className="text-lg font-bold text-gray-800">Saathis</h1>
          <span className="rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-semibold text-gray-600">
            {filtered.length}
          </span>
        </div>
        <div className="flex flex-wrap gap-2">
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name, phone, village…"
            className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300 sm:w-56"
          />
          <select
            value={vehicleFilter}
            onChange={(e) => setVehicleFilter(e.target.value)}
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
          >
            <option value="all">All Vehicles</option>
            <option value="bike">Bike</option>
            <option value="auto">Auto</option>
            <option value="cycle">Cycle</option>
          </select>
        </div>
      </div>

      <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-10"><Spinner /></div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-2 p-10 text-gray-400">
            <span className="text-3xl">🚗</span>
            <p className="text-sm">No records found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  {['Name & Phone', 'Village', 'Vehicle', 'Online', 'Available', 'Rating', 'Rides', 'Blocked', 'Last Seen', 'Actions'].map((h) => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.map((s, i) => (
                  <tr key={s.id} className={`hover:bg-gray-50 ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                    <td className="px-4 py-3">
                      <p className="font-medium text-gray-800">{s.name || '—'}</p>
                      <p className="text-xs text-gray-400">{s.phone || '—'}</p>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{s.village || '—'}</td>
                    <td className="px-4 py-3 capitalize text-gray-600">{s.vehicleType || '—'}</td>
                    <td className="px-4 py-3"><Dot on={s.isOnline} /></td>
                    <td className="px-4 py-3"><Dot on={s.isAvailable} /></td>
                    <td className="px-4 py-3">⭐ {s.rating ?? '—'}</td>
                    <td className="px-4 py-3">{s.totalRides ?? 0}</td>
                    <td className="px-4 py-3">
                      <StatusBadge status={s.isBlocked ? 'blocked' : 'active'} />
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-400">{formatDate(s.lastSeen)}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        <button type="button" title={s.isBlocked ? 'Unblock' : 'Block'} onClick={() => handleToggleBlock(s)} className="rounded p-1 hover:bg-gray-100">
                          {s.isBlocked ? '✅' : '🚫'}
                        </button>
                        <button type="button" title="Toggle Availability" onClick={() => handleToggleAvailable(s)} className="rounded p-1 hover:bg-gray-100">
                          {s.isAvailable ? '🔴' : '🟢'}
                        </button>
                        <button type="button" title="Delete" onClick={() => setConfirm(s)} className="rounded p-1 hover:bg-red-50">
                          🗑️
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <ConfirmModal
        isOpen={!!confirm}
        title="Delete Saathi?"
        message={`This will permanently delete "${confirm?.name || confirm?.id}".`}
        onConfirm={() => handleDelete(confirm?.id)}
        onCancel={() => setConfirm(null)}
      />
    </div>
  )
}

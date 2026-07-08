import { useState } from 'react'
import {
  doc, updateDoc, serverTimestamp, orderBy,
  collection, setDoc, writeBatch
} from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useCollection } from '../hooks/useCollection.js'
import StatusBadge from '../components/StatusBadge.jsx'
import Spinner from '../components/Spinner.jsx'

const VILLAGES = [
  { id: 'mahuva', name: 'Mahuva', nameGu: 'મહુવા' },
  { id: 'anaval', name: 'Anaval', nameGu: 'અણવેલ' },
  { id: 'talaja', name: 'Talaja', nameGu: 'તળાજા' },
  { id: 'bavaliyari', name: 'Bavaliyari', nameGu: 'બાવળિયારી' },
  { id: 'una', name: 'Una', nameGu: 'ઉના' },
  { id: 'rajpara', name: 'Rajpara', nameGu: 'રાજપારા' },
  { id: 'dhari', name: 'Dhari', nameGu: 'ધારી' },
  { id: 'khambha', name: 'Khambha', nameGu: 'ખાંભા' },
  { id: 'sihor', name: 'Sihor', nameGu: 'સિહોર' },
]

const formatDate = (ts) => {
  if (!ts) return 'Never'
  if (ts?.toDate) return ts.toDate().toLocaleString('en-IN')
  if (ts instanceof Date) return ts.toLocaleString('en-IN')
  return '—'
}

function AddSaathiModal({ onClose, onSave }) {
  const [form, setForm] = useState({
    name: '', phone: '', village: '', vehicleType: 'bike', vehicleNumber: '',
  })
  const valid = form.name && form.phone && form.village && form.vehicleNumber

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl">
        <div className="mb-6 flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-800">Add New Saathi</h2>
          <button onClick={onClose} className="text-2xl text-gray-400 hover:text-gray-600">×</button>
        </div>
        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium text-gray-700">Name *</label>
            <input
              value={form.name}
              onChange={e => setForm({ ...form, name: e.target.value })}
              placeholder="Full name"
              className="mt-1 w-full rounded-xl border border-gray-200 px-4 py-3 focus:border-green-500 focus:outline-none"
            />
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Phone *</label>
            <div className="mt-1 flex gap-2">
              <span className="rounded-xl border border-gray-200 bg-gray-50 px-4 py-3 text-gray-500">+91</span>
              <input
                value={form.phone.replace('+91', '')}
                onChange={e => setForm({ ...form, phone: '+91' + e.target.value.replace(/\D/g, '').slice(0, 10) })}
                placeholder="10 digit number"
                maxLength={10}
                className="flex-1 rounded-xl border border-gray-200 px-4 py-3 focus:border-green-500 focus:outline-none"
              />
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Village *</label>
            <select
              value={form.village}
              onChange={e => setForm({ ...form, village: e.target.value })}
              className="mt-1 w-full rounded-xl border border-gray-200 px-4 py-3 focus:border-green-500 focus:outline-none"
            >
              <option value="">Select village</option>
              {VILLAGES.map(v => (
                <option key={v.id} value={v.name}>{v.nameGu} ({v.name})</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Vehicle Type *</label>
            <div className="mt-2 flex gap-3">
              {[
                { type: 'bike', emoji: '🛵', label: 'Bike' },
                { type: 'auto', emoji: '🛺', label: 'Auto' },
                { type: 'cycle', emoji: '🚲', label: 'Cycle' },
              ].map(({ type, emoji, label }) => (
                <button
                  key={type}
                  type="button"
                  onClick={() => setForm({ ...form, vehicleType: type })}
                  className={`flex-1 rounded-xl border-2 py-3 text-sm font-medium transition ${
                    form.vehicleType === type
                      ? 'border-green-600 bg-green-50 text-green-700'
                      : 'border-gray-200 text-gray-500'
                  }`}
                >
                  {emoji}<br />{label}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Vehicle Number *</label>
            <input
              value={form.vehicleNumber}
              onChange={e => setForm({ ...form, vehicleNumber: e.target.value.toUpperCase() })}
              placeholder="GJ 05 AB 1234"
              className="mt-1 w-full rounded-xl border border-gray-200 px-4 py-3 font-mono focus:border-green-500 focus:outline-none"
            />
          </div>
        </div>
        <div className="mt-6 flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 rounded-xl border border-gray-200 py-3 text-gray-600 transition hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={() => onSave(form)}
            disabled={!valid}
            className="flex-[2] rounded-xl bg-green-700 py-3 font-medium text-white transition hover:bg-green-800 disabled:cursor-not-allowed disabled:opacity-50"
          >
            Add Saathi ✅
          </button>
        </div>
      </div>
    </div>
  )
}

function EditSaathiModal({ saathi, onClose, onSave }) {
  const [form, setForm] = useState({
    name: saathi.name || '',
    village: saathi.village || '',
    vehicleType: saathi.vehicleType || 'bike',
    vehicleNumber: saathi.vehicleNumber || '',
    vehicleColor: saathi.vehicleColor || '',
  })

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl">
        <div className="mb-6 flex items-center justify-between">
          <h2 className="text-xl font-bold text-gray-800">Edit Saathi</h2>
          <button onClick={onClose} className="text-2xl text-gray-400 hover:text-gray-600">×</button>
        </div>
        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium text-gray-700">Name</label>
            <input
              value={form.name}
              onChange={e => setForm({ ...form, name: e.target.value })}
              className="mt-1 w-full rounded-xl border border-gray-200 px-4 py-3 focus:border-blue-500 focus:outline-none"
            />
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Village</label>
            <select
              value={form.village}
              onChange={e => setForm({ ...form, village: e.target.value })}
              className="mt-1 w-full rounded-xl border border-gray-200 px-4 py-3 focus:border-blue-500 focus:outline-none"
            >
              <option value="">Select village</option>
              {VILLAGES.map(v => (
                <option key={v.id} value={v.name}>{v.nameGu} ({v.name})</option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Vehicle Type</label>
            <div className="mt-2 flex gap-3">
              {['bike', 'auto', 'cycle'].map(type => (
                <button
                  key={type}
                  type="button"
                  onClick={() => setForm({ ...form, vehicleType: type })}
                  className={`flex-1 rounded-xl border-2 py-2 text-sm font-medium transition capitalize ${
                    form.vehicleType === type
                      ? 'border-blue-500 bg-blue-50 text-blue-700'
                      : 'border-gray-200 text-gray-500'
                  }`}
                >
                  {type}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Vehicle Number</label>
            <input
              value={form.vehicleNumber}
              onChange={e => setForm({ ...form, vehicleNumber: e.target.value.toUpperCase() })}
              className="mt-1 w-full rounded-xl border border-gray-200 px-4 py-3 font-mono focus:border-blue-500 focus:outline-none"
            />
          </div>
          <div>
            <label className="text-sm font-medium text-gray-700">Vehicle Color</label>
            <input
              value={form.vehicleColor}
              onChange={e => setForm({ ...form, vehicleColor: e.target.value })}
              placeholder="e.g. Red, Black"
              className="mt-1 w-full rounded-xl border border-gray-200 px-4 py-3 focus:border-blue-500 focus:outline-none"
            />
          </div>
        </div>
        <div className="mt-6 flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 rounded-xl border border-gray-200 py-3 text-gray-600 transition hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            onClick={() => onSave(form)}
            className="flex-[2] rounded-xl bg-blue-600 py-3 font-medium text-white transition hover:bg-blue-700"
          >
            Save Changes
          </button>
        </div>
      </div>
    </div>
  )
}

const Dot = ({ on }) => (
  <span className={`text-lg ${on ? 'text-green-500' : 'text-gray-300'}`}>●</span>
)

export default function AllSaathiPage() {
  const { data: saathis, loading } = useCollection('saathis', orderBy('createdAt', 'desc'))
  const [search, setSearch] = useState('')
  const [vehicleFilter, setVehicleFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [showAddModal, setShowAddModal] = useState(false)
  const [editSaathi, setEditSaathi] = useState(null)

  const filtered = saathis.filter(s => {
    if (s.isDeleted) return false
    const q = search.toLowerCase()
    const matchSearch = !q ||
      (s.name || '').toLowerCase().includes(q) ||
      (s.phone || '').includes(q) ||
      (s.village || '').toLowerCase().includes(q)
    const matchVehicle = vehicleFilter === 'all' || s.vehicleType === vehicleFilter
    const matchStatus = statusFilter === 'all' ||
      (statusFilter === 'online' && s.isOnline) ||
      (statusFilter === 'blocked' && s.isBlocked) ||
      (statusFilter === 'unverified' && !s.isVerified)
    return matchSearch && matchVehicle && matchStatus
  })

  const handleAddSaathi = async (data) => {
    try {
      // Use phone number (without +91) as temp docId so the Flutter app
      // can migrate it to a real UID when the Saathi logs in for the first time
      const phoneClean = data.phone.replace('+91', '').trim()
      const batch = writeBatch(db)

      // Write saathis doc — phone as docId (temp uid)
      batch.set(doc(db, 'saathis', phoneClean), {
        uid: phoneClean,
        name: data.name,
        phone: data.phone,
        village: data.village,
        vehicleType: data.vehicleType,
        vehicleNumber: data.vehicleNumber,
        vehicleColor: '',
        profilePhoto: '',
        isAvailable: false,
        isOnline: false,
        isBlocked: false,
        isVerified: false,
        status: 'pending',
        rating: 5.0,
        totalRides: 0,
        fcmToken: '',
        position: { geohash: '', geopoint: { latitude: 0, longitude: 0 } },
        lastSeen: serverTimestamp(),
        createdAt: serverTimestamp(),
      })

      // Also write a basic users doc so the Saathi can be found by phone
      batch.set(doc(db, 'users', phoneClean), {
        uid: phoneClean,
        name: data.name,
        displayName: data.name,
        phone: data.phone,
        role: 'saathi',
        village: data.village,
        profilePhoto: '',
        fcmToken: '',
        isBlocked: false,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })

      await batch.commit()
      toast.success(`${data.name} added! Will appear in Verifications. ✅`)
      setShowAddModal(false)
    } catch (e) {
      toast.error('Failed to add Saathi: ' + e.message)
    }
  }

  const handleUpdateSaathi = async (form) => {
    try {
      const batch = writeBatch(db)
      batch.update(doc(db, 'saathis', editSaathi.id), {
        ...form,
        updatedAt: serverTimestamp(),
      })
      if (form.name || form.village) {
        batch.update(doc(db, 'users', editSaathi.id), {
          ...(form.name && { name: form.name, displayName: form.name }),
          ...(form.village && { village: form.village }),
          updatedAt: serverTimestamp(),
        })
      }
      await batch.commit()
      toast.success('Saathi updated!')
      setEditSaathi(null)
    } catch (e) {
      toast.error('Update failed: ' + e.message)
    }
  }

  const handleToggleBlock = async (s) => {
    try {
      const batch = writeBatch(db)
      batch.update(doc(db, 'saathis', s.id), {
        isBlocked: !s.isBlocked,
        isAvailable: false,
        isOnline: false,
        updatedAt: serverTimestamp(),
      })
      batch.update(doc(db, 'users', s.id), {
        isBlocked: !s.isBlocked,
        updatedAt: serverTimestamp(),
      })
      await batch.commit()
      toast.success(s.isBlocked ? `${s.name} unblocked ✅` : `${s.name} blocked 🚫`)
    } catch (e) {
      toast.error('Error: ' + e.message)
    }
  }

  const handleVerify = async (s) => {
    try {
      await updateDoc(doc(db, 'saathis', s.id), {
        isVerified: true,
        verifiedAt: serverTimestamp(),
      })
      toast.success(`${s.name} verified! ✅`)
    } catch (e) {
      toast.error('Error: ' + e.message)
    }
  }

  const handleDelete = async (s) => {
    if (!window.confirm(`DELETE ${s.name}? This cannot be undone.`)) return
    try {
      const batch = writeBatch(db)
      batch.update(doc(db, 'saathis', s.id), {
        isDeleted: true,
        isAvailable: false,
        isOnline: false,
        isBlocked: true,
        deletedAt: serverTimestamp(),
      })
      batch.update(doc(db, 'users', s.id), {
        isDeleted: true,
        isBlocked: true,
        updatedAt: serverTimestamp(),
      })
      await batch.commit()
      toast.success(`${s.name} removed from platform`)
    } catch (e) {
      toast.error('Error: ' + e.message)
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-lg font-bold text-gray-800">Saathi Manager</h1>
            <span className="rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-semibold text-gray-600">
              {filtered.length}
            </span>
          </div>
          <p className="text-xs text-gray-500">
            {saathis.filter(s => !s.isDeleted && s.isOnline).length} online now ·{' '}
            {saathis.filter(s => !s.isDeleted && !s.isVerified).length} unverified
          </p>
        </div>
        <button
          onClick={() => setShowAddModal(true)}
          className="flex items-center gap-2 rounded-xl bg-green-700 px-4 py-2 text-sm font-medium text-white transition hover:bg-green-800"
        >
          + Add Saathi
        </button>
      </div>

      <div className="flex flex-wrap gap-2">
        <input
          type="text"
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search name, phone, village…"
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300 sm:w-56"
        />
        <select
          value={vehicleFilter}
          onChange={e => setVehicleFilter(e.target.value)}
          className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
        >
          <option value="all">All Vehicles</option>
          <option value="bike">🛵 Bike</option>
          <option value="auto">🛺 Auto</option>
          <option value="cycle">🚲 Cycle</option>
        </select>
        <select
          value={statusFilter}
          onChange={e => setStatusFilter(e.target.value)}
          className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
        >
          <option value="all">All Status</option>
          <option value="online">🟢 Online</option>
          <option value="blocked">🚫 Blocked</option>
          <option value="unverified">⚠️ Unverified</option>
        </select>
      </div>

      <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-10"><Spinner /></div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-2 p-10 text-gray-400">
            <span className="text-3xl">🛵</span>
            <p className="text-sm">No saathis found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  {['Name & Phone', 'Village', 'Vehicle', 'Online', 'Rating', 'Rides', 'Earnings', 'Verified', 'Status', 'Last Seen', 'Actions'].map(h => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.map((s, i) => (
                  <tr key={s.id} className={`hover:bg-gray-50 ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <div className={`flex h-9 w-9 items-center justify-center rounded-full text-sm font-bold text-white ${s.isBlocked ? 'bg-red-400' : 'bg-green-600'}`}>
                          {(s.name || '?')[0].toUpperCase()}
                        </div>
                        <div>
                          <p className="font-medium text-gray-800">{s.name || '—'}</p>
                          <p className="text-xs text-gray-400">{s.phone || '—'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{s.village || '—'}</td>
                    <td className="px-4 py-3">
                      <span className="rounded-lg bg-gray-100 px-2 py-1 text-xs capitalize text-gray-600">
                        {s.vehicleType || '—'}
                      </span>
                    </td>
                    <td className="px-4 py-3"><Dot on={s.isOnline} /></td>
                    <td className="px-4 py-3">⭐ {s.rating?.toFixed(1) || '5.0'}</td>
                    <td className="px-4 py-3 font-medium">{s.totalRides || 0}</td>
                    <td className="px-4 py-3 font-medium text-green-700">₹{(s.totalEarnings || 0).toLocaleString('en-IN')}</td>
                    <td className="px-4 py-3">
                      {s.isVerified ? (
                        <span className="text-xs text-green-600">✅ Yes</span>
                      ) : (
                        <button
                          onClick={() => handleVerify(s)}
                          className="rounded-lg bg-orange-100 px-2 py-1 text-xs text-orange-700 transition hover:bg-orange-200"
                        >
                          Verify
                        </button>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={s.isBlocked ? 'blocked' : 'active'} />
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-400">{formatDate(s.lastSeen)}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        <button
                          title="Edit"
                          onClick={() => setEditSaathi(s)}
                          className="rounded p-1.5 text-blue-600 transition hover:bg-blue-50"
                        >
                          ✏️
                        </button>
                        <button
                          title={s.isBlocked ? 'Unblock' : 'Block'}
                          onClick={() => handleToggleBlock(s)}
                          className={`rounded p-1.5 transition ${s.isBlocked ? 'text-green-600 hover:bg-green-50' : 'text-orange-600 hover:bg-orange-50'}`}
                        >
                          {s.isBlocked ? '🔓' : '🔒'}
                        </button>
                        <a
                          href={`https://wa.me/${(s.phone || '').replace('+', '')}`}
                          target="_blank"
                          rel="noreferrer"
                          title="WhatsApp"
                          className="rounded p-1.5 text-green-600 transition hover:bg-green-50"
                        >
                          💬
                        </a>
                        <button
                          title="Delete"
                          onClick={() => handleDelete(s)}
                          className="rounded p-1.5 text-red-500 transition hover:bg-red-50"
                        >
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

      {showAddModal && (
        <AddSaathiModal
          onClose={() => setShowAddModal(false)}
          onSave={handleAddSaathi}
        />
      )}

      {editSaathi && (
        <EditSaathiModal
          saathi={editSaathi}
          onClose={() => setEditSaathi(null)}
          onSave={handleUpdateSaathi}
        />
      )}
    </div>
  )
}

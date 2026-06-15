import { collection, doc, onSnapshot, updateDoc, addDoc, serverTimestamp } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { CheckCircle, XCircle, Clock, Truck, MessageSquare } from 'lucide-react'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { formatDateOnly } from '../utils/formatters'
import { SkeletonRows } from '../components/SkeletonRow'

export default function VerificationsPage() {
  const [saathi, setSaathi] = useState([])
  const [haulVehicles, setHaulVehicles] = useState([])
  const [loading, setLoading] = useState(true)
  const [haulLoading, setHaulLoading] = useState(true)
  const [rejectModal, setRejectModal] = useState(null)
  const [rejectReason, setRejectReason] = useState('')

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'saathis'), (snap) => {
        setSaathi(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
        setLoading(false)
      }),
      onSnapshot(collection(db, 'haul_vehicles'), (snap) => {
        setHaulVehicles(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
        setHaulLoading(false)
      }),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  // Pending = any saathi that is not yet verified and not deleted/blocked
  // Works for both app-registered (isVerified:false) and admin-added (status:'pending')
  const pending = useMemo(() =>
    saathi
      .filter((s) => {
        if (s.isDeleted || s.isBlocked) return false
        // admin-added saathi: status='pending'
        if (String(s.status || '').toLowerCase() === 'pending') return true
        // app-registered saathi: isVerified=false and no status yet
        if (s.isVerified === false && !s.status) return true
        return false
      })
      .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0)),
    [saathi])

  const pendingHaul = useMemo(() =>
    haulVehicles.filter((v) => String(v.status || '').toLowerCase() === 'pending')
      .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0)),
    [haulVehicles])

  const approve = async (s) => {
    await updateDoc(doc(db, 'saathis', s.id), {
      isVerified: true,
      status: 'active',
      approvedAt: serverTimestamp(),
    })
    toast.success(`${s.name || 'Saathi'} approved ✓`)
  }

  const openReject = (id, name) => {
    setRejectModal({ id, name })
    setRejectReason('')
  }

  const confirmReject = async () => {
    if (!rejectModal) return
    await updateDoc(doc(db, 'saathis', rejectModal.id), {
      isVerified: false,
      status: 'rejected',
      isBlocked: true,
      rejectionReason: rejectReason.trim() || 'No reason provided',
      rejectedAt: serverTimestamp(),
    })
    toast.error(`${rejectModal.name || 'Saathi'} rejected`)
    setRejectModal(null)
  }

  const approveHaul = async (id, name) => {
    await updateDoc(doc(db, 'haul_vehicles', id), {
      status: 'active',
      approvedAt: serverTimestamp(),
    })
    toast.success(`${name || 'Vehicle'} approved ✓`)
  }

  const rejectHaul = async (id, name) => {
    if (!window.confirm(`Reject vehicle application from ${name}?`)) return
    await updateDoc(doc(db, 'haul_vehicles', id), {
      status: 'rejected',
      rejectedAt: serverTimestamp(),
    })
    toast.error(`${name || 'Vehicle'} rejected`)
  }

  return (
    <div className="space-y-5">
      {rejectModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <div className="flex items-center gap-2 mb-4">
              <MessageSquare size={18} className="text-rose-500" />
              <h3 className="font-bold text-slate-800">Reject — {rejectModal.name}</h3>
            </div>
            <p className="text-sm text-slate-500 mb-3">
              Provide a reason (optional). The Saathi will see this message.
            </p>
            <textarea
              className="w-full rounded-xl border border-slate-200 p-3 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-rose-300"
              rows={3}
              placeholder="e.g. Vehicle RC copy unclear, please resubmit..."
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
            <div className="mt-4 flex gap-3">
              <button
                type="button"
                onClick={() => setRejectModal(null)}
                className="flex-1 rounded-xl border border-slate-200 py-2.5 text-sm font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={confirmReject}
                className="flex-1 rounded-xl bg-rose-500 py-2.5 text-sm font-semibold text-white hover:bg-rose-600"
              >
                Confirm Reject
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2 rounded-lg bg-amber-50 border border-amber-200 px-3 py-2">
          <Clock size={14} className="text-amber-600" />
          <span className="text-sm font-semibold text-amber-700">{pending.length} pending Saathi</span>
        </div>
        {pendingHaul.length > 0 && (
          <div className="flex items-center gap-2 rounded-lg bg-blue-50 border border-blue-200 px-3 py-2">
            <Truck size={14} className="text-blue-600" />
            <span className="text-sm font-semibold text-blue-700">{pendingHaul.length} pending GaamHaul vehicles</span>
          </div>
        )}
      </div>

      <div className="panel-card overflow-hidden">
        <div className="section-header">
          <h3 className="font-bold text-slate-800">Pending Saathi Verifications</h3>
          <p className="text-sm text-slate-500 mt-0.5">Review and approve or reject new Saathi registrations</p>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Name</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Vehicle</th>
                <th className="px-4 py-3 font-semibold">Vehicle No.</th>
                <th className="px-4 py-3 font-semibold">Source</th>
                <th className="px-4 py-3 font-semibold">Applied</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && <SkeletonRows count={5} cols={8} />}
              {!loading && pending.map((s) => (
                <tr key={s.id} className="border-t border-slate-100 hover:bg-amber-50/50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-amber-100 text-xs font-bold text-amber-700">
                        {(s.name || s.fullName || 'S').charAt(0).toUpperCase()}
                      </div>
                      <span className="font-medium text-slate-800">{s.name || s.fullName || '—'}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{s.phone || s.phoneNumber || '—'}</td>
                  <td className="px-4 py-3 text-slate-600">{s.village || '—'}</td>
                  <td className="px-4 py-3"><span className="badge badge-gray">{s.vehicleType || s.vehicle || '—'}</span></td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">{s.vehicleNumber || '—'}</td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                      s.status === 'pending'
                        ? 'bg-blue-100 text-blue-700'
                        : 'bg-green-100 text-green-700'
                    }`}>
                      {s.status === 'pending' ? 'Admin added' : 'App signup'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-slate-400">{formatDateOnly(s.registeredAt || s.createdAt)}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => approve(s)}
                        className="flex items-center gap-1.5 rounded-md bg-green-100 px-3 py-1.5 text-xs font-semibold text-green-700 hover:bg-green-200"
                      >
                        <CheckCircle size={13} /> Approve
                      </button>
                      <button
                        type="button"
                        onClick={() => openReject(s.id, s.name || s.fullName)}
                        className="flex items-center gap-1.5 rounded-md bg-rose-100 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-200"
                      >
                        <XCircle size={13} /> Reject…
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!loading && pending.length === 0 && (
                <tr>
                  <td colSpan={8} className="px-4 py-8 text-center">
                    <CheckCircle className="mx-auto mb-2 text-green-400" size={32} />
                    <p className="font-semibold text-slate-600">All caught up!</p>
                    <p className="text-sm text-slate-400">No pending Saathi verifications.</p>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="section-header flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2">
              <Truck size={16} className="text-blue-600" />
              <h3 className="font-bold text-slate-800">GaamHaul Vehicle Applications</h3>
            </div>
            <p className="text-sm text-slate-500 mt-0.5">Review haul vehicle owner registrations</p>
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Owner</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Vehicle Type</th>
                <th className="px-4 py-3 font-semibold">Reg. No.</th>
                <th className="px-4 py-3 font-semibold">Capacity</th>
                <th className="px-4 py-3 font-semibold">Applied</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {haulLoading && <SkeletonRows count={3} cols={7} />}
              {!haulLoading && pendingHaul.map((v) => (
                <tr key={v.id} className="border-t border-slate-100 hover:bg-blue-50/50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-700">
                        <Truck size={13} />
                      </div>
                      <span className="font-medium text-slate-800">{v.ownerName || v.name || '—'}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{v.ownerPhone || v.phone || '—'}</td>
                  <td className="px-4 py-3"><span className="badge badge-gray">{v.vehicleType || v.type || '—'}</span></td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">{v.registrationNumber || v.vehicleNumber || '—'}</td>
                  <td className="px-4 py-3 text-slate-600">{v.capacity ? `${v.capacity} ton` : '—'}</td>
                  <td className="px-4 py-3 text-xs text-slate-400">{formatDateOnly(v.createdAt)}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => approveHaul(v.id, v.ownerName || v.name)}
                        className="flex items-center gap-1.5 rounded-md bg-blue-100 px-3 py-1.5 text-xs font-semibold text-blue-700 hover:bg-blue-200"
                      >
                        <CheckCircle size={13} /> Approve
                      </button>
                      <button
                        type="button"
                        onClick={() => rejectHaul(v.id, v.ownerName || v.name)}
                        className="flex items-center gap-1.5 rounded-md bg-rose-100 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-200"
                      >
                        <XCircle size={13} /> Reject
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!haulLoading && pendingHaul.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center">
                    <Truck className="mx-auto mb-2 text-slate-300" size={28} />
                    <p className="text-sm text-slate-400">No pending GaamHaul vehicle applications.</p>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="section-header">
          <h3 className="font-bold text-slate-800">All Saathi — Status Overview</h3>
        </div>
        <div className="grid grid-cols-2 gap-0 divide-x divide-y divide-slate-100 sm:grid-cols-4">
          {[
            { label: 'Active', count: saathi.filter((s) => s.status === 'active' || (s.isVerified && !s.isBlocked && !s.isDeleted)).length, color: 'text-green-600 bg-green-50' },
            { label: 'Pending', count: pending.length, color: 'text-amber-600 bg-amber-50' },
            { label: 'Blocked', count: saathi.filter((s) => s.isBlocked && !s.isDeleted).length, color: 'text-rose-600 bg-rose-50' },
            { label: 'Rejected', count: saathi.filter((s) => String(s.status || '').toLowerCase() === 'rejected').length, color: 'text-slate-500 bg-slate-50' },
          ].map((item) => (
            <div key={item.label} className={`p-5 ${item.color}`}>
              <p className="text-3xl font-bold">{item.count}</p>
              <p className="mt-0.5 text-sm font-medium">{item.label}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

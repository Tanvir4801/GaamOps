import { collection, doc, onSnapshot, updateDoc, serverTimestamp } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import {
  CheckCircle, XCircle, Clock, Truck, MessageSquare,
  AlertTriangle, FileText, Eye, X as Close,
} from 'lucide-react'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { formatDateOnly } from '../utils/formatters'
import { SkeletonRows } from '../components/SkeletonRow'

export default function VerificationsPage() {
  const [saathi, setSaathi]             = useState([])
  const [haulVehicles, setHaulVehicles] = useState([])
  const [loading, setLoading]           = useState(true)
  const [haulLoading, setHaulLoading]   = useState(true)
  const [permError, setPermError]       = useState(false)
  const [busyIds, setBusyIds]           = useState(new Set())

  // Saathi reject modal
  const [rejectModal, setRejectModal]   = useState(null)
  const [rejectReason, setRejectReason] = useState('')

  // Haul reject modal
  const [haulRejectModal, setHaulRejectModal]   = useState(null)
  const [haulRejectReason, setHaulRejectReason] = useState('')

  // Document viewer modal { name, docs: [{label, url}] }
  const [docModal, setDocModal] = useState(null)
  const [docIndex, setDocIndex] = useState(0)

  // ── Firestore listeners ────────────────────────────────────────────────────
  useEffect(() => {
    const unsubs = [
      onSnapshot(
        collection(db, 'saathis'),
        (snap) => { setSaathi(snap.docs.map((d) => ({ id: d.id, ...d.data() }))); setLoading(false); setPermError(false) },
        (err) => { console.error(err); if (err.code === 'permission-denied') setPermError(true); setLoading(false) },
      ),
      onSnapshot(
        collection(db, 'haul_vehicles'),
        (snap) => { setHaulVehicles(snap.docs.map((d) => ({ id: d.id, ...d.data() }))); setHaulLoading(false) },
        (err) => { console.error(err); setHaulLoading(false) },
      ),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  // ── Derived data ───────────────────────────────────────────────────────────
  const pending = useMemo(() =>
    saathi
      .filter((s) => {
        if (s.isDeleted || s.isBlocked) return false
        if (String(s.status || '').toLowerCase() === 'pending') return true
        if (s.isVerified === false && !s.status) return true
        return false
      })
      .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0)),
    [saathi])

  const pendingHaul = useMemo(() =>
    haulVehicles
      .filter((v) => String(v.status || '').toLowerCase() === 'pending')
      .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0)),
    [haulVehicles])

  // ── Helpers ────────────────────────────────────────────────────────────────
  const setBusy = (id, val) =>
    setBusyIds((prev) => { const next = new Set(prev); val ? next.add(id) : next.delete(id); return next })

  // ── Saathi approve / reject ────────────────────────────────────────────────
  const approve = async (s) => {
    if (busyIds.has(s.id)) return
    setBusy(s.id, true)
    try {
      await updateDoc(doc(db, 'saathis', s.id), { isVerified: true, status: 'active', approvedAt: serverTimestamp() })
      toast.success(`${s.name || 'Saathi'} approved ✓`)
    } catch (err) {
      if (err.code === 'permission-denied') { setPermError(true); toast.error('Permission denied — update Firestore rules', { duration: 5000 }) }
      else toast.error('Approve failed: ' + err.message)
    } finally { setBusy(s.id, false) }
  }

  const confirmReject = async () => {
    if (!rejectModal) return
    const { id, name } = rejectModal
    if (busyIds.has(id)) return
    setBusy(id, true)
    try {
      await updateDoc(doc(db, 'saathis', id), {
        isVerified: false, status: 'rejected', isBlocked: true,
        rejectionReason: rejectReason.trim() || 'No reason provided',
        rejectedAt: serverTimestamp(),
      })
      toast.error(`${name || 'Saathi'} rejected`)
      setRejectModal(null)
    } catch (err) {
      if (err.code === 'permission-denied') setPermError(true)
      toast.error('Reject failed: ' + err.message)
    } finally { setBusy(id, false) }
  }

  // ── Haul approve / reject ─────────────────────────────────────────────────
  const approveHaul = async (id, name) => {
    if (busyIds.has(id)) return
    setBusy(id, true)
    try {
      await updateDoc(doc(db, 'haul_vehicles', id), {
        status: 'active', isVerified: true, approvedAt: serverTimestamp(),
      })
      toast.success(`${name || 'Vehicle'} approved ✓`)
    } catch (err) {
      if (err.code === 'permission-denied') { setPermError(true); toast.error('Permission denied — update Firestore rules', { duration: 5000 }) }
      else toast.error('Approve failed: ' + err.message)
    } finally { setBusy(id, false) }
  }

  const confirmHaulReject = async () => {
    if (!haulRejectModal) return
    const { id, name } = haulRejectModal
    if (busyIds.has(id)) return
    setBusy(id, true)
    try {
      await updateDoc(doc(db, 'haul_vehicles', id), {
        status: 'rejected',
        rejectionReason: haulRejectReason.trim() || 'No reason provided',
        rejectedAt: serverTimestamp(),
      })
      toast.error(`${name || 'Vehicle'} rejected`)
      setHaulRejectModal(null)
    } catch (err) {
      if (err.code === 'permission-denied') setPermError(true)
      toast.error('Reject failed: ' + err.message)
    } finally { setBusy(id, false) }
  }

  // ── Document viewer opener ─────────────────────────────────────────────────
  const openDocs = (v) => {
    const docs = [
      { label: 'DL Front', url: v.dlFrontUrl || '' },
      { label: 'DL Back', url: v.dlBackUrl || '' },
      { label: 'RC Book', url: v.rcUrl || '' },
      { label: 'Vehicle Photo', url: v.vehiclePhotoUrl || '' },
      { label: 'Insurance', url: v.insuranceUrl || '' },
      { label: 'PUC', url: v.pucUrl || '' },
    ].filter((d) => d.url)

    if (docs.length === 0) { toast('No documents uploaded yet.'); return }
    setDocModal({ name: v.ownerName || v.name || 'Vehicle Owner', docs })
    setDocIndex(0)
  }

  // ── Vehicle type label ─────────────────────────────────────────────────────
  const vehicleLabel = (type) => {
    const map = {
      chhota_hathi: 'Chhota Hathi', tata_ace_gold_cng: 'Tata Ace Gold CNG',
      mahindra_jeeto: 'Mahindra Jeeto', ashok_leyland_dost: 'Ashok Leyland Dost',
      maruti_super_carry: 'Maruti Super Carry', bolero_pickup: 'Bolero Pickup',
      tata_yodha: 'Tata Yodha', eicher_truck: 'Eicher Truck',
      tractor: 'Tractor', cargo_tempo: 'Cargo Tempo',
      cng_cargo: 'CNG Cargo', mini_tempo: 'Mini Tempo',
      pickup: 'Pickup', truck_407: '407 Truck',
    }
    return map[type] || type || '—'
  }

  // ── Render ─────────────────────────────────────────────────────────────────
  return (
    <div className="space-y-5">

      {/* ── Saathi Reject Modal ─────────────────────────────────────────── */}
      {rejectModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <div className="flex items-center gap-2 mb-3">
              <MessageSquare size={18} className="text-rose-500" />
              <h3 className="font-bold text-slate-800">Reject — {rejectModal.name}</h3>
            </div>
            <p className="text-sm text-slate-500 mb-3">Reason will be shown to the Saathi in the app.</p>
            <textarea
              className="w-full rounded-xl border border-slate-200 p-3 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-rose-300"
              rows={3}
              placeholder="e.g. DL copy unclear, please resubmit..."
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
            <div className="mt-4 flex gap-3">
              <button type="button" onClick={() => setRejectModal(null)}
                className="flex-1 rounded-xl border border-slate-200 py-2.5 text-sm font-semibold text-slate-600 hover:bg-slate-50">
                Cancel
              </button>
              <button type="button" disabled={busyIds.has(rejectModal.id)} onClick={confirmReject}
                className="flex-1 rounded-xl bg-rose-500 py-2.5 text-sm font-semibold text-white hover:bg-rose-600 disabled:opacity-60">
                {busyIds.has(rejectModal.id) ? 'Rejecting…' : 'Confirm Reject'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Haul Reject Modal ──────────────────────────────────────────────── */}
      {haulRejectModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <div className="flex items-center gap-2 mb-3">
              <Truck size={18} className="text-rose-500" />
              <h3 className="font-bold text-slate-800">Reject Vehicle — {haulRejectModal.name}</h3>
            </div>
            <p className="text-sm text-slate-500 mb-3">Reason will be sent to the Vahan Saathi via push notification.</p>
            <textarea
              className="w-full rounded-xl border border-slate-200 p-3 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-rose-300"
              rows={3}
              placeholder="e.g. RC book copy is unclear. Please re-upload a clearer photo."
              value={haulRejectReason}
              onChange={(e) => setHaulRejectReason(e.target.value)}
            />
            <div className="mt-4 flex gap-3">
              <button type="button" onClick={() => setHaulRejectModal(null)}
                className="flex-1 rounded-xl border border-slate-200 py-2.5 text-sm font-semibold text-slate-600 hover:bg-slate-50">
                Cancel
              </button>
              <button type="button" disabled={busyIds.has(haulRejectModal.id)} onClick={confirmHaulReject}
                className="flex-1 rounded-xl bg-rose-500 py-2.5 text-sm font-semibold text-white hover:bg-rose-600 disabled:opacity-60">
                {busyIds.has(haulRejectModal.id) ? 'Rejecting…' : 'Confirm Reject'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Document Viewer Modal ─────────────────────────────────────────── */}
      {docModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
          <div className="relative w-full max-w-2xl rounded-2xl bg-white overflow-hidden shadow-2xl">
            {/* Header */}
            <div className="flex items-center justify-between bg-slate-800 px-5 py-3">
              <div>
                <p className="font-bold text-white text-sm">{docModal.name} — Documents</p>
                <p className="text-xs text-slate-400">{docModal.docs[docIndex].label}</p>
              </div>
              <button onClick={() => setDocModal(null)} className="text-slate-400 hover:text-white">
                <Close size={20} />
              </button>
            </div>

            {/* Image */}
            <div className="bg-slate-900 flex items-center justify-center" style={{ minHeight: 380 }}>
              <img
                src={docModal.docs[docIndex].url}
                alt={docModal.docs[docIndex].label}
                className="max-h-96 max-w-full object-contain"
                onError={(e) => { e.target.style.display = 'none' }}
              />
            </div>

            {/* Tab strip */}
            <div className="flex gap-1 overflow-x-auto bg-slate-100 p-2">
              {docModal.docs.map((d, i) => (
                <button key={i} onClick={() => setDocIndex(i)}
                  className={`flex-shrink-0 rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                    docIndex === i
                      ? 'bg-slate-800 text-white'
                      : 'bg-white text-slate-600 hover:bg-slate-200'
                  }`}>
                  {d.label}
                </button>
              ))}
            </div>

            {/* Open in new tab */}
            <div className="border-t px-5 py-3 flex justify-end">
              <a href={docModal.docs[docIndex].url} target="_blank" rel="noreferrer"
                className="text-xs text-blue-600 hover:underline flex items-center gap-1">
                <Eye size={13} /> Open full size
              </a>
            </div>
          </div>
        </div>
      )}

      {/* Permission error banner */}
      {permError && (
        <div className="flex items-start gap-3 rounded-xl border border-amber-200 bg-amber-50 p-4">
          <AlertTriangle size={18} className="mt-0.5 flex-shrink-0 text-amber-500" />
          <div>
            <p className="font-semibold text-amber-800">Firestore permission denied</p>
            <p className="mt-0.5 text-sm text-amber-700">
              Go to <strong>Firebase Console → Firestore Database → Rules</strong> and add:
            </p>
            <pre className="mt-2 rounded-lg bg-amber-100 p-3 text-xs text-amber-900 overflow-x-auto select-all">
{`rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}`}
            </pre>
          </div>
        </div>
      )}

      {/* Summary badges */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2 rounded-lg bg-amber-50 border border-amber-200 px-3 py-2">
          <Clock size={14} className="text-amber-600" />
          <span className="text-sm font-semibold text-amber-700">{pending.length} pending Saathi</span>
        </div>
        {pendingHaul.length > 0 && (
          <div className="flex items-center gap-2 rounded-lg bg-blue-50 border border-blue-200 px-3 py-2">
            <Truck size={14} className="text-blue-600" />
            <span className="text-sm font-semibold text-blue-700">{pendingHaul.length} pending Vahan Saathi</span>
          </div>
        )}
      </div>

      {/* ── Saathi Verifications ──────────────────────────────────────────── */}
      <div className="panel-card overflow-hidden">
        <div className="section-header">
          <h3 className="font-bold text-slate-800">Pending Gaam Saathi Verifications</h3>
          <p className="text-sm text-slate-500 mt-0.5">Review and approve or reject new driver registrations</p>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Name</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Vehicle</th>
                <th className="px-4 py-3 font-semibold">Reg. No.</th>
                <th className="px-4 py-3 font-semibold">Applied</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && <SkeletonRows count={5} cols={7} />}
              {!loading && pending.map((s) => (
                <tr key={s.id} className="border-t border-slate-100 hover:bg-amber-50/50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      {s.profilePhoto
                        ? <img src={s.profilePhoto} className="h-8 w-8 rounded-full object-cover" alt="" />
                        : <div className="flex h-8 w-8 items-center justify-center rounded-full bg-amber-100 text-xs font-bold text-amber-700">
                            {(s.name || 'S').charAt(0).toUpperCase()}
                          </div>
                      }
                      <span className="font-medium text-slate-800">{s.name || '—'}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{s.phone || '—'}</td>
                  <td className="px-4 py-3 text-slate-600">{s.village || '—'}</td>
                  <td className="px-4 py-3">
                    <span className="badge badge-gray">{s.vehicleType || '—'}</span>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">{s.vehicleNumber || '—'}</td>
                  <td className="px-4 py-3 text-xs text-slate-400">{formatDateOnly(s.createdAt)}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <button type="button" disabled={busyIds.has(s.id)} onClick={() => approve(s)}
                        className="flex items-center gap-1.5 rounded-md bg-green-100 px-3 py-1.5 text-xs font-semibold text-green-700 hover:bg-green-200 disabled:opacity-60 disabled:cursor-not-allowed">
                        {busyIds.has(s.id) ? <><Spinner14 /> Saving…</> : <><CheckCircle size={13} /> Approve</>}
                      </button>
                      <button type="button" disabled={busyIds.has(s.id)}
                        onClick={() => { setRejectModal({ id: s.id, name: s.name }); setRejectReason('') }}
                        className="flex items-center gap-1.5 rounded-md bg-rose-100 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-200 disabled:opacity-60 disabled:cursor-not-allowed">
                        <XCircle size={13} /> Reject…
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!loading && pending.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-10 text-center">
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

      {/* ── Vahan Saathi (GaamHaul) Applications ─────────────────────────── */}
      <div className="panel-card overflow-hidden">
        <div className="section-header flex items-center justify-between">
          <div>
            <div className="flex items-center gap-2">
              <Truck size={16} className="text-blue-600" />
              <h3 className="font-bold text-slate-800">Vahan Saathi Applications</h3>
            </div>
            <p className="text-sm text-slate-500 mt-0.5">Review truck / tractor / tempo owner registrations</p>
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Owner</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Vehicle</th>
                <th className="px-4 py-3 font-semibold">Reg. No.</th>
                <th className="px-4 py-3 font-semibold">Capacity</th>
                <th className="px-4 py-3 font-semibold">Docs</th>
                <th className="px-4 py-3 font-semibold">Applied</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {haulLoading && <SkeletonRows count={3} cols={9} />}
              {!haulLoading && pendingHaul.map((v) => {
                const docCount = [v.dlFrontUrl, v.dlBackUrl, v.rcUrl, v.vehiclePhotoUrl]
                  .filter(Boolean).length
                return (
                  <tr key={v.id} className="border-t border-slate-100 hover:bg-blue-50/50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {v.profilePhotoUrl
                          ? <img src={v.profilePhotoUrl} className="h-8 w-8 rounded-full object-cover" alt="" />
                          : <div className="flex h-8 w-8 items-center justify-center rounded-full bg-blue-100">
                              <Truck size={13} className="text-blue-600" />
                            </div>
                        }
                        <span className="font-medium text-slate-800">{v.ownerName || v.name || '—'}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-slate-600">{v.phone || '—'}</td>
                    <td className="px-4 py-3 text-slate-600">{v.village || '—'}</td>
                    <td className="px-4 py-3">
                      <span className="badge badge-gray">{vehicleLabel(v.vehicleType)}</span>
                      {v.vehicleBrand && <div className="text-xs text-slate-400 mt-0.5">{v.vehicleBrand} {v.vehicleModel}</div>}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-slate-500">{v.vehicleNumber || '—'}</td>
                    <td className="px-4 py-3 text-slate-600">{v.capacity || '—'}</td>
                    <td className="px-4 py-3">
                      <button
                        onClick={() => openDocs(v)}
                        className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                          docCount >= 4
                            ? 'bg-green-100 text-green-700 hover:bg-green-200'
                            : 'bg-amber-100 text-amber-700 hover:bg-amber-200'
                        }`}>
                        <FileText size={12} />
                        {docCount}/4 docs
                      </button>
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-400">{formatDateOnly(v.createdAt)}</td>
                    <td className="px-4 py-3">
                      <div className="flex gap-2">
                        <button type="button" disabled={busyIds.has(v.id)}
                          onClick={() => approveHaul(v.id, v.ownerName || v.name)}
                          className="flex items-center gap-1.5 rounded-md bg-blue-100 px-3 py-1.5 text-xs font-semibold text-blue-700 hover:bg-blue-200 disabled:opacity-60 disabled:cursor-not-allowed">
                          {busyIds.has(v.id) ? <><Spinner14 /> Saving…</> : <><CheckCircle size={13} /> Approve</>}
                        </button>
                        <button type="button" disabled={busyIds.has(v.id)}
                          onClick={() => { setHaulRejectModal({ id: v.id, name: v.ownerName || v.name }); setHaulRejectReason('') }}
                          className="flex items-center gap-1.5 rounded-md bg-rose-100 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-200 disabled:opacity-60 disabled:cursor-not-allowed">
                          <XCircle size={13} /> Reject…
                        </button>
                      </div>
                    </td>
                  </tr>
                )
              })}
              {!haulLoading && pendingHaul.length === 0 && (
                <tr>
                  <td colSpan={9} className="px-4 py-10 text-center">
                    <Truck className="mx-auto mb-2 text-slate-300" size={28} />
                    <p className="font-semibold text-slate-600">No pending Vahan Saathi applications.</p>
                    <p className="text-sm text-slate-400">New applications from the app will appear here.</p>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Saathi Status Overview ─────────────────────────────────────────── */}
      <div className="panel-card overflow-hidden">
        <div className="section-header">
          <h3 className="font-bold text-slate-800">All Saathi — Status Overview</h3>
        </div>
        <div className="grid grid-cols-2 gap-0 divide-x divide-y divide-slate-100 sm:grid-cols-4">
          {[
            { label: 'Active',   count: saathi.filter((s) => s.status === 'active' || (s.isVerified && !s.isBlocked && !s.isDeleted)).length, color: 'text-green-600 bg-green-50' },
            { label: 'Pending',  count: pending.length, color: 'text-amber-600 bg-amber-50' },
            { label: 'Blocked',  count: saathi.filter((s) => s.isBlocked && !s.isDeleted).length, color: 'text-rose-600 bg-rose-50' },
            { label: 'Rejected', count: saathi.filter((s) => String(s.status || '').toLowerCase() === 'rejected').length, color: 'text-slate-500 bg-slate-50' },
          ].map((item) => (
            <div key={item.label} className={`p-5 ${item.color}`}>
              <p className="text-3xl font-bold">{item.count}</p>
              <p className="mt-0.5 text-sm font-medium">{item.label}</p>
            </div>
          ))}
        </div>
      </div>

      {/* ── Vahan Saathi Status Overview ──────────────────────────────────── */}
      <div className="panel-card overflow-hidden">
        <div className="section-header">
          <h3 className="font-bold text-slate-800">All Vahan Saathi — Status Overview</h3>
        </div>
        <div className="grid grid-cols-2 gap-0 divide-x divide-y divide-slate-100 sm:grid-cols-4">
          {[
            { label: 'Active',   count: haulVehicles.filter((v) => v.status === 'active' || v.status === 'approved').length, color: 'text-blue-600 bg-blue-50' },
            { label: 'Pending',  count: pendingHaul.length, color: 'text-amber-600 bg-amber-50' },
            { label: 'Rejected', count: haulVehicles.filter((v) => v.status === 'rejected').length, color: 'text-rose-600 bg-rose-50' },
            { label: 'Total',    count: haulVehicles.length, color: 'text-slate-600 bg-slate-50' },
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

function Spinner14() {
  return (
    <svg className="h-3.5 w-3.5 animate-spin inline mr-1" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
    </svg>
  )
}

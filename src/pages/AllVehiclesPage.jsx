import { useState, useMemo } from 'react'
import { doc, updateDoc, deleteDoc, setDoc, serverTimestamp, orderBy } from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useCollection } from '../hooks/useCollection.js'
import Spinner from '../components/Spinner.jsx'
import { CheckCircle, XCircle, Ban, Eye, FileText, X as Close, Shield, Truck, Star } from 'lucide-react'

const VEHICLE_TYPE_MAP = {
  chhota_hathi:        { label: 'Chhota Hathi', emoji: '🚚' },
  tata_ace_gold_cng:   { label: 'Tata Ace Gold CNG', emoji: '🚚' },
  mahindra_jeeto:      { label: 'Mahindra Jeeto', emoji: '🚚' },
  ashok_leyland_dost:  { label: 'Ashok Leyland Dost', emoji: '🚚' },
  maruti_super_carry:  { label: 'Maruti Super Carry', emoji: '🚚' },
  bolero_pickup:       { label: 'Bolero Pickup', emoji: '🛻' },
  tata_yodha:          { label: 'Tata Yodha Pickup', emoji: '🛻' },
  eicher_truck:        { label: 'Eicher Truck', emoji: '🚛' },
  tractor:             { label: 'Tractor', emoji: '🚜' },
  cargo_tempo:         { label: 'Cargo Tempo', emoji: '📦' },
  cng_cargo:           { label: 'CNG Cargo Vehicle', emoji: '⛽' },
  mini_tempo:          { label: 'Mini Tempo', emoji: '🚌' },
  pickup:              { label: 'Pickup Truck', emoji: '🛻' },
  truck_407:           { label: '407 Truck', emoji: '🚛' },
  other:               { label: 'Other', emoji: '🚗' },
}

const vehicleLabel = (type) => {
  const entry = VEHICLE_TYPE_MAP[type]
  if (entry) return `${entry.emoji} ${entry.label}`
  return type ? `🚗 ${type}` : '—'
}

const TABS = ['All', 'Pending', 'Approved', 'Rejected', 'Blocked']

const STATUS_STYLES = {
  pending:  { bg: 'bg-amber-50 text-amber-700 border-amber-200', dot: 'bg-amber-400' },
  active:   { bg: 'bg-green-50 text-green-700 border-green-200', dot: 'bg-green-400' },
  approved: { bg: 'bg-green-50 text-green-700 border-green-200', dot: 'bg-green-400' },
  rejected: { bg: 'bg-red-50 text-red-700 border-red-200', dot: 'bg-red-400' },
  blocked:  { bg: 'bg-gray-100 text-gray-600 border-gray-200', dot: 'bg-gray-400' },
}

function StatusPill({ v }) {
  const isBlocked = v.isBlocked
  const rawStatus = isBlocked ? 'blocked' : (v.status || 'pending')
  const s = STATUS_STYLES[rawStatus] || STATUS_STYLES.pending
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-semibold ${s.bg}`}>
      <span className={`h-1.5 w-1.5 rounded-full ${s.dot}`} />
      {isBlocked ? 'Blocked' : rawStatus.charAt(0).toUpperCase() + rawStatus.slice(1)}
    </span>
  )
}

function DocBadge({ count, total = 4, onClick }) {
  const complete = count >= total
  return (
    <button
      onClick={onClick}
      className={`flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-xs font-semibold transition-colors ${
        complete ? 'bg-green-100 text-green-700 hover:bg-green-200' : 'bg-amber-100 text-amber-700 hover:bg-amber-200'
      }`}
    >
      <FileText size={12} />
      {count}/{total}
    </button>
  )
}

function DocViewerModal({ vehicle, onClose }) {
  const [idx, setIdx] = useState(0)
  const docs = [
    { label: 'DL Front', url: vehicle.dlFrontUrl || '' },
    { label: 'DL Back', url: vehicle.dlBackUrl || '' },
    { label: 'RC Book', url: vehicle.rcUrl || '' },
    { label: 'Vehicle Photo', url: vehicle.vehiclePhotoUrl || '' },
    { label: 'Insurance', url: vehicle.insuranceUrl || '' },
    { label: 'PUC', url: vehicle.pucUrl || '' },
  ].filter(d => d.url)

  if (docs.length === 0) return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 text-center shadow-2xl">
        <FileText size={40} className="mx-auto mb-3 text-gray-300" />
        <p className="font-semibold text-gray-600">No documents uploaded yet</p>
        <button onClick={onClose} className="mt-4 rounded-xl bg-gray-100 px-6 py-2 text-sm font-medium text-gray-600 hover:bg-gray-200">Close</button>
      </div>
    </div>
  )

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4">
      <div className="relative w-full max-w-2xl overflow-hidden rounded-2xl bg-white shadow-2xl">
        <div className="flex items-center justify-between bg-slate-800 px-5 py-3.5">
          <div>
            <p className="font-bold text-white">{vehicle.ownerName || 'Owner'} — Documents</p>
            <p className="text-xs text-slate-400">{docs[idx]?.label}</p>
          </div>
          <button onClick={onClose} className="text-slate-400 hover:text-white"><Close size={20} /></button>
        </div>
        <div className="flex min-h-[340px] items-center justify-center bg-slate-900">
          <img
            src={docs[idx]?.url}
            alt={docs[idx]?.label}
            className="max-h-96 max-w-full object-contain"
            onError={(e) => { e.target.style.display = 'none' }}
          />
        </div>
        <div className="flex gap-1.5 overflow-x-auto bg-slate-100 p-2.5">
          {docs.map((d, i) => (
            <button key={i} onClick={() => setIdx(i)}
              className={`shrink-0 rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                i === idx ? 'bg-slate-800 text-white' : 'bg-white text-slate-600 hover:bg-slate-200'
              }`}>{d.label}</button>
          ))}
        </div>
        <div className="flex justify-end border-t px-5 py-3">
          <a href={docs[idx]?.url} target="_blank" rel="noreferrer"
            className="flex items-center gap-1 text-xs text-blue-600 hover:underline">
            <Eye size={13} /> Open full size
          </a>
        </div>
      </div>
    </div>
  )
}

function RejectModal({ vehicle, onClose, onConfirm, busy }) {
  const [reason, setReason] = useState('')
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl">
        <div className="mb-3 flex items-center gap-2">
          <XCircle size={18} className="text-red-500" />
          <h3 className="font-bold text-gray-800">Reject — {vehicle.ownerName}</h3>
        </div>
        <p className="mb-3 text-sm text-gray-500">Reason will be shown to the owner in the app.</p>
        <textarea
          className="w-full resize-none rounded-xl border border-gray-200 p-3 text-sm outline-none focus:ring-2 focus:ring-red-200"
          rows={3}
          placeholder="e.g. RC book photo is unclear, please resubmit..."
          value={reason}
          onChange={e => setReason(e.target.value)}
        />
        <div className="mt-4 flex gap-3">
          <button onClick={onClose}
            className="flex-1 rounded-xl border border-gray-200 py-2.5 text-sm font-semibold text-gray-600 hover:bg-gray-50">
            Cancel
          </button>
          <button disabled={busy} onClick={() => onConfirm(reason.trim() || 'No reason provided')}
            className="flex-1 rounded-xl bg-red-500 py-2.5 text-sm font-semibold text-white hover:bg-red-600 disabled:opacity-60">
            {busy ? 'Rejecting…' : 'Confirm Reject'}
          </button>
        </div>
      </div>
    </div>
  )
}

export default function AllVehiclesPage() {
  const { data: vehicles, loading } = useCollection('haul_vehicles', orderBy('createdAt', 'desc'))
  const [activeTab, setActiveTab] = useState('All')
  const [search, setSearch] = useState('')
  const [docViewer, setDocViewer] = useState(null)
  const [rejectTarget, setRejectTarget] = useState(null)
  const [busyIds, setBusyIds] = useState(new Set())

  const setBusy = (id, val) =>
    setBusyIds(prev => { const n = new Set(prev); val ? n.add(id) : n.delete(id); return n })

  const filtered = useMemo(() => {
    return vehicles.filter(v => {
      const q = search.toLowerCase()
      const matchSearch = !q ||
        (v.ownerName || '').toLowerCase().includes(q) ||
        (v.phone || '').includes(q) ||
        (v.vehicleNumber || '').toLowerCase().includes(q) ||
        (v.village || '').toLowerCase().includes(q)
      if (!matchSearch) return false

      const status = v.isBlocked ? 'blocked' : (v.status || 'pending')
      if (activeTab === 'All') return true
      if (activeTab === 'Pending') return status === 'pending'
      if (activeTab === 'Approved') return status === 'active' || status === 'approved'
      if (activeTab === 'Rejected') return status === 'rejected'
      if (activeTab === 'Blocked') return status === 'blocked'
      return true
    })
  }, [vehicles, activeTab, search])

  const counts = useMemo(() => {
    const c = { All: vehicles.length, Pending: 0, Approved: 0, Rejected: 0, Blocked: 0 }
    vehicles.forEach(v => {
      const s = v.isBlocked ? 'blocked' : (v.status || 'pending')
      if (s === 'pending') c.Pending++
      else if (s === 'active' || s === 'approved') c.Approved++
      else if (s === 'rejected') c.Rejected++
      else if (s === 'blocked') c.Blocked++
    })
    return c
  }, [vehicles])

  const approve = async (v) => {
    if (busyIds.has(v.id)) return
    setBusy(v.id, true)
    try {
      await updateDoc(doc(db, 'haul_vehicles', v.id), {
        status: 'active', isVerified: true, approvedAt: serverTimestamp(),
      })
      toast.success(`${v.ownerName || 'Vehicle'} approved ✓`)
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally { setBusy(v.id, false) }
  }

  const reject = async (v, reason) => {
    if (busyIds.has(v.id)) return
    setBusy(v.id, true)
    try {
      await updateDoc(doc(db, 'haul_vehicles', v.id), {
        status: 'rejected', isVerified: false,
        rejectionReason: reason, rejectedAt: serverTimestamp(),
      })
      toast.error(`${v.ownerName || 'Vehicle'} rejected`)
      setRejectTarget(null)
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally { setBusy(v.id, false) }
  }

  const toggleBlock = async (v) => {
    if (busyIds.has(v.id)) return
    setBusy(v.id, true)
    const blocking = !v.isBlocked
    try {
      await updateDoc(doc(db, 'haul_vehicles', v.id), {
        isBlocked: blocking, isAvailable: false,
        ...(blocking ? { blockedAt: serverTimestamp() } : { unblockedAt: serverTimestamp() }),
      })
      toast.success(blocking ? `${v.ownerName || 'Vehicle'} blocked 🚫` : `${v.ownerName || 'Vehicle'} unblocked ✓`)
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally { setBusy(v.id, false) }
  }

  const docCount = (v) => [v.dlFrontUrl, v.dlBackUrl, v.rcUrl, v.vehiclePhotoUrl].filter(Boolean).length

  return (
    <div className="space-y-4">
      {/* ── Header ── */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <Truck size={20} className="text-orange-500" />
            <h1 className="text-lg font-bold text-gray-800">Vahan Saathi Vehicles</h1>
            <span className="rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-semibold text-gray-600">{vehicles.length}</span>
          </div>
          <p className="mt-0.5 text-xs text-gray-500">
            {counts.Pending > 0 && <span className="font-semibold text-amber-600">{counts.Pending} pending review · </span>}
            {counts.Approved} approved · {counts.Blocked} blocked
          </p>
        </div>
      </div>

      {/* ── Tab Bar ── */}
      <div className="flex gap-1 overflow-x-auto rounded-xl border border-gray-100 bg-white p-1.5 shadow-sm">
        {TABS.map(tab => (
          <button key={tab} onClick={() => setActiveTab(tab)}
            className={`relative shrink-0 rounded-lg px-4 py-2 text-sm font-semibold transition-colors ${
              activeTab === tab
                ? 'bg-orange-500 text-white shadow-sm'
                : 'text-gray-500 hover:bg-gray-100'
            }`}>
            {tab}
            {counts[tab] > 0 && (
              <span className={`ml-1.5 rounded-full px-1.5 py-0.5 text-[10px] font-bold ${
                activeTab === tab ? 'bg-white/25 text-white' : 'bg-gray-100 text-gray-600'
              }`}>{counts[tab]}</span>
            )}
            {tab === 'Pending' && counts.Pending > 0 && activeTab !== tab && (
              <span className="absolute -right-0.5 -top-0.5 h-2.5 w-2.5 rounded-full bg-amber-400 ring-2 ring-white" />
            )}
          </button>
        ))}
      </div>

      {/* ── Search ── */}
      <input
        type="text"
        value={search}
        onChange={e => setSearch(e.target.value)}
        placeholder="Search owner, phone, vehicle number, village…"
        className="w-full rounded-xl border border-gray-200 bg-white px-4 py-2.5 text-sm shadow-sm outline-none focus:ring-2 focus:ring-orange-200 sm:w-72"
      />

      {/* ── Table ── */}
      <div className="overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-12"><Spinner /></div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center gap-3 p-12 text-gray-400">
            <Truck size={40} className="opacity-30" />
            <p className="text-sm font-medium">
              {search ? 'No vehicles match your search' : `No ${activeTab.toLowerCase()} vehicles`}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-gray-100 bg-gray-50/80">
                  {['Owner', 'Vehicle', 'Reg. No.', 'Village', 'Rate', 'Capacity', 'Status', 'Docs', 'Rating', 'Jobs', 'Actions'].map(h => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-400">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filtered.map((v) => {
                  const busy = busyIds.has(v.id)
                  const status = v.isBlocked ? 'blocked' : (v.status || 'pending')
                  const isPending = status === 'pending'
                  const isApproved = status === 'active' || status === 'approved'
                  const isBlocked = status === 'blocked'
                  const dc = docCount(v)
                  return (
                    <tr key={v.id} className={`transition-colors hover:bg-orange-50/30 ${isPending ? 'bg-amber-50/20' : ''}`}>
                      {/* Owner */}
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2.5">
                          {v.profilePhotoUrl
                            ? <img src={v.profilePhotoUrl} className="h-9 w-9 rounded-full object-cover ring-2 ring-orange-100" alt="" />
                            : <div className="flex h-9 w-9 items-center justify-center rounded-full bg-orange-100 text-sm font-bold text-orange-600">
                                {(v.ownerName || 'V').charAt(0).toUpperCase()}
                              </div>
                          }
                          <div>
                            <p className="font-semibold text-gray-800">{v.ownerName || '—'}</p>
                            <p className="text-xs text-gray-400">{v.phone || '—'}</p>
                          </div>
                        </div>
                      </td>
                      {/* Vehicle */}
                      <td className="px-4 py-3">
                        <div className="font-medium text-gray-700">{vehicleLabel(v.vehicleType)}</div>
                        {(v.vehicleBrand || v.vehicleModel) && (
                          <div className="text-xs text-gray-400">{[v.vehicleBrand, v.vehicleModel].filter(Boolean).join(' ')}</div>
                        )}
                      </td>
                      {/* Reg No */}
                      <td className="px-4 py-3 font-mono text-xs font-semibold text-gray-600">{v.vehicleNumber || '—'}</td>
                      {/* Village */}
                      <td className="px-4 py-3 text-gray-600">{v.village || '—'}</td>
                      {/* Rate */}
                      <td className="px-4 py-3">
                        <span className="rounded-lg bg-orange-50 px-2 py-1 text-xs font-semibold text-orange-700">
                          ₹{v.ratePerHour ?? '—'}/hr
                        </span>
                      </td>
                      {/* Capacity */}
                      <td className="px-4 py-3 text-gray-600 text-xs">{v.capacity || '—'}</td>
                      {/* Status */}
                      <td className="px-4 py-3"><StatusPill v={v} /></td>
                      {/* Docs */}
                      <td className="px-4 py-3">
                        <DocBadge count={dc} onClick={() => setDocViewer(v)} />
                      </td>
                      {/* Rating */}
                      <td className="px-4 py-3">
                        <span className="flex items-center gap-1 text-xs font-semibold text-amber-600">
                          <Star size={12} fill="currentColor" />
                          {v.rating ? Number(v.rating).toFixed(1) : '5.0'}
                        </span>
                      </td>
                      {/* Jobs */}
                      <td className="px-4 py-3 font-semibold text-gray-700">{v.totalBookings ?? 0}</td>
                      {/* Actions */}
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-1">
                          {/* View Docs */}
                          <button onClick={() => setDocViewer(v)} title="View Documents"
                            className="rounded-lg p-1.5 text-blue-500 hover:bg-blue-50 transition-colors">
                            <Eye size={15} />
                          </button>
                          {/* Approve — show if pending */}
                          {isPending && (
                            <button disabled={busy} onClick={() => approve(v)} title="Approve"
                              className="rounded-lg p-1.5 text-green-600 hover:bg-green-50 transition-colors disabled:opacity-50">
                              <CheckCircle size={15} />
                            </button>
                          )}
                          {/* Reject — show if pending or approved */}
                          {(isPending || isApproved) && (
                            <button disabled={busy} onClick={() => setRejectTarget(v)} title="Reject"
                              className="rounded-lg p-1.5 text-red-500 hover:bg-red-50 transition-colors disabled:opacity-50">
                              <XCircle size={15} />
                            </button>
                          )}
                          {/* Block / Unblock */}
                          <button disabled={busy} onClick={() => toggleBlock(v)}
                            title={isBlocked ? 'Unblock' : 'Block'}
                            className={`rounded-lg p-1.5 transition-colors disabled:opacity-50 ${
                              isBlocked
                                ? 'text-green-600 hover:bg-green-50'
                                : 'text-gray-400 hover:bg-gray-100'
                            }`}>
                            {isBlocked
                              ? <Shield size={15} />
                              : <Ban size={15} />}
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ── Modals ── */}
      {docViewer && <DocViewerModal vehicle={docViewer} onClose={() => setDocViewer(null)} />}
      {rejectTarget && (
        <RejectModal
          vehicle={rejectTarget}
          onClose={() => setRejectTarget(null)}
          onConfirm={(reason) => reject(rejectTarget, reason)}
          busy={busyIds.has(rejectTarget.id)}
        />
      )}
    </div>
  )
}

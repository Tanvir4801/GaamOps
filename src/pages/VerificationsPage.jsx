import { collection, doc, onSnapshot, updateDoc } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { CheckCircle, XCircle, Clock } from 'lucide-react'
import { db } from '../firebase'
import { formatDateOnly } from '../utils/formatters'
import Toast, { useToast } from '../components/Toast'
import { SkeletonRows } from '../components/SkeletonRow'
import EmptyTableState from '../components/EmptyTableState'

export default function VerificationsPage() {
  const [saathi, setSaathi] = useState([])
  const [loading, setLoading] = useState(true)
  const { toast, showToast } = useToast()

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'saathi'), (snap) => {
      setSaathi(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      setLoading(false)
    })
    return () => unsub()
  }, [])

  const pending = useMemo(() =>
    saathi.filter((s) => String(s.status || '').toLowerCase() === 'pending')
      .sort((a, b) => (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0)),
    [saathi])

  const approve = async (id, name) => {
    await updateDoc(doc(db, 'saathi', id), { status: 'active' })
    showToast(`${name || 'Saathi'} approved`)
  }

  const reject = async (id, name) => {
    await updateDoc(doc(db, 'saathi', id), { status: 'rejected' })
    showToast(`${name || 'Saathi'} rejected`, 'error')
  }

  return (
    <div className="space-y-5">
      <Toast show={toast.show} message={toast.message} type={toast.type} />

      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 rounded-lg bg-amber-50 border border-amber-200 px-3 py-2">
          <Clock size={14} className="text-amber-600" />
          <span className="text-sm font-semibold text-amber-700">{pending.length} pending verifications</span>
        </div>
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
                      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-amber-100 text-xs font-bold text-amber-700">
                        {(s.name || s.fullName || 'S').charAt(0).toUpperCase()}
                      </div>
                      <span className="font-medium text-slate-800">{s.name || s.fullName || '—'}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{s.phone || s.phoneNumber || '—'}</td>
                  <td className="px-4 py-3 text-slate-600">{s.village || '—'}</td>
                  <td className="px-4 py-3"><span className="badge badge-gray">{s.vehicle || s.vehicleType || '—'}</span></td>
                  <td className="px-4 py-3 font-mono text-xs text-slate-500">{s.vehicleNumber || '—'}</td>
                  <td className="px-4 py-3 text-xs text-slate-400">{formatDateOnly(s.registeredAt || s.createdAt)}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => approve(s.id, s.name || s.fullName)}
                        className="flex items-center gap-1.5 rounded-md bg-green-100 px-3 py-1.5 text-xs font-semibold text-green-700 hover:bg-green-200"
                      >
                        <CheckCircle size={13} /> Approve
                      </button>
                      <button
                        type="button"
                        onClick={() => reject(s.id, s.name || s.fullName)}
                        className="flex items-center gap-1.5 rounded-md bg-rose-100 px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-200"
                      >
                        <XCircle size={13} /> Reject
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!loading && pending.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-4 py-8 text-center">
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
        <div className="section-header">
          <h3 className="font-bold text-slate-800">All Saathi — Status Overview</h3>
        </div>
        <div className="grid grid-cols-2 gap-0 divide-x divide-y divide-slate-100 sm:grid-cols-4">
          {[
            { label: 'Active', count: saathi.filter((s) => String(s.status || '').toLowerCase() === 'active').length, color: 'text-green-600 bg-green-50' },
            { label: 'Pending', count: pending.length, color: 'text-amber-600 bg-amber-50' },
            { label: 'Blocked', count: saathi.filter((s) => String(s.status || '').toLowerCase() === 'blocked').length, color: 'text-rose-600 bg-rose-50' },
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

import { addDoc, collection, doc, onSnapshot, updateDoc } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { Plus, X } from 'lucide-react'
import { db } from '../firebase'
import { toDate, formatDateOnly } from '../utils/formatters'
import { VILLAGES, VEHICLE_TYPES } from '../utils/constants'
import Toast, { useToast } from '../components/Toast'
import ConfirmDialog from '../components/ConfirmDialog'
import { SkeletonRows } from '../components/SkeletonRow'
import EmptyTableState from '../components/EmptyTableState'

const HAUL_VEHICLES = ['Mini Tempo', 'Pickup Truck', 'Tractor', 'Large Truck']

function StatusDot({ status }) {
  const s = String(status || '').toLowerCase()
  if (s === 'active') return <span className="inline-flex items-center gap-1.5 text-xs font-medium text-green-600"><span className="h-2 w-2 rounded-full bg-green-500" />Available</span>
  if (s === 'blocked') return <span className="inline-flex items-center gap-1.5 text-xs font-medium text-rose-600"><span className="h-2 w-2 rounded-full bg-rose-500" />Blocked</span>
  return <span className="inline-flex items-center gap-1.5 text-xs font-medium text-slate-500"><span className="h-2 w-2 rounded-full bg-slate-300" />Offline</span>
}

const emptyForm = { ownerName: '', phone: '', village: '', vehicleType: '', capacity: '', ratePerHr: '', vehicleNumber: '' }

function AddVehicleModal({ onClose, onSave }) {
  const [form, setForm] = useState(emptyForm)
  const [saving, setSaving] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSaving(true)
    await onSave(form)
    setSaving(false)
    onClose()
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between border-b border-slate-100 p-5">
          <h3 className="font-bold text-slate-800">Add Vehicle Owner</h3>
          <button type="button" onClick={onClose} className="rounded-lg p-1.5 hover:bg-slate-100"><X size={18} /></button>
        </div>
        <form onSubmit={handleSubmit} className="grid grid-cols-2 gap-4 p-6">
          {[
            { name: 'ownerName', label: 'Owner Name', type: 'text', required: true },
            { name: 'phone', label: 'Phone Number', type: 'tel', required: true },
            { name: 'vehicleNumber', label: 'Vehicle Number', type: 'text' },
            { name: 'capacity', label: 'Capacity (kg)', type: 'number' },
            { name: 'ratePerHr', label: 'Rate per Hour (₹)', type: 'number' },
          ].map((f) => (
            <div key={f.name}>
              <label className="mb-1 block text-xs font-semibold text-slate-600">{f.label}</label>
              <input
                className="input" type={f.type} required={f.required}
                value={form[f.name]}
                onChange={(e) => setForm((p) => ({ ...p, [f.name]: e.target.value }))}
              />
            </div>
          ))}
          <div>
            <label className="mb-1 block text-xs font-semibold text-slate-600">Village</label>
            <select className="input" value={form.village} onChange={(e) => setForm((p) => ({ ...p, village: e.target.value }))} required>
              <option value="">Select village</option>
              {VILLAGES.map((v) => <option key={v.id} value={v.name}>{v.name}</option>)}
            </select>
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-slate-600">Vehicle Type</label>
            <select className="input" value={form.vehicleType} onChange={(e) => setForm((p) => ({ ...p, vehicleType: e.target.value }))} required>
              <option value="">Select type</option>
              {HAUL_VEHICLES.map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </div>
          <div className="col-span-2 flex justify-end gap-3 pt-2">
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
            <button type="submit" className="bg-haul hover:bg-haul-dark rounded-lg px-4 py-2 text-sm font-semibold text-white" disabled={saving}>
              {saving ? 'Adding…' : 'Add Vehicle Owner'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function AllVehiclesPage() {
  const [vehicles, setVehicles] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [villageFilter, setVillageFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [showAdd, setShowAdd] = useState(false)
  const [confirm, setConfirm] = useState(null)
  const { toast, showToast } = useToast()

  useEffect(() => {
    const unsub = onSnapshot(collection(db, 'haul_vehicles'), (snap) => {
      setVehicles(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      setLoading(false)
    })
    return () => unsub()
  }, [])

  const filtered = useMemo(() =>
    vehicles.filter((v) => {
      const q = search.trim().toLowerCase()
      const name = String(v.ownerName || v.name || '').toLowerCase()
      const phone = String(v.phone || '').toLowerCase()
      const matchSearch = !q || name.includes(q) || phone.includes(q)
      const matchVillage = villageFilter === 'all' || v.village === villageFilter
      const matchStatus = statusFilter === 'all' || String(v.status || '').toLowerCase() === statusFilter
      return matchSearch && matchVillage && matchStatus
    }), [vehicles, search, villageFilter, statusFilter])

  const handleAddVehicle = async (form) => {
    await addDoc(collection(db, 'haul_vehicles'), {
      ownerName: form.ownerName,
      phone: form.phone,
      village: form.village,
      vehicleType: form.vehicleType,
      capacity: form.capacity ? Number(form.capacity) : null,
      ratePerHr: form.ratePerHr ? Number(form.ratePerHr) : null,
      vehicleNumber: form.vehicleNumber,
      status: 'active',
      createdAt: new Date(),
    })
    showToast('Vehicle owner added successfully')
  }

  const handleBlock = (vehicle) => {
    setConfirm({ vehicle, action: 'block' })
  }

  const handleConfirm = async () => {
    if (!confirm) return
    const newStatus = confirm.action === 'block' ? 'blocked' : 'active'
    await updateDoc(doc(db, 'haul_vehicles', confirm.vehicle.id), { status: newStatus })
    showToast(`Vehicle owner ${newStatus === 'blocked' ? 'blocked' : 'unblocked'}`)
    setConfirm(null)
  }

  return (
    <div className="space-y-5">
      <Toast show={toast.show} message={toast.message} type={toast.type} />
      <ConfirmDialog
        open={!!confirm}
        title={confirm?.action === 'block' ? 'Block Vehicle Owner' : 'Unblock Vehicle Owner'}
        message={`Are you sure you want to ${confirm?.action} ${confirm?.vehicle?.ownerName || 'this owner'}?`}
        danger={confirm?.action === 'block'}
        confirmLabel={confirm?.action === 'block' ? 'Block' : 'Unblock'}
        onConfirm={handleConfirm}
        onCancel={() => setConfirm(null)}
      />
      {showAdd && <AddVehicleModal onClose={() => setShowAdd(false)} onSave={handleAddVehicle} />}

      <div className="flex flex-wrap gap-3">
        <input
          type="text" className="input min-w-[200px]" placeholder="Search by name or phone"
          value={search} onChange={(e) => setSearch(e.target.value)}
        />
        <select className="input min-w-[150px]" value={villageFilter} onChange={(e) => setVillageFilter(e.target.value)}>
          <option value="all">All Villages</option>
          {VILLAGES.map((v) => <option key={v.id} value={v.name}>{v.name}</option>)}
        </select>
        <select className="input min-w-[130px]" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="all">All Status</option>
          <option value="active">Active</option>
          <option value="blocked">Blocked</option>
        </select>
        <button
          type="button"
          className="ml-auto flex items-center gap-2 rounded-lg bg-haul px-4 py-2 text-sm font-semibold text-white hover:bg-haul-dark"
          onClick={() => setShowAdd(true)}
        >
          <Plus size={14} /> Add Vehicle Owner
        </button>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Owner</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Vehicle Type</th>
                <th className="px-4 py-3 font-semibold">Capacity</th>
                <th className="px-4 py-3 font-semibold">Rate/hr</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && <SkeletonRows count={5} cols={8} />}
              {!loading && filtered.map((v) => (
                <tr key={v.id} className="border-t border-slate-100 hover:bg-slate-50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-haul/15 text-xs font-bold text-haul">
                        {(v.ownerName || v.name || 'V').charAt(0).toUpperCase()}
                      </div>
                      <span className="font-medium text-slate-800">{v.ownerName || v.name || '—'}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{v.phone || '—'}</td>
                  <td className="px-4 py-3 text-slate-600">{v.village || '—'}</td>
                  <td className="px-4 py-3">
                    <span className="badge badge-orange">{v.vehicleType || '—'}</span>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{v.capacity ? `${v.capacity} kg` : '—'}</td>
                  <td className="px-4 py-3 font-semibold text-haul">{v.ratePerHr ? `₹${v.ratePerHr}` : '—'}</td>
                  <td className="px-4 py-3"><StatusDot status={v.status} /></td>
                  <td className="px-4 py-3">
                    {String(v.status || '').toLowerCase() === 'blocked' ? (
                      <button
                        type="button"
                        className="rounded-md bg-green-100 px-2.5 py-1 text-xs font-semibold text-green-700 hover:bg-green-200"
                        onClick={() => setConfirm({ vehicle: v, action: 'unblock' })}
                      >Unblock</button>
                    ) : (
                      <button
                        type="button"
                        className="rounded-md bg-rose-100 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-200"
                        onClick={() => handleBlock(v)}
                      >Block</button>
                    )}
                  </td>
                </tr>
              ))}
              {!loading && filtered.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-2"><EmptyTableState message="No vehicles found." /></td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

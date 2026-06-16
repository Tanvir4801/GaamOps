import { useState } from 'react'
import { doc, updateDoc, deleteDoc, setDoc, serverTimestamp, orderBy } from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useCollection } from '../hooks/useCollection.js'
import ConfirmModal from '../components/ConfirmModal.jsx'
import Spinner from '../components/Spinner.jsx'

const VEHICLE_TYPES = ['mini_tempo', 'pickup', 'tractor', 'truck_407']

const EMPTY_FORM = {
  uid: '', ownerName: '', phone: '', village: '',
  vehicleType: 'mini_tempo', capacity: '', ratePerHour: '', vehicleNumber: '', isAvailable: true,
}

function VehicleField({ label, name, type = 'text', value, onChange, children }) {
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-gray-600">{label}</label>
      {children || (
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(name, e.target.value)}
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
        />
      )}
    </div>
  )
}

export default function AllVehiclesPage() {
  const { data: vehicles, loading } = useCollection('haul_vehicles', orderBy('createdAt', 'desc'))
  const [confirm, setConfirm] = useState(null)
  const [showAdd, setShowAdd] = useState(false)
  const [editTarget, setEditTarget] = useState(null)
  const [form, setForm] = useState(EMPTY_FORM)
  const [saving, setSaving] = useState(false)

  const handleChange = (name, value) => setForm((prev) => ({ ...prev, [name]: value }))

  const openAdd = () => { setForm(EMPTY_FORM); setEditTarget(null); setShowAdd(true) }
  const openEdit = (v) => {
    setForm({
      uid: v.uid || v.id, ownerName: v.ownerName || '', phone: v.phone || '',
      village: v.village || '', vehicleType: v.vehicleType || 'mini_tempo',
      capacity: v.capacity || '', ratePerHour: v.ratePerHour ?? '', vehicleNumber: v.vehicleNumber || '',
      isAvailable: v.isAvailable !== false,
    })
    setEditTarget(v)
    setShowAdd(true)
  }

  const handleSave = async (e) => {
    e.preventDefault()
    const { uid, ownerName, phone, village, vehicleType, capacity, ratePerHour, vehicleNumber, isAvailable } = form
    if (!uid || !ownerName || !phone || !village || !vehicleType || !capacity || !ratePerHour || !vehicleNumber) {
      toast.error('Please fill all required fields')
      return
    }
    setSaving(true)
    try {
      if (editTarget) {
        await updateDoc(doc(db, 'haul_vehicles', editTarget.id), {
          ownerName, phone, village, vehicleType, capacity,
          ratePerHour: Number(ratePerHour), vehicleNumber, isAvailable,
          updatedAt: serverTimestamp(),
        })
        toast.success('Updated successfully')
      } else {
        await setDoc(doc(db, 'haul_vehicles', uid), {
          uid, ownerName, phone, village, vehicleType, capacity,
          ratePerHour: Number(ratePerHour), vehicleNumber, isAvailable,
          totalBookings: 0, fcmToken: '', lastSeen: null,
          createdAt: serverTimestamp(),
        })
        toast.success('Vehicle added')
      }
      setShowAdd(false)
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (id) => {
    try {
      await deleteDoc(doc(db, 'haul_vehicles', id))
      toast.success('Deleted successfully')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
    setConfirm(null)
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <h1 className="text-lg font-bold text-gray-800">Haul Vehicles</h1>
          <span className="rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-semibold text-gray-600">{vehicles.length}</span>
        </div>
        <button type="button" onClick={openAdd}
          className="rounded-lg px-4 py-2 text-sm font-semibold text-white" style={{ backgroundColor: '#f97316' }}>
          ➕ Add Vehicle
        </button>
      </div>

      <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-10"><Spinner /></div>
        ) : vehicles.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-2 p-10 text-gray-400">
            <span className="text-3xl">🚛</span>
            <p className="text-sm">No records found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  {['Owner','Phone','Village','Vehicle','Capacity','Rate/Hour','Vehicle No','Available','Total Bookings','Actions'].map((h) => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {vehicles.map((v, i) => (
                  <tr key={v.id} className={`hover:bg-gray-50 ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                    <td className="px-4 py-3 font-medium text-gray-800">{v.ownerName || '—'}</td>
                    <td className="px-4 py-3 text-gray-600">{v.phone || '—'}</td>
                    <td className="px-4 py-3 text-gray-600">{v.village || '—'}</td>
                    <td className="px-4 py-3 capitalize">{v.vehicleType || '—'}</td>
                    <td className="px-4 py-3">{v.capacity || '—'}</td>
                    <td className="px-4 py-3">₹{v.ratePerHour ?? '—'}/hr</td>
                    <td className="px-4 py-3 font-mono text-xs">{v.vehicleNumber || '—'}</td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${v.isAvailable ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
                        {v.isAvailable ? 'Yes' : 'No'}
                      </span>
                    </td>
                    <td className="px-4 py-3">{v.totalBookings ?? 0}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        <button type="button" title="Edit" onClick={() => openEdit(v)} className="rounded p-1 hover:bg-gray-100">✏️</button>
                        <button type="button" title="Delete" onClick={() => setConfirm(v)} className="rounded p-1 hover:bg-red-50">🗑️</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {showAdd && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setShowAdd(false)}>
          <div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="mb-4 flex items-center justify-between">
              <h3 className="font-semibold text-gray-800">{editTarget ? 'Edit Vehicle' : 'Add Vehicle'}</h3>
              <button type="button" onClick={() => setShowAdd(false)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>
            <form onSubmit={handleSave} className="space-y-3">
              {!editTarget && (
                <VehicleField label="Firebase Auth UID *" name="uid" value={form.uid} onChange={handleChange} />
              )}
              <div className="grid grid-cols-2 gap-3">
                <VehicleField label="Owner Name *" name="ownerName" value={form.ownerName} onChange={handleChange} />
                <VehicleField label="Phone *" name="phone" value={form.phone} onChange={handleChange} />
                <VehicleField label="Village *" name="village" value={form.village} onChange={handleChange} />
                <VehicleField label="Vehicle Number *" name="vehicleNumber" value={form.vehicleNumber} onChange={handleChange} />
                <VehicleField label="Capacity *" name="capacity" value={form.capacity} onChange={handleChange} />
                <VehicleField label="Rate per Hour (₹) *" name="ratePerHour" type="number" value={form.ratePerHour} onChange={handleChange} />
              </div>
              <VehicleField label="Vehicle Type *" name="vehicleType" value={form.vehicleType} onChange={handleChange}>
                <select value={form.vehicleType} onChange={(e) => handleChange('vehicleType', e.target.value)}
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300">
                  {VEHICLE_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
              </VehicleField>
              <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
                <input type="checkbox" checked={form.isAvailable} onChange={(e) => handleChange('isAvailable', e.target.checked)} />
                Available
              </label>
              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={() => setShowAdd(false)} className="rounded-lg border border-gray-200 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button type="submit" disabled={saving} className="rounded-lg px-4 py-2 text-sm font-semibold text-white disabled:opacity-60" style={{ backgroundColor: '#f97316' }}>
                  {saving ? 'Saving…' : (editTarget ? 'Save Changes' : 'Add Vehicle')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <ConfirmModal isOpen={!!confirm} title="Delete vehicle?" message={`Delete "${confirm?.ownerName}"'s vehicle?`} onConfirm={() => handleDelete(confirm?.id)} onCancel={() => setConfirm(null)} />
    </div>
  )
}

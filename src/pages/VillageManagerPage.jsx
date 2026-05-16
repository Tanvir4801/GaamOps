import { addDoc, collection, doc, onSnapshot, setDoc, deleteDoc } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { Plus, Edit2, Trash2, X, MapPin, CheckCircle, XCircle } from 'lucide-react'
import { db } from '../firebase'
import { VILLAGES as DEFAULT_VILLAGES } from '../utils/constants'
import Toast, { useToast } from '../components/Toast'
import ConfirmDialog from '../components/ConfirmDialog'

const EMPTY_FORM = { name: '', gujarati: '', lat: '', lng: '', taluka: 'Mahuva', active: true }

function VillageCard({ village, activeSaathi, onEdit, onToggle, onDelete }) {
  const isActive = village.active !== false
  return (
    <div className={`panel-card p-5 transition ${isActive ? '' : 'opacity-60'}`}>
      <div className="flex items-start justify-between gap-2">
        <div>
          <h3 className="font-bold text-slate-800">{village.gujarati || village.name}</h3>
          <p className="text-sm text-slate-500">{village.name}</p>
        </div>
        <span className={`badge ${isActive ? 'badge-green' : 'badge-red'}`}>
          {isActive ? '✅ Active' : '❌ Inactive'}
        </span>
      </div>
      <div className="mt-3 grid grid-cols-2 gap-2 text-xs text-slate-500">
        <div><span className="font-medium">Lat:</span> {village.lat || '—'}</div>
        <div><span className="font-medium">Lng:</span> {village.lng || '—'}</div>
        <div><span className="font-medium">Taluka:</span> {village.taluka || 'Mahuva'}</div>
        <div><span className="font-medium">Active Saathi:</span> <span className="font-bold text-brand">{activeSaathi}</span></div>
      </div>
      <div className="mt-4 flex gap-2">
        <button
          type="button"
          onClick={() => onEdit(village)}
          className="flex items-center gap-1.5 rounded-lg border border-slate-200 px-2.5 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-50"
        >
          <Edit2 size={12} /> Edit
        </button>
        <button
          type="button"
          onClick={() => onToggle(village)}
          className={`flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-xs font-semibold ${
            isActive
              ? 'bg-amber-50 text-amber-700 hover:bg-amber-100'
              : 'bg-green-50 text-green-700 hover:bg-green-100'
          }`}
        >
          {isActive ? <XCircle size={12} /> : <CheckCircle size={12} />}
          {isActive ? 'Deactivate' : 'Activate'}
        </button>
        <button
          type="button"
          onClick={() => onDelete(village)}
          className="ml-auto flex items-center gap-1 rounded-lg px-2 py-1.5 text-xs font-semibold text-rose-500 hover:bg-rose-50"
        >
          <Trash2 size={12} />
        </button>
      </div>
    </div>
  )
}

function VillageFormModal({ village, onClose, onSave }) {
  const [form, setForm] = useState(village ? {
    name: village.name || '',
    gujarati: village.gujarati || '',
    lat: String(village.lat ?? ''),
    lng: String(village.lng ?? ''),
    taluka: village.taluka || 'Mahuva',
    active: village.active !== false,
  } : EMPTY_FORM)
  const [saving, setSaving] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSaving(true)
    await onSave(form, village?.id)
    setSaving(false)
    onClose()
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content max-w-md" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between border-b border-slate-100 p-5">
          <h3 className="font-bold text-slate-800">{village ? 'Edit Village' : 'Add Village'}</h3>
          <button type="button" onClick={onClose} className="rounded-lg p-1.5 hover:bg-slate-100"><X size={18} /></button>
        </div>
        <form onSubmit={handleSubmit} className="space-y-4 p-5">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="mb-1 block text-xs font-semibold text-slate-600">Name (English)</label>
              <input className="input" value={form.name} onChange={(e) => setForm((p) => ({ ...p, name: e.target.value }))} required />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-slate-600">Name (Gujarati)</label>
              <input className="input" value={form.gujarati} onChange={(e) => setForm((p) => ({ ...p, gujarati: e.target.value }))} />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-slate-600">Latitude</label>
              <input className="input" type="number" step="any" value={form.lat} onChange={(e) => setForm((p) => ({ ...p, lat: e.target.value }))} required />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-slate-600">Longitude</label>
              <input className="input" type="number" step="any" value={form.lng} onChange={(e) => setForm((p) => ({ ...p, lng: e.target.value }))} required />
            </div>
            <div>
              <label className="mb-1 block text-xs font-semibold text-slate-600">Taluka</label>
              <input className="input" value={form.taluka} onChange={(e) => setForm((p) => ({ ...p, taluka: e.target.value }))} />
            </div>
            <div className="flex flex-col justify-end">
              <label className="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" checked={form.active} onChange={(e) => setForm((p) => ({ ...p, active: e.target.checked }))} className="h-4 w-4 rounded accent-brand" />
                <span className="text-sm font-medium text-slate-700">Active village</span>
              </label>
            </div>
          </div>
          <div className="flex justify-end gap-3 pt-2">
            <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
            <button type="submit" className="btn-primary" disabled={saving}>
              {saving ? 'Saving…' : village ? 'Save Changes' : 'Add Village'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function VillageManagerPage() {
  const [villages, setVillages] = useState([])
  const [saathi, setSaathi] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [editingVillage, setEditingVillage] = useState(null)
  const [confirm, setConfirm] = useState(null)
  const { toast, showToast } = useToast()

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'villages'), (snap) =>
        setVillages(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      ),
      onSnapshot(collection(db, 'saathi'), (snap) =>
        setSaathi(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      ),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  const activeSaathiByVillage = useMemo(() =>
    saathi.reduce((acc, s) => {
      const v = String(s.village || '').trim()
      if (v && String(s.status || '').toLowerCase() === 'active') {
        acc[v] = (acc[v] || 0) + 1
      }
      return acc
    }, {}), [saathi])

  const displayVillages = villages.length > 0 ? villages : DEFAULT_VILLAGES.map((v) => ({ id: v.id, ...v }))

  const handleSave = async (form, id) => {
    const payload = {
      name: form.name.trim(),
      gujarati: form.gujarati.trim(),
      lat: Number(form.lat),
      lng: Number(form.lng),
      taluka: form.taluka.trim(),
      active: form.active,
    }
    if (id) {
      await setDoc(doc(db, 'villages', id), payload, { merge: true })
    } else {
      await addDoc(collection(db, 'villages'), payload)
    }
    showToast(id ? 'Village updated' : 'Village added')
  }

  const handleToggle = (village) => {
    const isActive = village.active !== false
    setDoc(doc(db, 'villages', village.id), { active: !isActive }, { merge: true })
    showToast(`Village ${isActive ? 'deactivated' : 'activated'}`)
  }

  const handleDelete = (village) => {
    setConfirm({ village })
  }

  const handleConfirmDelete = async () => {
    if (confirm?.village?.id) {
      await deleteDoc(doc(db, 'villages', confirm.village.id))
      showToast('Village deleted')
    }
    setConfirm(null)
  }

  return (
    <div className="space-y-5">
      <Toast show={toast.show} message={toast.message} type={toast.type} />
      <ConfirmDialog
        open={!!confirm}
        title="Delete Village"
        message={`Delete ${confirm?.village?.name}? This will remove it from the service zone and the app.`}
        confirmLabel="Delete"
        onConfirm={handleConfirmDelete}
        onCancel={() => setConfirm(null)}
      />
      {(showForm || editingVillage) && (
        <VillageFormModal
          village={editingVillage}
          onClose={() => { setShowForm(false); setEditingVillage(null) }}
          onSave={handleSave}
        />
      )}

      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-slate-500">{displayVillages.length} villages in Mahuva Taluka service zone</p>
        </div>
        <button
          type="button"
          className="btn-primary flex items-center gap-2"
          onClick={() => setShowForm(true)}
        >
          <Plus size={14} /> Add Village
        </button>
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {displayVillages.map((v) => (
          <VillageCard
            key={v.id}
            village={v}
            activeSaathi={activeSaathiByVillage[v.name] || 0}
            onEdit={(vill) => setEditingVillage(vill)}
            onToggle={handleToggle}
            onDelete={handleDelete}
          />
        ))}
      </div>

      <div className="panel-card overflow-hidden">
        <div className="section-header">
          <h3 className="font-bold text-slate-800">Service Boundary Overview</h3>
          <p className="text-sm text-slate-500 mt-0.5">Mahuva Taluka, Surat District, Gujarat</p>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-2.5 text-left font-semibold">Village</th>
                <th className="px-4 py-2.5 text-left font-semibold">Gujarati</th>
                <th className="px-4 py-2.5 text-left font-semibold">Coordinates</th>
                <th className="px-4 py-2.5 text-left font-semibold">Active Saathi</th>
                <th className="px-4 py-2.5 text-left font-semibold">Status</th>
              </tr>
            </thead>
            <tbody>
              {displayVillages.map((v) => (
                <tr key={v.id} className="border-t border-slate-100">
                  <td className="px-4 py-2.5 font-medium text-slate-800">{v.name}</td>
                  <td className="px-4 py-2.5 text-slate-600">{v.gujarati || '—'}</td>
                  <td className="px-4 py-2.5 text-slate-500 text-xs font-mono">{v.lat}, {v.lng}</td>
                  <td className="px-4 py-2.5 font-semibold text-brand">{activeSaathiByVillage[v.name] || 0}</td>
                  <td className="px-4 py-2.5">
                    <span className={`badge ${v.active !== false ? 'badge-green' : 'badge-red'}`}>
                      {v.active !== false ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

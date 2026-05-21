import { useState } from 'react'
import { doc, updateDoc, deleteDoc, setDoc, writeBatch, orderBy } from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useCollection } from '../hooks/useCollection.js'
import ConfirmModal from '../components/ConfirmModal.jsx'
import Spinner from '../components/Spinner.jsx'

const SEED_VILLAGES = {
  anaval: { name: 'Anaval', nameGu: 'આણવલ', lat: 20.8394, lng: 73.2637, isActive: true, taluka: 'Mahuva' },
  kos: { name: 'Kos', nameGu: 'કૉસ', lat: 20.8480, lng: 73.2350, isActive: true, taluka: 'Mahuva' },
  tarkani: { name: 'Tarkani', nameGu: 'તારકણી', lat: 20.8550, lng: 73.2580, isActive: true, taluka: 'Mahuva' },
  angaldhara: { name: 'Angaldhara', nameGu: 'અંગળધરા', lat: 20.8180, lng: 73.2280, isActive: true, taluka: 'Mahuva' },
  dholikuva: { name: 'Dholikuva', nameGu: 'ઢોળીકૂવા', lat: 20.8650, lng: 73.2800, isActive: true, taluka: 'Mahuva' },
  lakhavadi: { name: 'Lakhavadi', nameGu: 'લખાવડી', lat: 20.8050, lng: 73.2150, isActive: true, taluka: 'Mahuva' },
  unai: { name: 'Unai', nameGu: 'ઉનાઈ', lat: 20.8550, lng: 73.2100, isActive: true, taluka: 'Mahuva' },
  doldha: { name: 'Doldha', nameGu: 'ડોળધા', lat: 20.7950, lng: 73.2600, isActive: true, taluka: 'Mahuva' },
  kamboya: { name: 'Kamboya', nameGu: 'કાંબોયા', lat: 20.8750, lng: 73.2200, isActive: true, taluka: 'Mahuva' },
}

const EMPTY_FORM = { name: '', nameGu: '', lat: '', lng: '', taluka: 'Mahuva', isActive: true }

function validateCoords(lat, lng) {
  const la = Number(lat), lo = Number(lng)
  if (la < 20.0 || la > 22.0) return 'Latitude must be between 20.0 and 22.0'
  if (lo < 72.0 || lo > 74.5) return 'Longitude must be between 72.0 and 74.5'
  return null
}

export default function VillageManagerPage() {
  const { data: villages, loading } = useCollection('villages', orderBy('name', 'asc'))
  const [confirm, setConfirm] = useState(null)
  const [showModal, setShowModal] = useState(false)
  const [editTarget, setEditTarget] = useState(null)
  const [form, setForm] = useState(EMPTY_FORM)
  const [formError, setFormError] = useState('')
  const [saving, setSaving] = useState(false)
  const [seeding, setSeeding] = useState(false)

  const openAdd = () => { setForm(EMPTY_FORM); setFormError(''); setEditTarget(null); setShowModal(true) }
  const openEdit = (v) => {
    setForm({ name: v.name || '', nameGu: v.nameGu || '', lat: v.lat ?? '', lng: v.lng ?? '', taluka: v.taluka || 'Mahuva', isActive: v.isActive !== false })
    setFormError('')
    setEditTarget(v)
    setShowModal(true)
  }

  const handleSave = async (e) => {
    e.preventDefault()
    const err = validateCoords(form.lat, form.lng)
    if (err) { setFormError(err); return }
    setSaving(true)
    try {
      const data = { name: form.name, nameGu: form.nameGu, lat: Number(form.lat), lng: Number(form.lng), taluka: form.taluka, isActive: form.isActive }
      if (editTarget) {
        await updateDoc(doc(db, 'villages', editTarget.id), data)
        toast.success('Updated successfully')
      } else {
        const id = form.name.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '')
        await setDoc(doc(db, 'villages', id), data)
        toast.success('Village added')
      }
      setShowModal(false)
    } catch (err2) {
      toast.error('Error: ' + err2.message)
    } finally {
      setSaving(false)
    }
  }

  const handleToggleActive = async (v) => {
    try {
      await updateDoc(doc(db, 'villages', v.id), { isActive: !v.isActive })
      toast.success('Updated successfully')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
  }

  const handleDelete = async (id) => {
    try {
      await deleteDoc(doc(db, 'villages', id))
      toast.success('Deleted successfully')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
    setConfirm(null)
  }

  const handleSeed = async () => {
    setSeeding(true)
    try {
      const batch = writeBatch(db)
      const existingIds = new Set(villages.map((v) => v.id))
      let count = 0
      for (const [id, data] of Object.entries(SEED_VILLAGES)) {
        if (!existingIds.has(id)) {
          batch.set(doc(db, 'villages', id), data)
          count++
        }
      }
      if (count === 0) { toast.success('All villages already exist'); setSeeding(false); return }
      await batch.commit()
      toast.success(`Seeded ${count} villages`)
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally {
      setSeeding(false)
    }
  }

  const F = ({ label, name, type = 'text' }) => (
    <div>
      <label className="mb-1 block text-xs font-medium text-gray-600">{label}</label>
      <input type={type} value={form[name]} onChange={(e) => { setForm({ ...form, [name]: e.target.value }); setFormError('') }}
        className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300" />
    </div>
  )

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <h1 className="text-lg font-bold text-gray-800">Villages</h1>
          <span className="rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-semibold text-gray-600">{villages.length}</span>
        </div>
        <div className="flex gap-2">
          <button type="button" onClick={handleSeed} disabled={seeding}
            className="rounded-lg border border-gray-200 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60">
            {seeding ? 'Seeding…' : '🌱 Seed 9 Villages'}
          </button>
          <button type="button" onClick={openAdd}
            className="rounded-lg px-4 py-2 text-sm font-semibold text-white" style={{ backgroundColor: '#f97316' }}>
            ➕ Add Village
          </button>
        </div>
      </div>

      <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-10"><Spinner /></div>
        ) : villages.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-2 p-10 text-gray-400">
            <span className="text-3xl">📍</span>
            <p className="text-sm">No records found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  {['Doc ID','Name','Gujarati Name','Lat','Lng','Taluka','Active','Actions'].map((h) => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {villages.map((v, i) => (
                  <tr key={v.id} className={`hover:bg-gray-50 ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                    <td className="px-4 py-3 font-mono text-xs text-gray-500">{v.id}</td>
                    <td className="px-4 py-3 font-medium text-gray-800">{v.name}</td>
                    <td className="px-4 py-3 text-gray-600">{v.nameGu || '—'}</td>
                    <td className="px-4 py-3 text-xs font-mono">{v.lat}</td>
                    <td className="px-4 py-3 text-xs font-mono">{v.lng}</td>
                    <td className="px-4 py-3 text-gray-600">{v.taluka || '—'}</td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${v.isActive ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'}`}>
                        {v.isActive ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        <button type="button" title="Edit" onClick={() => openEdit(v)} className="rounded p-1 hover:bg-gray-100">✏️</button>
                        <button type="button" title="Toggle Active" onClick={() => handleToggleActive(v)} className="rounded p-1 hover:bg-gray-100">🔄</button>
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

      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setShowModal(false)}>
          <div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="mb-4 flex items-center justify-between">
              <h3 className="font-semibold text-gray-800">{editTarget ? 'Edit Village' : 'Add Village'}</h3>
              <button type="button" onClick={() => setShowModal(false)} className="text-gray-400 hover:text-gray-600">✕</button>
            </div>
            <div className="mb-4 rounded-lg bg-amber-50 px-4 py-3 text-xs text-amber-800">
              ⚠️ Enter correct GPS coordinates only. Wrong coordinates break the app.
            </div>
            {formError && (
              <div className="mb-3 rounded-lg bg-red-50 px-4 py-2 text-xs text-red-700">{formError}</div>
            )}
            <form onSubmit={handleSave} className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <F label="Name *" name="name" />
                <F label="Gujarati Name *" name="nameGu" />
                <F label="Latitude *" name="lat" type="number" />
                <F label="Longitude *" name="lng" type="number" />
                <F label="Taluka *" name="taluka" />
              </div>
              <label className="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
                <input type="checkbox" checked={form.isActive} onChange={(e) => setForm({ ...form, isActive: e.target.checked })} />
                Active
              </label>
              <div className="flex justify-end gap-3 pt-2">
                <button type="button" onClick={() => setShowModal(false)} className="rounded-lg border border-gray-200 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel</button>
                <button type="submit" disabled={saving} className="rounded-lg px-4 py-2 text-sm font-semibold text-white disabled:opacity-60" style={{ backgroundColor: '#f97316' }}>
                  {saving ? 'Saving…' : (editTarget ? 'Save Changes' : 'Add Village')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <ConfirmModal
        isOpen={!!confirm}
        title="Delete village?"
        message={`Delete village "${confirm?.name}"? This may break rides using this village.`}
        onConfirm={() => handleDelete(confirm?.id)}
        onCancel={() => setConfirm(null)}
      />
    </div>
  )
}

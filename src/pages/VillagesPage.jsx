import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  setDoc,
} from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import EmptyTableState from '../components/EmptyTableState'
import SuccessToast from '../components/SuccessToast'
import { db } from '../firebase'

const initialForm = {
  name: '',
  lat: '',
  lng: '',
  radius: '',
}

const DEFAULT_RADIUS_KM = 20

export default function VillagesPage() {
  const [villages, setVillages] = useState([])
  const [saathi, setSaathi] = useState([])
  const [form, setForm] = useState(initialForm)
  const [editingId, setEditingId] = useState(null)
  const [showSuccessToast, setShowSuccessToast] = useState(false)

  useEffect(() => {
    if (!showSuccessToast) return undefined

    const timer = setTimeout(() => {
      setShowSuccessToast(false)
    }, 3000)

    return () => clearTimeout(timer)
  }, [showSuccessToast])

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'villages'), (snapshot) => {
        setVillages(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
      onSnapshot(collection(db, 'saathi'), (snapshot) => {
        setSaathi(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
    ]

    return () => unsubs.forEach((unsub) => unsub())
  }, [])

  const activeSaathiByVillage = useMemo(() => {
    return saathi.reduce((acc, driver) => {
      const village = String(driver.village || '').trim()
      const status = String(driver.status || '').toLowerCase()
      if (!village || status !== 'active') return acc
      acc[village] = (acc[village] || 0) + 1
      return acc
    }, {})
  }, [saathi])

  const handleChange = (event) => {
    const { name, value } = event.target
    setForm((prev) => ({ ...prev, [name]: value }))
  }

  const handleEdit = (village) => {
    setEditingId(village.id)
    setForm({
      name: village.name || '',
      lat: String(village.lat ?? ''),
      lng: String(village.lng ?? ''),
      radius: String(village.radius ?? DEFAULT_RADIUS_KM),
    })
  }

  const handleCancelEdit = () => {
    setEditingId(null)
    setForm(initialForm)
  }

  const handleSubmit = async (event) => {
    event.preventDefault()

    const parsedRadius = Number(form.radius)
    const radius = Number.isFinite(parsedRadius) && parsedRadius > 0 ? parsedRadius : DEFAULT_RADIUS_KM

    const payload = {
      name: form.name.trim(),
      lat: Number(form.lat),
      lng: Number(form.lng),
      radius,
    }

    if (editingId) {
      await setDoc(doc(db, 'villages', editingId), payload, { merge: true })
    } else {
      await addDoc(collection(db, 'villages'), payload)
    }

    handleCancelEdit()
    setShowSuccessToast(true)
  }

  const handleDelete = async (id) => {
    const shouldDelete = window.confirm('Delete this village?')
    if (!shouldDelete) return
    await deleteDoc(doc(db, 'villages', id))
  }

  return (
    <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">
      <SuccessToast show={showSuccessToast} message="Saved successfully" />
      <section className="panel-card p-5 xl:col-span-1">
        <h3 className="text-lg font-bold text-slate-800">
          {editingId ? 'Edit Village' : 'Add Village'}
        </h3>
        <form className="mt-4 space-y-3" onSubmit={handleSubmit}>
          <input
            className="input"
            name="name"
            placeholder="Village name"
            value={form.name}
            onChange={handleChange}
            required
          />
          <input
            className="input"
            name="lat"
            type="number"
            step="any"
            placeholder="Latitude"
            value={form.lat}
            onChange={handleChange}
            required
          />
          <input
            className="input"
            name="lng"
            type="number"
            step="any"
            placeholder="Longitude"
            value={form.lng}
            onChange={handleChange}
            required
          />
          <input
            className="input"
            name="radius"
            type="number"
            step="0.1"
            placeholder="Radius (km)"
            value={form.radius}
            onChange={handleChange}
          />

          <div className="flex gap-2">
            <button type="submit" className="btn-primary">
              {editingId ? 'Save Changes' : 'Add Village'}
            </button>
            {editingId ? (
              <button type="button" className="btn-secondary" onClick={handleCancelEdit}>
                Cancel
              </button>
            ) : null}
          </div>
        </form>
      </section>

      <section className="panel-card overflow-hidden xl:col-span-2">
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Lat</th>
                <th className="px-4 py-3 font-semibold">Lng</th>
                <th className="px-4 py-3 font-semibold">Radius (km)</th>
                <th className="px-4 py-3 font-semibold">Active Saathi</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {villages.map((village) => (
                <tr key={village.id} className="border-t border-slate-100">
                  <td className="px-4 py-3 font-semibold text-slate-800">{village.name}</td>
                  <td className="px-4 py-3">{village.lat}</td>
                  <td className="px-4 py-3">{village.lng}</td>
                  <td className="px-4 py-3">{village.radius ?? DEFAULT_RADIUS_KM}</td>
                  <td className="px-4 py-3">{activeSaathiByVillage[village.name] || 0}</td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <button
                        type="button"
                        className="rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                        onClick={() => handleEdit(village)}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        className="rounded-md bg-rose-100 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-200"
                        onClick={() => handleDelete(village.id)}
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!villages.length ? (
                <tr>
                  <td className="px-4 py-2" colSpan={6}>
                    <EmptyTableState message="No villages found." />
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  )
}

import { useEffect, useState } from 'react'
import { doc, setDoc } from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useDoc } from '../hooks/useDoc.js'
import Spinner from '../components/Spinner.jsx'

const DEFAULT = {
  rideFareBase: '', rideFarePerKm: '', rideFareMinimum: '', rideFareMaximum: '',
  haulCommission: 75,
  serviceZoneSW: { lat: '', lng: '' }, serviceZoneNE: { lat: '', lng: '' },
  maintenanceMode: false, appVersion: '',
}

export default function AppSettingsPage() {
  const { data, loading } = useDoc('app_settings', 'config')
  const [form, setForm] = useState(DEFAULT)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!data) return
    setForm({
      rideFareBase: data.rideFareBase ?? '',
      rideFarePerKm: data.rideFarePerKm ?? '',
      rideFareMinimum: data.rideFareMinimum ?? '',
      rideFareMaximum: data.rideFareMaximum ?? '',
      haulCommission: data.haulCommission ?? 75,
      serviceZoneSW: data.serviceZoneSW || { lat: '', lng: '' },
      serviceZoneNE: data.serviceZoneNE || { lat: '', lng: '' },
      maintenanceMode: data.maintenanceMode ?? false,
      appVersion: data.appVersion ?? '',
    })
  }, [data])

  const set = (field, val) => setForm((f) => ({ ...f, [field]: val }))
  const setSW = (key, val) => setForm((f) => ({ ...f, serviceZoneSW: { ...f.serviceZoneSW, [key]: val } }))
  const setNE = (key, val) => setForm((f) => ({ ...f, serviceZoneNE: { ...f.serviceZoneNE, [key]: val } }))

  const handleSave = async (e) => {
    e.preventDefault()
    setSaving(true)
    try {
      await setDoc(doc(db, 'app_settings', 'config'), {
        rideFareBase: Number(form.rideFareBase),
        rideFarePerKm: Number(form.rideFarePerKm),
        rideFareMinimum: Number(form.rideFareMinimum),
        rideFareMaximum: Number(form.rideFareMaximum),
        haulCommission: Number(form.haulCommission),
        serviceZoneSW: { lat: Number(form.serviceZoneSW.lat), lng: Number(form.serviceZoneSW.lng) },
        serviceZoneNE: { lat: Number(form.serviceZoneNE.lat), lng: Number(form.serviceZoneNE.lng) },
        maintenanceMode: form.maintenanceMode,
        appVersion: form.appVersion,
      }, { merge: true })
      toast.success('Settings saved')
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally {
      setSaving(false)
    }
  }

  const Input = ({ label, value, onChange, type = 'number', note }) => (
    <div>
      <label className="mb-1 block text-xs font-medium text-gray-600">{label}</label>
      <input type={type} value={value} onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300" />
      {note && <p className="mt-1 text-xs text-gray-400">{note}</p>}
    </div>
  )

  const Section = ({ title, children }) => (
    <div>
      <h3 className="mb-3 text-sm font-semibold uppercase tracking-wide text-gray-500">{title}</h3>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">{children}</div>
    </div>
  )

  if (loading) return <div className="flex justify-center p-10"><Spinner /></div>

  return (
    <div className="max-w-2xl space-y-6">
      {form.maintenanceMode && (
        <div className="rounded-lg bg-red-500 px-4 py-4 text-center font-semibold text-white">
          🔴 MAINTENANCE MODE IS ON — Users cannot book rides or see the app.
        </div>
      )}

      <form onSubmit={handleSave} className="rounded-xl border border-gray-100 bg-white p-6 shadow-sm">
        <div className="space-y-6">
          <Section title="Ride Fare">
            <Input label="Base fare ₹" value={form.rideFareBase} onChange={(v) => set('rideFareBase', v)} />
            <Input label="Per km ₹" value={form.rideFarePerKm} onChange={(v) => set('rideFarePerKm', v)} />
            <Input label="Minimum fare ₹" value={form.rideFareMinimum} onChange={(v) => set('rideFareMinimum', v)} />
            <Input label="Maximum fare ₹" value={form.rideFareMaximum} onChange={(v) => set('rideFareMaximum', v)} />
          </Section>

          <hr className="border-gray-100" />

          <Section title="Haul Settings">
            <Input label="App commission ₹" value={form.haulCommission} onChange={(v) => set('haulCommission', v)} note="Fixed at ₹75 per booking" />
          </Section>

          <hr className="border-gray-100" />

          <Section title="Service Zone">
            <div>
              <p className="mb-2 text-xs font-medium text-gray-600">South-West boundary</p>
              <div className="grid grid-cols-2 gap-2">
                <Input label="Lat" value={form.serviceZoneSW.lat} onChange={(v) => setSW('lat', v)} />
                <Input label="Lng" value={form.serviceZoneSW.lng} onChange={(v) => setSW('lng', v)} />
              </div>
            </div>
            <div>
              <p className="mb-2 text-xs font-medium text-gray-600">North-East boundary</p>
              <div className="grid grid-cols-2 gap-2">
                <Input label="Lat" value={form.serviceZoneNE.lat} onChange={(v) => setNE('lat', v)} />
                <Input label="Lng" value={form.serviceZoneNE.lng} onChange={(v) => setNE('lng', v)} />
              </div>
            </div>
          </Section>

          <hr className="border-gray-100" />

          <div>
            <h3 className="mb-3 text-sm font-semibold uppercase tracking-wide text-gray-500">App Control</h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between rounded-lg border border-gray-200 px-4 py-3">
                <div>
                  <p className="text-sm font-medium text-gray-800">Maintenance Mode</p>
                  <p className={`text-xs font-semibold ${form.maintenanceMode ? 'text-red-500' : 'text-green-600'}`}>
                    {form.maintenanceMode ? 'MAINTENANCE MODE' : 'App is LIVE'}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => set('maintenanceMode', !form.maintenanceMode)}
                  className={`relative inline-flex h-7 w-12 items-center rounded-full transition-colors ${form.maintenanceMode ? 'bg-red-500' : 'bg-green-500'}`}
                >
                  <span className={`inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform ${form.maintenanceMode ? 'translate-x-6' : 'translate-x-1'}`} />
                </button>
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-gray-600">App Version</label>
                <input type="text" value={form.appVersion} onChange={(e) => set('appVersion', e.target.value)} placeholder="e.g. 1.2.3"
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300 sm:w-48" />
              </div>
            </div>
          </div>
        </div>

        <div className="mt-6 flex justify-end">
          <button type="submit" disabled={saving}
            className="rounded-lg px-6 py-2.5 text-sm font-semibold text-white disabled:opacity-60"
            style={{ backgroundColor: '#f97316' }}>
            {saving ? 'Saving…' : 'Save Settings'}
          </button>
        </div>
      </form>
    </div>
  )
}

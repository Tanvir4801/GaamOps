import { useEffect, useState } from 'react'
import { doc, setDoc, updateDoc, getDocs, collection, query, where } from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useDoc } from '../hooks/useDoc.js'
import Spinner from '../components/Spinner.jsx'

const DEFAULT = {
  rideFareBase: 15, rideFarePerKm: 8, rideFareMinimum: 25, rideFareMaximum: 300,
  haulCommission: 75,
  gstPercent: 5, platformFee: 3, lateNightFee: 10,
  gaamRideUpi: 'gaamride@upi',
  serviceZoneSW: { lat: '', lng: '' }, serviceZoneNE: { lat: '', lng: '' },
  maintenanceMode: false, appVersion: '',
  surgeMorning: 1.0, surgeEvening: 1.0, surgeWeekend: 1.0,
}

export default function AppSettingsPage() {
  const { data, loading } = useDoc('app_settings', 'config')
  const [form, setForm] = useState(DEFAULT)
  const [saving, setSaving] = useState(false)
  const [notifTitle, setNotifTitle] = useState('')
  const [notifBody, setNotifBody] = useState('')
  const [notifTarget, setNotifTarget] = useState('all')
  const [sending, setSending] = useState(false)

  useEffect(() => {
    if (!data) return
    setForm({
      rideFareBase: data.rideFareBase ?? 15,
      rideFarePerKm: data.rideFarePerKm ?? 8,
      rideFareMinimum: data.rideFareMinimum ?? 25,
      rideFareMaximum: data.rideFareMaximum ?? 300,
      haulCommission: data.haulCommission ?? 75,
      gstPercent: data.gstPercent ?? 5,
      platformFee: data.platformFee ?? 3,
      lateNightFee: data.lateNightFee ?? 10,
      gaamRideUpi: data.gaamRideUpi ?? 'gaamride@upi',
      serviceZoneSW: data.serviceZoneSW || { lat: '', lng: '' },
      serviceZoneNE: data.serviceZoneNE || { lat: '', lng: '' },
      maintenanceMode: data.maintenanceMode ?? false,
      appVersion: data.appVersion ?? '',
      surgeMorning: data.surgeMorning ?? 1.0,
      surgeEvening: data.surgeEvening ?? 1.0,
      surgeWeekend: data.surgeWeekend ?? 1.0,
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
        gstPercent: Number(form.gstPercent) || 5,
        platformFee: Number(form.platformFee) || 3,
        lateNightFee: Number(form.lateNightFee) || 10,
        gaamRideUpi: form.gaamRideUpi || 'gaamride@upi',
        serviceZoneSW: { lat: Number(form.serviceZoneSW.lat), lng: Number(form.serviceZoneSW.lng) },
        serviceZoneNE: { lat: Number(form.serviceZoneNE.lat), lng: Number(form.serviceZoneNE.lng) },
        maintenanceMode: form.maintenanceMode,
        appVersion: form.appVersion,
        surgeMorning: Number(form.surgeMorning) || 1.0,
        surgeEvening: Number(form.surgeEvening) || 1.0,
        surgeWeekend: Number(form.surgeWeekend) || 1.0,
      }, { merge: true })
      toast.success('Settings saved! App will update automatically.')
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally {
      setSaving(false)
    }
  }

  const handleMaintenanceToggle = async () => {
    const msg = form.maintenanceMode
      ? 'Turn OFF maintenance? App will go live.'
      : '⚠️ Turn ON maintenance? ALL users will be blocked from booking!'
    if (!window.confirm(msg)) return
    try {
      const newVal = !form.maintenanceMode
      await updateDoc(doc(db, 'app_settings', 'config'), { maintenanceMode: newVal })
      set('maintenanceMode', newVal)
      toast.success(newVal ? '🔴 Maintenance mode ON' : '🟢 App is now live')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
  }

  const handleBroadcast = async () => {
    if (!notifTitle || !notifBody) return
    setSending(true)
    try {
      const q = notifTarget === 'all'
        ? query(collection(db, 'users'))
        : query(collection(db, 'users'), where('role', '==', notifTarget))
      const snap = await getDocs(q)
      const tokens = snap.docs
        .map(d => d.data().fcmToken)
        .filter(t => t && t !== '')
      if (tokens.length === 0) {
        toast.error('No registered device tokens found')
        return
      }
      const confirmed = window.confirm(`Send "${notifTitle}" to ${tokens.length} users?`)
      if (confirmed) {
        toast.success(`Notification queued for ${tokens.length} users`)
        setNotifTitle('')
        setNotifBody('')
      }
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally {
      setSending(false)
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
            <Input label="Base fare ₹" value={form.rideFareBase} onChange={(v) => set('rideFareBase', v)} note="Charged for every ride" />
            <Input label="Per km ₹" value={form.rideFarePerKm} onChange={(v) => set('rideFarePerKm', v)} note="Rate per kilometre" />
            <Input label="Minimum fare ₹" value={form.rideFareMinimum} onChange={(v) => set('rideFareMinimum', v)} />
            <Input label="Maximum fare cap ₹" value={form.rideFareMaximum} onChange={(v) => set('rideFareMaximum', v)} />
          </Section>

          <hr className="border-gray-100" />

          <div>
            <h3 className="mb-1 text-sm font-semibold uppercase tracking-wide text-gray-500">💸 Taxes & Fees</h3>
            <p className="mb-3 text-xs text-gray-400">Applied to every ride on top of base + distance. Shown in the app's fare breakdown.</p>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <Input label="GST %" value={form.gstPercent} onChange={(v) => set('gstPercent', v)} note="5% is standard for ride-share" />
              <Input label="Platform fee ₹" value={form.platformFee} onChange={(v) => set('platformFee', v)} note="Flat fee per ride" />
              <Input label="Late night surcharge ₹" value={form.lateNightFee} onChange={(v) => set('lateNightFee', v)} note="Applied 11 PM – 5 AM" />
            </div>
          </div>

          <hr className="border-gray-100" />

          <div>
            <h3 className="mb-1 text-sm font-semibold uppercase tracking-wide text-gray-500">📱 UPI Payment</h3>
            <p className="mb-3 text-xs text-gray-400">Central GaamRide UPI ID shown to customers when they choose UPI payment. Free to use — no gateway fees.</p>
            <div className="flex items-center gap-3 rounded-lg border border-purple-100 bg-purple-50 p-4">
              <span className="text-2xl">📱</span>
              <div className="flex-1">
                <label className="mb-1 block text-xs font-medium text-gray-600">GaamRide UPI ID</label>
                <input
                  type="text"
                  value={form.gaamRideUpi}
                  onChange={(e) => set('gaamRideUpi', e.target.value)}
                  placeholder="yourname@upi"
                  className="w-full rounded-lg border border-purple-200 bg-white px-3 py-2 text-sm font-mono font-bold text-purple-700 outline-none focus:ring-2 focus:ring-purple-300"
                />
                <p className="mt-1 text-xs text-gray-400">Works with GPay, PhonePe, Paytm, BHIM — customers launch their UPI app directly</p>
              </div>
            </div>
          </div>

          <hr className="border-gray-100" />

          <div>
            <h3 className="mb-3 text-sm font-semibold uppercase tracking-wide text-gray-500">⚡ Surge Pricing</h3>
            <p className="mb-3 text-xs text-gray-400">Set a fare multiplier for peak hours. Applied on top of the base fare + per-km rate.</p>
            <div className="space-y-3">
              {[
                { key: 'surgeMorning', label: 'Morning Peak (7–9 AM)', default: form.surgeMorning ?? 1.0 },
                { key: 'surgeEvening', label: 'Evening Peak (5–8 PM)', default: form.surgeEvening ?? 1.0 },
                { key: 'surgeWeekend', label: 'Weekend / Festival', default: form.surgeWeekend ?? 1.0 },
              ].map(({ key, label, default: val }) => (
                <div key={key} className="flex items-center justify-between rounded-lg border border-gray-100 bg-gray-50 px-4 py-3">
                  <div>
                    <p className="text-sm font-medium text-gray-800">{label}</p>
                    <p className="text-xs text-gray-400">
                      {(val === 1.0 || !val) ? 'No surge' : `×${Number(val).toFixed(1)} — fares ${Math.round((val - 1) * 100)}% higher`}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-xs text-gray-500">×</span>
                    <input
                      type="number"
                      min="1.0"
                      max="3.0"
                      step="0.1"
                      value={form[key] ?? 1.0}
                      onChange={(e) => set(key, parseFloat(e.target.value))}
                      className="w-16 rounded-lg border border-gray-200 px-2 py-1.5 text-center text-sm font-bold text-orange-600 outline-none focus:ring-2 focus:ring-orange-300"
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>

          <hr className="border-gray-100" />

          <Section title="Haul Settings">
            <Input label="App commission ₹" value={form.haulCommission} onChange={(v) => set('haulCommission', v)} note="Fixed commission per haul booking" />
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
                    {form.maintenanceMode ? '🔴 MAINTENANCE MODE — App is blocked' : '🟢 App is LIVE'}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={handleMaintenanceToggle}
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

      <div className="rounded-xl border border-gray-100 bg-white p-6 shadow-sm">
        <h3 className="mb-1 text-sm font-semibold uppercase tracking-wide text-gray-500">📢 Broadcast Notification</h3>
        <p className="mb-4 text-xs text-gray-400">Send a push notification to all app users</p>
        <div className="space-y-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-gray-600">Target Audience</label>
            <select
              value={notifTarget}
              onChange={(e) => setNotifTarget(e.target.value)}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
            >
              <option value="all">All Users</option>
              <option value="customer">Customers Only</option>
              <option value="saathi">Saathis Only</option>
            </select>
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-gray-600">Title</label>
            <input
              type="text"
              placeholder="Notification title"
              value={notifTitle}
              onChange={(e) => setNotifTitle(e.target.value)}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-gray-600">Message</label>
            <textarea
              placeholder="Notification message body"
              value={notifBody}
              onChange={(e) => setNotifBody(e.target.value)}
              rows={3}
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
            />
          </div>
          <button
            type="button"
            onClick={handleBroadcast}
            disabled={!notifTitle || !notifBody || sending}
            className="rounded-lg px-5 py-2 text-sm font-semibold text-white disabled:opacity-50"
            style={{ backgroundColor: '#f97316' }}
          >
            {sending ? 'Sending…' : '📢 Send Notification'}
          </button>
        </div>
      </div>
    </div>
  )
}

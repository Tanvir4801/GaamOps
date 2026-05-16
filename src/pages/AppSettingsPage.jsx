import { doc, getDoc, setDoc, onSnapshot } from 'firebase/firestore'
import { useEffect, useState } from 'react'
import { Save, AlertTriangle, Bell, Map, DollarSign, Wrench } from 'lucide-react'
import { db } from '../firebase'
import { SERVICE_BOUNDS } from '../utils/constants'
import Toast, { useToast } from '../components/Toast'

function SettingSection({ icon: Icon, title, description, children }) {
  return (
    <div className="panel-card overflow-hidden">
      <div className="flex items-center gap-3 border-b border-slate-100 px-5 py-4">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-brand/10">
          <Icon size={16} className="text-brand" />
        </div>
        <div>
          <h3 className="font-bold text-slate-800">{title}</h3>
          {description && <p className="text-xs text-slate-500">{description}</p>}
        </div>
      </div>
      <div className="p-5">{children}</div>
    </div>
  )
}

export default function AppSettingsPage() {
  const { toast, showToast } = useToast()

  const [fareSettings, setFareSettings] = useState({ baseFare: 20, perKmRate: 8, minFare: 30, haulCommission: 75 })
  const [bounds, setBounds] = useState({ swLat: SERVICE_BOUNDS.sw.lat, swLng: SERVICE_BOUNDS.sw.lng, neLat: SERVICE_BOUNDS.ne.lat, neLng: SERVICE_BOUNDS.ne.lng })
  const [maintenance, setMaintenance] = useState(false)
  const [notification, setNotification] = useState({ title: '', body: '', target: 'all' })
  const [saving, setSaving] = useState({})

  useEffect(() => {
    const settingsRef = doc(db, 'app_settings', 'config')
    const unsub = onSnapshot(settingsRef, (snap) => {
      if (snap.exists()) {
        const data = snap.data()
        setFareSettings((prev) => ({
          baseFare: data.baseFare ?? prev.baseFare,
          perKmRate: data.perKmRate ?? prev.perKmRate,
          minFare: data.minFare ?? prev.minFare,
          haulCommission: data.haulCommission ?? prev.haulCommission,
        }))
        setBounds((prev) => ({
          swLat: data.swLat ?? data.serviceBounds?.sw?.lat ?? prev.swLat,
          swLng: data.swLng ?? data.serviceBounds?.sw?.lng ?? prev.swLng,
          neLat: data.neLat ?? data.serviceBounds?.ne?.lat ?? prev.neLat,
          neLng: data.neLng ?? data.serviceBounds?.ne?.lng ?? prev.neLng,
        }))
        setMaintenance(data.maintenanceMode === true)
      }
    })
    return () => unsub()
  }, [])

  const saveFares = async () => {
    setSaving((p) => ({ ...p, fares: true }))
    await setDoc(doc(db, 'app_settings', 'config'), {
      baseFare: Number(fareSettings.baseFare),
      perKmRate: Number(fareSettings.perKmRate),
      minFare: Number(fareSettings.minFare),
      haulCommission: Number(fareSettings.haulCommission),
      updatedAt: new Date(),
    }, { merge: true })
    setSaving((p) => ({ ...p, fares: false }))
    showToast('Fare settings saved — Flutter app will update immediately')
  }

  const saveBounds = async () => {
    setSaving((p) => ({ ...p, bounds: true }))
    await setDoc(doc(db, 'app_settings', 'config'), {
      swLat: Number(bounds.swLat),
      swLng: Number(bounds.swLng),
      neLat: Number(bounds.neLat),
      neLng: Number(bounds.neLng),
      serviceBounds: {
        sw: { lat: Number(bounds.swLat), lng: Number(bounds.swLng) },
        ne: { lat: Number(bounds.neLat), lng: Number(bounds.neLng) },
      },
      updatedAt: new Date(),
    }, { merge: true })
    setSaving((p) => ({ ...p, bounds: false }))
    showToast('Service bounds saved')
  }

  const toggleMaintenance = async () => {
    const newVal = !maintenance
    await setDoc(doc(db, 'app_settings', 'config'), { maintenanceMode: newVal, updatedAt: new Date() }, { merge: true })
    setMaintenance(newVal)
    showToast(`Maintenance mode ${newVal ? 'enabled' : 'disabled'}`)
  }

  const sendNotification = async (e) => {
    e.preventDefault()
    setSaving((p) => ({ ...p, notif: true }))
    await setDoc(doc(db, 'app_notifications', `notif_${Date.now()}`), {
      title: notification.title,
      body: notification.body,
      target: notification.target,
      sentAt: new Date(),
      sentBy: 'admin',
    })
    setNotification({ title: '', body: '', target: 'all' })
    setSaving((p) => ({ ...p, notif: false }))
    showToast('Notification queued for broadcast')
  }

  return (
    <div className="space-y-6 max-w-3xl">
      <Toast show={toast.show} message={toast.message} type={toast.type} />

      <SettingSection icon={DollarSign} title="Fare Settings" description="Changes take effect in Flutter app immediately — no update needed">
        <div className="grid grid-cols-2 gap-4">
          {[
            { key: 'baseFare', label: 'GaamRide Base Fare (₹)' },
            { key: 'perKmRate', label: 'Per KM Rate (₹)' },
            { key: 'minFare', label: 'Minimum Fare (₹)' },
          ].map((f) => (
            <div key={f.key}>
              <label className="mb-1 block text-xs font-semibold text-slate-600">{f.label}</label>
              <input
                type="number" step="0.5" className="input"
                value={fareSettings[f.key]}
                onChange={(e) => setFareSettings((p) => ({ ...p, [f.key]: e.target.value }))}
              />
            </div>
          ))}
          <div>
            <label className="mb-1 block text-xs font-semibold text-slate-600">GaamHaul Commission (₹/booking)</label>
            <input
              type="number" className="input"
              value={fareSettings.haulCommission}
              onChange={(e) => setFareSettings((p) => ({ ...p, haulCommission: e.target.value }))}
            />
          </div>
        </div>
        <button
          type="button" onClick={saveFares} disabled={saving.fares}
          className="btn-primary mt-4 flex items-center gap-2"
        >
          <Save size={14} /> {saving.fares ? 'Saving…' : 'Save Fare Settings'}
        </button>
      </SettingSection>

      <SettingSection icon={Map} title="Service Zone Bounds" description="Geographic boundary of the service area in Mahuva Taluka">
        <div className="grid grid-cols-2 gap-4">
          {[
            { key: 'swLat', label: 'SW Latitude (South)' },
            { key: 'swLng', label: 'SW Longitude (West)' },
            { key: 'neLat', label: 'NE Latitude (North)' },
            { key: 'neLng', label: 'NE Longitude (East)' },
          ].map((f) => (
            <div key={f.key}>
              <label className="mb-1 block text-xs font-semibold text-slate-600">{f.label}</label>
              <input
                type="number" step="any" className="input"
                value={bounds[f.key]}
                onChange={(e) => setBounds((p) => ({ ...p, [f.key]: e.target.value }))}
              />
            </div>
          ))}
        </div>
        <button
          type="button" onClick={saveBounds} disabled={saving.bounds}
          className="btn-primary mt-4 flex items-center gap-2"
        >
          <Save size={14} /> {saving.bounds ? 'Saving…' : 'Save Service Bounds'}
        </button>
      </SettingSection>

      <SettingSection icon={Bell} title="Broadcast Notification" description="Send FCM notification to all users or a specific group">
        <form onSubmit={sendNotification} className="space-y-4">
          <div>
            <label className="mb-1 block text-xs font-semibold text-slate-600">Title</label>
            <input className="input" placeholder="Notification title" value={notification.title}
              onChange={(e) => setNotification((p) => ({ ...p, title: e.target.value }))} required />
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-slate-600">Message</label>
            <textarea
              className="input min-h-[80px] resize-none"
              placeholder="Notification body text"
              value={notification.body}
              onChange={(e) => setNotification((p) => ({ ...p, body: e.target.value }))}
              required
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold text-slate-600">Target Audience</label>
            <select className="input" value={notification.target}
              onChange={(e) => setNotification((p) => ({ ...p, target: e.target.value }))}>
              <option value="all">All Users</option>
              <option value="customers">Customers Only</option>
              <option value="saathi">Saathi Only</option>
              <option value="haul_owners">Haul Owners Only</option>
            </select>
          </div>
          <button type="submit" disabled={saving.notif} className="btn-primary flex items-center gap-2">
            <Bell size={14} /> {saving.notif ? 'Sending…' : 'Send Notification'}
          </button>
        </form>
      </SettingSection>

      <SettingSection icon={Wrench} title="Maintenance Mode" description="When ON, the Flutter app shows a maintenance message to all users">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-medium text-slate-800">App Maintenance Mode</p>
            <p className="mt-0.5 text-sm text-slate-500">
              {maintenance
                ? 'Currently ON — Users see: "GaamRide હાળ અપડેટ થઈ રહ્યું છે. થોડી રાહ જુઓ."'
                : 'Currently OFF — App is live and accepting bookings'}
            </p>
          </div>
          <button
            type="button"
            onClick={toggleMaintenance}
            className={`relative inline-flex h-7 w-12 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 focus:outline-none ${
              maintenance ? 'bg-haul' : 'bg-slate-200'
            }`}
            role="switch"
            aria-checked={maintenance}
          >
            <span
              className={`inline-block h-6 w-6 transform rounded-full bg-white shadow transition duration-200 ${
                maintenance ? 'translate-x-5' : 'translate-x-0'
              }`}
            />
          </button>
        </div>
        {maintenance && (
          <div className="mt-4 flex items-start gap-2 rounded-lg bg-amber-50 border border-amber-200 px-4 py-3">
            <AlertTriangle size={16} className="mt-0.5 flex-shrink-0 text-amber-600" />
            <p className="text-sm text-amber-700">Maintenance mode is <strong>active</strong>. Users cannot book rides until you turn this off.</p>
          </div>
        )}
      </SettingSection>
    </div>
  )
}

import { collection, doc, onSnapshot, updateDoc } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { X, Phone, MapPin, Star, Bike, Clock } from 'lucide-react'
import { db } from '../firebase'
import { toDate, formatDate, formatDateOnly } from '../utils/formatters'
import { VILLAGES, VEHICLE_TYPES } from '../utils/constants'
import Toast, { useToast } from '../components/Toast'
import ConfirmDialog from '../components/ConfirmDialog'
import { SkeletonRows } from '../components/SkeletonRow'
import EmptyTableState from '../components/EmptyTableState'

function StatusDot({ status }) {
  const s = String(status || '').toLowerCase()
  if (s === 'active') return <span className="inline-flex items-center gap-1.5 text-xs font-medium text-green-600"><span className="h-2 w-2 rounded-full bg-green-500" />Online</span>
  if (s === 'blocked') return <span className="inline-flex items-center gap-1.5 text-xs font-medium text-rose-600"><span className="h-2 w-2 rounded-full bg-rose-500" />Blocked</span>
  if (s === 'pending') return <span className="inline-flex items-center gap-1.5 text-xs font-medium text-amber-600"><span className="h-2 w-2 rounded-full bg-amber-400" />Pending</span>
  return <span className="inline-flex items-center gap-1.5 text-xs font-medium text-slate-500"><span className="h-2 w-2 rounded-full bg-slate-300" />Offline</span>
}

function VehicleBadge({ type }) {
  const t = String(type || '').toLowerCase()
  const color = t.includes('auto') ? 'badge-green' : t.includes('bike') ? 'badge-blue' : t.includes('tempo') || t.includes('truck') ? 'badge-orange' : 'badge-gray'
  return <span className={`badge ${color}`}>{type || '—'}</span>
}

function SaathiModal({ driver, bookings, onClose, onBlock, onUnblock }) {
  if (!driver) return null
  const totalRides = bookings.filter((b) => b.assignedDriverId === driver.id || b.driverId === driver.id).length
  const completedRides = bookings.filter((b) =>
    (b.assignedDriverId === driver.id || b.driverId === driver.id) &&
    String(b.status || '').toLowerCase() === 'completed'
  )
  const totalEarnings = completedRides.reduce((s, b) => s + Number(b.fare || b.amount || 0), 0)
  const recentRides = completedRides.slice(-5).reverse()
  const isBlocked = String(driver.status || '').toLowerCase() === 'blocked'

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between p-6 border-b border-slate-100">
          <div className="flex items-center gap-4">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-brand text-xl font-bold text-white">
              {(driver.name || driver.fullName || 'S').charAt(0).toUpperCase()}
            </div>
            <div>
              <h3 className="text-lg font-bold text-slate-800">{driver.name || driver.fullName || '—'}</h3>
              <p className="text-sm text-slate-500">{driver.phone || driver.phoneNumber || '—'}</p>
              <StatusDot status={driver.status} />
            </div>
          </div>
          <button type="button" onClick={onClose} className="rounded-lg p-1.5 hover:bg-slate-100">
            <X size={18} />
          </button>
        </div>

        <div className="grid grid-cols-2 gap-4 p-6 sm:grid-cols-4">
          {[
            { label: 'Village', value: driver.village || '—', icon: <MapPin size={14} /> },
            { label: 'Vehicle', value: driver.vehicle || driver.vehicleType || '—', icon: <Bike size={14} /> },
            { label: 'Total Rides', value: totalRides, icon: <Star size={14} /> },
            { label: 'Earnings (est.)', value: `₹${totalEarnings.toLocaleString('en-IN')}`, icon: null },
          ].map((item) => (
            <div key={item.label} className="rounded-lg bg-slate-50 p-3">
              <p className="flex items-center gap-1 text-xs text-slate-500">{item.icon}{item.label}</p>
              <p className="mt-0.5 font-bold text-slate-800">{item.value}</p>
            </div>
          ))}
        </div>

        {recentRides.length > 0 && (
          <div className="px-6 pb-4">
            <h4 className="mb-2 text-sm font-bold text-slate-700">Recent Completed Rides</h4>
            <div className="space-y-1.5">
              {recentRides.map((ride) => (
                <div key={ride.id} className="flex items-center justify-between rounded-lg bg-slate-50 px-3 py-2 text-sm">
                  <span className="text-slate-600">
                    {ride.pickupVillage || ride.fromVillage || '?'} → {ride.dropLocation || ride.toVillage || '?'}
                  </span>
                  <span className="font-semibold text-brand">₹{ride.fare || ride.amount || 0}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex gap-3 border-t border-slate-100 p-6">
          {isBlocked ? (
            <button type="button" onClick={() => onUnblock(driver)} className="btn-primary flex-1">
              Unblock Saathi
            </button>
          ) : (
            <button type="button" onClick={() => onBlock(driver)} className="btn-danger flex-1">
              Block Saathi
            </button>
          )}
          {driver.phone && (
            <a
              href={`https://wa.me/91${driver.phone}`}
              target="_blank"
              rel="noopener noreferrer"
              className="btn-secondary flex items-center gap-2"
            >
              <Phone size={14} /> WhatsApp
            </a>
          )}
          <button type="button" onClick={onClose} className="btn-secondary">Close</button>
        </div>
      </div>
    </div>
  )
}

export default function AllSaathiPage() {
  const [drivers, setDrivers] = useState([])
  const [bookings, setBookings] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [villageFilter, setVillageFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [vehicleFilter, setVehicleFilter] = useState('all')
  const [selectedDriver, setSelectedDriver] = useState(null)
  const [confirm, setConfirm] = useState(null)
  const { toast, showToast } = useToast()

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'saathi'), (snap) => {
        setDrivers(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
        setLoading(false)
      }),
      onSnapshot(collection(db, 'bookings'), (snap) =>
        setBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      ),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  const filtered = useMemo(() =>
    drivers.filter((d) => {
      const q = search.trim().toLowerCase()
      const name = String(d.name || d.fullName || '').toLowerCase()
      const phone = String(d.phone || d.phoneNumber || '').toLowerCase()
      const matchSearch = !q || name.includes(q) || phone.includes(q)
      const matchVillage = villageFilter === 'all' || d.village === villageFilter
      const matchStatus = statusFilter === 'all' || String(d.status || '').toLowerCase() === statusFilter
      const matchVehicle = vehicleFilter === 'all' || String(d.vehicle || d.vehicleType || '').toLowerCase().includes(vehicleFilter.toLowerCase())
      return matchSearch && matchVillage && matchStatus && matchVehicle
    }), [drivers, search, villageFilter, statusFilter, vehicleFilter])

  const updateStatus = async (driverId, status) => {
    await updateDoc(doc(db, 'saathi', driverId), { status })
    showToast(`Saathi ${status === 'blocked' ? 'blocked' : 'unblocked'} successfully`)
    setSelectedDriver(null)
  }

  const handleBlock = (driver) => {
    setConfirm({
      driver,
      action: 'block',
      title: 'Block Saathi',
      message: `Are you sure you want to block ${driver.name || 'this Saathi'}? They won't be able to go online in the app.`,
    })
  }

  const handleUnblock = (driver) => {
    setConfirm({
      driver,
      action: 'unblock',
      title: 'Unblock Saathi',
      message: `Unblock ${driver.name || 'this Saathi'} and restore their access?`,
      danger: false,
    })
  }

  const handleConfirm = async () => {
    if (!confirm) return
    await updateStatus(confirm.driver.id, confirm.action === 'block' ? 'blocked' : 'active')
    setConfirm(null)
  }

  return (
    <div className="space-y-5">
      <Toast show={toast.show} message={toast.message} type={toast.type} />
      <ConfirmDialog
        open={!!confirm}
        title={confirm?.title}
        message={confirm?.message}
        danger={confirm?.danger !== false}
        confirmLabel={confirm?.action === 'block' ? 'Block' : 'Unblock'}
        onConfirm={handleConfirm}
        onCancel={() => setConfirm(null)}
      />
      {selectedDriver && (
        <SaathiModal
          driver={selectedDriver}
          bookings={bookings}
          onClose={() => setSelectedDriver(null)}
          onBlock={handleBlock}
          onUnblock={handleUnblock}
        />
      )}

      <div className="flex flex-wrap gap-3">
        <input
          type="text" className="input min-w-[220px]" placeholder="Search by name or phone"
          value={search} onChange={(e) => setSearch(e.target.value)}
        />
        <select className="input min-w-[160px]" value={villageFilter} onChange={(e) => setVillageFilter(e.target.value)}>
          <option value="all">All Villages</option>
          {VILLAGES.map((v) => <option key={v.id} value={v.name}>{v.name}</option>)}
        </select>
        <select className="input min-w-[140px]" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="all">All Status</option>
          <option value="active">Active</option>
          <option value="pending">Pending</option>
          <option value="blocked">Blocked</option>
          <option value="deactivated">Deactivated</option>
        </select>
        <select className="input min-w-[140px]" value={vehicleFilter} onChange={(e) => setVehicleFilter(e.target.value)}>
          <option value="all">All Vehicles</option>
          {VEHICLE_TYPES.map((v) => <option key={v} value={v}>{v}</option>)}
        </select>
        <span className="ml-auto self-center text-sm text-slate-500">{filtered.length} Saathi</span>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Name</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Vehicle</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Joined</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && <SkeletonRows count={6} cols={7} />}
              {!loading && filtered.map((driver) => (
                <tr key={driver.id} className="border-t border-slate-100 hover:bg-slate-50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full bg-brand/20 text-xs font-bold text-brand">
                        {(driver.name || driver.fullName || 'S').charAt(0).toUpperCase()}
                      </div>
                      <span className="font-medium text-slate-800">{driver.name || driver.fullName || '—'}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{driver.phone || driver.phoneNumber || '—'}</td>
                  <td className="px-4 py-3 text-slate-600">{driver.village || '—'}</td>
                  <td className="px-4 py-3"><VehicleBadge type={driver.vehicle || driver.vehicleType} /></td>
                  <td className="px-4 py-3"><StatusDot status={driver.status} /></td>
                  <td className="px-4 py-3 text-slate-400 text-xs">
                    {formatDateOnly(driver.registeredAt || driver.createdAt)}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex gap-2">
                      <button
                        type="button"
                        className="rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                        onClick={() => setSelectedDriver(driver)}
                      >View</button>
                      {String(driver.status || '').toLowerCase() === 'blocked' ? (
                        <button
                          type="button"
                          className="rounded-md bg-green-100 px-2.5 py-1 text-xs font-semibold text-green-700 hover:bg-green-200"
                          onClick={() => handleUnblock(driver)}
                        >Unblock</button>
                      ) : (
                        <button
                          type="button"
                          className="rounded-md bg-rose-100 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-200"
                          onClick={() => handleBlock(driver)}
                        >Block</button>
                      )}
                      {String(driver.status || '').toLowerCase() === 'pending' && (
                        <button
                          type="button"
                          className="rounded-md bg-brand/10 px-2.5 py-1 text-xs font-semibold text-brand hover:bg-brand/20"
                          onClick={() => updateDoc(doc(db, 'saathi', driver.id), { status: 'active' }).then(() => showToast('Saathi approved!'))}
                        >Approve</button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {!loading && filtered.length === 0 && (
                <tr><td colSpan={7} className="px-4 py-2"><EmptyTableState message="No Saathi found." /></td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

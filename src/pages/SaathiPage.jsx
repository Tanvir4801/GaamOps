import { collection, doc, onSnapshot, updateDoc } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import EmptyTableState from '../components/EmptyTableState'
import SuccessToast from '../components/SuccessToast'
import StatusBadge from '../components/StatusBadge'
import { db } from '../firebase'

function toDate(value) {
  if (!value) return null
  if (typeof value?.toDate === 'function') return value.toDate()
  if (typeof value === 'object' && value.seconds != null) {
    const fromSeconds = new Date(Number(value.seconds) * 1000)
    return Number.isNaN(fromSeconds.getTime()) ? null : fromSeconds
  }
  if (typeof value === 'object' && value._seconds != null) {
    const fromSeconds = new Date(Number(value._seconds) * 1000)
    return Number.isNaN(fromSeconds.getTime()) ? null : fromSeconds
  }
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

function formatRegisteredOn(driver) {
  const date = toDate(driver.registeredAt || driver.createdAt)
  if (!date) return '-'
  return date.toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
}

export default function SaathiPage() {
  const [drivers, setDrivers] = useState([])
  const [villages, setVillages] = useState([])
  const [statusFilter, setStatusFilter] = useState('all')
  const [villageFilter, setVillageFilter] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')
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
      onSnapshot(collection(db, 'saathi'), (snapshot) => {
        setDrivers(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
      onSnapshot(collection(db, 'villages'), (snapshot) => {
        setVillages(snapshot.docs.map((docRef) => ({ id: docRef.id, ...docRef.data() })))
      }),
    ]

    return () => unsubs.forEach((unsub) => unsub())
  }, [])

  const filteredDrivers = useMemo(
    () =>
      drivers.filter((driver) => {
        const query = searchQuery.trim().toLowerCase()
        const name = String(driver.name || driver.fullName || '').toLowerCase()
        const village = String(driver.village || '').toLowerCase()
        const searchMatch = !query || name.includes(query) || village.includes(query)

        const villageMatch = villageFilter === 'all' || driver.village === villageFilter
        const statusMatch =
          statusFilter === 'all' ||
          String(driver.status || '').toLowerCase() === statusFilter.toLowerCase()
        return searchMatch && villageMatch && statusMatch
      }),
    [drivers, searchQuery, statusFilter, villageFilter],
  )

  const updateStatus = async (driverId, status) => {
    await updateDoc(doc(db, 'saathi', driverId), { status })
    setShowSuccessToast(true)
  }

  return (
    <div className="space-y-5">
      <SuccessToast show={showSuccessToast} message="Saved successfully" />
      <div className="flex flex-wrap items-end gap-3">
        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Search</label>
          <input
            type="text"
            className="input min-w-[220px]"
            placeholder="Search by name or village"
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
          />
        </div>

        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Village</label>
          <select
            className="input min-w-[180px]"
            value={villageFilter}
            onChange={(event) => setVillageFilter(event.target.value)}
          >
            <option value="all">All villages</option>
            {villages.map((village) => (
              <option key={village.id} value={village.name}>
                {village.name}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="mb-1 block text-sm font-semibold text-slate-600">Status</label>
          <select
            className="input min-w-[180px]"
            value={statusFilter}
            onChange={(event) => setStatusFilter(event.target.value)}
          >
            <option value="all">All statuses</option>
            <option value="active">Active</option>
            <option value="pending">Pending</option>
            <option value="blocked">Blocked</option>
            <option value="deactivated">Deactivated</option>
          </select>
        </div>
      </div>

      <section className="panel-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Name</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Vehicle</th>
                <th className="px-4 py-3 font-semibold">Registered On</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredDrivers.map((driver) => (
                <tr key={driver.id} className="border-t border-slate-100">
                  <td className="px-4 py-3">{driver.name || driver.fullName || '-'}</td>
                  <td className="px-4 py-3">{driver.phone || driver.phoneNumber || '-'}</td>
                  <td className="px-4 py-3">{driver.village || '-'}</td>
                  <td className="px-4 py-3">{driver.vehicle || driver.vehicleType || '-'}</td>
                  <td className="px-4 py-3">{formatRegisteredOn(driver)}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={driver.status || 'pending'} />
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-2">
                      <button
                        type="button"
                        className="rounded-md bg-emerald-100 px-2.5 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-200"
                        onClick={() => updateStatus(driver.id, 'active')}
                      >
                        Approve
                      </button>
                      <button
                        type="button"
                        className="rounded-md bg-rose-100 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-200"
                        onClick={() => updateStatus(driver.id, 'blocked')}
                      >
                        Block
                      </button>
                      <button
                        type="button"
                        className="rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                        onClick={() => updateStatus(driver.id, 'deactivated')}
                      >
                        Deactivate
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {!filteredDrivers.length ? (
                <tr>
                  <td className="px-4 py-2" colSpan={7}>
                    <EmptyTableState message="No Saathi registered yet." />
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

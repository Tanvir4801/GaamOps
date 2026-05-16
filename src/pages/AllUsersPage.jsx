import { collection, doc, onSnapshot, updateDoc, deleteDoc } from 'firebase/firestore'
import { useEffect, useMemo, useState } from 'react'
import { X } from 'lucide-react'
import { db } from '../firebase'
import { toDate, formatDate, formatDateOnly } from '../utils/formatters'
import { VILLAGES } from '../utils/constants'
import Toast, { useToast } from '../components/Toast'
import ConfirmDialog from '../components/ConfirmDialog'
import { SkeletonRows } from '../components/SkeletonRow'
import EmptyTableState from '../components/EmptyTableState'

function RoleBadge({ role }) {
  const r = String(role || 'customer').toLowerCase()
  const map = {
    customer: ['badge-blue', 'Customer'],
    saathi: ['badge-green', 'Saathi'],
    haul_owner: ['badge-orange', 'Haul Owner'],
    both: ['badge-purple', 'Both'],
  }
  const [cls, label] = map[r] || ['badge-gray', role || 'Customer']
  return <span className={`badge ${cls}`}>{label}</span>
}

function StatusBadge({ blocked }) {
  return blocked
    ? <span className="badge badge-red">Blocked</span>
    : <span className="badge badge-green">Active</span>
}

function UserModal({ user, bookings, onClose, onBlock, onUnblock, onDelete }) {
  if (!user) return null
  const isBlocked = user.isBlocked === true
  const userBookings = bookings.filter((b) => b.userId === user.id || b.customerId === user.id)

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between p-5 border-b border-slate-100">
          <div className="flex items-center gap-3">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-blue-100 text-lg font-bold text-blue-600">
              {(user.displayName || user.name || user.phoneNumber || 'U').charAt(0).toUpperCase()}
            </div>
            <div>
              <h3 className="font-bold text-slate-800">{user.displayName || user.name || '—'}</h3>
              <p className="text-sm text-slate-500">{user.phoneNumber || user.phone || user.email || '—'}</p>
            </div>
          </div>
          <button type="button" onClick={onClose} className="rounded-lg p-1.5 hover:bg-slate-100"><X size={18} /></button>
        </div>
        <div className="grid grid-cols-3 gap-4 p-5">
          {[
            ['Village', user.village || '—'],
            ['Role', <RoleBadge key="r" role={user.role} />],
            ['Joined', formatDateOnly(user.createdAt)],
            ['Total Rides', userBookings.length],
            ['Status', <StatusBadge key="s" blocked={isBlocked} />],
            ['Email', user.email || '—'],
          ].map(([label, value]) => (
            <div key={label} className="rounded-lg bg-slate-50 p-3">
              <p className="text-xs text-slate-500">{label}</p>
              <p className="mt-0.5 text-sm font-semibold text-slate-800">{value}</p>
            </div>
          ))}
        </div>
        {userBookings.length > 0 && (
          <div className="px-5 pb-4">
            <h4 className="mb-2 text-sm font-bold text-slate-700">Recent Bookings</h4>
            <div className="space-y-1">
              {userBookings.slice(0, 5).map((b) => (
                <div key={b.id} className="flex items-center justify-between rounded-lg bg-slate-50 px-3 py-2 text-xs">
                  <span className="text-slate-600">{b.pickupVillage || b.fromVillage || '?'} → {b.dropLocation || b.toVillage || '?'}</span>
                  <span className="text-slate-400">{formatDate(b.timestamp || b.createdAt, { year: undefined, hour: undefined, minute: undefined })}</span>
                </div>
              ))}
            </div>
          </div>
        )}
        <div className="flex gap-3 border-t border-slate-100 p-5">
          {isBlocked
            ? <button type="button" onClick={() => onUnblock(user)} className="btn-primary flex-1">Unblock User</button>
            : <button type="button" onClick={() => onBlock(user)} className="btn-danger">Block User</button>
          }
          <button type="button" onClick={() => onDelete(user)} className="rounded-lg border border-rose-200 px-3 py-2 text-xs font-semibold text-rose-600 hover:bg-rose-50">Delete Account</button>
          <button type="button" onClick={onClose} className="btn-secondary ml-auto">Close</button>
        </div>
      </div>
    </div>
  )
}

export default function AllUsersPage() {
  const [users, setUsers] = useState([])
  const [bookings, setBookings] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('all')
  const [villageFilter, setVillageFilter] = useState('all')
  const [selectedUser, setSelectedUser] = useState(null)
  const [confirm, setConfirm] = useState(null)
  const { toast, showToast } = useToast()

  useEffect(() => {
    const unsubs = [
      onSnapshot(collection(db, 'users'), (snap) => {
        setUsers(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
        setLoading(false)
      }),
      onSnapshot(collection(db, 'bookings'), (snap) =>
        setBookings(snap.docs.map((d) => ({ id: d.id, ...d.data() })))
      ),
    ]
    return () => unsubs.forEach((u) => u())
  }, [])

  const filtered = useMemo(() =>
    users.filter((u) => {
      const q = search.trim().toLowerCase()
      const name = String(u.displayName || u.name || '').toLowerCase()
      const phone = String(u.phoneNumber || u.phone || '').toLowerCase()
      const matchSearch = !q || name.includes(q) || phone.includes(q)
      const matchRole = roleFilter === 'all' || String(u.role || 'customer').toLowerCase() === roleFilter
      const matchVillage = villageFilter === 'all' || u.village === villageFilter
      return matchSearch && matchRole && matchVillage
    }), [users, search, roleFilter, villageFilter])

  const handleBlock = (user) => setConfirm({ user, action: 'block' })
  const handleUnblock = (user) => setConfirm({ user, action: 'unblock' })
  const handleDelete = (user) => setConfirm({ user, action: 'delete' })

  const handleConfirm = async () => {
    if (!confirm) return
    const { user, action } = confirm
    if (action === 'block') {
      await updateDoc(doc(db, 'users', user.id), { isBlocked: true })
      showToast('User blocked')
    } else if (action === 'unblock') {
      await updateDoc(doc(db, 'users', user.id), { isBlocked: false })
      showToast('User unblocked')
    } else if (action === 'delete') {
      await deleteDoc(doc(db, 'users', user.id))
      showToast('User account deleted')
    }
    setConfirm(null)
    setSelectedUser(null)
  }

  const userBookingsCount = useMemo(() => {
    const map = {}
    bookings.forEach((b) => {
      const uid = b.userId || b.customerId
      if (uid) map[uid] = (map[uid] || 0) + 1
    })
    return map
  }, [bookings])

  return (
    <div className="space-y-5">
      <Toast show={toast.show} message={toast.message} type={toast.type} />
      <ConfirmDialog
        open={!!confirm}
        title={confirm?.action === 'delete' ? 'Delete Account' : confirm?.action === 'block' ? 'Block User' : 'Unblock User'}
        message={
          confirm?.action === 'delete'
            ? `Permanently delete ${confirm?.user?.displayName || 'this user'}'s account? This cannot be undone.`
            : `${confirm?.action === 'block' ? 'Block' : 'Unblock'} ${confirm?.user?.displayName || 'this user'}?`
        }
        danger={confirm?.action !== 'unblock'}
        confirmLabel={confirm?.action === 'delete' ? 'Delete' : confirm?.action === 'block' ? 'Block' : 'Unblock'}
        onConfirm={handleConfirm}
        onCancel={() => setConfirm(null)}
      />
      {selectedUser && (
        <UserModal
          user={selectedUser}
          bookings={bookings}
          onClose={() => setSelectedUser(null)}
          onBlock={(u) => { handleBlock(u); setSelectedUser(null) }}
          onUnblock={(u) => { handleUnblock(u); setSelectedUser(null) }}
          onDelete={(u) => { handleDelete(u); setSelectedUser(null) }}
        />
      )}

      <div className="flex flex-wrap gap-3">
        <input type="text" className="input min-w-[220px]" placeholder="Search by name or phone"
          value={search} onChange={(e) => setSearch(e.target.value)} />
        <select className="input min-w-[140px]" value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}>
          <option value="all">All Roles</option>
          <option value="customer">Customer</option>
          <option value="saathi">Saathi</option>
          <option value="haul_owner">Haul Owner</option>
          <option value="both">Both</option>
        </select>
        <select className="input min-w-[150px]" value={villageFilter} onChange={(e) => setVillageFilter(e.target.value)}>
          <option value="all">All Villages</option>
          {VILLAGES.map((v) => <option key={v.id} value={v.name}>{v.name}</option>)}
        </select>
        <span className="ml-auto self-center text-sm text-slate-500">{filtered.length} users</span>
      </div>

      <div className="panel-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-slate-50 text-slate-600">
              <tr>
                <th className="px-4 py-3 font-semibold">Name</th>
                <th className="px-4 py-3 font-semibold">Phone</th>
                <th className="px-4 py-3 font-semibold">Role</th>
                <th className="px-4 py-3 font-semibold">Village</th>
                <th className="px-4 py-3 font-semibold">Joined</th>
                <th className="px-4 py-3 font-semibold">Rides</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && <SkeletonRows count={7} cols={8} />}
              {!loading && filtered.map((u) => (
                <tr key={u.id} className="border-t border-slate-100 hover:bg-slate-50">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-600">
                        {(u.displayName || u.name || 'U').charAt(0).toUpperCase()}
                      </div>
                      <span className="font-medium text-slate-800">{u.displayName || u.name || '—'}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{u.phoneNumber || u.phone || '—'}</td>
                  <td className="px-4 py-3"><RoleBadge role={u.role} /></td>
                  <td className="px-4 py-3 text-slate-600">{u.village || '—'}</td>
                  <td className="px-4 py-3 text-xs text-slate-400">{formatDateOnly(u.createdAt)}</td>
                  <td className="px-4 py-3 font-semibold text-slate-700">{userBookingsCount[u.id] || 0}</td>
                  <td className="px-4 py-3"><StatusBadge blocked={u.isBlocked} /></td>
                  <td className="px-4 py-3">
                    <button
                      type="button"
                      className="rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                      onClick={() => setSelectedUser(u)}
                    >View</button>
                  </td>
                </tr>
              ))}
              {!loading && filtered.length === 0 && (
                <tr><td colSpan={8} className="px-4 py-2"><EmptyTableState message="No users found." /></td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

import { useState } from 'react'
import { doc, updateDoc, serverTimestamp, orderBy, writeBatch } from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { useCollection } from '../hooks/useCollection.js'
import StatusBadge from '../components/StatusBadge.jsx'
import ConfirmModal from '../components/ConfirmModal.jsx'
import Spinner from '../components/Spinner.jsx'

const formatDate = (ts) => {
  if (!ts) return '—'
  if (ts?.toDate) return ts.toDate().toLocaleDateString('en-IN')
  if (ts instanceof Date) return ts.toLocaleDateString('en-IN')
  return '—'
}

const ROLE_COLORS = { customer: '#3b82f6', saathi: '#8b5cf6', both: '#0d9488' }

function Avatar({ name, role }) {
  const letter = (name || '?')[0].toUpperCase()
  const bg = ROLE_COLORS[role] || '#94a3b8'
  return (
    <div
      className="flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full text-xs font-bold text-white"
      style={{ backgroundColor: bg }}
    >
      {letter}
    </div>
  )
}

export default function AllUsersPage() {
  const { data: users, loading } = useCollection('users', orderBy('createdAt', 'desc'))
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [confirm, setConfirm] = useState(null)

  const filtered = users.filter(u => {
    if (u.isDeleted) return false
    const q = search.toLowerCase()
    const matchSearch = !q ||
      (u.name || '').toLowerCase().includes(q) ||
      (u.phone || '').includes(q) ||
      (u.village || '').toLowerCase().includes(q)
    const matchRole = roleFilter === 'all' || u.role === roleFilter
    const matchStatus = statusFilter === 'all' ||
      (statusFilter === 'blocked' && u.isBlocked) ||
      (statusFilter === 'active' && !u.isBlocked)
    return matchSearch && matchRole && matchStatus
  })

  const handleToggleBlock = async (u) => {
    try {
      await updateDoc(doc(db, 'users', u.id), {
        isBlocked: !u.isBlocked,
        updatedAt: serverTimestamp(),
      })
      toast.success(u.isBlocked ? `${u.name} unblocked ✅` : `${u.name} blocked 🚫`)
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
  }

  const handleSoftDelete = async (uid) => {
    try {
      const batch = writeBatch(db)
      batch.update(doc(db, 'users', uid), {
        isDeleted: true,
        isBlocked: true,
        deletedAt: serverTimestamp(),
      })
      await batch.commit()
      toast.success('User removed from platform')
    } catch (err) {
      toast.error('Error: ' + err.message)
    }
    setConfirm(null)
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-lg font-bold text-gray-800">Users</h1>
            <span className="rounded-full bg-gray-100 px-2.5 py-0.5 text-xs font-semibold text-gray-600">
              {filtered.length}
            </span>
          </div>
          <p className="text-xs text-gray-500">
            {users.filter(u => !u.isDeleted && u.role === 'customer').length} customers ·{' '}
            {users.filter(u => !u.isDeleted && u.role === 'saathi').length} saathis
          </p>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        <input
          type="text"
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Search by name, phone, village…"
          className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300 sm:w-64"
        />
        <select
          value={roleFilter}
          onChange={e => setRoleFilter(e.target.value)}
          className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
        >
          <option value="all">All Roles</option>
          <option value="customer">👤 Customer</option>
          <option value="saathi">🛵 Saathi</option>
        </select>
        <select
          value={statusFilter}
          onChange={e => setStatusFilter(e.target.value)}
          className="rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
        >
          <option value="all">All Status</option>
          <option value="active">✅ Active</option>
          <option value="blocked">🚫 Blocked</option>
        </select>
      </div>

      <div className="rounded-xl border border-gray-100 bg-white shadow-sm">
        {loading ? (
          <div className="flex justify-center p-10"><Spinner /></div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-2 p-10 text-gray-400">
            <span className="text-3xl">👥</span>
            <p className="text-sm">No users found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50">
                <tr>
                  {['Name', 'Phone', 'Role', 'Village', 'Status', 'Created', 'Actions'].map(h => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.map((u, i) => (
                  <tr key={u.id} className={`hover:bg-gray-50 ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <Avatar name={u.name || u.displayName} role={u.role} />
                        <span className="font-medium text-gray-800">{u.name || u.displayName || '—'}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{u.phone || '—'}</td>
                    <td className="px-4 py-3">
                      <span
                        className="rounded-full px-2.5 py-0.5 text-xs font-semibold capitalize text-white"
                        style={{ backgroundColor: ROLE_COLORS[u.role] || '#94a3b8' }}
                      >
                        {u.role || '—'}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-gray-600">{u.village || '—'}</td>
                    <td className="px-4 py-3">
                      <StatusBadge status={u.isBlocked ? 'blocked' : 'active'} />
                    </td>
                    <td className="px-4 py-3 text-xs text-gray-400">{formatDate(u.createdAt)}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1">
                        <button
                          type="button"
                          title={u.isBlocked ? 'Unblock' : 'Block'}
                          onClick={() => handleToggleBlock(u)}
                          className="rounded p-1.5 text-gray-400 transition hover:bg-gray-100 hover:text-gray-600"
                        >
                          {u.isBlocked ? '✅' : '🚫'}
                        </button>
                        {u.phone && (
                          <a
                            href={`https://wa.me/${(u.phone || '').replace('+', '')}`}
                            target="_blank"
                            rel="noreferrer"
                            title="WhatsApp"
                            className="rounded p-1.5 text-green-600 transition hover:bg-green-50"
                          >
                            💬
                          </a>
                        )}
                        <button
                          type="button"
                          title="Remove"
                          onClick={() => setConfirm(u)}
                          className="rounded p-1.5 text-gray-400 transition hover:bg-red-50 hover:text-red-500"
                        >
                          🗑️
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <ConfirmModal
        isOpen={!!confirm}
        title="Remove user?"
        message={`This will block and hide "${confirm?.name || confirm?.id}" from the platform. Data is preserved.`}
        onConfirm={() => handleSoftDelete(confirm?.id)}
        onCancel={() => setConfirm(null)}
      />
    </div>
  )
}

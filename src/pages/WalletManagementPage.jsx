import { useState } from 'react'
import {
  collection, doc, getDoc, getDocs, query, where,
  setDoc, addDoc, updateDoc, serverTimestamp, orderBy, limit,
} from 'firebase/firestore'
import toast from 'react-hot-toast'
import { db } from '../firebase'
import { formatCurrency, formatDateOnly } from '../utils/formatters'

export default function WalletManagementPage() {
  const [search, setSearch] = useState('')
  const [searching, setSearching] = useState(false)
  const [user, setUser] = useState(null)
  const [walletBalance, setWalletBalance] = useState(0)
  const [transactions, setTransactions] = useState([])
  const [loadingWallet, setLoadingWallet] = useState(false)
  const [amount, setAmount] = useState('')
  const [note, setNote] = useState('')
  const [txnType, setTxnType] = useState('credit')
  const [saving, setSaving] = useState(false)

  const handleSearch = async (e) => {
    e.preventDefault()
    if (!search.trim()) return
    setSearching(true)
    setUser(null)
    setWalletBalance(0)
    setTransactions([])
    try {
      let found = null
      // Search by phone (strip +91)
      const phone = search.trim().replace(/^\+91/, '')
      const byPhone = await getDocs(
        query(collection(db, 'users'), where('phone', 'in', [phone, `+91${phone}`]))
      )
      if (!byPhone.empty) {
        found = { id: byPhone.docs[0].id, ...byPhone.docs[0].data() }
      }
      // Search by name if phone not found
      if (!found) {
        const snap = await getDocs(collection(db, 'users'))
        const match = snap.docs.find((d) =>
          (d.data().name || '').toLowerCase().includes(search.toLowerCase())
        )
        if (match) found = { id: match.id, ...match.data() }
      }
      if (!found) {
        toast.error('User not found')
        return
      }
      setUser(found)
      await loadWallet(found.id)
    } catch (err) {
      toast.error('Search error: ' + err.message)
    } finally {
      setSearching(false)
    }
  }

  const loadWallet = async (uid) => {
    setLoadingWallet(true)
    try {
      const walletRef = doc(db, 'users', uid, 'wallet', 'balance')
      const walletDoc = await getDoc(walletRef)
      const balance = walletDoc.exists() ? (walletDoc.data().balance ?? 0) : 0
      setWalletBalance(balance)

      // Load transactions
      try {
        const txSnap = await getDocs(
          query(
            collection(db, 'users', uid, 'wallet', 'balance', 'transactions'),
            orderBy('createdAt', 'desc'),
            limit(20)
          )
        )
        setTransactions(txSnap.docs.map((d) => ({ id: d.id, ...d.data() })))
      } catch (_) {
        setTransactions([])
      }
    } catch (err) {
      toast.error('Wallet load error: ' + err.message)
    } finally {
      setLoadingWallet(false)
    }
  }

  const handleAdjust = async (e) => {
    e.preventDefault()
    if (!user || !amount || Number(amount) <= 0) return
    setSaving(true)
    const uid = user.id
    const amt = Number(amount)
    const isCredit = txnType === 'credit' || txnType === 'bonus' || txnType === 'cashback'
    const newBalance = isCredit ? walletBalance + amt : Math.max(0, walletBalance - amt)

    try {
      const walletRef = doc(db, 'users', uid, 'wallet', 'balance')
      await setDoc(walletRef, { balance: newBalance, updatedAt: serverTimestamp() }, { merge: true })

      await addDoc(collection(db, 'users', uid, 'wallet', 'balance', 'transactions'), {
        type: txnType,
        amount: amt,
        note: note.trim() || (isCredit ? 'Admin credit' : 'Admin deduction'),
        balanceBefore: walletBalance,
        balanceAfter: newBalance,
        addedBy: 'admin',
        createdAt: serverTimestamp(),
      })

      setWalletBalance(newBalance)
      setAmount('')
      setNote('')
      toast.success(`${isCredit ? 'Added' : 'Deducted'} ${formatCurrency(amt)} ${isCredit ? 'to' : 'from'} ${user.name}'s wallet`)
      await loadWallet(uid)
    } catch (err) {
      toast.error('Error: ' + err.message)
    } finally {
      setSaving(false)
    }
  }

  const txnColor = (type) => {
    if (['credit', 'cashback', 'referral', 'bonus', 'rating'].includes(type)) return 'text-green-600'
    return 'text-red-500'
  }

  const txnSign = (type) => {
    if (['credit', 'cashback', 'referral', 'bonus', 'rating'].includes(type)) return '+'
    return '-'
  }

  return (
    <div className="space-y-6 max-w-3xl">
      <div>
        <h2 className="text-xl font-bold text-slate-800">GaamCash Wallet Management</h2>
        <p className="text-sm text-slate-500 mt-1">Search a user and manage their GaamCash balance</p>
      </div>

      {/* Search */}
      <form onSubmit={handleSearch} className="panel-card p-5 flex gap-3">
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by phone number or name..."
          className="flex-1 rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
        />
        <button
          type="submit"
          disabled={searching}
          className="rounded-lg px-5 py-2 text-sm font-semibold text-white disabled:opacity-50"
          style={{ backgroundColor: '#f97316' }}
        >
          {searching ? 'Searching…' : 'Search'}
        </button>
      </form>

      {user && (
        <>
          {/* User Card */}
          <div className="panel-card p-5 flex items-center gap-4">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-green-100 text-lg font-bold text-green-700">
              {(user.name || '?')[0].toUpperCase()}
            </div>
            <div className="flex-1">
              <p className="font-semibold text-slate-800">{user.name || '—'}</p>
              <p className="text-sm text-slate-500">{user.phone} · {user.village || '—'}</p>
              <span className={`text-xs font-medium ${user.role === 'saathi' ? 'text-orange-500' : 'text-green-600'}`}>
                {user.role === 'saathi' ? '🛵 Saathi' : '👤 Customer'}
              </span>
            </div>
            <div className="text-right">
              <p className="text-2xl font-bold text-green-700">
                {loadingWallet ? '…' : formatCurrency(walletBalance)}
              </p>
              <p className="text-xs text-slate-400">GaamCash Balance</p>
            </div>
          </div>

          {/* Adjust Balance */}
          <div className="panel-card p-5">
            <h3 className="font-semibold text-slate-700 mb-4">Adjust Balance</h3>
            <form onSubmit={handleAdjust} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="mb-1 block text-xs font-medium text-gray-600">Transaction Type</label>
                  <select
                    value={txnType}
                    onChange={(e) => setTxnType(e.target.value)}
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
                  >
                    <option value="credit">💚 Credit (Add money)</option>
                    <option value="debit">🔴 Debit (Deduct money)</option>
                    <option value="bonus">🎁 Bonus Reward</option>
                    <option value="cashback">💸 Cashback</option>
                    <option value="referral">👫 Referral Bonus</option>
                  </select>
                </div>
                <div>
                  <label className="mb-1 block text-xs font-medium text-gray-600">Amount (₹)</label>
                  <input
                    type="number"
                    min="1"
                    step="1"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="e.g. 50"
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
                    required
                  />
                </div>
              </div>
              <div>
                <label className="mb-1 block text-xs font-medium text-gray-600">Note (optional)</label>
                <input
                  type="text"
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder="e.g. Welcome bonus, Complaint resolution..."
                  className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-orange-300"
                />
              </div>
              {amount && Number(amount) > 0 && (
                <div className={`rounded-lg px-4 py-3 text-sm font-medium ${
                  ['credit', 'bonus', 'cashback', 'referral'].includes(txnType)
                    ? 'bg-green-50 text-green-700'
                    : 'bg-red-50 text-red-600'
                }`}>
                  New balance will be: {formatCurrency(
                    ['credit', 'bonus', 'cashback', 'referral'].includes(txnType)
                      ? walletBalance + Number(amount)
                      : Math.max(0, walletBalance - Number(amount))
                  )}
                </div>
              )}
              <button
                type="submit"
                disabled={saving || !amount}
                className="rounded-lg px-6 py-2.5 text-sm font-semibold text-white disabled:opacity-50"
                style={{ backgroundColor: '#f97316' }}
              >
                {saving ? 'Saving…' : 'Apply Adjustment'}
              </button>
            </form>
          </div>

          {/* Transaction History */}
          <div className="panel-card overflow-hidden">
            <div className="section-header">
              <h3 className="font-semibold text-slate-800">Transaction History</h3>
            </div>
            {transactions.length === 0 ? (
              <p className="px-5 py-6 text-center text-sm text-slate-400">No transactions found</p>
            ) : (
              <div className="divide-y divide-slate-100">
                {transactions.map((t) => (
                  <div key={t.id} className="flex items-center justify-between px-5 py-3">
                    <div>
                      <p className="text-sm font-medium text-slate-800 capitalize">{t.type}</p>
                      <p className="text-xs text-slate-400">{t.note || '—'} · {t.createdAt?.toDate ? formatDateOnly(t.createdAt) : '—'}</p>
                    </div>
                    <span className={`text-sm font-bold ${txnColor(t.type)}`}>
                      {txnSign(t.type)}₹{Number(t.amount || 0).toLocaleString('en-IN')}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  )
}

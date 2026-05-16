const STATUS_STYLES = {
  active: 'bg-emerald-100 text-emerald-700',
  approved: 'bg-emerald-100 text-emerald-700',
  accepted: 'bg-emerald-100 text-emerald-700',
  completed: 'bg-emerald-100 text-emerald-700',
  pending: 'bg-amber-100 text-amber-700',
  rejected: 'bg-rose-100 text-rose-700',
  blocked: 'bg-rose-100 text-rose-700',
  deactivate: 'bg-rose-100 text-rose-700',
  deactivated: 'bg-rose-100 text-rose-700',
}

export default function StatusBadge({ status }) {
  const normalized = String(status || 'unknown').toLowerCase()
  const style = STATUS_STYLES[normalized] || 'bg-slate-100 text-slate-700'

  return (
    <span className={`rounded-full px-2.5 py-1 text-xs font-semibold capitalize ${style}`}>
      {normalized}
    </span>
  )
}

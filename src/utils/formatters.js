export function formatCurrency(amount) {
  if (amount == null || amount === '') return '—'
  const num = Number(amount)
  if (Number.isNaN(num)) return '—'
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(num)
}

export function toDate(value) {
  if (!value) return null
  if (typeof value?.toDate === 'function') return value.toDate()
  if (typeof value === 'object' && value.seconds != null) {
    return new Date(Number(value.seconds) * 1000)
  }
  if (typeof value === 'object' && value._seconds != null) {
    return new Date(Number(value._seconds) * 1000)
  }
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed
}

export function formatDate(value, options = {}) {
  const date = toDate(value)
  if (!date) return '—'
  return date.toLocaleString('en-IN', {
    timeZone: 'Asia/Kolkata',
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    ...options,
  })
}

export function formatDateOnly(value) {
  return formatDate(value, { hour: undefined, minute: undefined })
}

export function formatTimeAgo(value) {
  const date = toDate(value)
  if (!date) return '—'
  const diff = Date.now() - date.getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'just now'
  if (mins < 60) return `${mins} min ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  const days = Math.floor(hrs / 24)
  return `${days}d ago`
}

export function isSameDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  )
}

export function formatPhone(phone) {
  if (!phone) return '—'
  return String(phone).replace(/(\d{5})(\d{5})/, '$1 $2')
}

export function firstNonEmpty(...values) {
  return values.find((v) => String(v ?? '').trim() !== '') ?? null
}

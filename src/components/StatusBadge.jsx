const STATUS_STYLES = {
  searching: { bg: '#fef9c3', color: '#854d0e' },
  accepted: { bg: '#dbeafe', color: '#1e40af' },
  arriving: { bg: '#e0e7ff', color: '#3730a3' },
  started: { bg: '#f3e8ff', color: '#6b21a8' },
  completed: { bg: '#dcfce7', color: '#166534' },
  cancelled: { bg: '#fee2e2', color: '#991b1b' },
  blocked: { bg: '#fee2e2', color: '#991b1b' },
  active: { bg: '#dcfce7', color: '#166534' },
  online: { bg: '#dcfce7', color: '#166534' },
  available: { bg: '#dcfce7', color: '#166534' },
  true: { bg: '#dcfce7', color: '#166534' },
  false: { bg: '#f3f4f6', color: '#374151' },
  offline: { bg: '#f3f4f6', color: '#374151' },
  inactive: { bg: '#f3f4f6', color: '#374151' },
}

export default function StatusBadge({ status }) {
  const key = String(status).toLowerCase()
  const style = STATUS_STYLES[key] || { bg: '#f3f4f6', color: '#374151' }
  return (
    <span
      className="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold capitalize"
      style={{ backgroundColor: style.bg, color: style.color }}
    >
      {String(status)}
    </span>
  )
}

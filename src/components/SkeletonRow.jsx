export function SkeletonRow({ cols = 5 }) {
  return (
    <tr className="animate-pulse border-t border-slate-100">
      {Array.from({ length: cols }).map((_, i) => (
        <td key={i} className="px-4 py-3">
          <div className="h-4 rounded bg-slate-200" style={{ width: `${60 + Math.random() * 30}%` }} />
        </td>
      ))}
    </tr>
  )
}

export function SkeletonCard() {
  return (
    <div className="panel-card animate-pulse p-5">
      <div className="mb-3 h-4 w-24 rounded bg-slate-200" />
      <div className="h-8 w-16 rounded bg-slate-200" />
    </div>
  )
}

export function SkeletonRows({ count = 5, cols = 5 }) {
  return Array.from({ length: count }).map((_, i) => <SkeletonRow key={i} cols={cols} />)
}

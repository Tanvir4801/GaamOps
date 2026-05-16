export default function StatCard({ title, value, subtitle, onClick }) {
  const isInteractive = typeof onClick === 'function'

  return (
    <article
      className={`panel-card p-5 ${
        isInteractive
          ? 'cursor-pointer transition hover:-translate-y-0.5 hover:border-brand/40 hover:shadow-md focus-within:ring-2 focus-within:ring-brand/20'
          : ''
      }`}
    >
      {isInteractive ? (
        <button
          type="button"
          onClick={onClick}
          className="w-full text-left outline-none"
          aria-label={`Open ${title}`}
        >
          <p className="text-sm text-slate-500">{title}</p>
          <p className="mt-2 text-3xl font-bold text-slate-800">{value}</p>
          {subtitle ? <p className="mt-1 text-xs text-slate-500">{subtitle}</p> : null}
        </button>
      ) : (
        <>
          <p className="text-sm text-slate-500">{title}</p>
          <p className="mt-2 text-3xl font-bold text-slate-800">{value}</p>
          {subtitle ? <p className="mt-1 text-xs text-slate-500">{subtitle}</p> : null}
        </>
      )}
    </article>
  )
}

import { CheckCircle2 } from 'lucide-react'

export default function SuccessToast({ show, message = 'Saved successfully' }) {
  if (!show) return null

  return (
    <div className="fixed right-5 top-5 z-50 animate-[fadeIn_0.2s_ease-out]">
      <div className="flex items-center gap-2 rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-semibold text-emerald-800 shadow-lg">
        <CheckCircle2 size={18} className="text-emerald-600" />
        <span>{message}</span>
      </div>
    </div>
  )
}

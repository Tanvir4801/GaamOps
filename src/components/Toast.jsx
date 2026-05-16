import { CheckCircle, XCircle, X } from 'lucide-react'
import { useEffect, useState } from 'react'

export default function Toast({ show, message, type = 'success', onClose }) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (show) {
      setVisible(true)
      const t = setTimeout(() => {
        setVisible(false)
        onClose?.()
      }, 3500)
      return () => clearTimeout(t)
    }
  }, [show, onClose])

  if (!visible) return null

  const isError = type === 'error'

  return (
    <div
      className={`fixed bottom-6 right-6 z-[9999] flex items-center gap-3 rounded-xl px-4 py-3 shadow-lg transition-all ${
        isError ? 'bg-rose-600' : 'bg-[#2E7D32]'
      } text-white`}
    >
      {isError ? <XCircle size={18} /> : <CheckCircle size={18} />}
      <span className="text-sm font-semibold">{message}</span>
      <button
        type="button"
        onClick={() => { setVisible(false); onClose?.() }}
        className="ml-1 opacity-70 hover:opacity-100"
      >
        <X size={14} />
      </button>
    </div>
  )
}

export function useToast() {
  const [toast, setToast] = useState({ show: false, message: '', type: 'success' })

  const showToast = (message, type = 'success') => {
    setToast({ show: true, message, type })
  }

  const hideToast = () => setToast((prev) => ({ ...prev, show: false }))

  return { toast, showToast, hideToast }
}

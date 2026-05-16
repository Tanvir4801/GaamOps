import { Inbox } from 'lucide-react'

export default function EmptyTableState({ message, icon: Icon = Inbox }) {
  return (
    <div className="flex min-h-[120px] flex-col items-center justify-center gap-2 py-6 text-center">
      <Icon size={20} className="text-slate-400" />
      <p className="text-sm font-medium text-slate-500">{message}</p>
    </div>
  )
}

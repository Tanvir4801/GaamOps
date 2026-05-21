import { missingFirebaseEnv } from '../firebase'

export default function FirebaseConfigNotice() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 p-5">
      <div className="w-full max-w-2xl rounded-2xl border border-amber-200 bg-amber-50 p-6 shadow-sm">
        <h1 className="text-2xl font-bold text-amber-900">Firebase configuration missing</h1>
        <p className="mt-2 text-sm text-amber-800">
          Add the required variables to your .env file and restart the dev server.
        </p>
        <div className="mt-4 rounded-lg border border-amber-300 bg-white p-4">
          <p className="text-xs font-semibold uppercase tracking-wider text-amber-700">
            Missing keys
          </p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-amber-900">
            {missingFirebaseEnv.map((key) => (
              <li key={key}>{key}</li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  )
}

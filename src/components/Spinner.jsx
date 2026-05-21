export default function Spinner({ fullPage = false }) {
  if (fullPage) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div
          className="animate-spin rounded-full border-4 border-gray-200 border-t-orange-500"
          style={{ width: 40, height: 40 }}
        />
      </div>
    )
  }
  return (
    <div
      className="inline-block animate-spin rounded-full border-4 border-gray-200 border-t-orange-500"
      style={{ width: 24, height: 24 }}
    />
  )
}

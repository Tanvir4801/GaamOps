export function calculateRideFare(distanceKm, settings = {}) {
  const baseFare = Number(settings.baseFare ?? 20)
  const perKm = Number(settings.perKmRate ?? 8)
  const minFare = Number(settings.minFare ?? 30)
  const fare = baseFare + distanceKm * perKm
  return Math.max(fare, minFare)
}

export function calculateHaulCommission(settings = {}) {
  return Number(settings.haulCommission ?? 75)
}

export function estimateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLng = ((lng2 - lng1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

export const VILLAGES = [
  { id: 'anaval', name: 'Anaval', gujarati: 'આણવલ', lat: 20.8306, lng: 73.2469 },
  { id: 'kos', name: 'Kos', gujarati: 'કોસ', lat: 20.8420, lng: 73.2380 },
  { id: 'tarkani', name: 'Tarkani', gujarati: 'તારખની', lat: 20.8550, lng: 73.2580 },
  { id: 'dholikuva', name: 'Dholikuva', gujarati: 'ઢોળીકૂવા', lat: 20.8190, lng: 73.2610 },
  { id: 'mahuva', name: 'Mahuva', gujarati: 'માહૂવા', lat: 20.8000, lng: 73.2200 },
  { id: 'budhlada', name: 'Budhlada', gujarati: 'બૂધ્લાડા', lat: 20.8650, lng: 73.2700 },
  { id: 'chanod', name: 'Chanod', gujarati: 'ચાણોદ', lat: 20.8730, lng: 73.2450 },
  { id: 'saroli', name: 'Saroli', gujarati: 'સારોલી', lat: 20.8100, lng: 73.2800 },
  { id: 'vansva', name: 'Vansva', gujarati: 'વાંસવા', lat: 20.8460, lng: 73.2150 },
]

export const ADMIN_EMAILS = [
  'admin@gaamride.com',
  'ops@gaamride.com',
  'founder@gaamride.com',
]

export const SERVICE_BOUNDS = {
  sw: { lat: 20.780, lng: 73.190 },
  ne: { lat: 20.920, lng: 73.320 },
}

export const RIDE_STATUSES = {
  searching: { label: 'Searching', color: 'blue' },
  accepted: { label: 'Accepted', color: 'yellow' },
  started: { label: 'In Progress', color: 'orange' },
  completed: { label: 'Completed', color: 'green' },
  cancelled: { label: 'Cancelled', color: 'red' },
}

export const VEHICLE_TYPES = ['Auto', 'Bike', 'Cycle', 'Mini Tempo', 'Pickup Truck', 'Tractor']

export const USER_ROLES = {
  customer: { label: 'Customer', color: 'blue' },
  saathi: { label: 'Saathi', color: 'green' },
  haul_owner: { label: 'Haul Owner', color: 'orange' },
  both: { label: 'Both', color: 'purple' },
}

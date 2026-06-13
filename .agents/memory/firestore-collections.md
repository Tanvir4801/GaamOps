---
name: Firestore collection names
description: Canonical Firestore collection names for GaamRide — several were wrong in the original codebase
---

Canonical collection names (always use these):
- `users` — customer/saathi user profiles
- `saathis` — driver profiles (NOT `saathi` — the old codebase used the singular form)
- `rides` — ride bookings (NOT `bookings` — old codebase used a shared `bookings` collection with a `type` field)
- `haul_bookings` — GaamHaul bookings (NOT filtered from `bookings`)
- `haul_vehicles` — haul vehicle owners
- `villages` — village list with lat/lng
- `app_settings/config` — single document with fare settings and maintenance mode flag

**Why:** The original code used `saathi` (singular) and a shared `bookings` collection with `type: 'ride'|'haul'` filtering. This was refactored to separate collections for correctness and Firestore query efficiency.

**How to apply:** Any new page/service must use these exact collection names. The migration service in `/mobile/lib/services/migration_service.dart` handles migrating old `saathi` → `saathis` and `bookings` → `rides`/`haul_bookings`.

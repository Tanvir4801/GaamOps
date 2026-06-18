---
name: Vahan Saathi System
description: Self-registration, pending approval flow, Firebase Storage paths, and Cloud Functions for haul_owner role
---

## Registration Wizard
`screens/auth/vahan_saathi_registration_screen.dart` — 5-step PageView:
1. Personal (name, village, profile photo)
2. Vehicle Type grid (12 types including chhota_hathi, tata_yodha, tractor, etc.)
3. Vehicle Details (number, brand, model, capacity chips)
4. Document Upload (DL front+back required, RC required, vehicle photo required; insurance+PUC optional)
5. Bank/UPI (all optional) + Review & Submit

**On submit:** parallel Firebase Storage uploads → batch write users/{uid} (role: haul_owner) + haul_vehicles/{uid} (status: pending) → navigate to VahanSaathiPendingScreen.

## Firebase Storage Paths
All docs under `vahan_saathi/{uid}/`:
- `profile.jpg`, `dl_front.jpg`, `dl_back.jpg`, `rc.jpg`, `vehicle.jpg`, `insurance.jpg`, `puc.jpg`

Storage rules in `storage.rules` — owner can write own uid path, any auth can read.

## HaulVehicleModel Fields (extended)
Added: `vehicleBrand`, `vehicleModel`, `isOnline`, `isBlocked`, `isVerified`, `rating`, `profilePhotoUrl`, `dlFrontUrl`, `dlBackUrl`, `rcUrl`, `vehiclePhotoUrl`, `insuranceUrl`, `pucUrl`, `upiId`, `bankAccount`, `ifsc`, `status`, `rejectionReason`

**Status values:** `pending` | `approved` | `active` | `rejected` | `blocked`

## OTP Screen Routing (haul_owner)
- New user → `VahanSaathiRegistrationScreen`
- Returning user → check `haul_vehicles/{uid}.status`
  - `approved` or `active` → `HaulOwnerShell`
  - anything else → `VahanSaathiPendingScreen` (live stream watches status)

## Pending Screen
`screens/haul_owner/vahan_saathi_pending_screen.dart` — streams `haul_vehicles/{uid}`. Auto-navigates to HaulOwnerShell when status flips to approved/active. Shows rejection reason when rejected.

## Cloud Functions (functions/index.js)
All triggers in Node 18. Key exports:
- `onRideCreated` — new ride → FCM to all online saathis in pickup village
- `onRideUpdated` — ride status change → FCM to customer (accepted/started/completed/cancelled)
- `onHaulBookingCreated` — new haul → FCM to available vahan saathis
- `onHaulBookingUpdated` — haul status → FCM to customer + owner
- `onVahanSaathiVerified` — haul_vehicles status change → FCM approved/rejected to owner
- `onSaathiVerified` — saathis isVerified flip → FCM to saathi

**Why:** Cloud Functions are the only reliable way to send push to offline devices; client-side FCM won't work if the recipient app is closed.

## Admin Panel — VerificationsPage Upgrades
- Document viewer modal: opens DL front/back, RC, vehicle photo in full-screen image viewer with tab strip
- Haul reject modal: proper reason modal (not window.confirm); reason stored in rejectionReason field + sent via FCM
- approveHaul now sets `isVerified: true` alongside `status: active`
- Vahan Saathi status overview grid added (Active / Pending / Rejected / Total)
- `vehicleLabel()` helper maps internal type keys to human labels

## Import Note
All files in `screens/auth/` must use `'../login_screen.dart'` not `'login_screen.dart'` for the LoginScreen import.

# GaamRide Monorepo

## Overview
GaamRide is a village-focused ride-hailing & logistics platform for the Mahuva Taluka area. This repo is a monorepo:

- **Root (`src/`)** — **GaamOps**, a React + Vite admin dashboard for managing rides, saathis (drivers), haul bookings, customers, and platform settings. Backed by Firebase (project `gaamride`).
- **`mobile/`** — the customer/Saathi/Vahan-Saathi/Haul-Owner **Flutter app** (Android/iOS). Also backed by Firebase.
- **`functions/`** — Firebase Cloud Functions (FCM push notifications on ride/booking/verification status changes).

## Running things
- `Start application` workflow runs `npm run dev` at the repo root — this serves **GaamOps** (Vite) on port 5000.
- The Flutter app (`mobile/`) is not run inside this Replit workflow — there is no Flutter/Dart SDK in this environment. It must be built/run with Flutter tooling elsewhere (Android Studio, VS Code, `flutter run`, etc.). Cannot run `flutter analyze` here.
- Cloud Functions (`functions/`) are deployed separately via `firebase deploy --only functions` — not managed by a Replit workflow.

## Payments (mobile app)
- Real payment gateway: **Razorpay** (`razorpay_flutter`), wired up in `mobile/lib/services/payment_service.dart` and `mobile/lib/screens/customer/payment_screen.dart`.
- Requires a Razorpay Key ID before online payments will work: create an account at razorpay.com, generate a Test (or Live) Key ID, and paste it into the `keyId` constant in `payment_service.dart` (the Key ID is a public identifier, safe to ship in the app — never put the Key **Secret** in client code).
- Flow: rider picks a *preferred* method at booking time (cash or UPI, via `payment_sheet.dart`) — this is just a preference, no money moves yet. `paymentStatus` always starts `pending`. Once a ride's status becomes `completed`, the customer is routed to `PaymentScreen`, which is the only place `paymentStatus` becomes `paid` — either through a real Razorpay checkout (GPay/PhonePe/Paytm/any UPI app, detected live by Razorpay) or an honest cash confirmation (no fake "processing"). Payment is mandatory at that point — the screen blocks back navigation until confirmed.
- Known limitation: payment success is currently trusted from the client-side Razorpay callback and written directly to Firestore. There's no backend order-creation or server-side signature/webhook verification yet (would need a Cloud Function using the Key Secret). Fine for now/testing; recommended before handling real money at scale.

## User preferences
(none recorded yet)

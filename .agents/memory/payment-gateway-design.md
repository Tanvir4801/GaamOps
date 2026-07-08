---
name: GaamRide payment gateway design
description: Where real money changes hands in the ride flow, and the client-trust limitation of the current Razorpay integration.
---

`paymentStatus` on a ride must only ever become `paid` in one place: `PaymentScreen`
(`mobile/lib/screens/customer/payment_screen.dart`), shown once `RideModel.status == completed`
and `paymentStatus != paid`. Booking-time method selection (`payment_sheet.dart`) only records a
*preference* — it must never write `paid` itself.

**Why:** the original implementation marked UPI as instantly "paid" at ride creation with no real
charge (fake gateway). Centralizing the write to one honest post-ride screen (real Razorpay
checkout for online methods, honour-system confirm for cash) closes that gap and makes cash/online
consistent.

**How to apply:** if adding new payment methods or entry points, route them through
`RideService.updatePayment()` and never set `paymentStatus: paid` anywhere else. Razorpay's Key ID
(not the Key Secret) is safe as a client constant — no need for secure storage. Known gap: payment
success is currently trusted from the client Razorpay callback with no server-side signature/webhook
verification (no backend order-creation exists in `functions/`) — acceptable for testing/MVP, worth
hardening with a Cloud Function before scaling real transaction volume.

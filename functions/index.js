const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ── Helper ──────────────────────────────────────────────────────────────────

async function sendFcm(token, title, body, data = {}) {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: { priority: 'high', notification: { sound: 'default' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  } catch (err) {
    // Token invalid — clean it up
    if (err.code === 'messaging/registration-token-not-registered') {
      const col = data.role === 'saathi' ? 'saathis'
        : data.role === 'haul_owner' ? 'haul_vehicles'
        : 'users';
      const docId = data.userId || data.saathiId;
      if (docId) {
        await db.collection(col).doc(docId).update({ fcmToken: '' })
          .catch(() => {});
      }
    }
    console.error('FCM error:', err.message);
  }
}

// ── RIDES ────────────────────────────────────────────────────────────────────

/**
 * When a ride is created (status: 'searching') → notify all online Saathis
 * in the same pickup village.
 */
exports.onRideCreated = functions.firestore
  .document('rides/{rideId}')
  .onCreate(async (snap, ctx) => {
    const ride = snap.data();
    if (ride.status !== 'searching') return;

    const village = ride.pickupVillage || '';
    const rideId  = ctx.params.rideId;

    // Get all online, unblocked, verified saathis in that village
    const saathisSnap = await db.collection('saathis')
      .where('isOnline', '==', true)
      .where('isBlocked', '==', false)
      .get();

    const sends = [];
    saathisSnap.forEach((doc) => {
      const s = doc.data();
      const token = s.fcmToken || '';
      if (!token) return;
      // Village filter (client side — Firestore can't do contains)
      if (s.village && village && !s.village.toLowerCase().includes(
          village.toLowerCase().substring(0, 3))) return;

      sends.push(sendFcm(
        token,
        '🚖 નવી સવારી વિનંતી!',
        `${ride.pickupVillage} → ${ride.destinationVillage} · ₹${ride.estimatedFare || ''}`,
        { type: 'new_ride', rideId, role: 'saathi', saathiId: doc.id },
      ));
    });

    await Promise.all(sends);
    console.log(`onRideCreated: notified ${sends.length} saathis for ${rideId}`);
  });

/**
 * Ride status changes → notify customer and/or saathi.
 * accepted  → customer: "Saathi on the way"
 * started   → customer: "Ride started"
 * completed → customer: "Ride completed"
 * cancelled → both parties
 */
exports.onRideUpdated = functions.firestore
  .document('rides/{rideId}')
  .onUpdate(async (change, ctx) => {
    const before = change.before.data();
    const after  = change.after.data();
    const rideId = ctx.params.rideId;

    if (before.status === after.status) return;

    const customerId = after.customerId || '';
    const saathiId   = after.saathiId || '';

    // Fetch FCM tokens in parallel
    const [custSnap, saathiSnap] = await Promise.all([
      customerId ? db.collection('users').doc(customerId).get() : Promise.resolve(null),
      saathiId   ? db.collection('saathis').doc(saathiId).get() : Promise.resolve(null),
    ]);

    const custToken   = custSnap?.data()?.fcmToken || '';
    const saathiToken = saathiSnap?.data()?.fcmToken || '';

    const sends = [];

    switch (after.status) {
      case 'accepted':
        sends.push(sendFcm(custToken,
          '✅ Saathi Accepted!',
          `${saathiSnap?.data()?.name || 'Your saathi'} is on the way.`,
          { type: 'ride_accepted', rideId, userId: customerId },
        ));
        break;

      case 'started':
        sends.push(sendFcm(custToken,
          '🚖 Ride Started!',
          `Your ride to ${after.destinationVillage} has begun.`,
          { type: 'ride_started', rideId, userId: customerId },
        ));
        break;

      case 'completed':
        sends.push(sendFcm(custToken,
          '🏁 Ride Completed!',
          `Total fare: ₹${after.finalFare || after.estimatedFare || ''}. Thank you!`,
          { type: 'ride_completed', rideId, userId: customerId },
        ));
        sends.push(sendFcm(saathiToken,
          '💰 Ride Completed!',
          `You earned ₹${after.saathiEarnings || ''}. Great job!`,
          { type: 'ride_completed', rideId, role: 'saathi', saathiId },
        ));
        break;

      case 'cancelled':
        if (after.cancelledBy === 'customer') {
          sends.push(sendFcm(saathiToken,
            '❌ Ride Cancelled',
            'Customer cancelled the ride.',
            { type: 'ride_cancelled', rideId, role: 'saathi', saathiId },
          ));
        } else {
          sends.push(sendFcm(custToken,
            '❌ Ride Cancelled',
            'Your saathi cancelled. Please try again.',
            { type: 'ride_cancelled', rideId, userId: customerId },
          ));
        }
        break;
    }

    await Promise.all(sends);
    console.log(`onRideUpdated: ${before.status} → ${after.status} for ${rideId}`);
  });

// ── HAUL BOOKINGS ─────────────────────────────────────────────────────────────

/**
 * New haul_booking created (status: 'searching') → notify matching Vahan Saathis.
 */
exports.onHaulBookingCreated = functions.firestore
  .document('haul_bookings/{bookingId}')
  .onCreate(async (snap, ctx) => {
    const booking   = snap.data();
    const bookingId = ctx.params.bookingId;
    if (booking.status !== 'searching') return;

    const vehicleType = booking.vehicleType || '';

    const vehiclesSnap = await db.collection('haul_vehicles')
      .where('isAvailable', '==', true)
      .where('isBlocked', '==', false)
      .get();

    const sends = [];
    vehiclesSnap.forEach((doc) => {
      const v = doc.data();
      const token = v.fcmToken || '';
      if (!token) return;
      if (vehicleType && v.vehicleType && v.vehicleType !== vehicleType) return;

      sends.push(sendFcm(
        token,
        '📦 નવું Haul Booking!',
        `${booking.pickupVillage || ''} → ${booking.destinationVillage || ''} · ${booking.loadDescription || ''}`,
        { type: 'new_haul', bookingId, role: 'haul_owner', ownerId: doc.id },
      ));
    });

    await Promise.all(sends);
    console.log(`onHaulBookingCreated: notified ${sends.length} vahan saathis for ${bookingId}`);
  });

/**
 * Haul booking status changes → notify customer and/or vahan saathi.
 */
exports.onHaulBookingUpdated = functions.firestore
  .document('haul_bookings/{bookingId}')
  .onUpdate(async (change, ctx) => {
    const before    = change.before.data();
    const after     = change.after.data();
    const bookingId = ctx.params.bookingId;

    if (before.status === after.status) return;

    const customerId = after.customerId || '';
    const ownerId    = after.ownerId || '';

    const [custSnap, ownerSnap] = await Promise.all([
      customerId ? db.collection('users').doc(customerId).get() : Promise.resolve(null),
      ownerId    ? db.collection('haul_vehicles').doc(ownerId).get() : Promise.resolve(null),
    ]);

    const custToken  = custSnap?.data()?.fcmToken || '';
    const ownerToken = ownerSnap?.data()?.fcmToken || '';

    const sends = [];

    switch (after.status) {
      case 'accepted':
        sends.push(sendFcm(custToken,
          '✅ Vahan Saathi Accepted!',
          `${ownerSnap?.data()?.ownerName || 'Driver'} is ready to haul.`,
          { type: 'haul_accepted', bookingId, userId: customerId },
        ));
        break;

      case 'started':
        sends.push(sendFcm(custToken,
          '🚚 Haul Started!',
          `Your freight is on the way to ${after.destinationVillage || ''}.`,
          { type: 'haul_started', bookingId, userId: customerId },
        ));
        break;

      case 'completed':
        sends.push(sendFcm(custToken,
          '🏁 Delivery Completed!',
          'Your freight has been delivered successfully!',
          { type: 'haul_completed', bookingId, userId: customerId },
        ));
        sends.push(sendFcm(ownerToken,
          '💰 Haul Completed!',
          `You earned ₹${after.ownerEarnings || ''}. Great work!`,
          { type: 'haul_completed', bookingId, role: 'haul_owner', ownerId },
        ));
        break;

      case 'cancelled':
        sends.push(sendFcm(custToken,
          '❌ Booking Cancelled',
          'Your haul booking was cancelled.',
          { type: 'haul_cancelled', bookingId, userId: customerId },
        ));
        sends.push(sendFcm(ownerToken,
          '❌ Booking Cancelled',
          'A customer cancelled the haul booking.',
          { type: 'haul_cancelled', bookingId, role: 'haul_owner', ownerId },
        ));
        break;
    }

    await Promise.all(sends);
    console.log(`onHaulBookingUpdated: ${before.status} → ${after.status} for ${bookingId}`);
  });

// ── VAHAN SAATHI VERIFICATION ────────────────────────────────────────────────

/**
 * When admin approves or rejects a Vahan Saathi → send them a push notification.
 */
exports.onVahanSaathiVerified = functions.firestore
  .document('haul_vehicles/{uid}')
  .onUpdate(async (change, ctx) => {
    const before = change.before.data();
    const after  = change.after.data();
    const uid    = ctx.params.uid;

    if (before.status === after.status) return;
    const token = after.fcmToken || '';
    if (!token) return;

    if (after.status === 'approved' || after.status === 'active') {
      await sendFcm(token,
        '🎉 Account Approved!',
        'તમારો GaamHaul account approve થઈ ગયો. બુકિંગ સ્વીકારવા online થઓ!',
        { type: 'account_approved', role: 'haul_owner', ownerId: uid },
      );
    } else if (after.status === 'rejected') {
      await sendFcm(token,
        '❌ Application Rejected',
        `Reason: ${after.rejectionReason || 'Contact support for details.'}`,
        { type: 'account_rejected', role: 'haul_owner', ownerId: uid },
      );
    }
  });

/**
 * When admin approves a Saathi (isVerified flips to true) → send push.
 */
exports.onSaathiVerified = functions.firestore
  .document('saathis/{uid}')
  .onUpdate(async (change, ctx) => {
    const before = change.before.data();
    const after  = change.after.data();
    if (before.isVerified === after.isVerified) return;

    const token = after.fcmToken || '';
    if (!token) return;

    if (after.isVerified === true) {
      await sendFcm(token,
        '✅ Saathi Account Verified!',
        'GaamRide Saathi account verify થઈ ગઈ! Online થઈ rides accept કરો.',
        { type: 'saathi_verified', saathiId: ctx.params.uid, role: 'saathi' },
      );
    }
  });

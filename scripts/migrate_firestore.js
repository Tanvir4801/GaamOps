// scripts/migrate_firestore.js
// Run ONCE: node migrate_firestore.js
// Then this file can be kept for records (serviceAccountKey.json should be gitignored)

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function runMigrations() {
  console.log('🚀 GaamRide Firestore Migration Starting...\n');

  await fixUserRoles();
  await fixRidesStatus();
  await fixHaulBookings();
  await fixSaathisPosition();
  await fixSaathisMissingFields();

  console.log('\n✅ All migrations complete!');
  process.exit(0);
}

async function fixUserRoles() {
  console.log('📝 Fixing user roles...');
  const snap = await db.collection('users').get();
  const batch = db.batch();
  let fixed = 0;

  for (const docRef of snap.docs) {
    const role = docRef.data().role;
    const updates = {};

    if (role && role.includes('|')) {
      let correctRole = 'customer';
      if (role.includes('saathi') && role.includes('customer')) correctRole = 'both';
      else if (role.includes('saathi')) correctRole = 'saathi';
      updates.role = correctRole;
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      console.log(`  Fixed user ${docRef.id}: "${role}" → "${correctRole}"`);
      fixed++;
    }

    if (docRef.data().isBlocked === undefined) updates.isBlocked = false;
    if (!docRef.data().fcmToken) updates.fcmToken = '';
    if (!docRef.data().profilePhoto) updates.profilePhoto = '';
    if (!docRef.data().displayName && docRef.data().name) {
      updates.displayName = docRef.data().name;
    }

    if (Object.keys(updates).length > 0) batch.update(docRef.ref, updates);
  }

  await batch.commit();
  console.log(`  ✅ Fixed ${fixed} user role(s)\n`);
}

async function fixRidesStatus() {
  console.log('🛵 Fixing rides...');
  const snap = await db.collection('rides').get();
  const batch = db.batch();
  let fixed = 0;

  for (const docRef of snap.docs) {
    const data = docRef.data();
    const updates = {};
    let needsFix = false;

    if (data.status && data.status.includes('|')) {
      updates.status = 'cancelled';
      needsFix = true;
      console.log(`  Fixed ride ${docRef.id}: pipe status → "cancelled"`);
    }
    if (data.completedAt === 0) { updates.completedAt = null; needsFix = true; }
    if (data.customerId === '') { updates.customerId = 'unknown'; needsFix = true; }

    if (needsFix) { batch.update(docRef.ref, updates); fixed++; }
  }

  await batch.commit();
  console.log(`  ✅ Fixed ${fixed} ride(s)\n`);
}

async function fixHaulBookings() {
  console.log('🚛 Fixing haul_bookings...');
  const snap = await db.collection('haul_bookings').get();
  let fixed = 0;

  for (const docRef of snap.docs) {
    const data = docRef.data();
    const updates = {};
    let needsFix = false;

    if (data.status && data.status.includes('|')) { updates.status = 'cancelled'; needsFix = true; }
    if (data.duration && data.duration.includes('|')) {
      updates.duration = '1h'; updates.durationHours = 1; needsFix = true;
    }
    if (data.vehicleType && data.vehicleType.includes('|')) { updates.vehicleType = 'mini_tempo'; needsFix = true; }
    if (!data.bookingId || data.bookingId === '') { updates.bookingId = docRef.id; needsFix = true; }

    if ('customerId::' in data) {
      updates['customerId'] = data['customerId::'] || '';
      needsFix = true;
      console.log(`  Found double-colon field in ${docRef.id}`);
    }

    if (needsFix) {
      await docRef.ref.set({
        ...data,
        ...updates,
        'customerId::': admin.firestore.FieldValue.delete(),
        'customerName::': admin.firestore.FieldValue.delete(),
      }, { merge: true });
      fixed++;
      console.log(`  Fixed haul_booking ${docRef.id}`);
    }
  }

  console.log(`  ✅ Fixed ${fixed} haul_booking(s)\n`);
}

async function fixSaathisPosition() {
  console.log('📍 Fixing saathi positions...');
  const snap = await db.collection('saathis').get();
  const batch = db.batch();
  let fixed = 0;

  for (const docRef of snap.docs) {
    const data = docRef.data();
    const pos = data.position;

    if (pos && pos.geopoint) {
      const lat = pos.geopoint._latitude || pos.geopoint.latitude || 0;
      const lng = pos.geopoint._longitude || pos.geopoint.longitude || 0;

      if (Math.abs(lat - 37.42) < 0.5 && Math.abs(lng - (-122.08)) < 0.5) {
        batch.update(docRef.ref, {
          position: { geohash: '', geopoint: new admin.firestore.GeoPoint(0, 0) },
          isAvailable: false,
          isOnline: false,
        });
        console.log(`  Reset SF coordinates for saathi ${docRef.id}`);
        fixed++;
      }
    }

    if (data.fcmToken === null || data.fcmToken === undefined) {
      batch.update(docRef.ref, { fcmToken: '' });
    }
  }

  await batch.commit();
  console.log(`  ✅ Fixed ${fixed} saathi position(s)\n`);
}

async function fixSaathisMissingFields() {
  console.log('🔧 Fixing saathi missing fields...');
  const snap = await db.collection('saathis').get();
  const batch = db.batch();
  let fixed = 0;

  for (const docRef of snap.docs) {
    const data = docRef.data();
    const updates = {};
    let needsFix = false;

    if (data.isBlocked === undefined) { updates.isBlocked = false; needsFix = true; }
    if (data.isVerified === undefined) { updates.isVerified = false; needsFix = true; }
    if (!data.village) { updates.village = 'Mahuva'; needsFix = true; }
    if (!data.vehicleNumber) { updates.vehicleNumber = ''; needsFix = true; }
    if (!data.vehicleType) { updates.vehicleType = 'bike'; needsFix = true; }
    if (data.rating === undefined) { updates.rating = 5.0; needsFix = true; }
    if (data.totalRides === undefined) { updates.totalRides = 0; needsFix = true; }
    // Set status field if missing
    if (!data.status) {
      updates.status = data.isVerified ? 'active' : 'pending';
      needsFix = true;
    }

    if (needsFix) {
      batch.update(docRef.ref, updates);
      fixed++;
      console.log(`  Fixed missing fields for saathi ${docRef.id}`);
    }
  }

  await batch.commit();
  console.log(`  ✅ Fixed ${fixed} saathi document(s)\n`);
}

runMigrations().catch(console.error);

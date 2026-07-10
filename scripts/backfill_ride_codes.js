/**
 * GaamRide — Backfill rideCode for existing customers
 *
 * Generates a unique permanent 4-digit ride code for every customer
 * in the `users` collection that doesn't have one yet.
 *
 * Usage:
 *   node scripts/backfill_ride_codes.js
 *
 * Requirements:
 *   - GOOGLE_APPLICATION_CREDENTIALS env var pointing to your service account JSON
 *   - OR run inside the Firebase Functions emulator / Cloud Shell with ADC
 */

const admin = require('firebase-admin')

if (!admin.apps.length) {
  admin.initializeApp()
}

const db = admin.firestore()

async function generateUniqueCode(existingCodes) {
  let code
  let attempts = 0
  do {
    code = String(1000 + Math.floor(Math.random() * 9000))
    attempts++
    if (attempts > 100) throw new Error('Could not find unique code after 100 tries')
  } while (existingCodes.has(code))
  existingCodes.add(code)
  return code
}

async function main() {
  console.log('Fetching all customer users...')

  // Load all existing ride codes so we guarantee uniqueness
  const allUsersSnap = await db.collection('users').get()
  const existingCodes = new Set(
    allUsersSnap.docs
      .map(d => d.data().rideCode)
      .filter(Boolean)
  )

  console.log(`Found ${existingCodes.size} existing ride codes.`)

  const toUpdate = allUsersSnap.docs.filter(d => {
    const data = d.data()
    return (
      (data.role === 'customer' || data.role === 'both') &&
      !data.rideCode
    )
  })

  console.log(`${toUpdate.length} customers need a ride code.`)

  if (toUpdate.length === 0) {
    console.log('All customers already have ride codes. Nothing to do.')
    return
  }

  // Firestore batch limit is 500
  const BATCH_SIZE = 400
  let processed = 0

  for (let i = 0; i < toUpdate.length; i += BATCH_SIZE) {
    const chunk = toUpdate.slice(i, i + BATCH_SIZE)
    const batch = db.batch()

    for (const docSnap of chunk) {
      const code = await generateUniqueCode(existingCodes)
      batch.update(docSnap.ref, { rideCode: code })
      processed++
      if (processed % 50 === 0) {
        console.log(`  Assigned ${processed}/${toUpdate.length}...`)
      }
    }

    await batch.commit()
    console.log(`  Batch committed (${Math.min(i + BATCH_SIZE, toUpdate.length)}/${toUpdate.length})`)
  }

  console.log(`\n✅ Done. Assigned ride codes to ${processed} customers.`)
}

main().catch(err => {
  console.error('Error:', err)
  process.exit(1)
})

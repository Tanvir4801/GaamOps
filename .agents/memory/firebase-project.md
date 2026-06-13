---
name: Firebase project config
description: GaamRide Firebase project ID and how secrets are stored
---

Project ID: `gaamride`
Auth domain: `gaamride.firebaseapp.com`
Storage bucket: `gaamride.firebasestorage.app`

All 6 `VITE_FIREBASE_*` keys are stored as **shared environment variables** (not secrets) in Replit, because they are client-side values that appear in the browser bundle anyway.

**Why:** `setEnvVars` was used instead of `requestEnvVar`/secrets because Firebase web config is intentionally public-facing.

**How to apply:** If Firebase env vars ever go missing, re-set them via `setEnvVars` with the values from the Firebase console → Project Settings → Your apps.

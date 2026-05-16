import { collection, doc, getDoc, getDocs, limit, query, setDoc } from 'firebase/firestore'
import { useEffect, useState } from 'react'
import SuccessToast from '../components/SuccessToast'
import { db } from '../firebase'

const initialPricing = {
  baseFare: '',
  perKmRate: '',
  gaamHaulRate: '',
}

export default function PricingPage() {
  const [pricing, setPricing] = useState(initialPricing)
  const [saving, setSaving] = useState(false)
  const [pricingDocId, setPricingDocId] = useState('config')
  const [showSuccessToast, setShowSuccessToast] = useState(false)

  useEffect(() => {
    if (!showSuccessToast) return undefined

    const timer = setTimeout(() => {
      setShowSuccessToast(false)
    }, 3000)

    return () => clearTimeout(timer)
  }, [showSuccessToast])

  useEffect(() => {
    let mounted = true

    const loadPricing = async () => {
      const configRef = doc(db, 'pricing', 'config')
      const configSnap = await getDoc(configRef)

      if (configSnap.exists()) {
        const data = configSnap.data()
        if (!mounted) return
        setPricing({
          baseFare: String(data.baseFare ?? ''),
          perKmRate: String(data.perKmRate ?? ''),
          gaamHaulRate: String(data.gaamHaulRate ?? ''),
        })
        setPricingDocId('config')
        return
      }

      const firstPricingSnap = await getDocs(query(collection(db, 'pricing'), limit(1)))
      if (!firstPricingSnap.empty) {
        const firstDoc = firstPricingSnap.docs[0]
        const data = firstDoc.data()
        if (!mounted) return
        setPricing({
          baseFare: String(data.baseFare ?? ''),
          perKmRate: String(data.perKmRate ?? ''),
          gaamHaulRate: String(data.gaamHaulRate ?? ''),
        })
        setPricingDocId(firstDoc.id)
      }
    }

    loadPricing()

    return () => {
      mounted = false
    }
  }, [])

  const handleChange = (event) => {
    const { name, value } = event.target
    setPricing((prev) => ({ ...prev, [name]: value }))
  }

  const handleSave = async (event) => {
    event.preventDefault()
    setSaving(true)

    const payload = {
      baseFare: Number(pricing.baseFare),
      perKmRate: Number(pricing.perKmRate),
      gaamHaulRate: Number(pricing.gaamHaulRate),
      updatedAt: new Date(),
    }

    await setDoc(doc(db, 'pricing', pricingDocId), payload, { merge: true })
    setSaving(false)
    setShowSuccessToast(true)
  }

  return (
    <>
      <SuccessToast show={showSuccessToast} message="Saved successfully" />
      <section className="panel-card max-w-xl p-6">
        <h3 className="text-xl font-bold text-slate-800">Pricing Configuration</h3>
        <p className="mt-1 text-sm text-slate-500">Set fares for GaamRide and GaamHaul services.</p>

        <form className="mt-6 space-y-4" onSubmit={handleSave}>
          <div>
            <label className="mb-1 block text-sm font-semibold text-slate-600">Base Fare (INR)</label>
            <input
              className="input"
              name="baseFare"
              type="number"
              step="0.1"
              value={pricing.baseFare}
              onChange={handleChange}
              required
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-semibold text-slate-600">Per KM Rate (INR)</label>
            <input
              className="input"
              name="perKmRate"
              type="number"
              step="0.1"
              value={pricing.perKmRate}
              onChange={handleChange}
              required
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-semibold text-slate-600">GaamHaul Rate (INR)</label>
            <input
              className="input"
              name="gaamHaulRate"
              type="number"
              step="0.1"
              value={pricing.gaamHaulRate}
              onChange={handleChange}
              required
            />
          </div>

          <button type="submit" className="btn-primary" disabled={saving}>
            {saving ? 'Saving...' : 'Save Pricing'}
          </button>
        </form>
      </section>
    </>
  )
}

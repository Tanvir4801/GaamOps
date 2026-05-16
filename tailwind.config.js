/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: '#2E7D32',
        'brand-dark': '#1B5E20',
        'brand-light': '#E8F5E9',
        haul: '#E65100',
        'haul-dark': '#BF360C',
        'haul-light': '#FBE9E7',
        sidebar: '#1A1A2E',
        'sidebar-active': '#2E7D32',
        surface: '#F5F7FA',
      },
      fontFamily: {
        sans: ['Manrope', 'system-ui', 'sans-serif'],
        heading: ['Plus Jakarta Sans', 'Manrope', 'sans-serif'],
      },
    },
  },
  plugins: [],
}

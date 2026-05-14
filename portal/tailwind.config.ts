import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
amber: {
          light: '#e8a040',
          DEFAULT: '#c07a20',
          dark: '#8B5E3C',
        },
        ui: {
          card: '#FFFFFF',
          panel: 'rgba(255,248,235,0.92)',
          muted: '#aaa',
          border: '#e0d5c0',
        },
      },
      fontFamily: {
        pixel: ['"Orbitron"', 'sans-serif'],
      },
      borderRadius: {
        card: '16px',
        btn: '14px',
        input: '12px',
      },
      boxShadow: {
        card: '0 3px 12px rgba(139,94,60,0.2)',
        btn: '0 4px 0 #8B5E3C',
      },
    },
  },
  plugins: [],
}
export default config

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
        arcade: {
          bg: '#1a0a2e',
          panel: '#2d1b4e',
          border: '#3b1f5e',
          gold: '#fbbf24',
          violet: '#7c3aed',
          pink: '#ec4899',
          purple: '#a78bfa',
          dim: '#4b2d7e',
          green: '#4ade80',
          cyan: '#06b6d4',
        },
      },
      fontFamily: {
        mono: ['Courier New', 'Courier', 'monospace'],
      },
    },
  },
  plugins: [],
}
export default config

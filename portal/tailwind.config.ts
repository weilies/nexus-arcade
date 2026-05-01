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
          bg: '#0a080e',
          panel: '#110f1a',
          border: '#2a2040',
          amber: '#ffb300',
          'amber-dim': '#7a5500',
          hot: '#ff0080',
          green: '#00ff88',
          cyan: '#00e5ff',
          dim: '#3a3050',
          scan: '#1a1520',
        },
      },
      fontFamily: {
        pixel: ['"Press Start 2P"', 'monospace'],
        mono: ['"Share Tech Mono"', 'Courier New', 'monospace'],
      },
      keyframes: {
        blink: { '0%,49%': { opacity: '1' }, '50%,100%': { opacity: '0' } },
        flicker: {
          '0%,100%': { opacity: '1' },
          '92%': { opacity: '0.97' },
          '94%': { opacity: '0.93' },
          '96%': { opacity: '0.99' },
        },
        glitch: {
          '0%,100%': { transform: 'translate(0)' },
          '20%': { transform: 'translate(-2px, 1px)' },
          '40%': { transform: 'translate(2px, -1px)' },
          '60%': { transform: 'translate(-1px, 2px)' },
        },
        marchingAnts: {
          '0%': { strokeDashoffset: '0' },
          '100%': { strokeDashoffset: '32' },
        },
      },
      animation: {
        blink: 'blink 1s step-end infinite',
        flicker: 'flicker 8s infinite',
        glitch: 'glitch 0.3s ease-in-out',
      },
      boxShadow: {
        amber: '0 0 8px #ffb300, 0 0 24px #ffb30055, inset 0 0 8px #ffb30011',
        hot: '0 0 8px #ff0080, 0 0 24px #ff008055',
        green: '0 0 8px #00ff88, 0 0 20px #00ff8855',
        cyan: '0 0 8px #00e5ff, 0 0 20px #00e5ff55',
        pixel: '4px 4px 0 #00000099',
        cabinet: 'inset 2px 2px 0 #ffb30055, inset -2px -2px 0 #7a550055, 0 0 20px #ffb30022',
      },
    },
  },
  plugins: [],
}
export default config

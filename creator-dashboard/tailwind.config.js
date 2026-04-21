/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}', './lib/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: { DEFAULT: '#7C5CFC', light: '#9B82FF', dark: '#6344E8', foreground: '#ffffff' },
        secondary: { DEFAULT: '#FF6B9D', foreground: '#ffffff' },
        accent: { DEFAULT: '#2DD4BF' },
        success: { DEFAULT: '#10B981' },
        danger: { DEFAULT: '#EF4444' },
        warning: { DEFAULT: '#FFD60A' },
        surface: { DEFAULT: '#F8F7FF', card: '#FFFFFF', border: '#EDECF8' },
        muted: { DEFAULT: '#9A96B8', foreground: '#4A4769' },
      },
      fontFamily: {
        sans: ['var(--font-nunito)', 'system-ui', 'sans-serif'],
      },
      borderRadius: { lg: '12px', xl: '16px', '2xl': '20px' },
      boxShadow: {
        card: '0 2px 16px rgba(124, 92, 252, 0.08)',
        'card-hover': '0 8px 32px rgba(124, 92, 252, 0.16)',
      },
    },
  },
  plugins: [],
};

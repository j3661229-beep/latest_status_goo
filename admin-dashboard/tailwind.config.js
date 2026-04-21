/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        // Status Go brand palette
        primary: {
          DEFAULT: '#7C5CFC',
          light: '#9B82FF',
          dark: '#6344E8',
          foreground: '#ffffff',
        },
        secondary: { DEFAULT: '#FF6B9D', foreground: '#ffffff' },
        accent: { DEFAULT: '#2DD4BF', foreground: '#ffffff' },
        amber: { DEFAULT: '#FFB347' },
        success: { DEFAULT: '#10B981' },
        danger: { DEFAULT: '#EF4444' },
        warning: { DEFAULT: '#FFD60A' },
        // Sidebar
        sidebar: {
          DEFAULT: '#0F0B1E',
          border: '#1E1837',
          muted: '#2A2347',
          active: '#7C5CFC',
        },
        // Content area
        surface: { DEFAULT: '#F8F7FF', card: '#FFFFFF', border: '#EDECF8' },
        muted: { DEFAULT: '#9A96B8', foreground: '#4A4769' },
      },
      fontFamily: {
        sans: ['var(--font-nunito)', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        lg: '12px',
        xl: '16px',
        '2xl': '20px',
      },
      boxShadow: {
        card: '0 2px 16px rgba(124, 92, 252, 0.08)',
        'card-hover': '0 8px 32px rgba(124, 92, 252, 0.16)',
      },
      backgroundImage: {
        'gradient-brand': 'linear-gradient(135deg, #7C5CFC 0%, #FF6B9D 100%)',
        'gradient-devotional': 'linear-gradient(135deg, #F7971E 0%, #FFD200 100%)',
        'gradient-morning': 'linear-gradient(135deg, #2DD4BF 0%, #7C5CFC 100%)',
      },
    },
  },
  plugins: [],
};

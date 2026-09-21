/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}', './lib/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: { 
          DEFAULT: '#2563EB', // Royal Blue 600
          light: '#3B82F6',   // Blue 500
          dark: '#1D4ED8',    // Blue 700
          subtle: '#EFF6FF',  // Blue 50
          border: '#BFDBFE',  // Blue 200
          foreground: '#ffffff' 
        },
        secondary: { 
          DEFAULT: '#0EA5E9', // Sky Blue 500
          light: '#38BDF8',
          dark: '#0284C7',
          foreground: '#ffffff' 
        },
        accent: { DEFAULT: '#0284C7' },
        success: { DEFAULT: '#10B981' },
        danger: { DEFAULT: '#EF4444' },
        warning: { DEFAULT: '#F59E0B' },
        surface: { 
          DEFAULT: '#F8FAFC', 
          card: '#FFFFFF', 
          border: '#E2E8F0',
          muted: '#F1F5F9',
        },
        muted: { DEFAULT: '#64748B', foreground: '#334155' },
      },
      fontFamily: {
        sans: ['var(--font-nunito)', 'system-ui', 'sans-serif'],
      },
      borderRadius: { lg: '12px', xl: '16px', '2xl': '20px' },
      boxShadow: {
        card: '0 1px 3px 0 rgba(15, 23, 42, 0.05), 0 1px 2px -1px rgba(15, 23, 42, 0.05)',
        'card-hover': '0 10px 25px -5px rgba(37, 99, 235, 0.08), 0 8px 10px -6px rgba(15, 23, 42, 0.03)',
        'primary-glow': '0 4px 14px 0 rgba(37, 99, 235, 0.25)',
      },
      backgroundImage: {
        'gradient-brand': 'linear-gradient(135deg, #2563EB 0%, #0EA5E9 100%)',
        'gradient-subtle': 'linear-gradient(135deg, #EFF6FF 0%, #DBEAFE 100%)',
      },
    },
  },
  plugins: [],
};

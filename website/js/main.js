// main.js — Status Go (statusgo.in)

// ── Mobile Navigation Toggle ──────────────────────────────────
const navToggle = document.getElementById('nav-toggle');
const navMenu = document.getElementById('nav-menu') || document.getElementById('nav-links');

if (navToggle && navMenu) {
  navToggle.addEventListener('click', (e) => {
    e.stopPropagation();
    const isOpen = navMenu.classList.toggle('open');
    navToggle.classList.toggle('open', isOpen);
    navToggle.setAttribute('aria-expanded', isOpen);
  });

  // Close when clicking any nav link
  navMenu.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      navMenu.classList.remove('open');
      navToggle.classList.remove('open');
      navToggle.setAttribute('aria-expanded', 'false');
    });
  });

  // Close when clicking outside
  document.addEventListener('click', (e) => {
    if (!navMenu.contains(e.target) && !navToggle.contains(e.target) && navMenu.classList.contains('open')) {
      navMenu.classList.remove('open');
      navToggle.classList.remove('open');
      navToggle.setAttribute('aria-expanded', 'false');
    }
  });
}

// ── Toast Notification Helper ─────────────────────────────────
function showToast(message, isSuccess = true) {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    container.className = 'toast-container';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.innerHTML = `
    <span style="font-size: 1.1rem;">${isSuccess ? '✅' : 'ℹ️'}</span>
    <span>${message}</span>
  `;

  container.appendChild(toast);
  requestAnimationFrame(() => toast.classList.add('show'));

  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 350);
  }, 4000);
}

// ── Early Access / Pre-Register Form ──────────────────────────
const earlyForm = document.getElementById('early-access-form');
if (earlyForm) {
  earlyForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const input = document.getElementById('early-access-contact');
    const val = input ? input.value.trim() : '';

    if (!val) return;

    try {
      const existing = JSON.parse(localStorage.getItem('statusgo_waitlist') || '[]');
      existing.push({ contact: val, date: new Date().toISOString() });
      localStorage.setItem('statusgo_waitlist', JSON.stringify(existing));
    } catch (_) {}

    showToast("🎉 Thank you! You will be notified the moment we launch on Google Play.");
    earlyForm.reset();
  });
}

// ── Contact Form Handler ──────────────────────────────────────
const contactForm = document.getElementById('contact-form');
if (contactForm) {
  contactForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const btn = contactForm.querySelector('button[type="submit"]');
    const origText = btn ? btn.textContent : 'Send';

    if (btn) {
      btn.textContent = 'Sending...';
      btn.disabled = true;
    }

    setTimeout(() => {
      showToast("Message sent! Our support team will get back to you within 24 hours.");
      contactForm.reset();
      if (btn) {
        btn.textContent = origText;
        btn.disabled = false;
      }
    }, 800);
  });
}

// ── Smooth Scroll for Anchor Links ────────────────────────────
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function(e) {
    const targetId = this.getAttribute('href');
    if (targetId && targetId !== '#') {
      const targetEl = document.querySelector(targetId);
      if (targetEl) {
        e.preventDefault();
        targetEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }
  });
});

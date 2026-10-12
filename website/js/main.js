// main.js — Status Go website

// ── Nav scroll state ──────────────────────────────────────────
const nav = document.getElementById('main-nav');
if (nav) {
  const onScroll = () => {
    nav.classList.toggle('scrolled', window.scrollY > 40);
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

// ── Mobile nav toggle ─────────────────────────────────────────
const toggle = document.getElementById('nav-toggle');
const links  = document.getElementById('nav-links');
if (toggle && links) {
  toggle.addEventListener('click', () => {
    const open = links.classList.toggle('open');
    toggle.setAttribute('aria-expanded', open);
    document.body.style.overflow = open ? 'hidden' : '';
  });
  // Close on link click
  links.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', () => {
      links.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
      document.body.style.overflow = '';
    });
  });
}

// ── Smooth anchor scroll ──────────────────────────────────────
document.querySelectorAll('a[href^="#"]').forEach(a => {
  a.addEventListener('click', e => {
    const target = document.querySelector(a.getAttribute('href'));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});

// ── Intersection observer: fade-in on scroll ──────────────────
const fadeEls = document.querySelectorAll(
  '.feature-card, .step, .pricing-card, .cat-card, .contact-channel, .value-card, .legal-section, .about-card'
);
if ('IntersectionObserver' in window && fadeEls.length) {
  fadeEls.forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(24px)';
    el.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
  });
  const obs = new IntersectionObserver((entries) => {
    entries.forEach((entry, i) => {
      if (entry.isIntersecting) {
        setTimeout(() => {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'none';
        }, 60);
        obs.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -30px 0px' });
  fadeEls.forEach(el => obs.observe(el));
}

// ── Contact form (demo handler) ───────────────────────────────
const form = document.getElementById('contact-form');
if (form) {
  form.addEventListener('submit', e => {
    e.preventDefault();
    const btn = form.querySelector('button[type="submit"]');
    const original = btn.textContent;
    btn.textContent = '✓ Message sent!';
    btn.style.background = 'linear-gradient(135deg,#15803D,#16a34a)';
    btn.disabled = true;
    setTimeout(() => {
      btn.textContent = original;
      btn.style.background = '';
      btn.disabled = false;
      form.reset();
    }, 3500);
  });
}

// ── TOC active link ───────────────────────────────────────────
const tocLinks = document.querySelectorAll('.toc-link');
if (tocLinks.length) {
  const headings = Array.from(document.querySelectorAll('.legal-section'));
  const io = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const id = entry.target.id;
        tocLinks.forEach(l => l.classList.remove('active'));
        const active = document.querySelector(`.toc-link[href="#${id}"]`);
        if (active) active.classList.add('active');
      }
    });
  }, { rootMargin: '-30% 0px -60% 0px' });
  headings.forEach(h => io.observe(h));
}

// ── Active toc link styling ───────────────────────────────────
const style = document.createElement('style');
style.textContent = `.toc-link.active { color: var(--primary) !important; background: rgba(91,61,245,.08) !important; font-weight: 700; }`;
document.head.appendChild(style);

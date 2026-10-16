import { contentConfig } from '../src/lib/content/config';
import { safeFetchText } from '../src/lib/content/safe-fetch';
const cfg = contentConfig();
(async () => {
  for (const u of process.argv.slice(2)) {
    try {
      const r = await safeFetchText(u, cfg);
      const links = [...new Set([...r.text.matchAll(/href="([^"#]+)"/g)].map((m) => m[1]))].filter((h) => /news|scheme|yojana|article|20\d\d|story/i.test(h));
      console.log('===', u, r.finalUrl, r.text.length, '\n' + links.slice(0, 40).join('\n'));
    } catch (e) { console.log('FAIL', u, (e as Error).message); }
  }
})();

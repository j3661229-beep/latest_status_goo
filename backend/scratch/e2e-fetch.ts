import { contentConfig } from '../src/lib/content/config';
import { safeFetchText, htmlToText } from '../src/lib/content/safe-fetch';
const cfg = contentConfig();
console.log('hosts allowed:', cfg.sourceHosts.join(','));
(async () => { for (const u of process.argv.slice(2)) {
  try {
    const r: any = await safeFetchText(u, cfg);
    const t = htmlToText(r.text);
    console.log('\n=== OK', u, 'chars', t.length, Object.keys(r).join(','), JSON.stringify(r.headers ?? r.lastModified ?? '').slice(0,200));
    console.log(t.slice(0, 1800));
  } catch (e) { console.log('\n=== FAIL', u, (e as Error).message); }
}
})();

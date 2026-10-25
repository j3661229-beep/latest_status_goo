import 'dotenv/config';
import { safeFetchText, htmlToText } from '../src/lib/content/safe-fetch';
import { contentConfig } from '../src/lib/content/config';

(async () => {
  const cfg = contentConfig();
  const r = await safeFetchText('https://newsonair.gov.in/india-aims-to-quadruple-port-capacity-by-2047-union-minister-piyush-goyal/', cfg);
  const t = htmlToText(r.text);
  const ents = t.match(/&#?\w+;/g) ?? [];
  console.log('entities left in text:', [...new Set(ents)].join(' '), 'count', ents.length);
  const i = t.indexOf('Union Commerce');
  console.log('article body:', t.slice(i, i + 1800));
  console.log('numbers in source:', [...new Set(t.match(/\d+/g))].join(','));
})();

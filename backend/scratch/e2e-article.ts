import { contentConfig } from '../src/lib/content/config';
import { safeFetchText, htmlToText } from '../src/lib/content/safe-fetch';
(async () => {
  const r = await safeFetchText(process.argv[2], contentConfig());
  const meta = (p: string) => r.text.match(new RegExp(`<meta[^>]+(?:property|name)=["']${p}["'][^>]+content=["']([^"']+)`, 'i'))?.[1];
  console.log('final', r.finalUrl);
  for (const k of ['og:title','article:published_time','article:modified_time','og:url']) console.log(k, '=', meta(k));
  console.log('canonical', r.text.match(/<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)/i)?.[1]);
  const art = r.text.match(/<article[\s\S]*?<\/article>/i)?.[0] ?? r.text;
  console.log('\n' + htmlToText(art).slice(0, 3000));
})();

import 'dotenv/config';
import { contentConfig } from '../backend/src/lib/content/config';
import { safeFetchText } from '../backend/src/lib/content/safe-fetch';

async function test() {
  const cfg = contentConfig();
  console.log('cfg sourceHosts:', cfg.sourceHosts);
  const url = 'https://news.google.com/rss/search?q=Uttar+Pradesh&hl=hi&gl=IN&ceid=IN:hi';
  console.log('Fetching:', url);
  try {
    const res = await safeFetchText(url, cfg);
    console.log('Fetch success! Status:', res.status, 'Text length:', res.text.length);
    console.log('Sample text:', res.text.slice(0, 300));
  } catch (err: any) {
    console.error('Fetch error:', err.message);
  }
}

test();

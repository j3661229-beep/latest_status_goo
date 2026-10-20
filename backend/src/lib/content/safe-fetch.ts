// src/lib/content/safe-fetch.ts
// SSRF-safe retrieval for source material.
//  - https only, default port only, no embedded credentials
//  - hostname must be on the operator-configured allowlist (CONTENT_SOURCE_HOSTS)
//  - every DNS result (and every redirect hop) must be a public IP
//  - the TCP connection is pinned to the validated address (no DNS-rebinding window)
//  - bounded redirects, response size, time and content type
// Nothing in the API lets an end user choose a URL to fetch; URLs come from admin-entered
// source records or admin-configured feeds, and still pass through this gate.
import dns from 'dns';
import https from 'https';
import net from 'net';
import type { ContentConfig } from './config';

export class UnsafeUrlError extends Error {}
export class FetchError extends Error {
  constructor(message: string, public status?: number) { super(message); }
}

const ALLOWED_TYPES = /^(text\/(html|plain|xml)|application\/(xml|rss\+xml|atom\+xml|json|xhtml\+xml))/i;
const MAX_REDIRECTS = 3;

export function isPrivateAddress(addr: string): boolean {
  const kind = net.isIP(addr);
  if (kind === 4) {
    const [a, b, c] = addr.split('.').map(Number);
    return (
      a === 0 || a === 10 || a === 127 || a >= 224 ||
      (a === 100 && b >= 64 && b <= 127) ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      (a === 192 && b === 0 && c === 0) ||
      (a === 198 && (b === 18 || b === 19))
    );
  }
  if (kind === 6) {
    const v = addr.toLowerCase();
    const mapped = v.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
    if (mapped) return isPrivateAddress(mapped[1]);
    if (v === '::' || v === '::1') return true;
    const first = parseInt(v.split(':')[0] || '0', 16);
    return (first & 0xfe00) === 0xfc00 || (first & 0xffc0) === 0xfe80 || (first & 0xff00) === 0xff00;
  }
  return true; // not an IP at all → refuse
}

export function hostAllowed(host: string, allowlist: string[]): boolean {
  const h = host.toLowerCase().replace(/\.$/, '');
  return allowlist.some((a) => h === a || h.endsWith(`.${a}`));
}

export type Resolver = (host: string) => Promise<string[]>;
const defaultResolver: Resolver = async (host) =>
  (await dns.promises.lookup(host, { all: true })).map((r) => r.address);

/** Validates a URL and returns it with one vetted public address to connect to. */
export async function vetUrl(
  raw: string, cfg: Pick<ContentConfig, 'sourceHosts'>, resolve: Resolver = defaultResolver,
): Promise<{ url: URL; address: string }> {
  let url: URL;
  try { url = new URL(raw); } catch { throw new UnsafeUrlError('Invalid URL'); }
  if (url.protocol !== 'https:') throw new UnsafeUrlError('Only https URLs are allowed');
  if (url.username || url.password) throw new UnsafeUrlError('Credentials in URL are not allowed');
  if (url.port && url.port !== '443') throw new UnsafeUrlError('Non-standard ports are not allowed');
  if (net.isIP(url.hostname.replace(/^\[|\]$/g, ''))) throw new UnsafeUrlError('IP-literal hosts are not allowed');
  if (!hostAllowed(url.hostname, cfg.sourceHosts)) throw new UnsafeUrlError(`Host not on source allowlist: ${url.hostname}`);

  const addrs = await resolve(url.hostname);
  if (addrs.length === 0) throw new FetchError('DNS returned no addresses');
  if (addrs.some(isPrivateAddress)) throw new UnsafeUrlError('Host resolves to a non-public address');
  return { url, address: addrs[0] };
}

export interface TransportResponse { status: number; headers: Record<string, string | undefined>; body: Buffer }
export type Transport = (
  target: { url: URL; address: string },
  opts: { timeoutMs: number; maxBytes: number; userAgent: string },
) => Promise<TransportResponse>;

export const httpsTransport: Transport = ({ url, address }, { timeoutMs, maxBytes, userAgent }) =>
  new Promise((resolve, reject) => {
    const req = https.request(
      {
        method: 'GET',
        host: url.hostname,
        servername: url.hostname,
        path: url.pathname + url.search,
        timeout: timeoutMs,
        headers: { 'User-Agent': userAgent, Accept: 'text/html,application/xml,application/rss+xml,application/json,text/plain' },
        // Pin the socket to the address we already vetted.
        // Node >= 20 calls lookup with { all: true } and expects an array; older call shapes expect (addr, family).
        lookup: (_h, o, cb) => {
          const family = net.isIP(address);
          if ((o as { all?: boolean } | undefined)?.all) (cb as any)(null, [{ address, family }]);
          else (cb as any)(null, address, family);
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        let size = 0;
        res.on('data', (c: Buffer) => {
          size += c.length;
          if (size > maxBytes) { req.destroy(new FetchError('Response too large')); return; }
          chunks.push(c);
        });
        res.on('end', () =>
          resolve({
            status: res.statusCode ?? 0,
            headers: Object.fromEntries(Object.entries(res.headers).map(([k, v]) => [k, Array.isArray(v) ? v[0] : v])),
            body: Buffer.concat(chunks),
          }));
        res.on('error', reject);
      },
    );
    req.on('timeout', () => req.destroy(new FetchError('Request timed out')));
    req.on('error', reject);
    req.end();
  });

/** Minimal fetch signature the pipeline depends on (lets tests inject fakes). */
export type FetchFn = (url: string) => Promise<{ text: string }>;

export interface FetchedText { url: string; finalUrl: string; status: number; contentType: string; text: string }

export async function safeFetchText(
  rawUrl: string,
  cfg: Pick<ContentConfig, 'sourceHosts' | 'maxFetchBytes' | 'fetchTimeoutMs'>,
  deps: { resolve?: Resolver; transport?: Transport } = {},
): Promise<FetchedText> {
  const transport = deps.transport ?? httpsTransport;
  let current = rawUrl;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    const target = await vetUrl(current, cfg, deps.resolve); // re-vet EVERY hop
    const res = await transport(target, {
      timeoutMs: cfg.fetchTimeoutMs, maxBytes: cfg.maxFetchBytes,
      userAgent: process.env.CONTENT_USER_AGENT || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    });
    if ([301, 302, 303, 307, 308].includes(res.status)) {
      const loc = res.headers.location;
      if (!loc) throw new FetchError('Redirect without Location');
      current = new URL(loc, target.url).toString();
      continue;
    }
    if (res.status < 200 || res.status >= 300) throw new FetchError(`Source returned HTTP ${res.status}`, res.status);
    const ct = res.headers['content-type'] ?? '';
    if (!ALLOWED_TYPES.test(ct)) throw new FetchError(`Unsupported content type: ${ct || 'unknown'}`);
    return { url: rawUrl, finalUrl: current, status: res.status, contentType: ct, text: res.body.toString('utf8') };
  }
  throw new FetchError('Too many redirects');
}

/** Crude HTML → text for prompt input (scripts/styles dropped). Output is only ever a prompt input. */
export function htmlToText(html: string): string {
  return html
    .replace(/<(script|style|noscript)[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

import { describe, it, expect, vi } from 'vitest';
import { isPrivateAddress, vetUrl, safeFetchText, UnsafeUrlError, FetchError, hostAllowed, Transport, htmlToText } from '../src/lib/content/safe-fetch';

const cfg = { sourceHosts: ['pib.gov.in', 'example.org'], maxFetchBytes: 1000, fetchTimeoutMs: 1000 };
const pub = async () => ['93.184.216.34'];

describe('htmlToText', () => {
  it('decodes numeric and named entities so verbatim source quotes can match (WordPress feeds use &#8217; etc.)', () => {
    const html = '<p>the government&#8217;s plan &#038; &#x201C;Sagarmala&#x201D; &amp; more &#039;ok&#039; &copy;</p><script>x&#8217;</script>';
    expect(htmlToText(html)).toBe('the government’s plan & “Sagarmala” & more \'ok\' &copy;');
  });
  it('does not double-decode &amp;#8217; (literal text) and leaves invalid code points alone', () => {
    expect(htmlToText('a &amp;#8217; b &#0; c')).toBe('a &#8217; b &#0; c');
  });
});

describe('isPrivateAddress', () => {
  it.each(['127.0.0.1', '10.1.2.3', '172.16.0.1', '172.31.255.255', '192.168.1.1', '169.254.169.254', '100.64.0.1', '0.0.0.0', '::1', 'fc00::1', 'fe80::1', '::ffff:10.0.0.1', 'not-an-ip'])(
    'blocks %s', (a) => expect(isPrivateAddress(a)).toBe(true));
  it.each(['8.8.8.8', '93.184.216.34', '2606:4700::1111'])('allows %s', (a) => expect(isPrivateAddress(a)).toBe(false));
});

describe('hostAllowed', () => {
  it('matches exact and subdomains only', () => {
    expect(hostAllowed('pib.gov.in', cfg.sourceHosts)).toBe(true);
    expect(hostAllowed('www.pib.gov.in', cfg.sourceHosts)).toBe(true);
    expect(hostAllowed('evilpib.gov.in', cfg.sourceHosts)).toBe(false);
    expect(hostAllowed('pib.gov.in.evil.com', cfg.sourceHosts)).toBe(false);
  });
});

describe('vetUrl', () => {
  const bad = async (u: string, resolve = pub) => expect(vetUrl(u, cfg, resolve)).rejects.toBeInstanceOf(UnsafeUrlError);
  it('rejects http, credentials, odd ports, IP literals, unlisted hosts', async () => {
    await bad('http://pib.gov.in/x');
    await bad('https://user:pw@pib.gov.in/x');
    await bad('https://pib.gov.in:8443/x');
    await bad('https://169.254.169.254/latest/meta-data');
    await bad('https://[::1]/');
    await bad('https://evil.com/x');
    await bad('not a url');
  });
  it('rejects allowlisted hosts that resolve to private addresses (DNS rebinding / internal DNS)', async () => {
    await bad('https://pib.gov.in/x', async () => ['10.0.0.5']);
    await bad('https://pib.gov.in/x', async () => ['93.184.216.34', '127.0.0.1']);
  });
  it('accepts an allowlisted host with a public address', async () => {
    expect((await vetUrl('https://www.pib.gov.in/a?b=1', cfg, pub)).address).toBe('93.184.216.34');
  });
  it('fetches nothing when the allowlist is empty', async () => {
    await expect(vetUrl('https://pib.gov.in/', { sourceHosts: [] }, pub)).rejects.toBeInstanceOf(UnsafeUrlError);
  });
});

const ok = (body: string, ct = 'text/html'): Awaited<ReturnType<Transport>> => ({ status: 200, headers: { 'content-type': ct }, body: Buffer.from(body) });

describe('safeFetchText', () => {
  it('returns text for a good response', async () => {
    const t: Transport = vi.fn().mockResolvedValue(ok('<p>hi</p>'));
    const r = await safeFetchText('https://pib.gov.in/a', cfg, { resolve: pub, transport: t });
    expect(r.text).toBe('<p>hi</p>');
  });
  it('re-validates every redirect hop (redirect to internal host is blocked)', async () => {
    const t: Transport = vi.fn().mockResolvedValueOnce({ status: 302, headers: { location: 'https://internal.evil.com/x' }, body: Buffer.alloc(0) });
    await expect(safeFetchText('https://pib.gov.in/a', cfg, { resolve: pub, transport: t })).rejects.toBeInstanceOf(UnsafeUrlError);
    expect(t).toHaveBeenCalledTimes(1);
  });
  it('blocks a redirect to an allowlisted host that resolves privately', async () => {
    const resolve = vi.fn().mockResolvedValueOnce(['93.184.216.34']).mockResolvedValueOnce(['192.168.0.9']);
    const t: Transport = vi.fn().mockResolvedValueOnce({ status: 301, headers: { location: 'https://example.org/n' }, body: Buffer.alloc(0) });
    await expect(safeFetchText('https://pib.gov.in/a', cfg, { resolve, transport: t })).rejects.toBeInstanceOf(UnsafeUrlError);
  });
  it('follows safe redirects but stops after 3', async () => {
    const t: Transport = vi.fn().mockResolvedValue({ status: 302, headers: { location: 'https://pib.gov.in/loop' }, body: Buffer.alloc(0) });
    await expect(safeFetchText('https://pib.gov.in/a', cfg, { resolve: pub, transport: t })).rejects.toThrow(/Too many redirects/);
  });
  it('rejects non-2xx and unsupported content types', async () => {
    await expect(safeFetchText('https://pib.gov.in/a', cfg, { resolve: pub, transport: async () => ({ status: 403, headers: {}, body: Buffer.alloc(0) }) })).rejects.toBeInstanceOf(FetchError);
    await expect(safeFetchText('https://pib.gov.in/a', cfg, { resolve: pub, transport: async () => ok('x', 'application/octet-stream') })).rejects.toThrow(/content type/);
  });
});

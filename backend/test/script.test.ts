import { describe, it, expect, vi } from 'vitest';
import {
  ScriptSchema, validateScriptAgainstSources, generateValidatedScript, ScriptValidationError, numberTokens, ScriptProvider, ScriptInput,
  VertexGeminiProvider,
} from '../src/lib/content/script';
import { contentConfig } from '../src/lib/content/config';

const URL1 = 'https://pmkisan.gov.in/about';
const SRC = 'पीएम किसान योजना में पात्र किसान परिवारों को प्रति वर्ष 6,000 रुपये की सहायता दी जाती है। आवेदन आधिकारिक वेबसाइट पर करें।';
const sources = [{ url: URL1, text: SRC }];

const good = () => ({
  title: 'पीएम किसान योजना',
  hook: 'किसानों के लिए सालाना सहायता',
  narration: 'पीएम किसान योजना में पात्र किसान परिवारों को प्रति वर्ष 6000 रुपये की सहायता दी जाती है। पात्रता की जाँच और आवेदन आधिकारिक वेबसाइट पर करें।',
  scenes: [
    { text: 'योजना', caption: 'पीएम किसान योजना', visual: 'HEADLINE_CARD' },
    { text: 'लाभ', caption: 'प्रति वर्ष 6000 रुपये', visual: 'KEY_FACT' },
  ],
  keyFacts: ['प्रति वर्ष 6000 रुपये की सहायता'],
  claims: [{ text: 'पात्र परिवारों को सालाना 6000 रुपये', sourceUrl: URL1, sourceQuote: 'पात्र किसान परिवारों को प्रति वर्ष 6,000 रुपये की सहायता दी जाती है' }],
  category: 'FARMER',
  description: 'पीएम किसान योजना का सरल सारांश।',
  attributionText: 'स्रोत: pmkisan.gov.in',
  thumbnailText: 'पीएम किसान',
  warnings: [],
  estimatedDurationSec: 26,
});

const input: ScriptInput = { kind: 'SCHEME', language: 'HINDI', category: 'FARMER', targetSeconds: 28, sources };
const provider = (...outs: any[]): ScriptProvider & { generate: any } => {
  const generate = vi.fn();
  outs.forEach((o) => generate.mockResolvedValueOnce({ raw: o, inputTokens: 1000, outputTokens: 500, model: 'm' }));
  return { name: 'mock', generate };
};

describe('validateScriptAgainstSources', () => {
  it('accepts a fully source-backed script (Devanagari and ASCII digits, commas ignored)', () => {
    expect(numberTokens('६,००० और 6,000')).toEqual(['6000', '6000']);
    expect(validateScriptAgainstSources(ScriptSchema.parse(good()), sources)).toEqual([]);
  });
  it('rejects a quote that is not verbatim in the source', () => {
    const s = good(); s.claims[0].sourceQuote = 'सभी किसानों को हर साल दस हज़ार रुपये मिलते हैं';
    expect(validateScriptAgainstSources(ScriptSchema.parse(s), sources).join()).toMatch(/not found verbatim/);
  });
  it('rejects claims citing a URL that was not supplied', () => {
    const s = good(); s.claims[0].sourceUrl = 'https://made-up.example/x';
    expect(validateScriptAgainstSources(ScriptSchema.parse(s), sources).join()).toMatch(/not provided as a source/);
  });
  it('rejects invented numbers (amounts, ages, deadlines)', () => {
    const s = good(); s.narration += ' अंतिम तिथि 31 दिसंबर है और आयु सीमा 60 वर्ष है।';
    const e = validateScriptAgainstSources(ScriptSchema.parse(s), sources);
    expect(e.some((x) => x.includes('"31"'))).toBe(true);
    expect(e.some((x) => x.includes('"60"'))).toBe(true);
  });
  it('rejects invented links but allows provided/known hosts', () => {
    const s = good(); s.narration += ' आवेदन www.fake-yojana.in पर करें।';
    expect(validateScriptAgainstSources(ScriptSchema.parse(s), sources).join()).toMatch(/fake-yojana\.in/);
    const ok = good(); ok.narration += ' विवरण pmkisan.gov.in पर देखें।';
    expect(validateScriptAgainstSources(ScriptSchema.parse(ok), sources)).toEqual([]);
  });
  it('rejects guarantee language and non-Hindi scripts', () => {
    const g = good(); g.narration += ' सभी को मिलेगा, पक्का मिलेगा।';
    expect(validateScriptAgainstSources(ScriptSchema.parse(g), sources).join()).toMatch(/guaranteed/);
    const en = good(); en.narration = 'Eligible farm families receive support every year from the government, apply on the official website today.';
    en.title = 'PM Kisan'; en.hook = 'Yearly support'; en.scenes = [{ text: 'a', caption: 'PM Kisan', visual: 'HEADLINE_CARD' }, { text: 'b', caption: 'Apply', visual: 'KEY_FACT' }]; en.keyFacts = ['Support'];
    expect(validateScriptAgainstSources(ScriptSchema.parse(en), sources).join()).toMatch(/Hindi/);
  });
});

describe('generateValidatedScript', () => {
  const cfg = contentConfig({} as any);
  it('returns a valid script and tracks cost', async () => {
    const p = provider(good());
    const r = await generateValidatedScript(p, input, cfg);
    expect(r.script.title).toBe('पीएम किसान योजना');
    expect(r.costMicroUsd).toBeGreaterThan(0);
    expect(p.generate).toHaveBeenCalledTimes(1);
  });
  it('retries once with feedback after invalid structured output, then succeeds', async () => {
    const p = provider({ title: 'x' }, good());
    const r = await generateValidatedScript(p, input, cfg);
    expect(p.generate).toHaveBeenCalledTimes(2);
    expect(p.generate.mock.calls[1][0].user).toMatch(/rejected for/);
    expect(r.costMicroUsd).toBeGreaterThan(0);
  });
  it('fails (and bills both attempts) when the model keeps producing unsupported claims', async () => {
    const bad = good(); bad.claims[0].sourceQuote = 'यह पाठ स्रोत में कहीं नहीं है';
    const p = provider(bad, bad);
    const e = await generateValidatedScript(p, input, cfg).catch((x) => x);
    expect(e).toBeInstanceOf(ScriptValidationError);
    expect(e.costMicroUsd).toBeGreaterThan(0);
    expect(p.generate).toHaveBeenCalledTimes(2);
  });
  it('refuses to call the model with no sources (no general-knowledge news)', async () => {
    const p = provider(good());
    await expect(generateValidatedScript(p, { ...input, sources: [] }, cfg)).rejects.toBeInstanceOf(ScriptValidationError);
    expect(p.generate).not.toHaveBeenCalled();
  });
  it('truncates oversized sources to the configured limit and marks them as untrusted data', async () => {
    const p = provider(good());
    const small = { ...cfg, maxSourceChars: 50 };
    await generateValidatedScript(p, { ...input, sources: [{ url: URL1, text: SRC + 'x'.repeat(5000) }] }, small).catch(() => undefined);
    const prompt = p.generate.mock.calls[0][0];
    expect(prompt.user.length).toBeLessThan(1500);
    expect(prompt.system).toMatch(/untrusted data/);
  });
});

describe('VertexGeminiProvider', () => {
  const cfg = contentConfig({ GCP_PROJECT_ID: 'p', CONTENT_VERTEX_LOCATION: 'asia-south1', CONTENT_SCRIPT_MODEL: 'gemini-3.5-flash' } as any);
  const vertex = (data: unknown) => {
    const request = vi.fn().mockResolvedValue({ data });
    const auth = { getClient: vi.fn().mockResolvedValue({ request }) } as any;
    return { provider: new VertexGeminiProvider(cfg, auth), request };
  };
  const prompt = { system: 's', user: 'u' };

  it('disables the thinking budget so hidden reasoning cannot eat the JSON output budget', async () => {
    const { provider, request } = vertex({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: '{"ok":true}' }] } }], usageMetadata: { promptTokenCount: 5, candidatesTokenCount: 3 } });
    const r = await provider.generate(prompt);
    expect(r.raw).toEqual({ ok: true });
    expect(r.outputTokens).toBe(3);
    const body = request.mock.calls[0][0].data;
    expect(body.generationConfig.thinkingConfig).toEqual({ thinkingBudget: 0 });
    expect(request.mock.calls[0][0].url).toContain('/asia-south1/publishers/google/models/gemini-3.5-flash:generateContent');
  });
  it('reports truncation (MAX_TOKENS) instead of a generic non-JSON error', async () => {
    const { provider } = vertex({ candidates: [{ finishReason: 'MAX_TOKENS', content: { parts: [{ text: '{"title":"आधा' }] } }] });
    await expect(provider.generate(prompt)).rejects.toThrow(/truncated \(finishReason: MAX_TOKENS\)/);
  });
  it('still reports non-JSON output for a completed but malformed response', async () => {
    const { provider } = vertex({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: 'not json' }] } }] });
    await expect(provider.generate(prompt)).rejects.toThrow(/non-JSON/);
  });
  it('includes finishReason when no text part is returned', async () => {
    const { provider } = vertex({ candidates: [{ finishReason: 'SAFETY', content: { parts: [] } }] });
    await expect(provider.generate(prompt)).rejects.toThrow(/no content \(finishReason: SAFETY\)/);
  });
});

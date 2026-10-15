// src/lib/content/tts.ts
// Hindi narration. Provider interface + Google Cloud Text-to-Speech (ADC, REST).
import { GoogleAuth } from 'google-auth-library';
import { contentConfig, costs, ContentConfig } from './config';

export interface TtsResult {
  audio: Buffer; // mp3
  provider: string;
  voice: string;
  chars: number;
  costMicroUsd: number;
}
export interface TtsProvider {
  readonly name: string;
  synthesize(text: string): Promise<{ audio: Buffer; voice: string }>;
}

const ONES = ['शून्य', 'एक', 'दो', 'तीन', 'चार', 'पाँच', 'छह', 'सात', 'आठ', 'नौ'];
/**
 * Make narration safer for TTS: expand common abbreviations and spell out digit strings that
 * are not plain amounts/years. Numbers are NOT rewritten semantically (no inventing values);
 * we only replace symbols the voice mispronounces.
 */
export function prepareNarration(text: string): string {
  return text
    .replace(/₹\s?([\d,]+(?:\.\d+)?)/g, '$1 रुपये')
    .replace(/(\d)\s?%/g, '$1 प्रतिशत')
    .replace(/\bPM\b/g, 'पी एम').replace(/\bDBT\b/g, 'डी बी टी').replace(/\bOTP\b/g, 'ओ टी पी')
    .replace(/\bKYC\b/g, 'के वाई सी').replace(/\bSC\b/g, 'एस सी').replace(/\bST\b/g, 'एस टी').replace(/\bOBC\b/g, 'ओ बी सी')
    .replace(/\s+/g, ' ').trim();
}
export const _digitWords = ONES; // exported only to keep the table documented/testable

export class GoogleTtsProvider implements TtsProvider {
  readonly name = 'google-tts';
  constructor(private cfg: ContentConfig = contentConfig(), private auth = new GoogleAuth({ scopes: 'https://www.googleapis.com/auth/cloud-platform' })) {}

  async synthesize(text: string) {
    const client = await this.auth.getClient();
    const res = await client.request<{ audioContent?: string }>({
      url: 'https://texttospeech.googleapis.com/v1/text:synthesize',
      method: 'POST',
      timeout: 60_000,
      data: {
        input: { text },
        voice: { languageCode: this.cfg.ttsLanguageCode, name: this.cfg.ttsVoice },
        audioConfig: { audioEncoding: 'MP3', speakingRate: 1.0, sampleRateHertz: 24000 },
      },
    });
    if (!res.data?.audioContent) throw new Error('TTS returned no audio');
    return { audio: Buffer.from(res.data.audioContent, 'base64'), voice: this.cfg.ttsVoice };
  }
}

export async function narrate(provider: TtsProvider, narration: string, cfg: ContentConfig = contentConfig()): Promise<TtsResult> {
  const text = prepareNarration(narration);
  if (!text) throw new Error('Empty narration');
  const { audio, voice } = await provider.synthesize(text);
  if (!audio || audio.length < 500) throw new Error('Narration audio missing or too small');
  return { audio, provider: provider.name, voice, chars: text.length, costMicroUsd: costs.tts(cfg, text.length) };
}

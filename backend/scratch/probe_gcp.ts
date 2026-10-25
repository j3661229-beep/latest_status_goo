import { GoogleAuth } from 'google-auth-library';
import { Storage } from '@google-cloud/storage';

async function main() {
  console.log('Testing GCP integration...');
  const proj = process.env.GCP_PROJECT_ID || process.env.GCS_PROJECT_ID;
  const loc = process.env.CONTENT_VERTEX_LOCATION || 'asia-south1';
  const model = process.env.CONTENT_SCRIPT_MODEL || 'gemini-1.5-flash';
  const bucketName = process.env.GCS_BUCKET_NAME;

  console.log(JSON.stringify({ proj, loc, model, bucketName }));

  const auth = new GoogleAuth({ scopes: 'https://www.googleapis.com/auth/cloud-platform' });
  const client = await auth.getClient();
  console.log('Auth client initialized successfully');

  // 1. Test GCS
  try {
    const storage = new Storage({ projectId: proj });
    const bucket = storage.bucket(bucketName);
    const [exists] = await bucket.exists();
    console.log(`GCS bucket ${bucketName} exists:`, exists);

    const testFile = bucket.file('scratch/test-probe.txt');
    await testFile.save('probe-' + Date.now(), { contentType: 'text/plain' });
    console.log('GCS write test: SUCCESS');
    const [contents] = await testFile.download();
    console.log('GCS read test: SUCCESS (content length ' + contents.length + ')');
    await testFile.delete();
    console.log('GCS delete test: SUCCESS');
  } catch (err: any) {
    console.error('GCS test FAILED:', err.message || err);
  }

  // 2. Test TTS
  try {
    const res: any = await client.request({
      url: 'https://texttospeech.googleapis.com/v1/text:synthesize',
      method: 'POST',
      data: {
        input: { text: 'नमस्ते, यह एक परीक्षण है।' },
        voice: { languageCode: 'hi-IN', name: 'hi-IN-Neural2-A' },
        audioConfig: { audioEncoding: 'MP3' },
      },
    });
    console.log('TTS test: SUCCESS, audio bytes:', res.data?.audioContent ? Buffer.from(res.data.audioContent, 'base64').length : 0);
  } catch (err: any) {
    console.error('TTS test FAILED:', err.message || err);
    if (err.response?.data) console.error(JSON.stringify(err.response.data));
  }

  // 3. Test Vertex AI with model
  const testModels = [model, 'gemini-1.5-flash', 'gemini-1.5-flash-002', 'gemini-2.0-flash', 'gemini-2.5-flash'];
  for (const m of testModels) {
    try {
      console.log(`Testing Vertex AI with model: ${m} in ${loc}...`);
      const res: any = await client.request({
        url: `https://${loc}-aiplatform.googleapis.com/v1/projects/${proj}/locations/${loc}/publishers/google/models/${m}:generateContent`,
        method: 'POST',
        data: {
          contents: [{ role: 'user', parts: [{ text: 'Hello, respond with {"status":"ok"}' }] }],
          generationConfig: { responseMimeType: 'application/json' },
        },
      });
      console.log(`Vertex AI (${m}) test: SUCCESS!`);
      const text = res.data?.candidates?.[0]?.content?.parts?.[0]?.text;
      console.log('Response:', text);
      break; // found a working model
    } catch (err: any) {
      console.error(`Vertex AI (${m}) FAILED:`, err.message || err);
      if (err.response?.data) console.error(JSON.stringify(err.response.data));
    }
  }
}

main().catch(console.error);

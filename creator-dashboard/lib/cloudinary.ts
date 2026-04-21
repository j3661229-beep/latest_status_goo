import axios from 'axios';

/**
 * Uploads a file to Cloudinary using signed parameters from our backend.
 */
export async function uploadToCloudinary(
  file: File, 
  signData: { signature: string; timestamp: number; cloudName: string; apiKey: string; folder: string }
) {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('signature', signData.signature);
  formData.append('timestamp', signData.timestamp.toString());
  formData.append('api_key', signData.apiKey);
  formData.append('folder', signData.folder);

  const url = `https://api.cloudinary.com/v1_1/${signData.cloudName}/auto/upload`;

  const res = await axios.post(url, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });

  return {
    url: res.data.secure_url,
    publicId: res.data.public_id,
    duration: res.data.duration, // only for videos
    width: res.data.width,
    height: res.data.height,
    format: res.data.format,
  };
}

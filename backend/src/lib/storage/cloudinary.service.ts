import { v2 as cloudinary } from 'cloudinary';

// Configure Cloudinary properly from CLOUDINARY_URL or individual env vars
function initCloudinary() {
  const url = process.env.CLOUDINARY_URL || '';
  const match = url.match(/cloudinary:\/\/([^:]+):([^@]+)@(.*)/);
  const cloudName = match ? match[3] : (process.env.NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME || process.env.CLOUDINARY_CLOUD_NAME);
  const apiKey = match ? match[1] : (process.env.NEXT_PUBLIC_CLOUDINARY_API_KEY || process.env.CLOUDINARY_API_KEY);
  const apiSecret = match ? match[2] : process.env.CLOUDINARY_API_SECRET;

  if (cloudName && apiKey && apiSecret) {
    cloudinary.config({
      cloud_name: cloudName,
      api_key: apiKey,
      api_secret: apiSecret,
      secure: true,
    });
  }
}
initCloudinary();

export class CloudinaryService {
  /**
   * Generates a signed upload request signature.
   */
  static async getSignature(params: Record<string, any>) {
    const timestamp = params.timestamp || Math.round(new Date().getTime() / 1000);
    
    // The library uses the config established above to sign
    const signature = cloudinary.utils.api_sign_request(
      { ...params, timestamp },
      cloudinary.config().api_secret || ''
    );
    
    return { 
      signature, 
      timestamp, 
      apiKey: cloudinary.config().api_key, 
      cloudName: cloudinary.config().cloud_name 
    };
  }

  static async uploadStream(fileBuffer: Buffer, folder: string = 'templates'): Promise<any> {
    return new Promise((resolve, reject) => {
      const upload = cloudinary.uploader.upload_stream(
        {
          folder: `status-go/${folder}`,
          resource_type: 'auto',
        },
        (error, result) => {
          if (error) return reject(error);
          resolve(result);
        }
      );
      upload.end(fileBuffer);
    });
  }
}

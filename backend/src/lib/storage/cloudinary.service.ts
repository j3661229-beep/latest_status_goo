import { v2 as cloudinary } from 'cloudinary';

// Configure with the URL from .env
if (process.env.CLOUDINARY_URL) {
  cloudinary.config({
    cloudinary_url: process.env.CLOUDINARY_URL
  });
}

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

export interface ImageData {
  readonly contentType: string;
  readonly body: Buffer;
}

/**
 * Fetches a product image from wherever the data source hosts it, so the
 * client only ever talks to our API. A future source with its own CDN (or S3
 * + CloudFront) would get its own adapter, or the API could redirect instead.
 */
export interface ImageFetcher {
  fetch(sourceUrl: string): Promise<ImageData>;
}

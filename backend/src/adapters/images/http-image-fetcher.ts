import { UpstreamUnavailableError } from '../../domain/errors.js';
import type { ImageData, ImageFetcher } from '../../ports/image-fetcher.js';

export interface HttpImageFetcherOptions {
  readonly timeoutMs: number;
  /** Refuse anything larger, so a bad upstream can't make us buffer huge files. */
  readonly maxBytes?: number;
  /** Injected so tests never touch the network. */
  readonly fetch?: typeof globalThis.fetch;
}

/**
 * Downloads an image over HTTP(S). Only ever called with URLs that came from
 * the product data source (looked up by product id), never with a URL a client
 * sent, so it cannot be used to make the server fetch arbitrary addresses.
 */
export class HttpImageFetcher implements ImageFetcher {
  private readonly fetchFn: typeof globalThis.fetch;
  private readonly maxBytes: number;

  constructor(private readonly options: HttpImageFetcherOptions) {
    this.fetchFn = options.fetch ?? globalThis.fetch;
    this.maxBytes = options.maxBytes ?? 5 * 1024 * 1024;
  }

  async fetch(sourceUrl: string): Promise<ImageData> {
    const url = new URL(sourceUrl);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') {
      throw new UpstreamUnavailableError(`Refusing to fetch image over ${url.protocol}`);
    }

    let response: Response;
    try {
      response = await this.fetchFn(url, { signal: AbortSignal.timeout(this.options.timeoutMs) });
    } catch (error) {
      throw new UpstreamUnavailableError('Image source did not respond', { cause: error });
    }

    if (!response.ok) {
      throw new UpstreamUnavailableError(`Image source returned HTTP ${response.status}`);
    }

    const contentType = response.headers.get('content-type')?.split(';')[0]?.trim().toLowerCase() ?? '';
    if (!contentType.startsWith('image/')) {
      throw new UpstreamUnavailableError(`Image source returned "${contentType || 'no content type'}"`);
    }

    const declaredLength = Number(response.headers.get('content-length') ?? 0);
    if (declaredLength > this.maxBytes) {
      throw new UpstreamUnavailableError('Image is too large');
    }

    const body = Buffer.from(await response.arrayBuffer());
    if (body.length > this.maxBytes) {
      throw new UpstreamUnavailableError('Image is too large');
    }
    return { contentType, body };
  }
}

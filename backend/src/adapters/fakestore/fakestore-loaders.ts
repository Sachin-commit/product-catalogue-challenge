import { readFile } from 'node:fs/promises';
import { UpstreamUnavailableError } from '../../domain/errors.js';
import type { Product } from '../../domain/product.js';
import type { Logger } from '../../lib/logger.js';
import { mapFakeStoreCatalogue } from './fakestore-mapper.js';

export interface FakeStoreApiOptions {
  readonly baseUrl: string;
  readonly timeoutMs: number;
  readonly logger: Logger;
  /** Injected so tests never touch the network. */
  readonly fetch?: typeof globalThis.fetch;
}

/**
 * Loads the whole catalogue from Fake Store's `/products` endpoint.
 * The catalogue is 20 items, so one call plus caching beats per-id calls,
 * and it sidesteps Fake Store returning `200` with an empty body for unknown ids.
 */
export function createFakeStoreApiLoader(options: FakeStoreApiOptions): () => Promise<Product[]> {
  const fetchFn = options.fetch ?? globalThis.fetch;
  const url = new URL('/products', options.baseUrl);

  return async () => {
    let response: Response;
    try {
      response = await fetchFn(url, {
        headers: { accept: 'application/json' },
        signal: AbortSignal.timeout(options.timeoutMs),
      });
    } catch (error) {
      throw new UpstreamUnavailableError('Product source did not respond', { cause: error });
    }

    if (!response.ok) {
      throw new UpstreamUnavailableError(`Product source returned HTTP ${response.status}`);
    }

    const body = await response.text();
    if (body.trim().length === 0) {
      throw new UpstreamUnavailableError('Product source returned an empty response');
    }

    try {
      const products = mapFakeStoreCatalogue(JSON.parse(body), options.logger);
      options.logger.info({ count: products.length }, 'Loaded catalogue from Fake Store API');
      return products;
    } catch (error) {
      throw new UpstreamUnavailableError('Product source returned data we could not read', { cause: error });
    }
  };
}

/**
 * Loads a recorded Fake Store response from disk. Lets the app run with no
 * internet access and gives tests and demos a stable catalogue.
 */
export function createFakeStoreSnapshotLoader(filePath: string, logger: Logger): () => Promise<Product[]> {
  return async () => {
    const raw = await readFile(filePath, 'utf8');
    const products = mapFakeStoreCatalogue(JSON.parse(raw), logger);
    logger.info({ count: products.length, filePath }, 'Loaded catalogue from snapshot file');
    return products;
  };
}

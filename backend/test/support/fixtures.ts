import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { pino } from 'pino';
import { mapFakeStoreCatalogue } from '../../src/adapters/fakestore/fakestore-mapper.js';
import { InMemoryProductRepository } from '../../src/adapters/in-memory/in-memory-product-repository.js';
import { StaticMerchandisingSource } from '../../src/adapters/merchandising/json-file-merchandising-source.js';
import { createApp } from '../../src/app.js';
import type { Product } from '../../src/domain/product.js';
import { categoryFromSourceName } from '../../src/domain/category.js';
import type { EmailSender, OutboundEmail } from '../../src/ports/email-sender.js';
import type { ImageData, ImageFetcher } from '../../src/ports/image-fetcher.js';
import type { ProductRepository } from '../../src/ports/product-repository.js';
import { CatalogueService } from '../../src/services/catalogue-service.js';
import { EnquiryService } from '../../src/services/enquiry-service.js';

export const silentLogger = pino({ level: 'silent' });

export const SNAPSHOT_PATH = fileURLToPath(new URL('../../data/fakestore-products.snapshot.json', import.meta.url));

export function loadSnapshotCatalogue(): Product[] {
  return mapFakeStoreCatalogue(JSON.parse(readFileSync(SNAPSHOT_PATH, 'utf8')), silentLogger);
}

export function makeProduct(overrides: Partial<Product> & { id: string }): Product {
  return {
    title: `Product ${overrides.id}`,
    description: 'A product',
    category: categoryFromSourceName('misc'),
    price: { amountMinor: 1000, currency: 'USD' },
    sourceImageUrl: `https://images.example.com/${overrides.id}.png`,
    rating: { average: 3, count: 10 },
    ...overrides,
  };
}

/** Records emails instead of sending them; can be told to fail. */
export class RecordingEmailSender implements EmailSender {
  readonly sent: OutboundEmail[] = [];
  failWith: Error | null = null;

  async send(email: OutboundEmail): Promise<void> {
    if (this.failWith) throw this.failWith;
    this.sent.push(email);
  }
}

/** Serves a tiny fake PNG for any URL, records what was asked for, and can be told to fail. */
export class FakeImageFetcher implements ImageFetcher {
  static readonly PNG = Buffer.from('89504e470d0a1a0a', 'hex');
  readonly requested: string[] = [];
  failWith: Error | null = null;

  async fetch(sourceUrl: string): Promise<ImageData> {
    this.requested.push(sourceUrl);
    if (this.failWith) throw this.failWith;
    return { contentType: 'image/png', body: FakeImageFetcher.PNG };
  }
}

export interface TestAppOptions {
  products?: ProductRepository;
  featuredIds?: string[];
  email?: RecordingEmailSender;
  images?: FakeImageFetcher;
  rateLimitMax?: number;
  publicBaseUrl?: string;
}

export const SALES_INBOX = 'sales@test.local';

export function createTestApp(options: TestAppOptions = {}) {
  const catalogue = loadSnapshotCatalogue();
  const products = options.products ?? new InMemoryProductRepository(async () => catalogue);
  const merchandising = new StaticMerchandisingSource(options.featuredIds ?? ['3', '5', '11', '17', '1']);
  const email = options.email ?? new RecordingEmailSender();
  const images = options.images ?? new FakeImageFetcher();

  const app = createApp({
    catalogue: new CatalogueService(products, merchandising, images, silentLogger),
    enquiries: new EnquiryService(products, email, silentLogger, {
      salesInbox: SALES_INBOX,
      generateReference: () => 'ENQ-TEST0001',
    }),
    logger: silentLogger,
    trustProxy: false,
    publicBaseUrl: options.publicBaseUrl,
    enquiryRateLimit: { max: options.rateLimitMax ?? 100, windowMs: 60_000 },
  });
  return { app, email, images };
}

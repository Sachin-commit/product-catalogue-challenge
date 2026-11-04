import { z } from 'zod';
import { categoryFromSourceName } from '../../domain/category.js';
import { toMinorUnits, type Product } from '../../domain/product.js';
import type { Logger } from '../../lib/logger.js';

/**
 * Fake Store's product shape. Kept private to this adapter: the rest of the
 * app only ever sees our `Product`.
 */
const fakeStoreProductSchema = z.object({
  id: z.number().int().positive(),
  title: z.string().trim().min(1),
  price: z.number().nonnegative(),
  description: z.string(),
  category: z.string().trim().min(1),
  image: z.url(),
  rating: z
    .object({
      rate: z.number().min(0).max(5),
      count: z.number().int().nonnegative(),
    })
    .optional(),
});

type FakeStoreProduct = z.infer<typeof fakeStoreProductSchema>;

/** Fake Store has no currency field; its prices are presented in USD. */
const FAKESTORE_CURRENCY = 'USD';

function toProduct(raw: FakeStoreProduct): Product {
  return {
    id: String(raw.id),
    title: raw.title,
    description: raw.description.trim(),
    category: categoryFromSourceName(raw.category),
    price: { amountMinor: toMinorUnits(raw.price), currency: FAKESTORE_CURRENCY },
    sourceImageUrl: raw.image,
    rating: raw.rating ? { average: raw.rating.rate, count: raw.rating.count } : null,
  };
}

export class MalformedCatalogueError extends Error {}

/**
 * Validates and maps a Fake Store `/products` payload.
 * A payload that is not a list is rejected outright. Individual malformed items
 * are skipped and logged rather than taking the whole catalogue down.
 */
export function mapFakeStoreCatalogue(payload: unknown, logger: Logger): Product[] {
  if (!Array.isArray(payload)) {
    throw new MalformedCatalogueError('Expected a JSON array of products');
  }

  const products: Product[] = [];
  payload.forEach((item, index) => {
    const parsed = fakeStoreProductSchema.safeParse(item);
    if (parsed.success) {
      products.push(toProduct(parsed.data));
    } else {
      logger.warn({ index, issues: parsed.error.issues.map((issue) => issue.path.join('.')) }, 'Skipping malformed product');
    }
  });
  return products;
}

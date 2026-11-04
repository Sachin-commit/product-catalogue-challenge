import type { Category, Product } from '../domain/product.js';

/**
 * The only way the application reads product data.
 *
 * Search and category filtering are part of the contract (rather than
 * "give me everything and I'll filter") so that a future source — a database,
 * a PIM, a search engine — can do them natively and at scale. The current
 * adapters happen to do them in memory because the catalogue is tiny.
 */
export interface ProductRepository {
  getById(id: string): Promise<Product | null>;
  listCategories(): Promise<Category[]>;
  /** Returns null when the category does not exist (distinct from an empty category). */
  listByCategory(slug: string): Promise<{ category: Category; products: Product[] } | null>;
  search(term: string): Promise<Product[]>;
  /** Used by merchandising, which needs to look up curated ids and fall back by rating. */
  listAll(): Promise<Product[]>;
}

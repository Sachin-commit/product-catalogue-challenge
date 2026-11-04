import type { Category, Product } from '../../domain/product.js';
import { searchProducts } from '../../domain/search.js';
import type { ProductRepository } from '../../ports/product-repository.js';

/**
 * Implements the repository contract over a full in-memory product list.
 * Fine for a catalogue of tens or hundreds of products; a larger catalogue
 * would get a repository that pushes search and filtering down to its store.
 */
export class InMemoryProductRepository implements ProductRepository {
  constructor(private readonly loadCatalogue: () => Promise<readonly Product[]>) {}

  async listAll(): Promise<Product[]> {
    return [...(await this.loadCatalogue())];
  }

  async getById(id: string): Promise<Product | null> {
    const products = await this.loadCatalogue();
    return products.find((product) => product.id === id) ?? null;
  }

  async listCategories(): Promise<Category[]> {
    const products = await this.loadCatalogue();
    const bySlug = new Map<string, Category>();
    for (const product of products) {
      if (!bySlug.has(product.category.slug)) bySlug.set(product.category.slug, product.category);
    }
    return [...bySlug.values()].sort((a, b) => a.name.localeCompare(b.name));
  }

  async listByCategory(slug: string): Promise<{ category: Category; products: Product[] } | null> {
    const products = (await this.loadCatalogue()).filter((product) => product.category.slug === slug);
    const category = products[0]?.category;
    return category ? { category, products } : null;
  }

  async search(term: string): Promise<Product[]> {
    return searchProducts(await this.loadCatalogue(), term);
  }
}

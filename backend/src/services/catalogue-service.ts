import { NotFoundError } from '../domain/errors.js';
import { partitionCategory, selectFeaturedProducts, type CategoryListing } from '../domain/merchandising.js';
import type { Category, Product } from '../domain/product.js';
import type { Logger } from '../lib/logger.js';
import type { ImageData, ImageFetcher } from '../ports/image-fetcher.js';
import type { MerchandisingSource } from '../ports/merchandising-source.js';
import type { ProductRepository } from '../ports/product-repository.js';

/** Use cases for browsing the catalogue. Knows nothing about HTTP or Fake Store. */
export class CatalogueService {
  constructor(
    private readonly products: ProductRepository,
    private readonly merchandising: MerchandisingSource,
    private readonly images: ImageFetcher,
    private readonly logger: Logger,
  ) {}

  async getFeaturedProducts(): Promise<Product[]> {
    const [catalogue, curatedIds] = await Promise.all([
      this.products.listAll(),
      this.merchandising.getFeaturedProductIds(),
    ]);
    const selection = selectFeaturedProducts(catalogue, curatedIds);
    if (selection.missingIds.length > 0 || selection.toppedUp) {
      this.logger.warn(
        { missingIds: selection.missingIds, toppedUp: selection.toppedUp },
        'Featured products need attention: curated ids missing from the catalogue',
      );
    }
    return selection.products;
  }

  listCategories(): Promise<Category[]> {
    return this.products.listCategories();
  }

  async getCategoryListing(slug: string): Promise<{ category: Category } & CategoryListing> {
    const [listing, curatedIds] = await Promise.all([
      this.products.listByCategory(slug),
      this.merchandising.getFeaturedProductIds(),
    ]);
    if (!listing) throw new NotFoundError(`Category "${slug}" was not found`);
    return { category: listing.category, ...partitionCategory(listing.products, curatedIds) };
  }

  search(term: string): Promise<Product[]> {
    return this.products.search(term);
  }

  async getProduct(id: string): Promise<Product> {
    const product = await this.products.getById(id);
    if (!product) throw new NotFoundError(`Product "${id}" was not found`);
    return product;
  }

  /** The image is looked up by product id, so clients can't make us fetch arbitrary URLs. */
  async getProductImage(id: string): Promise<ImageData> {
    const product = await this.getProduct(id);
    return this.images.fetch(product.sourceImageUrl);
  }
}

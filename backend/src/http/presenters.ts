import type { Category, Product } from '../domain/product.js';

/**
 * The public API contract (v1). Deliberately separate from the domain types so
 * the domain can evolve without breaking shipped mobile apps, which cannot be
 * force-updated the way a website can.
 */
export interface ProductDto {
  id: string;
  title: string;
  description: string;
  category: CategoryDto;
  /** Amount in minor units (cents). Clients format it for their locale. */
  price: { amountMinor: number; currency: string };
  /** Always points at this API (`/products/:id/image`), never at the data source. */
  imageUrl: string;
  rating: { average: number; count: number } | null;
}

export interface CategoryDto {
  slug: string;
  name: string;
}

export function toCategoryDto(category: Category): CategoryDto {
  return { slug: category.slug, name: category.name };
}

/** Builds the public URL of a product's image on this API. */
export type ImageUrlBuilder = (productId: string) => string;

export function imageUrlBuilder(publicBaseUrl: string): ImageUrlBuilder {
  return (productId) => new URL(`/api/v1/products/${encodeURIComponent(productId)}/image`, publicBaseUrl).toString();
}

export function toProductDto(product: Product, imageUrlFor: ImageUrlBuilder): ProductDto {
  return {
    id: product.id,
    title: product.title,
    description: product.description,
    category: toCategoryDto(product.category),
    price: { amountMinor: product.price.amountMinor, currency: product.price.currency },
    imageUrl: imageUrlFor(product.id),
    rating: product.rating ? { average: product.rating.average, count: product.rating.count } : null,
  };
}

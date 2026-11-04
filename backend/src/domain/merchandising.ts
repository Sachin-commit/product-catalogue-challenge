import { compareByCustomerRating, type Product } from './product.js';

/** The home page shows exactly this many featured products. */
export const FEATURED_PRODUCT_COUNT = 5;
/** The "top rated" strip on a category page shows up to this many. */
export const CATEGORY_TOP_RATED_COUNT = 3;

export interface FeaturedSelection {
  readonly products: Product[];
  /** Curated ids that no longer exist in the catalogue. Surfaced so they can be logged. */
  readonly missingIds: string[];
  /** True when the curated list could not fill the slots and we topped up by rating. */
  readonly toppedUp: boolean;
}

/**
 * "Top rated" on the home page means the owner's curated picks, in their order.
 * If a curated product has disappeared from the data source we keep the page
 * full by topping up with the best customer-rated products instead of showing
 * a gap, and report the missing ids so someone can fix the curation.
 */
export function selectFeaturedProducts(
  catalogue: readonly Product[],
  curatedIds: readonly string[],
  count = FEATURED_PRODUCT_COUNT,
): FeaturedSelection {
  const byId = new Map(catalogue.map((product) => [product.id, product]));
  const uniqueIds = [...new Set(curatedIds)];

  const chosen: Product[] = [];
  const missingIds: string[] = [];
  for (const id of uniqueIds) {
    const product = byId.get(id);
    if (product) {
      if (chosen.length < count) chosen.push(product);
    } else {
      missingIds.push(id);
    }
  }

  const toppedUp = chosen.length < count;
  if (toppedUp) {
    const chosenIds = new Set(chosen.map((product) => product.id));
    const fillers = [...catalogue]
      .filter((product) => !chosenIds.has(product.id))
      .sort(compareByCustomerRating)
      .slice(0, count - chosen.length);
    chosen.push(...fillers);
  }

  return { products: chosen, missingIds, toppedUp };
}

export interface CategoryListing {
  readonly topRated: Product[];
  readonly more: Product[];
}

/**
 * Splits one category's products into a "top rated" strip and "more products".
 * Curated picks that belong to this category lead the strip (the owner's choice
 * wins), the rest of the strip is filled by customer rating so it is never empty,
 * and everything else is listed under "more", best rated first.
 */
export function partitionCategory(
  categoryProducts: readonly Product[],
  curatedIds: readonly string[],
  topCount = CATEGORY_TOP_RATED_COUNT,
): CategoryListing {
  const curatedRank = new Map([...new Set(curatedIds)].map((id, index) => [id, index]));

  const curated = categoryProducts
    .filter((product) => curatedRank.has(product.id))
    .sort((a, b) => curatedRank.get(a.id)! - curatedRank.get(b.id)!);
  const others = categoryProducts
    .filter((product) => !curatedRank.has(product.id))
    .sort(compareByCustomerRating);

  const ordered = [...curated, ...others];
  return { topRated: ordered.slice(0, topCount), more: ordered.slice(topCount) };
}

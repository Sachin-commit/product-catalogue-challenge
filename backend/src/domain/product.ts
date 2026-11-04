/**
 * Core catalogue types. These belong to *us*, not to any data source:
 * adapters map their own shapes into these, and the HTTP layer maps these
 * into the public API contract. Nothing outside `adapters/` knows Fake Store exists.
 */

export interface Money {
  /** Integer amount in the currency's minor unit (e.g. cents) to avoid float rounding. */
  readonly amountMinor: number;
  /** ISO 4217 code. */
  readonly currency: string;
}

export interface Category {
  /** URL-safe, stable identifier generated from the source name. */
  readonly slug: string;
  /** Human-readable label for display. */
  readonly name: string;
}

export interface Rating {
  /** Average customer rating, 0–5. */
  readonly average: number;
  readonly count: number;
}

export interface Product {
  /** String so that a future data source is not tied to integer ids. */
  readonly id: string;
  readonly title: string;
  readonly description: string;
  readonly category: Category;
  readonly price: Money;
  /** Where the data source hosts the image. Clients never see this; they get our proxied URL. */
  readonly sourceImageUrl: string;
  readonly rating: Rating | null;
}

const PRODUCT_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

export function isValidProductId(id: string): boolean {
  return PRODUCT_ID_PATTERN.test(id);
}

/** Converts a decimal price such as 109.95 into minor units without float drift. */
export function toMinorUnits(amount: number, fractionDigits = 2): number {
  return Math.round(amount * 10 ** fractionDigits);
}

/** Highest customer rating first; more reviews wins a tie; id keeps the order stable. */
export function compareByCustomerRating(a: Product, b: Product): number {
  const byAverage = (b.rating?.average ?? 0) - (a.rating?.average ?? 0);
  if (byAverage !== 0) return byAverage;
  const byCount = (b.rating?.count ?? 0) - (a.rating?.count ?? 0);
  if (byCount !== 0) return byCount;
  return a.id.localeCompare(b.id, 'en', { numeric: true });
}

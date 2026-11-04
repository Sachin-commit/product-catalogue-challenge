/**
 * Where the owner's curation decisions live. Today it is a JSON file in the
 * repo; tomorrow it could be a CMS or an admin screen backed by a database.
 */
export interface MerchandisingSource {
  /** Product ids the owner has chosen as "top rated", in display order. */
  getFeaturedProductIds(): Promise<string[]>;
}

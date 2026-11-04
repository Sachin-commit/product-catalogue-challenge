import { describe, expect, it } from 'vitest';
import { partitionCategory, selectFeaturedProducts } from '../../src/domain/merchandising.js';
import { makeProduct } from '../support/fixtures.js';

const rated = (id: string, average: number, count = 10) => makeProduct({ id, rating: { average, count } });

const catalogue = [rated('1', 4.0), rated('2', 2.0), rated('3', 4.9), rated('4', 3.0), rated('5', 1.0), rated('6', 4.5), rated('7', 3.5)];

describe('selectFeaturedProducts', () => {
  it("returns exactly the owner's five picks, in the owner's order, regardless of customer rating", () => {
    const selection = selectFeaturedProducts(catalogue, ['5', '2', '7', '1', '4']);
    expect(selection.products.map((product) => product.id)).toEqual(['5', '2', '7', '1', '4']);
    expect(selection.missingIds).toEqual([]);
    expect(selection.toppedUp).toBe(false);
  });

  it('tops up by customer rating and reports ids that no longer exist', () => {
    const selection = selectFeaturedProducts(catalogue, ['5', 'gone', '2', '7', '1']);
    expect(selection.products.map((product) => product.id)).toEqual(['5', '2', '7', '1', '3']);
    expect(selection.missingIds).toEqual(['gone']);
    expect(selection.toppedUp).toBe(true);
  });

  it('ignores duplicate picks and extra picks beyond five', () => {
    const selection = selectFeaturedProducts(catalogue, ['1', '1', '2', '4', '5', '6', '7']);
    expect(selection.products.map((product) => product.id)).toEqual(['1', '2', '4', '5', '6']);
  });

  it('never returns more products than exist', () => {
    expect(selectFeaturedProducts(catalogue.slice(0, 2), []).products).toHaveLength(2);
  });
});

describe('partitionCategory', () => {
  it('puts curated picks first, fills the top-rated strip by rating, and lists the rest under "more"', () => {
    const listing = partitionCategory(catalogue, ['4']);
    expect(listing.topRated.map((product) => product.id)).toEqual(['4', '3', '6']);
    expect(listing.more.map((product) => product.id)).toEqual(['1', '7', '2', '5']);
  });

  it('keeps every product exactly once across both sections', () => {
    const listing = partitionCategory(catalogue, ['2', '9']);
    const all = [...listing.topRated, ...listing.more].map((product) => product.id).sort();
    expect(all).toEqual(catalogue.map((product) => product.id).sort());
  });

  it('handles categories smaller than the strip', () => {
    const listing = partitionCategory(catalogue.slice(0, 2), []);
    expect(listing.topRated).toHaveLength(2);
    expect(listing.more).toEqual([]);
  });

  it('breaks rating ties by number of reviews', () => {
    const listing = partitionCategory([rated('a', 4, 5), rated('b', 4, 50)], [], 1);
    expect(listing.topRated[0]?.id).toBe('b');
  });
});

import { describe, expect, it } from 'vitest';
import { categoryFromSourceName } from '../../src/domain/category.js';
import { searchProducts, tokenizeSearchTerm } from '../../src/domain/search.js';
import { loadSnapshotCatalogue, makeProduct } from '../support/fixtures.js';

const catalogue = loadSnapshotCatalogue();
const ids = (term: string) => searchProducts(catalogue, term).map((product) => product.id);

describe('tokenizeSearchTerm', () => {
  it('lowercases, strips accents and apostrophes, and de-duplicates', () => {
    expect(tokenizeSearchTerm("  Women's  CAFÉ café ")).toEqual(['womens', 'cafe']);
  });

  it('returns no tokens for punctuation-only input', () => {
    expect(tokenizeSearchTerm('!!! ---')).toEqual([]);
  });
});

describe('searchProducts', () => {
  it('only returns products whose text matches the term', () => {
    const results = searchProducts(catalogue, 'ssd');
    expect(results.length).toBeGreaterThan(0);
    for (const product of results) {
      expect(`${product.title} ${product.description}`.toLowerCase()).toContain('ssd');
    }
  });

  it('is case-insensitive', () => {
    expect(ids('BACKPACK')).toEqual(ids('backpack'));
    expect(ids('backpack')).toEqual(['1']);
  });

  it('matches word prefixes, so "laptop" finds "Laptops"', () => {
    expect(ids('laptop')).toContain('1');
  });

  it('does not match inside words: "men" must not return women\'s clothing', () => {
    const results = searchProducts(catalogue, 'men');
    expect(results.length).toBeGreaterThan(0);
    expect(results.every((product) => product.category.slug !== 'womens-clothing')).toBe(true);
  });

  it('requires every word to match (AND), so more words narrow the results', () => {
    const broad = ids('jacket');
    const narrow = ids('jacket women');
    expect(narrow.length).toBeGreaterThan(0);
    expect(narrow.length).toBeLessThan(broad.length);
    expect(narrow.every((id) => broad.includes(id))).toBe(true);
  });

  it('matches the category name', () => {
    expect(ids('jewelery').sort()).toEqual(['5', '6', '7', '8']);
  });

  it('returns nothing for a term with no words, and nothing for no match', () => {
    expect(ids('???')).toEqual([]);
    expect(ids('zzzzqqq')).toEqual([]);
  });

  it('ranks title matches above description-only matches, then by rating', () => {
    const products = [
      makeProduct({ id: 'a', title: 'Plain mug', description: 'A red cup', rating: { average: 5, count: 1 } }),
      makeProduct({ id: 'b', title: 'Red cup', description: 'Ceramic', rating: { average: 2, count: 1 } }),
      makeProduct({ id: 'c', title: 'Red cup deluxe', description: 'Ceramic', rating: { average: 4, count: 1 } }),
      makeProduct({ id: 'd', title: 'Blue cup', description: 'Ceramic', category: categoryFromSourceName('red') }),
    ];
    // c and b match both words in the title (c is better rated), d matches "cup" in
    // the title and "red" via its category, a only matches in the description.
    expect(searchProducts(products, 'red cup').map((product) => product.id)).toEqual(['c', 'b', 'd', 'a']);
  });
});

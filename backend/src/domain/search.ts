import { compareByCustomerRating, type Product } from './product.js';

export const SEARCH_TERM_MAX_LENGTH = 100;

/**
 * Splits text into lowercase, accent-free words. Apostrophes are removed before
 * splitting so "Men's" becomes the single word "mens".
 */
function toWords(text: string): string[] {
  return text
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/['’]/g, '')
    .split(/[^a-z0-9]+/)
    .filter((word) => word.length > 0);
}

export function tokenizeSearchTerm(term: string): string[] {
  return [...new Set(toWords(term))];
}

interface SearchableText {
  readonly titleWords: string[];
  readonly allWords: string[];
}

function searchableText(product: Product): SearchableText {
  const titleWords = toWords(product.title);
  return {
    titleWords,
    allWords: [...titleWords, ...toWords(product.description), ...toWords(product.category.name)],
  };
}

const startsAnyWord = (words: string[], token: string): boolean =>
  words.some((word) => word.startsWith(token));

/**
 * Matching rule (see DECISIONS.md):
 * - every token in the term must match (AND), so adding words narrows results;
 * - a token matches when it is the *start of a word* in the title, description
 *   or category. Plain substring matching was rejected because "men" would then
 *   match "women's clothing".
 * Results are ordered by how many tokens hit the title, then by customer rating.
 */
export function searchProducts(products: readonly Product[], term: string): Product[] {
  const tokens = tokenizeSearchTerm(term);
  if (tokens.length === 0) return [];

  return products
    .map((product) => ({ product, text: searchableText(product) }))
    .filter(({ text }) => tokens.every((token) => startsAnyWord(text.allWords, token)))
    .map(({ product, text }) => ({
      product,
      titleHits: tokens.filter((token) => startsAnyWord(text.titleWords, token)).length,
    }))
    .sort((a, b) => b.titleHits - a.titleHits || compareByCustomerRating(a.product, b.product))
    .map(({ product }) => product);
}

import type { Category } from './product.js';

/**
 * Builds a URL-safe slug from a free-text category name.
 * "men's clothing" -> "mens-clothing". Apostrophes are dropped (not turned into
 * hyphens) so possessives read naturally.
 */
export function slugify(name: string): string {
  return name
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/['’]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/** "men's clothing" -> "Men's Clothing" */
export function toDisplayName(name: string): string {
  return name
    .trim()
    .split(/\s+/)
    .map((word) => (word.length === 0 ? word : word[0]!.toUpperCase() + word.slice(1)))
    .join(' ');
}

export function categoryFromSourceName(sourceName: string): Category {
  return { slug: slugify(sourceName), name: toDisplayName(sourceName) };
}

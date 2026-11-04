import { describe, expect, it } from 'vitest';
import { categoryFromSourceName, slugify } from '../../src/domain/category.js';

describe('category naming', () => {
  it.each([
    ["men's clothing", 'mens-clothing'],
    ['  Home & Garden ', 'home-garden'],
    ['Électronique', 'electronique'],
    ['jewelery', 'jewelery'],
  ])('slugifies %j as %j', (input, expected) => {
    expect(slugify(input)).toBe(expected);
  });

  it('builds a display name and slug from the source name', () => {
    expect(categoryFromSourceName("women's clothing")).toEqual({ slug: 'womens-clothing', name: "Women's Clothing" });
  });
});

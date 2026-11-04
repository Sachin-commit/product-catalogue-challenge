import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { InMemoryProductRepository } from '../../src/adapters/in-memory/in-memory-product-repository.js';
import { UpstreamUnavailableError } from '../../src/domain/errors.js';
import type { ProductDto } from '../../src/http/presenters.js';
import { createTestApp } from '../support/fixtures.js';

const ids = (products: ProductDto[]) => products.map((product) => product.id);

describe('GET /api/v1/featured (home page)', () => {
  it("returns the owner's 5 chosen products in order", async () => {
    const { app } = createTestApp({ featuredIds: ['3', '5', '11', '17', '1'] });
    const res = await request(app).get('/api/v1/featured').expect(200);

    expect(ids(res.body.products)).toEqual(['3', '5', '11', '17', '1']);
    expect(res.body.products[0]).toEqual({
      id: '3',
      title: 'Mens Cotton Jacket',
      description: expect.any(String),
      category: { slug: 'mens-clothing', name: "Men's Clothing" },
      price: { amountMinor: 5599, currency: 'USD' },
      // Served by our API, never by the data source.
      imageUrl: expect.stringMatching(/^http:\/\/127\.0\.0\.1:\d+\/api\/v1\/products\/3\/image$/),
      rating: { average: 4.7, count: 500 },
    });
  });

  it('still shows 5 products if a chosen product has been removed from the source', async () => {
    const { app } = createTestApp({ featuredIds: ['3', '5', '11', '17', 'deleted'] });
    const res = await request(app).get('/api/v1/featured').expect(200);
    expect(res.body.products).toHaveLength(5);
    expect(ids(res.body.products).slice(0, 4)).toEqual(['3', '5', '11', '17']);
  });
});

describe('GET /api/v1/categories', () => {
  it('lists every category with a slug for linking', async () => {
    const { app } = createTestApp();
    const res = await request(app).get('/api/v1/categories').expect(200);
    expect(res.body.categories).toEqual([
      { slug: 'electronics', name: 'Electronics' },
      { slug: 'jewelery', name: 'Jewelery' },
      { slug: 'mens-clothing', name: "Men's Clothing" },
      { slug: 'womens-clothing', name: "Women's Clothing" },
    ]);
  });
});

describe('GET /api/v1/categories/:slug/products (category page)', () => {
  it('returns top rated products and additional products for the category only', async () => {
    const { app } = createTestApp({ featuredIds: ['17'] });
    const res = await request(app).get('/api/v1/categories/womens-clothing/products').expect(200);

    expect(res.body.category).toEqual({ slug: 'womens-clothing', name: "Women's Clothing" });
    // 17 is the owner's pick so it leads, then the best customer-rated: 18 (4.7), 19 (4.5).
    expect(ids(res.body.topRated)).toEqual(['17', '18', '19']);
    expect(res.body.more.length).toBeGreaterThan(0);

    const all: ProductDto[] = [...res.body.topRated, ...res.body.more];
    expect(all).toHaveLength(6);
    expect(all.every((product) => product.category.slug === 'womens-clothing')).toBe(true);
  });

  it('404s for an unknown category', async () => {
    const { app } = createTestApp();
    const res = await request(app).get('/api/v1/categories/garden/products').expect(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('400s for a malformed slug', async () => {
    const { app } = createTestApp();
    await request(app).get('/api/v1/categories/Not%20A%20Slug/products').expect(400);
  });
});

describe('GET /api/v1/products?search= (search)', () => {
  it('returns only products matching the term', async () => {
    const { app } = createTestApp();
    const res = await request(app).get('/api/v1/products').query({ search: 'backpack' }).expect(200);
    expect(res.body.query).toBe('backpack');
    expect(ids(res.body.products)).toEqual(['1']);
  });

  it('returns an empty list, not an error, when nothing matches', async () => {
    const { app } = createTestApp();
    const res = await request(app).get('/api/v1/products').query({ search: 'zzzz' }).expect(200);
    expect(res.body.products).toEqual([]);
  });

  it.each([
    ['missing', {}],
    ['blank', { search: '   ' }],
    ['too long', { search: 'x'.repeat(101) }],
    ['repeated', 'search=a&search=b'],
  ])('rejects a %s search term with a field error', async (_label, query) => {
    const { app } = createTestApp();
    const res = await request(app).get('/api/v1/products').query(query).expect(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
    expect(res.body.error.details[0].field).toBe('search');
  });
});

describe('GET /api/v1/products/:id (product page)', () => {
  it('returns the product details', async () => {
    const { app } = createTestApp();
    const res = await request(app).get('/api/v1/products/5').expect(200);
    expect(res.body.title).toContain('John Hardy');
    expect(res.body.price).toEqual({ amountMinor: 69500, currency: 'USD' });
  });

  it('404s for an unknown product', async () => {
    const { app } = createTestApp();
    const res = await request(app).get('/api/v1/products/999').expect(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('400s for an id that could never be valid', async () => {
    const { app } = createTestApp();
    await request(app).get('/api/v1/products/%3Cscript%3E').expect(400);
  });
});

describe('GET /api/v1/products/:id/image (images go through our API)', () => {
  it("streams the product's image from the data source with long-lived caching", async () => {
    const { app, images } = createTestApp();

    const res = await request(app).get('/api/v1/products/3/image').expect(200);

    expect(res.headers['content-type']).toBe('image/png');
    expect(res.headers['cache-control']).toBe('public, max-age=86400');
    expect(images.requested).toEqual(['https://fakestoreapi.com/img/71li-ujtlUL._AC_UX679_t.png']);
  });

  it('404s for an unknown product without fetching anything', async () => {
    const { app, images } = createTestApp();
    await request(app).get('/api/v1/products/999/image').expect(404);
    expect(images.requested).toEqual([]);
  });

  it('502s when the image source fails', async () => {
    const { app, images } = createTestApp();
    images.failWith = new UpstreamUnavailableError('timeout');
    const res = await request(app).get('/api/v1/products/3/image').expect(502);
    expect(res.body.error.code).toBe('UPSTREAM_UNAVAILABLE');
  });

  it('uses PUBLIC_BASE_URL for image links when configured', async () => {
    const { app } = createTestApp({ publicBaseUrl: 'https://api.shop.example' });
    const res = await request(app).get('/api/v1/products/3').expect(200);
    expect(res.body.imageUrl).toBe('https://api.shop.example/api/v1/products/3/image');
  });

  it('never exposes a data-source URL in any product response', async () => {
    const { app } = createTestApp();
    const responses = await Promise.all([
      request(app).get('/api/v1/featured'),
      request(app).get('/api/v1/categories/electronics/products'),
      request(app).get('/api/v1/products').query({ search: 'jacket' }),
      request(app).get('/api/v1/products/1'),
    ]);
    for (const res of responses) {
      expect(JSON.stringify(res.body)).not.toContain('fakestoreapi.com');
    }
  });
});

describe('when the product source is down', () => {
  it('returns 502 with a customer-safe message and a request id', async () => {
    const failing = new InMemoryProductRepository(async () => {
      throw new UpstreamUnavailableError('connect ECONNREFUSED 10.0.0.1:443');
    });
    const { app } = createTestApp({ products: failing });

    const res = await request(app).get('/api/v1/featured').expect(502);
    expect(res.body.error.code).toBe('UPSTREAM_UNAVAILABLE');
    expect(res.body.error.message).not.toContain('ECONNREFUSED');
    expect(res.body.error.requestId).toBe(res.headers['x-request-id']);
  });
});

describe('cross-cutting HTTP behaviour', () => {
  it('serves a health check', async () => {
    const { app } = createTestApp();
    await request(app).get('/health').expect(200, { status: 'ok' });
  });

  it('returns JSON 404s for unknown routes', async () => {
    const { app } = createTestApp();
    const res = await request(app).get('/api/v1/nope').expect(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('sets security headers and hides the framework', async () => {
    const { app } = createTestApp();
    const res = await request(app).get('/health');
    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  it('echoes a well-formed incoming request id and replaces a malformed one', async () => {
    const { app } = createTestApp();
    const good = await request(app).get('/health').set('X-Request-Id', 'abc-123');
    expect(good.headers['x-request-id']).toBe('abc-123');
    const bad = await request(app).get('/health').set('X-Request-Id', 'evil\tvalue with spaces');
    expect(bad.headers['x-request-id']).not.toBe('evil\tvalue with spaces');
  });
});

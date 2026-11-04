import { describe, expect, it, vi } from 'vitest';
import { createFakeStoreApiLoader, createFakeStoreSnapshotLoader } from '../../src/adapters/fakestore/fakestore-loaders.js';
import { mapFakeStoreCatalogue } from '../../src/adapters/fakestore/fakestore-mapper.js';
import { UpstreamUnavailableError } from '../../src/domain/errors.js';
import { SNAPSHOT_PATH, silentLogger } from '../support/fixtures.js';

const rawProduct = {
  id: 1,
  title: 'Backpack ',
  price: 109.95,
  description: ' Your perfect pack ',
  category: "men's clothing",
  image: 'https://fakestoreapi.com/img/backpack.png',
  rating: { rate: 3.9, count: 120 },
};

const respond = (body: string, status = 200) =>
  vi.fn<typeof fetch>().mockResolvedValue(new Response(body, { status }));

const loader = (fetchFn: typeof fetch) =>
  createFakeStoreApiLoader({ baseUrl: 'https://fake.test', timeoutMs: 1000, logger: silentLogger, fetch: fetchFn });

describe('mapFakeStoreCatalogue', () => {
  it('maps Fake Store fields into our domain model', () => {
    expect(mapFakeStoreCatalogue([rawProduct], silentLogger)).toEqual([
      {
        id: '1',
        title: 'Backpack',
        description: 'Your perfect pack',
        category: { slug: 'mens-clothing', name: "Men's Clothing" },
        price: { amountMinor: 10995, currency: 'USD' },
        sourceImageUrl: 'https://fakestoreapi.com/img/backpack.png',
        rating: { average: 3.9, count: 120 },
      },
    ]);
  });

  it('converts prices to minor units without floating point drift', () => {
    const [product] = mapFakeStoreCatalogue([{ ...rawProduct, price: 0.1 + 0.2 }], silentLogger);
    expect(product?.price.amountMinor).toBe(30);
  });

  it('skips malformed items instead of failing the whole catalogue', () => {
    const products = mapFakeStoreCatalogue([rawProduct, { id: 'oops' }, { ...rawProduct, id: 2, image: 'not a url' }], silentLogger);
    expect(products.map((product) => product.id)).toEqual(['1']);
  });

  it('treats a missing rating as null rather than zero', () => {
    const { rating: _rating, ...unrated } = rawProduct;
    expect(mapFakeStoreCatalogue([unrated], silentLogger)[0]?.rating).toBeNull();
  });

  it('rejects a payload that is not a list', () => {
    expect(() => mapFakeStoreCatalogue({ products: [] }, silentLogger)).toThrow();
  });
});

describe('createFakeStoreApiLoader', () => {
  it('requests /products on the configured base URL', async () => {
    const fetchFn = respond(JSON.stringify([rawProduct]));
    await expect(loader(fetchFn)()).resolves.toHaveLength(1);
    expect(String(fetchFn.mock.calls[0]?.[0])).toBe('https://fake.test/products');
  });

  it.each([
    ['a network failure', vi.fn<typeof fetch>().mockRejectedValue(new TypeError('fetch failed'))],
    ['a timeout', vi.fn<typeof fetch>().mockRejectedValue(new DOMException('timed out', 'TimeoutError'))],
    ['an HTTP 500', respond('oops', 500)],
    // Fake Store answers 200 with an empty body for things it does not have.
    ['a 200 with an empty body', respond('')],
    ['invalid JSON', respond('<html>')],
    ['a non-list payload', respond('{"message":"rate limited"}')],
  ])('turns %s into UpstreamUnavailableError', async (_label, fetchFn) => {
    await expect(loader(fetchFn)()).rejects.toBeInstanceOf(UpstreamUnavailableError);
  });
});

describe('createFakeStoreSnapshotLoader', () => {
  it('loads the recorded catalogue: 20 products in 4 categories', async () => {
    const products = await createFakeStoreSnapshotLoader(SNAPSHOT_PATH, silentLogger)();
    expect(products).toHaveLength(20);
    expect(new Set(products.map((product) => product.category.slug))).toEqual(
      new Set(['mens-clothing', 'womens-clothing', 'jewelery', 'electronics']),
    );
  });
});

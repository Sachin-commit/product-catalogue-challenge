import { describe, expect, it, vi } from 'vitest';
import { HttpImageFetcher } from '../../src/adapters/images/http-image-fetcher.js';
import { UpstreamUnavailableError } from '../../src/domain/errors.js';

const PNG = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);

const respond = (body: ConstructorParameters<typeof Response>[0], init: ResponseInit) =>
  vi.fn<typeof fetch>().mockResolvedValue(new Response(body, init));

const fetcher = (fetchFn: typeof fetch, maxBytes?: number) =>
  new HttpImageFetcher({ timeoutMs: 1000, fetch: fetchFn, maxBytes });

describe('HttpImageFetcher', () => {
  it('returns the image bytes and normalised content type', async () => {
    const fetchFn = respond(PNG, { headers: { 'content-type': 'image/PNG; charset=binary' } });

    const image = await fetcher(fetchFn).fetch('https://fakestoreapi.com/img/1.png');

    expect(image.contentType).toBe('image/png');
    expect([...image.body]).toEqual([...PNG]);
    expect(String(fetchFn.mock.calls[0]?.[0])).toBe('https://fakestoreapi.com/img/1.png');
  });

  it.each([
    ['a network failure', vi.fn<typeof fetch>().mockRejectedValue(new TypeError('fetch failed'))],
    ['an HTTP 404', respond('nope', { status: 404, headers: { 'content-type': 'image/png' } })],
    ['a non-image response', respond('<html>', { headers: { 'content-type': 'text/html' } })],
    ['a response with no content type', respond(PNG, {})],
  ])('turns %s into UpstreamUnavailableError', async (_label, fetchFn) => {
    await expect(fetcher(fetchFn).fetch('https://x.test/a.png')).rejects.toBeInstanceOf(UpstreamUnavailableError);
  });

  it('refuses images over the size limit', async () => {
    const big = respond(new Uint8Array(11), { headers: { 'content-type': 'image/png' } });
    await expect(fetcher(big, 10).fetch('https://x.test/a.png')).rejects.toThrow('too large');
  });

  it('only fetches over http(s)', async () => {
    const fetchFn = vi.fn<typeof fetch>();
    await expect(fetcher(fetchFn).fetch('file:///etc/passwd')).rejects.toBeInstanceOf(UpstreamUnavailableError);
    expect(fetchFn).not.toHaveBeenCalled();
  });
});

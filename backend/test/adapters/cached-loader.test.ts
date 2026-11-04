import { describe, expect, it, vi } from 'vitest';
import { CachedLoader } from '../../src/adapters/in-memory/cached-loader.js';
import { silentLogger } from '../support/fixtures.js';

function setup(load: () => Promise<string>) {
  let now = 0;
  const loader = new CachedLoader(load, silentLogger, {
    ttlMs: 1000,
    retryAfterFailureMs: 100,
    now: () => now,
  });
  return { loader, advance: (ms: number) => (now += ms) };
}

describe('CachedLoader', () => {
  it('reuses the cached value until the TTL expires', async () => {
    const load = vi.fn().mockResolvedValueOnce('v1').mockResolvedValueOnce('v2');
    const { loader, advance } = setup(load);

    expect(await loader.get()).toBe('v1');
    advance(999);
    expect(await loader.get()).toBe('v1');
    advance(1);
    expect(await loader.get()).toBe('v2');
    expect(load).toHaveBeenCalledTimes(2);
  });

  it('shares one in-flight load between concurrent callers', async () => {
    const load = vi.fn().mockResolvedValue('v1');
    const { loader } = setup(load);

    const results = await Promise.all([loader.get(), loader.get(), loader.get()]);
    expect(results).toEqual(['v1', 'v1', 'v1']);
    expect(load).toHaveBeenCalledTimes(1);
  });

  it('serves stale data when a refresh fails, then backs off before retrying', async () => {
    const load = vi
      .fn()
      .mockResolvedValueOnce('v1')
      .mockRejectedValueOnce(new Error('upstream down'))
      .mockResolvedValueOnce('v2');
    const { loader, advance } = setup(load);

    await loader.get();
    advance(1000);
    expect(await loader.get()).toBe('v1');
    advance(50);
    expect(await loader.get()).toBe('v1');
    expect(load).toHaveBeenCalledTimes(2);
    advance(50);
    expect(await loader.get()).toBe('v2');
  });

  it('propagates the error when there is nothing cached, and retries on the next call', async () => {
    const load = vi.fn().mockRejectedValueOnce(new Error('upstream down')).mockResolvedValueOnce('v1');
    const { loader } = setup(load);

    await expect(loader.get()).rejects.toThrow('upstream down');
    expect(await loader.get()).toBe('v1');
  });
});

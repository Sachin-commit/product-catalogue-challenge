import type { Logger } from '../../lib/logger.js';

export interface CachedLoaderOptions {
  readonly ttlMs: number;
  /** After a failed refresh with stale data available, wait this long before trying upstream again. */
  readonly retryAfterFailureMs?: number;
  readonly now?: () => number;
}

/**
 * Caches the result of an expensive async load.
 * - Concurrent callers share one in-flight request (no thundering herd on cold start).
 * - If a refresh fails but we have older data, we serve the stale data and back off,
 *   so a flaky upstream degrades freshness rather than availability.
 * - If there is no data at all, the error propagates.
 */
export class CachedLoader<T> {
  private cached: { value: T; expiresAt: number } | undefined;
  private inFlight: Promise<T> | undefined;
  private readonly now: () => number;
  private readonly retryAfterFailureMs: number;

  constructor(
    private readonly load: () => Promise<T>,
    private readonly logger: Logger,
    private readonly options: CachedLoaderOptions,
  ) {
    this.now = options.now ?? Date.now;
    this.retryAfterFailureMs = options.retryAfterFailureMs ?? 30_000;
  }

  get(): Promise<T> {
    if (this.cached && this.now() < this.cached.expiresAt) {
      return Promise.resolve(this.cached.value);
    }
    this.inFlight ??= this.refresh().finally(() => {
      this.inFlight = undefined;
    });
    return this.inFlight;
  }

  private async refresh(): Promise<T> {
    try {
      const value = await this.load();
      this.cached = { value, expiresAt: this.now() + this.options.ttlMs };
      return value;
    } catch (error) {
      if (!this.cached) throw error;
      this.logger.warn({ err: error }, 'Refresh failed; serving stale data');
      this.cached = { value: this.cached.value, expiresAt: this.now() + this.retryAfterFailureMs };
      return this.cached.value;
    }
  }
}

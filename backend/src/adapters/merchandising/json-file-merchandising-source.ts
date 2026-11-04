import { readFileSync } from 'node:fs';
import { z } from 'zod';
import { isValidProductId } from '../../domain/product.js';
import type { MerchandisingSource } from '../../ports/merchandising-source.js';

const merchandisingFileSchema = z.object({
  featuredProductIds: z
    .array(z.string().refine(isValidProductId, 'Invalid product id'))
    .min(1, 'Choose at least one featured product'),
});

/**
 * Reads the owner's curated picks from a JSON file in the repo.
 * Loaded once at startup so a typo fails the boot loudly instead of
 * breaking the home page later. Changing picks needs a restart; a CMS or
 * admin screen would replace this adapter.
 */
export class JsonFileMerchandisingSource implements MerchandisingSource {
  private readonly featuredProductIds: string[];

  constructor(filePath: string) {
    const parsed = merchandisingFileSchema.safeParse(JSON.parse(readFileSync(filePath, 'utf8')));
    if (!parsed.success) {
      throw new Error(`Invalid merchandising file ${filePath}: ${z.prettifyError(parsed.error)}`);
    }
    this.featuredProductIds = parsed.data.featuredProductIds;
  }

  async getFeaturedProductIds(): Promise<string[]> {
    return [...this.featuredProductIds];
  }
}

/** For tests and for wiring curation from elsewhere (env, DB) without a file. */
export class StaticMerchandisingSource implements MerchandisingSource {
  constructor(private readonly featuredProductIds: readonly string[]) {}

  async getFeaturedProductIds(): Promise<string[]> {
    return [...this.featuredProductIds];
  }
}

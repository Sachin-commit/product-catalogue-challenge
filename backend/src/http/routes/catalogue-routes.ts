import { Router, type Request } from 'express';
import { z } from 'zod';
import { isValidProductId } from '../../domain/product.js';
import { SEARCH_TERM_MAX_LENGTH } from '../../domain/search.js';
import type { CatalogueService } from '../../services/catalogue-service.js';
import { imageUrlBuilder, toCategoryDto, toProductDto, type ImageUrlBuilder } from '../presenters.js';
import { parseRequest } from '../validation.js';

const searchQuerySchema = z.object({
  search: z
    .string({ error: 'Enter a search term' })
    .trim()
    .min(1, 'Enter a search term')
    .max(SEARCH_TERM_MAX_LENGTH, `Search term must be ${SEARCH_TERM_MAX_LENGTH} characters or fewer`),
});

const productParamsSchema = z.object({
  id: z.string().refine(isValidProductId, 'Invalid product id'),
});

const categoryParamsSchema = z.object({
  slug: z.string().regex(/^[a-z0-9-]{1,64}$/, 'Invalid category'),
});

/** Catalogue data changes rarely; let clients and any CDN reuse responses briefly. */
const CACHE_HEADER = 'public, max-age=60';
/** Product images effectively never change for a given id. */
const IMAGE_CACHE_HEADER = 'public, max-age=86400';

export interface CatalogueRouteOptions {
  /**
   * Public origin used to build image URLs (e.g. https://api.example.com).
   * When unset we use the origin the request arrived on, which is right for
   * local use; set it in production so URLs never depend on the Host header.
   */
  readonly publicBaseUrl?: string | undefined;
}

export function catalogueRoutes(catalogue: CatalogueService, options: CatalogueRouteOptions = {}): Router {
  const router = Router();
  const imageUrls = (req: Request): ImageUrlBuilder =>
    imageUrlBuilder(options.publicBaseUrl ?? `${req.protocol}://${req.get('host')}`);

  router.get('/featured', async (req, res) => {
    const products = await catalogue.getFeaturedProducts();
    const toDto = imageUrls(req);
    res.set('Cache-Control', CACHE_HEADER).json({ products: products.map((p) => toProductDto(p, toDto)) });
  });

  router.get('/categories', async (_req, res) => {
    const categories = await catalogue.listCategories();
    res.set('Cache-Control', CACHE_HEADER).json({ categories: categories.map(toCategoryDto) });
  });

  router.get('/categories/:slug/products', async (req, res) => {
    const { slug } = parseRequest(categoryParamsSchema, req.params);
    const listing = await catalogue.getCategoryListing(slug);
    const toDto = imageUrls(req);
    res.set('Cache-Control', CACHE_HEADER).json({
      category: toCategoryDto(listing.category),
      topRated: listing.topRated.map((p) => toProductDto(p, toDto)),
      more: listing.more.map((p) => toProductDto(p, toDto)),
    });
  });

  router.get('/products', async (req, res) => {
    const { search } = parseRequest(searchQuerySchema, req.query);
    const products = await catalogue.search(search);
    const toDto = imageUrls(req);
    res
      .set('Cache-Control', CACHE_HEADER)
      .json({ query: search, products: products.map((p) => toProductDto(p, toDto)) });
  });

  router.get('/products/:id', async (req, res) => {
    const { id } = parseRequest(productParamsSchema, req.params);
    const product = await catalogue.getProduct(id);
    res.set('Cache-Control', CACHE_HEADER).json(toProductDto(product, imageUrls(req)));
  });

  // Images are served through us so the client never talks to the data source.
  router.get('/products/:id/image', async (req, res) => {
    const { id } = parseRequest(productParamsSchema, req.params);
    const image = await catalogue.getProductImage(id);
    res.set('Cache-Control', IMAGE_CACHE_HEADER).type(image.contentType).send(image.body);
  });

  return router;
}

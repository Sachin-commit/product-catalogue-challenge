import { z } from 'zod';

const booleanString = z
  .enum(['true', 'false'])
  .default('false')
  .transform((value) => value === 'true');

/**
 * Every setting the API reads, validated once at startup. Defaults are chosen
 * so `docker compose up` and `npm run dev` work with no .env file; see
 * .env.example for documentation of each value. No secrets have defaults.
 */
const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65_535).default(8080),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  /** Set to true behind a load balancer (e.g. AWS ALB) so rate limiting sees real client IPs. */
  TRUST_PROXY: booleanString,
  /** Public origin for image URLs in responses. Unset locally; set in production. */
  PUBLIC_BASE_URL: z.url().optional(),

  PRODUCT_SOURCE: z.enum(['fakestore-api', 'fakestore-snapshot']).default('fakestore-api'),
  FAKESTORE_BASE_URL: z.url().default('https://fakestoreapi.com'),
  FAKESTORE_SNAPSHOT_FILE: z.string().min(1).default('data/fakestore-products.snapshot.json'),
  UPSTREAM_TIMEOUT_MS: z.coerce.number().int().min(100).max(60_000).default(5_000),
  CATALOGUE_CACHE_TTL_SECONDS: z.coerce.number().int().min(0).max(86_400).default(300),
  MERCHANDISING_FILE: z.string().min(1).default('data/merchandising.json'),

  EMAIL_TRANSPORT: z.enum(['smtp', 'log']).default('smtp'),
  SMTP_HOST: z.string().min(1).default('localhost'),
  SMTP_PORT: z.coerce.number().int().min(1).max(65_535).default(1025),
  SMTP_SECURE: booleanString,
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  MAIL_FROM: z.string().min(3).default('Product Catalogue <no-reply@catalogue.local>'),
  SALES_INBOX: z.email().default('sales@catalogue.local'),

  ENQUIRY_RATE_LIMIT_MAX: z.coerce.number().int().min(1).default(10),
  ENQUIRY_RATE_LIMIT_WINDOW_MINUTES: z.coerce.number().int().min(1).default(15),
});

export type AppConfig = z.infer<typeof envSchema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  // Treat empty strings (e.g. `SMTP_USER=` copied from .env.example) as "not set".
  const cleaned = Object.fromEntries(Object.entries(env).filter(([, value]) => value !== ''));
  const parsed = envSchema.safeParse(cleaned);
  if (!parsed.success) {
    throw new Error(`Invalid configuration:\n${z.prettifyError(parsed.error)}`);
  }
  return parsed.data;
}

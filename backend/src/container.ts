import { resolve } from 'node:path';
import { LogEmailSender } from './adapters/email/log-email-sender.js';
import { SmtpEmailSender } from './adapters/email/smtp-email-sender.js';
import { createFakeStoreApiLoader, createFakeStoreSnapshotLoader } from './adapters/fakestore/fakestore-loaders.js';
import { HttpImageFetcher } from './adapters/images/http-image-fetcher.js';
import { CachedLoader } from './adapters/in-memory/cached-loader.js';
import { InMemoryProductRepository } from './adapters/in-memory/in-memory-product-repository.js';
import { JsonFileMerchandisingSource } from './adapters/merchandising/json-file-merchandising-source.js';
import type { AppDependencies } from './app.js';
import type { AppConfig } from './config/env.js';
import type { Logger } from './lib/logger.js';
import type { EmailSender } from './ports/email-sender.js';
import type { ProductRepository } from './ports/product-repository.js';
import { CatalogueService } from './services/catalogue-service.js';
import { EnquiryService } from './services/enquiry-service.js';

/**
 * Composition root: the single place that decides which adapter backs each port.
 * Swapping the product source or email provider is a change here plus config.
 */
export function buildDependencies(config: AppConfig, logger: Logger): AppDependencies {
  const products = buildProductRepository(config, logger);
  const merchandising = new JsonFileMerchandisingSource(resolve(config.MERCHANDISING_FILE));
  const email = buildEmailSender(config, logger);
  const images = new HttpImageFetcher({ timeoutMs: config.UPSTREAM_TIMEOUT_MS });

  return {
    catalogue: new CatalogueService(products, merchandising, images, logger),
    enquiries: new EnquiryService(products, email, logger, { salesInbox: config.SALES_INBOX }),
    logger,
    trustProxy: config.TRUST_PROXY,
    publicBaseUrl: config.PUBLIC_BASE_URL,
    enquiryRateLimit: {
      max: config.ENQUIRY_RATE_LIMIT_MAX,
      windowMs: config.ENQUIRY_RATE_LIMIT_WINDOW_MINUTES * 60_000,
    },
  };
}

function buildProductRepository(config: AppConfig, logger: Logger): ProductRepository {
  const load =
    config.PRODUCT_SOURCE === 'fakestore-api'
      ? createFakeStoreApiLoader({
          baseUrl: config.FAKESTORE_BASE_URL,
          timeoutMs: config.UPSTREAM_TIMEOUT_MS,
          logger,
        })
      : createFakeStoreSnapshotLoader(resolve(config.FAKESTORE_SNAPSHOT_FILE), logger);

  const cache = new CachedLoader(load, logger, { ttlMs: config.CATALOGUE_CACHE_TTL_SECONDS * 1000 });
  return new InMemoryProductRepository(() => cache.get());
}

function buildEmailSender(config: AppConfig, logger: Logger): EmailSender {
  if (config.EMAIL_TRANSPORT === 'log') return new LogEmailSender(logger);
  return SmtpEmailSender.fromSettings(
    {
      host: config.SMTP_HOST,
      port: config.SMTP_PORT,
      secure: config.SMTP_SECURE,
      user: config.SMTP_USER,
      pass: config.SMTP_PASS,
    },
    config.MAIL_FROM,
  );
}

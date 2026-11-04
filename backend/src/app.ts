import { randomUUID } from 'node:crypto';
import express, { type Express } from 'express';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';
import { errorHandler, notFoundHandler } from './http/middleware/error-handler.js';
import { catalogueRoutes } from './http/routes/catalogue-routes.js';
import { enquiryRoutes } from './http/routes/enquiry-routes.js';
import type { Logger } from './lib/logger.js';
import type { CatalogueService } from './services/catalogue-service.js';
import type { EnquiryService } from './services/enquiry-service.js';

export interface AppDependencies {
  readonly catalogue: CatalogueService;
  readonly enquiries: EnquiryService;
  readonly logger: Logger;
  readonly trustProxy: boolean;
  /** See CatalogueRouteOptions.publicBaseUrl. */
  readonly publicBaseUrl?: string | undefined;
  readonly enquiryRateLimit: { max: number; windowMs: number };
}

/**
 * Builds the Express app from already-constructed services. No I/O happens
 * here, which is what lets the HTTP tests run against in-memory fakes.
 */
export function createApp(deps: AppDependencies): Express {
  const app = express();
  app.set('trust proxy', deps.trustProxy);

  app.use(helmet());
  app.use(
    pinoHttp({
      logger: deps.logger,
      genReqId: (req, res) => {
        const incoming = req.headers['x-request-id'];
        const id = typeof incoming === 'string' && /^[\w-]{1,64}$/.test(incoming) ? incoming : randomUUID();
        res.setHeader('X-Request-Id', id);
        return id;
      },
    }),
  );
  app.use(express.json({ limit: '10kb' }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/api/v1', catalogueRoutes(deps.catalogue, { publicBaseUrl: deps.publicBaseUrl }));
  app.use(
    '/api/v1',
    enquiryRoutes(deps.enquiries, {
      rateLimitMax: deps.enquiryRateLimit.max,
      rateLimitWindowMs: deps.enquiryRateLimit.windowMs,
    }),
  );

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

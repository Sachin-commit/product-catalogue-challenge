import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { enquiryInputSchema } from '../../domain/enquiry.js';
import type { EnquiryService } from '../../services/enquiry-service.js';
import { errorBody } from '../middleware/error-handler.js';
import { parseRequest } from '../validation.js';

export interface EnquiryRouteOptions {
  readonly rateLimitMax: number;
  readonly rateLimitWindowMs: number;
}

export function enquiryRoutes(enquiries: EnquiryService, options: EnquiryRouteOptions): Router {
  const router = Router();

  // Enquiries send real email, so they are the obvious abuse target.
  // In-memory store is per instance; a shared store (Redis/ElastiCache) is needed when scaled out.
  const limiter = rateLimit({
    windowMs: options.rateLimitWindowMs,
    limit: options.rateLimitMax,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler: (req, res) => {
      res
        .status(429)
        .json(errorBody('RATE_LIMITED', 'Too many enquiries. Please try again later.', req.id));
    },
  });

  router.post('/enquiries', limiter, async (req, res) => {
    const input = parseRequest(enquiryInputSchema, req.body ?? {});
    const receipt = await enquiries.submit(input);
    res.status(202).json({ reference: receipt.reference });
  });

  return router;
}

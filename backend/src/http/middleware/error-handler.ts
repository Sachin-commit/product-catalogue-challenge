import type { ErrorRequestHandler, RequestHandler } from 'express';
import { AppError } from '../../domain/errors.js';
import type { FieldError } from '../validation.js';
import { RequestValidationError } from '../validation.js';

/** One error shape for every endpoint, so clients need one decoder. */
export interface ErrorBody {
  error: {
    code: string;
    message: string;
    requestId?: string;
    details?: FieldError[];
  };
}

export function errorBody(code: string, message: string, requestId?: unknown, details?: FieldError[]): ErrorBody {
  return {
    error: {
      code,
      message,
      ...(requestId ? { requestId: String(requestId) } : {}),
      ...(details ? { details } : {}),
    },
  };
}

const STATUS_BY_CODE: Record<string, number> = {
  NOT_FOUND: 404,
  INVALID_REQUEST: 400,
  UPSTREAM_UNAVAILABLE: 502,
  EMAIL_DELIVERY_FAILED: 502,
};

/** Messages safe to show customers. Internal details stay in the logs. */
const PUBLIC_MESSAGE_BY_CODE: Record<string, string> = {
  UPSTREAM_UNAVAILABLE: 'Products are temporarily unavailable. Please try again shortly.',
  EMAIL_DELIVERY_FAILED: 'We could not send your enquiry. Please try again.',
};

export const notFoundHandler: RequestHandler = (req, res) => {
  res.status(404).json(errorBody('NOT_FOUND', `No route for ${req.method} ${req.path}`, req.id));
};

export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  if (err instanceof AppError) {
    const status = STATUS_BY_CODE[err.code] ?? 500;
    if (status >= 500) req.log.error({ err }, 'Request failed');
    const details = err instanceof RequestValidationError ? err.details : undefined;
    const message = PUBLIC_MESSAGE_BY_CODE[err.code] ?? err.message;
    res.status(status).json(errorBody(err.code, message, req.id, details));
    return;
  }

  // Errors raised by Express's own body parser carry a status and a type.
  const bodyParserType = (err as { type?: unknown }).type;
  if (bodyParserType === 'entity.too.large') {
    res.status(413).json(errorBody('PAYLOAD_TOO_LARGE', 'Request body is too large', req.id));
    return;
  }
  if (bodyParserType === 'entity.parse.failed') {
    res.status(400).json(errorBody('INVALID_REQUEST', 'Request body is not valid JSON', req.id));
    return;
  }

  req.log.error({ err }, 'Unhandled error');
  res.status(500).json(errorBody('INTERNAL_ERROR', 'Something went wrong. Please try again.', req.id));
};

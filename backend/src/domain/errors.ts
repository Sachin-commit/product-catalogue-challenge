/**
 * Errors the application understands. The HTTP layer maps each `code` to a
 * status; nothing below the HTTP layer knows about status codes.
 */
export abstract class AppError extends Error {
  abstract readonly code: string;

  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = new.target.name;
  }
}

export class NotFoundError extends AppError {
  readonly code = 'NOT_FOUND';
}

export class InvalidRequestError extends AppError {
  readonly code = 'INVALID_REQUEST';
}

/** The product data source failed, timed out or returned something we could not use. */
export class UpstreamUnavailableError extends AppError {
  readonly code = 'UPSTREAM_UNAVAILABLE';
}

/** The email provider refused or failed to accept the message. */
export class EmailDeliveryError extends AppError {
  readonly code = 'EMAIL_DELIVERY_FAILED';
}

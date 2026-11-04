import type { z } from 'zod';
import { InvalidRequestError } from '../domain/errors.js';

export interface FieldError {
  field: string;
  message: string;
}

export class RequestValidationError extends InvalidRequestError {
  constructor(
    message: string,
    readonly details: FieldError[],
  ) {
    super(message);
  }
}

/** Parses untrusted input or throws a 400 with one message per invalid field. */
export function parseRequest<T extends z.ZodType>(schema: T, input: unknown): z.infer<T> {
  const result = schema.safeParse(input);
  if (result.success) return result.data;

  const details = result.error.issues.map((issue) => ({
    field: issue.path.join('.') || '(root)',
    message: issue.message,
  }));
  throw new RequestValidationError('The request contains invalid fields', details);
}

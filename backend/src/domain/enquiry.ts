import { z } from 'zod';
import type { Product } from './product.js';
import { isValidProductId } from './product.js';

// eslint-disable-next-line no-control-regex
const CONTROL_CHARS = /[\u0000-\u001f\u007f]/;
// Same, but keeps \n and \t so a multi-line message survives.
// eslint-disable-next-line no-control-regex
const CONTROL_CHARS_EXCEPT_NEWLINE_TAB = /[\u0000-\u0008\u000b-\u001f\u007f]/g;

const trimmed = (value: unknown) => (typeof value === 'string' ? value.trim() : value);
const blankToUndefined = (value: unknown) => {
  const result = trimmed(value);
  return result === '' || result === null ? undefined : result;
};

/**
 * What a customer submits. Validation lives in the domain so every entry point
 * (this API today, a web form or queue consumer tomorrow) gets the same rules.
 */
export const enquiryInputSchema = z.object({
  productId: z.string().refine(isValidProductId, 'Unknown product'),
  name: z.preprocess(
    trimmed,
    z
      .string({ error: 'Enter your name' })
      .min(1, 'Enter your name')
      .max(100, 'Name must be 100 characters or fewer')
      .refine((value) => !CONTROL_CHARS.test(value), 'Name contains invalid characters'),
  ),
  email: z.preprocess(
    trimmed,
    z.email({ error: 'Enter a valid email address' }).max(254, 'Email must be 254 characters or fewer'),
  ),
  phone: z.preprocess(
    blankToUndefined,
    z
      .string()
      .regex(/^\+?[0-9 ()-]{6,20}$/, 'Enter a valid phone number')
      .optional(),
  ),
  message: z.preprocess(
    blankToUndefined,
    z
      .string()
      .max(2000, 'Message must be 2000 characters or fewer')
      .transform((value) => value.replace(CONTROL_CHARS_EXCEPT_NEWLINE_TAB, ''))
      .optional(),
  ),
});

export type EnquiryInput = z.infer<typeof enquiryInputSchema>;

export interface EnquiryEmailContent {
  readonly subject: string;
  readonly text: string;
}

/** Defence in depth against header injection: no line breaks in anything that becomes a header. */
export function toHeaderSafe(value: string, maxLength = 150): string {
  return value.replace(/[\r\n]+/g, ' ').trim().slice(0, maxLength);
}

export function composeEnquiryEmail(
  reference: string,
  enquiry: EnquiryInput,
  product: Product,
  formattedPrice: string,
): EnquiryEmailContent {
  const lines = [
    `New enquiry ${reference}`,
    '',
    'Product',
    `  ${product.title}`,
    `  ID: ${product.id}`,
    `  Category: ${product.category.name}`,
    `  Price: ${formattedPrice}`,
    '',
    'Customer',
    `  Name: ${enquiry.name}`,
    `  Email: ${enquiry.email}`,
    `  Phone: ${enquiry.phone ?? 'not provided'}`,
    '',
    'Message',
    enquiry.message ? enquiry.message : '  (no message)',
    '',
    'Reply to this email to respond to the customer directly.',
  ];

  return {
    subject: toHeaderSafe(`Enquiry ${reference}: ${product.title}`),
    text: lines.join('\n'),
  };
}

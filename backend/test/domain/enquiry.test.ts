import { describe, expect, it } from 'vitest';
import { composeEnquiryEmail, enquiryInputSchema, toHeaderSafe } from '../../src/domain/enquiry.js';
import { makeProduct } from '../support/fixtures.js';

const valid = { productId: '3', name: 'Jane Doe', email: 'jane@example.com' };

describe('enquiryInputSchema', () => {
  it('accepts the minimum: product, name and email', () => {
    expect(enquiryInputSchema.parse(valid)).toEqual(valid);
  });

  it('trims input and treats blank optional fields as absent', () => {
    const parsed = enquiryInputSchema.parse({ ...valid, name: '  Jane Doe  ', email: ' jane@example.com ', phone: ' ', message: '' });
    expect(parsed).toEqual(valid);
    expect(parsed.phone).toBeUndefined();
    expect(parsed.message).toBeUndefined();
  });

  it.each([
    ['missing name', { ...valid, name: '' }, 'name'],
    ['whitespace name', { ...valid, name: '   ' }, 'name'],
    ['bad email', { ...valid, email: 'not-an-email' }, 'email'],
    ['missing email', { productId: '3', name: 'Jane' }, 'email'],
    ['bad phone', { ...valid, phone: 'call me' }, 'phone'],
    ['long message', { ...valid, message: 'x'.repeat(2001) }, 'message'],
    ['header injection in name', { ...valid, name: 'Jane\r\nBcc: victim@example.com' }, 'name'],
    ['bad product id', { ...valid, productId: '../etc/passwd' }, 'productId'],
  ])('rejects %s', (_label, input, field) => {
    const result = enquiryInputSchema.safeParse(input);
    expect(result.success).toBe(false);
    expect(result.error?.issues.map((issue) => issue.path.join('.'))).toContain(field);
  });

  it('keeps line breaks in the message but strips other control characters', () => {
    const parsed = enquiryInputSchema.parse({ ...valid, message: 'Line one\nLine two\u0007' });
    expect(parsed.message).toBe('Line one\nLine two');
  });
});

describe('composeEnquiryEmail', () => {
  const product = makeProduct({ id: '3', title: 'Mens Cotton Jacket' });

  it('includes the reference, product and customer details', () => {
    const email = composeEnquiryEmail('ENQ-1', { ...valid, phone: '+65 1234 5678', message: 'Is it waterproof?' }, product, '$55.99');
    expect(email.subject).toBe('Enquiry ENQ-1: Mens Cotton Jacket');
    expect(email.text).toContain('Jane Doe');
    expect(email.text).toContain('jane@example.com');
    expect(email.text).toContain('+65 1234 5678');
    expect(email.text).toContain('Is it waterproof?');
    expect(email.text).toContain('$55.99');
  });

  it('never puts a line break in the subject, even if a product title contains one', () => {
    const email = composeEnquiryEmail('ENQ-1', valid, makeProduct({ id: '9', title: 'Evil\r\nBcc: x@y.z' }), '$1.00');
    expect(email.subject).not.toMatch(/[\r\n]/);
  });

  it('caps header length', () => {
    expect(toHeaderSafe('x'.repeat(500))).toHaveLength(150);
  });
});

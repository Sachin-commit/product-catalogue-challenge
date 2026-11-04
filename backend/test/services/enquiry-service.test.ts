import { describe, expect, it } from 'vitest';
import { InMemoryProductRepository } from '../../src/adapters/in-memory/in-memory-product-repository.js';
import { EmailDeliveryError, NotFoundError } from '../../src/domain/errors.js';
import { EnquiryService, generateEnquiryReference } from '../../src/services/enquiry-service.js';
import { RecordingEmailSender, loadSnapshotCatalogue, silentLogger } from '../support/fixtures.js';

function setup() {
  const catalogue = loadSnapshotCatalogue();
  const email = new RecordingEmailSender();
  const service = new EnquiryService(new InMemoryProductRepository(async () => catalogue), email, silentLogger, {
    salesInbox: 'sales@shop.test',
    generateReference: () => 'ENQ-ABC123',
  });
  return { service, email };
}

const enquiry = { productId: '3', name: 'Jane Doe', email: 'jane@example.com', message: 'Do you have XL?' };

describe('EnquiryService', () => {
  it('emails the sales inbox with the product and customer details and returns a reference', async () => {
    const { service, email } = setup();

    await expect(service.submit(enquiry)).resolves.toEqual({ reference: 'ENQ-ABC123' });

    expect(email.sent).toHaveLength(1);
    const [sent] = email.sent;
    expect(sent?.to).toBe('sales@shop.test');
    expect(sent?.replyTo).toBe('jane@example.com');
    expect(sent?.subject).toBe('Enquiry ENQ-ABC123: Mens Cotton Jacket');
    expect(sent?.text).toContain('$55.99');
    expect(sent?.text).toContain('Do you have XL?');
  });

  it('rejects enquiries for products that do not exist, without sending email', async () => {
    const { service, email } = setup();
    await expect(service.submit({ ...enquiry, productId: '999' })).rejects.toBeInstanceOf(NotFoundError);
    expect(email.sent).toHaveLength(0);
  });

  it('surfaces email provider failures so the customer is not told "thank you" for a lost enquiry', async () => {
    const { service, email } = setup();
    email.failWith = new EmailDeliveryError('smtp down');
    await expect(service.submit(enquiry)).rejects.toBeInstanceOf(EmailDeliveryError);
  });
});

describe('generateEnquiryReference', () => {
  it('produces short, readable, distinct references', () => {
    const a = generateEnquiryReference();
    expect(a).toMatch(/^ENQ-[0-9A-F]{8}$/);
    expect(generateEnquiryReference()).not.toBe(a);
  });
});

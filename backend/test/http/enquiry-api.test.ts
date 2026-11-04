import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { EmailDeliveryError } from '../../src/domain/errors.js';
import { RecordingEmailSender, SALES_INBOX, createTestApp } from '../support/fixtures.js';

const validEnquiry = {
  productId: '3',
  name: 'Jane Doe',
  email: 'jane@example.com',
  phone: '+65 9123 4567',
  message: 'Do you ship to Singapore?',
};

describe('POST /api/v1/enquiries', () => {
  it('emails the sales inbox and returns a reference for the thank-you screen', async () => {
    const { app, email } = createTestApp();

    const res = await request(app).post('/api/v1/enquiries').send(validEnquiry).expect(202);

    expect(res.body).toEqual({ reference: 'ENQ-TEST0001' });
    expect(email.sent).toHaveLength(1);
    expect(email.sent[0]).toMatchObject({ to: SALES_INBOX, replyTo: 'jane@example.com' });
    expect(email.sent[0]?.text).toContain('Do you ship to Singapore?');
  });

  it('accepts an enquiry with only the required fields', async () => {
    const { app } = createTestApp();
    await request(app)
      .post('/api/v1/enquiries')
      .send({ productId: '3', name: 'Jane', email: 'jane@example.com' })
      .expect(202);
  });

  it('returns one error per invalid field and sends nothing', async () => {
    const { app, email } = createTestApp();

    const res = await request(app)
      .post('/api/v1/enquiries')
      .send({ productId: '3', name: '', email: 'nope' })
      .expect(400);

    expect(res.body.error.code).toBe('INVALID_REQUEST');
    expect(res.body.error.details.map((detail: { field: string }) => detail.field).sort()).toEqual(['email', 'name']);
    expect(email.sent).toHaveLength(0);
  });

  it('404s when the product does not exist', async () => {
    const { app, email } = createTestApp();
    await request(app).post('/api/v1/enquiries').send({ ...validEnquiry, productId: '999' }).expect(404);
    expect(email.sent).toHaveLength(0);
  });

  it('502s with a retryable message when the email provider fails', async () => {
    const email = new RecordingEmailSender();
    email.failWith = new EmailDeliveryError('535 auth failed');
    const { app } = createTestApp({ email });

    const res = await request(app).post('/api/v1/enquiries').send(validEnquiry).expect(502);
    expect(res.body.error.code).toBe('EMAIL_DELIVERY_FAILED');
    expect(res.body.error.message).toBe('We could not send your enquiry. Please try again.');
  });

  it('rejects malformed JSON and oversized bodies', async () => {
    const { app } = createTestApp();
    await request(app).post('/api/v1/enquiries').set('Content-Type', 'application/json').send('{"name":').expect(400);
    await request(app)
      .post('/api/v1/enquiries')
      .send({ ...validEnquiry, message: 'x'.repeat(20_000) })
      .expect(413);
  });

  it('rate limits repeated submissions from the same client', async () => {
    const { app, email } = createTestApp({ rateLimitMax: 2 });

    await request(app).post('/api/v1/enquiries').send(validEnquiry).expect(202);
    await request(app).post('/api/v1/enquiries').send(validEnquiry).expect(202);
    const res = await request(app).post('/api/v1/enquiries').send(validEnquiry).expect(429);

    expect(res.body.error.code).toBe('RATE_LIMITED');
    expect(email.sent).toHaveLength(2);
  });
});

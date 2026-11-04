import type { SendMailOptions, Transporter } from 'nodemailer';
import { describe, expect, it } from 'vitest';
import { SmtpEmailSender } from '../../src/adapters/email/smtp-email-sender.js';
import { EmailDeliveryError } from '../../src/domain/errors.js';

function fakeTransporter(sendMail: (mail: SendMailOptions) => Promise<unknown>): Transporter {
  return { sendMail } as unknown as Transporter;
}

describe('SmtpEmailSender', () => {
  it('sends from the configured address, to the recipient, with reply-to set to the customer', async () => {
    const sent: SendMailOptions[] = [];
    const transporter = fakeTransporter(async (mail) => sent.push(mail));

    await new SmtpEmailSender(transporter, 'Catalogue <no-reply@shop.test>').send({
      to: 'sales@shop.test',
      replyTo: 'jane@example.com',
      subject: 'Enquiry ENQ-1: Jacket',
      text: 'Hello',
    });

    expect(sent).toEqual([
      {
        from: 'Catalogue <no-reply@shop.test>',
        to: 'sales@shop.test',
        replyTo: 'jane@example.com',
        subject: 'Enquiry ENQ-1: Jacket',
        text: 'Hello',
      },
    ]);
  });

  it('wraps provider failures in EmailDeliveryError, keeping the cause for the logs', async () => {
    const cause = new Error('ECONNREFUSED');
    const sender = new SmtpEmailSender(
      fakeTransporter(async () => Promise.reject(cause)),
      'no-reply@shop.test',
    );

    const error = await sender.send({ to: 'a@b.c', subject: 's', text: 't' }).catch((e: unknown) => e);
    expect(error).toBeInstanceOf(EmailDeliveryError);
    expect((error as Error).cause).toBe(cause);
  });
});

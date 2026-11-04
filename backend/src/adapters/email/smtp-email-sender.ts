import nodemailer, { type Transporter } from 'nodemailer';
import { EmailDeliveryError } from '../../domain/errors.js';
import type { EmailSender, OutboundEmail } from '../../ports/email-sender.js';

export interface SmtpSettings {
  readonly host: string;
  readonly port: number;
  readonly secure: boolean;
  readonly user?: string | undefined;
  readonly pass?: string | undefined;
}

/**
 * Sends through any SMTP server. Locally that is Mailpit (a fake inbox with a
 * web UI); in production the same adapter can point at the AWS SES SMTP
 * endpoint, so switching provider is configuration, not code.
 */
export class SmtpEmailSender implements EmailSender {
  constructor(
    private readonly transporter: Transporter,
    private readonly from: string,
  ) {}

  static fromSettings(settings: SmtpSettings, from: string): SmtpEmailSender {
    const transporter = nodemailer.createTransport({
      host: settings.host,
      port: settings.port,
      secure: settings.secure,
      auth: settings.user ? { user: settings.user, pass: settings.pass ?? '' } : undefined,
      connectionTimeout: 10_000,
      greetingTimeout: 10_000,
      socketTimeout: 15_000,
    });
    return new SmtpEmailSender(transporter, from);
  }

  async send(email: OutboundEmail): Promise<void> {
    try {
      await this.transporter.sendMail({
        from: this.from,
        to: email.to,
        replyTo: email.replyTo,
        subject: email.subject,
        text: email.text,
      });
    } catch (error) {
      throw new EmailDeliveryError('Email provider did not accept the message', { cause: error });
    }
  }
}

import type { Logger } from '../../lib/logger.js';
import type { EmailSender, OutboundEmail } from '../../ports/email-sender.js';

/**
 * Writes the email to the log instead of sending it (EMAIL_TRANSPORT=log).
 * Useful for running the API without Docker or a mail server. Only the
 * envelope is logged at info level; the body (which contains customer
 * details) only appears at debug level.
 */
export class LogEmailSender implements EmailSender {
  constructor(private readonly logger: Logger) {}

  async send(email: OutboundEmail): Promise<void> {
    this.logger.info({ to: email.to, subject: email.subject }, 'Email (log transport, not sent)');
    this.logger.debug({ text: email.text }, 'Email body');
  }
}

/**
 * Provider-neutral outbound email. Adapters: SMTP (Mailpit locally, or the
 * AWS SES SMTP endpoint in production) and a log-only sender for running
 * without any mail server. An SES API or SendGrid adapter would implement this too.
 */
export interface OutboundEmail {
  readonly to: string;
  readonly replyTo?: string;
  readonly subject: string;
  /** Plain text only for now: no HTML means no HTML-injection surface. */
  readonly text: string;
}

export interface EmailSender {
  /** Resolves once the provider has accepted the message; rejects otherwise. */
  send(email: OutboundEmail): Promise<void>;
}

import { pino, type Logger } from 'pino';

export type { Logger };

export function createLogger(level: string): Logger {
  return pino({
    level,
    // Defence in depth: even if someone logs a whole request body, these never reach the logs.
    redact: {
      paths: ['req.headers.authorization', 'req.headers.cookie', '*.email', '*.phone', '*.message'],
      censor: '[redacted]',
    },
  });
}

/** "jane.doe@example.com" -> "j***@example.com", for correlating logs without storing PII. */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf('@');
  if (at <= 0) return '***';
  return `${email[0]}***${email.slice(at)}`;
}

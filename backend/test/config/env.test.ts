import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../src/config/env.js';

describe('loadConfig', () => {
  it('works with no environment at all (local defaults)', () => {
    const config = loadConfig({});
    expect(config.PORT).toBe(8080);
    expect(config.PRODUCT_SOURCE).toBe('fakestore-api');
    expect(config.EMAIL_TRANSPORT).toBe('smtp');
    expect(config.SMTP_SECURE).toBe(false);
  });

  it('coerces numbers and booleans from strings', () => {
    const config = loadConfig({ PORT: '9000', SMTP_SECURE: 'true', TRUST_PROXY: 'true' });
    expect(config.PORT).toBe(9000);
    expect(config.SMTP_SECURE).toBe(true);
    expect(config.TRUST_PROXY).toBe(true);
  });

  it('treats empty values as unset', () => {
    expect(loadConfig({ SMTP_USER: '', PORT: '' }).SMTP_USER).toBeUndefined();
  });

  it('fails fast with a readable message on bad values', () => {
    expect(() => loadConfig({ SALES_INBOX: 'not-an-email' })).toThrow(/SALES_INBOX/);
    expect(() => loadConfig({ PRODUCT_SOURCE: 'mysql' })).toThrow(/PRODUCT_SOURCE/);
  });
});

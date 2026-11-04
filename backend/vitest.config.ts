import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    environment: 'node',
    // Tests must never reach the real network or a real SMTP server.
    // Every outbound dependency is injected and faked.
    restoreMocks: true,
  },
});

import { existsSync } from 'node:fs';
import { createApp } from './app.js';
import { loadConfig } from './config/env.js';
import { buildDependencies } from './container.js';
import { createLogger } from './lib/logger.js';

// Local convenience only; in Docker/AWS the environment is injected directly.
if (existsSync('.env')) process.loadEnvFile('.env');

const config = loadConfig();
const logger = createLogger(config.LOG_LEVEL);
const app = createApp(buildDependencies(config, logger));

const server = app.listen(config.PORT, () => {
  logger.info(
    { port: config.PORT, productSource: config.PRODUCT_SOURCE, emailTransport: config.EMAIL_TRANSPORT },
    'Catalogue API listening',
  );
});

function shutdown(signal: string): void {
  logger.info({ signal }, 'Shutting down');
  server.close(() => process.exit(0));
  // Don't hang forever on keep-alive connections.
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

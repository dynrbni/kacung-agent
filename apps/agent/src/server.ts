import { LoflyAgentApp } from './app.js';
import { getConfig } from '@lofly/config';

async function bootstrap() {
  const config = getConfig();
  const app = new LoflyAgentApp({ config });

  await app.listen(config.server.port, config.server.host);

  const shutdown = async (signal: string) => {
    console.log(`\nReceived ${signal}, shutting down Lofly Agent Server gracefully...`);
    await app.close();
    process.exit(0);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

bootstrap().catch((err) => {
  console.error('Fatal error starting Lofly Agent Server:', err);
  process.exit(1);
});

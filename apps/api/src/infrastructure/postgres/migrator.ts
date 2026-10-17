// infrastructure/postgres/migrator.ts
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { withTransaction } from '../../shared/infrastructure/postgres/connection.js';
import { logger } from '../../shared/infrastructure/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function runMigrations(): Promise<void> {
  logger.info('Starting database migrations...');
  await withTransaction(async (client) => {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    const migrationsDir = path.resolve(__dirname, '../../../migrations');
    if (!fs.existsSync(migrationsDir)) {
      logger.warn(`Migrations directory not found at: ${migrationsDir}`);
      return;
    }

    const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
    
    const res = await client.query('SELECT version FROM schema_migrations');
    const applied = new Set(res.rows.map((r: any) => r.version));

    for (const file of files) {
      if (applied.has(file)) {
        logger.debug(`Migration ${file} already applied.`);
        continue;
      }

      logger.info(`Applying migration: ${file}`);
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
      logger.info(`Successfully applied migration: ${file}`);
    }
  });
  logger.info('Database migrations completed successfully.');
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  runMigrations()
    .then(() => {
      console.log('Migrations finished.');
      process.exit(0);
    })
    .catch((err) => {
      console.error('Migration failed:', err);
      process.exit(1);
    });
}

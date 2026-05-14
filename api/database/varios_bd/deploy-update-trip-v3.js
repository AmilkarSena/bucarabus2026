// Deploy fun_update_trip_v3.sql
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config({ path: join(dirname(fileURLToPath(import.meta.url)), '..', '.env') });

const { Pool } = pg;
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'db_newBucarabus',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres'
});

async function deploy() {
  const client = await pool.connect();
  const __dirname = dirname(fileURLToPath(import.meta.url));
  try {
    console.log('📤 Desplegando fun_update_trip_v3.sql...');
    const sql = readFileSync(join(__dirname, 'fun_update_trip_v3.sql'), 'utf8');
    await client.query(sql);
    console.log('✅ fun_update_trip (v3) desplegada exitosamente');
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

deploy();

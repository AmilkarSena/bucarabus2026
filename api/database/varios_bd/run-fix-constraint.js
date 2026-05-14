// =============================================
// Ejecutar fix de constraint UNIQUE
// =============================================

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

async function fixConstraint() {
  const client = await pool.connect();
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  
  try {
    console.log('🔧 Corrigiendo constraint UNIQUE...\n');
    
    const sql = readFileSync(join(__dirname, 'fix-unique-constraint.sql'), 'utf8');
    const result = await client.query(sql);
    
    console.log('✅ Constraint migrada exitosamente de UNIQUE a índice filtrado\n');
    console.log('Cambios aplicados:');
    console.log('  • Eliminada: uq_trips_route_datetime (aplicaba a TODOS los viajes)');
    console.log('  • Creada: uq_trips_route_datetime_active (solo viajes con is_active=TRUE)');
    console.log('  • Resultado: Ahora puedes crear viajes en horarios de viajes cancelados\n');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

fixConstraint()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ Operación fallida:', error);
    process.exit(1);
  });

// =============================================
// Deploy trip creation functions v3 (sin validación secuencial global)
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

async function deployFunctions() {
  const client = await pool.connect();
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  
  try {
    console.log('🚌 BucaraBus - Desplegando funciones de creación v3...\n');
    
    // 1. Desplegar fun_create_trip_v3.sql
    console.log('📤 Desplegando fun_create_trip_v3.sql...');
    const createTripSQL = readFileSync(join(__dirname, 'fun_create_trip_v3.sql'), 'utf8');
    await client.query(createTripSQL);
    console.log('✅ fun_create_trip desplegada\n');
    
    // 2. Desplegar fun_create_trips_batch_v3.sql
    console.log('📤 Desplegando fun_create_trips_batch_v3.sql...');
    const createTripsBatchSQL = readFileSync(join(__dirname, 'fun_create_trips_batch_v3.sql'), 'utf8');
    await client.query(createTripsBatchSQL);
    console.log('✅ fun_create_trips_batch desplegada\n');
    
    console.log('═'.repeat(60));
    console.log('✅ FUNCIONES DESPLEGADAS EXITOSAMENTE');
    console.log('═'.repeat(60));
    console.log('Cambios aplicados:');
    console.log('  • Eliminada validación de orden secuencial global');
    console.log('  • Ahora permite crear viajes en cualquier horario');
    console.log('  • Solo valida:');
    console.log('    - No duplicados activos (is_active=TRUE)');
    console.log('    - end_time > start_time');
    console.log('    - Secuencia dentro del batch (batch only)');
    console.log('═'.repeat(60));
    
  } catch (error) {
    console.error('❌ Error al desplegar funciones:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

deployFunctions()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ Despliegue fallido:', error);
    process.exit(1);
  });

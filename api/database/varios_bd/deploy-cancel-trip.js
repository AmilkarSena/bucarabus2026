// =============================================
// Deploy fun_cancel_trip_v3.sql
// =============================================

import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config({ path: join(dirname(fileURLToPath(import.meta.url)), '..', '.env') });

const { Pool } = pg;

// Obtener directorio actual (ESM)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuración de la base de datos (usar misma config que la app)
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'db_newBucarabus',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres'
});

async function deployFunction() {
  const client = await pool.connect();
  
  try {
    console.log('🚌 BucaraBus - Desplegando fun_cancel_trip_v3...\n');
    
    // Leer archivo SQL
    const sqlFile = join(__dirname, 'fun_cancel_trip_v3.sql');
    const sql = readFileSync(sqlFile, 'utf8');
    
    console.log('📤 Ejecutando SQL...');
    
    // Ejecutar SQL
    await client.query(sql);
    
    console.log('✅ Funciones desplegadas exitosamente!');
    console.log('   • fun_cancel_trip');
    console.log('   • fun_cancel_trips_batch');
    
  } catch (error) {
    console.error('❌ Error al desplegar funciones:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

deployFunction()
  .then(() => {
    console.log('\n✅ Despliegue completado');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Despliegue fallido:', error);
    process.exit(1);
  });

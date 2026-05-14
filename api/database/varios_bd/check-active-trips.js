// =============================================
// Verificar viajes activos vs cancelados
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

async function checkActiveTrips() {
  const client = await pool.connect();
  
  try {
    console.log('🔍 Verificando viajes activos vs cancelados...\n');
    
    // Pedir datos al usuario (o usar valores por defecto)
    const id_route = process.argv[2] || 1; // Primer argumento: id_route
    const trip_date = process.argv[3] || new Date().toISOString().split('T')[0]; // Segundo: fecha
    
    console.log(`📍 Ruta: ${id_route}`);
    console.log(`📅 Fecha: ${trip_date}\n`);
    
    // Consultar TODOS los viajes (activos e inactivos)
    const queryAll = `
      SELECT 
        id_trip,
        start_time,
        end_time,
        id_status AS status_trip,
        is_active,
        plate_number,
        id_user,
        CASE 
          WHEN id_status = 1 THEN 'pending'
          WHEN id_status = 2 THEN 'assigned'
          WHEN id_status = 3 THEN 'active'
          WHEN id_status = 4 THEN 'completed'
          WHEN id_status = 5 THEN 'cancelled'
          ELSE 'unknown'
        END as status_name
      FROM tab_trips
      WHERE id_route = $1 AND trip_date = $2
      ORDER BY start_time, id_trip
    `;
    
    const result = await client.query(queryAll, [id_route, trip_date]);
    
    if (result.rows.length === 0) {
      console.log('📭 No hay viajes para esta ruta/fecha');
      return;
    }
    
    console.log('═'.repeat(100));
    console.log(`Total de viajes: ${result.rows.length}`);
    console.log('═'.repeat(100));
    
    const activeTrips = result.rows.filter(r => r.is_active);
    const inactiveTrips = result.rows.filter(r => !r.is_active);
    
    console.log(`\n✅ VIAJES ACTIVOS (is_active = TRUE): ${activeTrips.length}`);
    console.log('─'.repeat(100));
    if (activeTrips.length > 0) {
      activeTrips.forEach(trip => {
        console.log(`  ID: ${trip.id_trip.toString().padEnd(8)} | ` +
                    `${trip.start_time.substring(0,5)} - ${trip.end_time.substring(0,5)} | ` +
                    `Status: ${trip.status_name.padEnd(10)} (${trip.status_trip}) | ` +
                    `Bus: ${trip.plate_number || 'N/A'.padEnd(6)} | ` +
                    `User: ${trip.id_user || 'N/A'}`);
      });
    } else {
      console.log('  (ninguno)');
    }
    
    console.log(`\n❌ VIAJES INACTIVOS (is_active = FALSE): ${inactiveTrips.length}`);
    console.log('─'.repeat(100));
    if (inactiveTrips.length > 0) {
      inactiveTrips.forEach(trip => {
        console.log(`  ID: ${trip.id_trip.toString().padEnd(8)} | ` +
                    `${trip.start_time.substring(0,5)} - ${trip.end_time.substring(0,5)} | ` +
                    `Status: ${trip.status_name.padEnd(10)} (${trip.status_trip}) | ` +
                    `Bus: ${trip.plate_number || 'N/A'.padEnd(6)} | ` +
                    `User: ${trip.id_user || 'N/A'}`);
      });
    } else {
      console.log('  (ninguno)');
    }
    
    // Detectar horarios duplicados
    console.log(`\n⚠️  VERIFICACIÓN DE HORARIOS DUPLICADOS`);
    console.log('─'.repeat(100));
    
    const timeCounts = {};
    activeTrips.forEach(trip => {
      const time = trip.start_time;
      if (!timeCounts[time]) {
        timeCounts[time] = [];
      }
      timeCounts[time].push(trip);
    });
    
    const duplicates = Object.entries(timeCounts).filter(([_, trips]) => trips.length > 1);
    
    if (duplicates.length > 0) {
      console.log('  ❌ ENCONTRADOS VIAJES ACTIVOS CON HORARIOS DUPLICADOS:');
      duplicates.forEach(([time, trips]) => {
        console.log(`    Hora ${time.substring(0,5)} - ${trips.length} viajes:`);
        trips.forEach(trip => {
          console.log(`      - ID ${trip.id_trip} (${trip.status_name})`);
        });
      });
    } else {
      console.log('  ✅ No hay horarios duplicados en viajes activos');
    }
    
    console.log('\n' + '═'.repeat(100));
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

console.log('\n🚌 BucaraBus - Verificación de Viajes\n');
console.log('Uso: node check-active-trips.js [id_route] [fecha_YYYY-MM-DD]');
console.log('Ejemplo: node check-active-trips.js 1 2026-02-21\n');

checkActiveTrips()
  .then(() => {
    console.log('\n✅ Verificación completada');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Verificación fallida:',error.message);
    process.exit(1);
  });

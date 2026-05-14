import pkg from 'pg';
const { Pool } = pkg;

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'db_bucarabus',
  password: '0000',
  port: 5432,
});

async function checkTripsData() {
  try {
    console.log('🔍 Verificando datos de trips en la BD...\n');
    
    // Contar todos los trips
    const countResult = await pool.query("SELECT COUNT(*) FROM tab_trips WHERE id_status != 5");
    console.log('📊 Total de trips activos:', countResult.rows[0].count);
    
    // Ver trips recientes
    const recentTrips = await pool.query(`
      SELECT 
        t.id_trip,
        t.trip_date,
        t.start_time,
        t.end_time,
        t.id_route,
        t.plate_number,
        t.id_status AS status_trip
      FROM tab_trips t
      WHERE id_status != 5
      ORDER BY t.trip_date DESC, t.start_time DESC
      LIMIT 10
    `);
    
    console.log('\n📋 Últimos 10 trips:');
    if (recentTrips.rows.length === 0) {
      console.log('  ❌ No hay trips en la base de datos');
    } else {
      recentTrips.rows.forEach(trip => {
        console.log(`  - Ruta ${trip.id_route} | ${trip.trip_date} | ${trip.start_time}-${trip.end_time} | Bus: ${trip.plate_number || 'Sin asignar'} | ${trip.status_trip}`);
      });
    }
    
    // Trips por fecha
    const tripsByDate = await pool.query(`
      SELECT 
        trip_date,
        COUNT(*) as total,
        COUNT(plate_number) as assigned
      FROM tab_trips
      WHERE id_status != 5
      GROUP BY trip_date
      ORDER BY trip_date DESC
      LIMIT 7
    `);
    
    console.log('\n📅 Trips por fecha:');
    if (tripsByDate.rows.length === 0) {
      console.log('  ❌ No hay trips agrupados por fecha');
    } else {
      tripsByDate.rows.forEach(row => {
        console.log(`  ${row.trip_date}: ${row.total} trips (${row.assigned} asignados)`);
      });
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkTripsData();

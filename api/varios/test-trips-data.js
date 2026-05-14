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
    const countResult = await pool.query('SELECT COUNT(*) FROM tab_trips WHERE is_deleted = false');
    console.log('📊 Total de trips activos:', countResult.rows[0].count);
    
    // Ver trips recientes
    const recentTrips = await pool.query(`
      SELECT 
        t.id_trip,
        t.trip_date,
        t.start_time,
        t.end_time,
        r.route_name,
        t.plate_number,
        t.is_deleted
      FROM tab_trips t
      LEFT JOIN tab_routes r ON r.id_route = t.id_route
      WHERE t.is_deleted = false
      ORDER BY t.trip_date DESC, t.start_time DESC
      LIMIT 10
    `);
    
    console.log('\n📋 Últimos 10 trips:');
    recentTrips.rows.forEach(trip => {
      console.log(`  - ${trip.route_name || 'Sin ruta'} | ${trip.trip_date} | ${trip.start_time}-${trip.end_time} | Bus: ${trip.plate_number || 'Sin asignar'}`);
    });
    
    // Trips por fecha
    const tripsByDate = await pool.query(`
      SELECT 
        trip_date,
        COUNT(*) as total,
        COUNT(plate_number) as assigned
      FROM tab_trips
      WHERE is_deleted = false
      GROUP BY trip_date
      ORDER BY trip_date DESC
      LIMIT 7
    `);
    
    console.log('\n📅 Trips por fecha:');
    tripsByDate.rows.forEach(row => {
      console.log(`  ${row.trip_date}: ${row.total} trips (${row.assigned} asignados)`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkTripsData();

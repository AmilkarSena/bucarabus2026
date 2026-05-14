import pkg from 'pg';
const { Pool } = pkg;

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  password: '0000',
  port: 5432,
  database: 'postgres' // Conectar a la BD por defecto
});

async function listDatabases() {
  try {
    console.log('🔍 Listando bases de datos disponibles...\n');
    
    const result = await pool.query(`
      SELECT datname 
      FROM pg_database 
      WHERE datistemplate = false 
      ORDER BY datname
    `);
    
    console.log('📊 Bases de datos encontradas:');
    result.rows.forEach(row => {
      console.log(`  - ${row.datname}`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

listDatabases();

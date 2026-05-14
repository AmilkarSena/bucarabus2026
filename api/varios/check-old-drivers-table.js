// Verificar si tab_drivers (tabla vieja) existe
import pool from './config/database.js';

async function checkOldTable() {
  try {
    console.log('🔍 Buscando tab_drivers (tabla vieja)...\n');
    
    const tableCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'tab_drivers'
      );
    `);
    
    if (tableCheck.rows[0].exists) {
      console.log('⚠️  La tabla tab_drivers (VIEJA) todavía existe\n');
      
      // Ver estructura
      const columns = await pool.query(`
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'tab_drivers'
        AND column_name LIKE '%card%'
        ORDER BY ordinal_position
      `);
      
      if (columns.rows.length > 0) {
        console.log('Columnas con "card":');
        columns.rows.forEach(col => {
          console.log(`   ${col.column_name}: ${col.data_type}`);
        });
        console.log('');
      }
      
      // Contar registros
      const count = await pool.query('SELECT COUNT(*) FROM tab_drivers');
      console.log(`Registros en tab_drivers: ${count.rows[0].count}\n`);
      
      console.log('💡 Esta tabla podría estar causando conflictos con la nueva arquitectura\n');
      console.log('   Opciones:');
      console.log('   1. Migrar datos de tab_drivers a la nueva arquitectura (tab_users + tab_driver_details)');
      console.log('   2. Renombrar tab_drivers a tab_drivers_old');
      console.log('   3. Eliminar tab_drivers si no contiene datos importantes\n');
      
    } else {
      console.log('✅ La tabla tab_drivers NO existe (esto es correcto)\n');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkOldTable();

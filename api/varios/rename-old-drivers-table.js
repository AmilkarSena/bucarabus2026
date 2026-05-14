// Renombrar tabla vieja tab_drivers a tab_drivers_old
import pool from './config/database.js';

async function renameOldTable() {
  try {
    console.log('🔄 Renombrando tab_drivers a tab_drivers_old...\n');
    
    // Renombrar la tabla
    await pool.query('ALTER TABLE tab_drivers RENAME TO tab_drivers_old;');
    
    console.log('✅ Tabla renombrada exitosamente\n');
    
    // Verificar
    const  check = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_name LIKE '%drivers%'
      ORDER BY table_name
    `);
    
    console.log('📊 Tablas de conductores en la base de datos:\n');
    check.rows.forEach(row => {
      console.log(`   ✓ ${row.table_name}`);
    });
    
    console.log('\n💡 Ahora puedes:\n');
    console.log('   1. Usar la nueva arquitectura (tab_users + tab_driver_details)');
    console.log('   2. Migrar los 14 registros de tab_drivers_old si es necesario');
    console.log('   3. Eliminar tab_drivers_old cuando ya no la necesites\n');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code === '42P01') {
      console.error('💡 La tabla tab_drivers no existe o ya fue renombrada');
    }
  } finally {
    await pool.end();
  }
}

renameOldTable();

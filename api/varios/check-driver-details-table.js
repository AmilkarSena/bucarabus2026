// Verificar estructura de tab_driver_details
import pool from './config/database.js';

async function checkTables() {
  try {
    console.log('🔍 Verificando estructura de tablas...\n');
    
    // Verificar si tab_driver_details existe
    const tableCheck = await pool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'tab_driver_details'
      );
    `);
    
    if (!tableCheck.rows[0].exists) {
      console.log('❌ La tabla tab_driver_details NO existe\n');
      console.log('💡 Necesitas ejecutar el script user_roles.sql para crearla\n');
      return;
    }
    
    console.log('✅ La tabla tab_driver_details existe\n');
    
    // Ver estructura
    const columns = await pool.query(`
      SELECT 
        column_name, 
        data_type,
        character_maximum_length,
        numeric_precision,
        numeric_scale,
        is_nullable,
        column_default
      FROM information_schema.columns 
      WHERE table_name = 'tab_driver_details'
      ORDER BY ordinal_position
    `);
    
    console.log('📊 Columnas de tab_driver_details:\n');
    columns.rows.forEach(col => {
      const type = col.character_maximum_length 
        ? `${col.data_type}(${col.character_maximum_length})`
        : col.numeric_precision
          ? `${col.data_type}(${col.numeric_precision},${col.numeric_scale})`
          : col.data_type;
      
      console.log(`   ${col.column_name.padEnd(20)} ${type.padEnd(20)} ${col.is_nullable === 'NO' ? 'NOT NULL' : 'NULL    '}`);
    });
    
    // Ver constraints
    const constraints = await pool.query(`
      SELECT 
        con.conname AS constraint_name,
        con.contype AS constraint_type,
        pg_get_constraintdef(con.oid) AS definition
      FROM pg_constraint con
      JOIN pg_class rel ON rel.oid = con.conrelid
      WHERE rel.relname = 'tab_driver_details'
    `);
    
    console.log('\n📊 Constraints:\n');
    constraints.rows.forEach(con => {
      const type = {
        'p': 'PRIMARY KEY',
        'f': 'FOREIGN KEY',
        'u': 'UNIQUE',
        'c': 'CHECK'
      }[con.constraint_type] || con.constraint_type;
      
      console.log(`   [${type}] ${con.constraint_name}`);
      console.log(`   ${con.definition}\n`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkTables();

// Script para recrear fun_create_driver en la base de datos
import fs from 'fs';
import pool from './config/database.js';

async function recreateFunction() {
  try {
    console.log('🔄 Recreando fun_create_driver en la base de datos...\n');
    
    // Leer el archivo SQL
    const sql = fs.readFileSync('./database/fun_create_driver.sql', 'utf8');
    
    // Ejecutar el SQL
    await pool.query(sql);
    
    console.log('✅ Función fun_create_driver recreada exitosamente\n');
    
    // Verificar que existe
    const check = await pool.query(`
      SELECT proname, pronargs 
      FROM pg_proc 
      WHERE proname = 'fun_create_driver'
    `);
    
    if (check.rows.length > 0) {
      console.log('📊 Función verificada:');
      console.log('   Nombre:', check.rows[0].proname);
      console.log('   Número de argumentos:', check.rows[0].pronargs);
    } else {
      console.warn('⚠️  No se pudo verificar la función');
    }
    
  } catch (error) {
    console.error('❌ Error al recrear función:', error.message);
    if (error.hint) {
      console.error('💡 Hint:', error.hint);
    }
  } finally {
    await pool.end();
  }
}

recreateFunction();

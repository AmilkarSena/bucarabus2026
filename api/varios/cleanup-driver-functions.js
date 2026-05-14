// Verificar y eliminar todas las versiones de fun_create_driver
import pool from './config/database.js';

async function cleanupDriverFunctions() {
  try {
    console.log('🔍 Buscando todas las versiones de fun_create_driver...\n');
    
    const check = await pool.query(`
      SELECT 
        p.proname AS nombre_funcion,
        pg_get_function_identity_arguments(p.oid) AS argumentos,
        pg_get_functiondef(p.oid) AS definicion_completa
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'fun_create_driver'
        AND n.nspname = 'public'
    `);
    
    console.log(`📊 Funciones encontradas: ${check.rows.length}\n`);
    
    if (check.rows.length > 0) {
      check.rows.forEach((row, i) => {
        console.log(`${i + 1}. ${row.nombre_funcion}(${row.argumentos})`);
      });
      console.log('');
      
      // Eliminar todas las versiones
      console.log('🗑️  Eliminando todas las versiones...\n');
      
      for (const row of check.rows) {
        const dropSQL = `DROP FUNCTION IF EXISTS fun_create_driver(${row.argumentos}) CASCADE`;
        console.log(`   Ejecutando: ${dropSQL}`);
        await pool.query(dropSQL);
      }
      
      console.log('\n✅ Todas las versiones eliminadas\n');
    } else {
      console.log('✅ No hay funciones para eliminar\n');
    }
    
    // Verificar que se eliminaron
    const finalCheck = await pool.query(`
      SELECT COUNT(*) as total
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'fun_create_driver'
        AND n.nspname = 'public'
    `);
    
    console.log(`🔍 Verificación final: ${finalCheck.rows[0].total} funciones restantes\n`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await pool.end();
  }
}

cleanupDriverFunctions();

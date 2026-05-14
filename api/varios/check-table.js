// Verificar estructura de tab_active_shifts
import pool from './config/database.js';

async function checkTable() {
    const result = await pool.query(`
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_name = 'tab_active_shifts' 
        ORDER BY ordinal_position
    `);
    
    console.log('Columnas de tab_active_shifts:');
    result.rows.forEach(c => console.log('  -', c.column_name, ':', c.data_type));
    
    await pool.end();
}

checkTable();

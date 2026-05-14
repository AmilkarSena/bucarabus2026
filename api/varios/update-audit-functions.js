import pg from 'pg';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Cargar variables de entorno desde el directorio padre
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const { Pool } = pg;

// Configuración de conexión a PostgreSQL
const pool = new Pool({
  host: '10.5.213.111',
  port: 5432,
  user: 'dlastre',
  password: 'Remoto1050',
  database: 'db_bucarabus'
});

async function executeSQLFile(filePath) {
  const fileName = path.basename(filePath);
  console.log(`\n📄 Ejecutando: ${fileName}...`);
  
  try {
    const sql = fs.readFileSync(filePath, 'utf8');
    await pool.query(sql);
    console.log(`✅ ${fileName} ejecutado exitosamente`);
    return true;
  } catch (error) {
    console.error(`❌ Error en ${fileName}:`, error.message);
    return false;
  }
}

async function updateAuditFunctions() {
  console.log('🚀 Actualizando funciones con campos de auditoría...\n');
  
  const functionsToUpdate = [
    path.join(__dirname, 'database', 'fun_create_user.sql'),
    path.join(__dirname, 'database', 'fun_update_user.sql'),
    path.join(__dirname, 'database', 'fun_create_driver.sql'),
    path.join(__dirname, 'database', 'fun_update_driver.sql')
  ];
  
  let successCount = 0;
  let failCount = 0;
  
  for (const filePath of functionsToUpdate) {
    const success = await executeSQLFile(filePath);
    if (success) {
      successCount++;
    } else {
      failCount++;
    }
  }
  
  console.log('\n' + '='.repeat(50));
  console.log(`✅ Exitosas: ${successCount}`);
  console.log(`❌ Fallidas: ${failCount}`);
  console.log('='.repeat(50));
  
  await pool.end();
  
  if (failCount > 0) {
    process.exit(1);
  }
}

updateAuditFunctions();

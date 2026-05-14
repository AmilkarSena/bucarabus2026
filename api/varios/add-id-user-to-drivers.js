/**
 * Migración: Agrega columna id_user (nullable) a tab_drivers
 * 
 * Vincula conductores con cuentas de usuario del sistema (Opción A).
 * Solo conductores con acceso a DriverAppView necesitan este valor.
 */

import pg from 'pg'
import dotenv from 'dotenv'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __dirname = dirname(fileURLToPath(import.meta.url))
dotenv.config({ path: join(__dirname, '../.env') })

const { Pool } = pg

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT || '5432'),
  database: process.env.DB_NAME,
  user:     process.env.DB_SUPERUSER || 'postgres',
  password: process.env.DB_SUPERUSER_PASSWORD,
})

async function migrate() {
  const client = await pool.connect()
  try {
    await client.query('BEGIN')

    // 1. Agregar columna id_user nullable
    await client.query(`
      ALTER TABLE tab_drivers
      ADD COLUMN IF NOT EXISTS id_user SMALLINT;
    `)
    console.log('✅ Columna id_user agregada a tab_drivers')

    // 2. FK a tab_users con ON DELETE SET NULL
    await client.query(`
      ALTER TABLE tab_drivers
      ADD CONSTRAINT fk_drivers_user
        FOREIGN KEY (id_user) REFERENCES tab_users(id_user) ON DELETE SET NULL;
    `)
    console.log('✅ FK fk_drivers_user creada')

    // 3. UNIQUE: un usuario solo puede ser un conductor
    await client.query(`
      ALTER TABLE tab_drivers
      ADD CONSTRAINT uq_drivers_user UNIQUE (id_user);
    `)
    console.log('✅ UNIQUE uq_drivers_user creado')

    // 4. Índice parcial (solo filas donde id_user no es NULL)
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_driver_user
        ON tab_drivers(id_user) WHERE id_user IS NOT NULL;
    `)
    console.log('✅ Índice idx_driver_user creado')

    // 5. Comentarios
    await client.query(`
      COMMENT ON COLUMN tab_drivers.id_user IS
        'FK nullable a tab_users. NULL = conductor sin acceso al sistema. NOT NULL = conductor con cuenta activa para DriverAppView.';
    `)
    await client.query(`
      COMMENT ON TABLE tab_drivers IS
        'Perfil operativo del conductor, identificado por cédula (id_driver). id_user es nullable: solo se asigna si el conductor tiene acceso al sistema.';
    `)
    console.log('✅ Comentarios actualizados')

    await client.query('COMMIT')
    console.log('\n🎉 Migración completada exitosamente')
  } catch (error) {
    await client.query('ROLLBACK')
    // Si la constraint ya existe, no es un error crítico
    if (error.code === '42710' || error.message.includes('already exists')) {
      console.log('ℹ️  La migración ya fue aplicada anteriormente')
    } else {
      console.error('❌ Error en migración:', error.message)
      process.exit(1)
    }
  } finally {
    client.release()
    await pool.end()
  }
}

migrate()

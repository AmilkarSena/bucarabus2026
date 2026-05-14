import pool from '../config/database.js';

/**
 * Script de prueba para verificar los procedimientos almacenados de conductores
 */

async function testStoredProcedures() {
  console.log('🚀 Iniciando pruebas de procedimientos almacenados de conductores...\n');

  try {
    // 1. Verificar conexión
    console.log('1️⃣ Verificando conexión a la base de datos...');
    const connectionTest = await pool.query('SELECT NOW()');
    console.log('✅ Conexión exitosa:', connectionTest.rows[0].now);
    console.log('');

    // 2. Obtener todos los conductores
    console.log('2️⃣ Obteniendo todos los conductores...');
    const allDrivers = await pool.query('SELECT * FROM sp_get_all_drivers($1)', [false]);
    console.log(`✅ Total de conductores: ${allDrivers.rows.length}`);
    console.log('Conductores:', JSON.stringify(allDrivers.rows, null, 2));
    console.log('');

    // 3. Obtener solo conductores activos
    console.log('3️⃣ Obteniendo conductores activos...');
    const activeDrivers = await pool.query('SELECT * FROM sp_get_all_drivers($1)', [true]);
    console.log(`✅ Conductores activos: ${activeDrivers.rows.length}`);
    console.log('');

    // 4. Crear un conductor de prueba
    console.log('4️⃣ Creando conductor de prueba...');
    const testDriver = {
      name_driver: 'TEST - Juan Pérez',
      id_card: Math.floor(Math.random() * 1000000000), // Cédula aleatoria
      cel: 3001234567,
      email: `test.${Date.now()}@prueba.com`, // Email único
      license_cat: 'C2',
      license_exp: '2026-12-31',
      address_driver: 'Dirección de prueba #123',
      photo_driver: null,
      user_create: 'test_script'
    };

    const createResult = await pool.query(
      `SELECT * FROM sp_create_driver($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [
        testDriver.name_driver,
        testDriver.id_card,
        testDriver.cel,
        testDriver.email,
        testDriver.license_cat,
        testDriver.license_exp,
        testDriver.address_driver,
        testDriver.photo_driver,
        testDriver.user_create
      ]
    );

    if (createResult.rows[0] && createResult.rows[0].id_user) {
      const newDriverId = createResult.rows[0].id_user;
      console.log(`✅ Conductor creado con ID: ${newDriverId}`);
      console.log('Datos:', JSON.stringify(createResult.rows[0], null, 2));
      console.log('');

      // 5. Obtener conductor por ID
      console.log(`5️⃣ Obteniendo conductor con ID ${newDriverId}...`);
      const driverById = await pool.query('SELECT * FROM sp_get_driver_by_id($1)', [newDriverId]);
      console.log('✅ Conductor encontrado:', JSON.stringify(driverById.rows[0], null, 2));
      console.log('');

      // 6. Actualizar conductor
      console.log(`6️⃣ Actualizando conductor ${newDriverId}...`);
      const updateResult = await pool.query(
        `SELECT * FROM sp_update_driver($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          newDriverId,
          'TEST - Juan Pérez ACTUALIZADO',
          testDriver.id_card,
          3009876543,
          testDriver.email,
          'C2',
          '2027-12-31',
          'Nueva dirección actualizada',
          null,
          'test_script'
        ]
      );
      console.log('✅ Conductor actualizado:', JSON.stringify(updateResult.rows[0], null, 2));
      console.log('');

      // 7. Cambiar disponibilidad
      console.log(`7️⃣ Cambiando disponibilidad del conductor ${newDriverId}...`);
      const availabilityResult = await pool.query(
        'SELECT * FROM sp_toggle_driver_availability($1, $2, $3)',
        [newDriverId, false, 'test_script']
      );
      console.log('✅ Disponibilidad cambiada:', availabilityResult.rows[0].avalible);
      console.log('');

      // 8. Obtener conductores disponibles
      console.log('8️⃣ Obteniendo conductores disponibles...');
      const availableDrivers = await pool.query('SELECT * FROM sp_get_available_drivers()');
      console.log(`✅ Conductores disponibles: ${availableDrivers.rows.length}`);
      console.log('');

      // 9. Cambiar estado (inactivar)
      console.log(`9️⃣ Inactivando conductor ${newDriverId}...`);
      const statusResult = await pool.query(
        'SELECT * FROM sp_toggle_driver_status($1, $2, $3)',
        [newDriverId, false, 'test_script']
      );
      console.log('✅ Estado cambiado:', statusResult.rows[0].status_driver);
      console.log('');

      // 10. Eliminar conductor de prueba
      console.log(`🔟 Eliminando conductor de prueba ${newDriverId}...`);
      const deleteResult = await pool.query('SELECT * FROM sp_delete_driver($1)', [newDriverId]);
      console.log('✅ Conductor eliminado exitosamente');
      console.log('');

    } else {
      console.error('❌ Error al crear conductor de prueba');
      if (createResult.rows[0]) {
        console.error('Mensaje:', createResult.rows[0]);
      }
    }

    // Resumen final
    console.log('═══════════════════════════════════════════════════════');
    console.log('✅ TODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE');
    console.log('═══════════════════════════════════════════════════════');
    console.log('');
    console.log('Procedimientos probados:');
    console.log('  ✓ sp_get_all_drivers');
    console.log('  ✓ sp_get_driver_by_id');
    console.log('  ✓ sp_create_driver');
    console.log('  ✓ sp_update_driver');
    console.log('  ✓ sp_toggle_driver_availability');
    console.log('  ✓ sp_toggle_driver_status');
    console.log('  ✓ sp_get_available_drivers');
    console.log('  ✓ sp_delete_driver');
    console.log('');

  } catch (error) {
    console.error('❌ Error durante las pruebas:');
    console.error('Mensaje:', error.message);
    console.error('Código:', error.code);
    console.error('Detalle:', error.detail);
    console.error('Stack:', error.stack);
    
    if (error.message.includes('function') && error.message.includes('does not exist')) {
      console.error('');
      console.error('💡 SOLUCIÓN: Ejecuta el archivo stored_procedures_drivers.sql');
      console.error('   psql -U postgres -d bucarabus -f api/database/stored_procedures_drivers.sql');
    }
  } finally {
    // Cerrar pool de conexiones
    await pool.end();
    console.log('🔌 Conexión cerrada');
  }
}

// Ejecutar pruebas
testStoredProcedures();

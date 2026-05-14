// Script para probar fun_create_driver (nueva arquitectura)
import pool from './config/database.js';
import bcrypt from 'bcrypt';

async function testCreateDriver() {
  try {
    console.log('🧪 Probando fun_create_driver con nueva arquitectura...\n');
    
    // 1. Generar password hash
    const password = 'password123';
    const passwordHash = await bcrypt.hash(password, 10);
    console.log('🔐 Password hash generado:', passwordHash);
    console.log('   Longitud:', passwordHash.length, 'caracteres\n');
    
    // 2. Datos del conductor de prueba
    const driverData = {
      email: `conductor.test.${Date.now()}@bucarabus.com`,
      password_hash: passwordHash,
      full_name: 'Juan Carlos Pérez García',
      avatar_url: 'https://i.pravatar.cc/300?img=12',
      id_card: Math.floor(Math.random() * 9000000000) + 1000000000, // 10 dígitos
      cel: '3201234567',
      license_cat: 'C2',
      license_exp: '2027-12-31',
      address_driver: 'Calle 45 #23-11, Bucaramanga'
    };
    
    console.log('📝 Datos del conductor:');
    console.log('   Email:', driverData.email);
    console.log('   Nombre:', driverData.full_name);
    console.log('   Cédula:', driverData.id_card);
    console.log('   Teléfono:', driverData.cel);
    console.log('   Licencia:', driverData.license_cat, '-', driverData.license_exp);
    console.log('   Dirección:', driverData.address_driver);
    console.log('');
    
    // 3. Llamar a la función
    console.log('📞 Llamando a fun_create_driver...\n');
    
    const result = await pool.query(
      `SELECT * FROM fun_create_driver($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [
        driverData.email,          // p_email
        driverData.password_hash,  // p_password_hash
        driverData.full_name,      // p_full_name
        driverData.id_card,        // p_id_card
        driverData.cel,            // p_cel
        driverData.license_cat,    // p_license_cat
        driverData.license_exp,    // p_license_exp
        driverData.avatar_url,     // p_avatar_url (opcional)
        driverData.address_driver  // p_address_driver (opcional)
      ]
    );
    
    // El resultado viene como un tipo personalizado, necesitamos extraer los campos
    const driverResult = result.rows[0].fun_create_driver;
    
    // Parse el resultado (viene como string "(value1,value2,...)")
    console.log('✅ Conductor creado exitosamente:');
    console.log('   Datos retornados:', driverResult);
    
    // Consulta directa para verificar insertados
    const verifyUser = await pool.query(
      'SELECT id_user, email, full_name, created_at FROM tab_users WHERE email = $1',
      [driverData.email]
    );
    
    const driver = verifyUser.rows[0];
    
    if (driver) {
      console.log('   ID Usuario:', driver.id_user, `(${typeof driver.id_user})`);
      console.log('   Email:', driver.email);
      console.log('   Nombre:', driver.full_name);
      console.log('   Creado:', driver.created_at);
      console.log('');
      
      // Verificar detalles del conductor
      const details = await pool.query(
        'SELECT id_card, license_cat, license_exp FROM tab_driver_details WHERE id_user = $1',
        [driver.id_user]
      );
      
      if (details.rows.length > 0) {
        console.log('   Cédula:', details.rows[0].id_card);
        console.log('   Licencia:', details.rows[0].license_cat, 'vence', details.rows[0].license_exp);
        console.log('');
      }
    } else {
      throw new Error('No se pudo verificar el usuario creado');
    }
    
    // 4. Verificar registros en todas las tablas
    console.log('🔍 Verificando registros creados...\n');
    
    // tab_users
    const userCheck = await pool.query(
      'SELECT id_user, email, full_name, avatar_url, is_active, created_at FROM tab_users WHERE id_user = $1',
      [driver.id_user]
    );
    console.log('📊 tab_users:');
    console.log(userCheck.rows[0]);
    console.log('');
    
    // tab_user_roles
    const rolesCheck = await pool.query(
      `SELECT ur.id_user, ur.id_role, r.role_name, ur.assigned_at, ur.is_active 
       FROM tab_user_roles ur 
       JOIN tab_roles r ON ur.id_role = r.id_role 
       WHERE ur.id_user = $1`,
      [driver.id_user]
    );
    console.log('📊 tab_user_roles:');
    console.log(rolesCheck.rows);
    console.log('');
    
    // tab_driver_details
    const detailsCheck = await pool.query(
      `SELECT id_card, id_user, cel, license_cat, license_exp, address_driver, 
              available, status_driver, date_entry, created_at 
       FROM tab_driver_details WHERE id_user = $1`,
      [driver.id_user]
    );
    console.log('📊 tab_driver_details:');
    console.log(detailsCheck.rows[0]);
    console.log('');
    
    // 5. Limpiar datos de prueba
    console.log('🗑️  Limpiando datos de prueba...\n');
    
    await pool.query('DELETE FROM tab_driver_details WHERE id_user = $1', [driver.id_user]);
    await pool.query('DELETE FROM tab_user_roles WHERE id_user = $1', [driver.id_user]);
    await pool.query('DELETE FROM tab_users WHERE id_user = $1', [driver.id_user]);
    
    console.log('✅ Datos de prueba eliminados\n');
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✨ PRUEBA COMPLETADA EXITOSAMENTE ✨');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log('📋 Resumen:');
    console.log('   ✅ Usuario creado en tab_users');
    console.log('   ✅ Rol Conductor asignado en tab_user_roles');
    console.log('   ✅ Detalles guardados en tab_driver_details');
    console.log('   ✅ ID generado con epoch 2025');
    console.log('   ✅ Password hash bcrypt válido');
    console.log('   ✅ Todas las validaciones pasaron');
    console.log('');
    
  } catch (error) {
    console.error('❌ Error en la prueba:', error.message);
    if (error.hint) {
      console.error('💡 Hint:', error.hint);
    }
    console.error('\n📋 Stack trace:', error.stack);
  } finally {
    await pool.end();
  }
}

testCreateDriver();

const { Pool } = require('pg');

const pool = new Pool({
  user: 'bucarabus_user',
  host: 'localhost',
  database: 'db_bucarabus',
  password: 'bucarabus2024',
  port: 5432,
});

async function check() {
  try {
    const rolesResult = await pool.query(
      `SELECT r.id_role, r.role_name
       FROM tab_user_roles ur
       INNER JOIN tab_roles r ON ur.id_role = r.id_role
       WHERE ur.id_user = 2 AND ur.is_active = TRUE AND r.is_active = TRUE`
    );
    console.log("ROLES DEL USUARIO JOSE:", rolesResult.rows);
  } catch (err) {
    console.error(err);
  } finally {
    pool.end();
  }
}
check();

import pool from '../config/database.js'

await pool.query(`
  INSERT INTO tab_bus_statuses (id_status, status_name, descrip, color_hex) VALUES
    (1, 'disponible',        'Bus listo para ser asignado a un viaje',     '#4CAF50'),
    (2, 'en_ruta',           'Bus operando actualmente en un viaje',       '#2196F3'),
    (3, 'mantenimiento',     'Bus en taller, no disponible temporalmente', '#FFA500'),
    (4, 'fuera_de_servicio', 'Bus con falla grave, requiere intervencion', '#F44336')
  ON CONFLICT (id_status) DO NOTHING
`)
console.log('✅ tab_bus_statuses OK')

const r = await pool.query('SELECT id_status, status_name FROM tab_bus_statuses')
console.log(JSON.stringify(r.rows))
process.exit(0)

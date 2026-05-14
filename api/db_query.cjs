const { Pool } = require('pg');
const pool = new Pool({ user: 'postgres', host: 'localhost', database: 'db_bucarabus', password: 'admin', port: 5432 });
pool.query("SELECT assoc.point_order, assoc.id_point, cp.name_point FROM tab_route_points_assoc assoc JOIN tab_route_points cp ON assoc.id_point = cp.id_point JOIN tab_routes r ON assoc.id_route = r.id_route WHERE r.name_route = 'ruta con OSM' ORDER BY assoc.point_order").then(res => { console.table(res.rows); pool.end(); });

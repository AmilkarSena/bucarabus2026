const fs = require('fs');
const filepath = './api/services/routes.service.js';

let content = fs.readFileSync(filepath, 'utf8');

const anchor = '      const result = await pool.query(';
const lines = content.split('\n');
let newLines = [];

for(let i=0; i<lines.length; i++) {
    newLines.push(lines[i]);
    if(lines[i].includes(anchor) && i > 400 && i < 500) {
        // We are at line 454 (approx)
        // Keep until the query text finishes.
        break;
    }
}

const restOfFile = `
        \`SELECT success, msg, error_code, out_id_route, out_id_point, out_point_order
         FROM fun_assign_route_point($1, $2, $3, $4, $5)\`,
        [
          routeId,
          Number(idPoint),
          Number(pointOrder),
          distFromStart != null ? Number(distFromStart) : null,
          etaSeconds    != null ? Number(etaSeconds)    : null
        ]
      )

      const { success, msg, error_code, out_id_route, out_id_point, out_point_order } = result.rows[0]

      if (!success) {
        const err = new Error(msg)
        err.code = error_code
        throw err
      }

      return {
        success:    true,
        idRoute:    out_id_route,
        idPoint:    out_id_point,
        pointOrder: out_point_order,
        message:    msg
      }
    } catch (error) {
      console.error('❌ Error asignando punto a ruta:', error)
      if (error.code) console.error('   Código:', error.code)
      throw error
    }
  }

  /**
   * Obtener los puntos asignados a una ruta
   */
  async getRoutePoints(idRoute) {
    const routeId = Number(idRoute)
    try {
      const result = await pool.query(\`
        SELECT 
          ap.id_point,
          p.name_point,
          p.descrip_point,
          ST_Y(p.geom_point::geometry) as lat,
          ST_X(p.geom_point::geometry) as lng,
          ap.point_order,
          ap.dist_from_start,
          ap.eta_seconds,
          p.is_active as point_is_active
        FROM tab_route_points_assoc ap
        JOIN tab_route_points p ON ap.id_point = p.id_point
        WHERE ap.id_route = $1
        ORDER BY ap.point_order ASC
      \`, [routeId])

      return result.rows.map(row => ({
        idPoint:       row.id_point,
        namePoint:     row.name_point,
        descripPoint:  row.descrip_point,
        coordinates:   [parseFloat(row.lat), parseFloat(row.lng)],
        pointOrder:    row.point_order,
        distFromStart: row.dist_from_start,
        etaSeconds:    row.eta_seconds,
        isActive:      row.point_is_active
      }))
    } catch (error) {
      console.error('❌ Error obteniendo puntos de ruta:', error)
      throw error
    }
  }

  /**
   * Desasignar un punto de una ruta
   */
  async unassignRoutePoint(idRoute, idPoint) {
    try {
      const result = await pool.query(
        \`SELECT success, msg, error_code, out_id_route, out_id_point, out_point_order
         FROM fun_unassign_route_point($1, $2)\`,
        [Number(idRoute), Number(idPoint)]
      )

      const { success, msg, error_code, out_id_route, out_id_point, out_point_order } = result.rows[0]

      if (!success) {
        const err = new Error(msg)
        err.code = error_code
        throw err
      }

      return {
        success:    true,
        idRoute:    out_id_route,
        idPoint:    out_id_point,
        pointOrder: out_point_order,
        message:    msg
      }
    } catch (error) {
      console.error('❌ Error desasignando punto de ruta:', error)
      throw error
    }
  }
}

export const routesService = new RoutesService()
`;

fs.writeFileSync(filepath, newLines.join('\\n') + restOfFile);
console.log('Fijado');

-- =============================================
-- FUNCIÓN: fun_unassign_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Elimina la asociación de un punto con una ruta en tab_route_points_assoc.
--   Usa DELETE en lugar de is_active = FALSE porque la tabla pivote no
--   tiene campo de auditoría — una fila borrada no tiene historial relevante.
--   Si se necesita preservar el historial, usar is_active = FALSE directamente.
--
--   Reglas de negocio (validar en backend antes de llamar):
--     - No desasignar el primer o último punto si hay viajes activos en la ruta.
--     - Considerar si quedan al menos 2 puntos tras la eliminación.
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros (IN):
--   wid_route   tab_route_points_assoc.id_route%TYPE  — ID de la ruta
--   wid_point   tab_route_points_assoc.id_point%TYPE  — ID del punto a desasignar
--
-- Retorna (OUT):
--   success          BOOLEAN                                   — TRUE si se eliminó
--   msg              TEXT                                      — Mensaje descriptivo
--   error_code       VARCHAR(50)                              — NULL si éxito
--   out_id_route     tab_route_points_assoc.id_route%TYPE     — ID de la ruta (confirmación)
--   out_id_point     tab_route_points_assoc.id_point%TYPE     — ID del punto desasignado
--   out_point_order  tab_route_points_assoc.point_order%TYPE  — Orden que tenía en la ruta
--
-- Códigos de error:
--   ROUTE_POINT_ASSOC_NOT_FOUND — La combinación (id_route, id_point) no existe
--   ROUTE_POINT_ASSOC_FK        — FK inválida (raro en DELETE, pero posible)
--   ROUTE_POINT_ASSOC_ERROR     — Error inesperado
--
-- Versión   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_unassign_route_point(SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_unassign_route_point(
  wid_route   tab_route_points_assoc.id_route%TYPE,
  wid_point   tab_route_points_assoc.id_point%TYPE,

  -- Parámetros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_route     tab_route_points_assoc.id_route%TYPE,
  OUT out_id_point     tab_route_points_assoc.id_point%TYPE,
  OUT out_point_order  tab_route_points_assoc.point_order%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_point_order  tab_route_points_assoc.point_order%TYPE;
BEGIN

  success         := FALSE;
  msg             := '';
  error_code      := NULL;
  out_id_route    := NULL;
  out_id_point    := NULL;
  out_point_order := NULL;

  DELETE FROM tab_route_points_assoc
  WHERE  id_route = wid_route
    AND  id_point = wid_point
  RETURNING point_order INTO v_point_order;

  IF v_point_order IS NULL THEN
    msg        := 'Asociación no encontrada (ruta: ' || wid_route || ', punto: ' || wid_point || ')';
    error_code := 'ROUTE_POINT_ASSOC_NOT_FOUND';
    RETURN;
  END IF;

  out_id_route    := wid_route;
  out_id_point    := wid_point;
  out_point_order := v_point_order;
  success         := TRUE;
  msg             := 'Punto (ID: ' || wid_point || ') desasignado de ruta (ID: ' || wid_route
                     || '), posición liberada: ' || v_point_order;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Error de FK al eliminar asociación: ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_FK';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_unassign_route_point(SMALLINT, SMALLINT) IS
'v1.0 — Elimina la asociación de un punto con una ruta (DELETE en tab_route_points_assoc). Retorna el point_order que tenía para que el backend pueda reordenar si es necesario.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desasignar punto ID=3 de ruta ID=1
SELECT * FROM fun_unassign_route_point(1, 3);
-- success | msg                                              | error_code | out_id_route | out_id_point | out_point_order
-- TRUE    | Punto (ID: 3) desasignado de ruta (ID: 1), posición liberada: 2 | NULL | 1  | 3            | 2

-- Asociación inexistente
SELECT * FROM fun_unassign_route_point(1, 99);
-- success | msg                                               | error_code                    | ...
-- FALSE   | Asociación no encontrada (ruta: 1, punto: 99)    | ROUTE_POINT_ASSOC_NOT_FOUND   | NULL

-- Flujo recomendado en el backend tras desasignar:
--   1. Llamar fun_unassign_route_point(id_route, id_point)
--   2. Si success = TRUE, llamar fun_reorder_route_points(id_route, [nuevo_orden])
--      para cerrar el hueco dejado por el punto eliminado.

*/

-- =============================================
-- FUNCIÓN: fun_toggle_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Activa o desactiva un punto de ruta en tab_route_points (campo is_active).
--   Regla de negocio: no se puede desactivar un punto que está activo en
--   una o más rutas (tab_route_points_assoc); esa validación es
--   responsabilidad del backend (Node.js) antes de llamar esta función.
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros (IN):
--   wid_point     tab_route_points.id_point%TYPE    — ID del punto a activar/desactivar
--   wis_active    tab_route_points.is_active%TYPE   — TRUE = activar, FALSE = desactivar
--   wuser_update  tab_route_points.user_update%TYPE — Usuario que realiza el cambio
--
-- Retorna (OUT):
--   success       BOOLEAN                           — TRUE si se aplicó el cambio
--   msg           TEXT                              — Mensaje descriptivo
--   error_code    VARCHAR(50)                       — NULL si éxito; código si falla
--   out_id_point  tab_route_points.id_point%TYPE    — ID del punto modificado
--   new_status    tab_route_points.is_active%TYPE   — Nuevo valor de is_active
--
-- Códigos de error:
--   ROUTE_POINT_NOT_FOUND    — El id_point no existe en tab_route_points
--   ROUTE_POINT_FK_VIOLATION — FK de user_update inválida
--   ROUTE_POINT_UPDATE_ERROR — Error inesperado en el UPDATE
--
-- Versión   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_route_point(SMALLINT, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_route_point(
  wid_point     tab_route_points.id_point%TYPE,
  wis_active    tab_route_points.is_active%TYPE,
  wuser_update  tab_route_points.user_update%TYPE,

  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_point  tab_route_points.id_point%TYPE,
  OUT new_status    tab_route_points.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_point  tab_route_points.id_point%TYPE;
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_point := NULL;
  new_status   := NULL;

  UPDATE tab_route_points SET
    is_active   = wis_active,
    updated_at  = NOW(),
    user_update = wuser_update
  WHERE id_point = wid_point
  RETURNING id_point INTO v_id_point;

  IF v_id_point IS NULL THEN
    msg        := 'Punto de ruta no encontrado (ID: ' || wid_point || ')';
    error_code := 'ROUTE_POINT_NOT_FOUND';
    RETURN;
  END IF;

  out_id_point := v_id_point;
  new_status   := wis_active;
  success      := TRUE;
  msg          := 'Punto de ruta (ID: ' || out_id_point || ') '
                  || CASE WHEN wis_active THEN 'activado' ELSE 'desactivado' END
                  || ' exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario no válido (user_update): ' || SQLERRM;
    error_code := 'ROUTE_POINT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_route_point(SMALLINT, BOOLEAN, SMALLINT) IS
'v1.0 — Activa o desactiva un punto de ruta en tab_route_points. Usa RETURNING para detectar NOT FOUND. La regla de negocio (no desactivar si está en uso) debe validarla el backend antes de llamar esta función.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar punto ID=3 (ejecutado por usuario 1)
SELECT * FROM fun_toggle_route_point(3, FALSE, 1);
-- success | msg                                          | error_code | out_id_point | new_status
-- TRUE    | Punto de ruta (ID: 3) desactivado exitosamente | NULL    | 3            | FALSE

-- Activar punto previamente desactivado
SELECT * FROM fun_toggle_route_point(3, TRUE, 1);
-- success | msg                                        | error_code | out_id_point | new_status
-- TRUE    | Punto de ruta (ID: 3) activado exitosamente | NULL     | 3            | TRUE

-- ID inexistente
SELECT * FROM fun_toggle_route_point(99, FALSE, 1);
-- success | msg                                    | error_code              | out_id_point | new_status
-- FALSE   | Punto de ruta no encontrado (ID: 99)  | ROUTE_POINT_NOT_FOUND   | NULL         | NULL

*/

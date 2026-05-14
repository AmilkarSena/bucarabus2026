-- =============================================
-- FUNCIÓN: fun_toggle_route v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Activa o desactiva una ruta en tab_routes (campo is_active).
--   Reglas de negocio (validar en backend antes de llamar):
--     - No desactivar una ruta con viajes activos en tab_trips.
--     - No desactivar si hay turnos en curso que la referencian.
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros (IN):
--   wid_route     tab_routes.id_route%TYPE     — ID de la ruta a activar/desactivar
--   wis_active    tab_routes.is_active%TYPE    — TRUE = activar, FALSE = desactivar
--   wuser_update  tab_routes.user_update%TYPE  — Usuario que realiza el cambio
--
-- Retorna (OUT):
--   success       BOOLEAN                      — TRUE si se aplicó el cambio
--   msg           TEXT                         — Mensaje descriptivo
--   error_code    VARCHAR(50)                  — NULL si éxito; código si falla
--   out_id_route  tab_routes.id_route%TYPE     — ID de la ruta modificada
--   new_status    tab_routes.is_active%TYPE    — Nuevo valor de is_active
--
-- Códigos de error:
--   ROUTE_NOT_FOUND    — El id_route no existe en tab_routes
--   ROUTE_FK_VIOLATION — FK de user_update inválida
--   ROUTE_UPDATE_ERROR — Error inesperado
--
-- Versión   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_route(SMALLINT, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_route(
  wid_route     tab_routes.id_route%TYPE,
  wis_active    tab_routes.is_active%TYPE,
  wuser_update  tab_routes.user_update%TYPE,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_route  tab_routes.id_route%TYPE,
  OUT new_status    tab_routes.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_route  tab_routes.id_route%TYPE;
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_route := NULL;
  new_status   := NULL;

  UPDATE tab_routes SET
    is_active   = wis_active,
    updated_at  = NOW(),
    user_update = wuser_update
  WHERE id_route = wid_route
  RETURNING id_route INTO v_id_route;

  IF v_id_route IS NULL THEN
    msg        := 'Ruta no encontrada (ID: ' || wid_route || ')';
    error_code := 'ROUTE_NOT_FOUND';
    RETURN;
  END IF;

  out_id_route := v_id_route;
  new_status   := wis_active;
  success      := TRUE;
  msg          := 'Ruta (ID: ' || out_id_route || ') '
                  || CASE WHEN wis_active THEN 'activada' ELSE 'desactivada' END
                  || ' exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario no válido (user_update): ' || SQLERRM;
    error_code := 'ROUTE_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_route(SMALLINT, BOOLEAN, SMALLINT) IS
'v1.0 — Activa o desactiva una ruta en tab_routes. La verificación de viajes/turnos activos debe hacerse en el backend antes de llamar esta función.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar ruta ID=1
SELECT * FROM fun_toggle_route(1, FALSE, 1);
-- success | msg                                | error_code | out_id_route | new_status
-- TRUE    | Ruta (ID: 1) desactivada exitosamente | NULL    | 1            | FALSE

-- Activar ruta
SELECT * FROM fun_toggle_route(1, TRUE, 1);
-- success | msg                               | error_code | out_id_route | new_status
-- TRUE    | Ruta (ID: 1) activada exitosamente | NULL      | 1            | TRUE

-- ID inexistente
SELECT * FROM fun_toggle_route(99, FALSE, 1);
-- success | msg                         | error_code      | out_id_route | new_status
-- FALSE   | Ruta no encontrada (ID: 99) | ROUTE_NOT_FOUND | NULL         | NULL

*/

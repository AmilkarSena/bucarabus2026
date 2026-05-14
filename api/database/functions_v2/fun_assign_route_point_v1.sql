-- =============================================
-- FUNCIÓN: fun_assign_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Asigna un punto de ruta existente a una ruta en tab_route_points_assoc.
--   Permite que una misma parada (ej. "Terminal Metrolínea") aparezca
--   en múltiples rutas con orden, distancia y ETA propios por ruta.
--
--   Reglas de negocio (validar en backend antes de llamar):
--     - El id_point debe existir y estar activo en tab_route_points.
--     - El id_route debe existir y estar activo en tab_routes.
--     - El point_order no debe estar ya ocupado en esa ruta.
--
--   Los constraints de la BD (PK, UNIQUE, FK, CHECK) actúan como última barrera.
--
-- Parámetros (IN):
--   wid_route        tab_route_points_assoc.id_route%TYPE       — ID de la ruta
--   wid_point        tab_route_points_assoc.id_point%TYPE       — ID del punto a asignar
--   wpoint_order     tab_route_points_assoc.point_order%TYPE    — Posición en la ruta (> 0)
--   wdist_from_start tab_route_points_assoc.dist_from_start%TYPE — km acumulados (DEFAULT NULL)
--   weta_seconds     tab_route_points_assoc.eta_seconds%TYPE    — Segundos estimados (DEFAULT NULL)
--
-- Retorna (OUT):
--   success          BOOLEAN                                    — TRUE si se asignó correctamente
--   msg              TEXT                                       — Mensaje descriptivo
--   error_code       VARCHAR(50)                               — NULL si éxito; código si falla
--   out_id_route     tab_route_points_assoc.id_route%TYPE      — ID de la ruta (confirmación)
--   out_id_point     tab_route_points_assoc.id_point%TYPE      — ID del punto asignado
--   out_point_order  tab_route_points_assoc.point_order%TYPE   — Orden asignado
--
-- Códigos de error:
--   ROUTE_POINT_ASSOC_ORDER_TAKEN — El point_order ya está ocupado en esa ruta (PK)
--   ROUTE_POINT_ASSOC_FK          — FK inválida (ruta o punto no existe)
--   ROUTE_POINT_ASSOC_CHECK       — point_order <= 0 o dist/eta negativos
--   ROUTE_POINT_ASSOC_ERROR       — Error inesperado
--
-- Versión   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_assign_route_point(SMALLINT, SMALLINT, SMALLINT, NUMERIC, INTEGER);

CREATE OR REPLACE FUNCTION fun_assign_route_point(
  wid_route         tab_route_points_assoc.id_route%TYPE,
  wid_point         tab_route_points_assoc.id_point%TYPE,
  wpoint_order      tab_route_points_assoc.point_order%TYPE,
  wdist_from_start  tab_route_points_assoc.dist_from_start%TYPE  DEFAULT NULL,
  weta_seconds      tab_route_points_assoc.eta_seconds%TYPE      DEFAULT NULL,

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
BEGIN

  success         := FALSE;
  msg             := '';
  error_code      := NULL;
  out_id_route    := NULL;
  out_id_point    := NULL;
  out_point_order := NULL;

  INSERT INTO tab_route_points_assoc (
    id_route,
    id_point,
    point_order,
    dist_from_start,
    eta_seconds
  ) VALUES (
    wid_route,
    wid_point,
    wpoint_order,
    wdist_from_start,
    weta_seconds
  );

  out_id_route    := wid_route;
  out_id_point    := wid_point;
  out_point_order := wpoint_order;
  success         := TRUE;
  msg             := 'Punto (ID: ' || wid_point || ') asignado a ruta (ID: ' || wid_route
                     || ') en posición ' || wpoint_order || ' exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    -- Solo puede ser por PK (id_route, point_order)
    msg        := 'El orden ' || wpoint_order || ' ya está ocupado en la ruta (ID: ' || wid_route || ')';
    error_code := 'ROUTE_POINT_ASSOC_ORDER_TAKEN';
  WHEN foreign_key_violation THEN
    msg        := 'Ruta o punto no existe: ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_FK';
  WHEN check_violation THEN
    msg        := 'Valor fuera de rango (point_order > 0, dist >= 0, eta >= 0): ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_CHECK';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_assign_route_point(SMALLINT, SMALLINT, SMALLINT, NUMERIC, INTEGER) IS
'v1.0 — Asigna un punto de ruta (tab_route_points) a una ruta (tab_routes) mediante tab_route_points_assoc. Un mismo punto puede asignarse a múltiples rutas con orden, distancia y ETA propios.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Asignar "Terminal Metrolínea" (id_point=1) a Ruta 1 en posición 1 (inicio)
SELECT * FROM fun_assign_route_point(1, 1, 1, 0.000, 0);
-- success | msg                                              | error_code | out_id_route | out_id_point | out_point_order
-- TRUE    | Punto (ID:1) asignado a ruta (ID:1) en posición 1 | NULL     | 1            | 1            | 1

-- Asignar el mismo punto a Ruta 3 en posición 5 (reutilización)
SELECT * FROM fun_assign_route_point(3, 1, 5, 8.200, 1440);
-- success | msg                                              | error_code | out_id_route | out_id_point | out_point_order
-- TRUE    | Punto (ID:1) asignado a ruta (ID:3) en posición 5 | NULL     | 3            | 1            | 5

-- Error: punto ya asignado a esa ruta
SELECT * FROM fun_assign_route_point(1, 1, 2);
-- success | msg                                                    | error_code                    | ...
-- FALSE   | El punto (ID: 1) ya está asignado a la ruta (ID: 1)  | ROUTE_POINT_ASSOC_DUPLICATE   | NULL

-- Error: posición ya ocupada
SELECT * FROM fun_assign_route_point(1, 2, 1);
-- success | msg                                                    | error_code                      | ...
-- FALSE   | El orden 1 ya está ocupado en la ruta (ID: 1)        | ROUTE_POINT_ASSOC_ORDER_TAKEN   | NULL

*/

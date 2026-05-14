-- =============================================
-- FUNCIÓN: fun_update_route v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza los metadatos de una ruta existente en tab_routes.
--   El id_route es el identificador (PK) y nunca se modifica.
--   path_route NO es actualizable por esta función:
--     un cambio de trayecto implica crear una nueva ruta y desactivar la anterior.
--   La validación de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   los constraints de la BD actúan como última barrera.
--
-- Parámetros (IN):
--   wid_route             tab_routes.id_route%TYPE              — ID de la ruta a actualizar
--   wname_route           tab_routes.name_route%TYPE            — Nuevo nombre
--   wcolor_route          tab_routes.color_route%TYPE           — Color hex (#RRGGBB)
--   wid_company           tab_routes.id_company%TYPE            — FK a tab_companies
--   wuser_update          tab_routes.user_update%TYPE           — Usuario que realiza el cambio
--   wdescrip_route        tab_routes.descrip_route%TYPE         DEFAULT NULL
--   wfirst_trip           tab_routes.first_trip%TYPE            DEFAULT NULL
--   wlast_trip            tab_routes.last_trip%TYPE             DEFAULT NULL
--   wdeparture_route_sign tab_routes.departure_route_sign%TYPE  DEFAULT NULL
--   wreturn_route_sign    tab_routes.return_route_sign%TYPE     DEFAULT NULL
--
-- Retorna (OUT):
--   success       BOOLEAN                    — TRUE si se actualizó correctamente
--   msg           TEXT                       — Mensaje descriptivo
--   error_code    VARCHAR(50)                — NULL si éxito; código si falla
--   out_id_route  tab_routes.id_route%TYPE   — ID de la ruta actualizada (NULL si falla)
--
-- Códigos de error:
--   ROUTE_NOT_FOUND       — El id_route no existe en tab_routes
--   ROUTE_FK_VIOLATION    — FK inválida (compañía o usuario no existe)
--   ROUTE_CHECK_VIOLATION — color inválido o first_trip >= last_trip
--   ROUTE_UPDATE_ERROR    — Error inesperado
--
-- Campos NO actualizables por esta función:
--   id_route (PK), path_route, is_active, created_at, user_create
--
-- Versión   : 1.3
-- Fecha     : 2026-04-17
-- =============================================

DROP FUNCTION IF EXISTS fun_update_route(SMALLINT, VARCHAR, VARCHAR, SMALLINT, SMALLINT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_update_route(
  wid_route              tab_routes.id_route%TYPE,
  wname_route            tab_routes.name_route%TYPE,
  wcolor_route           tab_routes.color_route%TYPE,
  wid_company            tab_routes.id_company%TYPE,
  wuser_update           tab_routes.user_update%TYPE,
  wdescrip_route         tab_routes.descrip_route%TYPE         DEFAULT NULL,
  wfirst_trip            tab_routes.first_trip%TYPE            DEFAULT NULL,
  wlast_trip             tab_routes.last_trip%TYPE             DEFAULT NULL,
  wdeparture_route_sign  tab_routes.departure_route_sign%TYPE  DEFAULT NULL,
  wreturn_route_sign     tab_routes.return_route_sign%TYPE     DEFAULT NULL,
  wroute_fare            tab_routes.route_fare%TYPE            DEFAULT 0,
  wis_circular           BOOLEAN                               DEFAULT TRUE,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_route  tab_routes.id_route%TYPE
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

  UPDATE tab_routes SET
    name_route            = TRIM(wname_route),
    color_route           = UPPER(TRIM(wcolor_route)),
    id_company            = wid_company,
    descrip_route         = NULLIF(TRIM(wdescrip_route), ''),
    first_trip            = wfirst_trip,
    last_trip             = wlast_trip,
    departure_route_sign  = NULLIF(TRIM(wdeparture_route_sign), ''),
    return_route_sign     = NULLIF(TRIM(wreturn_route_sign), ''),
    route_fare            = GREATEST(wroute_fare, 0),
    is_circular           = COALESCE(wis_circular, FALSE),
    updated_at            = NOW(),
    user_update           = wuser_update
  WHERE id_route = wid_route
  RETURNING id_route INTO v_id_route;

  IF v_id_route IS NULL THEN
    msg        := 'Ruta no encontrada (ID: ' || wid_route || ')';
    error_code := 'ROUTE_NOT_FOUND';
    RETURN;
  END IF;

  out_id_route := v_id_route;
  success      := TRUE;
  msg          := 'Ruta (ID: ' || out_id_route || ') actualizada exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Compañía o usuario no existe: ' || SQLERRM;
    error_code := 'ROUTE_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Valor fuera de rango (color inválido o first_trip >= last_trip): ' || SQLERRM;
    error_code := 'ROUTE_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_route(SMALLINT, VARCHAR, VARCHAR, SMALLINT, SMALLINT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN) IS
'v1.2 — Actualiza los metadatos de una ruta (tab_routes), incluyendo route_fare (tarifa) e is_circular (circuito cerrado). path_route es inmutable.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar nombre y color
SELECT * FROM fun_update_route(
  1,                        -- id_route
  'Ruta 18 - Cabecera v2',  -- name_route
  '#764ba2',                -- color_route
  1,                        -- id_company
  2,                        -- user_update
  'Descripción actualizada',
  '05:00:00',
  '23:00:00',
  'CABECERA → CENTRO',
  'CENTRO → CABECERA'
);
-- success | msg                                | error_code | out_id_route
-- TRUE    | Ruta (ID: 1) actualizada exitosamente | NULL    | 1

-- Error: ID no existe
-- success | msg                         | error_code      | out_id_route
-- FALSE   | Ruta no encontrada (ID: 99) | ROUTE_NOT_FOUND | NULL

*/

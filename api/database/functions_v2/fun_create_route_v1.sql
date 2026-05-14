-- =============================================
-- FUNCIÓN: fun_create_route v1.3
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea una nueva ruta en tab_routes.
--   path_route se recibe como GeoJSON TEXT y se convierte internamente a GEOMETRY(SRID 4326).
--   La validación de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   los constraints de la BD actúan como última barrera.
--
-- Parámetros obligatorios (IN):
--   wname_route    tab_routes.name_route%TYPE  — Nombre de la ruta
--   wpath_route    TEXT                         — GeoJSON LineString con el trayecto
--   wcolor_route   tab_routes.color_route%TYPE  — Color hex (#RRGGBB) para la UI
--   wid_company    tab_routes.id_company%TYPE   — FK a tab_companies
--   wuser_create   tab_routes.user_create%TYPE  — Usuario que crea el registro
--
-- Parámetros opcionales (IN):
--   wdescrip_route        tab_routes.descrip_route%TYPE        DEFAULT NULL
--   wfirst_trip           tab_routes.first_trip%TYPE           DEFAULT NULL
--   wlast_trip            tab_routes.last_trip%TYPE            DEFAULT NULL
--   wdeparture_route_sign tab_routes.departure_route_sign%TYPE DEFAULT NULL
--   wreturn_route_sign    tab_routes.return_route_sign%TYPE    DEFAULT NULL
--   wroute_fare           tab_routes.route_fare%TYPE           DEFAULT 0
--   wis_circular          BOOLEAN                              DEFAULT FALSE
--
-- Retorna (OUT):
--   success       BOOLEAN                      — TRUE si se creó correctamente
--   msg           TEXT                         — Mensaje descriptivo
--   error_code    VARCHAR(50)                  — NULL si éxito; código si falla
--   out_id_route  tab_routes.id_route%TYPE     — ID generado (NULL si falla)
--
-- Códigos de error:
--   ROUTE_FK_VIOLATION    — FK inválida (compañía o usuario no existe)
--   ROUTE_CHECK_VIOLATION — color inválido o first_trip >= last_trip
--   ROUTE_GEOM_ERROR      — GeoJSON de path_route inválido
--   ROUTE_INSERT_ERROR    — Error inesperado
--
-- Versión   : 1.3
-- Fecha     : 2026-04-17
-- =============================================

DROP FUNCTION IF EXISTS fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, TEXT, TEXT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_create_route(
  wname_route            tab_routes.name_route%TYPE,
  wpath_route            TEXT,                                          -- GeoJSON LineString
  wcolor_route           tab_routes.color_route%TYPE,
  wid_company            tab_routes.id_company%TYPE,
  wuser_create           tab_routes.user_create%TYPE,
  wdescrip_route         tab_routes.descrip_route%TYPE        DEFAULT NULL,
  wfirst_trip            tab_routes.first_trip%TYPE           DEFAULT NULL,
  wlast_trip             tab_routes.last_trip%TYPE            DEFAULT NULL,
  wdeparture_route_sign  tab_routes.departure_route_sign%TYPE DEFAULT NULL,
  wreturn_route_sign     tab_routes.return_route_sign%TYPE    DEFAULT NULL,
  wroute_fare            tab_routes.route_fare%TYPE           DEFAULT 0,
  wis_circular           BOOLEAN                              DEFAULT TRUE,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_route  tab_routes.id_route%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_path_geom   GEOMETRY(LineString, 4326);
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_route := NULL;

  -- Convertir GeoJSON → GEOMETRY
  BEGIN
    v_path_geom := ST_SetSRID(ST_GeomFromGeoJSON(wpath_route), 4326);
  EXCEPTION WHEN OTHERS THEN
    msg        := 'GeoJSON de path_route inválido: ' || SQLERRM;
    error_code := 'ROUTE_GEOM_ERROR';
    RETURN;
  END;

  INSERT INTO tab_routes (
    name_route,
    path_route,
    descrip_route,
    color_route,
    id_company,
    first_trip,
    last_trip,
    departure_route_sign,
    return_route_sign,
    route_fare,
    is_circular,
    user_create
  ) VALUES (
    TRIM(wname_route),
    v_path_geom,
    NULLIF(TRIM(wdescrip_route), ''),
    UPPER(TRIM(wcolor_route)),
    wid_company,
    wfirst_trip,
    wlast_trip,
    NULLIF(TRIM(wdeparture_route_sign), ''),
    NULLIF(TRIM(wreturn_route_sign), ''),
    GREATEST(wroute_fare, 0),
    COALESCE(wis_circular, FALSE),
    wuser_create
  )
  RETURNING id_route INTO out_id_route;

  success := TRUE;
  msg     := 'Ruta creada exitosamente (ID: ' || out_id_route || ')';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Compañía o usuario no existe: ' || SQLERRM;
    error_code := 'ROUTE_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Valor fuera de rango (color inválido o first_trip >= last_trip): ' || SQLERRM;
    error_code := 'ROUTE_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN) IS
'v1.3 — Crea una ruta en tab_routes. Acepta path_route como GeoJSON TEXT. Recibe wroute_fare (tarifa) y wis_circular (circuito cerrado). Retorna out_id_route.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear ruta mínima (solo campos obligatorios)
SELECT * FROM fun_create_route(
  'Ruta 18 - Cabecera',
  '{"type":"LineString","coordinates":[[-73.1227,7.1193],[-73.1150,7.1300],[-73.1050,7.1400]]}',
  '#667eea',
  1,   -- id_company
  1    -- user_create
);
-- success | msg                              | error_code | out_id_route
-- TRUE    | Ruta creada exitosamente (ID: 1) | NULL       | 1

-- Crear ruta circular con todos los campos
SELECT * FROM fun_create_route(
  'Ruta 18 - Circular',
  '{"type":"LineString","coordinates":[[-73.1227,7.1193],[-73.1150,7.1300]]}',
  '#667eea',
  1,
  1,
  'Circuito desde Cabecera al Centro',
  '05:30:00',
  '22:00:00',
  'CABECERA → CENTRO',
  'CENTRO → CABECERA',
  2500,
  TRUE
);

-- Error: GeoJSON inválido
-- success | msg                              | error_code       | out_id_route
-- FALSE   | GeoJSON de path_route inválido   | ROUTE_GEOM_ERROR | NULL

*/

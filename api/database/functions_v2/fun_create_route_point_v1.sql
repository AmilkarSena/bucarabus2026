-- =============================================
-- FUNCIÓN: fun_create_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo punto de ruta en tab_route_points.
--   La validación de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   y los constraints de la BD actúan como última línea de defensa.
--
-- Parámetros obligatorios (IN):
--   wname_point    tab_route_points.name_point%TYPE   — Nombre descriptivo
--   wlat           DOUBLE PRECISION                   — Latitud  (WGS-84)
--   wlng           DOUBLE PRECISION                   — Longitud (WGS-84)
--
-- Parámetros opcionales (IN):
--   wpoint_type    tab_route_points.point_type%TYPE    — 1=Parada (DEFAULT), 2=Referencia
--   wdescrip_point tab_route_points.descrip_point%TYPE — Descripción adicional (DEFAULT NULL)
--   wis_checkpoint tab_route_points.is_checkpoint%TYPE — Punto de control (DEFAULT FALSE)
--   wuser_create   tab_route_points.user_create%TYPE   — Usuario creador (DEFAULT 1)
--
-- Retorna (OUT):
--   success        BOOLEAN                            — TRUE si se creó correctamente
--   msg            TEXT                               — Mensaje descriptivo
--   error_code     VARCHAR(50)                        — NULL si éxito; código si falla
--   out_id_point   tab_route_points.id_point%TYPE     — ID generado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_create_route_point(VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, SMALLINT, TEXT, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_route_point(
  wname_point     tab_route_points.name_point%TYPE,
  wlat            DOUBLE PRECISION,                           -- Latitud (sin columna directa; tabla almacena GEOMETRY)
  wlng            DOUBLE PRECISION,                           -- Longitud (ídem)
  wpoint_type     tab_route_points.point_type%TYPE    DEFAULT 1,
  wdescrip_point  tab_route_points.descrip_point%TYPE DEFAULT NULL,
  wis_checkpoint  tab_route_points.is_checkpoint%TYPE DEFAULT FALSE,
  wuser_create    tab_route_points.user_create%TYPE   DEFAULT 1,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_point  tab_route_points.id_point%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_point := NULL;

  INSERT INTO tab_route_points (
    point_type,
    name_point,
    location_point,
    descrip_point,
    is_checkpoint,
    user_create
  ) VALUES (
    wpoint_type,
    TRIM(wname_point),
    ST_SetSRID(ST_MakePoint(wlng, wlat), 4326),   -- PostGIS: MakePoint(lon, lat)
    NULLIF(TRIM(wdescrip_point), ''),
    wis_checkpoint,
    wuser_create
  )
  RETURNING id_point INTO out_id_point;

  success := TRUE;
  msg     := 'Punto de ruta creado exitosamente (ID: ' || out_id_point || ')';

EXCEPTION
  WHEN check_violation THEN
    msg        := 'Tipo de punto inválido (point_type debe ser 1 o 2): ' || SQLERRM;
    error_code := 'ROUTE_POINT_CHECK_VIOLATION';
  WHEN not_null_violation THEN
    msg        := 'Campo obligatorio nulo: ' || SQLERRM;
    error_code := 'ROUTE_POINT_NULL_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_route_point(VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, SMALLINT, TEXT, BOOLEAN, SMALLINT) IS
'v1.0 — Crea un punto de ruta en tab_route_points. Acepta lat/lng por separado y construye el GEOMETRY internamente con ST_MakePoint(lng, lat). Retorna out_id_point.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear parada normal (Terminal del Norte)
SELECT * FROM fun_create_route_point(
  'Terminal del Norte',                            -- name_point
  7.1248,                                          -- lat
  -73.1127,                                        -- lng
  1,                                               -- point_type = Parada
  'Parada principal frente al Terminal del Norte', -- descrip_point
  FALSE,                                           -- is_checkpoint
  1                                                -- user_create
);

-- Crear punto de referencia + checkpoint (mínimo: solo nombre + coords)
SELECT * FROM fun_create_route_point(
  'Glorieta Caracoli',
  7.0893,
  -73.1341,
  2,      -- Referencia
  NULL,
  TRUE    -- es punto de control
);

-- Resultado exitoso:
-- success | msg                                      | error_code | out_id_point
-- TRUE    | Punto de ruta creado exitosamente (ID:1) | NULL       | 1

-- Error: point_type inválido (ej. 3):
-- success | msg                                            | error_code                  | out_id_point
-- FALSE   | Tipo de punto inválido (point_type debe ...) | ROUTE_POINT_CHECK_VIOLATION | NULL

*/

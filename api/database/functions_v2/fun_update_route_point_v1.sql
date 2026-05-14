-- =============================================
-- FUNCIÓN: fun_update_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza los datos de un punto de ruta existente en tab_route_points.
--   El id_point se usa como identificador (PK) y nunca se modifica.
--   La validación de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   los constraints de la BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wid_point      tab_route_points.id_point%TYPE      — ID del punto a actualizar
--   wname_point    tab_route_points.name_point%TYPE     — Nuevo nombre
--   wlat           DOUBLE PRECISION                     — Nueva latitud  (WGS-84)
--   wlng           DOUBLE PRECISION                     — Nueva longitud (WGS-84)
--   wpoint_type    tab_route_points.point_type%TYPE     — Tipo: 1=Parada, 2=Referencia
--   wdescrip_point tab_route_points.descrip_point%TYPE  — Nueva descripción (DEFAULT NULL)
--   wis_checkpoint tab_route_points.is_checkpoint%TYPE  — Punto de control (DEFAULT FALSE)
--   wuser_update   tab_route_points.user_update%TYPE    — Usuario que realiza el cambio
--
-- Retorna (OUT):
--   success        BOOLEAN                              — TRUE si se actualizó correctamente
--   msg            TEXT                                 — Mensaje descriptivo
--   error_code     VARCHAR(50)                          — NULL si éxito; código si falla
--   out_id_point   tab_route_points.id_point%TYPE       — ID del punto actualizado (NULL si falla)
--
-- Códigos de error:
--   ROUTE_POINT_NOT_FOUND        — El id_point no existe en tab_route_points
--   ROUTE_POINT_CHECK_VIOLATION  — point_type fuera de rango (1 o 2)
--   ROUTE_POINT_FK_VIOLATION     — FK de user_update inválida
--   ROUTE_POINT_UPDATE_ERROR     — Error inesperado en el UPDATE
--
-- Campos NO actualizables por esta función:
--   id_point (PK), is_active, created_at, user_create
--
-- Versión   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_update_route_point(SMALLINT, VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, SMALLINT, TEXT, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_update_route_point(
  wid_point       tab_route_points.id_point%TYPE,
  wname_point     tab_route_points.name_point%TYPE,
  wlat            DOUBLE PRECISION,                            -- Latitud (sin columna directa en tab; almacena GEOMETRY)
  wlng            DOUBLE PRECISION,                            -- Longitud (ídem)
  wpoint_type     tab_route_points.point_type%TYPE,
  wdescrip_point  tab_route_points.descrip_point%TYPE  DEFAULT NULL,
  wis_checkpoint  tab_route_points.is_checkpoint%TYPE  DEFAULT FALSE,
  wuser_update    tab_route_points.user_update%TYPE     DEFAULT 1,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_point  tab_route_points.id_point%TYPE
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

  UPDATE tab_route_points SET
    name_point     = TRIM(wname_point),
    location_point = ST_SetSRID(ST_MakePoint(wlng, wlat), 4326),  -- PostGIS: MakePoint(lon, lat)
    point_type     = wpoint_type,
    descrip_point  = NULLIF(TRIM(wdescrip_point), ''),
    is_checkpoint  = wis_checkpoint,
    updated_at     = NOW(),
    user_update    = wuser_update
  WHERE id_point = wid_point
  RETURNING id_point INTO v_id_point;

  IF v_id_point IS NULL THEN
    msg        := 'Punto de ruta no encontrado (ID: ' || wid_point || ')';
    error_code := 'ROUTE_POINT_NOT_FOUND';
    RETURN;
  END IF;

  out_id_point := v_id_point;
  success      := TRUE;
  msg          := 'Punto de ruta actualizado exitosamente (ID: ' || out_id_point || ')';

EXCEPTION
  WHEN check_violation THEN
    msg        := 'Tipo de punto inválido (point_type debe ser 1 o 2): ' || SQLERRM;
    error_code := 'ROUTE_POINT_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave foránea inválida (user_update): ' || SQLERRM;
    error_code := 'ROUTE_POINT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_route_point(SMALLINT, VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, SMALLINT, TEXT, BOOLEAN, SMALLINT) IS
'v1.0 — Actualiza un punto de ruta en tab_route_points identificado por id_point. Usa RETURNING para detectar NOT FOUND. No modifica id_point, is_active, created_at ni user_create.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar nombre y coordenadas del punto ID=1
SELECT * FROM fun_update_route_point(
  1,                                               -- id_point
  'Terminal del Norte (actualizado)',              -- name_point
  7.1250,                                          -- lat
  -73.1130,                                        -- lng
  1,                                               -- point_type = Parada
  'Descripción actualizada',                       -- descrip_point
  TRUE,                                            -- is_checkpoint
  2                                                -- user_update
);

-- Resultado exitoso:
-- success | msg                                         | error_code | out_id_point
-- TRUE    | Punto de ruta actualizado exitosamente (ID:1) | NULL     | 1

-- Error: ID no existe
-- success | msg                                      | error_code               | out_id_point
-- FALSE   | Punto de ruta no encontrado (ID: 99)    | ROUTE_POINT_NOT_FOUND    | NULL

-- Error: point_type = 5
-- success | msg                                      | error_code                  | out_id_point
-- FALSE   | Tipo de punto inválido (point_type ...)  | ROUTE_POINT_CHECK_VIOLATION | NULL

*/

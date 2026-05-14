-- =============================================
-- FUNCIÓN: fun_create_route v2.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea una nueva ruta en tab_routes Y asigna sus paradas en tab_route_points_assoc
--   en una única transacción atómica (BEGIN...COMMIT implícito de PL/pgSQL).
--
--   Cambio respecto a v1: acepta un JSONB con el array de paradas ordenadas.
--   Si la inserción de cualquier parada falla, TODA la ruta se revierte (ROLLBACK).
--
-- Parámetros obligatorios (IN):
--   wname_route    VARCHAR   — Nombre de la ruta
--   wpath_route    TEXT      — GeoJSON LineString con el trayecto calculado por OSRM
--   wcolor_route   VARCHAR   — Color hex (#RRGGBB) para la UI
--   wid_company    SMALLINT  — FK a tab_companies
--   wuser_create   SMALLINT  — Usuario que crea el registro
--   wstops         JSONB     — Array de paradas en orden:
--                              [{ "id_point": 1, "dist_from_start": 0.0, "eta_seconds": 0 }, ...]
--                              dist_from_start y eta_seconds son opcionales (DEFAULT NULL).
--
-- Parámetros opcionales (IN):
--   wdescrip_route        TEXT      DEFAULT NULL
--   wfirst_trip           TIME      DEFAULT NULL
--   wlast_trip            TIME      DEFAULT NULL
--   wdeparture_route_sign VARCHAR   DEFAULT NULL
--   wreturn_route_sign    VARCHAR   DEFAULT NULL
--   wroute_fare           SMALLINT  DEFAULT 0
--   wis_circular          BOOLEAN   DEFAULT FALSE
--
-- Retorna (OUT):
--   success       BOOLEAN    — TRUE si se creó correctamente
--   msg           TEXT       — Mensaje descriptivo
--   error_code    VARCHAR(50)— NULL si éxito; código si falla
--   out_id_route  SMALLINT   — ID generado (NULL si falla)
--
-- Códigos de error:
--   ROUTE_FK_VIOLATION     — FK inválida (compañía o usuario no existe)
--   ROUTE_CHECK_VIOLATION  — color inválido o first_trip >= last_trip
--   ROUTE_GEOM_ERROR       — GeoJSON de path_route inválido
--   ROUTE_STOPS_EMPTY      — Array de paradas vacío o con menos de 2 puntos
--   ROUTE_STOP_INVALID     — id_point no existe o no está activo
--   ROUTE_STOP_ERROR       — Error al insertar una parada
--   ROUTE_INSERT_ERROR     — Error inesperado
--
-- Versión : 2.0
-- Fecha   : 2026-04-18
-- =============================================

DROP FUNCTION IF EXISTS fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, JSONB, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_create_route(
  wname_route            tab_routes.name_route%TYPE,
  wpath_route            TEXT,                                          -- GeoJSON LineString
  wcolor_route           tab_routes.color_route%TYPE,
  wid_company            tab_routes.id_company%TYPE,
  wuser_create           tab_routes.user_create%TYPE,
  wstops                 JSONB,                                         -- Array de paradas ordenadas
  wdescrip_route         tab_routes.descrip_route%TYPE        DEFAULT NULL,
  wfirst_trip            tab_routes.first_trip%TYPE           DEFAULT NULL,
  wlast_trip             tab_routes.last_trip%TYPE            DEFAULT NULL,
  wdeparture_route_sign  tab_routes.departure_route_sign%TYPE DEFAULT NULL,
  wreturn_route_sign     tab_routes.return_route_sign%TYPE    DEFAULT NULL,
  wroute_fare            tab_routes.route_fare%TYPE           DEFAULT 0,
  wis_circular           BOOLEAN                              DEFAULT FALSE,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_route  tab_routes.id_route%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_path_geom    GEOMETRY(LineString, 4326);
  v_stop         JSONB;
  v_id_point     SMALLINT;
  v_order        SMALLINT := 0;
  v_dist         NUMERIC;
  v_eta          INTEGER;
  v_stop_count   INTEGER;
  v_point_exists BOOLEAN;
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_route := NULL;

  -- ── Validar que hay al menos 2 paradas ───────────────────────────────────
  v_stop_count := jsonb_array_length(COALESCE(wstops, '[]'::JSONB));
  IF v_stop_count < 2 THEN
    msg        := 'Se requieren al menos 2 paradas para crear una ruta. Recibidas: ' || v_stop_count;
    error_code := 'ROUTE_STOPS_EMPTY';
    RETURN;
  END IF;

  -- ── Convertir GeoJSON → GEOMETRY ─────────────────────────────────────────
  BEGIN
    v_path_geom := ST_SetSRID(ST_GeomFromGeoJSON(wpath_route), 4326);
  EXCEPTION WHEN OTHERS THEN
    msg        := 'GeoJSON de path_route inválido: ' || SQLERRM;
    error_code := 'ROUTE_GEOM_ERROR';
    RETURN;
  END;

  -- ── Insertar la ruta en tab_routes ────────────────────────────────────────
  BEGIN
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

  EXCEPTION
    WHEN foreign_key_violation THEN
      msg        := 'Compañía o usuario no existe: ' || SQLERRM;
      error_code := 'ROUTE_FK_VIOLATION';
      RETURN;
    WHEN check_violation THEN
      msg        := 'Valor fuera de rango (color inválido o first_trip >= last_trip): ' || SQLERRM;
      error_code := 'ROUTE_CHECK_VIOLATION';
      RETURN;
    WHEN OTHERS THEN
      msg        := 'Error al insertar la ruta: ' || SQLERRM;
      error_code := 'ROUTE_INSERT_ERROR';
      RETURN;
  END;

  -- ── Insertar cada parada en tab_route_points_assoc ───────────────────────
  -- Iteramos el array JSONB en orden de índice (0-based).
  -- point_order empieza en 1.
  FOR v_stop IN SELECT * FROM jsonb_array_elements(wstops) LOOP

    v_order    := v_order + 1;
    v_id_point := (v_stop->>'id_point')::SMALLINT;
    v_dist     := NULLIF(v_stop->>'dist_from_start', '')::NUMERIC;
    v_eta      := NULLIF(v_stop->>'eta_seconds', '')::INTEGER;

    -- Verificar que el punto existe y está activo
    SELECT EXISTS (
      SELECT 1 FROM tab_route_points
      WHERE id_point = v_id_point
        AND is_active = TRUE
    ) INTO v_point_exists;

    IF NOT v_point_exists THEN
      msg        := 'La parada con id_point=' || v_id_point || ' no existe o está inactiva.';
      error_code := 'ROUTE_STOP_INVALID';
      -- Al retornar aquí sin COMMIT explícito, PL/pgSQL hace ROLLBACK automático
      -- de todo lo insertado en esta ejecución de la función.
      RAISE EXCEPTION 'ROUTE_STOP_INVALID: %', msg;
    END IF;

    BEGIN
      INSERT INTO tab_route_points_assoc (
        id_route,
        id_point,
        point_order,
        dist_from_start,
        eta_seconds
      ) VALUES (
        out_id_route,
        v_id_point,
        v_order,
        v_dist,
        v_eta
      );
    EXCEPTION
      WHEN unique_violation THEN
        msg        := 'Conflicto de orden en posición ' || v_order || ' para la ruta.';
        error_code := 'ROUTE_STOP_ERROR';
        RAISE EXCEPTION 'ROUTE_STOP_ERROR: %', msg;
      WHEN foreign_key_violation THEN
        msg        := 'FK inválida para parada id_point=' || v_id_point;
        error_code := 'ROUTE_STOP_ERROR';
        RAISE EXCEPTION 'ROUTE_STOP_ERROR: %', msg;
      WHEN OTHERS THEN
        msg        := 'Error insertando parada ' || v_order || ': ' || SQLERRM;
        error_code := 'ROUTE_STOP_ERROR';
        RAISE EXCEPTION 'ROUTE_STOP_ERROR: %', msg;
    END;

  END LOOP;

  success := TRUE;
  msg     := 'Ruta creada exitosamente con ' || v_stop_count || ' paradas (ID: ' || out_id_route || ')';

EXCEPTION
  WHEN OTHERS THEN
    -- El RAISE EXCEPTION dentro del loop aterriza aquí.
    -- success ya es FALSE y msg / error_code ya están seteados arriba.
    -- Si por alguna razón no lo están, los forzamos:
    IF error_code IS NULL THEN
      error_code := 'ROUTE_INSERT_ERROR';
      msg        := 'Error inesperado: ' || SQLERRM;
    END IF;
    out_id_route := NULL;
END;
$$;

COMMENT ON FUNCTION fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, JSONB, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN) IS
'v2.0 — Crea una ruta en tab_routes e inserta sus paradas en tab_route_points_assoc en una única transacción atómica.
wstops: JSONB array [{id_point, dist_from_start?, eta_seconds?}...] en el orden secuencial deseado.
Si cualquier parada falla, toda la ruta se revierte.';

-- =============================================
-- EJEMPLO DE USO
-- =============================================
/*
SELECT * FROM fun_create_route(
  'Ruta 18 - Cabecera → Centro',
  '{"type":"LineString","coordinates":[[-73.1227,7.1193],[-73.1150,7.1300],[-73.1050,7.1400]]}',
  '#667eea',
  1,    -- id_company
  1,    -- user_create
  '[{"id_point":1,"dist_from_start":0,"eta_seconds":0},{"id_point":5,"dist_from_start":1.2,"eta_seconds":180},{"id_point":9,"dist_from_start":3.4,"eta_seconds":420}]'::JSONB,
  'Descripción opcional',
  '05:30:00',
  '22:00:00',
  'CABECERA → CENTRO',
  'CENTRO → CABECERA',
  2500,
  FALSE
);
-- success | msg                                          | error_code | out_id_route
-- TRUE    | Ruta creada exitosamente con 3 paradas (ID: 7) | NULL    | 7
*/

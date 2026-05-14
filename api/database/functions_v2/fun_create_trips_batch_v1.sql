-- =============================================
-- FUNCIÓN: fun_create_trips_batch v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea múltiples viajes/turnos en lote a partir de un array JSONB.
--   id_trip se genera automáticamente (GENERATED ALWAYS AS IDENTITY).
--   La validación de formato y negocio es responsabilidad del backend (Node.js);
--   los constraints de la BD actúan como última barrera por viaje.
--   Un viaje fallido no aborta el resto del batch.
--
-- Parámetros obligatorios (IN):
--   wid_route      tab_trips.id_route%TYPE    — ID de la ruta (aplica a todos los viajes)
--   wtrip_date     tab_trips.trip_date%TYPE   — Fecha del viaje (aplica a todos)
--   wtrips         JSONB                      — Array de viajes a crear (ver estructura)
--   wuser_create   tab_trips.user_create%TYPE — Usuario que crea
--
-- Estructura del JSONB wtrips:
--   [
--     {
--       "start_time": "08:00:00",   -- obligatorio
--       "end_time":   "09:30:00",   -- obligatorio
--       "id_bus":     1,            -- opcional (FK tab_buses.id_bus)
--       "id_driver":  12345678,     -- opcional (FK tab_drivers.id_driver)
--       "id_status":  1             -- opcional (default 1=pending)
--     },
--     { ... }
--   ]
--
-- Retorna (OUT):
--   success        BOOLEAN      — TRUE si se creó al menos un viaje
--   msg            TEXT         — Mensaje descriptivo del resultado
--   error_code     VARCHAR(50)  — NULL si success = TRUE; código si falla total
--   trips_created  INTEGER      — Cantidad de viajes creados exitosamente
--   trips_failed   INTEGER      — Cantidad de viajes fallidos
--   trip_ids       INTEGER[]    — IDs de los viajes creados
--
-- Códigos de error (falla total):
--   TRIPS_ARRAY_EMPTY   — El array JSONB está vacío o es NULL
--   ALL_TRIPS_FAILED    — Todos los viajes fallaron (ver msg para detalles)
--
-- Códigos de error por viaje (en el campo msg cuando ALL_TRIPS_FAILED):
--   TRIP_UNIQUE      — Viaje duplicado (ruta + fecha + start_time ya existe activo)
--   TRIP_CHECK       — end_time <= start_time
--   TRIP_FK          — FK inválida (ruta, bus, conductor o estado no existe)
--   TRIP_ERROR       — Error inesperado al insertar
--
-- Versión   : 1.0
-- Fecha     : 2026-03-18
-- =============================================

-- Limpiar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_trips_batch(DECIMAL(3,0), DATE, JSONB, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_trips_batch(INTEGER, DATE, JSONB, INTEGER);
DROP FUNCTION IF EXISTS fun_create_trips_batch(SMALLINT, DATE, JSONB, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_trips_batch(
  wid_route      tab_trips.id_route%TYPE,
  wtrip_date     tab_trips.trip_date%TYPE,
  wtrips         JSONB,
  wuser_create   tab_trips.user_create%TYPE,

  OUT success        BOOLEAN,
  OUT msg            TEXT,
  OUT error_code     VARCHAR(50),
  OUT trips_created  INTEGER,
  OUT trips_failed   INTEGER,
  OUT trip_ids       INTEGER[]
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_trip     JSONB; -- Variable para iterar cada viaje del array
  v_index    INTEGER := 0;
  v_id_trip  tab_trips.id_trip%TYPE;
  v_ids      INTEGER[] := ARRAY[]::INTEGER[];
  v_created  INTEGER   := 0;
  v_failed   INTEGER   := 0;
  v_errors   TEXT      := '';
BEGIN
  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  trips_created := 0;
  trips_failed  := 0;
  trip_ids      := ARRAY[]::INTEGER[];

  -- Único check necesario: array vacío no lanza excepción pero no tiene
  -- resultado útil y el error_code sería engañoso sin este guard.
  IF wtrips IS NULL OR jsonb_array_length(wtrips) = 0 THEN
    msg        := 'El array de viajes no puede estar vacío';
    error_code := 'TRIPS_ARRAY_EMPTY';
    RETURN;
  END IF;

  FOR v_trip IN SELECT * FROM jsonb_array_elements(wtrips)
  LOOP
    v_index := v_index + 1;

    BEGIN

      INSERT INTO tab_trips (
        id_route,
        trip_date,
        start_time,
        end_time,
        id_bus,
        id_driver,
        id_status,
        is_active,
        created_at,
        user_create
      ) VALUES (
        wid_route,
        wtrip_date,
        (v_trip->>'start_time')::TIME,
        (v_trip->>'end_time')::TIME,
        (v_trip->>'id_bus')::SMALLINT,
        (v_trip->>'id_driver')::BIGINT,
        COALESCE((v_trip->>'id_status')::SMALLINT, 1),
        TRUE,
        NOW(),
        wuser_create
      )
      RETURNING id_trip INTO v_id_trip;

      v_ids    := array_append(v_ids, v_id_trip);
      v_created := v_created + 1;

    EXCEPTION
      WHEN unique_violation THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || '[#' || v_index || ' TRIP_UNIQUE] ' || SQLERRM || '; ';
      WHEN check_violation THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || '[#' || v_index || ' TRIP_CHECK] ' || SQLERRM || '; ';
      WHEN foreign_key_violation THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || '[#' || v_index || ' TRIP_FK] ' || SQLERRM || '; ';
      WHEN OTHERS THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || '[#' || v_index || ' TRIP_ERROR] ' || SQLERRM || '; ';
    END;

  END LOOP;

  trips_created := v_created;
  trips_failed  := v_failed;
  trip_ids      := v_ids;

  IF v_created > 0 THEN
    success := TRUE;
    msg     := v_created || ' viaje(s) creado(s) exitosamente';
    IF v_failed > 0 THEN
      msg := msg || ', ' || v_failed || ' fallido(s). ' || v_errors;
    END IF;
  ELSE
    success    := FALSE;
    msg        := 'No se pudo crear ningún viaje. ' || v_errors;
    error_code := 'ALL_TRIPS_FAILED';
  END IF;

END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_trips_batch(SMALLINT, DATE, JSONB, SMALLINT) IS
'v1.0 — Crea viajes en lote desde JSONB. id_trip por IDENTITY. Un viaje fallido no aborta el batch. '
'JSONB: [{start_time, end_time, id_bus?, id_driver?, id_status?}]. '
'Errores por viaje en campo msg: TRIP_UNIQUE, TRIP_CHECK, TRIP_FK, TRIP_ERROR. '
'Falla total: TRIPS_ARRAY_EMPTY, ALL_TRIPS_FAILED.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear 3 viajes pending (sin bus ni conductor):
SELECT * FROM fun_create_trips_batch(
  1, CURRENT_DATE,
  '[
    {"start_time": "08:00:00", "end_time": "09:30:00"},
    {"start_time": "10:00:00", "end_time": "11:30:00"},
    {"start_time": "14:00:00", "end_time": "15:30:00"}
  ]'::JSONB,
  1
);

-- Crear viajes con bus y conductor asignados (status=2):
SELECT * FROM fun_create_trips_batch(
  1, CURRENT_DATE,
  '[
    {"start_time": "06:00:00", "end_time": "07:30:00", "id_bus": 1, "id_driver": 12345678, "id_status": 2},
    {"start_time": "08:00:00", "end_time": "09:30:00", "id_bus": 2, "id_driver": 87654321, "id_status": 2}
  ]'::JSONB,
  1
);

-- Batch mixto (algunos fallan, el resto se crea):
SELECT * FROM fun_create_trips_batch(
  1, CURRENT_DATE,
  '[
    {"start_time": "12:00:00", "end_time": "13:30:00"},
    {"start_time": "14:00:00", "end_time": "13:00:00"},
    {"start_time": "16:00:00", "end_time": "17:30:00"}
  ]'::JSONB,
  1
);
-- El viaje #2 falla por TRIP_CHECK (end_time <= start_time), los otros se crean

*/

-- =============================================
-- FIN DE fun_create_trips_batch v1.0
-- =============================================

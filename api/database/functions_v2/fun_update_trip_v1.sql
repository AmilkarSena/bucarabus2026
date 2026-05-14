-- =============================================
-- FUNCION: fun_update_trip v2.0
-- Directorio: functions_v2
-- =============================================
-- Descripcion:
--   Actualiza un viaje existente en tab_trips.
--   Soporta actualizaciones parciales:
--     NULL en parametro opcional = mantener valor actual (via COALESCE sobre fila leida)
--     0 en wid_bus / wid_driver  = desasignar (set a NULL)
--   Gestiona automaticamente:
--     started_at   -> se graba al transicionar a id_status = 3 (activo), solo si aun es NULL
--     completed_at -> se graba al transicionar a id_status = 4 (completado), solo si aun es NULL
--   Para cancelar un viaje (status=5, is_active=FALSE) usar fun_cancel_trip.
--
-- Parametros obligatorios (IN):
--   wid_trip     INTEGER  - ID del viaje a actualizar
--   wuser_update SMALLINT - Usuario que realiza el cambio
--
-- Parametros opcionales (IN / DEFAULT NULL = sin cambio):
--   wid_route    SMALLINT - Nueva ruta
--   wtrip_date   DATE     - Nueva fecha
--   wstart_time  TIME     - Nueva hora de inicio
--   wend_time    TIME     - Nueva hora de fin
--   wid_bus      SMALLINT - Nuevo bus  (NULL = sin cambio, 0 = desasignar)
--   wid_driver   BIGINT   - Nuevo conductor (NULL = sin cambio, 0 = desasignar)
--   wid_status   SMALLINT - Nuevo estado (1=pendiente, 2=asignado, 3=activo, 4=completado)
--                           Para cancelar un viaje usar fun_cancel_trip.
--
-- Retorna (OUT):
--   success      BOOLEAN
--   msg          TEXT
--   error_code   VARCHAR(50)
--   out_id_trip  INTEGER
--
-- Codigos de error:
--   TRIP_NOT_FOUND        - El viaje no existe o ya esta inactivo
--   TRIP_STATUS_INVALID   - Se intento usar status 5 (usar fun_cancel_trip)
--   TRIP_UNIQUE_VIOLATION - Conflicto de bus/conductor en misma fecha y hora
--   TRIP_CHECK_VIOLATION  - end_time <= start_time u otro CHECK
--   TRIP_FK_VIOLATION     - Ruta, bus, conductor o estado inexistentes
--   TRIP_UPDATE_ERROR     - Error inesperado
--
-- Version : 2.0
-- Fecha   : 2026-03-18
-- =============================================

-- Limpiar versiones anteriores
DROP FUNCTION IF EXISTS fun_update_trip(INTEGER, SMALLINT, SMALLINT, DATE, TIME, TIME, SMALLINT, BIGINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_update_trip(INTEGER, INTEGER,  TIME,     TIME, VARCHAR, SMALLINT);

CREATE OR REPLACE FUNCTION fun_update_trip(
  wid_trip       tab_trips.id_trip%TYPE,
  wuser_update   tab_trips.user_update%TYPE,
  wid_route      tab_trips.id_route%TYPE    DEFAULT NULL,
  wtrip_date     tab_trips.trip_date%TYPE   DEFAULT NULL,
  wstart_time    tab_trips.start_time%TYPE  DEFAULT NULL,
  wend_time      tab_trips.end_time%TYPE    DEFAULT NULL,
  wid_bus        tab_trips.id_bus%TYPE      DEFAULT NULL,
  wid_driver     tab_trips.id_driver%TYPE   DEFAULT NULL,
  wid_status     tab_trips.id_status%TYPE   DEFAULT NULL,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT out_id_trip tab_trips.id_trip%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_cur   tab_trips%ROWTYPE;
  v_rows  INTEGER;
BEGIN

  success     := FALSE;
  msg         := '';
  error_code  := NULL;
  out_id_trip := NULL;

  -- Leer fila actual para COALESCE y timestamps automaticos
  SELECT * INTO v_cur
  FROM tab_trips
  WHERE id_trip = wid_trip AND is_active = TRUE;

  IF NOT FOUND THEN
    msg        := 'Viaje no encontrado o inactivo (ID: ' || wid_trip || ')';
    error_code := 'TRIP_NOT_FOUND';
    RETURN;
  END IF;

  -- Prevenir uso incorrecto: cancelacion se hace con fun_cancel_trip
  IF wid_status = 5 THEN
    msg        := 'Para cancelar un viaje usar fun_cancel_trip';
    error_code := 'TRIP_STATUS_INVALID';
    RETURN;
  END IF;

  UPDATE tab_trips SET
    id_route    = COALESCE(wid_route,   v_cur.id_route),
    trip_date   = COALESCE(wtrip_date,  v_cur.trip_date),
    start_time  = COALESCE(wstart_time, v_cur.start_time),
    end_time    = COALESCE(wend_time,   v_cur.end_time),

    -- NULL = sin cambio | 0 = desasignar | >0 = asignar
    id_bus      = CASE
                    WHEN wid_bus IS NULL THEN v_cur.id_bus
                    WHEN wid_bus = 0    THEN NULL
                    ELSE wid_bus
                  END,
    id_driver   = CASE
                    WHEN wid_driver IS NULL THEN v_cur.id_driver
                    WHEN wid_driver = 0    THEN NULL
                    ELSE wid_driver
                  END,

    id_status   = COALESCE(wid_status, v_cur.id_status),

    -- Timestamps operacionales automaticos
    started_at   = CASE
                     WHEN wid_status = 3 AND v_cur.started_at IS NULL THEN NOW()
                     ELSE v_cur.started_at
                   END,
    completed_at = CASE
                     WHEN wid_status = 4 AND v_cur.completed_at IS NULL THEN NOW()
                     ELSE v_cur.completed_at
                   END,

    updated_at  = NOW(),
    user_update = wuser_update

  WHERE id_trip = wid_trip;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'No se pudo actualizar el viaje (ID: ' || wid_trip || ')';
    error_code := 'TRIP_NOT_FOUND';
    RETURN;
  END IF;

  success     := TRUE;
  out_id_trip := wid_trip;
  msg         := 'Viaje actualizado exitosamente (ID: ' || wid_trip || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Conflicto: bus o conductor ya tienen un viaje en esa fecha/hora: ' || SQLERRM;
    error_code := 'TRIP_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restriccion CHECK violada (ej: end_time > start_time): ' || SQLERRM;
    error_code := 'TRIP_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Ruta, bus, conductor o estado no encontrados: ' || SQLERRM;
    error_code := 'TRIP_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'TRIP_UPDATE_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_update_trip(INTEGER, SMALLINT, SMALLINT, DATE, TIME, TIME, SMALLINT, BIGINT, SMALLINT) IS
'v2.0 - Actualiza viaje con soporte parcial (NULL=sin cambio, 0=desasignar id_bus/id_driver). Gestiona started_at en status=3 y completed_at en status=4. Para cancelar usar fun_cancel_trip.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Cambiar solo el estado a activo (inicia turno) -> graba started_at
SELECT * FROM fun_update_trip(42, 1, wid_status => 3);

-- Cambiar solo el estado a completado -> graba completed_at
SELECT * FROM fun_update_trip(42, 1, wid_status => 4);

-- Cancelar viaje -> usar fun_cancel_trip
-- SELECT * FROM fun_cancel_trip(42, 1, 'Viaje cancelado por operaciones', FALSE);

-- Asignar bus y conductor, cambiar a asignado
SELECT * FROM fun_update_trip(42, 1, wid_bus => 3::SMALLINT, wid_driver => 1015432876, wid_status => 2);

-- Cambiar horario sin tocar status
SELECT * FROM fun_update_trip(42, 1,
  wstart_time => '06:00'::TIME,
  wend_time   => '07:30'::TIME
);

-- Desasignar bus (0 = set NULL en BD), volver a pendiente
SELECT * FROM fun_update_trip(42, 1, wid_bus => 0::SMALLINT, wid_status => 1);

*/

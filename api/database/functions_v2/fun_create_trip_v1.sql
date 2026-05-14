-- =============================================
-- FUNCIÓN: fun_create_trip v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo viaje (turno) en tab_trips.
--   id_trip se genera automáticamente (GENERATED ALWAYS AS IDENTITY).
--   La validación de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   los constraints de la BD actúan como última barrera.
--
-- Parámetros obligatorios (IN):
--   wid_route      tab_trips.id_route%TYPE    — ID de la ruta
--   wtrip_date     tab_trips.trip_date%TYPE   — Fecha del viaje
--   wstart_time    tab_trips.start_time%TYPE  — Hora de inicio
--   wend_time      tab_trips.end_time%TYPE    — Hora de fin
--   wuser_create   tab_trips.user_create%TYPE — Usuario que crea
--
-- Parámetros opcionales (IN):
--   wid_bus        tab_trips.id_bus%TYPE      DEFAULT NULL — ID interno del bus (FK tab_buses.id_bus)
--   wid_driver     tab_trips.id_driver%TYPE   DEFAULT NULL — Cédula del conductor (FK tab_drivers.id_driver)
--   wid_status     tab_trips.id_status%TYPE   DEFAULT 1    — Estado inicial (1=pending)
--
-- Retorna (OUT):
--   success        BOOLEAN                   — TRUE si se creó correctamente
--   msg            TEXT                      — Mensaje descriptivo
--   error_code     VARCHAR(50)               — NULL si éxito; código si falla
--   out_id_trip    tab_trips.id_trip%TYPE    — ID generado (NULL si falla)
--
-- Códigos de error:
--   TRIP_UNIQUE_VIOLATION — Viaje duplicado (ruta + fecha + hora ya existe)
--   TRIP_CHECK_VIOLATION  — end_time <= start_time (violación de chk_trips_times)
--   TRIP_FK_VIOLATION     — FK inválida (ruta, bus, conductor o usuario no existe)
--   TRIP_INSERT_ERROR     — Error inesperado
--
-- Versión   : 1.0
-- Fecha     : 2026-03-17
-- =============================================

-- Limpiar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_trip(INTEGER, DATE, TIME, TIME, INTEGER, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_trip(INTEGER, DATE, TIME, TIME, INTEGER, VARCHAR, INTEGER, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_trip(SMALLINT, DATE, TIME, TIME, SMALLINT, SMALLINT, BIGINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_trip(SMALLINT, DATE, TIME, TIME, SMALLINT, SMALLINT, BIGINT, SMALLINT, BOOLEAN, TEXT, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION fun_create_trip(
  wid_route      tab_trips.id_route%TYPE,
  wtrip_date     tab_trips.trip_date%TYPE,
  wstart_time    tab_trips.start_time%TYPE,
  wend_time      tab_trips.end_time%TYPE,
  wuser_create   tab_trips.user_create%TYPE,
  wid_bus        tab_trips.id_bus%TYPE      DEFAULT NULL,
  wid_driver     tab_trips.id_driver%TYPE   DEFAULT NULL,
  wid_status     tab_trips.id_status%TYPE   DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT out_id_trip tab_trips.id_trip%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success     := FALSE;
  msg         := '';
  error_code  := NULL;
  out_id_trip := NULL;

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
    wstart_time,
    wend_time,
    wid_bus,
    wid_driver,
    wid_status,
    TRUE,
    NOW(),
    wuser_create
  )
  RETURNING id_trip INTO out_id_trip;

  success := TRUE;
  msg     := 'Viaje creado exitosamente (ID: ' || out_id_trip || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe un viaje para esa ruta, fecha y hora de inicio: ' || SQLERRM;
    error_code := 'TRIP_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'La hora de fin debe ser posterior a la hora de inicio: ' || SQLERRM;
    error_code := 'TRIP_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Referencia inválida (ruta, bus, conductor o usuario no existe): ' || SQLERRM;
    error_code := 'TRIP_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'TRIP_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_trip(SMALLINT, DATE, TIME, TIME, SMALLINT, SMALLINT, BIGINT, SMALLINT) IS
'v1.0 — Crea un viaje en tab_trips. id_trip generado por IDENTITY automáticamente. Validación de negocio delegada al backend y constraints de BD. Códigos de error: TRIP_UNIQUE_VIOLATION, TRIP_CHECK_VIOLATION, TRIP_FK_VIOLATION, TRIP_INSERT_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Ejemplo 1: Viaje básico (solo ruta, fecha y horario)
SELECT * FROM fun_create_trip(
  1,              -- id_route
  CURRENT_DATE,   -- trip_date
  '08:00:00',     -- start_time
  '09:30:00',     -- end_time
  1               -- user_create
);
-- success | msg                              | error_code | out_id_trip
-- TRUE    | Viaje creado exitosamente (ID:1) | NULL       | 1


-- Ejemplo 2: Viaje asignado (con bus y conductor)
SELECT * FROM fun_create_trip(
  1,              -- id_route
  CURRENT_DATE,   -- trip_date
  '10:00:00',     -- start_time
  '11:30:00',     -- end_time
  1,              -- user_create
  3,              -- id_bus   (id interno del bus en tab_buses)
  10005678901,    -- id_driver (cédula del conductor en tab_drivers)
  2               -- id_status (2=assigned)
);
-- success | msg                              | error_code | out_id_trip
-- TRUE    | Viaje creado exitosamente (ID:2) | NULL       | 2


-- Ejemplo 3: ERROR — hora fin anterior a hora inicio (CHECK constraint)
SELECT * FROM fun_create_trip(
  1, CURRENT_DATE, '10:00:00', '09:00:00', 1
);
-- success | msg                                          | error_code          | out_id_trip
-- FALSE   | La hora de fin debe ser posterior a la de.. | TRIP_CHECK_VIOLATION| NULL


-- Ejemplo 4: ERROR — ruta inexistente (FK constraint)
SELECT * FROM fun_create_trip(
  999, CURRENT_DATE, '08:00:00', '09:30:00', 1
);
-- success | msg                                 | error_code         | out_id_trip
-- FALSE   | Referencia inválida (ruta, bus,..)  | TRIP_FK_VIOLATION  | NULL


-- Ejemplo 5: ERROR — viaje duplicado (ruta+fecha+hora)
SELECT * FROM fun_create_trip(
  1, CURRENT_DATE, '08:00:00', '09:30:00', 1  -- misma combinación que ejemplo 1
);
-- success | msg                                   | error_code               | out_id_trip
-- FALSE   | Ya existe un viaje para esa ruta,...  | TRIP_UNIQUE_VIOLATION    | NULL


-- Ejemplo 6: Verificar viaje creado
SELECT
  t.id_trip,
  r.name_route,
  t.trip_date,
  t.start_time,
  t.end_time,
  b.amb_code  AS bus_code,
  d.name_driver,
  ts.status_name
FROM tab_trips t
JOIN tab_routes r           ON t.id_route  = r.id_route
JOIN tab_trip_statuses ts   ON t.id_status = ts.id_status
LEFT JOIN tab_buses b       ON t.id_bus    = b.id_bus
LEFT JOIN tab_drivers d     ON t.id_driver = d.id_driver
WHERE t.id_trip = 1;

*/

-- =============================================
-- FIN DE LA FUNCIÓN fun_create_trip v1.0
-- =============================================

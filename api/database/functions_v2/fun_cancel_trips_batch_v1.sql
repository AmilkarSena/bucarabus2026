-- =============================================
-- FUNCIÓN: fun_cancel_trips_batch v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Cancela en lote todos los viajes activos de una ruta y fecha (soft delete).
--   La validación de negocio es responsabilidad del backend (Node.js);
--   los constraints de la BD actúan como última barrera.
--
-- Parámetros obligatorios (IN):
--   wid_route             tab_trips.id_route%TYPE    — ID de la ruta
--   wtrip_date            tab_trips.trip_date%TYPE   — Fecha de los viajes
--   wuser_cancel          tab_trips.user_update%TYPE — Usuario que cancela
--
-- Parámetros opcionales (IN):
--   wcancellation_reason  TEXT    DEFAULT NULL  — Motivo de cancelación
--   wforce_cancel_active  BOOLEAN DEFAULT FALSE — Si TRUE cancela también status=3 (en curso)
--
-- Retorna (OUT):
--   success               BOOLEAN      — TRUE si se canceló al menos un viaje
--   msg                   TEXT         — Mensaje descriptivo del resultado
--   error_code            VARCHAR(50)  — NULL si success = TRUE; código si falla
--   trips_cancelled       INTEGER      — Cantidad de viajes cancelados
--   trips_active_skipped  INTEGER      — Viajes en curso omitidos (wforce_cancel_active=FALSE)
--   cancelled_ids         INTEGER[]    — IDs de viajes cancelados
--
-- Códigos de error:
--   NO_TRIPS_CANCELLED  — El UPDATE no afectó ninguna fila (ya cancelados o no existen)
--   BATCH_FK_VIOLATION  — FK inválida en el UPDATE
--   BATCH_CANCEL_ERROR  — Error inesperado
--
-- Versión   : 1.0
-- Fecha     : 2026-03-18
-- =============================================

-- Limpiar versiones anteriores
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER);
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(SMALLINT, DATE, SMALLINT, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_cancel_trips_batch(
  wid_route             tab_trips.id_route%TYPE,
  wtrip_date            tab_trips.trip_date%TYPE,
  wuser_cancel          tab_trips.user_update%TYPE,
  wcancellation_reason  TEXT    DEFAULT NULL,
  wforce_cancel_active  BOOLEAN DEFAULT FALSE,

  OUT success               BOOLEAN,
  OUT msg                   TEXT,
  OUT error_code            VARCHAR(50),
  OUT trips_cancelled       INTEGER,
  OUT trips_active_skipped  INTEGER,
  OUT cancelled_ids         INTEGER[]
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_ids  INTEGER[];
BEGIN
  success              := FALSE;
  msg                  := '';
  error_code           := NULL;
  trips_cancelled      := 0;
  trips_active_skipped := 0;
  cancelled_ids        := ARRAY[]::INTEGER[];

  -- Cancelar viajes activos de la ruta/fecha que no estén ya en estado terminal.
  -- status=3 (en curso) solo se incluye si wforce_cancel_active = TRUE.
  UPDATE tab_trips
     SET id_status           = 5,
         is_active            = FALSE,
         completed_at         = NOW(),
         cancellation_reason  = COALESCE(wcancellation_reason, cancellation_reason),
         updated_at           = NOW(),
         user_update          = wuser_cancel
   WHERE id_route  = wid_route
     AND trip_date = wtrip_date
     AND is_active = TRUE
     AND id_status NOT IN (4, 5)
     AND (id_status != 3 OR wforce_cancel_active = TRUE)
  RETURNING id_trip
  INTO v_ids;

  -- Necesario: UPDATE sin filas no genera excepción; hay que chequearlo.
  GET DIAGNOSTICS trips_cancelled = ROW_COUNT;

  IF trips_cancelled = 0 THEN
    msg        := 'No hay viajes cancelables para la ruta ' || wid_route || ' en ' || wtrip_date;
    error_code := 'NO_TRIPS_CANCELLED';
    RETURN;
  END IF;

  -- Contar viajes en curso que quedaron omitidos (solo cuando no se forzó)
  IF NOT wforce_cancel_active THEN
    SELECT COUNT(*)
      INTO trips_active_skipped
      FROM tab_trips
     WHERE id_route  = wid_route
       AND trip_date = wtrip_date
       AND id_status = 3
       AND is_active = TRUE;
  END IF;

  cancelled_ids := v_ids;
  success       := TRUE;
  msg           := trips_cancelled || ' viaje(s) cancelado(s) en ruta ' || wid_route || ' para ' || wtrip_date;

  IF trips_active_skipped > 0 THEN
    msg := msg || '. ' || trips_active_skipped || ' viaje(s) en curso omitido(s)';
  END IF;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Referencia inválida al cancelar viajes: ' || SQLERRM;
    error_code := 'BATCH_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado al cancelar viajes: ' || SQLERRM;
    error_code := 'BATCH_CANCEL_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_cancel_trips_batch(SMALLINT, DATE, SMALLINT, TEXT, BOOLEAN) IS
'v1.0 — Cancela en lote los viajes activos de una ruta/fecha. '
'status=3 (en curso) solo se cancela con wforce_cancel_active=TRUE. '
'Errores: NO_TRIPS_CANCELLED, BATCH_FK_VIOLATION, BATCH_CANCEL_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Cancelar viajes pendientes/asignados (skip en curso):
SELECT * FROM fun_cancel_trips_batch(1, CURRENT_DATE, 1, 'Restructuración de horarios', FALSE);

-- Cancelar TODOS incluidos los en curso:
SELECT * FROM fun_cancel_trips_batch(1, CURRENT_DATE, 1, 'Emergencia: huelga de conductores', TRUE);

-- Sin motivo (opcional):
SELECT * FROM fun_cancel_trips_batch(1, CURRENT_DATE, 1);

*/

-- =============================================
-- FIN DE fun_cancel_trips_batch v1.0
-- =============================================

-- =============================================================================
-- fun_cancel_trip
-- Version   : 1.0
-- Descripcion: Cancela un viaje (soft delete):
--              - Pone id_status = 5 (cancelado)
--              - Pone is_active  = FALSE
--              - Registra completed_at = NOW()
--              - Registra razon de cancelacion si se proporciona
--
-- Parametros:
--   wid_trip              INTEGER  - ID del viaje a cancelar
--   wuser_cancel          SMALLINT - ID del usuario que cancela
--   wcancellation_reason  TEXT     - Razon de cancelacion (opcional)
--   wforce_cancel         BOOLEAN  - Si TRUE cancela aunque el viaje este activo
--                                    (status=3). Si FALSE rechaza viajes activos.
--
-- Retorna:
--   success    BOOLEAN - TRUE si se cancelo correctamente
--   msg        TEXT    - Mensaje descriptivo del resultado
--   error_code TEXT    - Codigo de error si success = FALSE, NULL si success
--
-- Codigos de error:
--   TRIP_NOT_FOUND      - El viaje no existe
--   TRIP_ALREADY_DONE   - El viaje ya fue completado (status=4), no se puede cancelar
--   TRIP_ALREADY_CANCEL - El viaje ya estaba cancelado (status=5 / is_active=FALSE)
--   TRIP_IN_PROGRESS    - El viaje esta en curso (status=3) y wforce_cancel=FALSE
--   TRIP_CANCEL_ERROR   - Error inesperado al cancelar
-- =============================================================================

DROP FUNCTION IF EXISTS fun_cancel_trip(INTEGER, SMALLINT, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trip(INTEGER, INTEGER, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_cancel_trip(
  wid_trip             INTEGER,
  wuser_cancel         SMALLINT,
  wcancellation_reason TEXT    DEFAULT NULL,
  wforce_cancel        BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(success BOOLEAN, msg TEXT, error_code TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_status  SMALLINT;
  v_is_active  BOOLEAN;
BEGIN
  -- Leer estado actual del viaje
  SELECT t.id_status, t.is_active
    INTO v_id_status, v_is_active
    FROM tab_trips t
   WHERE t.id_trip = wid_trip;

  IF NOT FOUND THEN
    msg        := 'Viaje no encontrado (ID: ' || wid_trip || ')';
    error_code := 'TRIP_NOT_FOUND';
    success    := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Verificar que no este ya cancelado
  IF v_id_status = 5 OR v_is_active = FALSE THEN
    msg        := 'El viaje ya fue cancelado anteriormente (ID: ' || wid_trip || ')';
    error_code := 'TRIP_ALREADY_CANCEL';
    success    := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Verificar que no este ya completado
  IF v_id_status = 4 THEN
    msg        := 'No se puede cancelar un viaje ya completado (ID: ' || wid_trip || ')';
    error_code := 'TRIP_ALREADY_DONE';
    success    := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Si esta en curso (status=3) requerir force_cancel
  IF v_id_status = 3 AND wforce_cancel = FALSE THEN
    msg        := 'El viaje esta en curso. Para cancelarlo usar wforce_cancel = TRUE';
    error_code := 'TRIP_IN_PROGRESS';
    success    := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Ejecutar cancelacion
  UPDATE tab_trips
     SET id_status            = 5,
         is_active             = FALSE,
         completed_at          = NOW(),
         cancellation_reason   = COALESCE(wcancellation_reason, cancellation_reason),
         updated_at            = NOW(),
         user_update           = wuser_cancel
   WHERE id_trip = wid_trip;

  success    := TRUE;
  msg        := 'Viaje cancelado correctamente (ID: ' || wid_trip || ')';
  error_code := NULL;
  RETURN NEXT;

EXCEPTION WHEN OTHERS THEN
  success    := FALSE;
  msg        := 'Error al cancelar viaje: ' || SQLERRM;
  error_code := 'TRIP_CANCEL_ERROR';
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION fun_cancel_trip(INTEGER, SMALLINT, TEXT, BOOLEAN) IS
  'Cancela un viaje: id_status=5, is_active=FALSE, completed_at=NOW(). '
  'Requiere wforce_cancel=TRUE para viajes en curso (status=3). '
  'Para actualizar datos del viaje sin cancelar usar fun_update_trip.';

-- =============================================================================
-- Ejemplos de uso
-- =============================================================================
-- Cancelar viaje pendiente/asignado:
-- SELECT * FROM fun_cancel_trip(42, 1, 'Conductor no disponible', FALSE);
--
-- Cancelar viaje en curso (requiere force):
-- SELECT * FROM fun_cancel_trip(42, 1, 'Emergencia operativa', TRUE);
--
-- Cancelar sin razon:
-- SELECT * FROM fun_cancel_trip(42, 1);

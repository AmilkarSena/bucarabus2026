-- =============================================
-- FUNCIÓN: fun_resolve_incident_v1.0
-- =============================================
-- Resuelve un incidente reportado por un conductor.
--
-- Parámetros IN:
--   wid_incident      INTEGER           — ID del incidente
--
-- OUT:
--   success           BOOLEAN
--   msg               TEXT
--   error_code        VARCHAR(50)
--
-- Códigos de error:
--   INCIDENT_NOT_FOUND   — id_incident no existe o ya está resuelto
--   INCIDENT_UPDATE_ERROR — error inesperado
-- =============================================

DROP FUNCTION IF EXISTS fun_resolve_incident(INTEGER);

CREATE OR REPLACE FUNCTION fun_resolve_incident(
  wid_trip_incident tab_trip_incidents.id_trip_incident%TYPE,

  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50)
)
LANGUAGE plpgsql AS $$
DECLARE
  v_updated INTEGER;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  UPDATE tab_trip_incidents
  SET 
    status_incident = 'resolved',
    resolved_at = NOW()
  WHERE 
    id_trip_incident = wid_trip_incident 
    AND status_incident = 'active';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    msg        := 'Incidente no encontrado o ya estaba resuelto.';
    error_code := 'INCIDENT_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Incidente marcado como resuelto exitosamente.';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_UPDATE_ERROR';
END;
$$;

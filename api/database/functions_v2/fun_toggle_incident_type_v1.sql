-- =============================================
-- FUNCIÓN: fun_toggle_incident_type v1.0
-- Directorio: functions_v2
-- =============================================
DROP FUNCTION IF EXISTS fun_toggle_incident_type(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_incident_type(
  wid_incident tab_incident_types.id_incident%TYPE,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_type   tab_incident_types.id_incident%TYPE,
  OUT out_name      tab_incident_types.name_incident%TYPE,
  OUT out_is_active tab_incident_types.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_type := NULL;
  out_name   := NULL;
  out_is_active := NULL;

  UPDATE tab_incident_types
  SET is_active = NOT is_active
  WHERE id_incident = wid_incident
  RETURNING id_incident, name_incident, is_active
  INTO out_id_type, out_name, out_is_active;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    msg        := 'Tipo de incidente no encontrado (ID: ' || wid_incident || ')';
    error_code := 'INCIDENT_TYPE_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Estado del tipo de incidente actualizado: ' || 
             CASE WHEN out_is_active THEN 'Activo' ELSE 'Inactivo' END;

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_TYPE_TOGGLE_ERROR';
END;
$$;

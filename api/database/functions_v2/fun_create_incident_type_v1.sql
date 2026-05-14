-- =============================================
-- FUNCIÓN: fun_create_incident_type v1.0
-- Directorio: functions_v2
-- =============================================
DROP FUNCTION IF EXISTS fun_create_incident_type(VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_incident_type(
  wname_incident tab_incident_types.name_incident%TYPE,
  wtag_incident  tab_incident_types.tag_incident%TYPE,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_type   tab_incident_types.id_incident%TYPE,
  OUT out_name      tab_incident_types.name_incident%TYPE,
  OUT out_tag       tab_incident_types.tag_incident%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_type := NULL;
  out_name   := NULL;
  out_tag    := NULL;

  INSERT INTO tab_incident_types (
    name_incident, tag_incident, is_active
  ) VALUES (
    INITCAP(TRIM(wname_incident)),
    LOWER(TRIM(wtag_incident)),
    TRUE
  )
  RETURNING id_incident, name_incident, tag_incident
  INTO out_id_type, out_name, out_tag;

  success := TRUE;
  msg     := 'Tipo de incidente creado exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe un incidente con ese nombre o tag: ' || SQLERRM;
    error_code := 'INCIDENT_TYPE_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_TYPE_INSERT_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_incident_type(VARCHAR, VARCHAR) IS
'v1.0 — Crea un tipo de incidente. Normaliza nombre con INITCAP y tag con LOWER.';

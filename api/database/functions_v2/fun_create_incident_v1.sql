-- =============================================
-- FUNCIÓN: fun_create_incident_v1.0
-- =============================================
-- Registra un incidente reportado por un conductor.
-- La validación de negocio (trip activo, tipo válido) es
-- responsabilidad del backend; los constraints de la BD
-- actúan como última barrera.
--
-- Parámetros IN:
--   wid_trip          INTEGER           — Viaje en curso
--   wid_incident      SMALLINT          — ID del tipo de incidente
--   wlat_incident     DECIMAL(10,7)     — Latitud GPS
--   wlng_incident     DECIMAL(10,7)     — Longitud GPS
--   wdescrip_incident TEXT DEFAULT NULL — Descripción libre
--
-- OUT:
--   success           BOOLEAN
--   msg               TEXT
--   error_code        VARCHAR(50)
--   out_id_trip_incident INTEGER
--
-- Códigos de error:
--   INCIDENT_FK_VIOLATION   — id_trip no existe
--   INCIDENT_CHECK_VIOLATION — tipo inválido
--   INCIDENT_INSERT_ERROR   — error inesperado
-- =============================================

DROP FUNCTION IF EXISTS fun_create_incident(INTEGER, VARCHAR, DECIMAL, DECIMAL, TEXT);

CREATE OR REPLACE FUNCTION fun_create_incident(
  wid_trip         tab_trip_incidents.id_trip%TYPE,
  wid_incident     tab_trip_incidents.id_incident%TYPE,
  wlat_incident    DECIMAL(10,7),
  wlng_incident    DECIMAL(10,7),
  wdescrip_incident tab_trip_incidents.descrip_incident%TYPE DEFAULT NULL,

  OUT success              BOOLEAN,
  OUT msg                  TEXT,
  OUT error_code           VARCHAR(50),
  OUT out_id_trip_incident tab_trip_incidents.id_trip_incident%TYPE
)
LANGUAGE plpgsql AS $$
BEGIN
  success              := FALSE;
  msg                  := '';
  error_code           := NULL;
  out_id_trip_incident := NULL;

  INSERT INTO tab_trip_incidents (
    id_trip, id_incident, descrip_incident,
    location_incident
  ) VALUES (
    wid_trip, wid_incident, wdescrip_incident,
    ST_SetSRID(ST_MakePoint(wlng_incident, wlat_incident), 4326)
  )
  RETURNING id_trip_incident INTO out_id_trip_incident;

  success := TRUE;
  msg     := 'Incidente registrado (ID: ' || out_id_trip_incident || ')';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'El viaje indicado no existe: ' || SQLERRM;
    error_code := 'INCIDENT_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Tipo de incidente o estado inválido: ' || SQLERRM;
    error_code := 'INCIDENT_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_INSERT_ERROR';
END;
$$;

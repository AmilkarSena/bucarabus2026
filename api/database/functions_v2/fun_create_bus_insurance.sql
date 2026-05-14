-- =============================================
-- FUNCIÓN: fun_create_bus_insurance v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea o reemplaza (Upsert) un seguro para un bus
--   en la tabla tab_bus_insurance.
--
-- Parámetros obligatorios (IN):
--   wid_bus            SMALLINT     — ID del bus
--   wid_insurance_type SMALLINT     — Tipo de seguro FK
--   wid_insurance      VARCHAR(50)  — Número de póliza
--   wid_insurer        SMALLINT     — Aseguradora FK
--   wstart_date_insu   DATE         — Fecha inicio
--   wend_date_insu     DATE         — Fecha fin
--   wuser_create       SMALLINT     — Usuario creador FK
--
-- Parámetros opcionales (IN):
--   wdoc_url           VARCHAR(500) — URL del documento
--
-- Retorna (OUT):
--   success      BOOLEAN      — TRUE si se registró correctamente
--   msg          TEXT         — Mensaje descriptivo
--   error_code   VARCHAR(50)  — NULL si éxito; código si falla
--
-- Versión   : 1.0
-- =============================================

DROP FUNCTION IF EXISTS fun_create_bus_insurance(SMALLINT, SMALLINT, VARCHAR, SMALLINT, DATE, DATE, SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_bus_insurance(
  wid_bus            tab_bus_insurance.id_bus%TYPE,
  wid_insurance_type tab_bus_insurance.id_insurance_type%TYPE,
  wid_insurance      tab_bus_insurance.id_insurance%TYPE,
  wid_insurer        tab_bus_insurance.id_insurer%TYPE,
  wstart_date_insu   tab_bus_insurance.start_date_insu%TYPE,
  wend_date_insu     tab_bus_insurance.end_date_insu%TYPE,
  wuser_create       tab_bus_insurance.user_create%TYPE,
  wdoc_url           tab_bus_insurance.doc_url%TYPE DEFAULT NULL,

  -- Parámetros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- Utiliza INSERT ... ON CONFLICT para remplazar en caso de que este bus
  -- ya tenga este tipo de seguro registrado
  INSERT INTO tab_bus_insurance (
    id_bus, id_insurance_type, id_insurance, id_insurer,
    start_date_insu, end_date_insu, doc_url, user_create
  ) VALUES (
    wid_bus,
    wid_insurance_type,
    UPPER(TRIM(wid_insurance)),
    wid_insurer,
    wstart_date_insu,
    wend_date_insu,
    NULLIF(TRIM(wdoc_url), ''),
    wuser_create
  )
  ON CONFLICT (id_bus, id_insurance_type) 
  DO UPDATE SET 
    id_insurance    = EXCLUDED.id_insurance,
    id_insurer      = EXCLUDED.id_insurer,
    start_date_insu = EXCLUDED.start_date_insu,
    end_date_insu   = EXCLUDED.end_date_insu,
    doc_url         = EXCLUDED.doc_url,
    user_update     = EXCLUDED.user_create,
    updated_at      = NOW();

  success := TRUE;
  msg     := 'Seguro registrado exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Esta póliza ya está registrada en otro bus: ' || SQLERRM;
    error_code := 'INSURANCE_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada (fechas inválidas): ' || SQLERRM;
    error_code := 'INSURANCE_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave foránea inválida (Bus, Tipo o Aseguradora no existen): ' || SQLERRM;
    error_code := 'INSURANCE_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INSURANCE_INSERT_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_bus_insurance(SMALLINT, SMALLINT, VARCHAR, SMALLINT, DATE, DATE, SMALLINT, VARCHAR) IS
'v1.0 — Crea o actualiza (Upsert) un seguro de bus. Si el bus ya tiene este tipo de seguro, lo sobreescribe.';

-- =============================================
-- FUNCIÓN: fun_update_bus v2.1
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza los datos de un bus existente en tab_buses.
--   La placa se usa como identificador de búsqueda (índice único) pero no se modifica.
--   El id_bus (PK surrogate GENERATED ALWAYS AS IDENTITY) nunca se modifica.
--   El estado (id_status/is_active) es gestionado por funciones separadas.
--   La validación de negocio es responsabilidad del backend (Node.js).
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros (IN):
--   wplate_number    VARCHAR(6)   — Placa del bus a actualizar (identificador, no se modifica)
--   wamb_code        VARCHAR(8)   — Código AMB nuevo
--   wcode_internal   VARCHAR(5)   — Código interno nuevo
--   wid_company      SMALLINT     — ID compañía FK
--   wmodel_year      SMALLINT     — Año modelo
--   wcapacity_bus    SMALLINT     — Pasajeros
--   wcolor_bus       VARCHAR(30)  — Color
--   wid_owner        BIGINT       — Cédula propietario FK
--   wuser_update     SMALLINT     — Usuario que realiza el cambio FK
--   wid_brand        SMALLINT     — ID marca FK (DEFAULT NULL)
--   wmodel_name      VARCHAR      — Modelo (DEFAULT 'SA')
--   wchassis_number  VARCHAR      — Chasis (DEFAULT 'SA')
--   wphoto_url       VARCHAR      — URL foto (DEFAULT NULL)
--   wgps_device_id   VARCHAR      — Dispositivo GPS (DEFAULT NULL)
--   wcolor_app       VARCHAR(7)   — Color hex para la app (DEFAULT '#CCCCCC')
--
-- Retorna (OUT):
--   success      BOOLEAN      — TRUE si se actualizó correctamente
--   msg          TEXT         — Mensaje descriptivo
--   error_code   VARCHAR(50)  — NULL si success = TRUE
--   out_id_bus   SMALLINT     — id_bus (PK) del bus actualizado
--   out_plate    VARCHAR(6)   — Placa del bus actualizado
--
-- Códigos de error:
--   BUS_NOT_FOUND        — La placa no existe en tab_buses
--   BUS_UNIQUE_VIOLATION — AMB, código interno o GPS duplicado
--   BUS_CHECK_VIOLATION  — Constraint CHECK violado
--   BUS_FK_VIOLATION     — FK inválida (compañía, propietario o usuario)
--   BUS_UPDATE_ERROR     — Error inesperado en el UPDATE
--
-- Campos NO actualizables por esta función:
--   id_bus (PK surrogate), plate_number, id_status, is_active, created_at, user_create
--
-- Versión   : 2.1
-- Fecha     : 2026-03-15
-- =============================================

DROP FUNCTION IF EXISTS fun_update_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_update_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_update_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_bus(
  wplate_number    tab_buses.plate_number%TYPE,
  wamb_code        tab_buses.amb_code%TYPE,
  wcode_internal   tab_buses.code_internal%TYPE,
  wid_company      tab_buses.id_company%TYPE,
  wmodel_year      tab_buses.model_year%TYPE,
  wcapacity_bus    tab_buses.capacity_bus%TYPE,
  wcolor_bus       tab_buses.color_bus%TYPE,
  wid_owner        tab_buses.id_owner%TYPE,
  wuser_update     tab_buses.user_update%TYPE,
  wid_brand        SMALLINT                                      DEFAULT NULL,
  wmodel_name      tab_buses.model_name%TYPE     DEFAULT 'SA',
  wchassis_number  tab_buses.chassis_number%TYPE DEFAULT 'SA',
  wphoto_url       tab_buses.photo_url%TYPE      DEFAULT NULL,
  wgps_device_id   tab_buses.gps_device_id%TYPE  DEFAULT NULL,
  wcolor_app       tab_buses.color_app%TYPE      DEFAULT '#CCCCCC',

  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_bus   tab_buses.id_bus%TYPE,
  OUT out_plate    tab_buses.plate_number%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_plate  tab_buses.plate_number%TYPE;
  v_id_bus tab_buses.id_bus%TYPE;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_bus := NULL;
  out_plate  := NULL;

  v_plate := UPPER(TRIM(wplate_number));

  UPDATE tab_buses SET
    amb_code       = NULLIF(UPPER(TRIM(wamb_code)), ''),
    code_internal  = NULLIF(TRIM(wcode_internal), ''),
    id_company     = wid_company,
    id_brand       = wid_brand,
    model_name     = COALESCE(NULLIF(TRIM(wmodel_name), ''), 'SA'),
    model_year     = wmodel_year,
    capacity_bus   = wcapacity_bus,
    chassis_number = COALESCE(NULLIF(UPPER(TRIM(wchassis_number)), ''), 'SA'),
    color_bus      = TRIM(wcolor_bus),
    color_app      = COALESCE(NULLIF(TRIM(wcolor_app), ''), '#CCCCCC'),
    photo_url      = NULLIF(TRIM(wphoto_url), ''),
    gps_device_id  = NULLIF(TRIM(wgps_device_id), ''),
    id_owner       = wid_owner,
    updated_at     = NOW(),
    user_update    = wuser_update
  WHERE plate_number = v_plate
  RETURNING id_bus INTO v_id_bus;

  IF v_id_bus IS NULL THEN
    msg        := 'Bus no encontrado con placa: ' || v_plate;
    error_code := 'BUS_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  out_id_bus := v_id_bus;
  out_plate  := v_plate;
  msg        := 'Bus actualizado exitosamente: ' || v_plate || ' (id_bus=' || v_id_bus || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'AMB, código interno o GPS ya registrado en otro bus: ' || SQLERRM;
    error_code := 'BUS_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada: ' || SQLERRM;
    error_code := 'BUS_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'FK inválida (compañía, propietario o usuario): ' || SQLERRM;
    error_code := 'BUS_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BUS_UPDATE_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_update_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS
'v2.1 — Actualiza bus en tab_buses. Busca por plate_number (único), retorna id_bus (PK surrogate). Normalización inline en SET. Validación delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar bus completo
SELECT * FROM fun_update_bus(
  'ABC123',           -- plate_number (identifica el bus, no se modifica)
  'AMB-0010',         -- amb_code nuevo
  'B001',             -- code_internal
  1,                  -- id_company
  2020,               -- model_year
  45,                 -- capacity_bus
  'Blanco y azul',    -- color_bus
  10000000,           -- id_owner
  1,                  -- wuser_update
  2,                  -- wid_brand
  'OF 1721',          -- model_name
  'CH123456789',      -- chassis_number
  NULL,               -- photo_url
  '352099001761481',  -- gps_device_id
  '#1A73E8'           -- color_app
);

-- Actualizar solo campos obligatorios (opcionales quedan en DEFAULT)
SELECT * FROM fun_update_bus(
  'ABC123',
  'SA',
  'B001',
  1,
  2020,
  45,
  'Rojo',
  10000000,
  1
);

-- Resultado exitoso:
-- success | msg                                              | error_code | out_id_bus | out_plate
-- TRUE    | Bus actualizado exitosamente: ABC123 (id_bus=3)  | NULL       | 3          | ABC123

-- Error: bus no encontrado
-- success | msg                                | error_code    | out_id_bus | out_plate
-- FALSE   | Bus no encontrado con placa: ZZZ999 | BUS_NOT_FOUND | NULL       | NULL

-- Error: AMB ya registrado en otro bus (UNIQUE constraint)
-- success | msg                                          | error_code           | out_id_bus | out_plate
-- FALSE   | AMB, código interno o GPS ya registrado...   | BUS_UNIQUE_VIOLATION | NULL       | NULL

*/
-- 
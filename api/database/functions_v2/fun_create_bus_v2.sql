-- =============================================
-- FUNCIÓN: fun_create_bus v2.1
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo bus en tab_buses.
--   Normaliza texto e inserta directamente.
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros obligatorios (IN):
--   wplate_number    VARCHAR(6)   — Placa del bus
--   wamb_code        VARCHAR(8)   — Código AMB
--   wcode_internal   VARCHAR(5)   — Código interno
--   wid_company      SMALLINT     — ID compañía FK
--   wmodel_year      SMALLINT     — Año modelo
--   wcapacity_bus    SMALLINT     — Pasajeros
--   wcolor_bus       VARCHAR(30)  — Color
--   wid_owner        BIGINT       — Cédula propietario FK
--   wuser_create     SMALLINT     — Usuario creador FK
--
-- Parámetros opcionales (IN):
--   wid_brand        SMALLINT     — Marca FK              (DEFAULT NULL)
--   wmodel_name      VARCHAR(50)  — Modelo                (DEFAULT 'SA')
--   wchassis_number  VARCHAR(50)  — Chasis                (DEFAULT 'SA')
--   wphoto_url       VARCHAR(500) — URL foto              (DEFAULT NULL)
--   wgps_device_id   VARCHAR(20)  — IMEI/ID dispositivo   (DEFAULT NULL)
--   wcolor_app       VARCHAR(7)   — Color hex para la app (DEFAULT '#CCCCCC')
--
-- Retorna (OUT):
--   success      BOOLEAN      — TRUE si se creó correctamente
--   msg          TEXT         — Mensaje descriptivo
--   error_code   VARCHAR(50)  — NULL si éxito; código si falla
--   out_id_bus   SMALLINT     — ID interno generado (NULL si falla)
--   out_plate    VARCHAR(6)   — Placa insertada (NULL si falla)
--
-- Versión   : 2.1
-- Fecha     : 2026-03-11
-- =============================================

DROP FUNCTION IF EXISTS fun_create_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_bus(
  wplate_number    tab_buses.plate_number%TYPE,
  wamb_code        tab_buses.amb_code%TYPE,
  wcode_internal   tab_buses.code_internal%TYPE,
  wid_company      tab_buses.id_company%TYPE,
  wmodel_year      tab_buses.model_year%TYPE,
  wcapacity_bus    tab_buses.capacity_bus%TYPE,
  wcolor_bus       tab_buses.color_bus%TYPE,
  wid_owner        tab_buses.id_owner%TYPE,
  wuser_create     tab_buses.user_create%TYPE,
  wid_brand        tab_buses.id_brand%TYPE       DEFAULT NULL,
  wmodel_name      tab_buses.model_name%TYPE     DEFAULT 'SA',
  wchassis_number  tab_buses.chassis_number%TYPE DEFAULT 'SA',
  wphoto_url       tab_buses.photo_url%TYPE      DEFAULT NULL,
  wgps_device_id   tab_buses.gps_device_id%TYPE  DEFAULT NULL,
  wcolor_app       tab_buses.color_app%TYPE      DEFAULT '#CCCCCC',

  -- Parámetros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_bus   tab_buses.id_bus%TYPE,
  OUT out_plate    tab_buses.plate_number%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_bus := NULL;
  out_plate  := NULL;

  INSERT INTO tab_buses (
    plate_number, amb_code, code_internal,
    id_company, id_brand, model_name, model_year, capacity_bus,
    chassis_number, color_bus, color_app, photo_url, gps_device_id,
    id_owner, id_status, is_active, created_at, user_create
  ) VALUES (
    UPPER(TRIM(wplate_number)),
    UPPER(TRIM(wamb_code)),
    UPPER(TRIM(wcode_internal)),
    wid_company,
    wid_brand,
    COALESCE(NULLIF(TRIM(wmodel_name),    ''), 'SA'),
    wmodel_year,
    wcapacity_bus,
    COALESCE(NULLIF(TRIM(wchassis_number),''), 'SA'),
    TRIM(wcolor_bus),
    COALESCE(NULLIF(TRIM(wcolor_app), ''), '#CCCCCC'),
    NULLIF(TRIM(wphoto_url),    ''),
    NULLIF(TRIM(wgps_device_id),''),
    wid_owner,
    1,
    TRUE,
    NOW(),
    wuser_create
  )
  RETURNING id_bus, plate_number
  INTO out_id_bus, out_plate;

  success   := TRUE;
  msg       := 'Bus creado exitosamente (Placa: ' || UPPER(TRIM(wplate_number)) || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Placa, código AMB, código interno o dispositivo GPS ya registrado: ' || SQLERRM;
    error_code := 'BUS_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada: ' || SQLERRM;
    error_code := 'BUS_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave foránea inválida: ' || SQLERRM;
    error_code := 'BUS_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BUS_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS
'v2.1 — Crea bus en tab_buses. Normaliza texto e inserta directamente; retorna out_id_bus y out_plate. Validación de negocio delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear bus completo con todos los datos
SELECT * FROM fun_create_bus(
  'ABC123',           -- plate_number
  'AMB-0001',         -- amb_code
  'B001',             -- code_internal
  1,                  -- id_company (Metrolínea)
  2019,               -- model_year
  45,                 -- capacity_bus
  'Amarillo y rojo',  -- color_bus
  10000000,           -- id_owner (cédula propietario)
  1,                  -- user_create
  'Mercedes-Benz',    -- brand_bus
  'OF 1721',          -- model_name
  'CH123456789',      -- chassis_number
  NULL,               -- photo_url
  '352099001761481'   -- gps_device_id (IMEI)
);

-- Crear bus mínimo (campos opcionales usan DEFAULT)
SELECT * FROM fun_create_bus(
  'XYZ789',
  'AMB-0002',
  'B002',
  2,
  2022,
  42,
  'Blanco',
  10000000,
  1
);

-- Resultado exitoso:
-- success | msg                                     | error_code | out_id_bus | out_plate
-- TRUE    | Bus creado exitosamente (Placa: ABC123) | NULL       | 101        | ABC123

-- Error: placa duplicada
-- success | msg                              | error_code           | out_id_bus | out_plate
-- FALSE   | Placa ... ya registrado         | BUS_UNIQUE_VIOLATION | NULL       | NULL

-- Error: GPS ya asignado a otro bus
-- success | msg                                            | error_code           | out_id_bus | out_plate
-- FALSE   | El dispositivo GPS 352099001761481 ya está ... | BUS_UNIQUE_VIOLATION | NULL       | NULL

*/

-- =============================================
-- FUNCIÓN: fun_create_driver v2.1
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo conductor en tab_drivers.
--   Normaliza texto e inserta directamente.
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros obligatorios (IN):
--   wid_driver         BIGINT       — Cédula del conductor (PK)
--   wname_driver       VARCHAR(100) — Nombre completo
--   wbirth_date        DATE         — Fecha de nacimiento
--   wlicense_exp       DATE         — Vencimiento de licencia
--   wuser_create       SMALLINT     — Usuario creador FK
--
-- Parámetros opcionales (IN / con DEFAULT):
--   waddress_driver    VARCHAR(200) — Dirección              (DEFAULT 'SIN DIRECCIÓN')
--   wphone_driver      VARCHAR(15)  — Teléfono               (DEFAULT '0900000000')
--   wemail_driver      VARCHAR(320) — Email                  (DEFAULT 'sa@sa.com')
--   wlicense_cat       VARCHAR(2)   — Cat. licencia          (DEFAULT 'SA')
--   wid_eps            SMALLINT     — EPS FK                 (DEFAULT 1)
--   wid_arl            SMALLINT     — ARL FK                 (DEFAULT 1)
--   wblood_type        VARCHAR(3)   — Tipo de sangre         (DEFAULT 'SA')
--   wemergency_contact VARCHAR(100) — Contacto emergencia    (DEFAULT 'SIN CONTACTO')
--   wemergency_phone   VARCHAR(15)  — Teléfono emergencia    (DEFAULT '0900000000')
--   wdate_entry        DATE         — Fecha ingreso          (DEFAULT CURRENT_DATE)
--   wid_status         SMALLINT     — Estado operativo FK    (DEFAULT 1)
--
-- Retorna (OUT):
--   success      BOOLEAN     — TRUE si se creó correctamente
--   msg          TEXT        — Mensaje descriptivo
--   error_code   VARCHAR(50) — NULL si éxito; código si falla
--   out_driver   BIGINT      — Cédula insertada (NULL si falla)
--
-- Versión   : 2.1  — Elimina wid_user (vínculo movido a tab_driver_accounts)
-- Fecha     : 2026-03-17
-- =============================================

-- Limpiar versiones anteriores (firmas v1 sobre esquema legacy)
DROP FUNCTION IF EXISTS fun_create_driver(VARCHAR, VARCHAR, VARCHAR, DECIMAL, VARCHAR, VARCHAR, DATE, VARCHAR, TEXT, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_driver(VARCHAR(320), VARCHAR(60), VARCHAR(100), DECIMAL(12,0), VARCHAR(15), VARCHAR(2), DATE, VARCHAR(500), TEXT, INTEGER);
DROP FUNCTION IF EXISTS fun_create_driver(VARCHAR, TEXT, VARCHAR, DECIMAL, VARCHAR, VARCHAR, DATE, VARCHAR, TEXT, INTEGER, VARCHAR, SMALLINT, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_driver(BIGINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_driver(BIGINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_driver(
  -- Parámetros en el mismo orden que las columnas de tab_drivers
  -- Campos de auditoría (user_create) al final
  wid_driver          tab_drivers.id_driver%TYPE,
  wname_driver        tab_drivers.name_driver%TYPE        DEFAULT 'SIN NOMBRE',
  waddress_driver     tab_drivers.address_driver%TYPE     DEFAULT 'SIN DIRECCIÓN',
  wphone_driver       tab_drivers.phone_driver%TYPE       DEFAULT '0900000000',
  wemail_driver       tab_drivers.email_driver%TYPE       DEFAULT 'sa@sa.com',
  wbirth_date         tab_drivers.birth_date%TYPE         DEFAULT '2000-01-01',
  wgender_driver      tab_drivers.gender_driver%TYPE      DEFAULT 'O',
  wlicense_cat        tab_drivers.license_cat%TYPE        DEFAULT 'SA',
  wlicense_exp        tab_drivers.license_exp%TYPE        DEFAULT '2000-01-01',
  wid_eps             tab_drivers.id_eps%TYPE             DEFAULT 1,
  wid_arl             tab_drivers.id_arl%TYPE             DEFAULT 1,
  wblood_type         tab_drivers.blood_type%TYPE         DEFAULT 'SA',
  wemergency_contact  tab_drivers.emergency_contact%TYPE  DEFAULT 'SIN CONTACTO',
  wemergency_phone    tab_drivers.emergency_phone%TYPE    DEFAULT '0900000000',
  wdate_entry         tab_drivers.date_entry%TYPE         DEFAULT CURRENT_DATE,
  wid_status          tab_drivers.id_status%TYPE          DEFAULT 1,
  wuser_create        tab_drivers.user_create%TYPE        DEFAULT 1,

  OUT success         BOOLEAN,
  OUT msg             TEXT,
  OUT error_code      VARCHAR(50),
  OUT out_driver      tab_drivers.id_driver%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_driver := NULL;

  INSERT INTO tab_drivers (
    id_driver, name_driver, address_driver, phone_driver, email_driver,
    birth_date, gender_driver, license_cat, license_exp, id_eps, id_arl, blood_type,
    emergency_contact, emergency_phone, date_entry, id_status,
    is_active, created_at, user_create
  ) VALUES (
    wid_driver,
    TRIM(wname_driver),
    COALESCE(NULLIF(TRIM(waddress_driver),         ''), 'SIN DIRECCIÓN'),
    COALESCE(NULLIF(TRIM(wphone_driver),           ''), '0900000000'),
    COALESCE(NULLIF(LOWER(TRIM(wemail_driver)),    ''), 'sa@sa.com'),
    COALESCE(wbirth_date, '2000-01-01'),
    COALESCE(NULLIF(UPPER(TRIM(wgender_driver)),          ''), 'O'),
    COALESCE(NULLIF(TRIM(wlicense_cat),            ''), 'SA'),
    COALESCE(wlicense_exp, '2000-01-01'),
    wid_eps,
    wid_arl,
    COALESCE(NULLIF(TRIM(wblood_type),             ''), 'SA'),
    COALESCE(NULLIF(TRIM(wemergency_contact),      ''), 'SIN CONTACTO'),
    COALESCE(NULLIF(TRIM(wemergency_phone),        ''), '0900000000'),
    COALESCE(wdate_entry, CURRENT_DATE),
    wid_status,
    TRUE,
    NOW(),
    wuser_create
  )
  RETURNING id_driver INTO out_driver;

  success    := TRUE;
  msg        := 'Conductor creado exitosamente (Cédula: ' || wid_driver || ')';


EXCEPTION
  WHEN unique_violation THEN
    msg        := 'La cédula o usuario de sistema ya existen: ' || SQLERRM;
    error_code := 'DRIVER_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave foránea inválida: ' || SQLERRM;
    error_code := 'DRIVER_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada: ' || SQLERRM;
    error_code := 'DRIVER_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'DRIVER_INSERT_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_driver(BIGINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT) IS
'v2.1 — Crea conductor en tab_drivers. Eliminado wid_user (vínculo con tab_users movido a tab_driver_accounts). Normaliza texto; validación delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear conductor completo
SELECT * FROM fun_create_driver(
  1015432876,
  'Carlos Alberto Pérez Gómez',
  '1990-05-15'::DATE,
  '2027-12-31'::DATE,
  1,                   -- user_create
  'Calle 45 # 20-10',
  '3001234567',
  'carlos@email.com',
  'C2',
  1, 1,               -- id_eps, id_arl
  'O+',
  'María Pérez',
  '3109876543',
  CURRENT_DATE,
  1                   -- id_status
);
-- Para vincular con tab_users, insertar después en tab_driver_accounts:
-- INSERT INTO tab_driver_accounts(id_driver, id_user) VALUES (1015432876, <id_user>);

-- Crear conductor mínimo (solo campos obligatorios)
SELECT * FROM fun_create_driver(
  1015432877,
  'Luis Fernando Torres',
  '1985-03-22'::DATE,
  '2026-06-30'::DATE,
  1
);

-- Resultado exitoso:
-- success | msg                                              | error_code | out_driver
-- TRUE    | Conductor creado exitosamente (Cédula: 1015432876) | NULL       | 1015432876

-- Error: cédula duplicada (UNIQUE constraint)
-- success | msg                                                        | error_code              | out_driver
-- FALSE   | La cédula o usuario de sistema ya existen: ...detail...    | DRIVER_UNIQUE_VIOLATION | NULL

-- Error: EPS inexistente (FK constraint)
-- success | msg                               | error_code           | out_driver
-- FALSE   | Clave foránea inválida: ...detail... | DRIVER_FK_VIOLATION  | NULL

-- Error: licencia inválida (CHECK constraint)
-- success | msg                                  | error_code              | out_driver
-- FALSE   | Restricción CHECK violada: ...detail... | DRIVER_CHECK_VIOLATION | NULL

*/

-- =============================================
-- FUNCIÓN: fun_update_driver v2.1
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza los datos de un conductor existente en tab_drivers.
--   La cédula (id_driver / PK) es inmutable: identifica al conductor
--   pero no se modifica.
--   El estado (id_status / is_active) solo puede cambiarse con esta
--   función a través del parámetro wid_status; la activación/desactivación
--   lógica (is_active) debe gestionarse con una función dedicada.
--   La validación de negocio es responsabilidad del backend (Node.js).
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros obligatorios (IN):
--   wid_driver         BIGINT       — Cédula del conductor a actualizar (PK, no se modifica)
--   wuser_update       SMALLINT     — Usuario que realiza el cambio FK
--
-- Parámetros opcionales (IN / con DEFAULT):
--   wname_driver       VARCHAR(100) — Nombre completo              (DEFAULT 'SIN NOMBRE')
--   waddress_driver    VARCHAR(200) — Dirección                    (DEFAULT 'SIN DIRECCIÓN')
--   wphone_driver      VARCHAR(15)  — Teléfono                     (DEFAULT '0900000000')
--   wemail_driver      VARCHAR(320) — Email                        (DEFAULT 'sa@sa.com')
--   wbirth_date        DATE         — Fecha de nacimiento          (DEFAULT '2000-01-01')
--   wlicense_cat       VARCHAR(2)   — Categoría licencia           (DEFAULT 'SA')
--   wlicense_exp       DATE         — Vencimiento licencia         (DEFAULT '2000-01-01')
--   wid_eps            SMALLINT     — EPS FK                       (DEFAULT 1)
--   wid_arl            SMALLINT     — ARL FK                       (DEFAULT 1)
--   wblood_type        VARCHAR(3)   — Tipo de sangre               (DEFAULT 'SA')
--   wemergency_contact VARCHAR(100) — Contacto emergencia          (DEFAULT 'SIN CONTACTO')
--   wemergency_phone   VARCHAR(15)  — Teléfono emergencia          (DEFAULT '0900000000')
--   wdate_entry        DATE         — Fecha de ingreso             (DEFAULT CURRENT_DATE)
--   wid_status         SMALLINT     — Estado operativo FK          (DEFAULT 1)
--
-- Retorna (OUT):
--   success      BOOLEAN      — TRUE si se actualizó correctamente
--   msg          TEXT         — Mensaje descriptivo
--   error_code   VARCHAR(50)  — NULL si success = TRUE
--   out_driver   BIGINT       — Cédula del conductor actualizado
--
-- Códigos de error:
--   DRIVER_NOT_FOUND        — La cédula no existe en tab_drivers
--   DRIVER_UNIQUE_VIOLATION — Email duplicado en otro conductor
--   DRIVER_CHECK_VIOLATION  — Constraint CHECK violado (licencia, sangre, teléfono, etc.)
--   DRIVER_FK_VIOLATION     — FK inválida (eps, arl, status)
--   DRIVER_UPDATE_ERROR     — Error inesperado en el UPDATE
--
-- Campos NO actualizables por esta función:
--   id_driver (PK inmutable), is_active, created_at, user_create
--
-- Versión   : 2.1  — Elimina wid_user (vínculo movido a tab_driver_accounts)
-- Fecha     : 2026-03-17
-- =============================================

DROP FUNCTION IF EXISTS fun_update_driver(BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_update_driver(BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT);

CREATE OR REPLACE FUNCTION fun_update_driver(
  -- wid_driver y wuser_update primero (identificador + auditoría requerida)
  -- resto en el mismo orden que las columnas de tab_drivers
  wid_driver          tab_drivers.id_driver%TYPE,
  wuser_update        tab_drivers.user_update%TYPE,
  wname_driver        tab_drivers.name_driver%TYPE       DEFAULT 'SIN NOMBRE',
  waddress_driver     tab_drivers.address_driver%TYPE    DEFAULT 'SIN DIRECCIÓN',
  wphone_driver       tab_drivers.phone_driver%TYPE      DEFAULT '0900000000',
  wemail_driver       tab_drivers.email_driver%TYPE      DEFAULT 'sa@sa.com',
  wbirth_date         tab_drivers.birth_date%TYPE        DEFAULT '2000-01-01',
  wgender_driver      tab_drivers.gender_driver%TYPE     DEFAULT 'O',
  wlicense_cat        tab_drivers.license_cat%TYPE       DEFAULT 'SA',
  wlicense_exp        tab_drivers.license_exp%TYPE       DEFAULT '2000-01-01',
  wid_eps             tab_drivers.id_eps%TYPE             DEFAULT 1,
  wid_arl             tab_drivers.id_arl%TYPE             DEFAULT 1,
  wblood_type         tab_drivers.blood_type%TYPE         DEFAULT 'SA',
  wemergency_contact  tab_drivers.emergency_contact%TYPE  DEFAULT 'SIN CONTACTO',
  wemergency_phone    tab_drivers.emergency_phone%TYPE    DEFAULT '0900000000',
  wdate_entry         tab_drivers.date_entry%TYPE         DEFAULT CURRENT_DATE,
  wid_status          tab_drivers.id_status%TYPE          DEFAULT 1,

  OUT success         BOOLEAN,
  OUT msg             TEXT,
  OUT error_code      VARCHAR(50),
  OUT out_driver      tab_drivers.id_driver%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_driver := NULL;

  UPDATE tab_drivers SET
    name_driver       = COALESCE(NULLIF(TRIM(wname_driver),            ''), 'SIN NOMBRE'),
    address_driver    = COALESCE(NULLIF(TRIM(waddress_driver),         ''), 'SIN DIRECCIÓN'),
    phone_driver      = COALESCE(NULLIF(TRIM(wphone_driver),           ''), '0900000000'),
    email_driver      = COALESCE(NULLIF(LOWER(TRIM(wemail_driver)),    ''), 'sa@sa.com'),
    birth_date        = COALESCE(wbirth_date,                              '2000-01-01'),
    gender_driver     = COALESCE(NULLIF(UPPER(TRIM(wgender_driver)),          ''), 'O'),
    license_cat       = COALESCE(NULLIF(TRIM(wlicense_cat),            ''), 'SA'),
    license_exp       = COALESCE(wlicense_exp,                             '2000-01-01'),
    id_eps            = wid_eps,
    id_arl            = wid_arl,
    blood_type        = COALESCE(NULLIF(TRIM(wblood_type),          ''), 'SA'),
    emergency_contact = COALESCE(NULLIF(TRIM(wemergency_contact),      ''), 'SIN CONTACTO'),
    emergency_phone   = COALESCE(NULLIF(TRIM(wemergency_phone),        ''), '0900000000'),
    date_entry        = COALESCE(wdate_entry,                              CURRENT_DATE),
    id_status         = wid_status,
    updated_at        = NOW(),
    user_update       = wuser_update
  WHERE id_driver = wid_driver;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'Conductor no encontrado con cédula: ' || wid_driver;
    error_code := 'DRIVER_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  out_driver := wid_driver;
  msg        := 'Conductor actualizado exitosamente (Cédula: ' || wid_driver || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Email ya registrado en otro conductor: ' || SQLERRM;
    error_code := 'DRIVER_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada: ' || SQLERRM;
    error_code := 'DRIVER_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave foránea inválida (eps, arl o status): ' || SQLERRM;
    error_code := 'DRIVER_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'DRIVER_UPDATE_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_update_driver(BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT) IS
'v2.1 — Actualiza conductor en tab_drivers. Eliminado wid_user (vínculo con tab_users movido a tab_driver_accounts). Normalización inline en SET. Validación delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar conductor completo
SELECT * FROM fun_update_driver(
  1015432876,          -- id_driver (cédula, no se modifica)
  1,                   -- user_update
  'Carlos A. Pérez',   -- name_driver
  'Calle 50 # 30-20',  -- address_driver
  '3011234567',        -- phone_driver
  'carlos@nuevo.com',  -- email_driver
  '1990-05-15'::DATE,  -- birth_date
  'C2',                -- license_cat
  '2028-12-31'::DATE,  -- license_exp
  2,                   -- id_eps
  1,                   -- id_arl
  'O+',                -- blood_type
  'Ana Pérez',         -- emergency_contact
  '3119876543',        -- emergency_phone
  '2024-01-15'::DATE,  -- date_entry
  1                    -- id_status
);
-- Para cambiar el vínculo con tab_users, usar tab_driver_accounts:
-- UPDATE tab_driver_accounts SET id_user = <nuevo_id_user> WHERE id_driver = 1015432876;

-- Actualizar solo campos obligatorios (opcionales quedan en DEFAULT)
SELECT * FROM fun_update_driver(
  1015432876,
  1
);

-- Resultado exitoso:
-- success | msg                                                    | error_code | out_driver
-- TRUE    | Conductor actualizado exitosamente (Cédula: 1015432876) | NULL       | 1015432876

-- Error: conductor no encontrado
-- success | msg                                          | error_code       | out_driver
-- FALSE   | Conductor no encontrado con cédula: 9999999  | DRIVER_NOT_FOUND | NULL

-- Error: email duplicado en otro conductor
-- success | msg                                                  | error_code              | out_driver
-- FALSE   | Email o usuario de sistema ya registrado en otro...   | DRIVER_UNIQUE_VIOLATION | NULL

-- Error: categoría de licencia inválida
-- success | msg                                  | error_code              | out_driver
-- FALSE   | Restricción CHECK violada: ...detail... | DRIVER_CHECK_VIOLATION | NULL

*/

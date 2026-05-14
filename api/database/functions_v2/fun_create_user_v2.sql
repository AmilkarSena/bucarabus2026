-- =============================================
-- FUNCIÓN: fun_create_user v2.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo usuario en tab_users y le asigna
--   el rol indicado en tab_user_roles.
--   Normaliza email y nombre e inserta directamente.
--   La validación de negocio es responsabilidad del
--   backend (Node.js); los constraints de la BD
--   actúan como última barrera.
--
-- Parámetros:
--   wemail_user    VARCHAR(320) — email del nuevo usuario
--   wpass_user     VARCHAR(60)  — hash bcrypt generado en el backend
--   wfull_name     VARCHAR(100) — nombre completo
--   wid_role       SMALLINT     — ID del rol a asignar (1=Administrador, 2=Turnador, 3=Conductor)
--   wuser_create   SMALLINT     — ID del usuario que ejecuta la acción. Default 1
--
-- Retorna (OUT):
--   success    BOOLEAN      — TRUE si se creó correctamente
--   msg        TEXT         — Mensaje descriptivo del resultado
--   error_code VARCHAR(50)  — NULL si success = TRUE
--   id_user    SMALLINT     — ID del usuario creado (NULL si falla)
--
-- Versión   : 2.0
-- Fecha     : 2026-03-11
-- =============================================

-- Limpiar versiones anteriores con distintas firmas
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, TEXT, VARCHAR, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, TEXT,    VARCHAR, SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_user(
  wemail_user    tab_users.email_user%TYPE,
  wpass_user     tab_users.pass_user%TYPE,
  wfull_name     tab_users.full_name%TYPE,
  wid_role       tab_roles.id_role%TYPE,
  wuser_create   tab_user_roles.assigned_by%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT id_user     tab_users.id_user%TYPE
)
LANGUAGE plpgsql

AS $$
DECLARE
  v_email    tab_users.email_user%TYPE;
  v_name     tab_users.full_name%TYPE;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;
  id_user    := NULL;

  -- Normalizar
  v_email := LOWER(TRIM(wemail_user));
  v_name  := TRIM(REGEXP_REPLACE(wfull_name, '\s+', ' ', 'g'));

  -- INSERT en tab_users. Omitimos 'id_user' y lo capturamos al final con RETURNING
  INSERT INTO tab_users (full_name, email_user, pass_user, is_active)
  VALUES (v_name, v_email, wpass_user, TRUE)
  RETURNING tab_users.id_user INTO id_user; -- Capturamos el ID generado

  -- Usamos el ID recién creado para asignar el rol
  INSERT INTO tab_user_roles (id_user, id_role, assigned_at, assigned_by, is_active)
  VALUES (id_user, wid_role, NOW(), wuser_create, TRUE);

  success := TRUE;
  msg     := 'Usuario creado exitosamente (ID: ' || id_user || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'El email o la combinación usuario/rol ya existe: ' || SQLERRM;
    error_code := 'USER_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave foránea inválida (rol o usuario no existe): ' || SQLERRM;
    error_code := 'USER_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada: ' || SQLERRM;
    error_code := 'USER_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'USER_INSERT_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT) IS
'v2.0 — Crea usuario en tab_users + asigna rol en tab_user_roles. Normaliza email y nombre; validación de negocio delegada al backend y constraints de BD. id_user generado por IDENTITY (SMALLINT).';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear un conductor (id_role = 3)
SELECT * FROM fun_create_user(
  'carlos.gil@bucarabus.com',
  '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lh7i',
  'Carlos Gil',
  3,
  1
);

-- Resultado exitoso:
-- success | msg                         | error_code | id_user
-- TRUE    | Usuario creado exitosamente | NULL       | 2

-- Error: email duplicado (UNIQUE constraint)
-- success | msg                                          | error_code            | id_user
-- FALSE   | El email o la combinación usuario/rol ya ... | USER_UNIQUE_VIOLATION | NULL

-- Error: rol inexistente (FK constraint)
-- success | msg                                           | error_code         | id_user
-- FALSE   | Clave foránea inválida (rol o usuario no ...) | USER_FK_VIOLATION  | NULL

*/


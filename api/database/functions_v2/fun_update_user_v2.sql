-- =============================================
-- FUNCIÓN: fun_update_user v2.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza el nombre completo y/o el email de un
--   usuario existente en tab_users.
--   Ambos campos son opcionales: si se pasa NULL se
--   conserva el valor actual (via COALESCE en el SET).
--   La validación de negocio es responsabilidad del
--   backend (Node.js); los constraints de la BD
--   actúan como última barrera.
--
-- Parámetros:
--   wid_user    SMALLINT     — ID del usuario a actualizar
--   wfull_name  VARCHAR(100) — Nuevo nombre completo (NULL = no cambiar)
--   wemail_user VARCHAR(320) — Nuevo email (NULL = no cambiar)
--
-- Retorna (OUT):
--   success    BOOLEAN     — TRUE si se actualizó correctamente
--   msg        TEXT        — Mensaje descriptivo del resultado
--   error_code VARCHAR(50) — NULL si success = TRUE
--
-- Códigos de error:
--   USER_NOT_FOUND        — El id_user no existe en tab_users
--   USER_UNIQUE_VIOLATION — Email ya en uso por otro usuario
--   USER_CHECK_VIOLATION  — Constraint CHECK violado
--   USER_UPDATE_ERROR     — Error inesperado en el UPDATE
--
-- Versión   : 2.0
-- Fecha     : 2026-03-11
-- =============================================

DROP FUNCTION IF EXISTS fun_update_user(SMALLINT, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_user(
  wid_user     tab_users.id_user%TYPE,
  wfull_name   tab_users.full_name%TYPE   DEFAULT NULL,
  wemail_user  tab_users.email_user%TYPE  DEFAULT NULL,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql

AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  UPDATE tab_users
  SET full_name  = COALESCE(NULLIF(TRIM(REGEXP_REPLACE(wfull_name, '\s+', ' ', 'g')), ''), full_name),
      email_user = COALESCE(NULLIF(LOWER(TRIM(wemail_user)), ''), email_user)
  WHERE id_user = wid_user;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'Usuario no encontrado (id_user: ' || COALESCE(wid_user::TEXT, 'NULL') || ')';
    error_code := 'USER_NOT_FOUND'; RETURN;
  END IF;

  success := TRUE;
  msg     := 'Usuario actualizado exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'El email ya está en uso por otro usuario: ' || SQLERRM;
    error_code := 'USER_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada: ' || SQLERRM;
    error_code := 'USER_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'USER_UPDATE_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_update_user(SMALLINT, VARCHAR, VARCHAR) IS
'v2.0 — Actualiza full_name y/o email_user en tab_users. NULL = conservar valor actual (COALESCE en SET). Validación delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar solo el nombre
SELECT * FROM fun_update_user(2, 'Carlos Alberto Gil', NULL);

-- Actualizar solo el email
SELECT * FROM fun_update_user(2, NULL, 'carlos.nuevo@bucarabus.com');

-- Actualizar ambos
SELECT * FROM fun_update_user(2, 'Carlos Alberto Gil', 'carlos.nuevo@bucarabus.com');

-- Resultado exitoso:
-- success | msg                              | error_code
-- TRUE    | Usuario actualizado exitosamente | NULL

-- Error: id_user no existe
-- success | msg                              | error_code
-- FALSE   | Usuario no encontrado (id_user: 99) | USER_NOT_FOUND

-- Error: email duplicado (UNIQUE constraint)
-- success | msg                                    | error_code
-- FALSE   | El email ya está en uso por otro ...   | USER_UNIQUE_VIOLATION

*/
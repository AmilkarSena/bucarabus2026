-- =============================================
-- FUNCIÓN: fun_toggle_user_status v2.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Activa o desactiva un usuario en tab_users (campo is_active).
--   La validación de negocio (último admin activo, estado actual, etc.)
--   es responsabilidad del backend (Node.js).
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros (IN):
--   wid_user    SMALLINT — ID del usuario a cambiar
--   wis_active  BOOLEAN  — TRUE = activar, FALSE = desactivar
--
-- Retorna (OUT):
--   success    BOOLEAN     — TRUE si se aplicó el cambio
--   msg        TEXT        — Mensaje descriptivo del resultado
--   error_code VARCHAR(50) — NULL si success = TRUE
--   new_status BOOLEAN     — Nuevo valor de is_active
--
-- Códigos de error:
--   USER_NOT_FOUND   — El id_user no existe en tab_users
--   USER_UPDATE_ERROR — Error inesperado en el UPDATE
--
-- Versión   : 2.0
-- Fecha     : 2026-03-11
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_user_status(SMALLINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_toggle_user_status(
  wid_user    tab_users.id_user%TYPE,
  wis_active  BOOLEAN,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT new_status  BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  new_status := NULL;

  UPDATE tab_users
  SET is_active = wis_active
  WHERE id_user = wid_user;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'Usuario no encontrado (id_user: ' || COALESCE(wid_user::TEXT, 'NULL') || ')';
    error_code := 'USER_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  new_status := wis_active;
  msg        := 'Usuario ' || CASE WHEN wis_active THEN 'activado' ELSE 'desactivado' END || ' exitosamente';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'USER_UPDATE_ERROR';
END;
$$;

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar usuario con id_user = 2
SELECT * FROM fun_toggle_user_status(2, FALSE);
-- success | msg                              | error_code | new_status
-- TRUE    | Usuario desactivado exitosamente | NULL       | FALSE

-- Activar usuario previamente desactivado
SELECT * FROM fun_toggle_user_status(2, TRUE);
-- success | msg                            | error_code | new_status
-- TRUE    | Usuario activado exitosamente  | NULL       | TRUE

-- id_user inexistente
SELECT * FROM fun_toggle_user_status(999, FALSE);
-- success | msg                                    | error_code     | new_status
-- FALSE   | Usuario no encontrado (id_user: 999)   | USER_NOT_FOUND | NULL

*/

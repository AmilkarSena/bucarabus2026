-- =============================================
-- FUNCIONES: fun_assign_role + fun_remove_role v2.0
-- Directorio: functions_v2
-- =============================================
-- fun_assign_role: asigna un rol a un usuario (INSERT o reactiva si existía)
-- fun_remove_role: quita un rol de un usuario (soft delete is_active = FALSE)
--
-- La validación de negocio (último rol activo, rol administrador, etc.)
-- es responsabilidad del backend (Node.js).
-- Los constraints de la BD actúan como última barrera.
--
-- Versión   : 2.0
-- Fecha     : 2026-03-11
-- =============================================

-- =============================================
-- fun_assign_role
-- =============================================
DROP FUNCTION IF EXISTS fun_assign_role(SMALLINT, SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_assign_role(
  wid_user      tab_users.id_user%TYPE,
  wid_role      tab_roles.id_role%TYPE,
  wassigned_by  tab_user_roles.assigned_by%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  INSERT INTO tab_user_roles (id_user, id_role, assigned_at, assigned_by, is_active)
  VALUES (wid_user, wid_role, NOW(), wassigned_by, TRUE)
  ON CONFLICT (id_user, id_role)
  DO UPDATE SET
    is_active   = TRUE,
    assigned_at = EXCLUDED.assigned_at,
    assigned_by = EXCLUDED.assigned_by
  WHERE tab_user_roles.is_active = FALSE
     OR tab_user_roles.assigned_by IS DISTINCT FROM EXCLUDED.assigned_by;

  success := TRUE;
  msg     := 'Rol asignado exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario o rol no válido: ' || SQLERRM;
    error_code := 'ROLE_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROLE_ASSIGN_ERROR';
END;
$$;


-- =============================================
-- fun_remove_role
-- =============================================
DROP FUNCTION IF EXISTS fun_remove_role(SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_remove_role(
  wid_user  tab_users.id_user%TYPE,
  wid_role  tab_roles.id_role%TYPE,

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

  UPDATE tab_user_roles
  SET is_active = FALSE
  WHERE id_user = wid_user
    AND id_role  = wid_role
    AND is_active = TRUE;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'El usuario no tiene este rol asignado (id_user: ' || COALESCE(wid_user::TEXT, 'NULL') || ', id_role: ' || COALESCE(wid_role::TEXT, 'NULL') || ')';
    error_code := 'ROLE_NOT_ASSIGNED'; RETURN;
  END IF;

  success := TRUE;
  msg     := 'Rol quitado exitosamente';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROLE_REMOVE_ERROR';
END;
$$;

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Asignar rol 2 al usuario 5 (admin = usuario 1 asigna)
SELECT * FROM fun_assign_role(5, 2, 1);
-- success | msg                    | error_code
-- TRUE    | Rol asignado exitosamente | NULL

-- Reactivar rol previamente quitado (ON CONFLICT DO UPDATE)
SELECT * FROM fun_assign_role(5, 2, 1);
-- success | msg                    | error_code
-- TRUE    | Rol asignado exitosamente | NULL   ← idempotente

-- Usuario o rol no existen (FK violation)
-- success | msg                          | error_code
-- FALSE   | Usuario o rol no válido: ... | ROLE_FK_VIOLATION

-- Quitar rol 2 del usuario 5
SELECT * FROM fun_remove_role(5, 2);
-- success | msg                   | error_code
-- TRUE    | Rol quitado exitosamente | NULL

-- Rol no asignado o ya inactivo
SELECT * FROM fun_remove_role(5, 2);
-- success | msg                                              | error_code
-- FALSE   | El usuario no tiene este rol asignado (...)      | ROLE_NOT_ASSIGNED

*/
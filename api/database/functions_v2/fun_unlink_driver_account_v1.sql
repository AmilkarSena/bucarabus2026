-- =============================================
-- FUNCIÓN: fun_unlink_driver_account v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Desvincula la cuenta de sistema de un conductor.
--   En una transacción atómica:
--     1. Elimina el rol Conductor de tab_user_roles (hard delete)
--     2. Desactiva el usuario en tab_users SOLO si no tiene otros roles activos
--     3. Elimina el vínculo de tab_driver_accounts (hard delete)
--
--   El usuario se preserva en tab_users (integridad referencial con auditoría).
--   La validación de negocio (conductor existe, tiene cuenta, no tiene viaje activo)
--   es responsabilidad del backend (Node.js).
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros:
--   wid_driver   BIGINT   — Cédula del conductor
--   wunlinked_by SMALLINT — ID del admin que realiza la acción. Default 1
--
-- Retorna (OUT):
--   success    BOOLEAN     — TRUE si se desvinculó correctamente
--   msg        TEXT        — Mensaje descriptivo del resultado
--   error_code VARCHAR(50) — NULL si success = TRUE
--
-- Versión   : 1.0
-- Fecha     : 2026-03-31
-- =============================================

DROP FUNCTION IF EXISTS fun_unlink_driver_account(BIGINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_unlink_driver_account(
  wid_driver    tab_drivers.id_driver%TYPE,
  wunlinked_by  tab_users.id_user%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_user  tab_users.id_user%TYPE;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- Obtener el id_user vinculado al conductor
  SELECT id_user INTO v_id_user
  FROM tab_driver_accounts
  WHERE id_driver = wid_driver;

  IF v_id_user IS NULL THEN
    msg        := 'El conductor no tiene una cuenta vinculada';
    error_code := 'ACCOUNT_NOT_FOUND';
    RETURN;
  END IF;

  -- 1. Eliminar rol Conductor de tab_user_roles (hard delete)
  -- Hard delete para que el rol pueda reasignarse limpiamente en el futuro
  DELETE FROM tab_user_roles
  WHERE id_user = v_id_user
    AND id_role = 3;

  -- 2. Desactivar usuario en tab_users solo si no tiene otros roles activos
  IF NOT EXISTS (
    SELECT 1 FROM tab_user_roles
    WHERE id_user  = v_id_user
      AND id_role  <> 3
      AND is_active = TRUE
  ) THEN
    UPDATE tab_users
    SET is_active = FALSE
    WHERE id_user = v_id_user;
  END IF;

  -- 3. Eliminar vínculo de tab_driver_accounts
  DELETE FROM tab_driver_accounts
  WHERE id_driver = wid_driver;

  success := TRUE;
  msg     := 'Cuenta desvinculada exitosamente (usuario ID: ' || v_id_user || ')';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'No se puede desvincular: restricción de integridad referencial: ' || SQLERRM;
    error_code := 'ACCOUNT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ACCOUNT_UNLINK_ERROR';
END;
$$;

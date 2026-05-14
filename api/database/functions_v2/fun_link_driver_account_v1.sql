-- =============================================
-- FUNCIÓN: fun_link_driver_account v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Vincula un conductor existente (tab_drivers) con un usuario existente (tab_users).
--   Solo registra el vínculo en tab_driver_accounts.
--
--   Flujo esperado:
--     1. Admin crea el conductor          → fun_create_driver
--     2. Admin crea la cuenta de usuario  → fun_create_user (con id_role = 3, Conductor)
--     3. Admin llama a esta función       → fun_link_driver_account
--
--   La validación de negocio (conductor existe, usuario existe, conductor ya vinculado,
--   usuario ya vinculado a otro conductor) es responsabilidad del backend (Node.js).
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros:
--   wid_driver   BIGINT   — Cédula del conductor (FK a tab_drivers)
--   wid_user     SMALLINT — ID del usuario a vincular (FK a tab_users)
--   wassigned_by SMALLINT — ID del admin que realiza la acción. Default 1
--
-- Retorna (OUT):
--   success    BOOLEAN     — TRUE si se vinculó correctamente
--   msg        TEXT        — Mensaje descriptivo del resultado
--   error_code VARCHAR(50) — NULL si success = TRUE
--
-- Versión   : 1.0
-- Fecha     : 2026-03-31
-- =============================================

DROP FUNCTION IF EXISTS fun_link_driver_account(BIGINT, VARCHAR, VARCHAR, VARCHAR, SMALLINT);
DROP FUNCTION IF EXISTS fun_link_driver_account(BIGINT, SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_link_driver_account(
  wid_driver    tab_drivers.id_driver%TYPE,
  wid_user      tab_users.id_user%TYPE,
  wassigned_by  tab_driver_accounts.assigned_by%TYPE  DEFAULT 1,

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

  INSERT INTO tab_driver_accounts (id_driver, id_user, assigned_at, assigned_by)
  VALUES (wid_driver, wid_user, NOW(), wassigned_by);

  success := TRUE;
  msg     := 'Cuenta vinculada exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'El conductor o el usuario ya tiene un vínculo activo: ' || SQLERRM;
    error_code := 'ACCOUNT_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Conductor o usuario no válido: ' || SQLERRM;
    error_code := 'ACCOUNT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ACCOUNT_LINK_ERROR';
END;
$$;

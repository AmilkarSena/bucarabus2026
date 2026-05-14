-- =============================================
-- BucaraBUS — Funciones: Recuperación de Contraseña
-- Archivo: fun_password_reset.sql
--
-- Principio arquitectónico: Solo mutaciones (DELETE + INSERT + UPDATE).
-- Las consultas SELECT viven en password-reset.service.js (Node.js).
-- =============================================

-- ─── 1. Crear token de recuperación (DELETE old + INSERT new, atómico) ───────
DROP FUNCTION IF EXISTS fun_create_password_reset_token(INTEGER, VARCHAR, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION fun_create_password_reset_token(
  wid_user    tab_users.id_user%TYPE,
  wtoken      tab_password_reset_tokens.token%TYPE,
  wexpires_at tab_password_reset_tokens.expires_at%TYPE,

  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- Eliminar tokens anteriores del mismo usuario (un token activo a la vez)
  DELETE FROM tab_password_reset_tokens WHERE id_user = wid_user;

  -- Insertar el nuevo token
  INSERT INTO tab_password_reset_tokens (id_user, token, expires_at)
  VALUES (wid_user, wtoken, wexpires_at);

  success := TRUE;
  msg     := 'Token de recuperación creado correctamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario inexistente: ' || SQLERRM;
    error_code := 'RESET_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado al crear token: ' || SQLERRM;
    error_code := 'RESET_INTERNAL_ERROR';
END;
$$;

-- ─── 2. Consumir token y actualizar contraseña (validar + UPDATE + DELETE) ───
DROP FUNCTION IF EXISTS fun_consume_password_reset_token(VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION fun_consume_password_reset_token(
  wtoken         tab_password_reset_tokens.token%TYPE,
  wpassword_hash tab_users.pass_user%TYPE,

  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_user tab_users.id_user%TYPE;
  v_id_token tab_password_reset_tokens.id_token%TYPE;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- Validar que el token existe y no ha expirado
  SELECT id_token, id_user
    INTO v_id_token, v_id_user
    FROM tab_password_reset_tokens
   WHERE token = wtoken AND expires_at > NOW();

  IF v_id_token IS NULL THEN
    msg        := 'El enlace de recuperación es inválido o ya expiró';
    error_code := 'RESET_TOKEN_INVALID';
    RETURN;
  END IF;

  -- Actualizar contraseña del usuario
  UPDATE tab_users
     SET pass_user = wpassword_hash
   WHERE id_user = v_id_user;

  -- Eliminar el token (uso único)
  DELETE FROM tab_password_reset_tokens WHERE id_token = v_id_token;

  success := TRUE;
  msg     := 'Contraseña actualizada correctamente';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado al restablecer contraseña: ' || SQLERRM;
    error_code := 'RESET_INTERNAL_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_password_reset_token IS
  'Elimina tokens anteriores del usuario e inserta uno nuevo. Atómico.';

COMMENT ON FUNCTION fun_consume_password_reset_token IS
  'Valida el token, actualiza la contraseña y elimina el token (uso único). Atómico.';

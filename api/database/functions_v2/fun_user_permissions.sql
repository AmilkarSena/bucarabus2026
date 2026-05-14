-- =============================================
-- BucaraBUS — Función: Overrides de Permisos por Usuario
-- Archivo: fun_user_permissions.sql
--
-- Principio arquitectónico: Esta función es una MUTACIÓN (DELETE + INSERT).
-- Las consultas SELECT de permisos efectivos viven en auth.service.js (Node.js).
-- =============================================

DROP FUNCTION IF EXISTS fun_update_user_permissions(INTEGER, JSONB, INTEGER);

CREATE OR REPLACE FUNCTION fun_update_user_permissions(
  wid_user        tab_users.id_user%TYPE,
  woverrides_json JSONB,
  wuser_update    tab_users.id_user%TYPE DEFAULT 1,

  -- Parámetros OUT siguiendo tu estándar v2
  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_override      JSONB;
  v_perm_code     tab_permissions.code_permission%TYPE;
  v_is_granted    BOOLEAN;
  v_id_permission tab_permissions.id_permission%TYPE;
BEGIN
  -- Inicializar respuesta
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- 1. Eliminar TODOS los overrides actuales del usuario (reemplazo atómico)
  DELETE FROM tab_user_permissions WHERE id_user = wid_user;

  -- 2. Insertar los nuevos overrides si se envió un arreglo no vacío
  IF woverrides_json IS NOT NULL AND jsonb_array_length(woverrides_json) > 0 THEN
    FOR v_override IN SELECT jsonb_array_elements(woverrides_json)
    LOOP
      -- Casteo y extracción del JSON
      v_perm_code  := UPPER(TRIM(v_override->>'code'));
      v_is_granted := (v_override->>'is_granted')::BOOLEAN;

      -- Buscar el id_permission por código
      SELECT id_permission
        INTO v_id_permission
        FROM tab_permissions
       WHERE code_permission = v_perm_code
         AND is_active = TRUE;

      -- Solo insertar si el permiso existe y es activo
      IF v_id_permission IS NOT NULL THEN
        INSERT INTO tab_user_permissions (id_user, id_permission, is_granted, assigned_by)
        VALUES (wid_user, v_id_permission, v_is_granted, wuser_update);
      END IF;

    END LOOP;
  END IF;

  success := TRUE;
  msg     := 'Permisos personalizados actualizados correctamente para el usuario ID: ' || wid_user;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario o permiso inexistente: ' || SQLERRM;
    error_code := 'USER_PERM_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado al actualizar permisos: ' || SQLERRM;
    error_code := 'USER_PERM_INTERNAL_ERROR';
END;
$$;

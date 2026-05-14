-- =============================================
-- FUNCIÓN: fun_toggle_insurer v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Invierte el estado is_active de un registro
--   en tab_insurers (activo → inactivo / inactivo → activo).
--
-- Parámetros (IN):
--   wid_insurer       SMALLINT  — ID de la aseguradora
--
-- Retorna (OUT):
--   success           BOOLEAN     — TRUE si se actualizó correctamente
--   msg               TEXT        — Mensaje descriptivo
--   error_code        VARCHAR(50) — NULL si éxito; código si falla
--   out_id_insurer    SMALLINT    — ID afectado (NULL si falla)
--   out_is_active     BOOLEAN     — Nuevo estado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_insurer(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_insurer(
  wid_insurer       tab_insurers.id_insurer%TYPE,

  -- Parámetros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_insurer   tab_insurers.id_insurer%TYPE,
  OUT out_name         tab_insurers.insurer_name%TYPE,
  OUT out_is_active    tab_insurers.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success        := FALSE;
  msg            := '';
  error_code     := NULL;
  out_id_insurer := NULL;
  out_name       := NULL;
  out_is_active  := NULL;

  UPDATE tab_insurers
  SET    is_active  = NOT is_active
  WHERE  id_insurer = wid_insurer
  RETURNING id_insurer, insurer_name, is_active
  INTO out_id_insurer, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la aseguradora con ID: ' || wid_insurer;
    error_code := 'INSURER_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Aseguradora ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente (ID: ' || out_id_insurer || ')';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INSURER_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_insurer(SMALLINT) IS
'v1.0 — Invierte is_active de aseguradora en tab_insurers. Retorna INSURER_NOT_FOUND si el ID no existe. El mensaje indica si quedó activada o desactivada.';

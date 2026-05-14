-- =============================================
-- FUNCIÓN: fun_toggle_arl v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Invierte el estado is_active de un registro
--   en tab_arl (activo → inactivo / inactivo → activo).
--
-- Parámetros (IN):
--   wid_arl         SMALLINT  — ID de la ARL
--
-- Retorna (OUT):
--   success         BOOLEAN     — TRUE si se actualizó correctamente
--   msg             TEXT        — Mensaje descriptivo
--   error_code      VARCHAR(50) — NULL si éxito; código si falla
--   out_id_arl      SMALLINT    — ID afectado (NULL si falla)
--   out_is_active   BOOLEAN     — Nuevo estado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_arl(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_arl(
  wid_arl         tab_arl.id_arl%TYPE,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_arl    tab_arl.id_arl%TYPE,
  OUT out_name      tab_arl.name_arl%TYPE,
  OUT out_is_active tab_arl.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_arl    := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_arl
  SET    is_active = NOT is_active
  WHERE  id_arl    = wid_arl
  RETURNING id_arl, name_arl, is_active
  INTO out_id_arl, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la ARL con ID: ' || wid_arl;
    error_code := 'ARL_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'ARL ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente (ID: ' || out_id_arl || ')';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ARL_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_arl(SMALLINT) IS
'v1.0 — Invierte is_active de ARL en tab_arl. Retorna ARL_NOT_FOUND si el ID no existe. El mensaje indica si quedó activada o desactivada.';

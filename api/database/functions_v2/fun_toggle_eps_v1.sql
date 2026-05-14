-- =============================================
-- FUNCIÓN: fun_toggle_eps v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Invierte el estado is_active de un registro
--   en tab_eps (activo → inactivo / inactivo → activo).
--
-- Parámetros (IN):
--   wid_eps         SMALLINT  — ID de la EPS
--
-- Retorna (OUT):
--   success         BOOLEAN   — TRUE si se actualizó correctamente
--   msg             TEXT      — Mensaje descriptivo
--   error_code      VARCHAR(50) — NULL si éxito; código si falla
--   out_id_eps      SMALLINT  — ID afectado (NULL si falla)
--   out_is_active   BOOLEAN   — Nuevo estado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_eps(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_eps(
  wid_eps         tab_eps.id_eps%TYPE,

  -- Parámetros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_eps    tab_eps.id_eps%TYPE,
  OUT out_name      tab_eps.name_eps%TYPE,
  OUT out_is_active tab_eps.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_eps    := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_eps
  SET    is_active = NOT is_active
  WHERE  id_eps    = wid_eps
  RETURNING id_eps, name_eps, is_active
  INTO out_id_eps, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la EPS con ID: ' || wid_eps;
    error_code := 'EPS_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'EPS ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente (ID: ' || out_id_eps || ')';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'EPS_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_eps(SMALLINT) IS
'v1.0 — Invierte is_active de EPS en tab_eps. Retorna EPS_NOT_FOUND si el ID no existe. El mensaje indica si quedó activada o desactivada.';

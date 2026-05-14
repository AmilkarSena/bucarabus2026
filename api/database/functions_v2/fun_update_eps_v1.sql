-- =============================================
-- FUNCIÓN: fun_update_eps v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza el nombre de un registro en tab_eps.
--   Normaliza el nombre (TRIM + mayúscula inicial).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wid_eps       SMALLINT     — ID de la EPS a actualizar
--   wname_eps     VARCHAR(60)  — Nuevo nombre de la EPS
--
-- Retorna (OUT):
--   success      BOOLEAN      — TRUE si se actualizó correctamente
--   msg          TEXT         — Mensaje descriptivo
--   error_code   VARCHAR(50)  — NULL si éxito; código si falla
--   out_id_eps   SMALLINT     — ID actualizado (NULL si falla)
--   out_name     VARCHAR(60)  — Nombre actualizado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_eps(SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_eps(
  wid_eps       tab_eps.id_eps%TYPE,
  wname_eps     tab_eps.name_eps%TYPE,

  -- Parámetros OUT
  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50),
  OUT out_id_eps tab_eps.id_eps%TYPE,
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
  SET    name_eps = INITCAP(TRIM(wname_eps))
  WHERE  id_eps   = wid_eps
  RETURNING id_eps, name_eps, is_active
  INTO out_id_eps, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la EPS con ID: ' || wid_eps;
    error_code := 'EPS_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'EPS actualizada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una EPS con ese nombre: ' || SQLERRM;
    error_code := 'EPS_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'EPS_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_eps(SMALLINT, VARCHAR) IS
'v1.0 — Actualiza nombre de EPS en tab_eps. Normaliza con INITCAP/TRIM. Retorna EPS_NOT_FOUND si el ID no existe. Validación de negocio delegada al backend.';

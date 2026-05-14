-- =============================================
-- FUNCIÓN: fun_update_arl v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza el nombre de un registro en tab_arl.
--   Normaliza el nombre (TRIM + mayúscula inicial).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wid_arl       SMALLINT     — ID de la ARL a actualizar
--   wname_arl     VARCHAR(60)  — Nuevo nombre de la ARL
--
-- Retorna (OUT):
--   success      BOOLEAN      — TRUE si se actualizó correctamente
--   msg          TEXT         — Mensaje descriptivo
--   error_code   VARCHAR(50)  — NULL si éxito; código si falla
--   out_id_arl   SMALLINT     — ID actualizado (NULL si falla)
--   out_name     VARCHAR(60)  — Nombre actualizado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_arl(SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_arl(
  wid_arl       tab_arl.id_arl%TYPE,
  wname_arl     tab_arl.name_arl%TYPE,

  -- Parámetros OUT
  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50),
  OUT out_id_arl tab_arl.id_arl%TYPE,
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
  SET    name_arl = INITCAP(TRIM(wname_arl))
  WHERE  id_arl   = wid_arl
  RETURNING id_arl, name_arl, is_active
  INTO out_id_arl, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la ARL con ID: ' || wid_arl;
    error_code := 'ARL_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'ARL actualizada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una ARL con ese nombre: ' || SQLERRM;
    error_code := 'ARL_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ARL_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_arl(SMALLINT, VARCHAR) IS
'v1.0 — Actualiza nombre de ARL en tab_arl. Normaliza con INITCAP/TRIM. Retorna ARL_NOT_FOUND si el ID no existe. Validación de negocio delegada al backend.';

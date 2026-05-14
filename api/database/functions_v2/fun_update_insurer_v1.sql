-- =============================================
-- FUNCIÓN: fun_update_insurer v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza el nombre de un registro en tab_insurers.
--   Normaliza el nombre (TRIM + mayúscula inicial).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wid_insurer     SMALLINT     — ID de la aseguradora a actualizar
--   winsurer_name   VARCHAR(100) — Nuevo nombre de la aseguradora
--
-- Retorna (OUT):
--   success          BOOLEAN     — TRUE si se actualizó correctamente
--   msg              TEXT        — Mensaje descriptivo
--   error_code       VARCHAR(50) — NULL si éxito; código si falla
--   out_id_insurer   SMALLINT    — ID actualizado (NULL si falla)
--   out_name         VARCHAR(100)— Nombre actualizado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_insurer(SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_insurer(
  wid_insurer     tab_insurers.id_insurer%TYPE,
  winsurer_name   tab_insurers.insurer_name%TYPE,

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
  SET    insurer_name = INITCAP(TRIM(winsurer_name))
  WHERE  id_insurer   = wid_insurer
  RETURNING id_insurer, insurer_name, is_active
  INTO out_id_insurer, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la aseguradora con ID: ' || wid_insurer;
    error_code := 'INSURER_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Aseguradora actualizada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una aseguradora con ese nombre: ' || SQLERRM;
    error_code := 'INSURER_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INSURER_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_insurer(SMALLINT, VARCHAR) IS
'v1.0 — Actualiza nombre de aseguradora en tab_insurers. Normaliza con INITCAP/TRIM. Retorna INSURER_NOT_FOUND si el ID no existe. Validación de negocio delegada al backend.';

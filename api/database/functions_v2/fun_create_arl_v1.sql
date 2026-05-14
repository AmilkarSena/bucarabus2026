-- =============================================
-- FUNCIÓN: fun_create_arl v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo registro en tab_arl.
--   Normaliza el nombre (TRIM + mayúscula inicial).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wname_arl     VARCHAR(60)  — Nombre de la ARL
--
-- Retorna (OUT):
--   success      BOOLEAN      — TRUE si se creó correctamente
--   msg          TEXT         — Mensaje descriptivo
--   error_code   VARCHAR(50)  — NULL si éxito; código si falla
--   out_id_arl   SMALLINT     — ID generado (NULL si falla)
--   out_name     VARCHAR(60)  — Nombre insertado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_create_arl(VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_arl(
  wname_arl     tab_arl.name_arl%TYPE,

  -- Parámetros OUT
  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50),
  OUT out_id_arl tab_arl.id_arl%TYPE,
  OUT out_name   tab_arl.name_arl%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_arl := NULL;
  out_name   := NULL;

  INSERT INTO tab_arl (
    id_arl, name_arl, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_arl) FROM tab_arl), 0) + 1,
    INITCAP(TRIM(wname_arl)),
    TRUE,
    NOW()
  )
  RETURNING id_arl, name_arl
  INTO out_id_arl, out_name;

  success := TRUE;
  msg     := 'ARL creada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una ARL con ese nombre: ' || SQLERRM;
    error_code := 'ARL_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ARL_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_arl(VARCHAR) IS
'v1.0 — Crea ARL en tab_arl. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. Validación de negocio delegada al backend y constraints de BD.';

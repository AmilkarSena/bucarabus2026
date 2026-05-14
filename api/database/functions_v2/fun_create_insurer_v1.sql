-- =============================================
-- FUNCIÓN: fun_create_insurer v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo registro en tab_insurers.
--   Normaliza el nombre (TRIM + mayúscula inicial).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   winsurer_name   VARCHAR(100) — Nombre de la aseguradora
--
-- Retorna (OUT):
--   success          BOOLEAN     — TRUE si se creó correctamente
--   msg              TEXT        — Mensaje descriptivo
--   error_code       VARCHAR(50) — NULL si éxito; código si falla
--   out_id_insurer   SMALLINT    — ID generado (NULL si falla)
--   out_name         VARCHAR(100)— Nombre insertado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_create_insurer(VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_insurer(
  winsurer_name     tab_insurers.insurer_name%TYPE,

  -- Parámetros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_insurer   tab_insurers.id_insurer%TYPE,
  OUT out_name         tab_insurers.insurer_name%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success        := FALSE;
  msg            := '';
  error_code     := NULL;
  out_id_insurer := NULL;
  out_name       := NULL;

  INSERT INTO tab_insurers (
    id_insurer, insurer_name, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_insurer) FROM tab_insurers), 0) + 1,
    INITCAP(TRIM(winsurer_name)),
    TRUE,
    NOW()
  )
  RETURNING id_insurer, insurer_name
  INTO out_id_insurer, out_name;

  success := TRUE;
  msg     := 'Aseguradora creada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una aseguradora con ese nombre: ' || SQLERRM;
    error_code := 'INSURER_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INSURER_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_insurer(VARCHAR) IS
'v1.0 — Crea aseguradora en tab_insurers. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. Validación de negocio delegada al backend y constraints de BD.';

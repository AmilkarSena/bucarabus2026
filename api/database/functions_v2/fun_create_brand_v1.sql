-- =============================================
-- FUNCIÓN: fun_create_brand v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo registro en tab_brands.
--   Normaliza el nombre (TRIM + mayúscula inicial).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wbrand_name   VARCHAR(50)  — Nombre de la marca
--
-- Retorna (OUT):
--   success        BOOLEAN     — TRUE si se creó correctamente
--   msg            TEXT        — Mensaje descriptivo
--   error_code     VARCHAR(50) — NULL si éxito; código si falla
--   out_id_brand   SMALLINT    — ID generado (NULL si falla)
--   out_name       VARCHAR(50) — Nombre insertado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_create_brand(VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_brand(
  wbrand_name     tab_brands.brand_name%TYPE,

  -- Parámetros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_brand tab_brands.id_brand%TYPE,
  OUT out_name     tab_brands.brand_name%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_brand := NULL;
  out_name     := NULL;

  INSERT INTO tab_brands (
    id_brand, brand_name, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_brand) FROM tab_brands), 0) + 1,
    INITCAP(TRIM(wbrand_name)),
    TRUE,
    NOW()
  )
  RETURNING id_brand, brand_name
  INTO out_id_brand, out_name;

  success := TRUE;
  msg     := 'Marca creada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una marca con ese nombre: ' || SQLERRM;
    error_code := 'BRAND_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BRAND_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_brand(VARCHAR) IS
'v1.0 — Crea marca en tab_brands. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. Validación de negocio delegada al backend y constraints de BD.';

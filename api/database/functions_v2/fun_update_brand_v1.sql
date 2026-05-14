-- =============================================
-- FUNCIÓN: fun_update_brand v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Actualiza el nombre de un registro en tab_brands.
--   Normaliza el nombre (TRIM + mayúscula inicial).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wid_brand     SMALLINT     — ID de la marca a actualizar
--   wbrand_name   VARCHAR(50)  — Nuevo nombre de la marca
--
-- Retorna (OUT):
--   success        BOOLEAN     — TRUE si se actualizó correctamente
--   msg            TEXT        — Mensaje descriptivo
--   error_code     VARCHAR(50) — NULL si éxito; código si falla
--   out_id_brand   SMALLINT    — ID actualizado (NULL si falla)
--   out_name       VARCHAR(50) — Nombre actualizado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_brand(SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_brand(
  wid_brand     tab_brands.id_brand%TYPE,
  wbrand_name   tab_brands.brand_name%TYPE,

  -- Parámetros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_brand tab_brands.id_brand%TYPE,
  OUT out_name      tab_brands.brand_name%TYPE,
  OUT out_is_active tab_brands.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_brand  := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_brands
  SET    brand_name = INITCAP(TRIM(wbrand_name))
  WHERE  id_brand   = wid_brand
  RETURNING id_brand, brand_name, is_active
  INTO out_id_brand, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la marca con ID: ' || wid_brand;
    error_code := 'BRAND_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Marca actualizada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una marca con ese nombre: ' || SQLERRM;
    error_code := 'BRAND_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BRAND_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_brand(SMALLINT, VARCHAR) IS
'v1.0 — Actualiza nombre de marca en tab_brands. Normaliza con INITCAP/TRIM. Retorna BRAND_NOT_FOUND si el ID no existe. Validación de negocio delegada al backend.';

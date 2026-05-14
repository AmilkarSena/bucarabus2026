-- =============================================
-- FUNCIÓN: fun_toggle_brand v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Invierte el estado is_active de un registro
--   en tab_brands (activo → inactivo / inactivo → activo).
--
-- Parámetros (IN):
--   wid_brand       SMALLINT  — ID de la marca
--
-- Retorna (OUT):
--   success         BOOLEAN     — TRUE si se actualizó correctamente
--   msg             TEXT        — Mensaje descriptivo
--   error_code      VARCHAR(50) — NULL si éxito; código si falla
--   out_id_brand    SMALLINT    — ID afectado (NULL si falla)
--   out_is_active   BOOLEAN     — Nuevo estado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_brand(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_brand(
  wid_brand       tab_brands.id_brand%TYPE,

  -- Parámetros OUT
  OUT success        BOOLEAN,
  OUT msg            TEXT,
  OUT error_code     VARCHAR(50),
  OUT out_id_brand   tab_brands.id_brand%TYPE,
  OUT out_name       tab_brands.brand_name%TYPE,
  OUT out_is_active  tab_brands.is_active%TYPE
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
  SET    is_active = NOT is_active
  WHERE  id_brand  = wid_brand
  RETURNING id_brand, brand_name, is_active
  INTO out_id_brand, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la marca con ID: ' || wid_brand;
    error_code := 'BRAND_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Marca ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente (ID: ' || out_id_brand || ')';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BRAND_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_brand(SMALLINT) IS
'v1.0 — Invierte is_active de marca en tab_brands. Retorna BRAND_NOT_FOUND si el ID no existe. El mensaje indica si quedó activada o desactivada.';

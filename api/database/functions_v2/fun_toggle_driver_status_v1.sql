-- =============================================
-- FUNCIÓN: fun_toggle_driver_status v1.0
-- Directorio: functions_v2
-- =============================================

-- Descripción:
--   Activa o desactiva un conductor en tab_drivers (campo is_active).  
--   La validación de negocio (último conductor activo, estado actual, etc.)
--   es responsabilidad del backend (Node.js). Los constraints de la BD actúan como última barrera.
-- Parámetros (IN):
--   wid_driver  BIGINT  — Cédula del conductor a cambiar
--   wis_active  BOOLEAN — TRUE = activar, FALSE = desactivar       
-- Retorna (OUT):
--   success    BOOLEAN     — TRUE si se aplicó el cambio   
--   msg        TEXT        — Mensaje descriptivo del resultado
--   error_code VARCHAR(50) — NULL si success = TRUE
--   new_status BOOLEAN     — Nuevo valor de is_active
-- Códigos de error:
--   DRIVER_NOT_FOUND   — La cédula no existe en tab_drivers
--   DRIVER_UPDATE_ERROR — Error inesperado en el UPDATE
-- Versión   : 1.0      
-- Fecha     : 2026-03-11
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_driver_status(BIGINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_toggle_driver_status(
  wid_driver  tab_drivers.id_driver%TYPE,
  wis_active  BOOLEAN,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT new_status  BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;       
  new_status := NULL;

  UPDATE tab_drivers
  SET is_active = wis_active
  WHERE id_driver = wid_driver;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'El conductor no existe (id_driver: ' || COALESCE(wid_driver::TEXT, 'NULL') || ')';
    error_code := 'DRIVER_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  msg     := 'Estado del conductor actualizado exitosamente';   
    new_status := wis_active;
EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'DRIVER_UPDATE_ERROR';
END;
$$; 


-- =============================================
-- FUNCIÓN: fun_toggle_company v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Invierte el estado is_active de una compañía
--   en tab_companies (activo → inactivo / inactivo → activo).
--   Registra auditoría: user_update + updated_at.
--
-- Parámetros (IN):
--   wid_company    SMALLINT  — ID de la compañía
--   wuser_update   SMALLINT  — ID del usuario que realiza el cambio
--
-- Retorna (OUT):
--   success          BOOLEAN      — TRUE si se actualizó correctamente
--   msg              TEXT         — Mensaje descriptivo
--   error_code       VARCHAR(50)  — NULL si éxito; código si falla
--   out_id_company   SMALLINT     — ID afectado (NULL si falla)
--   out_company_name VARCHAR(100) — Nombre actual (NULL si falla)
--   out_nit_company  VARCHAR(15)  — NIT actual (NULL si falla)
--   out_is_active    BOOLEAN      — Nuevo estado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_company(SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_company(
  wid_company    tab_companies.id_company%TYPE,
  wuser_update   tab_companies.user_update%TYPE,

  -- Parámetros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_company   tab_companies.id_company%TYPE,
  OUT out_company_name tab_companies.company_name%TYPE,
  OUT out_nit_company  tab_companies.nit_company%TYPE,
  OUT out_is_active    tab_companies.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success          := FALSE;
  msg              := '';
  error_code       := NULL;
  out_id_company   := NULL;
  out_company_name := NULL;
  out_nit_company  := NULL;
  out_is_active    := NULL;

  UPDATE tab_companies
  SET
    is_active   = NOT is_active,
    updated_at  = NOW(),
    user_update = wuser_update
  WHERE id_company = wid_company
  RETURNING id_company, company_name, nit_company, is_active
  INTO out_id_company, out_company_name, out_nit_company, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontró la compañía con ID: ' || wid_company;
    error_code := 'COMPANY_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Compañía ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente: ' || out_company_name;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario actualizador no válido: ' || SQLERRM;
    error_code := 'COMPANY_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'COMPANY_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_company(SMALLINT, SMALLINT) IS
'v1.0 — Invierte is_active de compañía en tab_companies. Registra user_update y updated_at. Retorna COMPANY_NOT_FOUND si el ID no existe.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar compañía
SELECT * FROM fun_toggle_company(1, 1);

-- Resultado exitoso (desactivada):
-- success | msg                                         | error_code | out_id_company | out_company_name | out_nit_company | out_is_active
-- --------+---------------------------------------------+------------+----------------+------------------+-----------------+--------------
-- true    | Compañía desactivada exitosamente: Metrolínea | NULL     | 1              | Metrolínea       | 9001234561      | false

-- Volver a activar
SELECT * FROM fun_toggle_company(1, 1);
-- out_is_active = true

-- ID no existe → 404 en backend:
SELECT * FROM fun_toggle_company(99, 1);
-- success=false, error_code='COMPANY_NOT_FOUND'

*/

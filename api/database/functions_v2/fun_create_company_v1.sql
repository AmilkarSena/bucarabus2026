-- =============================================
-- FUNCIÓN: fun_create_company v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo registro en tab_companies.
--   Normaliza el nombre (TRIM + INITCAP).
--   El NIT se almacena tal cual (sin normalización).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wcompany_name  VARCHAR(100)  — Nombre de la Compañía
--   wnit_company   VARCHAR(15)   — NIT de la Compañía
--   wuser_create   SMALLINT      — ID del usuario que crea el registro
--
-- Retorna (OUT):
--   success          BOOLEAN      — TRUE si se creó correctamente
--   msg              TEXT         — Mensaje descriptivo
--   error_code       VARCHAR(50)  — NULL si éxito; código si falla
--   out_id_company   SMALLINT     — ID generado (NULL si falla)
--   out_company_name VARCHAR(100) — Nombre insertado (NULL si falla)
--   out_nit_company  VARCHAR(15)  — NIT insertado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_create_company(VARCHAR, VARCHAR, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_company(
  wcompany_name  tab_companies.company_name%TYPE,
  wnit_company   tab_companies.nit_company%TYPE,
  wuser_create   tab_companies.user_create%TYPE,

  -- Parámetros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_company   tab_companies.id_company%TYPE,
  OUT out_company_name tab_companies.company_name%TYPE,
  OUT out_nit_company  tab_companies.nit_company%TYPE
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

  INSERT INTO tab_companies (
    id_company, company_name, nit_company, user_create, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_company) FROM tab_companies), 0) + 1,
    INITCAP(TRIM(wcompany_name)),
    TRIM(wnit_company),
    wuser_create,
    TRUE,
    NOW()
  )
  RETURNING id_company, company_name, nit_company
  INTO out_id_company, out_company_name, out_nit_company;

  success := TRUE;
  msg     := 'Compañía creada exitosamente: ' || out_company_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una compañía con ese nombre o NIT: ' || SQLERRM;
    error_code := 'COMPANY_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Usuario creador no válido: ' || SQLERRM;
    error_code := 'COMPANY_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'COMPANY_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_company(VARCHAR, VARCHAR, SMALLINT) IS
'v1.0 — Crea compañía en tab_companies. Normaliza company_name con INITCAP/TRIM, NIT con TRIM. Genera ID con MAX+1. Validación de negocio delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear compañía
SELECT * FROM fun_create_company('NUEVA EMPRESA SA', '900123456-1', 1);

-- Resultado exitoso:
-- success | msg                                  | error_code | out_id_company | out_company_name   | out_nit_company
-- --------+--------------------------------------+------------+----------------+--------------------+-----------------
-- true    | Compañía creada exitosamente: ...    | NULL       | 5              | Nueva Empresa Sa   | 900123456-1

-- Nombre duplicado → 409 en backend:
SELECT * FROM fun_create_company('Metrolínea', '000000000-0', 1);
-- success=false, error_code='COMPANY_UNIQUE_VIOLATION'

*/

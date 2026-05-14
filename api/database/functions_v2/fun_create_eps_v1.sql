-- =============================================
-- FUNCIÓN: fun_create_eps v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Crea un nuevo registro en tab_eps.
--   Normaliza el nombre (TRIM + mayúscula inicial).
--   La validación de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actúan como última línea de defensa.
--
-- Parámetros (IN):
--   wname_eps     VARCHAR(60)  — Nombre de la EPS
--
-- Retorna (OUT):
--   success      BOOLEAN      — TRUE si se creó correctamente
--   msg          TEXT         — Mensaje descriptivo
--   error_code   VARCHAR(50)  — NULL si éxito; código si falla
--   out_id_eps   SMALLINT     — ID generado (NULL si falla)
--   out_name     VARCHAR(60)  — Nombre insertado (NULL si falla)
--
-- Versión   : 1.0
-- Fecha     : 2026-03-28
-- =============================================

DROP FUNCTION IF EXISTS fun_create_eps(VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_eps(
  wname_eps     tab_eps.name_eps%TYPE,

  -- Parámetros OUT
  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50),
  OUT out_id_eps tab_eps.id_eps%TYPE,
  OUT out_name   tab_eps.name_eps%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_eps := NULL;
  out_name   := NULL;

  INSERT INTO tab_eps (
    id_eps, name_eps, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_eps) FROM tab_eps), 0) + 1,
    INITCAP(TRIM(wname_eps)),
    TRUE,
    NOW()
  )
  RETURNING id_eps, name_eps
  INTO out_id_eps, out_name;

  success := TRUE;
  msg     := 'EPS creada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una EPS con ese nombre: ' || SQLERRM;
    error_code := 'EPS_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Usuario creador no válido: ' || SQLERRM;
    error_code := 'EPS_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'EPS_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_eps(VARCHAR) IS
'v1.0 — Crea EPS en tab_eps. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. Validación de negocio delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear EPS
SELECT * FROM fun_create_eps('NUEVA EPS SA');

-- Resultado exitoso:
-- success | msg                          | error_code | out_id_eps | out_name
-- TRUE    | EPS creada exitosamente: ... | NULL       | 14         | Nueva Eps Sa

-- Error: nombre duplicado
-- success | msg                                  | error_code          | out_id_eps | out_name
-- FALSE   | Ya existe una EPS con ese nombre ... | EPS_UNIQUE_VIOLATION | NULL      | NULL

*/

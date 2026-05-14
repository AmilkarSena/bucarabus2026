-- =============================================
-- FUNCION: fun_assign_driver
-- Directorio: functions_v2
-- =============================================
-- fun_assign_driver:   asigna un conductor a un bus (INSERT en tab_bus_assignments)
-- 
--
-- PK de tab_bus_assignments: (id_bus, id_driver, assigned_at)
--
-- La validación de negocio (conductor activo, bus disponible, etc.)
-- es responsabilidad del frontend y del backend (Node.js).
-- Los constraints e índices de la BD actúan como última barrera:
--   - uq_bus_active_assign    → un bus no puede tener dos conductores activos
--   - uq_driver_active_assign → un conductor no puede estar en dos buses activos
--   - FK constraints          → bus, conductor y usuario deben existir
--
-- Versión   : 1.0
-- Fecha     : 2026-03-11
-- =============================================

-- =============================================
-- fun_assign_driver
-- =============================================
DROP FUNCTION IF EXISTS fun_assign_driver(BIGINT, BIGINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_assign_driver(BIGINT, BIGINT, SMALLINT, BOOLEAN, TEXT, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION fun_assign_driver(
  wid_bus        tab_buses.id_bus%TYPE,
  wid_driver     tab_drivers.id_driver%TYPE,
  wassigned_by   tab_users.id_user%TYPE  DEFAULT 1,

  OUT success        BOOLEAN,
  OUT msg            TEXT,
  OUT error_code     VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  INSERT INTO tab_bus_assignments (id_bus, id_driver, assigned_at, assigned_by)
  VALUES (wid_bus, wid_driver, NOW(), wassigned_by);

  success := TRUE;
  msg     := 'Conductor asignado exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'El bus o conductor ya tiene una asignación activa: ' || SQLERRM;
    error_code := 'ASSIGNMENT_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Referencia inválida (bus, conductor o usuario no existe): ' || SQLERRM;
    error_code := 'ASSIGNMENT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ASSIGNMENT_ERROR';
END;
$$;


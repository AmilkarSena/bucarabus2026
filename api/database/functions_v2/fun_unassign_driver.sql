
-- =============================================
-- fun_unassign_driver
-- desasigna al conductor activo de un bus (UPDATE en tab_bus_assignments)
-- =============================================
DROP FUNCTION IF EXISTS fun_unassign_driver(BIGINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_unassign_driver(
  wid_driver      tab_drivers.id_driver%TYPE,
  wunassigned_by  tab_users.id_user%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  UPDATE tab_bus_assignments
  SET unassigned_at = NOW(),
      unassigned_by = wunassigned_by
  WHERE id_driver   = wid_driver
    AND unassigned_at IS NULL;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'No se encontró asignación activa para el conductor (id_driver: ' || COALESCE(wid_driver::TEXT, 'NULL') || ')';
    error_code := 'ASSIGNMENT_NOT_FOUND'; RETURN;
  END IF;

  success := TRUE;
  msg     := 'Conductor desasignado exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario de desasignación inválido: ' || SQLERRM;
    error_code := 'UNASSIGNMENT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'UNASSIGNMENT_ERROR';
END;
$$;


-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Asignar conductor 12345678 al bus ABC123 (usuario 1 asigna)
SELECT * FROM fun_assign_driver('ABC123', 12345678, 1);
-- success | msg                             | error_code
-- TRUE    | Conductor asignado exitosamente | NULL

-- Intentar asignar cuando el bus o conductor ya tiene asignación activa
-- (uq_bus_active_assign o uq_driver_active_assign disparan unique_violation)
SELECT * FROM fun_assign_driver('ABC123', 99999999, 1);
-- success | msg                                                    | error_code
-- FALSE   | El bus o conductor ya tiene una asignación activa: ... | ASSIGNMENT_UNIQUE_VIOLATION

-- Bus o conductor no existen (FK constraint dispara foreign_key_violation)
SELECT * FROM fun_assign_driver('ZZZ000', 12345678, 1);
-- success | msg                                                      | error_code
-- FALSE   | Referencia inválida (bus, conductor o usuario no existe) | ASSIGNMENT_FK_VIOLATION

-- Desasignar conductor 12345678 (usuario 1 realiza la desasignación)
SELECT * FROM fun_unassign_driver(12345678, 1);
-- success | msg                              | error_code
-- TRUE    | Conductor desasignado exitosamente | NULL

-- Intentar desasignar cuando no tiene asignación activa
SELECT * FROM fun_unassign_driver(12345678, 1);
-- success | msg                                                       | error_code
-- FALSE   | No se encontró asignación activa para el conductor (...)  | ASSIGNMENT_NOT_FOUND

*/

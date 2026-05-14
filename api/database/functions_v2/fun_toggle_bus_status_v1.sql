-- =============================================
-- FUNCIÓN: fun_toggle_bus_status v1.1
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Activa o desactiva un bus en tab_buses (campo is_active).
--   La validación de negocio (bus activo, usuario válido, etc.)
--   es responsabilidad del backend (Node.js).
--   Los constraints de la BD actúan como última barrera.
--
-- Parámetros (IN):
--   wplate_number  VARCHAR(6)  — Placa del bus (identificador único, no PK)
--   wis_active     BOOLEAN     — TRUE = activar, FALSE = desactivar
--   wuser_update   SMALLINT    — Usuario que realiza el cambio (FK a tab_users)
--
-- Retorna (OUT):
--   success       BOOLEAN      — TRUE si se aplicó el cambio
--   msg           TEXT         — Mensaje descriptivo del resultado
--   error_code    VARCHAR(50)  — NULL si success = TRUE
--   out_id_bus    SMALLINT     — id_bus (PK) del bus modificado
--   new_status    BOOLEAN      — Nuevo valor de is_active
--
-- Códigos de error:
--   BUS_NOT_FOUND    — La placa no existe en tab_buses
--   BUS_FK_VIOLATION — FK inválida (usuario no existe)
--   BUS_UPDATE_ERROR — Error inesperado en el UPDATE
--
-- Versión   : 1.1
-- Fecha     : 2026-03-15
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_bus_status(VARCHAR, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_bus_status(
  wplate_number  tab_buses.plate_number%TYPE,
  wis_active     BOOLEAN,
  wuser_update   tab_buses.user_update%TYPE,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT out_id_bus  tab_buses.id_bus%TYPE,
  OUT new_status  BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_plate  tab_buses.plate_number%TYPE;
  v_id_bus tab_buses.id_bus%TYPE;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_bus := NULL;
  new_status := NULL;

  v_plate := UPPER(TRIM(wplate_number));

  UPDATE tab_buses
  SET
    is_active   = wis_active,
    updated_at  = NOW(),
    user_update = wuser_update
  WHERE plate_number = v_plate
  RETURNING id_bus INTO v_id_bus;

  IF v_id_bus IS NULL THEN
    msg        := 'Bus no encontrado con placa: ' || v_plate;
    error_code := 'BUS_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  out_id_bus := v_id_bus;
  new_status := wis_active;
  msg        := 'Bus ' || v_plate || ' (id_bus=' || v_id_bus || ') '
                || CASE WHEN wis_active THEN 'activado' ELSE 'desactivado' END
                || ' exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario no válido: ' || SQLERRM;
    error_code := 'BUS_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BUS_UPDATE_ERROR';
END;
$$;

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar bus ABC123 (ejecutado por usuario 1)
SELECT * FROM fun_toggle_bus_status('ABC123', FALSE, 1);
-- success | msg                                         | error_code | out_id_bus | new_status
-- TRUE    | Bus ABC123 (id_bus=3) desactivado exitosamente | NULL    | 3          | FALSE

-- Activar bus previamente desactivado
SELECT * FROM fun_toggle_bus_status('ABC123', TRUE, 1);
-- success | msg                                       | error_code | out_id_bus | new_status
-- TRUE    | Bus ABC123 (id_bus=3) activado exitosamente | NULL    | 3          | TRUE

-- Placa inexistente
SELECT * FROM fun_toggle_bus_status('ZZZ999', FALSE, 1);
-- success | msg                                | error_code    | out_id_bus | new_status
-- FALSE   | Bus no encontrado con placa: ZZZ999 | BUS_NOT_FOUND | NULL      | NULL

*/

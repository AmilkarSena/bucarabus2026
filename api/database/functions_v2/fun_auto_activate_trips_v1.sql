-- =============================================
-- FUNCIÓN: fun_auto_activate_trips v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Activa automáticamente los viajes del día indicado cuya hora de inicio
--   ya llegó (start_time <= NOW()::TIME) y cuya hora de fin aún no ha pasado
--   (end_time > NOW()::TIME), pasándolos de id_status 1 ó 2 a id_status = 3.
--
-- Parámetros (IN):
--   wp_date   DATE  — Fecha del día a evaluar (YYYY-MM-DD).
--                     Se pasa desde Node para evitar desfase UTC vs Colombia.
--
-- Retorna: VOID
--
-- Notas:
--   - Solo activa viajes con id_bus IS NOT NULL (deben tener bus asignado).
--   - user_update = 1 identifica transiciones automáticas del sistema.
--   - Llamar antes de consultar viajes (lazy evaluation), justo antes de
--     fun_finalize_expired_trips para respetar el orden lógico.
--   - Los errores se propagan al caller (Node.js try/catch).
-- =============================================

CREATE OR REPLACE FUNCTION fun_auto_activate_trips(wp_date DATE, wp_time TIME)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows INTEGER;
BEGIN

    UPDATE tab_trips
    SET  id_status   = 3,
         started_at  = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END,
         updated_at  = NOW(),
         user_update = 1
    WHERE trip_date  = wp_date
      AND id_status  IN (1, 2)
      AND start_time <= wp_time
      AND end_time    > wp_time
      AND id_bus      IS NOT NULL
      AND is_active   = TRUE;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows > 0 THEN
        RAISE NOTICE 'fun_auto_activate_trips: % viaje(s) activado(s) automáticamente para %', v_rows, wp_date;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'fun_auto_activate_trips: error al activar viajes para % — % (%)',
            wp_date, SQLERRM, SQLSTATE;
END;
$$;

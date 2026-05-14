-- =============================================
-- FUNCIÓN: fun_finalize_expired_trips v1.0
-- Directorio: functions_v2
-- =============================================
-- Descripción:
--   Finaliza automáticamente los viajes del día indicado cuya hora de fin
--   ya haya pasado (end_time < NOW()::TIME), pasándolos a id_status = 4.
--
-- Parámetros (IN):
--   wp_date   DATE  — Fecha del día a evaluar (YYYY-MM-DD).
--                     Se pasa desde Node para evitar desfase UTC vs Colombia.
--
-- Retorna: VOID
--
-- Notas:
--   - user_update = 1 identifica transiciones automáticas del sistema.
--   - Llamar antes de consultar viajes activos (lazy evaluation).
--   - Los errores se propagan al caller (Node.js try/catch).
-- =============================================

CREATE OR REPLACE FUNCTION fun_finalize_expired_trips(wp_date DATE, wp_time TIME)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows INTEGER;
BEGIN

    UPDATE tab_trips
    SET  id_status    = 4,
         completed_at = NOW(),
         updated_at   = NOW(),
         user_update  = 1
    WHERE trip_date  = wp_date
      AND id_status  IN (1, 2, 3)
      AND end_time   < wp_time
      AND is_active  = TRUE;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows > 0 THEN
        RAISE NOTICE 'fun_finalize_expired_trips: % viaje(s) finalizado(s) automáticamente para %', v_rows, wp_date;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'fun_finalize_expired_trips: error al finalizar viajes vencidos para % — % (%)',
            wp_date, SQLERRM, SQLSTATE;
END;
$$;

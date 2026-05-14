-- =====================================================
-- MIGRACIÓN: fun_cancel_trip v2.0 → v3.0
-- Elimina funciones antiguas de cancelación y despliega nuevas
-- =====================================================

-- 1. ELIMINAR FUNCIONES ANTIGUAS (todas las variantes posibles)
-- =====================================================

-- Versión antigua que podría existir
DROP FUNCTION IF EXISTS fun_cancel_trip(BIGINT, INTEGER, VARCHAR, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trip(BIGINT, INTEGER, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trip(INTEGER, INTEGER, VARCHAR, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trip(INTEGER, INTEGER, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trip(BIGINT, INTEGER, VARCHAR);
DROP FUNCTION IF EXISTS fun_cancel_trip(BIGINT, INTEGER, TEXT);
DROP FUNCTION IF EXISTS fun_cancel_trip(BIGINT, INTEGER);
DROP FUNCTION IF EXISTS fun_cancel_trip(INTEGER, INTEGER);

-- Versiones batch antiguas
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER, VARCHAR, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER, VARCHAR);
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER, TEXT);
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER);

-- fun_delete_trip antiguas (si existen, también eliminarlas)
DROP FUNCTION IF EXISTS fun_delete_trip(BIGINT, INTEGER);
DROP FUNCTION IF EXISTS fun_delete_trip(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS fun_delete_trips_by_date(INTEGER, DATE, INTEGER);

COMMIT;

-- Mensaje de confirmación
DO $$ 
BEGIN 
    RAISE NOTICE '✅ Funciones antiguas eliminadas correctamente';
END $$;

-- =====================================================
-- 2. DESPLEGAR FUNCIONES V3.0
-- =====================================================
-- Ahora ejecutar fun_cancel_trip_v3.sql desde DBeaver/pgAdmin

COMMIT;

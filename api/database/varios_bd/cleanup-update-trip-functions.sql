-- =============================================
-- Script de limpieza: Eliminar TODAS las versiones de fun_update_trip
-- =============================================
-- Ejecuta este script ANTES de desplegar fun_update_trip_v3.sql
-- para asegurar que no haya conflictos con versiones anteriores
-- =============================================

-- Eliminar todas las posibles versiones de fun_update_trip

-- Versión con VARCHAR status (v1/v2)
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, TIME, TIME, VARCHAR, VARCHAR);

-- Versión con SMALLINT status (v3) - todos los parámetros
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, TIME, TIME, VARCHAR, SMALLINT);

-- Versión solo con horarios
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, TIME, TIME);

-- Versión solo con placa
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, VARCHAR);

-- Versión solo con estado
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, SMALLINT);
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, VARCHAR);

-- Versión sin parámetros opcionales
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER);

-- Eliminar cualquier otra sobrecarga que pueda existir
DROP FUNCTION IF EXISTS fun_update_trip CASCADE;

SELECT 'Todas las versiones de fun_update_trip han sido eliminadas' AS status;

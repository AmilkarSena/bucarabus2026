-- =============================================
-- BucaraBUS - Deployment Completo DB: db_bucarabus
-- =============================================
-- Ejecuta esquema + todas las funciones en db_bucarabus
-- =============================================

\echo ''
\echo '╔══════════════════════════════════════════════════════════╗'
\echo '║                                                          ║'
\echo '║       🚍 BucaraBUS - Deployment Completo v2.0           ║'
\echo '║           Base de datos: db_bucarabus                   ║'
\echo '║                                                          ║'
\echo '╚══════════════════════════════════════════════════════════╝'
\echo ''

-- Configurar opciones
\set ON_ERROR_STOP on
\timing on

\echo '📊 Iniciando deployment completo...'
\echo ''

-- =============================================
-- 1. ESQUEMA BASE
-- =============================================

\echo '▶ [1/16] Ejecutando: bd_bucarabus.sql'
\echo '  Esquema base de datos con tablas, índices y datos iniciales'
\i bd_bucarabus.sql

-- =============================================
-- 2. FUNCIONES CREATE
-- =============================================

\echo ''
\echo '▶ [2/16] Ejecutando: fun_create_user.sql'
\i fun_create_user.sql

\echo ''
\echo '▶ [3/16] Ejecutando: fun_create_bus.sql'
\i fun_create_bus.sql

\echo ''
\echo '▶ [4/16] Ejecutando: fun_create_driver.sql'
\i fun_create_driver.sql

\echo ''
\echo '▶ [5/16] Ejecutando: fun_create_route.sql'
\i fun_create_route.sql

\echo ''
\echo '▶ [6/16] Ejecutando: fun_create_trip.sql'
\i fun_create_trip.sql

-- =============================================
-- 3. FUNCIONES UPDATE
-- =============================================

\echo ''
\echo '▶ [7/16] Ejecutando: fun_update_user.sql'
\i fun_update_user.sql

\echo ''
\echo '▶ [8/16] Ejecutando: fun_update_bus.sql'
\i fun_update_bus.sql

\echo ''
\echo '▶ [9/16] Ejecutando: fun_update_driver.sql'
\i fun_update_driver.sql

\echo ''
\echo '▶ [10/16] Ejecutando: fun_update_route.sql'
\i fun_update_route.sql

\echo ''
\echo '▶ [11/16] Ejecutando: fun_update_trip.sql'
\i fun_update_trip.sql

-- =============================================
-- 4. FUNCIONES DELETE
-- =============================================

\echo ''
\echo '▶ [12/16] Ejecutando: fun_delete_driver.sql'
\i fun_delete_driver.sql

\echo ''
\echo '▶ [13/16] Ejecutando: fun_delete_route.sql'
\i fun_delete_route.sql

\echo ''
\echo '▶ [14/16] Ejecutando: fun_delete_trip.sql'
\i fun_delete_trip.sql

-- =============================================
-- 5. FUNCIONES ESPECIALES
-- =============================================

\echo ''
\echo '▶ [15/16] Ejecutando: fun_assign_driver.sql'
\i fun_assign_driver.sql

\echo ''
\echo '▶ [16/16] Ejecutando: fun_toggle_bus_status.sql'
\i fun_toggle_bus_status.sql

-- =============================================
-- 6. VERIFICACIÓN FINAL
-- =============================================

\echo ''
\echo '╔══════════════════════════════════════════════════════════╗'
\echo '║                    VERIFICACIÓN                          ║'
\echo '╚══════════════════════════════════════════════════════════╝'
\echo ''

\echo '📋 Resumen de funciones creadas:'
\echo ''

SELECT 
    COUNT(*) as total_funciones,
    COUNT(*) FILTER (WHERE proname LIKE 'fun_create_%') as create_fns,
    COUNT(*) FILTER (WHERE proname LIKE 'fun_update_%') as update_fns,
    COUNT(*) FILTER (WHERE proname LIKE 'fun_delete_%') as delete_fns,
    COUNT(*) FILTER (WHERE proname ~ 'fun_(assign|toggle|set|cancel)%') as special_fns
FROM pg_proc
WHERE proname LIKE 'fun_%';

\echo ''
\echo '📊 Detalle de funciones por categoría:'
\echo ''

SELECT 
    proname AS funcion,
    pronargs AS parametros,
    CASE 
        WHEN proname LIKE 'fun_create_%' THEN 'CREATE'
        WHEN proname LIKE 'fun_update_%' THEN 'UPDATE'
        WHEN proname LIKE 'fun_delete_%' THEN 'DELETE'
        ELSE 'ESPECIAL'
    END AS tipo
FROM pg_proc
WHERE proname LIKE 'fun_%'
ORDER BY tipo, proname;

\echo ''
\echo '🎉 ¡Deployment completado exitosamente!'
\echo ''

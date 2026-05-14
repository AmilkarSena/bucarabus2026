-- =============================================
-- BucaraBUS - Deployment SOLO Funciones (Sin Esquema)
-- =============================================
-- Versión: 2.0
-- Fecha: Febrero 2025
-- Descripción: Ejecuta SOLO las funciones, omite bd_bucarabus.sql
-- Uso: Para updates subsecuentes cuando el esquema ya existe
-- =============================================
-- 
-- INSTRUCCIONES DE USO:
-- 
-- Desde terminal:
--   psql -U bucarabus_user -d bucarabus_db -f deploy-functions-only.sql
-- 
-- Desde psql interactivo:
--   \c bucarabus_db
--   \i deploy-functions-only.sql
-- 
-- =============================================

\echo ''
\echo '╔══════════════════════════════════════════════════════════╗'
\echo '║                                                          ║'
\echo '║   🚍 BucaraBUS - Deployment Funciones SOLO (v2.0)       ║'
\echo '║                                                          ║'
\echo '╚══════════════════════════════════════════════════════════╝'
\echo ''
\echo '⚠️  NOTA: Este script NO ejecuta bd_bucarabus.sql'
\echo '   Asegúrate de que el esquema ya existe.'
\echo ''

-- Configurar opciones de salida
\set ON_ERROR_STOP on
\set ECHO queries
\timing on

\echo ''
\echo '📊 Iniciando deployment de funciones...'
\echo ''

-- =============================================
-- 1. FUNCIONES CREATE (5 archivos)
-- =============================================

\echo ''
\echo '▶ [1/15] Ejecutando: fun_create_user.sql'
\echo '  Crear usuarios en el sistema'
\i fun_create_user.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [2/15] Ejecutando: fun_create_bus.sql'
\echo '  Crear buses en el catálogo'
\i fun_create_bus.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [3/15] Ejecutando: fun_create_driver.sql'
\echo '  Crear conductores con detalles'
\i fun_create_driver.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [4/15] Ejecutando: fun_create_route.sql'
\echo '  Crear rutas con geometría PostGIS'
\i fun_create_route.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [5/15] Ejecutando: fun_create_trip.sql'
\echo '  Crear turnos/viajes programados (2 funciones)'
\i fun_create_trip.sql
\echo '  ✅ Éxito'

-- =============================================
-- 2. FUNCIONES UPDATE (5 archivos)
-- =============================================

\echo ''
\echo '▶ [6/15] Ejecutando: fun_update_user.sql'
\echo '  Actualizar datos de usuarios (nombre, avatar)'
\i fun_update_user.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [7/15] Ejecutando: fun_update_bus.sql'
\echo '  Actualizar datos de buses'
\i fun_update_bus.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [8/15] Ejecutando: fun_update_driver.sql'
\echo '  Actualizar datos de conductores'
\i fun_update_driver.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [9/15] Ejecutando: fun_update_route.sql'
\echo '  Actualizar metadatos de rutas'
\i fun_update_route.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [10/15] Ejecutando: fun_update_trip.sql'
\echo '  Actualizar turnos/viajes (2 funciones: update + set_bus)'
\i fun_update_trip.sql
\echo '  ✅ Éxito'

-- =============================================
-- 3. FUNCIONES DELETE (3 archivos)
-- =============================================

\echo ''
\echo '▶ [11/15] Ejecutando: fun_delete_driver.sql'
\echo '  Eliminar/desactivar conductores'
\i fun_delete_driver.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [12/15] Ejecutando: fun_delete_route.sql'
\echo '  Eliminar/desactivar rutas'
\i fun_delete_route.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [13/15] Ejecutando: fun_delete_trip.sql'
\echo '  Eliminar turnos/viajes (3 funciones)'
\i fun_delete_trip.sql
\echo '  ✅ Éxito'

-- =============================================
-- 4. FUNCIONES ESPECIALES (2 archivos)
-- =============================================

\echo ''
\echo '▶ [14/15] Ejecutando: fun_assign_driver.sql'
\echo '  Asignar/desasignar conductor a bus'
\i fun_assign_driver.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [15/15] Ejecutando: fun_toggle_bus_status.sql'
\echo '  Activar/desactivar buses'
\i fun_toggle_bus_status.sql
\echo '  ✅ Éxito'

-- =============================================
-- 5. VERIFICACIÓN POST-DEPLOYMENT
-- =============================================

\echo ''
\echo ''
\echo '╔══════════════════════════════════════════════════════════╗'
\echo '║                    VERIFICACIÓN                          ║'
\echo '╚══════════════════════════════════════════════════════════╝'
\echo ''

\echo '📋 Funciones actualizadas/creadas:'
\echo ''

SELECT 
    proname AS "Función",
    pronargs AS "# Args",
    CASE 
        WHEN proname LIKE 'fun_create_%' THEN 'CREATE'
        WHEN proname LIKE 'fun_update_%' THEN 'UPDATE'
        WHEN proname LIKE 'fun_delete_%' THEN 'DELETE'
        ELSE 'SPECIAL'
    END AS "Tipo"
FROM pg_proc
WHERE proname LIKE 'fun_%'
ORDER BY 
    CASE 
        WHEN proname LIKE 'fun_create_%' THEN 1
        WHEN proname LIKE 'fun_update_%' THEN 2
        WHEN proname LIKE 'fun_delete_%' THEN 3
        ELSE 4
    END,
    proname;

\echo ''
\echo ''
\echo '╔══════════════════════════════════════════════════════════╗'
\echo '║                    RESUMEN FINAL                         ║'
\echo '╚══════════════════════════════════════════════════════════╝'
\echo ''

-- Contar funciones por categoría
SELECT 
    'Total funciones fun_*' AS categoria,
    COUNT(*)::text AS cantidad
FROM pg_proc
WHERE proname LIKE 'fun_%'

UNION ALL

SELECT 
    'Funciones CREATE',
    COUNT(*)::text
FROM pg_proc
WHERE proname LIKE 'fun_create_%'

UNION ALL

SELECT 
    'Funciones UPDATE',
    COUNT(*)::text
FROM pg_proc
WHERE proname LIKE 'fun_update_%'

UNION ALL

SELECT 
    'Funciones DELETE',
    COUNT(*)::text
FROM pg_proc
WHERE proname LIKE 'fun_delete_%'

UNION ALL

SELECT 
    'Funciones ESPECIALES',
    COUNT(*)::text
FROM pg_proc
WHERE proname ~ 'fun_(assign|toggle|set)';

\echo ''
\echo '🎉 ¡Deployment de funciones completado!'
\echo ''
\echo '📝 Próximos pasos:'
\echo '   1. Verificar que todas las funciones tienen la firma correcta (INTEGER user_create/user_update)'
\echo '   2. Probar funciones con ejemplos de los comentarios'
\echo '   3. Actualizar backend si es necesario'
\echo '   4. Ejecutar pruebas end-to-end'
\echo ''

-- =============================================
-- FIN DEL DEPLOYMENT
-- =============================================

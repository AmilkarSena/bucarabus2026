-- =============================================
-- BucaraBUS - Deployment Completo de Funciones
-- =============================================
-- Versión: 2.0
-- Fecha: Febrero 2025
-- Descripción: Ejecuta todas las funciones en orden de dependencias
-- =============================================
-- 
-- INSTRUCCIONES DE USO:
-- 
-- Opción 1 - Desde terminal:
--   psql -U bucarabus_user -d bucarabus_db -f deploy-all.sql
-- 
-- Opción 2 - Desde psql interactivo:
--   \c bucarabus_db
--   \i deploy-all.sql
-- 
-- Opción 3 - Usar scripts automatizados:
--   PowerShell: .\deploy-functions.ps1
--   Bash:       ./deploy-functions.sh
-- 
-- =============================================

\echo ''
\echo '╔══════════════════════════════════════════════════════════╗'
\echo '║                                                          ║'
\echo '║       🚍 BucaraBUS - Deployment de Funciones v2.0       ║'
\echo '║                                                          ║'
\echo '╚══════════════════════════════════════════════════════════╝'
\echo ''

-- Configurar opciones de salida
\set ON_ERROR_STOP on
\set ECHO queries
\timing on

\echo ''
\echo '📊 Iniciando deployment...'
\echo ''

-- =============================================
-- 1. ESQUEMA BASE (Opcional - comentar si ya existe)
-- =============================================

\echo ''
\echo '▶ [1/16] Ejecutando: bd_bucarabus.sql'
\echo '  Esquema base de datos con tablas, índices y datos iniciales'
\i bd_bucarabus.sql
\echo '  ✅ Éxito'

-- =============================================
-- 2. FUNCIONES CREATE
-- =============================================

\echo ''
\echo '▶ [2/16] Ejecutando: fun_create_user.sql'
\echo '  Crear usuarios en el sistema'
\i fun_create_user.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [3/16] Ejecutando: fun_create_bus.sql'
\echo '  Crear buses en el catálogo'
\i fun_create_bus.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [4/16] Ejecutando: fun_create_driver.sql'
\echo '  Crear conductores con detalles'
\i fun_create_driver.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [5/16] Ejecutando: fun_create_route.sql'
\echo '  Crear rutas con geometría PostGIS'
\i fun_create_route.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [6/16] Ejecutando: fun_create_trip.sql'
\echo '  Crear turnos/viajes programados (2 funciones)'
\i fun_create_trip.sql
\echo '  ✅ Éxito'

-- =============================================
-- 3. FUNCIONES UPDATE
-- =============================================

\echo ''
\echo '▶ [7/16] Ejecutando: fun_update_user.sql'
\echo '  Actualizar datos de usuarios (nombre, avatar)'
\i fun_update_user.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [8/16] Ejecutando: fun_update_bus.sql'
\echo '  Actualizar datos de buses'
\i fun_update_bus.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [9/16] Ejecutando: fun_update_driver.sql'
\echo '  Actualizar datos de conductores'
\i fun_update_driver.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [10/16] Ejecutando: fun_update_route.sql'
\echo '  Actualizar metadatos de rutas'
\i fun_update_route.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [11/16] Ejecutando: fun_update_trip.sql'
\echo '  Actualizar turnos/viajes (2 funciones: update + set_bus)'
\i fun_update_trip.sql
\echo '  ✅ Éxito'

-- =============================================
-- 4. FUNCIONES DELETE
-- =============================================

\echo ''
\echo '▶ [12/16] Ejecutando: fun_delete_driver.sql'
\echo '  Eliminar/desactivar conductores'
\i fun_delete_driver.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [13/16] Ejecutando: fun_delete_route.sql'
\echo '  Eliminar/desactivar rutas'
\i fun_delete_route.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [14/16] Ejecutando: fun_delete_trip.sql'
\echo '  Eliminar turnos/viajes (3 funciones)'
\i fun_delete_trip.sql
\echo '  ✅ Éxito'

-- =============================================
-- 5. FUNCIONES ESPECIALES
-- =============================================

\echo ''
\echo '▶ [15/16] Ejecutando: fun_assign_driver.sql'
\echo '  Asignar/desasignar conductor a bus'
\i fun_assign_driver.sql
\echo '  ✅ Éxito'

\echo ''
\echo '▶ [16/16] Ejecutando: fun_toggle_bus_status.sql'
\echo '  Activar/desactivar buses'
\i fun_toggle_bus_status.sql
\echo '  ✅ Éxito'

-- =============================================
-- 6. VERIFICACIÓN POST-DEPLOYMENT
-- =============================================

\echo ''
\echo ''
\echo '╔══════════════════════════════════════════════════════════╗'
\echo '║                    VERIFICACIÓN                          ║'
\echo '╚══════════════════════════════════════════════════════════╝'
\echo ''

\echo '📋 Funciones creadas:'
\echo ''

SELECT 
    proname AS "Función",
    pronargs AS "# Args",
    pg_get_function_identity_arguments(oid) AS "Argumentos"
FROM pg_proc
WHERE proname LIKE 'fun_%'
ORDER BY proname;

\echo ''
\echo ''
\echo '╔══════════════════════════════════════════════════════════╗'
\echo '║                    RESUMEN FINAL                         ║'
\echo '╚══════════════════════════════════════════════════════════╝'
\echo ''

-- Contar funciones creadas
SELECT 
    COUNT(*) AS total_funciones,
    COUNT(*) FILTER (WHERE proname LIKE 'fun_create_%') AS create_functions,
    COUNT(*) FILTER (WHERE proname LIKE 'fun_update_%') AS update_functions,
    COUNT(*) FILTER (WHERE proname LIKE 'fun_delete_%') AS delete_functions,
    COUNT(*) FILTER (WHERE proname ~ 'fun_(assign|toggle)%') AS special_functions
FROM pg_proc
WHERE proname LIKE 'fun_%';

\echo ''
\echo '🎉 ¡Deployment completado exitosamente!'
\echo ''
\echo '📝 Próximos pasos:'
\echo '   1. Probar funciones CREATE con usuario del sistema (1735689600)'
\echo '   2. Actualizar backend para usar INTEGER en user_create/user_update'
\echo '   3. Ejecutar pruebas end-to-end'
\echo '   4. Verificar error codes en aplicaciones cliente'
\echo ''

-- =============================================
-- 7. PRUEBAS BÁSICAS (Opcional - comentar si no deseas ejecutar)
-- =============================================

\echo ''
\echo '🧪 Ejecutando pruebas básicas...'
\echo ''

-- Prueba 1: Verificar usuario del sistema
\echo '▶ Prueba 1: Usuario del sistema existe'
SELECT 
    id_user,
    email,
    full_name,
    is_active,
    created_at
FROM tab_users
WHERE id_user = 1735689600;

-- Prueba 2: Verificar roles
\echo ''
\echo '▶ Prueba 2: Roles del sistema'
SELECT 
    id_role,
    role_name,
    description,
    is_active
FROM tab_roles
ORDER BY id_role;

-- Prueba 3: Crear usuario de prueba (comentar si no deseas)
-- \echo ''
-- \echo '▶ Prueba 3: Crear usuario de prueba'
-- SELECT * FROM fun_create_user(
--     1735689650,
--     'test@bucarabus.com',
--     '$2b$10$TESTHASH000000000000000000000000000000000000000',
--     'Usuario de Prueba',
--     NULL,
--     1735689600
-- );

\echo ''
\echo '✅ Verificación completada'
\echo ''

-- =============================================
-- FIN DEL DEPLOYMENT
-- =============================================

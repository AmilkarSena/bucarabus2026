-- =============================================
-- BucaraBUS - Script de Prueba Rápida
-- =============================================
-- Base de datos: db_bucarabus
-- Ejecutar: psql -U bucarabus_user -d db_bucarabus -f test-functions.sql
-- =============================================

\echo ''
\echo '🧪 PRUEBAS DE FUNCIONES - db_bucarabus'
\echo '======================================'
\echo ''

-- =============================================
-- 1. PRUEBA: Crear usuario de prueba
-- =============================================

\echo '▶ Test 1: Crear usuario de prueba'

SELECT * FROM fun_create_user(
    'test@bucarabus.com',
    '$2b$10$TESTHASH0000000000000000000000000000000000000000',
    'Usuario de Prueba',
    1735689600,  -- Sistema crea el usuario
    'https://example.com/avatar.jpg'
);

\echo ''

-- =============================================
-- 2. PRUEBA: Actualizar usuario
-- =============================================

\echo '▶ Test 2: Actualizar usuario creado'

SELECT * FROM fun_update_user(
    (SELECT id_user FROM tab_users WHERE email = 'test@bucarabus.com'),
    1735689600,  -- Sistema actualiza
    'Usuario de Prueba Actualizado',
    'https://example.com/avatar2.jpg'
);

\echo ''

-- =============================================
-- 3. PRUEBA: Crear bus
-- =============================================

\echo '▶ Test 3: Crear bus de prueba'

SELECT * FROM fun_create_bus(
    'ABC123',              -- plate_number
    'AMB-0001',            -- amb_code
    1,                     -- id_company
    50,                    -- capacity
    'https://example.com/bus.jpg',  -- photo_url
    '2026-12-31',          -- soat_exp
    '2026-12-31',          -- techno_exp
    '2026-12-31',          -- rcc_exp
    '2026-12-31',          -- rce_exp
    1234567890,            -- id_card_owner
    'Empresa de Transporte',  -- name_owner
    1735689600             -- user_create
);

\echo ''

-- =============================================
-- 4. PRUEBA: Crear ruta
-- =============================================

\echo '▶ Test 4: Crear ruta de prueba'

SELECT * FROM fun_create_route(
    'Ruta Centro - Norte',
    '[[-73.1198, 7.1193], [-73.1150, 7.1250], [-73.1100, 7.1300]]',
    1735689600,  -- user_create
    'Ruta que conecta el centro con el norte de la ciudad',
    '#FF5733'
);

\echo ''

-- =============================================
-- 5. PRUEBA: Crear viaje/turno
-- =============================================

\echo '▶ Test 5: Crear viaje de prueba'

SELECT * FROM fun_create_trip(
    (SELECT id_route FROM tab_routes WHERE name_route = 'Ruta Centro - Norte'),
    CURRENT_DATE + INTERVAL '1 day',  -- Mañana
    '08:00:00',
    '10:00:00',
    1735689600,  -- user_create
    'ABC123',    -- plate_number
    'assigned'   -- status
);

\echo ''

-- =============================================
-- 6. VERIFICACIÓN FINAL
-- =============================================

\echo '======================================'
\echo '📊 RESUMEN DE DATOS CREADOS'
\echo '======================================'
\echo ''

\echo '👥 Usuarios:'
SELECT id_user, email, full_name, is_active 
FROM tab_users 
WHERE email LIKE '%@bucarabus%'
ORDER BY id_user;

\echo ''
\echo '🚌 Buses:'
SELECT plate_number, amb_code, capacity, is_active 
FROM tab_buses
ORDER BY plate_number;

\echo ''
\echo '🛣️  Rutas:'
SELECT id_route, name_route, color_route, status_route 
FROM tab_routes
ORDER BY id_route;

\echo ''
\echo '🎫 Viajes/Turnos:'
SELECT id_trip, id_route, trip_date, start_time, end_time, status_trip, plate_number
FROM tab_trips
ORDER BY id_trip;

\echo ''
\echo '✅ Pruebas completadas exitosamente'
\echo ''

-- =============================================
-- LIMPIEZA (Opcional - descomentar para eliminar datos de prueba)
-- =============================================

/*
\echo '🧹 Limpiando datos de prueba...'

-- Eliminar en orden inverso por dependencias
DELETE FROM tab_trips WHERE plate_number = 'ABC123';
DELETE FROM tab_routes WHERE name_route = 'Ruta Centro - Norte';
DELETE FROM tab_buses WHERE plate_number = 'ABC123';
DELETE FROM tab_users WHERE email = 'test@bucarabus.com';

\echo '✅ Datos de prueba eliminados'
*/

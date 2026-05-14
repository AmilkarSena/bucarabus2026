-- ============================================================================
-- FIX: Corrección del ID del usuario del sistema
-- ============================================================================
-- PROBLEMA: El usuario del sistema tiene ID = 1735689600 (epoch 2025-01-01)
--           pero la fórmula de generación de IDs produce números más pequeños
--           como 355911950, causando error ID_NOT_MONOTONIC.
--
-- SOLUCIÓN: Cambiar el ID del sistema a 1, y actualizar todas las referencias.
-- ============================================================================

BEGIN;

-- Paso 1: Crear temporalmente un usuario con ID = 1 para las referencias
INSERT INTO tab_users (id_user, email, password_hash, full_name, user_create, is_active)
VALUES (1, 'temp@bucarabus.local', '$2a$10$temp', 'Temporal', 1735689600, false)
ON CONFLICT (id_user) DO NOTHING;

-- Paso 2: Actualizar todas las referencias user_create/user_update de 1735689600 a 1
UPDATE tab_users SET user_create = 1 WHERE user_create = 1735689600;
UPDATE tab_users SET user_update = 1 WHERE user_update = 1735689600;

UPDATE tab_roles SET user_create = 1 WHERE user_create = 1735689600;
UPDATE tab_roles SET user_update = 1 WHERE user_update = 1735689600;

UPDATE tab_driver_details SET user_create = 1 WHERE user_create = 1735689600;
UPDATE tab_driver_details SET user_update = 1 WHERE user_update = 1735689600;

UPDATE tab_buses SET user_create = 1 WHERE user_create = 1735689600;
UPDATE tab_buses SET user_update = 1 WHERE user_update = 1735689600;

UPDATE tab_routes SET user_create = 1 WHERE user_create = 1735689600;
UPDATE tab_routes SET user_update = 1 WHERE user_update = 1735689600;

UPDATE tab_trips SET user_create = 1 WHERE user_create = 1735689600;
UPDATE tab_trips SET user_update = 1 WHERE user_update = 1735689600;

UPDATE tab_bus_assignments SET user_create = 1 WHERE user_create = 1735689600;
UPDATE tab_bus_assignments SET user_update = 1 WHERE user_update = 1735689600;

-- Paso 3: Eliminar el usuario antiguo con ID 1735689600
DELETE FROM tab_users WHERE id_user = 1735689600;

-- Paso 4: Actualizar el usuario temporal para que sea el usuario del sistema
UPDATE tab_users 
SET email = 'system@bucarabus.local',
    password_hash = '$2a$10$YourHashHere',  -- Cambiar si es necesario
    full_name = 'Sistema Bucarabus',
    is_active = true
WHERE id_user = 1;

-- Paso 5: Verificar el cambio
SELECT 
    id_user,
    email,
    full_name,
    user_create,
    user_update,
    created_at
FROM tab_users 
WHERE id_user = 1;

-- Mostrar mensaje de éxito
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ ID del usuario del sistema actualizado correctamente';
    RAISE NOTICE '   Anterior: 1735689600';
    RAISE NOTICE '   Nuevo:    1';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANTE: Actualizar SYSTEM_USER_ID en el código:';
    RAISE NOTICE '   - Frontend: src/constants/system.js';
    RAISE NOTICE '   - Backend:  api/.env y todos los archivos de services/routes';
    RAISE NOTICE '   - Cambiar de 1735689600 a 1';
    RAISE NOTICE '';
END $$;

COMMIT;

-- Actualizar los defaults de las columnas user_create en todas las tablas (fuera de la transacción)
ALTER TABLE tab_users ALTER COLUMN user_create SET DEFAULT 1;
ALTER TABLE tab_roles ALTER COLUMN user_create SET DEFAULT 1;
ALTER TABLE tab_driver_details ALTER COLUMN user_create SET DEFAULT 1;
ALTER TABLE tab_buses ALTER COLUMN user_create SET DEFAULT 1;
ALTER TABLE tab_routes ALTER COLUMN user_create SET DEFAULT 1;
ALTER TABLE tab_trips ALTER COLUMN user_create SET DEFAULT 1;
ALTER TABLE tab_bus_assignments ALTER COLUMN user_create SET DEFAULT 1;

-- Verificación final: mostrar el rango de IDs actual
SELECT 
    MIN(id_user) as id_minimo,
    MAX(id_user) as id_maximo,
    COUNT(*) as total_usuarios
FROM tab_users;

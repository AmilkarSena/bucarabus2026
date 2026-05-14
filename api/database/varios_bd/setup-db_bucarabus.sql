-- =============================================
-- BucaraBUS - Configuración Inicial DB: db_bucarabus
-- =============================================
-- Este script crea el usuario y la base de datos db_bucarabus
-- Ejecutar como usuario postgres
-- =============================================

-- Crear usuario si no existe
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'bucarabus_user') THEN
        CREATE USER bucarabus_user WITH PASSWORD 'bucarabus2024';
        RAISE NOTICE 'Usuario bucarabus_user creado exitosamente';
    ELSE
        RAISE NOTICE 'Usuario bucarabus_user ya existe';
    END IF;
END
$$;

-- Crear base de datos si no existe
SELECT 'CREATE DATABASE db_bucarabus OWNER bucarabus_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'db_bucarabus')\gexec

-- Conectar a la nueva base de datos y otorgar permisos
\c db_bucarabus

-- Crear extensión PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Otorgar todos los permisos
GRANT ALL PRIVILEGES ON DATABASE db_bucarabus TO bucarabus_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO bucarabus_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO bucarabus_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO bucarabus_user;

-- Configurar permisos por defecto para objetos futuros
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO bucarabus_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO bucarabus_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO bucarabus_user;

\echo ''
\echo '✅ Base de datos db_bucarabus configurada exitosamente'
\echo ''
\echo '📊 Información de conexión:'
\echo '   Base de datos: db_bucarabus'
\echo '   Usuario:       bucarabus_user'
\echo '   Contraseña:    bucarabus2024'
\echo '   Host:          localhost'
\echo '   Puerto:        5432'
\echo ''

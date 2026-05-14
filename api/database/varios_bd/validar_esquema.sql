-- =============================================
-- SCRIPT DE VALIDACIÓN - bd_bucarabus.sql
-- =============================================
-- Ejecutar DESPUÉS de crear el esquema para verificar integridad
-- =============================================

-- =============================================
-- 1. VERIFICAR TABLAS CREADAS
-- =============================================

SELECT 
  'Verificando tablas creadas...' AS status;

SELECT 
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) AS columnas
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
  AND table_name LIKE 'tab_%'
ORDER BY table_name;

-- =============================================
-- 2. VERIFICAR USUARIO DEL SISTEMA
-- =============================================

SELECT 
  'Verificando usuario del sistema...' AS status;

SELECT 
  id_user,
  email,
  full_name,
  created_at,
  user_create,
  is_active
FROM tab_users 
WHERE id_user = 1735689600;

-- =============================================
-- 3. VERIFICAR ROLES INICIALES
-- =============================================

SELECT 
  'Verificando roles del sistema...' AS status;

SELECT 
  id_role,
  role_name,
  description,
  user_create
FROM tab_roles
ORDER BY id_role;

-- =============================================
-- 4. VERIFICAR FOREIGN KEYS DE AUDITORÍA
-- =============================================

SELECT 
  'Verificando foreign keys de auditoría...' AS status;

SELECT 
  tc.table_name,
  tc.constraint_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu 
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND kcu.column_name IN ('user_create', 'user_update', 'assigned_by', 'unassigned_by')
ORDER BY tc.table_name, kcu.column_name;

-- =============================================
-- 5. VERIFICAR ÍNDICES DE AUDITORÍA
-- =============================================

SELECT 
  'Verificando índices de auditoría...' AS status;

SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexname LIKE '%created_by%' 
    OR indexname LIKE '%updated_by%'
    OR indexname LIKE '%assigned_by%')
ORDER BY tablename, indexname;

-- =============================================
-- 6. VERIFICAR ÍNDICES ESPACIALES (PostGIS)
-- =============================================

SELECT 
  'Verificando índices espaciales PostGIS...' AS status;

SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexdef LIKE '%GIST%'
ORDER BY tablename, indexname;

-- =============================================
-- 7. VERIFICAR TIPOS DE DATOS DE TIMESTAMPS
-- =============================================

SELECT 
  'Verificando tipos de datos de timestamps...' AS status;

SELECT 
  table_name,
  column_name,
  data_type,
  CASE 
    WHEN data_type = 'timestamp with time zone' THEN '✅'
    WHEN data_type = 'timestamp without time zone' THEN '❌'
    ELSE '⚠️'
  END AS validacion
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name IN ('created_at', 'updated_at', 'assigned_at', 'unassigned_at', 'added_at', 'last_login')
ORDER BY table_name, column_name;

-- =============================================
-- 8. VERIFICAR CHECK CONSTRAINTS
-- =============================================

SELECT 
  'Verificando constraints CHECK...' AS status;

SELECT 
  tc.table_name,
  tc.constraint_name,
  cc.check_clause
FROM information_schema.table_constraints tc
JOIN information_schema.check_constraints cc 
  ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

-- =============================================
-- 9. VERIFICAR UNIQUE CONSTRAINTS
-- =============================================

SELECT 
  'Verificando constraints UNIQUE...' AS status;

SELECT 
  tc.table_name,
  tc.constraint_name,
  STRING_AGG(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS columnas
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'UNIQUE'
  AND tc.table_schema = 'public'
GROUP BY tc.table_name, tc.constraint_name
ORDER BY tc.table_name, tc.constraint_name;

-- =============================================
-- 10. VERIFICAR EXTENSIONES
-- =============================================

SELECT 
  'Verificando extensiones instaladas...' AS status;

SELECT 
  extname AS extension,
  extversion AS version
FROM pg_extension
WHERE extname IN ('postgis', 'postgis_topology');

-- =============================================
-- 11. ESTADÍSTICAS DE ÍNDICES
-- =============================================

SELECT 
  'Estadísticas de índices por tabla...' AS status;

SELECT 
  tablename,
  COUNT(*) AS total_indices
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename LIKE 'tab_%'
GROUP BY tablename
ORDER BY total_indices DESC, tablename;

-- =============================================
-- 12. VERIFICAR DEFAULT VALUES
-- =============================================

SELECT 
  'Verificando valores DEFAULT...' AS status;

SELECT 
  table_name,
  column_name,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_default IS NOT NULL
  AND (column_name IN ('user_create', 'created_at', 'is_active', 'status_trip', 'status_route', 'status_driver')
    OR column_default LIKE '%1735689600%')
ORDER BY table_name, column_name;

-- =============================================
-- 13. RESUMEN FINAL
-- =============================================

SELECT 
  'RESUMEN FINAL DE VALIDACIÓN' AS status;

SELECT 
  'Tablas creadas' AS verificacion,
  COUNT(*) AS total
FROM information_schema.tables
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
  AND table_name LIKE 'tab_%'

UNION ALL

SELECT 
  'Foreign Keys',
  COUNT(*)
FROM information_schema.table_constraints
WHERE constraint_type = 'FOREIGN KEY'
  AND table_schema = 'public'

UNION ALL

SELECT 
  'Check Constraints',
  COUNT(*)
FROM information_schema.table_constraints
WHERE constraint_type = 'CHECK'
  AND table_schema = 'public'

UNION ALL

SELECT 
  'Unique Constraints',
  COUNT(*)
FROM information_schema.table_constraints
WHERE constraint_type = 'UNIQUE'
  AND table_schema = 'public'

UNION ALL

SELECT 
  'Primary Keys',
  COUNT(*)
FROM information_schema.table_constraints
WHERE constraint_type = 'PRIMARY KEY'
  AND table_schema = 'public'

UNION ALL

SELECT 
  'Índices totales',
  COUNT(*)
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename LIKE 'tab_%'

UNION ALL

SELECT 
  'Índices de auditoría',
  COUNT(*)
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexname LIKE '%created_by%' OR indexname LIKE '%updated_by%')

UNION ALL

SELECT 
  'Índices espaciales PostGIS',
  COUNT(*)
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexdef LIKE '%GIST%';

-- =============================================
-- 14. TEST DE INTEGRIDAD REFERENCIAL
-- =============================================

SELECT 
  'TEST: Insertando usuario de prueba...' AS status;

-- Probar inserción con auditoría
BEGIN;

INSERT INTO tab_users (
  id_user,
  email,
  password_hash,
  full_name,
  user_create
) VALUES (
  999,
  'test@bucarabus.local',
  '$2b$10$TESTHASH',
  'Usuario de Prueba',
  1735689600  -- Debe existir (usuario sistema)
);

-- Verificar que se insertó
SELECT 
  id_user,
  email,
  full_name,
  user_create,
  created_at
FROM tab_users
WHERE id_user = 999;

-- Rollback para no contaminar la BD
ROLLBACK;

SELECT 
  '✅ Test de integridad referencial completado' AS status;

-- =============================================
-- FIN DE VALIDACIÓN
-- =============================================

SELECT 
  '✅ VALIDACIÓN COMPLETADA EXITOSAMENTE' AS resultado,
  NOW() AS fecha_validacion;

-- =============================================
-- Migrar constraint UNIQUE a índice filtrado
-- =============================================
-- Problema: uq_trips_route_datetime bloquea creación de viajes
--           con mismo horario aunque el viejo esté cancelado
-- Solución: Reemplazar con índice único que solo aplica a is_active=TRUE

BEGIN;

-- 1. Eliminar constraint UNIQUE antigua
ALTER TABLE tab_trips 
DROP CONSTRAINT IF EXISTS uq_trips_route_datetime;

-- 2. Crear índice único FILTRADO (solo viajes activos)
CREATE UNIQUE INDEX IF NOT EXISTS uq_trips_route_datetime_active 
ON tab_trips (id_route, trip_date, start_time) 
WHERE is_active = TRUE;

-- Verificar
SELECT 
  indexname, 
  indexdef 
FROM pg_indexes 
WHERE tablename = 'tab_trips' 
  AND indexname = 'uq_trips_route_datetime_active';

COMMIT;

-- =============================================
-- Resultado esperado:
-- ✅ Permite crear viajes con horarios de viajes cancelados
-- ✅ Previene duplicados en viajes activos
-- ✅ Libera horarios al cancelar (is_active=FALSE)
-- =============================================

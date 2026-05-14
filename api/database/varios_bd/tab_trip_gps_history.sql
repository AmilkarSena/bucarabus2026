-- =============================================
-- Tabla para histórico GPS de viajes
-- Guarda snapshots cada 10 minutos
-- =============================================

CREATE TABLE IF NOT EXISTS tab_trip_gps_history (
    id_gps_record BIGSERIAL PRIMARY KEY,
    id_trip BIGINT NOT NULL REFERENCES tab_trips(id_trip) ON DELETE CASCADE,
    gps_location GEOGRAPHY(POINT, 4326) NOT NULL,  -- Coordenadas GPS (lat, lng)
    speed DECIMAL(5, 2),              -- Velocidad en km/h
    recorded_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Índices para consultas rápidas
CREATE INDEX IF NOT EXISTS idx_trip_gps_trip_id ON tab_trip_gps_history(id_trip, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_trip_gps_date ON tab_trip_gps_history(recorded_at);
CREATE INDEX IF NOT EXISTS idx_trip_gps_location ON tab_trip_gps_history USING GIST(gps_location);

-- Comentarios
COMMENT ON TABLE tab_trip_gps_history IS 'Histórico de ubicaciones GPS durante viajes (snapshots cada 10 min)';
COMMENT ON COLUMN tab_trip_gps_history.gps_location IS 'Coordenadas geográficas (Point con lat/lng en WGS84)';
COMMENT ON COLUMN tab_trip_gps_history.speed IS 'Velocidad del bus en km/h';
COMMENT ON COLUMN tab_trip_gps_history.recorded_at IS 'Momento exacto en que el GPS capturó esta ubicación';

-- Función para limpiar registros antiguos (opcional, mantener últimos 90 días)
CREATE OR REPLACE FUNCTION cleanup_old_gps_history()
RETURNS void AS $$
BEGIN
    DELETE FROM tab_trip_gps_history
    WHERE recorded_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- Job programado para limpieza (ejecutar manualmente o con pg_cron)
-- SELECT cleanup_old_gps_history();

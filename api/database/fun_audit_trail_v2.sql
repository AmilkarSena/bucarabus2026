-- =============================================
-- BucaraBUS - Auditoría Opción C
-- Triggers específicos por grupo de tablas
-- =============================================
-- Decisiones de diseño:
--   ✅ Auditan: tab_drivers, tab_buses, tab_bus_owners, tab_companies,
--               tab_bus_insurance, tab_bus_transit_docs,
--               tab_routes, tab_route_points, tab_parameters
--   ❌ No auditan:
--       tab_users           → solo admin, tabla pequeña
--       tab_bus_assignments → es log por diseño (append-only)
--       tab_route_points_assoc → alta frecuencia, ruido operacional
--       Catálogos puros     → tab_roles, tab_brands, tab_insurers,
--                             tab_eps, tab_arl, tab_trip_statuses
--   ⚠️  Geometría PostGIS  → excluida del JSONB (path_route, location_point)
--                             Se loguea solo la parte escalar del registro.
-- =============================================


-- =============================================
-- 1. TABLA DE AUDITORÍA
-- =============================================

DROP TABLE IF EXISTS tab_audit_log;

CREATE TABLE tab_audit_log (
  id          BIGINT       GENERATED ALWAYS AS IDENTITY,
  table_name  VARCHAR(50)  NOT NULL,
  record_id   TEXT,                      -- PK del registro como texto. PKs compuestas: 'val1|val2'
  operation   CHAR(1)      NOT NULL,     -- I=Insert  U=Update  D=Delete físico
  old_data    JSONB,                     -- Estado anterior (NULL en INSERT)
  new_data    JSONB,                     -- Estado nuevo (NULL en DELETE físico)
  changed_by  SMALLINT,                  -- ID usuario. Sin FK: preserva historial si el usuario se elimina
  changed_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_audit_log PRIMARY KEY (id),
  CONSTRAINT chk_audit_op CHECK (operation IN ('I', 'U', 'D'))
);

-- Índices orientados a las consultas más comunes
CREATE INDEX idx_audit_table  ON tab_audit_log (table_name, changed_at DESC);
CREATE INDEX idx_audit_record ON tab_audit_log (table_name, record_id, changed_at DESC);
CREATE INDEX idx_audit_user   ON tab_audit_log (changed_by,  changed_at DESC);

COMMENT ON TABLE  tab_audit_log IS 'Registro inmutable de cambios en tablas críticas de BucaraBUS.';
COMMENT ON COLUMN tab_audit_log.record_id  IS 'PK del registro afectado. Para PKs compuestas se usa ''col1|col2''.';
COMMENT ON COLUMN tab_audit_log.changed_by IS 'ID del usuario que realizó el cambio. Sin FK para preservar historial.';
COMMENT ON COLUMN tab_audit_log.old_data   IS 'Snapshot completo antes del cambio. NULL en INSERT. Geometría excluida.';
COMMENT ON COLUMN tab_audit_log.new_data   IS 'Snapshot completo después del cambio. NULL en DELETE. Geometría excluida.';


-- =============================================
-- 2. fun_audit_full
-- =============================================
-- Para tablas con user_create + user_update + created_at + updated_at.
--
-- Tablas objetivo:
--   tab_drivers, tab_buses, tab_bus_owners, tab_companies,
--   tab_bus_insurance, tab_bus_transit_docs,
--   tab_routes, tab_route_points
--
-- TG_ARGV[0] → columnas PK separadas por '|'
--              Ej: 'id_bus'  o  'id_bus|id_insurance_type'
-- TG_ARGV[1] → (opcional) columnas a EXCLUIR del JSONB separadas por '|'
--              Ej: 'path_route'  o  'path_route|geom_col2'
--              Usar para columnas PostGIS (WKB binario ilegible en JSON).
-- =============================================

DROP FUNCTION IF EXISTS fun_audit_full() CASCADE;

CREATE OR REPLACE FUNCTION fun_audit_full()
RETURNS TRIGGER AS $$
DECLARE
  v_row        RECORD;         -- Fila de referencia para extraer la PK
  v_record_id  TEXT  := '';    -- PK construida
  v_changed_by SMALLINT;       -- ID del usuario que realizó el cambio
  v_old_data   JSONB;          -- Estado anterior del registro
  v_new_data   JSONB;          -- Estado nuevo del registro
  v_pk_cols    TEXT[];         -- Columnas de la llave primaria
  v_excl_cols  TEXT[];         -- Columnas a excluir del JSONB
  v_col        TEXT;           -- Columna actual que se está procesando
  v_val        TEXT;           -- Valor actual de la columna
BEGIN

  -- ── Determinar fila de referencia para extraer la PK ──────────────────────
  IF TG_OP = 'DELETE' THEN
    v_row := OLD;
  ELSE
    v_row := NEW;
  END IF;

  -- ── Construir record_id desde columna(s) PK (TG_ARGV[0]) ─────────────────
  v_pk_cols := string_to_array(TG_ARGV[0], '|');
  FOREACH v_col IN ARRAY v_pk_cols LOOP
    EXECUTE format('SELECT ($1).%I::TEXT', v_col)
      INTO v_val
      USING v_row;
    IF v_record_id <> '' THEN
      v_record_id := v_record_id || '|';
    END IF;
    v_record_id := v_record_id || COALESCE(v_val, 'NULL');
  END LOOP;

  -- ── Columnas a excluir del JSONB (TG_ARGV[1], opcional) ──────────────────
  -- Usado para columnas PostGIS que generan WKB binario ilegible en el log
  IF array_length(TG_ARGV, 1) >= 2 AND TG_ARGV[1] IS NOT NULL THEN
    v_excl_cols := string_to_array(TG_ARGV[1], '|');
  END IF;

  -- ── INSERT ─────────────────────────────────────────────────────────────────
  IF TG_OP = 'INSERT' THEN

    NEW.created_at := CURRENT_TIMESTAMP;

    v_new_data   := to_jsonb(NEW);
    v_changed_by := NEW.user_create;

    -- Excluir columnas indicadas (ej: geometría PostGIS)
    IF v_excl_cols IS NOT NULL THEN
      FOREACH v_col IN ARRAY v_excl_cols LOOP
        v_new_data := v_new_data - v_col;
      END LOOP;
    END IF;

    INSERT INTO tab_audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (TG_TABLE_NAME, v_record_id, 'I', NULL, v_new_data, v_changed_by);

    RETURN NEW;
  END IF;

  -- ── UPDATE ─────────────────────────────────────────────────────────────────
  IF TG_OP = 'UPDATE' THEN

    -- No auditar si no hubo cambio real
    IF NEW IS NOT DISTINCT FROM OLD THEN
      RETURN OLD;
    END IF;

    NEW.updated_at := CURRENT_TIMESTAMP;

    v_old_data   := to_jsonb(OLD);
    v_new_data   := to_jsonb(NEW);
    v_changed_by := NEW.user_update;

    -- Excluir columnas indicadas
    IF v_excl_cols IS NOT NULL THEN
      FOREACH v_col IN ARRAY v_excl_cols LOOP
        v_old_data := v_old_data - v_col;
        v_new_data := v_new_data - v_col;
      END LOOP;
    END IF;

    -- Notificar desactivaciones (borrado lógico) cuando la tabla tiene is_active
    IF (v_old_data->>'is_active')::BOOLEAN IS DISTINCT FROM FALSE
       AND (v_new_data->>'is_active')::BOOLEAN = FALSE THEN
      RAISE NOTICE '[AUDIT] Desactivación en [%] id=[%] por usuario [%]',
        TG_TABLE_NAME, v_record_id, v_changed_by;
    END IF;

    INSERT INTO tab_audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (TG_TABLE_NAME, v_record_id, 'U', v_old_data, v_new_data, v_changed_by);

    RETURN NEW;
  END IF;

  -- ── DELETE físico (solo desde pgAdmin / scripts de admin) ─────────────────
  -- En la app nunca hay borrado físico → este bloque captura acciones manuales del DBA.
  IF TG_OP = 'DELETE' THEN

    v_old_data   := to_jsonb(OLD);
    v_changed_by := OLD.user_update;   -- Último usuario que modificó el registro

    IF v_excl_cols IS NOT NULL THEN
      FOREACH v_col IN ARRAY v_excl_cols LOOP
        v_old_data := v_old_data - v_col;
      END LOOP;
    END IF;

    INSERT INTO tab_audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (TG_TABLE_NAME, v_record_id, 'D', v_old_data, NULL, v_changed_by);

    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fun_audit_full IS
  'Trigger de auditoría para tablas con user_create + user_update.
   TG_ARGV[0]: columnas PK separadas por "|" (ej: "id_bus" o "id_bus|id_insurance_type").
   TG_ARGV[1]: columnas a excluir del JSONB, separadas por "|" (opcional, para PostGIS).
   Maneja INSERT, UPDATE y DELETE físico.';


-- =============================================
-- 3. fun_audit_params
-- =============================================
-- Exclusivo para tab_parameters.
-- Solo tiene user_update (no user_create).
-- Solo auditamos UPDATE: el INSERT es seed de admin.
-- =============================================

DROP FUNCTION IF EXISTS fun_audit_params() CASCADE;

CREATE OR REPLACE FUNCTION fun_audit_params()
RETURNS TRIGGER AS $$
BEGIN

  IF TG_OP = 'UPDATE' THEN

    IF NEW IS NOT DISTINCT FROM OLD THEN
      RETURN OLD;
    END IF;

    NEW.updated_at := CURRENT_TIMESTAMP;

    INSERT INTO tab_audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (
      TG_TABLE_NAME,
      NEW.param_key,            -- PK de tab_parameters
      'U',
      to_jsonb(OLD),
      to_jsonb(NEW),
      NEW.user_update
    );

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fun_audit_params IS
  'Trigger de auditoría exclusivo para tab_parameters.
   Solo procesa UPDATE (INSERT es seed de admin, sin user_create en la tabla).';


-- =============================================
-- 4. TRIGGERS
-- =============================================

-- ── tab_companies ─────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_companies ON tab_companies;
CREATE TRIGGER trg_audit_companies
  BEFORE INSERT OR UPDATE OR DELETE ON tab_companies
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_company');

-- ── tab_bus_owners ────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_bus_owners ON tab_bus_owners;
CREATE TRIGGER trg_audit_bus_owners
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_owners
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_owner');

-- ── tab_drivers ───────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_drivers ON tab_drivers;
CREATE TRIGGER trg_audit_drivers
  BEFORE INSERT OR UPDATE OR DELETE ON tab_drivers
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_driver');

-- ── tab_buses ─────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_buses ON tab_buses;
CREATE TRIGGER trg_audit_buses
  BEFORE INSERT OR UPDATE OR DELETE ON tab_buses
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_bus');

-- ── tab_bus_insurance (PK compuesta: id_bus + id_insurance_type) ──────────
DROP TRIGGER IF EXISTS trg_audit_bus_insurance ON tab_bus_insurance;
CREATE TRIGGER trg_audit_bus_insurance
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_insurance
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_bus|id_insurance_type');

-- ── tab_bus_transit_docs (PK compuesta: id_doc + id_bus) ──────────────────
DROP TRIGGER IF EXISTS trg_audit_bus_transit_docs ON tab_bus_transit_docs;
CREATE TRIGGER trg_audit_bus_transit_docs
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_transit_docs
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_doc|id_bus');

-- ── tab_routes (excluye path_route: geometría PostGIS LineString) ──────────
DROP TRIGGER IF EXISTS trg_audit_routes ON tab_routes;
CREATE TRIGGER trg_audit_routes
  BEFORE INSERT OR UPDATE OR DELETE ON tab_routes
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_route', 'path_route');

-- ── tab_route_points (excluye location_point: geometría PostGIS Point) ────
DROP TRIGGER IF EXISTS trg_audit_route_points ON tab_route_points;
CREATE TRIGGER trg_audit_route_points
  BEFORE INSERT OR UPDATE OR DELETE ON tab_route_points
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_point', 'location_point');

-- ── tab_parameters ────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_audit_parameters ON tab_parameters;
CREATE TRIGGER trg_audit_parameters
  BEFORE UPDATE ON tab_parameters
  FOR EACH ROW EXECUTE FUNCTION fun_audit_params();


-- =============================================
-- 5. MEJORA ADICIONAL: created_at en tab_users
-- =============================================
-- tab_users no tiene trigger de auditoría (solo la maneja el admin),
-- pero sí le falta created_at para saber cuándo fue creado cada usuario.

ALTER TABLE tab_users
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

COMMENT ON COLUMN tab_users.created_at IS 'Fecha de creación del usuario. Sin trigger de auditoría: tabla gestionada solo por admin.';


-- =============================================
-- 6. CONSULTAS DE REFERENCIA
-- =============================================

-- Ver todos los cambios de un registro específico (ej: bus id=5)
/*
SELECT changed_at, operation, changed_by,
       old_data, new_data
FROM   tab_audit_log
WHERE  table_name = 'tab_buses'
  AND  record_id  = '5'
ORDER BY changed_at DESC;
*/

-- Ver desactivaciones (borrado lógico) en conductores
/*
SELECT changed_at, record_id AS id_driver, changed_by,
       old_data->>'is_active' AS era_activo,
       new_data->>'is_active' AS ahora_activo,
       new_data->>'name_driver' AS conductor
FROM   tab_audit_log
WHERE  table_name = 'tab_drivers'
  AND  operation  = 'U'
  AND  (old_data->>'is_active')::BOOLEAN = TRUE
  AND  (new_data->>'is_active')::BOOLEAN = FALSE
ORDER BY changed_at DESC;
*/

-- Ver historial de pólizas de seguro de un bus (incluye renovaciones con DELETE+INSERT)
/*
SELECT changed_at, operation, record_id,
       COALESCE(new_data->>'id_insurance', old_data->>'id_insurance') AS poliza,
       COALESCE(new_data->>'end_date_insu', old_data->>'end_date_insu') AS vencimiento
FROM   tab_audit_log
WHERE  table_name = 'tab_bus_insurance'
  AND  record_id LIKE '5|%'   -- Reemplazar 5 con id_bus
ORDER BY changed_at DESC;
*/

-- Ver cambios en parámetros del sistema
/*
SELECT changed_at, record_id AS parametro, changed_by,
       old_data->>'param_value' AS valor_anterior,
       new_data->>'param_value' AS valor_nuevo
FROM   tab_audit_log
WHERE  table_name = 'tab_parameters'
ORDER BY changed_at DESC;
*/

-- Ver quién modificó qué en los últimos 7 días
/*
SELECT al.changed_at, al.table_name, al.record_id, al.operation,
       u.full_name AS usuario
FROM   tab_audit_log al
LEFT   JOIN tab_users u ON u.id_user = al.changed_by
WHERE  al.changed_at >= NOW() - INTERVAL '7 days'
ORDER BY al.changed_at DESC;
*/

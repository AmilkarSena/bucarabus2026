
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
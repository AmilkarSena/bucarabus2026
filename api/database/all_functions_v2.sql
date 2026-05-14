-- =============================================
-- FUNCTION: fun_assign_driver_v1.sql
-- =============================================
-- =============================================
-- FUNCION: fun_assign_driver
-- Directorio: functions_v2
-- =============================================
-- fun_assign_driver:   asigna un conductor a un bus (INSERT en tab_bus_assignments)
-- 
--
-- PK de tab_bus_assignments: (id_bus, id_driver, assigned_at)
--
-- La validaciÃ³n de negocio (conductor activo, bus disponible, etc.)
-- es responsabilidad del frontend y del backend (Node.js).
-- Los constraints e Ã­ndices de la BD actÃºan como Ãºltima barrera:
--   - uq_bus_active_assign    â†’ un bus no puede tener dos conductores activos
--   - uq_driver_active_assign â†’ un conductor no puede estar en dos buses activos
--   - FK constraints          â†’ bus, conductor y usuario deben existir
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-11
-- =============================================

-- =============================================
-- fun_assign_driver
-- =============================================
DROP FUNCTION IF EXISTS fun_assign_driver(BIGINT, BIGINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_assign_driver(BIGINT, BIGINT, SMALLINT, BOOLEAN, TEXT, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION fun_assign_driver(
  wid_bus        tab_buses.id_bus%TYPE,
  wid_driver     tab_drivers.id_driver%TYPE,
  wassigned_by   tab_users.id_user%TYPE  DEFAULT 1,

  OUT success        BOOLEAN,
  OUT msg            TEXT,
  OUT error_code     VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  INSERT INTO tab_bus_assignments (id_bus, id_driver, assigned_at, assigned_by)
  VALUES (wid_bus, wid_driver, NOW(), wassigned_by);

  success := TRUE;
  msg     := 'Conductor asignado exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'El bus o conductor ya tiene una asignaciÃ³n activa: ' || SQLERRM;
    error_code := 'ASSIGNMENT_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Referencia invÃ¡lida (bus, conductor o usuario no existe): ' || SQLERRM;
    error_code := 'ASSIGNMENT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ASSIGNMENT_ERROR';
END;
$$;



-- =============================================
-- FUNCTION: fun_assign_route_point_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_assign_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Asigna un punto de ruta existente a una ruta en tab_route_points_assoc.
--   Permite que una misma parada (ej. "Terminal MetrolÃ­nea") aparezca
--   en mÃºltiples rutas con orden, distancia y ETA propios por ruta.
--
--   Reglas de negocio (validar en backend antes de llamar):
--     - El id_point debe existir y estar activo en tab_route_points.
--     - El id_route debe existir y estar activo en tab_routes.
--     - El point_order no debe estar ya ocupado en esa ruta.
--
--   Los constraints de la BD (PK, UNIQUE, FK, CHECK) actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros (IN):
--   wid_route        tab_route_points_assoc.id_route%TYPE       â€” ID de la ruta
--   wid_point        tab_route_points_assoc.id_point%TYPE       â€” ID del punto a asignar
--   wpoint_order     tab_route_points_assoc.point_order%TYPE    â€” PosiciÃ³n en la ruta (> 0)
--   wdist_from_start tab_route_points_assoc.dist_from_start%TYPE â€” km acumulados (DEFAULT NULL)
--   weta_seconds     tab_route_points_assoc.eta_seconds%TYPE    â€” Segundos estimados (DEFAULT NULL)
--
-- Retorna (OUT):
--   success          BOOLEAN                                    â€” TRUE si se asignÃ³ correctamente
--   msg              TEXT                                       â€” Mensaje descriptivo
--   error_code       VARCHAR(50)                               â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_route     tab_route_points_assoc.id_route%TYPE      â€” ID de la ruta (confirmaciÃ³n)
--   out_id_point     tab_route_points_assoc.id_point%TYPE      â€” ID del punto asignado
--   out_point_order  tab_route_points_assoc.point_order%TYPE   â€” Orden asignado
--
-- CÃ³digos de error:
--   ROUTE_POINT_ASSOC_ORDER_TAKEN â€” El point_order ya estÃ¡ ocupado en esa ruta (PK)
--   ROUTE_POINT_ASSOC_FK          â€” FK invÃ¡lida (ruta o punto no existe)
--   ROUTE_POINT_ASSOC_CHECK       â€” point_order <= 0 o dist/eta negativos
--   ROUTE_POINT_ASSOC_ERROR       â€” Error inesperado
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_assign_route_point(SMALLINT, SMALLINT, SMALLINT, NUMERIC, INTEGER);

CREATE OR REPLACE FUNCTION fun_assign_route_point(
  wid_route         tab_route_points_assoc.id_route%TYPE,
  wid_point         tab_route_points_assoc.id_point%TYPE,
  wpoint_order      tab_route_points_assoc.point_order%TYPE,
  wdist_from_start  tab_route_points_assoc.dist_from_start%TYPE  DEFAULT NULL,
  weta_seconds      tab_route_points_assoc.eta_seconds%TYPE      DEFAULT NULL,

  -- ParÃ¡metros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_route     tab_route_points_assoc.id_route%TYPE,
  OUT out_id_point     tab_route_points_assoc.id_point%TYPE,
  OUT out_point_order  tab_route_points_assoc.point_order%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success         := FALSE;
  msg             := '';
  error_code      := NULL;
  out_id_route    := NULL;
  out_id_point    := NULL;
  out_point_order := NULL;

  INSERT INTO tab_route_points_assoc (
    id_route,
    id_point,
    point_order,
    dist_from_start,
    eta_seconds
  ) VALUES (
    wid_route,
    wid_point,
    wpoint_order,
    wdist_from_start,
    weta_seconds
  );

  out_id_route    := wid_route;
  out_id_point    := wid_point;
  out_point_order := wpoint_order;
  success         := TRUE;
  msg             := 'Punto (ID: ' || wid_point || ') asignado a ruta (ID: ' || wid_route
                     || ') en posiciÃ³n ' || wpoint_order || ' exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    -- Solo puede ser por PK (id_route, point_order)
    msg        := 'El orden ' || wpoint_order || ' ya estÃ¡ ocupado en la ruta (ID: ' || wid_route || ')';
    error_code := 'ROUTE_POINT_ASSOC_ORDER_TAKEN';
  WHEN foreign_key_violation THEN
    msg        := 'Ruta o punto no existe: ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_FK';
  WHEN check_violation THEN
    msg        := 'Valor fuera de rango (point_order > 0, dist >= 0, eta >= 0): ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_CHECK';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_assign_route_point(SMALLINT, SMALLINT, SMALLINT, NUMERIC, INTEGER) IS
'v1.0 â€” Asigna un punto de ruta (tab_route_points) a una ruta (tab_routes) mediante tab_route_points_assoc. Un mismo punto puede asignarse a mÃºltiples rutas con orden, distancia y ETA propios.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Asignar "Terminal MetrolÃ­nea" (id_point=1) a Ruta 1 en posiciÃ³n 1 (inicio)
SELECT * FROM fun_assign_route_point(1, 1, 1, 0.000, 0);
-- success | msg                                              | error_code | out_id_route | out_id_point | out_point_order
-- TRUE    | Punto (ID:1) asignado a ruta (ID:1) en posiciÃ³n 1 | NULL     | 1            | 1            | 1

-- Asignar el mismo punto a Ruta 3 en posiciÃ³n 5 (reutilizaciÃ³n)
SELECT * FROM fun_assign_route_point(3, 1, 5, 8.200, 1440);
-- success | msg                                              | error_code | out_id_route | out_id_point | out_point_order
-- TRUE    | Punto (ID:1) asignado a ruta (ID:3) en posiciÃ³n 5 | NULL     | 3            | 1            | 5

-- Error: punto ya asignado a esa ruta
SELECT * FROM fun_assign_route_point(1, 1, 2);
-- success | msg                                                    | error_code                    | ...
-- FALSE   | El punto (ID: 1) ya estÃ¡ asignado a la ruta (ID: 1)  | ROUTE_POINT_ASSOC_DUPLICATE   | NULL

-- Error: posiciÃ³n ya ocupada
SELECT * FROM fun_assign_route_point(1, 2, 1);
-- success | msg                                                    | error_code                      | ...
-- FALSE   | El orden 1 ya estÃ¡ ocupado en la ruta (ID: 1)        | ROUTE_POINT_ASSOC_ORDER_TAKEN   | NULL

*/


-- =============================================
-- FUNCTION: fun_audit_full.sql
-- =============================================

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
-- TG_ARGV[0] â†’ columnas PK separadas por '|'
--              Ej: 'id_bus'  o  'id_bus|id_insurance_type'
-- TG_ARGV[1] â†’ (opcional) columnas a EXCLUIR del JSONB separadas por '|'
--              Ej: 'path_route'  o  'path_route|geom_col2'
--              Usar para columnas PostGIS (WKB binario ilegible en JSON).
-- =============================================

DROP FUNCTION IF EXISTS fun_audit_full() CASCADE;

CREATE OR REPLACE FUNCTION fun_audit_full()
RETURNS TRIGGER AS $$
DECLARE
  v_row        RECORD;         -- Fila de referencia para extraer la PK
  v_record_id  TEXT  := '';    -- PK construida
  v_changed_by SMALLINT;       -- ID del usuario que realizÃ³ el cambio
  v_old_data   JSONB;          -- Estado anterior del registro
  v_new_data   JSONB;          -- Estado nuevo del registro
  v_pk_cols    TEXT[];         -- Columnas de la llave primaria
  v_excl_cols  TEXT[];         -- Columnas a excluir del JSONB
  v_col        TEXT;           -- Columna actual que se estÃ¡ procesando
  v_val        TEXT;           -- Valor actual de la columna
BEGIN

  -- â”€â”€ Determinar fila de referencia para extraer la PK â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  IF TG_OP = 'DELETE' THEN
    v_row := OLD;
  ELSE
    v_row := NEW;
  END IF;

  -- â”€â”€ Construir record_id desde columna(s) PK (TG_ARGV[0]) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  -- â”€â”€ Columnas a excluir del JSONB (TG_ARGV[1], opcional) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  -- Usado para columnas PostGIS que generan WKB binario ilegible en el log
  IF array_length(TG_ARGV, 1) >= 2 AND TG_ARGV[1] IS NOT NULL THEN
    v_excl_cols := string_to_array(TG_ARGV[1], '|');
  END IF;

  -- â”€â”€ INSERT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  IF TG_OP = 'INSERT' THEN

    NEW.created_at := CURRENT_TIMESTAMP;

    v_new_data   := to_jsonb(NEW);
    v_changed_by := NEW.user_create;

    -- Excluir columnas indicadas (ej: geometrÃ­a PostGIS)
    IF v_excl_cols IS NOT NULL THEN
      FOREACH v_col IN ARRAY v_excl_cols LOOP
        v_new_data := v_new_data - v_col;
      END LOOP;
    END IF;

    INSERT INTO tab_audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (TG_TABLE_NAME, v_record_id, 'I', NULL, v_new_data, v_changed_by);

    RETURN NEW;
  END IF;

  -- â”€â”€ UPDATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    -- Notificar desactivaciones (borrado lÃ³gico) cuando la tabla tiene is_active
    IF (v_old_data->>'is_active')::BOOLEAN IS DISTINCT FROM FALSE
       AND (v_new_data->>'is_active')::BOOLEAN = FALSE THEN
      RAISE NOTICE '[AUDIT] DesactivaciÃ³n en [%] id=[%] por usuario [%]',
        TG_TABLE_NAME, v_record_id, v_changed_by;
    END IF;

    INSERT INTO tab_audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (TG_TABLE_NAME, v_record_id, 'U', v_old_data, v_new_data, v_changed_by);

    RETURN NEW;
  END IF;

  -- â”€â”€ DELETE fÃ­sico (solo desde pgAdmin / scripts de admin) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  -- En la app nunca hay borrado fÃ­sico â†’ este bloque captura acciones manuales del DBA.
  IF TG_OP = 'DELETE' THEN

    v_old_data   := to_jsonb(OLD);
    v_changed_by := OLD.user_update;   -- Ãšltimo usuario que modificÃ³ el registro

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
  'Trigger de auditorÃ­a para tablas con user_create + user_update.
   TG_ARGV[0]: columnas PK separadas por "|" (ej: "id_bus" o "id_bus|id_insurance_type").
   TG_ARGV[1]: columnas a excluir del JSONB, separadas por "|" (opcional, para PostGIS).
   Maneja INSERT, UPDATE y DELETE fÃ­sico.';

-- =============================================
-- FUNCTION: fun_audit_params.sql
-- =============================================

-- =============================================
-- FUNCIÃ“N: fun_audit_params
-- Directorio: functions_v2
-- =============================================
-- Trigger de auditorÃ­a especÃ­fico para tab_parameters.
-- tab_parameters usa param_key (VARCHAR) como PK y solo tiene user_update.
-- Solo maneja UPDATE (los parÃ¡metros iniciales son seeds).
-- =============================================

DROP FUNCTION IF EXISTS fun_audit_params() CASCADE;

CREATE OR REPLACE FUNCTION fun_audit_params()
RETURNS TRIGGER AS $$
DECLARE
  v_old_data   JSONB;
  v_new_data   JSONB;
  v_changed_by SMALLINT;
BEGIN

  -- Solo auditar si hubo cambio real
  IF NEW IS NOT DISTINCT FROM OLD THEN
    RETURN OLD;
  END IF;

  -- Actualizar timestamp
  NEW.updated_at := CURRENT_TIMESTAMP;

  v_old_data   := to_jsonb(OLD);
  v_new_data   := to_jsonb(NEW);
  v_changed_by := NEW.user_update;

  INSERT INTO tab_audit_log (
    table_name, 
    record_id, 
    operation, 
    old_data, 
    new_data, 
    changed_by
  )
  VALUES (
    TG_TABLE_NAME, 
    OLD.param_key, 
    'U', 
    v_old_data, 
    v_new_data, 
    v_changed_by
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fun_audit_params() IS 
'Trigger de auditorÃ­a para la tabla tab_parameters. Registra cambios en los valores de configuraciÃ³n.';


-- =============================================
-- FUNCTION: fun_auto_activate_trips_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_auto_activate_trips v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Activa automÃ¡ticamente los viajes del dÃ­a indicado cuya hora de inicio
--   ya llegÃ³ (start_time <= NOW()::TIME) y cuya hora de fin aÃºn no ha pasado
--   (end_time > NOW()::TIME), pasÃ¡ndolos de id_status 1 Ã³ 2 a id_status = 3.
--
-- ParÃ¡metros (IN):
--   wp_date   DATE  â€” Fecha del dÃ­a a evaluar (YYYY-MM-DD).
--                     Se pasa desde Node para evitar desfase UTC vs Colombia.
--
-- Retorna: VOID
--
-- Notas:
--   - Solo activa viajes con id_bus IS NOT NULL (deben tener bus asignado).
--   - user_update = 1 identifica transiciones automÃ¡ticas del sistema.
--   - Llamar antes de consultar viajes (lazy evaluation), justo antes de
--     fun_finalize_expired_trips para respetar el orden lÃ³gico.
--   - Los errores se propagan al caller (Node.js try/catch).
-- =============================================

CREATE OR REPLACE FUNCTION fun_auto_activate_trips(wp_date DATE, wp_time TIME)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows INTEGER;
BEGIN

    UPDATE tab_trips
    SET  id_status   = 3,
         started_at  = CASE WHEN started_at IS NULL THEN NOW() ELSE started_at END,
         updated_at  = NOW(),
         user_update = 1
    WHERE trip_date  = wp_date
      AND id_status  IN (1, 2)
      AND start_time <= wp_time
      AND end_time    > wp_time
      AND id_bus      IS NOT NULL
      AND is_active   = TRUE;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows > 0 THEN
        RAISE NOTICE 'fun_auto_activate_trips: % viaje(s) activado(s) automÃ¡ticamente para %', v_rows, wp_date;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'fun_auto_activate_trips: error al activar viajes para % â€” % (%)',
            wp_date, SQLERRM, SQLSTATE;
END;
$$;


-- =============================================
-- FUNCTION: fun_cancel_trips_batch_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_cancel_trips_batch v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Cancela en lote todos los viajes activos de una ruta y fecha (soft delete).
--   La validaciÃ³n de negocio es responsabilidad del backend (Node.js);
--   los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros obligatorios (IN):
--   wid_route             tab_trips.id_route%TYPE    â€” ID de la ruta
--   wtrip_date            tab_trips.trip_date%TYPE   â€” Fecha de los viajes
--   wuser_cancel          tab_trips.user_update%TYPE â€” Usuario que cancela
--
-- ParÃ¡metros opcionales (IN):
--   wcancellation_reason  TEXT    DEFAULT NULL  â€” Motivo de cancelaciÃ³n
--   wforce_cancel_active  BOOLEAN DEFAULT FALSE â€” Si TRUE cancela tambiÃ©n status=3 (en curso)
--
-- Retorna (OUT):
--   success               BOOLEAN      â€” TRUE si se cancelÃ³ al menos un viaje
--   msg                   TEXT         â€” Mensaje descriptivo del resultado
--   error_code            VARCHAR(50)  â€” NULL si success = TRUE; cÃ³digo si falla
--   trips_cancelled       INTEGER      â€” Cantidad de viajes cancelados
--   trips_active_skipped  INTEGER      â€” Viajes en curso omitidos (wforce_cancel_active=FALSE)
--   cancelled_ids         INTEGER[]    â€” IDs de viajes cancelados
--
-- CÃ³digos de error:
--   NO_TRIPS_CANCELLED  â€” El UPDATE no afectÃ³ ninguna fila (ya cancelados o no existen)
--   BATCH_FK_VIOLATION  â€” FK invÃ¡lida en el UPDATE
--   BATCH_CANCEL_ERROR  â€” Error inesperado
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-18
-- =============================================

-- Limpiar versiones anteriores
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER);
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(INTEGER, DATE, INTEGER, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trips_batch(SMALLINT, DATE, SMALLINT, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_cancel_trips_batch(
  wid_route             tab_trips.id_route%TYPE,
  wtrip_date            tab_trips.trip_date%TYPE,
  wuser_cancel          tab_trips.user_update%TYPE,
  wcancellation_reason  TEXT    DEFAULT NULL,
  wforce_cancel_active  BOOLEAN DEFAULT FALSE,

  OUT success               BOOLEAN,
  OUT msg                   TEXT,
  OUT error_code            VARCHAR(50),
  OUT trips_cancelled       INTEGER,
  OUT trips_active_skipped  INTEGER,
  OUT cancelled_ids         INTEGER[]
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_ids  INTEGER[];
BEGIN
  success              := FALSE;
  msg                  := '';
  error_code           := NULL;
  trips_cancelled      := 0;
  trips_active_skipped := 0;
  cancelled_ids        := ARRAY[]::INTEGER[];

  -- Cancelar viajes activos de la ruta/fecha que no estÃ©n ya en estado terminal.
  -- status=3 (en curso) solo se incluye si wforce_cancel_active = TRUE.
  UPDATE tab_trips
     SET id_status           = 5,
         is_active            = FALSE,
         completed_at         = NOW(),
         cancellation_reason  = COALESCE(wcancellation_reason, cancellation_reason),
         updated_at           = NOW(),
         user_update          = wuser_cancel
   WHERE id_route  = wid_route
     AND trip_date = wtrip_date
     AND is_active = TRUE
     AND id_status NOT IN (4, 5)
     AND (id_status != 3 OR wforce_cancel_active = TRUE)
  RETURNING id_trip
  INTO v_ids;

  -- Necesario: UPDATE sin filas no genera excepciÃ³n; hay que chequearlo.
  GET DIAGNOSTICS trips_cancelled = ROW_COUNT;

  IF trips_cancelled = 0 THEN
    msg        := 'No hay viajes cancelables para la ruta ' || wid_route || ' en ' || wtrip_date;
    error_code := 'NO_TRIPS_CANCELLED';
    RETURN;
  END IF;

  -- Contar viajes en curso que quedaron omitidos (solo cuando no se forzÃ³)
  IF NOT wforce_cancel_active THEN
    SELECT COUNT(*)
      INTO trips_active_skipped
      FROM tab_trips
     WHERE id_route  = wid_route
       AND trip_date = wtrip_date
       AND id_status = 3
       AND is_active = TRUE;
  END IF;

  cancelled_ids := v_ids;
  success       := TRUE;
  msg           := trips_cancelled || ' viaje(s) cancelado(s) en ruta ' || wid_route || ' para ' || wtrip_date;

  IF trips_active_skipped > 0 THEN
    msg := msg || '. ' || trips_active_skipped || ' viaje(s) en curso omitido(s)';
  END IF;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Referencia invÃ¡lida al cancelar viajes: ' || SQLERRM;
    error_code := 'BATCH_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado al cancelar viajes: ' || SQLERRM;
    error_code := 'BATCH_CANCEL_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_cancel_trips_batch(SMALLINT, DATE, SMALLINT, TEXT, BOOLEAN) IS
'v1.0 â€” Cancela en lote los viajes activos de una ruta/fecha. '
'status=3 (en curso) solo se cancela con wforce_cancel_active=TRUE. '
'Errores: NO_TRIPS_CANCELLED, BATCH_FK_VIOLATION, BATCH_CANCEL_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Cancelar viajes pendientes/asignados (skip en curso):
SELECT * FROM fun_cancel_trips_batch(1, CURRENT_DATE, 1, 'RestructuraciÃ³n de horarios', FALSE);

-- Cancelar TODOS incluidos los en curso:
SELECT * FROM fun_cancel_trips_batch(1, CURRENT_DATE, 1, 'Emergencia: huelga de conductores', TRUE);

-- Sin motivo (opcional):
SELECT * FROM fun_cancel_trips_batch(1, CURRENT_DATE, 1);

*/

-- =============================================
-- FIN DE fun_cancel_trips_batch v1.0
-- =============================================


-- =============================================
-- FUNCTION: fun_cancel_trip_v1.sql
-- =============================================
-- =============================================================================
-- fun_cancel_trip
-- Version   : 1.0
-- Descripcion: Cancela un viaje (soft delete):
--              - Pone id_status = 5 (cancelado)
--              - Pone is_active  = FALSE
--              - Registra completed_at = NOW()
--              - Registra razon de cancelacion si se proporciona
--
-- Parametros:
--   wid_trip              INTEGER  - ID del viaje a cancelar
--   wuser_cancel          SMALLINT - ID del usuario que cancela
--   wcancellation_reason  TEXT     - Razon de cancelacion (opcional)
--   wforce_cancel         BOOLEAN  - Si TRUE cancela aunque el viaje este activo
--                                    (status=3). Si FALSE rechaza viajes activos.
--
-- Retorna:
--   success    BOOLEAN - TRUE si se cancelo correctamente
--   msg        TEXT    - Mensaje descriptivo del resultado
--   error_code TEXT    - Codigo de error si success = FALSE, NULL si success
--
-- Codigos de error:
--   TRIP_NOT_FOUND      - El viaje no existe
--   TRIP_ALREADY_DONE   - El viaje ya fue completado (status=4), no se puede cancelar
--   TRIP_ALREADY_CANCEL - El viaje ya estaba cancelado (status=5 / is_active=FALSE)
--   TRIP_IN_PROGRESS    - El viaje esta en curso (status=3) y wforce_cancel=FALSE
--   TRIP_CANCEL_ERROR   - Error inesperado al cancelar
-- =============================================================================

DROP FUNCTION IF EXISTS fun_cancel_trip(INTEGER, SMALLINT, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_cancel_trip(INTEGER, INTEGER, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_cancel_trip(
  wid_trip             INTEGER,
  wuser_cancel         SMALLINT,
  wcancellation_reason TEXT    DEFAULT NULL,
  wforce_cancel        BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(success BOOLEAN, msg TEXT, error_code TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_status  SMALLINT;
  v_is_active  BOOLEAN;
BEGIN
  -- Leer estado actual del viaje
  SELECT t.id_status, t.is_active
    INTO v_id_status, v_is_active
    FROM tab_trips t
   WHERE t.id_trip = wid_trip;

  IF NOT FOUND THEN
    msg        := 'Viaje no encontrado (ID: ' || wid_trip || ')';
    error_code := 'TRIP_NOT_FOUND';
    success    := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Verificar que no este ya cancelado
  IF v_id_status = 5 OR v_is_active = FALSE THEN
    msg        := 'El viaje ya fue cancelado anteriormente (ID: ' || wid_trip || ')';
    error_code := 'TRIP_ALREADY_CANCEL';
    success    := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Verificar que no este ya completado
  IF v_id_status = 4 THEN
    msg        := 'No se puede cancelar un viaje ya completado (ID: ' || wid_trip || ')';
    error_code := 'TRIP_ALREADY_DONE';
    success    := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Si esta en curso (status=3) requerir force_cancel
  IF v_id_status = 3 AND wforce_cancel = FALSE THEN
    msg        := 'El viaje esta en curso. Para cancelarlo usar wforce_cancel = TRUE';
    error_code := 'TRIP_IN_PROGRESS';
    success    := FALSE;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Ejecutar cancelacion
  UPDATE tab_trips
     SET id_status            = 5,
         is_active             = FALSE,
         completed_at          = NOW(),
         cancellation_reason   = COALESCE(wcancellation_reason, cancellation_reason),
         updated_at            = NOW(),
         user_update           = wuser_cancel
   WHERE id_trip = wid_trip;

  success    := TRUE;
  msg        := 'Viaje cancelado correctamente (ID: ' || wid_trip || ')';
  error_code := NULL;
  RETURN NEXT;

EXCEPTION WHEN OTHERS THEN
  success    := FALSE;
  msg        := 'Error al cancelar viaje: ' || SQLERRM;
  error_code := 'TRIP_CANCEL_ERROR';
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION fun_cancel_trip(INTEGER, SMALLINT, TEXT, BOOLEAN) IS
  'Cancela un viaje: id_status=5, is_active=FALSE, completed_at=NOW(). '
  'Requiere wforce_cancel=TRUE para viajes en curso (status=3). '
  'Para actualizar datos del viaje sin cancelar usar fun_update_trip.';

-- =============================================================================
-- Ejemplos de uso
-- =============================================================================
-- Cancelar viaje pendiente/asignado:
-- SELECT * FROM fun_cancel_trip(42, 1, 'Conductor no disponible', FALSE);
--
-- Cancelar viaje en curso (requiere force):
-- SELECT * FROM fun_cancel_trip(42, 1, 'Emergencia operativa', TRUE);
--
-- Cancelar sin razon:
-- SELECT * FROM fun_cancel_trip(42, 1);


-- =============================================
-- FUNCTION: fun_create_arl_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_arl v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo registro en tab_arl.
--   Normaliza el nombre (TRIM + mayÃºscula inicial).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wname_arl     VARCHAR(60)  â€” Nombre de la ARL
--
-- Retorna (OUT):
--   success      BOOLEAN      â€” TRUE si se creÃ³ correctamente
--   msg          TEXT         â€” Mensaje descriptivo
--   error_code   VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_arl   SMALLINT     â€” ID generado (NULL si falla)
--   out_name     VARCHAR(60)  â€” Nombre insertado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_create_arl(VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_arl(
  wname_arl     tab_arl.name_arl%TYPE,

  -- ParÃ¡metros OUT
  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50),
  OUT out_id_arl tab_arl.id_arl%TYPE,
  OUT out_name   tab_arl.name_arl%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_arl := NULL;
  out_name   := NULL;

  INSERT INTO tab_arl (
    id_arl, name_arl, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_arl) FROM tab_arl), 0) + 1,
    INITCAP(TRIM(wname_arl)),
    TRUE,
    NOW()
  )
  RETURNING id_arl, name_arl
  INTO out_id_arl, out_name;

  success := TRUE;
  msg     := 'ARL creada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una ARL con ese nombre: ' || SQLERRM;
    error_code := 'ARL_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ARL_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_arl(VARCHAR) IS
'v1.0 â€” Crea ARL en tab_arl. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';


-- =============================================
-- FUNCTION: fun_create_brand_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_brand v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo registro en tab_brands.
--   Normaliza el nombre (TRIM + mayÃºscula inicial).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wbrand_name   VARCHAR(50)  â€” Nombre de la marca
--
-- Retorna (OUT):
--   success        BOOLEAN     â€” TRUE si se creÃ³ correctamente
--   msg            TEXT        â€” Mensaje descriptivo
--   error_code     VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_brand   SMALLINT    â€” ID generado (NULL si falla)
--   out_name       VARCHAR(50) â€” Nombre insertado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_create_brand(VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_brand(
  wbrand_name     tab_brands.brand_name%TYPE,

  -- ParÃ¡metros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_brand tab_brands.id_brand%TYPE,
  OUT out_name     tab_brands.brand_name%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_brand := NULL;
  out_name     := NULL;

  INSERT INTO tab_brands (
    id_brand, brand_name, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_brand) FROM tab_brands), 0) + 1,
    INITCAP(TRIM(wbrand_name)),
    TRUE,
    NOW()
  )
  RETURNING id_brand, brand_name
  INTO out_id_brand, out_name;

  success := TRUE;
  msg     := 'Marca creada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una marca con ese nombre: ' || SQLERRM;
    error_code := 'BRAND_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BRAND_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_brand(VARCHAR) IS
'v1.0 â€” Crea marca en tab_brands. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';


-- =============================================
-- FUNCTION: fun_create_bus_insurance.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_bus_insurance v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea o reemplaza (Upsert) un seguro para un bus
--   en la tabla tab_bus_insurance.
--
-- ParÃ¡metros obligatorios (IN):
--   wid_bus            SMALLINT     â€” ID del bus
--   wid_insurance_type SMALLINT     â€” Tipo de seguro FK
--   wid_insurance      VARCHAR(50)  â€” NÃºmero de pÃ³liza
--   wid_insurer        SMALLINT     â€” Aseguradora FK
--   wstart_date_insu   DATE         â€” Fecha inicio
--   wend_date_insu     DATE         â€” Fecha fin
--   wuser_create       SMALLINT     â€” Usuario creador FK
--
-- ParÃ¡metros opcionales (IN):
--   wdoc_url           VARCHAR(500) â€” URL del documento
--
-- Retorna (OUT):
--   success      BOOLEAN      â€” TRUE si se registrÃ³ correctamente
--   msg          TEXT         â€” Mensaje descriptivo
--   error_code   VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--
-- VersiÃ³n   : 1.0
-- =============================================

DROP FUNCTION IF EXISTS fun_create_bus_insurance(SMALLINT, SMALLINT, VARCHAR, SMALLINT, DATE, DATE, SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_bus_insurance(
  wid_bus            tab_bus_insurance.id_bus%TYPE,
  wid_insurance_type tab_bus_insurance.id_insurance_type%TYPE,
  wid_insurance      tab_bus_insurance.id_insurance%TYPE,
  wid_insurer        tab_bus_insurance.id_insurer%TYPE,
  wstart_date_insu   tab_bus_insurance.start_date_insu%TYPE,
  wend_date_insu     tab_bus_insurance.end_date_insu%TYPE,
  wuser_create       tab_bus_insurance.user_create%TYPE,
  wdoc_url           tab_bus_insurance.doc_url%TYPE DEFAULT NULL,

  -- ParÃ¡metros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- Utiliza INSERT ... ON CONFLICT para remplazar en caso de que este bus
  -- ya tenga este tipo de seguro registrado
  INSERT INTO tab_bus_insurance (
    id_bus, id_insurance_type, id_insurance, id_insurer,
    start_date_insu, end_date_insu, doc_url, user_create
  ) VALUES (
    wid_bus,
    wid_insurance_type,
    UPPER(TRIM(wid_insurance)),
    wid_insurer,
    wstart_date_insu,
    wend_date_insu,
    NULLIF(TRIM(wdoc_url), ''),
    wuser_create
  )
  ON CONFLICT (id_bus, id_insurance_type) 
  DO UPDATE SET 
    id_insurance    = EXCLUDED.id_insurance,
    id_insurer      = EXCLUDED.id_insurer,
    start_date_insu = EXCLUDED.start_date_insu,
    end_date_insu   = EXCLUDED.end_date_insu,
    doc_url         = EXCLUDED.doc_url,
    user_update     = EXCLUDED.user_create,
    updated_at      = NOW();

  success := TRUE;
  msg     := 'Seguro registrado exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Esta pÃ³liza ya estÃ¡ registrada en otro bus: ' || SQLERRM;
    error_code := 'INSURANCE_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'RestricciÃ³n CHECK violada (fechas invÃ¡lidas): ' || SQLERRM;
    error_code := 'INSURANCE_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave forÃ¡nea invÃ¡lida (Bus, Tipo o Aseguradora no existen): ' || SQLERRM;
    error_code := 'INSURANCE_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INSURANCE_INSERT_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_bus_insurance(SMALLINT, SMALLINT, VARCHAR, SMALLINT, DATE, DATE, SMALLINT, VARCHAR) IS
'v1.0 â€” Crea o actualiza (Upsert) un seguro de bus. Si el bus ya tiene este tipo de seguro, lo sobreescribe.';


-- =============================================
-- FUNCTION: fun_create_bus_v2.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_bus v2.1
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo bus en tab_buses.
--   Normaliza texto e inserta directamente.
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros obligatorios (IN):
--   wplate_number    VARCHAR(6)   â€” Placa del bus
--   wamb_code        VARCHAR(8)   â€” CÃ³digo AMB
--   wcode_internal   VARCHAR(5)   â€” CÃ³digo interno
--   wid_company      SMALLINT     â€” ID compaÃ±Ã­a FK
--   wmodel_year      SMALLINT     â€” AÃ±o modelo
--   wcapacity_bus    SMALLINT     â€” Pasajeros
--   wcolor_bus       VARCHAR(30)  â€” Color
--   wid_owner        BIGINT       â€” CÃ©dula propietario FK
--   wuser_create     SMALLINT     â€” Usuario creador FK
--
-- ParÃ¡metros opcionales (IN):
--   wid_brand        SMALLINT     â€” Marca FK              (DEFAULT NULL)
--   wmodel_name      VARCHAR(50)  â€” Modelo                (DEFAULT 'SA')
--   wchassis_number  VARCHAR(50)  â€” Chasis                (DEFAULT 'SA')
--   wphoto_url       VARCHAR(500) â€” URL foto              (DEFAULT NULL)
--   wgps_device_id   VARCHAR(20)  â€” IMEI/ID dispositivo   (DEFAULT NULL)
--   wcolor_app       VARCHAR(7)   â€” Color hex para la app (DEFAULT '#CCCCCC')
--
-- Retorna (OUT):
--   success      BOOLEAN      â€” TRUE si se creÃ³ correctamente
--   msg          TEXT         â€” Mensaje descriptivo
--   error_code   VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_bus   SMALLINT     â€” ID interno generado (NULL si falla)
--   out_plate    VARCHAR(6)   â€” Placa insertada (NULL si falla)
--
-- VersiÃ³n   : 2.1
-- Fecha     : 2026-03-11
-- =============================================

DROP FUNCTION IF EXISTS fun_create_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_bus(
  wplate_number    tab_buses.plate_number%TYPE,
  wamb_code        tab_buses.amb_code%TYPE,
  wcode_internal   tab_buses.code_internal%TYPE,
  wid_company      tab_buses.id_company%TYPE,
  wmodel_year      tab_buses.model_year%TYPE,
  wcapacity_bus    tab_buses.capacity_bus%TYPE,
  wcolor_bus       tab_buses.color_bus%TYPE,
  wid_owner        tab_buses.id_owner%TYPE,
  wuser_create     tab_buses.user_create%TYPE,
  wid_brand        tab_buses.id_brand%TYPE       DEFAULT NULL,
  wmodel_name      tab_buses.model_name%TYPE     DEFAULT 'SA',
  wchassis_number  tab_buses.chassis_number%TYPE DEFAULT 'SA',
  wphoto_url       tab_buses.photo_url%TYPE      DEFAULT NULL,
  wgps_device_id   tab_buses.gps_device_id%TYPE  DEFAULT NULL,
  wcolor_app       tab_buses.color_app%TYPE      DEFAULT '#CCCCCC',

  -- ParÃ¡metros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_bus   tab_buses.id_bus%TYPE,
  OUT out_plate    tab_buses.plate_number%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_bus := NULL;
  out_plate  := NULL;

  INSERT INTO tab_buses (
    plate_number, amb_code, code_internal,
    id_company, id_brand, model_name, model_year, capacity_bus,
    chassis_number, color_bus, color_app, photo_url, gps_device_id,
    id_owner, id_status, is_active, created_at, user_create
  ) VALUES (
    UPPER(TRIM(wplate_number)),
    UPPER(TRIM(wamb_code)),
    UPPER(TRIM(wcode_internal)),
    wid_company,
    wid_brand,
    COALESCE(NULLIF(TRIM(wmodel_name),    ''), 'SA'),
    wmodel_year,
    wcapacity_bus,
    COALESCE(NULLIF(TRIM(wchassis_number),''), 'SA'),
    TRIM(wcolor_bus),
    COALESCE(NULLIF(TRIM(wcolor_app), ''), '#CCCCCC'),
    NULLIF(TRIM(wphoto_url),    ''),
    NULLIF(TRIM(wgps_device_id),''),
    wid_owner,
    1,
    TRUE,
    NOW(),
    wuser_create
  )
  RETURNING id_bus, plate_number
  INTO out_id_bus, out_plate;

  success   := TRUE;
  msg       := 'Bus creado exitosamente (Placa: ' || UPPER(TRIM(wplate_number)) || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Placa, cÃ³digo AMB, cÃ³digo interno o dispositivo GPS ya registrado: ' || SQLERRM;
    error_code := 'BUS_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'RestricciÃ³n CHECK violada: ' || SQLERRM;
    error_code := 'BUS_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave forÃ¡nea invÃ¡lida: ' || SQLERRM;
    error_code := 'BUS_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BUS_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS
'v2.1 â€” Crea bus en tab_buses. Normaliza texto e inserta directamente; retorna out_id_bus y out_plate. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear bus completo con todos los datos
SELECT * FROM fun_create_bus(
  'ABC123',           -- plate_number
  'AMB-0001',         -- amb_code
  'B001',             -- code_internal
  1,                  -- id_company (MetrolÃ­nea)
  2019,               -- model_year
  45,                 -- capacity_bus
  'Amarillo y rojo',  -- color_bus
  10000000,           -- id_owner (cÃ©dula propietario)
  1,                  -- user_create
  'Mercedes-Benz',    -- brand_bus
  'OF 1721',          -- model_name
  'CH123456789',      -- chassis_number
  NULL,               -- photo_url
  '352099001761481'   -- gps_device_id (IMEI)
);

-- Crear bus mÃ­nimo (campos opcionales usan DEFAULT)
SELECT * FROM fun_create_bus(
  'XYZ789',
  'AMB-0002',
  'B002',
  2,
  2022,
  42,
  'Blanco',
  10000000,
  1
);

-- Resultado exitoso:
-- success | msg                                     | error_code | out_id_bus | out_plate
-- TRUE    | Bus creado exitosamente (Placa: ABC123) | NULL       | 101        | ABC123

-- Error: placa duplicada
-- success | msg                              | error_code           | out_id_bus | out_plate
-- FALSE   | Placa ... ya registrado         | BUS_UNIQUE_VIOLATION | NULL       | NULL

-- Error: GPS ya asignado a otro bus
-- success | msg                                            | error_code           | out_id_bus | out_plate
-- FALSE   | El dispositivo GPS 352099001761481 ya estÃ¡ ... | BUS_UNIQUE_VIOLATION | NULL       | NULL

*/


-- =============================================
-- FUNCTION: fun_create_company_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_company v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo registro en tab_companies.
--   Normaliza el nombre (TRIM + INITCAP).
--   El NIT se almacena tal cual (sin normalizaciÃ³n).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wcompany_name  VARCHAR(100)  â€” Nombre de la CompaÃ±Ã­a
--   wnit_company   VARCHAR(15)   â€” NIT de la CompaÃ±Ã­a
--   wuser_create   SMALLINT      â€” ID del usuario que crea el registro
--
-- Retorna (OUT):
--   success          BOOLEAN      â€” TRUE si se creÃ³ correctamente
--   msg              TEXT         â€” Mensaje descriptivo
--   error_code       VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_company   SMALLINT     â€” ID generado (NULL si falla)
--   out_company_name VARCHAR(100) â€” Nombre insertado (NULL si falla)
--   out_nit_company  VARCHAR(15)  â€” NIT insertado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_create_company(VARCHAR, VARCHAR, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_company(
  wcompany_name  tab_companies.company_name%TYPE,
  wnit_company   tab_companies.nit_company%TYPE,
  wuser_create   tab_companies.user_create%TYPE,

  -- ParÃ¡metros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_company   tab_companies.id_company%TYPE,
  OUT out_company_name tab_companies.company_name%TYPE,
  OUT out_nit_company  tab_companies.nit_company%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success          := FALSE;
  msg              := '';
  error_code       := NULL;
  out_id_company   := NULL;
  out_company_name := NULL;
  out_nit_company  := NULL;

  INSERT INTO tab_companies (
    id_company, company_name, nit_company, user_create, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_company) FROM tab_companies), 0) + 1,
    INITCAP(TRIM(wcompany_name)),
    TRIM(wnit_company),
    wuser_create,
    TRUE,
    NOW()
  )
  RETURNING id_company, company_name, nit_company
  INTO out_id_company, out_company_name, out_nit_company;

  success := TRUE;
  msg     := 'CompaÃ±Ã­a creada exitosamente: ' || out_company_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una compaÃ±Ã­a con ese nombre o NIT: ' || SQLERRM;
    error_code := 'COMPANY_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Usuario creador no vÃ¡lido: ' || SQLERRM;
    error_code := 'COMPANY_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'COMPANY_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_company(VARCHAR, VARCHAR, SMALLINT) IS
'v1.0 â€” Crea compaÃ±Ã­a en tab_companies. Normaliza company_name con INITCAP/TRIM, NIT con TRIM. Genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear compaÃ±Ã­a
SELECT * FROM fun_create_company('NUEVA EMPRESA SA', '900123456-1', 1);

-- Resultado exitoso:
-- success | msg                                  | error_code | out_id_company | out_company_name   | out_nit_company
-- --------+--------------------------------------+------------+----------------+--------------------+-----------------
-- true    | CompaÃ±Ã­a creada exitosamente: ...    | NULL       | 5              | Nueva Empresa Sa   | 900123456-1

-- Nombre duplicado â†’ 409 en backend:
SELECT * FROM fun_create_company('MetrolÃ­nea', '000000000-0', 1);
-- success=false, error_code='COMPANY_UNIQUE_VIOLATION'

*/


-- =============================================
-- FUNCTION: fun_create_driver_v2.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_driver v2.1
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo conductor en tab_drivers.
--   Normaliza texto e inserta directamente.
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros obligatorios (IN):
--   wid_driver         BIGINT       â€” CÃ©dula del conductor (PK)
--   wname_driver       VARCHAR(100) â€” Nombre completo
--   wbirth_date        DATE         â€” Fecha de nacimiento
--   wlicense_exp       DATE         â€” Vencimiento de licencia
--   wuser_create       SMALLINT     â€” Usuario creador FK
--
-- ParÃ¡metros opcionales (IN / con DEFAULT):
--   waddress_driver    VARCHAR(200) â€” DirecciÃ³n              (DEFAULT 'SIN DIRECCIÃ“N')
--   wphone_driver      VARCHAR(15)  â€” TelÃ©fono               (DEFAULT '0900000000')
--   wemail_driver      VARCHAR(320) â€” Email                  (DEFAULT 'sa@sa.com')
--   wlicense_cat       VARCHAR(2)   â€” Cat. licencia          (DEFAULT 'SA')
--   wid_eps            SMALLINT     â€” EPS FK                 (DEFAULT 1)
--   wid_arl            SMALLINT     â€” ARL FK                 (DEFAULT 1)
--   wblood_type        VARCHAR(3)   â€” Tipo de sangre         (DEFAULT 'SA')
--   wemergency_contact VARCHAR(100) â€” Contacto emergencia    (DEFAULT 'SIN CONTACTO')
--   wemergency_phone   VARCHAR(15)  â€” TelÃ©fono emergencia    (DEFAULT '0900000000')
--   wdate_entry        DATE         â€” Fecha ingreso          (DEFAULT CURRENT_DATE)
--   wid_status         SMALLINT     â€” Estado operativo FK    (DEFAULT 1)
--
-- Retorna (OUT):
--   success      BOOLEAN     â€” TRUE si se creÃ³ correctamente
--   msg          TEXT        â€” Mensaje descriptivo
--   error_code   VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_driver   BIGINT      â€” CÃ©dula insertada (NULL si falla)
--
-- VersiÃ³n   : 2.1  â€” Elimina wid_user (vÃ­nculo movido a tab_driver_accounts)
-- Fecha     : 2026-03-17
-- =============================================

-- Limpiar versiones anteriores (firmas v1 sobre esquema legacy)
DROP FUNCTION IF EXISTS fun_create_driver(VARCHAR, VARCHAR, VARCHAR, DECIMAL, VARCHAR, VARCHAR, DATE, VARCHAR, TEXT, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_driver(VARCHAR(320), VARCHAR(60), VARCHAR(100), DECIMAL(12,0), VARCHAR(15), VARCHAR(2), DATE, VARCHAR(500), TEXT, INTEGER);
DROP FUNCTION IF EXISTS fun_create_driver(VARCHAR, TEXT, VARCHAR, DECIMAL, VARCHAR, VARCHAR, DATE, VARCHAR, TEXT, INTEGER, VARCHAR, SMALLINT, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_driver(BIGINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_driver(BIGINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_driver(
  -- ParÃ¡metros en el mismo orden que las columnas de tab_drivers
  -- Campos de auditorÃ­a (user_create) al final
  wid_driver          tab_drivers.id_driver%TYPE,
  wname_driver        tab_drivers.name_driver%TYPE        DEFAULT 'SIN NOMBRE',
  waddress_driver     tab_drivers.address_driver%TYPE     DEFAULT 'SIN DIRECCIÃ“N',
  wphone_driver       tab_drivers.phone_driver%TYPE       DEFAULT '0900000000',
  wemail_driver       tab_drivers.email_driver%TYPE       DEFAULT 'sa@sa.com',
  wbirth_date         tab_drivers.birth_date%TYPE         DEFAULT '2000-01-01',
  wgender_driver      tab_drivers.gender_driver%TYPE      DEFAULT 'O',
  wlicense_cat        tab_drivers.license_cat%TYPE        DEFAULT 'SA',
  wlicense_exp        tab_drivers.license_exp%TYPE        DEFAULT '2000-01-01',
  wid_eps             tab_drivers.id_eps%TYPE             DEFAULT 1,
  wid_arl             tab_drivers.id_arl%TYPE             DEFAULT 1,
  wblood_type         tab_drivers.blood_type%TYPE         DEFAULT 'SA',
  wemergency_contact  tab_drivers.emergency_contact%TYPE  DEFAULT 'SIN CONTACTO',
  wemergency_phone    tab_drivers.emergency_phone%TYPE    DEFAULT '0900000000',
  wdate_entry         tab_drivers.date_entry%TYPE         DEFAULT CURRENT_DATE,
  wid_status          tab_drivers.id_status%TYPE          DEFAULT 1,
  wuser_create        tab_drivers.user_create%TYPE        DEFAULT 1,

  OUT success         BOOLEAN,
  OUT msg             TEXT,
  OUT error_code      VARCHAR(50),
  OUT out_driver      tab_drivers.id_driver%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_driver := NULL;

  INSERT INTO tab_drivers (
    id_driver, name_driver, address_driver, phone_driver, email_driver,
    birth_date, gender_driver, license_cat, license_exp, id_eps, id_arl, blood_type,
    emergency_contact, emergency_phone, date_entry, id_status,
    is_active, created_at, user_create
  ) VALUES (
    wid_driver,
    TRIM(wname_driver),
    COALESCE(NULLIF(TRIM(waddress_driver),         ''), 'SIN DIRECCIÃ“N'),
    COALESCE(NULLIF(TRIM(wphone_driver),           ''), '0900000000'),
    COALESCE(NULLIF(LOWER(TRIM(wemail_driver)),    ''), 'sa@sa.com'),
    COALESCE(wbirth_date, '2000-01-01'),
    COALESCE(NULLIF(UPPER(TRIM(wgender_driver)),          ''), 'O'),
    COALESCE(NULLIF(TRIM(wlicense_cat),            ''), 'SA'),
    COALESCE(wlicense_exp, '2000-01-01'),
    wid_eps,
    wid_arl,
    COALESCE(NULLIF(TRIM(wblood_type),             ''), 'SA'),
    COALESCE(NULLIF(TRIM(wemergency_contact),      ''), 'SIN CONTACTO'),
    COALESCE(NULLIF(TRIM(wemergency_phone),        ''), '0900000000'),
    COALESCE(wdate_entry, CURRENT_DATE),
    wid_status,
    TRUE,
    NOW(),
    wuser_create
  )
  RETURNING id_driver INTO out_driver;

  success    := TRUE;
  msg        := 'Conductor creado exitosamente (CÃ©dula: ' || wid_driver || ')';


EXCEPTION
  WHEN unique_violation THEN
    msg        := 'La cÃ©dula o usuario de sistema ya existen: ' || SQLERRM;
    error_code := 'DRIVER_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave forÃ¡nea invÃ¡lida: ' || SQLERRM;
    error_code := 'DRIVER_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'RestricciÃ³n CHECK violada: ' || SQLERRM;
    error_code := 'DRIVER_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'DRIVER_INSERT_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_driver(BIGINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT) IS
'v2.1 â€” Crea conductor en tab_drivers. Eliminado wid_user (vÃ­nculo con tab_users movido a tab_driver_accounts). Normaliza texto; validaciÃ³n delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear conductor completo
SELECT * FROM fun_create_driver(
  1015432876,
  'Carlos Alberto PÃ©rez GÃ³mez',
  '1990-05-15'::DATE,
  '2027-12-31'::DATE,
  1,                   -- user_create
  'Calle 45 # 20-10',
  '3001234567',
  'carlos@email.com',
  'C2',
  1, 1,               -- id_eps, id_arl
  'O+',
  'MarÃ­a PÃ©rez',
  '3109876543',
  CURRENT_DATE,
  1                   -- id_status
);
-- Para vincular con tab_users, insertar despuÃ©s en tab_driver_accounts:
-- INSERT INTO tab_driver_accounts(id_driver, id_user) VALUES (1015432876, <id_user>);

-- Crear conductor mÃ­nimo (solo campos obligatorios)
SELECT * FROM fun_create_driver(
  1015432877,
  'Luis Fernando Torres',
  '1985-03-22'::DATE,
  '2026-06-30'::DATE,
  1
);

-- Resultado exitoso:
-- success | msg                                              | error_code | out_driver
-- TRUE    | Conductor creado exitosamente (CÃ©dula: 1015432876) | NULL       | 1015432876

-- Error: cÃ©dula duplicada (UNIQUE constraint)
-- success | msg                                                        | error_code              | out_driver
-- FALSE   | La cÃ©dula o usuario de sistema ya existen: ...detail...    | DRIVER_UNIQUE_VIOLATION | NULL

-- Error: EPS inexistente (FK constraint)
-- success | msg                               | error_code           | out_driver
-- FALSE   | Clave forÃ¡nea invÃ¡lida: ...detail... | DRIVER_FK_VIOLATION  | NULL

-- Error: licencia invÃ¡lida (CHECK constraint)
-- success | msg                                  | error_code              | out_driver
-- FALSE   | RestricciÃ³n CHECK violada: ...detail... | DRIVER_CHECK_VIOLATION | NULL

*/


-- =============================================
-- FUNCTION: fun_create_eps_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_eps v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo registro en tab_eps.
--   Normaliza el nombre (TRIM + mayÃºscula inicial).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wname_eps     VARCHAR(60)  â€” Nombre de la EPS
--
-- Retorna (OUT):
--   success      BOOLEAN      â€” TRUE si se creÃ³ correctamente
--   msg          TEXT         â€” Mensaje descriptivo
--   error_code   VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_eps   SMALLINT     â€” ID generado (NULL si falla)
--   out_name     VARCHAR(60)  â€” Nombre insertado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-28
-- =============================================

DROP FUNCTION IF EXISTS fun_create_eps(VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_eps(
  wname_eps     tab_eps.name_eps%TYPE,

  -- ParÃ¡metros OUT
  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50),
  OUT out_id_eps tab_eps.id_eps%TYPE,
  OUT out_name   tab_eps.name_eps%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_eps := NULL;
  out_name   := NULL;

  INSERT INTO tab_eps (
    id_eps, name_eps, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_eps) FROM tab_eps), 0) + 1,
    INITCAP(TRIM(wname_eps)),
    TRUE,
    NOW()
  )
  RETURNING id_eps, name_eps
  INTO out_id_eps, out_name;

  success := TRUE;
  msg     := 'EPS creada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una EPS con ese nombre: ' || SQLERRM;
    error_code := 'EPS_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Usuario creador no vÃ¡lido: ' || SQLERRM;
    error_code := 'EPS_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'EPS_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_eps(VARCHAR) IS
'v1.0 â€” Crea EPS en tab_eps. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear EPS
SELECT * FROM fun_create_eps('NUEVA EPS SA');

-- Resultado exitoso:
-- success | msg                          | error_code | out_id_eps | out_name
-- TRUE    | EPS creada exitosamente: ... | NULL       | 14         | Nueva Eps Sa

-- Error: nombre duplicado
-- success | msg                                  | error_code          | out_id_eps | out_name
-- FALSE   | Ya existe una EPS con ese nombre ... | EPS_UNIQUE_VIOLATION | NULL      | NULL

*/


-- =============================================
-- FUNCTION: fun_create_incident_type_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_incident_type v1.0
-- Directorio: functions_v2
-- =============================================
DROP FUNCTION IF EXISTS fun_create_incident_type(VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_incident_type(
  wname_incident tab_incident_types.name_incident%TYPE,
  wtag_incident  tab_incident_types.tag_incident%TYPE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_type   tab_incident_types.id_incident%TYPE,
  OUT out_name      tab_incident_types.name_incident%TYPE,
  OUT out_tag       tab_incident_types.tag_incident%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_type := NULL;
  out_name   := NULL;
  out_tag    := NULL;

  INSERT INTO tab_incident_types (
    name_incident, tag_incident, is_active
  ) VALUES (
    INITCAP(TRIM(wname_incident)),
    LOWER(TRIM(wtag_incident)),
    TRUE
  )
  RETURNING id_incident, name_incident, tag_incident
  INTO out_id_type, out_name, out_tag;

  success := TRUE;
  msg     := 'Tipo de incidente creado exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe un incidente con ese nombre o tag: ' || SQLERRM;
    error_code := 'INCIDENT_TYPE_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_TYPE_INSERT_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_incident_type(VARCHAR, VARCHAR) IS
'v1.0 â€” Crea un tipo de incidente. Normaliza nombre con INITCAP y tag con LOWER.';


-- =============================================
-- FUNCTION: fun_create_incident_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_incident_v1.0
-- =============================================
-- Registra un incidente reportado por un conductor.
-- La validaciÃ³n de negocio (trip activo, tipo vÃ¡lido) es
-- responsabilidad del backend; los constraints de la BD
-- actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros IN:
--   wid_trip          INTEGER           â€” Viaje en curso
--   wid_incident      SMALLINT          â€” ID del tipo de incidente
--   wlat_incident     DECIMAL(10,7)     â€” Latitud GPS
--   wlng_incident     DECIMAL(10,7)     â€” Longitud GPS
--   wdescrip_incident TEXT DEFAULT NULL â€” DescripciÃ³n libre
--
-- OUT:
--   success           BOOLEAN
--   msg               TEXT
--   error_code        VARCHAR(50)
--   out_id_trip_incident INTEGER
--
-- CÃ³digos de error:
--   INCIDENT_FK_VIOLATION   â€” id_trip no existe
--   INCIDENT_CHECK_VIOLATION â€” tipo invÃ¡lido
--   INCIDENT_INSERT_ERROR   â€” error inesperado
-- =============================================

DROP FUNCTION IF EXISTS fun_create_incident(INTEGER, VARCHAR, DECIMAL, DECIMAL, TEXT);

CREATE OR REPLACE FUNCTION fun_create_incident(
  wid_trip         tab_trip_incidents.id_trip%TYPE,
  wid_incident     tab_trip_incidents.id_incident%TYPE,
  wlat_incident    DECIMAL(10,7),
  wlng_incident    DECIMAL(10,7),
  wdescrip_incident tab_trip_incidents.descrip_incident%TYPE DEFAULT NULL,

  OUT success              BOOLEAN,
  OUT msg                  TEXT,
  OUT error_code           VARCHAR(50),
  OUT out_id_trip_incident tab_trip_incidents.id_trip_incident%TYPE
)
LANGUAGE plpgsql AS $$
BEGIN
  success              := FALSE;
  msg                  := '';
  error_code           := NULL;
  out_id_trip_incident := NULL;

  INSERT INTO tab_trip_incidents (
    id_trip, id_incident, descrip_incident,
    location_incident
  ) VALUES (
    wid_trip, wid_incident, wdescrip_incident,
    ST_SetSRID(ST_MakePoint(wlng_incident, wlat_incident), 4326)
  )
  RETURNING id_trip_incident INTO out_id_trip_incident;

  success := TRUE;
  msg     := 'Incidente registrado (ID: ' || out_id_trip_incident || ')';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'El viaje indicado no existe: ' || SQLERRM;
    error_code := 'INCIDENT_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Tipo de incidente o estado invÃ¡lido: ' || SQLERRM;
    error_code := 'INCIDENT_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_INSERT_ERROR';
END;
$$;


-- =============================================
-- FUNCTION: fun_create_insurance_type.sql
-- =============================================
-- ==========================================
-- CREAR TIPO DE SEGURO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_create_insurance_type(
    p_tag tab_insurance_types.tag_insurance%TYPE,
    p_name tab_insurance_types.name_insurance%TYPE,
    p_descrip tab_insurance_types.descrip_insurance%TYPE,
    p_mandatory tab_insurance_types.is_mandatory%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_type tab_insurance_types.id_insurance_type%TYPE
) AS $$
DECLARE
    v_id SMALLINT;
BEGIN
    INSERT INTO tab_insurance_types (tag_insurance, name_insurance, descrip_insurance, is_mandatory, is_active)
    VALUES (p_tag, p_name, p_descrip, p_mandatory, TRUE)
    RETURNING id_insurance_type INTO v_id;

    RETURN QUERY SELECT TRUE, 'Tipo de seguro creado correctamente.'::TEXT, NULL::VARCHAR, v_id;
EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un tipo de seguro con este nombre o tag.'::TEXT, 'INSURANCE_TYPE_UNIQUE_VIOLATION'::VARCHAR, NULL::SMALLINT;
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: fun_create_insurer_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_insurer v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo registro en tab_insurers.
--   Normaliza el nombre (TRIM + mayÃºscula inicial).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   winsurer_name   VARCHAR(100) â€” Nombre de la aseguradora
--
-- Retorna (OUT):
--   success          BOOLEAN     â€” TRUE si se creÃ³ correctamente
--   msg              TEXT        â€” Mensaje descriptivo
--   error_code       VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_insurer   SMALLINT    â€” ID generado (NULL si falla)
--   out_name         VARCHAR(100)â€” Nombre insertado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_create_insurer(VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_insurer(
  winsurer_name     tab_insurers.insurer_name%TYPE,

  -- ParÃ¡metros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_insurer   tab_insurers.id_insurer%TYPE,
  OUT out_name         tab_insurers.insurer_name%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success        := FALSE;
  msg            := '';
  error_code     := NULL;
  out_id_insurer := NULL;
  out_name       := NULL;

  INSERT INTO tab_insurers (
    id_insurer, insurer_name, is_active, created_at
  ) VALUES (
    COALESCE((SELECT MAX(id_insurer) FROM tab_insurers), 0) + 1,
    INITCAP(TRIM(winsurer_name)),
    TRUE,
    NOW()
  )
  RETURNING id_insurer, insurer_name
  INTO out_id_insurer, out_name;

  success := TRUE;
  msg     := 'Aseguradora creada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una aseguradora con ese nombre: ' || SQLERRM;
    error_code := 'INSURER_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INSURER_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_insurer(VARCHAR) IS
'v1.0 â€” Crea aseguradora en tab_insurers. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';


-- =============================================
-- FUNCTION: fun_create_route_point_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo punto de ruta en tab_route_points.
--   La validaciÃ³n de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   y los constraints de la BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros obligatorios (IN):
--   wname_point    tab_route_points.name_point%TYPE   â€” Nombre descriptivo
--   wlat           DOUBLE PRECISION                   â€” Latitud  (WGS-84)
--   wlng           DOUBLE PRECISION                   â€” Longitud (WGS-84)
--
-- ParÃ¡metros opcionales (IN):
--   wpoint_type    tab_route_points.point_type%TYPE    â€” 1=Parada (DEFAULT), 2=Referencia
--   wdescrip_point tab_route_points.descrip_point%TYPE â€” DescripciÃ³n adicional (DEFAULT NULL)
--   wis_checkpoint tab_route_points.is_checkpoint%TYPE â€” Punto de control (DEFAULT FALSE)
--   wuser_create   tab_route_points.user_create%TYPE   â€” Usuario creador (DEFAULT 1)
--
-- Retorna (OUT):
--   success        BOOLEAN                            â€” TRUE si se creÃ³ correctamente
--   msg            TEXT                               â€” Mensaje descriptivo
--   error_code     VARCHAR(50)                        â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_point   tab_route_points.id_point%TYPE     â€” ID generado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_create_route_point(VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, SMALLINT, TEXT, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_route_point(
  wname_point     tab_route_points.name_point%TYPE,
  wlat            DOUBLE PRECISION,                           -- Latitud (sin columna directa; tabla almacena GEOMETRY)
  wlng            DOUBLE PRECISION,                           -- Longitud (Ã­dem)
  wpoint_type     tab_route_points.point_type%TYPE    DEFAULT 1,
  wdescrip_point  tab_route_points.descrip_point%TYPE DEFAULT NULL,
  wis_checkpoint  tab_route_points.is_checkpoint%TYPE DEFAULT FALSE,
  wuser_create    tab_route_points.user_create%TYPE   DEFAULT 1,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_point  tab_route_points.id_point%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_point := NULL;

  INSERT INTO tab_route_points (
    point_type,
    name_point,
    location_point,
    descrip_point,
    is_checkpoint,
    user_create
  ) VALUES (
    wpoint_type,
    TRIM(wname_point),
    ST_SetSRID(ST_MakePoint(wlng, wlat), 4326),   -- PostGIS: MakePoint(lon, lat)
    NULLIF(TRIM(wdescrip_point), ''),
    wis_checkpoint,
    wuser_create
  )
  RETURNING id_point INTO out_id_point;

  success := TRUE;
  msg     := 'Punto de ruta creado exitosamente (ID: ' || out_id_point || ')';

EXCEPTION
  WHEN check_violation THEN
    msg        := 'Tipo de punto invÃ¡lido (point_type debe ser 1 o 2): ' || SQLERRM;
    error_code := 'ROUTE_POINT_CHECK_VIOLATION';
  WHEN not_null_violation THEN
    msg        := 'Campo obligatorio nulo: ' || SQLERRM;
    error_code := 'ROUTE_POINT_NULL_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_route_point(VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, SMALLINT, TEXT, BOOLEAN, SMALLINT) IS
'v1.0 â€” Crea un punto de ruta en tab_route_points. Acepta lat/lng por separado y construye el GEOMETRY internamente con ST_MakePoint(lng, lat). Retorna out_id_point.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear parada normal (Terminal del Norte)
SELECT * FROM fun_create_route_point(
  'Terminal del Norte',                            -- name_point
  7.1248,                                          -- lat
  -73.1127,                                        -- lng
  1,                                               -- point_type = Parada
  'Parada principal frente al Terminal del Norte', -- descrip_point
  FALSE,                                           -- is_checkpoint
  1                                                -- user_create
);

-- Crear punto de referencia + checkpoint (mÃ­nimo: solo nombre + coords)
SELECT * FROM fun_create_route_point(
  'Glorieta Caracoli',
  7.0893,
  -73.1341,
  2,      -- Referencia
  NULL,
  TRUE    -- es punto de control
);

-- Resultado exitoso:
-- success | msg                                      | error_code | out_id_point
-- TRUE    | Punto de ruta creado exitosamente (ID:1) | NULL       | 1

-- Error: point_type invÃ¡lido (ej. 3):
-- success | msg                                            | error_code                  | out_id_point
-- FALSE   | Tipo de punto invÃ¡lido (point_type debe ...) | ROUTE_POINT_CHECK_VIOLATION | NULL

*/


-- =============================================
-- FUNCTION: fun_create_route_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_route v1.3
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea una nueva ruta en tab_routes.
--   path_route se recibe como GeoJSON TEXT y se convierte internamente a GEOMETRY(SRID 4326).
--   La validaciÃ³n de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros obligatorios (IN):
--   wname_route    tab_routes.name_route%TYPE  â€” Nombre de la ruta
--   wpath_route    TEXT                         â€” GeoJSON LineString con el trayecto
--   wcolor_route   tab_routes.color_route%TYPE  â€” Color hex (#RRGGBB) para la UI
--   wid_company    tab_routes.id_company%TYPE   â€” FK a tab_companies
--   wuser_create   tab_routes.user_create%TYPE  â€” Usuario que crea el registro
--
-- ParÃ¡metros opcionales (IN):
--   wdescrip_route        tab_routes.descrip_route%TYPE        DEFAULT NULL
--   wfirst_trip           tab_routes.first_trip%TYPE           DEFAULT NULL
--   wlast_trip            tab_routes.last_trip%TYPE            DEFAULT NULL
--   wdeparture_route_sign tab_routes.departure_route_sign%TYPE DEFAULT NULL
--   wreturn_route_sign    tab_routes.return_route_sign%TYPE    DEFAULT NULL
--   wroute_fare           tab_routes.route_fare%TYPE           DEFAULT 0
--   wis_circular          BOOLEAN                              DEFAULT FALSE
--
-- Retorna (OUT):
--   success       BOOLEAN                      â€” TRUE si se creÃ³ correctamente
--   msg           TEXT                         â€” Mensaje descriptivo
--   error_code    VARCHAR(50)                  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_route  tab_routes.id_route%TYPE     â€” ID generado (NULL si falla)
--
-- CÃ³digos de error:
--   ROUTE_FK_VIOLATION    â€” FK invÃ¡lida (compaÃ±Ã­a o usuario no existe)
--   ROUTE_CHECK_VIOLATION â€” color invÃ¡lido o first_trip >= last_trip
--   ROUTE_GEOM_ERROR      â€” GeoJSON de path_route invÃ¡lido
--   ROUTE_INSERT_ERROR    â€” Error inesperado
--
-- VersiÃ³n   : 1.3
-- Fecha     : 2026-04-17
-- =============================================

DROP FUNCTION IF EXISTS fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, TEXT, TEXT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN);
DROP FUNCTION IF EXISTS fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_create_route(
  wname_route            tab_routes.name_route%TYPE,
  wpath_route            TEXT,                                          -- GeoJSON LineString
  wcolor_route           tab_routes.color_route%TYPE,
  wid_company            tab_routes.id_company%TYPE,
  wuser_create           tab_routes.user_create%TYPE,
  wdescrip_route         tab_routes.descrip_route%TYPE        DEFAULT NULL,
  wfirst_trip            tab_routes.first_trip%TYPE           DEFAULT NULL,
  wlast_trip             tab_routes.last_trip%TYPE            DEFAULT NULL,
  wdeparture_route_sign  tab_routes.departure_route_sign%TYPE DEFAULT NULL,
  wreturn_route_sign     tab_routes.return_route_sign%TYPE    DEFAULT NULL,
  wroute_fare            tab_routes.route_fare%TYPE           DEFAULT 0,
  wis_circular           BOOLEAN                              DEFAULT TRUE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_route  tab_routes.id_route%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_path_geom   GEOMETRY(LineString, 4326);
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_route := NULL;

  -- Convertir GeoJSON â†’ GEOMETRY
  BEGIN
    v_path_geom := ST_SetSRID(ST_GeomFromGeoJSON(wpath_route), 4326);
  EXCEPTION WHEN OTHERS THEN
    msg        := 'GeoJSON de path_route invÃ¡lido: ' || SQLERRM;
    error_code := 'ROUTE_GEOM_ERROR';
    RETURN;
  END;

  INSERT INTO tab_routes (
    name_route,
    path_route,
    descrip_route,
    color_route,
    id_company,
    first_trip,
    last_trip,
    departure_route_sign,
    return_route_sign,
    route_fare,
    is_circular,
    user_create
  ) VALUES (
    TRIM(wname_route),
    v_path_geom,
    NULLIF(TRIM(wdescrip_route), ''),
    UPPER(TRIM(wcolor_route)),
    wid_company,
    wfirst_trip,
    wlast_trip,
    NULLIF(TRIM(wdeparture_route_sign), ''),
    NULLIF(TRIM(wreturn_route_sign), ''),
    GREATEST(wroute_fare, 0),
    COALESCE(wis_circular, FALSE),
    wuser_create
  )
  RETURNING id_route INTO out_id_route;

  success := TRUE;
  msg     := 'Ruta creada exitosamente (ID: ' || out_id_route || ')';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'CompaÃ±Ã­a o usuario no existe: ' || SQLERRM;
    error_code := 'ROUTE_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Valor fuera de rango (color invÃ¡lido o first_trip >= last_trip): ' || SQLERRM;
    error_code := 'ROUTE_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN) IS
'v1.3 â€” Crea una ruta en tab_routes. Acepta path_route como GeoJSON TEXT. Recibe wroute_fare (tarifa) y wis_circular (circuito cerrado). Retorna out_id_route.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear ruta mÃ­nima (solo campos obligatorios)
SELECT * FROM fun_create_route(
  'Ruta 18 - Cabecera',
  '{"type":"LineString","coordinates":[[-73.1227,7.1193],[-73.1150,7.1300],[-73.1050,7.1400]]}',
  '#667eea',
  1,   -- id_company
  1    -- user_create
);
-- success | msg                              | error_code | out_id_route
-- TRUE    | Ruta creada exitosamente (ID: 1) | NULL       | 1

-- Crear ruta circular con todos los campos
SELECT * FROM fun_create_route(
  'Ruta 18 - Circular',
  '{"type":"LineString","coordinates":[[-73.1227,7.1193],[-73.1150,7.1300]]}',
  '#667eea',
  1,
  1,
  'Circuito desde Cabecera al Centro',
  '05:30:00',
  '22:00:00',
  'CABECERA â†’ CENTRO',
  'CENTRO â†’ CABECERA',
  2500,
  TRUE
);

-- Error: GeoJSON invÃ¡lido
-- success | msg                              | error_code       | out_id_route
-- FALSE   | GeoJSON de path_route invÃ¡lido   | ROUTE_GEOM_ERROR | NULL

*/


-- =============================================
-- FUNCTION: fun_create_route_v2.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_route v2.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea una nueva ruta en tab_routes Y asigna sus paradas en tab_route_points_assoc
--   en una Ãºnica transacciÃ³n atÃ³mica (BEGIN...COMMIT implÃ­cito de PL/pgSQL).
--
--   Cambio respecto a v1: acepta un JSONB con el array de paradas ordenadas.
--   Si la inserciÃ³n de cualquier parada falla, TODA la ruta se revierte (ROLLBACK).
--
-- ParÃ¡metros obligatorios (IN):
--   wname_route    VARCHAR   â€” Nombre de la ruta
--   wpath_route    TEXT      â€” GeoJSON LineString con el trayecto calculado por OSRM
--   wcolor_route   VARCHAR   â€” Color hex (#RRGGBB) para la UI
--   wid_company    SMALLINT  â€” FK a tab_companies
--   wuser_create   SMALLINT  â€” Usuario que crea el registro
--   wstops         JSONB     â€” Array de paradas en orden:
--                              [{ "id_point": 1, "dist_from_start": 0.0, "eta_seconds": 0 }, ...]
--                              dist_from_start y eta_seconds son opcionales (DEFAULT NULL).
--
-- ParÃ¡metros opcionales (IN):
--   wdescrip_route        TEXT      DEFAULT NULL
--   wfirst_trip           TIME      DEFAULT NULL
--   wlast_trip            TIME      DEFAULT NULL
--   wdeparture_route_sign VARCHAR   DEFAULT NULL
--   wreturn_route_sign    VARCHAR   DEFAULT NULL
--   wroute_fare           SMALLINT  DEFAULT 0
--   wis_circular          BOOLEAN   DEFAULT FALSE
--
-- Retorna (OUT):
--   success       BOOLEAN    â€” TRUE si se creÃ³ correctamente
--   msg           TEXT       â€” Mensaje descriptivo
--   error_code    VARCHAR(50)â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_route  SMALLINT   â€” ID generado (NULL si falla)
--
-- CÃ³digos de error:
--   ROUTE_FK_VIOLATION     â€” FK invÃ¡lida (compaÃ±Ã­a o usuario no existe)
--   ROUTE_CHECK_VIOLATION  â€” color invÃ¡lido o first_trip >= last_trip
--   ROUTE_GEOM_ERROR       â€” GeoJSON de path_route invÃ¡lido
--   ROUTE_STOPS_EMPTY      â€” Array de paradas vacÃ­o o con menos de 2 puntos
--   ROUTE_STOP_INVALID     â€” id_point no existe o no estÃ¡ activo
--   ROUTE_STOP_ERROR       â€” Error al insertar una parada
--   ROUTE_INSERT_ERROR     â€” Error inesperado
--
-- VersiÃ³n : 2.0
-- Fecha   : 2026-04-18
-- =============================================

DROP FUNCTION IF EXISTS fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, JSONB, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_create_route(
  wname_route            tab_routes.name_route%TYPE,
  wpath_route            TEXT,                                          -- GeoJSON LineString
  wcolor_route           tab_routes.color_route%TYPE,
  wid_company            tab_routes.id_company%TYPE,
  wuser_create           tab_routes.user_create%TYPE,
  wstops                 JSONB,                                         -- Array de paradas ordenadas
  wdescrip_route         tab_routes.descrip_route%TYPE        DEFAULT NULL,
  wfirst_trip            tab_routes.first_trip%TYPE           DEFAULT NULL,
  wlast_trip             tab_routes.last_trip%TYPE            DEFAULT NULL,
  wdeparture_route_sign  tab_routes.departure_route_sign%TYPE DEFAULT NULL,
  wreturn_route_sign     tab_routes.return_route_sign%TYPE    DEFAULT NULL,
  wroute_fare            tab_routes.route_fare%TYPE           DEFAULT 0,
  wis_circular           BOOLEAN                              DEFAULT FALSE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_route  tab_routes.id_route%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_path_geom    GEOMETRY(LineString, 4326);
  v_stop         JSONB;
  v_id_point     SMALLINT;
  v_order        SMALLINT := 0;
  v_dist         NUMERIC;
  v_eta          INTEGER;
  v_stop_count   INTEGER;
  v_point_exists BOOLEAN;
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_route := NULL;

  -- â”€â”€ Validar que hay al menos 2 paradas â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  v_stop_count := jsonb_array_length(COALESCE(wstops, '[]'::JSONB));
  IF v_stop_count < 2 THEN
    msg        := 'Se requieren al menos 2 paradas para crear una ruta. Recibidas: ' || v_stop_count;
    error_code := 'ROUTE_STOPS_EMPTY';
    RETURN;
  END IF;

  -- â”€â”€ Convertir GeoJSON â†’ GEOMETRY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  BEGIN
    v_path_geom := ST_SetSRID(ST_GeomFromGeoJSON(wpath_route), 4326);
  EXCEPTION WHEN OTHERS THEN
    msg        := 'GeoJSON de path_route invÃ¡lido: ' || SQLERRM;
    error_code := 'ROUTE_GEOM_ERROR';
    RETURN;
  END;

  -- â”€â”€ Insertar la ruta en tab_routes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  BEGIN
    INSERT INTO tab_routes (
      name_route,
      path_route,
      descrip_route,
      color_route,
      id_company,
      first_trip,
      last_trip,
      departure_route_sign,
      return_route_sign,
      route_fare,
      is_circular,
      user_create
    ) VALUES (
      TRIM(wname_route),
      v_path_geom,
      NULLIF(TRIM(wdescrip_route), ''),
      UPPER(TRIM(wcolor_route)),
      wid_company,
      wfirst_trip,
      wlast_trip,
      NULLIF(TRIM(wdeparture_route_sign), ''),
      NULLIF(TRIM(wreturn_route_sign), ''),
      GREATEST(wroute_fare, 0),
      COALESCE(wis_circular, FALSE),
      wuser_create
    )
    RETURNING id_route INTO out_id_route;

  EXCEPTION
    WHEN foreign_key_violation THEN
      msg        := 'CompaÃ±Ã­a o usuario no existe: ' || SQLERRM;
      error_code := 'ROUTE_FK_VIOLATION';
      RETURN;
    WHEN check_violation THEN
      msg        := 'Valor fuera de rango (color invÃ¡lido o first_trip >= last_trip): ' || SQLERRM;
      error_code := 'ROUTE_CHECK_VIOLATION';
      RETURN;
    WHEN OTHERS THEN
      msg        := 'Error al insertar la ruta: ' || SQLERRM;
      error_code := 'ROUTE_INSERT_ERROR';
      RETURN;
  END;

  -- â”€â”€ Insertar cada parada en tab_route_points_assoc â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  -- Iteramos el array JSONB en orden de Ã­ndice (0-based).
  -- point_order empieza en 1.
  FOR v_stop IN SELECT * FROM jsonb_array_elements(wstops) LOOP

    v_order    := v_order + 1;
    v_id_point := (v_stop->>'id_point')::SMALLINT;
    v_dist     := NULLIF(v_stop->>'dist_from_start', '')::NUMERIC;
    v_eta      := NULLIF(v_stop->>'eta_seconds', '')::INTEGER;

    -- Verificar que el punto existe y estÃ¡ activo
    SELECT EXISTS (
      SELECT 1 FROM tab_route_points
      WHERE id_point = v_id_point
        AND is_active = TRUE
    ) INTO v_point_exists;

    IF NOT v_point_exists THEN
      msg        := 'La parada con id_point=' || v_id_point || ' no existe o estÃ¡ inactiva.';
      error_code := 'ROUTE_STOP_INVALID';
      -- Al retornar aquÃ­ sin COMMIT explÃ­cito, PL/pgSQL hace ROLLBACK automÃ¡tico
      -- de todo lo insertado en esta ejecuciÃ³n de la funciÃ³n.
      RAISE EXCEPTION 'ROUTE_STOP_INVALID: %', msg;
    END IF;

    BEGIN
      INSERT INTO tab_route_points_assoc (
        id_route,
        id_point,
        point_order,
        dist_from_start,
        eta_seconds
      ) VALUES (
        out_id_route,
        v_id_point,
        v_order,
        v_dist,
        v_eta
      );
    EXCEPTION
      WHEN unique_violation THEN
        msg        := 'Conflicto de orden en posiciÃ³n ' || v_order || ' para la ruta.';
        error_code := 'ROUTE_STOP_ERROR';
        RAISE EXCEPTION 'ROUTE_STOP_ERROR: %', msg;
      WHEN foreign_key_violation THEN
        msg        := 'FK invÃ¡lida para parada id_point=' || v_id_point;
        error_code := 'ROUTE_STOP_ERROR';
        RAISE EXCEPTION 'ROUTE_STOP_ERROR: %', msg;
      WHEN OTHERS THEN
        msg        := 'Error insertando parada ' || v_order || ': ' || SQLERRM;
        error_code := 'ROUTE_STOP_ERROR';
        RAISE EXCEPTION 'ROUTE_STOP_ERROR: %', msg;
    END;

  END LOOP;

  success := TRUE;
  msg     := 'Ruta creada exitosamente con ' || v_stop_count || ' paradas (ID: ' || out_id_route || ')';

EXCEPTION
  WHEN OTHERS THEN
    -- El RAISE EXCEPTION dentro del loop aterriza aquÃ­.
    -- success ya es FALSE y msg / error_code ya estÃ¡n seteados arriba.
    -- Si por alguna razÃ³n no lo estÃ¡n, los forzamos:
    IF error_code IS NULL THEN
      error_code := 'ROUTE_INSERT_ERROR';
      msg        := 'Error inesperado: ' || SQLERRM;
    END IF;
    out_id_route := NULL;
END;
$$;

COMMENT ON FUNCTION fun_create_route(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT, JSONB, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN) IS
'v2.0 â€” Crea una ruta en tab_routes e inserta sus paradas en tab_route_points_assoc en una Ãºnica transacciÃ³n atÃ³mica.
wstops: JSONB array [{id_point, dist_from_start?, eta_seconds?}...] en el orden secuencial deseado.
Si cualquier parada falla, toda la ruta se revierte.';

-- =============================================
-- EJEMPLO DE USO
-- =============================================
/*
SELECT * FROM fun_create_route(
  'Ruta 18 - Cabecera â†’ Centro',
  '{"type":"LineString","coordinates":[[-73.1227,7.1193],[-73.1150,7.1300],[-73.1050,7.1400]]}',
  '#667eea',
  1,    -- id_company
  1,    -- user_create
  '[{"id_point":1,"dist_from_start":0,"eta_seconds":0},{"id_point":5,"dist_from_start":1.2,"eta_seconds":180},{"id_point":9,"dist_from_start":3.4,"eta_seconds":420}]'::JSONB,
  'DescripciÃ³n opcional',
  '05:30:00',
  '22:00:00',
  'CABECERA â†’ CENTRO',
  'CENTRO â†’ CABECERA',
  2500,
  FALSE
);
-- success | msg                                          | error_code | out_id_route
-- TRUE    | Ruta creada exitosamente con 3 paradas (ID: 7) | NULL    | 7
*/


-- =============================================
-- FUNCTION: fun_create_transit_doc_type.sql
-- =============================================
-- ==========================================
-- CREAR TIPO DE DOCUMENTO DE TRANSITO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_create_transit_doc_type(
    p_tag tab_transit_documents.tag_transit_doc%TYPE,
    p_name tab_transit_documents.name_doc%TYPE,
    p_descrip tab_transit_documents.descrip_doc%TYPE,
    p_mandatory tab_transit_documents.is_mandatory%TYPE,
    p_has_expiration tab_transit_documents.has_expiration%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_doc tab_transit_documents.id_doc%TYPE
) AS $$
DECLARE
    v_id SMALLINT;
BEGIN
    INSERT INTO tab_transit_documents (tag_transit_doc, name_doc, descrip_doc, is_mandatory, is_active, has_expiration)
    VALUES (p_tag, p_name, p_descrip, p_mandatory, TRUE, p_has_expiration)
    RETURNING id_doc INTO v_id;

    RETURN QUERY SELECT TRUE, 'Tipo de documento creado correctamente.'::TEXT, NULL::VARCHAR, v_id;
EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un tipo de documento con este nombre o tag.'::TEXT, 'TRANSIT_DOC_UNIQUE_VIOLATION'::VARCHAR, NULL::SMALLINT;
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: fun_create_trips_batch_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_trips_batch v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea mÃºltiples viajes/turnos en lote a partir de un array JSONB.
--   id_trip se genera automÃ¡ticamente (GENERATED ALWAYS AS IDENTITY).
--   La validaciÃ³n de formato y negocio es responsabilidad del backend (Node.js);
--   los constraints de la BD actÃºan como Ãºltima barrera por viaje.
--   Un viaje fallido no aborta el resto del batch.
--
-- ParÃ¡metros obligatorios (IN):
--   wid_route      tab_trips.id_route%TYPE    â€” ID de la ruta (aplica a todos los viajes)
--   wtrip_date     tab_trips.trip_date%TYPE   â€” Fecha del viaje (aplica a todos)
--   wtrips         JSONB                      â€” Array de viajes a crear (ver estructura)
--   wuser_create   tab_trips.user_create%TYPE â€” Usuario que crea
--
-- Estructura del JSONB wtrips:
--   [
--     {
--       "start_time": "08:00:00",   -- obligatorio
--       "end_time":   "09:30:00",   -- obligatorio
--       "id_bus":     1,            -- opcional (FK tab_buses.id_bus)
--       "id_driver":  12345678,     -- opcional (FK tab_drivers.id_driver)
--       "id_status":  1             -- opcional (default 1=pending)
--     },
--     { ... }
--   ]
--
-- Retorna (OUT):
--   success        BOOLEAN      â€” TRUE si se creÃ³ al menos un viaje
--   msg            TEXT         â€” Mensaje descriptivo del resultado
--   error_code     VARCHAR(50)  â€” NULL si success = TRUE; cÃ³digo si falla total
--   trips_created  INTEGER      â€” Cantidad de viajes creados exitosamente
--   trips_failed   INTEGER      â€” Cantidad de viajes fallidos
--   trip_ids       INTEGER[]    â€” IDs de los viajes creados
--
-- CÃ³digos de error (falla total):
--   TRIPS_ARRAY_EMPTY   â€” El array JSONB estÃ¡ vacÃ­o o es NULL
--   ALL_TRIPS_FAILED    â€” Todos los viajes fallaron (ver msg para detalles)
--
-- CÃ³digos de error por viaje (en el campo msg cuando ALL_TRIPS_FAILED):
--   TRIP_UNIQUE      â€” Viaje duplicado (ruta + fecha + start_time ya existe activo)
--   TRIP_CHECK       â€” end_time <= start_time
--   TRIP_FK          â€” FK invÃ¡lida (ruta, bus, conductor o estado no existe)
--   TRIP_ERROR       â€” Error inesperado al insertar
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-18
-- =============================================

-- Limpiar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_trips_batch(DECIMAL(3,0), DATE, JSONB, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_trips_batch(INTEGER, DATE, JSONB, INTEGER);
DROP FUNCTION IF EXISTS fun_create_trips_batch(SMALLINT, DATE, JSONB, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_trips_batch(
  wid_route      tab_trips.id_route%TYPE,
  wtrip_date     tab_trips.trip_date%TYPE,
  wtrips         JSONB,
  wuser_create   tab_trips.user_create%TYPE,

  OUT success        BOOLEAN,
  OUT msg            TEXT,
  OUT error_code     VARCHAR(50),
  OUT trips_created  INTEGER,
  OUT trips_failed   INTEGER,
  OUT trip_ids       INTEGER[]
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_trip     JSONB; -- Variable para iterar cada viaje del array
  v_index    INTEGER := 0;
  v_id_trip  tab_trips.id_trip%TYPE;
  v_ids      INTEGER[] := ARRAY[]::INTEGER[];
  v_created  INTEGER   := 0;
  v_failed   INTEGER   := 0;
  v_errors   TEXT      := '';
BEGIN
  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  trips_created := 0;
  trips_failed  := 0;
  trip_ids      := ARRAY[]::INTEGER[];

  -- Ãšnico check necesario: array vacÃ­o no lanza excepciÃ³n pero no tiene
  -- resultado Ãºtil y el error_code serÃ­a engaÃ±oso sin este guard.
  IF wtrips IS NULL OR jsonb_array_length(wtrips) = 0 THEN
    msg        := 'El array de viajes no puede estar vacÃ­o';
    error_code := 'TRIPS_ARRAY_EMPTY';
    RETURN;
  END IF;

  FOR v_trip IN SELECT * FROM jsonb_array_elements(wtrips)
  LOOP
    v_index := v_index + 1;

    BEGIN

      INSERT INTO tab_trips (
        id_route,
        trip_date,
        start_time,
        end_time,
        id_bus,
        id_driver,
        id_status,
        is_active,
        created_at,
        user_create
      ) VALUES (
        wid_route,
        wtrip_date,
        (v_trip->>'start_time')::TIME,
        (v_trip->>'end_time')::TIME,
        (v_trip->>'id_bus')::SMALLINT,
        (v_trip->>'id_driver')::BIGINT,
        COALESCE((v_trip->>'id_status')::SMALLINT, 1),
        TRUE,
        NOW(),
        wuser_create
      )
      RETURNING id_trip INTO v_id_trip;

      v_ids    := array_append(v_ids, v_id_trip);
      v_created := v_created + 1;

    EXCEPTION
      WHEN unique_violation THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || '[#' || v_index || ' TRIP_UNIQUE] ' || SQLERRM || '; ';
      WHEN check_violation THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || '[#' || v_index || ' TRIP_CHECK] ' || SQLERRM || '; ';
      WHEN foreign_key_violation THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || '[#' || v_index || ' TRIP_FK] ' || SQLERRM || '; ';
      WHEN OTHERS THEN
        v_failed := v_failed + 1;
        v_errors := v_errors || '[#' || v_index || ' TRIP_ERROR] ' || SQLERRM || '; ';
    END;

  END LOOP;

  trips_created := v_created;
  trips_failed  := v_failed;
  trip_ids      := v_ids;

  IF v_created > 0 THEN
    success := TRUE;
    msg     := v_created || ' viaje(s) creado(s) exitosamente';
    IF v_failed > 0 THEN
      msg := msg || ', ' || v_failed || ' fallido(s). ' || v_errors;
    END IF;
  ELSE
    success    := FALSE;
    msg        := 'No se pudo crear ningÃºn viaje. ' || v_errors;
    error_code := 'ALL_TRIPS_FAILED';
  END IF;

END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_trips_batch(SMALLINT, DATE, JSONB, SMALLINT) IS
'v1.0 â€” Crea viajes en lote desde JSONB. id_trip por IDENTITY. Un viaje fallido no aborta el batch. '
'JSONB: [{start_time, end_time, id_bus?, id_driver?, id_status?}]. '
'Errores por viaje en campo msg: TRIP_UNIQUE, TRIP_CHECK, TRIP_FK, TRIP_ERROR. '
'Falla total: TRIPS_ARRAY_EMPTY, ALL_TRIPS_FAILED.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear 3 viajes pending (sin bus ni conductor):
SELECT * FROM fun_create_trips_batch(
  1, CURRENT_DATE,
  '[
    {"start_time": "08:00:00", "end_time": "09:30:00"},
    {"start_time": "10:00:00", "end_time": "11:30:00"},
    {"start_time": "14:00:00", "end_time": "15:30:00"}
  ]'::JSONB,
  1
);

-- Crear viajes con bus y conductor asignados (status=2):
SELECT * FROM fun_create_trips_batch(
  1, CURRENT_DATE,
  '[
    {"start_time": "06:00:00", "end_time": "07:30:00", "id_bus": 1, "id_driver": 12345678, "id_status": 2},
    {"start_time": "08:00:00", "end_time": "09:30:00", "id_bus": 2, "id_driver": 87654321, "id_status": 2}
  ]'::JSONB,
  1
);

-- Batch mixto (algunos fallan, el resto se crea):
SELECT * FROM fun_create_trips_batch(
  1, CURRENT_DATE,
  '[
    {"start_time": "12:00:00", "end_time": "13:30:00"},
    {"start_time": "14:00:00", "end_time": "13:00:00"},
    {"start_time": "16:00:00", "end_time": "17:30:00"}
  ]'::JSONB,
  1
);
-- El viaje #2 falla por TRIP_CHECK (end_time <= start_time), los otros se crean

*/

-- =============================================
-- FIN DE fun_create_trips_batch v1.0
-- =============================================


-- =============================================
-- FUNCTION: fun_create_trip_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_trip v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo viaje (turno) en tab_trips.
--   id_trip se genera automÃ¡ticamente (GENERATED ALWAYS AS IDENTITY).
--   La validaciÃ³n de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros obligatorios (IN):
--   wid_route      tab_trips.id_route%TYPE    â€” ID de la ruta
--   wtrip_date     tab_trips.trip_date%TYPE   â€” Fecha del viaje
--   wstart_time    tab_trips.start_time%TYPE  â€” Hora de inicio
--   wend_time      tab_trips.end_time%TYPE    â€” Hora de fin
--   wuser_create   tab_trips.user_create%TYPE â€” Usuario que crea
--
-- ParÃ¡metros opcionales (IN):
--   wid_bus        tab_trips.id_bus%TYPE      DEFAULT NULL â€” ID interno del bus (FK tab_buses.id_bus)
--   wid_driver     tab_trips.id_driver%TYPE   DEFAULT NULL â€” CÃ©dula del conductor (FK tab_drivers.id_driver)
--   wid_status     tab_trips.id_status%TYPE   DEFAULT 1    â€” Estado inicial (1=pending)
--
-- Retorna (OUT):
--   success        BOOLEAN                   â€” TRUE si se creÃ³ correctamente
--   msg            TEXT                      â€” Mensaje descriptivo
--   error_code     VARCHAR(50)               â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_trip    tab_trips.id_trip%TYPE    â€” ID generado (NULL si falla)
--
-- CÃ³digos de error:
--   TRIP_UNIQUE_VIOLATION â€” Viaje duplicado (ruta + fecha + hora ya existe)
--   TRIP_CHECK_VIOLATION  â€” end_time <= start_time (violaciÃ³n de chk_trips_times)
--   TRIP_FK_VIOLATION     â€” FK invÃ¡lida (ruta, bus, conductor o usuario no existe)
--   TRIP_INSERT_ERROR     â€” Error inesperado
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-17
-- =============================================

-- Limpiar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_trip(INTEGER, DATE, TIME, TIME, INTEGER, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_trip(INTEGER, DATE, TIME, TIME, INTEGER, VARCHAR, INTEGER, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_trip(SMALLINT, DATE, TIME, TIME, SMALLINT, SMALLINT, BIGINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_trip(SMALLINT, DATE, TIME, TIME, SMALLINT, SMALLINT, BIGINT, SMALLINT, BOOLEAN, TEXT, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION fun_create_trip(
  wid_route      tab_trips.id_route%TYPE,
  wtrip_date     tab_trips.trip_date%TYPE,
  wstart_time    tab_trips.start_time%TYPE,
  wend_time      tab_trips.end_time%TYPE,
  wuser_create   tab_trips.user_create%TYPE,
  wid_bus        tab_trips.id_bus%TYPE      DEFAULT NULL,
  wid_driver     tab_trips.id_driver%TYPE   DEFAULT NULL,
  wid_status     tab_trips.id_status%TYPE   DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT out_id_trip tab_trips.id_trip%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success     := FALSE;
  msg         := '';
  error_code  := NULL;
  out_id_trip := NULL;

  INSERT INTO tab_trips (
    id_route,
    trip_date,
    start_time,
    end_time,
    id_bus,
    id_driver,
    id_status,
    is_active,
    created_at,
    user_create
  ) VALUES (
    wid_route,
    wtrip_date,
    wstart_time,
    wend_time,
    wid_bus,
    wid_driver,
    wid_status,
    TRUE,
    NOW(),
    wuser_create
  )
  RETURNING id_trip INTO out_id_trip;

  success := TRUE;
  msg     := 'Viaje creado exitosamente (ID: ' || out_id_trip || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe un viaje para esa ruta, fecha y hora de inicio: ' || SQLERRM;
    error_code := 'TRIP_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'La hora de fin debe ser posterior a la hora de inicio: ' || SQLERRM;
    error_code := 'TRIP_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Referencia invÃ¡lida (ruta, bus, conductor o usuario no existe): ' || SQLERRM;
    error_code := 'TRIP_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'TRIP_INSERT_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_create_trip(SMALLINT, DATE, TIME, TIME, SMALLINT, SMALLINT, BIGINT, SMALLINT) IS
'v1.0 â€” Crea un viaje en tab_trips. id_trip generado por IDENTITY automÃ¡ticamente. ValidaciÃ³n de negocio delegada al backend y constraints de BD. CÃ³digos de error: TRIP_UNIQUE_VIOLATION, TRIP_CHECK_VIOLATION, TRIP_FK_VIOLATION, TRIP_INSERT_ERROR.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Ejemplo 1: Viaje bÃ¡sico (solo ruta, fecha y horario)
SELECT * FROM fun_create_trip(
  1,              -- id_route
  CURRENT_DATE,   -- trip_date
  '08:00:00',     -- start_time
  '09:30:00',     -- end_time
  1               -- user_create
);
-- success | msg                              | error_code | out_id_trip
-- TRUE    | Viaje creado exitosamente (ID:1) | NULL       | 1


-- Ejemplo 2: Viaje asignado (con bus y conductor)
SELECT * FROM fun_create_trip(
  1,              -- id_route
  CURRENT_DATE,   -- trip_date
  '10:00:00',     -- start_time
  '11:30:00',     -- end_time
  1,              -- user_create
  3,              -- id_bus   (id interno del bus en tab_buses)
  10005678901,    -- id_driver (cÃ©dula del conductor en tab_drivers)
  2               -- id_status (2=assigned)
);
-- success | msg                              | error_code | out_id_trip
-- TRUE    | Viaje creado exitosamente (ID:2) | NULL       | 2


-- Ejemplo 3: ERROR â€” hora fin anterior a hora inicio (CHECK constraint)
SELECT * FROM fun_create_trip(
  1, CURRENT_DATE, '10:00:00', '09:00:00', 1
);
-- success | msg                                          | error_code          | out_id_trip
-- FALSE   | La hora de fin debe ser posterior a la de.. | TRIP_CHECK_VIOLATION| NULL


-- Ejemplo 4: ERROR â€” ruta inexistente (FK constraint)
SELECT * FROM fun_create_trip(
  999, CURRENT_DATE, '08:00:00', '09:30:00', 1
);
-- success | msg                                 | error_code         | out_id_trip
-- FALSE   | Referencia invÃ¡lida (ruta, bus,..)  | TRIP_FK_VIOLATION  | NULL


-- Ejemplo 5: ERROR â€” viaje duplicado (ruta+fecha+hora)
SELECT * FROM fun_create_trip(
  1, CURRENT_DATE, '08:00:00', '09:30:00', 1  -- misma combinaciÃ³n que ejemplo 1
);
-- success | msg                                   | error_code               | out_id_trip
-- FALSE   | Ya existe un viaje para esa ruta,...  | TRIP_UNIQUE_VIOLATION    | NULL


-- Ejemplo 6: Verificar viaje creado
SELECT
  t.id_trip,
  r.name_route,
  t.trip_date,
  t.start_time,
  t.end_time,
  b.amb_code  AS bus_code,
  d.name_driver,
  ts.status_name
FROM tab_trips t
JOIN tab_routes r           ON t.id_route  = r.id_route
JOIN tab_trip_statuses ts   ON t.id_status = ts.id_status
LEFT JOIN tab_buses b       ON t.id_bus    = b.id_bus
LEFT JOIN tab_drivers d     ON t.id_driver = d.id_driver
WHERE t.id_trip = 1;

*/

-- =============================================
-- FIN DE LA FUNCIÃ“N fun_create_trip v1.0
-- =============================================


-- =============================================
-- FUNCTION: fun_create_user_v2.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_create_user v2.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Crea un nuevo usuario en tab_users y le asigna
--   el rol indicado en tab_user_roles.
--   Normaliza email y nombre e inserta directamente.
--   La validaciÃ³n de negocio es responsabilidad del
--   backend (Node.js); los constraints de la BD
--   actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros:
--   wemail_user    VARCHAR(320) â€” email del nuevo usuario
--   wpass_user     VARCHAR(60)  â€” hash bcrypt generado en el backend
--   wfull_name     VARCHAR(100) â€” nombre completo
--   wid_role       SMALLINT     â€” ID del rol a asignar (1=Administrador, 2=Turnador, 3=Conductor)
--   wuser_create   SMALLINT     â€” ID del usuario que ejecuta la acciÃ³n. Default 1
--
-- Retorna (OUT):
--   success    BOOLEAN      â€” TRUE si se creÃ³ correctamente
--   msg        TEXT         â€” Mensaje descriptivo del resultado
--   error_code VARCHAR(50)  â€” NULL si success = TRUE
--   id_user    SMALLINT     â€” ID del usuario creado (NULL si falla)
--
-- VersiÃ³n   : 2.0
-- Fecha     : 2026-03-11
-- =============================================

-- Limpiar versiones anteriores con distintas firmas
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, TEXT, VARCHAR, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, TEXT,    VARCHAR, SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_create_user(
  wemail_user    tab_users.email_user%TYPE,
  wpass_user     tab_users.pass_user%TYPE,
  wfull_name     tab_users.full_name%TYPE,
  wid_role       tab_roles.id_role%TYPE,
  wuser_create   tab_user_roles.assigned_by%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT id_user     tab_users.id_user%TYPE
)
LANGUAGE plpgsql

AS $$
DECLARE
  v_email    tab_users.email_user%TYPE;
  v_name     tab_users.full_name%TYPE;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;
  id_user    := NULL;

  -- Normalizar
  v_email := LOWER(TRIM(wemail_user));
  v_name  := TRIM(REGEXP_REPLACE(wfull_name, '\s+', ' ', 'g'));

  -- INSERT en tab_users. Omitimos 'id_user' y lo capturamos al final con RETURNING
  INSERT INTO tab_users (full_name, email_user, pass_user, is_active)
  VALUES (v_name, v_email, wpass_user, TRUE)
  RETURNING tab_users.id_user INTO id_user; -- Capturamos el ID generado

  -- Usamos el ID reciÃ©n creado para asignar el rol
  INSERT INTO tab_user_roles (id_user, id_role, assigned_at, assigned_by, is_active)
  VALUES (id_user, wid_role, NOW(), wuser_create, TRUE);

  success := TRUE;
  msg     := 'Usuario creado exitosamente (ID: ' || id_user || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'El email o la combinaciÃ³n usuario/rol ya existe: ' || SQLERRM;
    error_code := 'USER_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave forÃ¡nea invÃ¡lida (rol o usuario no existe): ' || SQLERRM;
    error_code := 'USER_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'RestricciÃ³n CHECK violada: ' || SQLERRM;
    error_code := 'USER_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'USER_INSERT_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT) IS
'v2.0 â€” Crea usuario en tab_users + asigna rol en tab_user_roles. Normaliza email y nombre; validaciÃ³n de negocio delegada al backend y constraints de BD. id_user generado por IDENTITY (SMALLINT).';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Crear un conductor (id_role = 3)
SELECT * FROM fun_create_user(
  'carlos.gil@bucarabus.com',
  '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lh7i',
  'Carlos Gil',
  3,
  1
);

-- Resultado exitoso:
-- success | msg                         | error_code | id_user
-- TRUE    | Usuario creado exitosamente | NULL       | 2

-- Error: email duplicado (UNIQUE constraint)
-- success | msg                                          | error_code            | id_user
-- FALSE   | El email o la combinaciÃ³n usuario/rol ya ... | USER_UNIQUE_VIOLATION | NULL

-- Error: rol inexistente (FK constraint)
-- success | msg                                           | error_code         | id_user
-- FALSE   | Clave forÃ¡nea invÃ¡lida (rol o usuario no ...) | USER_FK_VIOLATION  | NULL

*/



-- =============================================
-- FUNCTION: fun_finalize_expired_trips_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_finalize_expired_trips v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Finaliza automÃ¡ticamente los viajes del dÃ­a indicado cuya hora de fin
--   ya haya pasado (end_time < NOW()::TIME), pasÃ¡ndolos a id_status = 4.
--
-- ParÃ¡metros (IN):
--   wp_date   DATE  â€” Fecha del dÃ­a a evaluar (YYYY-MM-DD).
--                     Se pasa desde Node para evitar desfase UTC vs Colombia.
--
-- Retorna: VOID
--
-- Notas:
--   - user_update = 1 identifica transiciones automÃ¡ticas del sistema.
--   - Llamar antes de consultar viajes activos (lazy evaluation).
--   - Los errores se propagan al caller (Node.js try/catch).
-- =============================================

CREATE OR REPLACE FUNCTION fun_finalize_expired_trips(wp_date DATE, wp_time TIME)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows INTEGER;
BEGIN

    UPDATE tab_trips
    SET  id_status    = 4,
         completed_at = NOW(),
         updated_at   = NOW(),
         user_update  = 1
    WHERE trip_date  = wp_date
      AND id_status  IN (1, 2, 3)
      AND end_time   < wp_time
      AND is_active  = TRUE;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows > 0 THEN
        RAISE NOTICE 'fun_finalize_expired_trips: % viaje(s) finalizado(s) automÃ¡ticamente para %', v_rows, wp_date;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'fun_finalize_expired_trips: error al finalizar viajes vencidos para % â€” % (%)',
            wp_date, SQLERRM, SQLSTATE;
END;
$$;


-- =============================================
-- FUNCTION: fun_link_driver_account_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_link_driver_account v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Vincula un conductor existente (tab_drivers) con un usuario existente (tab_users).
--   Solo registra el vÃ­nculo en tab_driver_accounts.
--
--   Flujo esperado:
--     1. Admin crea el conductor          â†’ fun_create_driver
--     2. Admin crea la cuenta de usuario  â†’ fun_create_user (con id_role = 3, Conductor)
--     3. Admin llama a esta funciÃ³n       â†’ fun_link_driver_account
--
--   La validaciÃ³n de negocio (conductor existe, usuario existe, conductor ya vinculado,
--   usuario ya vinculado a otro conductor) es responsabilidad del backend (Node.js).
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros:
--   wid_driver   BIGINT   â€” CÃ©dula del conductor (FK a tab_drivers)
--   wid_user     SMALLINT â€” ID del usuario a vincular (FK a tab_users)
--   wassigned_by SMALLINT â€” ID del admin que realiza la acciÃ³n. Default 1
--
-- Retorna (OUT):
--   success    BOOLEAN     â€” TRUE si se vinculÃ³ correctamente
--   msg        TEXT        â€” Mensaje descriptivo del resultado
--   error_code VARCHAR(50) â€” NULL si success = TRUE
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-31
-- =============================================

DROP FUNCTION IF EXISTS fun_link_driver_account(BIGINT, VARCHAR, VARCHAR, VARCHAR, SMALLINT);
DROP FUNCTION IF EXISTS fun_link_driver_account(BIGINT, SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_link_driver_account(
  wid_driver    tab_drivers.id_driver%TYPE,
  wid_user      tab_users.id_user%TYPE,
  wassigned_by  tab_driver_accounts.assigned_by%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  INSERT INTO tab_driver_accounts (id_driver, id_user, assigned_at, assigned_by)
  VALUES (wid_driver, wid_user, NOW(), wassigned_by);

  success := TRUE;
  msg     := 'Cuenta vinculada exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'El conductor o el usuario ya tiene un vÃ­nculo activo: ' || SQLERRM;
    error_code := 'ACCOUNT_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Conductor o usuario no vÃ¡lido: ' || SQLERRM;
    error_code := 'ACCOUNT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ACCOUNT_LINK_ERROR';
END;
$$;


-- =============================================
-- FUNCTION: fun_manage_roles_v1.sql
-- =============================================
-- =============================================
-- FUNCIONES: fun_assign_role + fun_remove_role v2.0
-- Directorio: functions_v2
-- =============================================
-- fun_assign_role: asigna un rol a un usuario (INSERT o reactiva si existÃ­a)
-- fun_remove_role: quita un rol de un usuario (soft delete is_active = FALSE)
--
-- La validaciÃ³n de negocio (Ãºltimo rol activo, rol administrador, etc.)
-- es responsabilidad del backend (Node.js).
-- Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- VersiÃ³n   : 2.0
-- Fecha     : 2026-03-11
-- =============================================

-- =============================================
-- fun_assign_role
-- =============================================
DROP FUNCTION IF EXISTS fun_assign_role(SMALLINT, SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_assign_role(
  wid_user      tab_users.id_user%TYPE,
  wid_role      tab_roles.id_role%TYPE,
  wassigned_by  tab_user_roles.assigned_by%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  INSERT INTO tab_user_roles (id_user, id_role, assigned_at, assigned_by, is_active)
  VALUES (wid_user, wid_role, NOW(), wassigned_by, TRUE)
  ON CONFLICT (id_user, id_role)
  DO UPDATE SET
    is_active   = TRUE,
    assigned_at = EXCLUDED.assigned_at,
    assigned_by = EXCLUDED.assigned_by
  WHERE tab_user_roles.is_active = FALSE
     OR tab_user_roles.assigned_by IS DISTINCT FROM EXCLUDED.assigned_by;

  success := TRUE;
  msg     := 'Rol asignado exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario o rol no vÃ¡lido: ' || SQLERRM;
    error_code := 'ROLE_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROLE_ASSIGN_ERROR';
END;
$$;


-- =============================================
-- fun_remove_role
-- =============================================
DROP FUNCTION IF EXISTS fun_remove_role(SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_remove_role(
  wid_user  tab_users.id_user%TYPE,
  wid_role  tab_roles.id_role%TYPE,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  UPDATE tab_user_roles
  SET is_active = FALSE
  WHERE id_user = wid_user
    AND id_role  = wid_role
    AND is_active = TRUE;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'El usuario no tiene este rol asignado (id_user: ' || COALESCE(wid_user::TEXT, 'NULL') || ', id_role: ' || COALESCE(wid_role::TEXT, 'NULL') || ')';
    error_code := 'ROLE_NOT_ASSIGNED'; RETURN;
  END IF;

  success := TRUE;
  msg     := 'Rol quitado exitosamente';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROLE_REMOVE_ERROR';
END;
$$;

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Asignar rol 2 al usuario 5 (admin = usuario 1 asigna)
SELECT * FROM fun_assign_role(5, 2, 1);
-- success | msg                    | error_code
-- TRUE    | Rol asignado exitosamente | NULL

-- Reactivar rol previamente quitado (ON CONFLICT DO UPDATE)
SELECT * FROM fun_assign_role(5, 2, 1);
-- success | msg                    | error_code
-- TRUE    | Rol asignado exitosamente | NULL   â† idempotente

-- Usuario o rol no existen (FK violation)
-- success | msg                          | error_code
-- FALSE   | Usuario o rol no vÃ¡lido: ... | ROLE_FK_VIOLATION

-- Quitar rol 2 del usuario 5
SELECT * FROM fun_remove_role(5, 2);
-- success | msg                   | error_code
-- TRUE    | Rol quitado exitosamente | NULL

-- Rol no asignado o ya inactivo
SELECT * FROM fun_remove_role(5, 2);
-- success | msg                                              | error_code
-- FALSE   | El usuario no tiene este rol asignado (...)      | ROLE_NOT_ASSIGNED

*/

-- =============================================
-- FUNCTION: fun_password_reset.sql
-- =============================================
-- =============================================
-- BucaraBUS â€” Funciones: RecuperaciÃ³n de ContraseÃ±a
-- Archivo: fun_password_reset.sql
--
-- Principio arquitectÃ³nico: Solo mutaciones (DELETE + INSERT + UPDATE).
-- Las consultas SELECT viven en password-reset.service.js (Node.js).
-- =============================================

-- â”€â”€â”€ 1. Crear token de recuperaciÃ³n (DELETE old + INSERT new, atÃ³mico) â”€â”€â”€â”€â”€â”€â”€
DROP FUNCTION IF EXISTS fun_create_password_reset_token(INTEGER, VARCHAR, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION fun_create_password_reset_token(
  wid_user    tab_users.id_user%TYPE,
  wtoken      tab_password_reset_tokens.token%TYPE,
  wexpires_at tab_password_reset_tokens.expires_at%TYPE,

  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- Eliminar tokens anteriores del mismo usuario (un token activo a la vez)
  DELETE FROM tab_password_reset_tokens WHERE id_user = wid_user;

  -- Insertar el nuevo token
  INSERT INTO tab_password_reset_tokens (id_user, token, expires_at)
  VALUES (wid_user, wtoken, wexpires_at);

  success := TRUE;
  msg     := 'Token de recuperaciÃ³n creado correctamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario inexistente: ' || SQLERRM;
    error_code := 'RESET_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado al crear token: ' || SQLERRM;
    error_code := 'RESET_INTERNAL_ERROR';
END;
$$;

-- â”€â”€â”€ 2. Consumir token y actualizar contraseÃ±a (validar + UPDATE + DELETE) â”€â”€â”€
DROP FUNCTION IF EXISTS fun_consume_password_reset_token(VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION fun_consume_password_reset_token(
  wtoken         tab_password_reset_tokens.token%TYPE,
  wpassword_hash tab_users.pass_user%TYPE,

  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_user tab_users.id_user%TYPE;
  v_id_token tab_password_reset_tokens.id_token%TYPE;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- Validar que el token existe y no ha expirado
  SELECT id_token, id_user
    INTO v_id_token, v_id_user
    FROM tab_password_reset_tokens
   WHERE token = wtoken AND expires_at > NOW();

  IF v_id_token IS NULL THEN
    msg        := 'El enlace de recuperaciÃ³n es invÃ¡lido o ya expirÃ³';
    error_code := 'RESET_TOKEN_INVALID';
    RETURN;
  END IF;

  -- Actualizar contraseÃ±a del usuario
  UPDATE tab_users
     SET pass_user = wpassword_hash
   WHERE id_user = v_id_user;

  -- Eliminar el token (uso Ãºnico)
  DELETE FROM tab_password_reset_tokens WHERE id_token = v_id_token;

  success := TRUE;
  msg     := 'ContraseÃ±a actualizada correctamente';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado al restablecer contraseÃ±a: ' || SQLERRM;
    error_code := 'RESET_INTERNAL_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_create_password_reset_token IS
  'Elimina tokens anteriores del usuario e inserta uno nuevo. AtÃ³mico.';

COMMENT ON FUNCTION fun_consume_password_reset_token IS
  'Valida el token, actualiza la contraseÃ±a y elimina el token (uso Ãºnico). AtÃ³mico.';


-- =============================================
-- FUNCTION: fun_rbac.sql
-- =============================================
-- =============================================
-- BucaraBUS - Funciones Almacenadas para RBAC JerÃ¡rquico
-- Estandarizado con validaciones Backend y manejo de Excepciones BD
-- =============================================

-- ---------------------------------------------------------
-- 1. FunciÃ³n para crear un permiso
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS fun_create_permission(VARCHAR, VARCHAR, TEXT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_permission(
  wname_permission    tab_permissions.name_permission%TYPE,
  wcode_permission    tab_permissions.code_permission%TYPE,
  wdescrip_permission tab_permissions.descrip_permission%TYPE DEFAULT NULL,
  wcode_parent        tab_permissions.code_permission%TYPE    DEFAULT NULL,

  -- ParÃ¡metros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_perm  tab_permissions.id_permission%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_parent SMALLINT := NULL;
BEGIN
  success     := FALSE;
  msg         := '';
  error_code  := NULL;
  out_id_perm := NULL;

  -- 1. Si se enviÃ³ un cÃ³digo padre, buscamos su ID
  IF wcode_parent IS NOT NULL THEN
    SELECT id_permission INTO v_id_parent
    FROM tab_permissions
    WHERE code_permission = wcode_parent;

    IF v_id_parent IS NULL THEN
        success := FALSE;
        msg := 'El permiso padre especificado no existe';
        error_code := 'PARENT_NOT_FOUND';
        RETURN;
    END IF;
  END IF;

  -- 2. Intentar insertar el nuevo permiso
  INSERT INTO tab_permissions (name_permission, code_permission, descrip_permission, id_parent)
  VALUES (wname_permission, wcode_permission, wdescrip_permission, v_id_parent)
  RETURNING id_permission INTO out_id_perm;

  success := TRUE;
  msg := 'Permiso creado exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    -- Si ya existe (unique constraint en code_permission), lo consideramos Ã©xito para los seeds
    SELECT id_permission INTO out_id_perm FROM tab_permissions WHERE code_permission = wcode_permission;
    success := TRUE; 
    msg := 'El permiso ya existÃ­a';
  WHEN foreign_key_violation THEN
    success := FALSE;
    msg := 'ViolaciÃ³n de llave forÃ¡nea al crear permiso';
    error_code := SQLSTATE;
  WHEN OTHERS THEN
    success := FALSE;
    msg := 'Error inesperado al crear permiso: ' || SQLERRM;
    error_code := SQLSTATE;
END;
$$;

-- ---------------------------------------------------------
-- 2. FunciÃ³n para asignar permiso a un rol
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS fun_assign_role_permission(SMALLINT, VARCHAR, SMALLINT);

CREATE OR REPLACE FUNCTION fun_assign_role_permission(
  wid_role         tab_role_permissions.id_role%TYPE,
  wcode_permission tab_permissions.code_permission%TYPE,
  wassigned_by     tab_role_permissions.assigned_by%TYPE DEFAULT 1,

  -- ParÃ¡metros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_permission SMALLINT;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- 1. Buscar ID del permiso
  SELECT id_permission INTO v_id_permission 
  FROM tab_permissions 
  WHERE code_permission = wcode_permission;

  IF v_id_permission IS NULL THEN
    success := FALSE;
    msg := 'El permiso con cÃ³digo ' || wcode_permission || ' no existe';
    error_code := 'PERMISSION_NOT_FOUND';
    RETURN;
  END IF;

  -- 2. Asignar el permiso
  INSERT INTO tab_role_permissions (id_role, id_permission, assigned_by)
  VALUES (wid_role, v_id_permission, wassigned_by);

  success := TRUE;
  msg := 'Permiso asignado exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    -- Si ya tiene asignado este permiso, no es un error
    success := TRUE; 
    msg := 'El rol ya tenÃ­a asignado este permiso';
  WHEN foreign_key_violation THEN
    success := FALSE;
    msg := 'El rol (' || wid_role || ') o el usuario asignador no existen';
    error_code := SQLSTATE;
  WHEN OTHERS THEN
    success := FALSE;
    msg := 'Error inesperado al asignar permiso: ' || SQLERRM;
    error_code := SQLSTATE;
END;
$$;

-- ---------------------------------------------------------
-- 3. fun_get_user_permissions ELIMINADA
-- La consulta de permisos es un SELECT puro â†’ vive en auth.service.js (Node.js)
-- Principio: la BD solo gestiona mutaciones (INSERT/UPDATE/DELETE).
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS fun_get_user_permissions(INTEGER);

-- ---------------------------------------------------------
-- 4. FunciÃ³n para actualizar masivamente los permisos de un rol
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS fun_update_role_permissions(SMALLINT, JSONB, SMALLINT);

CREATE OR REPLACE FUNCTION fun_update_role_permissions(
  wid_role SMALLINT,
  wpermissions_json JSONB,
  wuser_update SMALLINT DEFAULT 1
)
RETURNS BOOLEAN AS $$
DECLARE
  v_perm_code VARCHAR;
  v_id_permission SMALLINT;
BEGIN
  -- 1. Eliminar todos los permisos actuales del rol
  DELETE FROM tab_role_permissions WHERE id_role = wid_role;

  -- 2. Insertar los nuevos permisos
  IF wpermissions_json IS NOT NULL AND jsonb_array_length(wpermissions_json) > 0 THEN
      FOR v_perm_code IN SELECT jsonb_array_elements_text(wpermissions_json)
      LOOP
          SELECT id_permission INTO v_id_permission FROM tab_permissions WHERE code_permission = v_perm_code;
          IF v_id_permission IS NOT NULL THEN
              INSERT INTO tab_role_permissions (id_role, id_permission, assigned_by)
              VALUES (wid_role, v_id_permission, wuser_update);
          END IF;
      END LOOP;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- SEMILLAS (Datos Iniciales usando las funciones)
-- =============================================
DO $$
DECLARE 
    v_admin_role SMALLINT := 1;
    v_turnador_role SMALLINT := 2;
BEGIN
    -- 1. Crear JerarquÃ­a de MÃ³dulos (RaÃ­ces)
    PERFORM fun_create_permission('MÃ³dulo Buses',       'MODULE_BUSES',     'Acceso al mÃ³dulo de buses');
    PERFORM fun_create_permission('MÃ³dulo Conductores', 'MODULE_DRIVERS',   'Acceso al mÃ³dulo de conductores');
    PERFORM fun_create_permission('MÃ³dulo Rutas',       'MODULE_ROUTES',    'Acceso al mÃ³dulo de rutas');
    PERFORM fun_create_permission('MÃ³dulo Paradas',     'MODULE_STOPS',     'Acceso al mÃ³dulo de paradas');
    PERFORM fun_create_permission('MÃ³dulo Turnos',      'MODULE_TRIPS',     'Acceso al panel de turnos');
    PERFORM fun_create_permission('MÃ³dulo CatÃ¡logos',   'MODULE_CATALOGS',  'Acceso a catÃ¡logos del sistema');
    PERFORM fun_create_permission('MÃ³dulo ConfiguraciÃ³n','MODULE_SETTINGS', 'Acceso a ajustes del sistema');

    -- 2. Permisos de Buses
    PERFORM fun_create_permission('Ver Buses',      'VIEW_BUSES',    'Ver lista de buses',       'MODULE_BUSES');
    PERFORM fun_create_permission('Crear Buses',    'CREATE_BUSES',  'AÃ±adir nuevos buses',      'MODULE_BUSES');
    PERFORM fun_create_permission('Editar Buses',   'EDIT_BUSES',    'Modificar datos de buses', 'MODULE_BUSES');
    PERFORM fun_create_permission('Eliminar Buses', 'DELETE_BUSES',  'Eliminar buses',           'MODULE_BUSES');

    -- 3. Permisos de Conductores
    PERFORM fun_create_permission('Ver Conductores',      'VIEW_DRIVERS',    'Ver lista de conductores', 'MODULE_DRIVERS');
    PERFORM fun_create_permission('Crear Conductores',    'CREATE_DRIVERS',  'AÃ±adir conductores',       'MODULE_DRIVERS');
    PERFORM fun_create_permission('Editar Conductores',   'EDIT_DRIVERS',    'Modificar conductores',    'MODULE_DRIVERS');
    PERFORM fun_create_permission('Eliminar Conductores', 'DELETE_DRIVERS',  'Eliminar conductores',     'MODULE_DRIVERS');

    -- 4. Permisos de Rutas
    PERFORM fun_create_permission('Ver Rutas',      'VIEW_ROUTES',    'Ver listado de rutas',    'MODULE_ROUTES');
    PERFORM fun_create_permission('Crear Rutas',    'CREATE_ROUTES',  'Crear nuevas rutas',      'MODULE_ROUTES');
    PERFORM fun_create_permission('Editar Rutas',   'EDIT_ROUTES',    'Modificar rutas',         'MODULE_ROUTES');
    PERFORM fun_create_permission('Eliminar Rutas', 'DELETE_ROUTES',  'Eliminar rutas',          'MODULE_ROUTES');

    -- 5. Permisos de Paradas
    PERFORM fun_create_permission('Ver Paradas',    'VIEW_STOPS',     'Ver listado de paradas',       'MODULE_STOPS');
    PERFORM fun_create_permission('Crear Paradas',  'CREATE_STOPS',   'Crear nuevas paradas',         'MODULE_STOPS');
    PERFORM fun_create_permission('Editar Paradas', 'EDIT_STOPS',     'Editar y activar/desactivar',  'MODULE_STOPS');

    -- 6. Permisos de Turnos
    PERFORM fun_create_permission('Ver Turnos',     'VIEW_TRIPS',    'Ver lista de viajes',                  'MODULE_TRIPS');
    PERFORM fun_create_permission('Crear Turnos',   'CREATE_TRIPS',  'Crear viajes individuales o masivos',  'MODULE_TRIPS');
    PERFORM fun_create_permission('Asignar Turnos', 'ASSIGN_TRIPS',  'Asignar bus/conductor a viajes',       'MODULE_TRIPS');
    PERFORM fun_create_permission('Cancelar Turnos','CANCEL_TRIPS',  'Cancelar viajes',                      'MODULE_TRIPS');

    -- 7. Permisos de CatÃ¡logos (EPS, ARL, Marcas, CompaÃ±Ã­as, Aseguradoras)
    PERFORM fun_create_permission('Crear CatÃ¡logos',    'CREATE_CATALOGS',  'Crear registros en catÃ¡logos',           'MODULE_CATALOGS');
    PERFORM fun_create_permission('Editar CatÃ¡logos',   'EDIT_CATALOGS',    'Editar registros de catÃ¡logos',          'MODULE_CATALOGS');
    PERFORM fun_create_permission('Activar CatÃ¡logos',  'TOGGLE_CATALOGS',  'Activar/desactivar registros',           'MODULE_CATALOGS');

    -- 8. Permisos de ConfiguraciÃ³n (Usuarios)
    PERFORM fun_create_permission('Gestionar Usuarios', 'MANAGE_USERS',  'Asignar roles y permisos',     'MODULE_SETTINGS');
    PERFORM fun_create_permission('Crear Usuarios',     'CREATE_USERS',  'Crear nuevos usuarios',        'MODULE_SETTINGS');
    PERFORM fun_create_permission('Editar Usuarios',    'EDIT_USERS',    'Editar datos de usuario',      'MODULE_SETTINGS');

    -- =============================================
    -- ASIGNACIONES DE ROLES (Seed inicial)
    -- Las asignaciones pueden cambiarse desde el Panel de Permisos
    -- =============================================
    
    -- Limpiar asignaciones previas para evitar "permisos fantasma" de corridas anteriores
    DELETE FROM tab_role_permissions;
    
    -- ADMINISTRADOR: Todos los permisos de todos los mÃ³dulos
    PERFORM fun_assign_role_permission(v_admin_role, 'VIEW_BUSES');
    PERFORM fun_assign_role_permission(v_admin_role, 'CREATE_BUSES');
    PERFORM fun_assign_role_permission(v_admin_role, 'EDIT_BUSES');
    PERFORM fun_assign_role_permission(v_admin_role, 'DELETE_BUSES');
    PERFORM fun_assign_role_permission(v_admin_role, 'VIEW_DRIVERS');
    PERFORM fun_assign_role_permission(v_admin_role, 'CREATE_DRIVERS');
    PERFORM fun_assign_role_permission(v_admin_role, 'EDIT_DRIVERS');
    PERFORM fun_assign_role_permission(v_admin_role, 'DELETE_DRIVERS');
    PERFORM fun_assign_role_permission(v_admin_role, 'VIEW_ROUTES');
    PERFORM fun_assign_role_permission(v_admin_role, 'CREATE_ROUTES');
    PERFORM fun_assign_role_permission(v_admin_role, 'EDIT_ROUTES');
    PERFORM fun_assign_role_permission(v_admin_role, 'DELETE_ROUTES');
    PERFORM fun_assign_role_permission(v_admin_role, 'VIEW_STOPS');
    PERFORM fun_assign_role_permission(v_admin_role, 'CREATE_STOPS');
    PERFORM fun_assign_role_permission(v_admin_role, 'EDIT_STOPS');
    PERFORM fun_assign_role_permission(v_admin_role, 'VIEW_TRIPS');
    PERFORM fun_assign_role_permission(v_admin_role, 'CREATE_TRIPS');
    PERFORM fun_assign_role_permission(v_admin_role, 'ASSIGN_TRIPS');
    PERFORM fun_assign_role_permission(v_admin_role, 'CANCEL_TRIPS');
    PERFORM fun_assign_role_permission(v_admin_role, 'CREATE_CATALOGS');
    PERFORM fun_assign_role_permission(v_admin_role, 'EDIT_CATALOGS');
    PERFORM fun_assign_role_permission(v_admin_role, 'TOGGLE_CATALOGS');
    PERFORM fun_assign_role_permission(v_admin_role, 'MANAGE_USERS');
    PERFORM fun_assign_role_permission(v_admin_role, 'CREATE_USERS');
    PERFORM fun_assign_role_permission(v_admin_role, 'EDIT_USERS');

    -- TURNADOR: Permisos de su trabajo principal
    -- El Administrador puede ajustar esto desde el Panel de Permisos
    PERFORM fun_assign_role_permission(v_turnador_role, 'VIEW_BUSES');
    PERFORM fun_assign_role_permission(v_turnador_role, 'VIEW_DRIVERS');
    PERFORM fun_assign_role_permission(v_turnador_role, 'VIEW_ROUTES');
    PERFORM fun_assign_role_permission(v_turnador_role, 'VIEW_TRIPS');
    PERFORM fun_assign_role_permission(v_turnador_role, 'CREATE_TRIPS');
    PERFORM fun_assign_role_permission(v_turnador_role, 'ASSIGN_TRIPS');
    PERFORM fun_assign_role_permission(v_turnador_role, 'CANCEL_TRIPS');

END $$;




-- =============================================
-- FUNCTION: fun_reorder_route_points_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_reorder_route_points v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Reordena todos los puntos de una ruta en tab_route_points_assoc
--   aplicando el nuevo orden recibido como array JSON.
--   Realiza la operaciÃ³n de forma atÃ³mica: si algÃºn id_point no existe
--   en la ruta, hace ROLLBACK y retorna error.
--
--   Caso de uso principal:
--     - DespuÃ©s de un drag-and-drop en la UI para reordenar paradas.
--     - DespuÃ©s de eliminar un punto (compactar huecos).
--
--   El array worder_json debe contener TODOS los id_point activos de
--   la ruta en el nuevo orden deseado. Ejemplo:
--     '[{"id_point":3,"order":1},{"id_point":1,"order":2},{"id_point":5,"order":3}]'
--
--   Reglas de negocio (validar en backend antes de llamar):
--     - El array debe contener exactamente los mismos puntos que la ruta tiene actualmente.
--     - No puede quedar la ruta con menos de 2 puntos.
--
-- ParÃ¡metros (IN):
--   wid_route    tab_route_points_assoc.id_route%TYPE â€” ID de la ruta a reordenar
--   worder_json  TEXT                                  â€” JSON array [{id_point, order}]
--
-- Retorna (OUT):
--   success       BOOLEAN                              â€” TRUE si se reordenÃ³ correctamente
--   msg           TEXT                                 â€” Mensaje descriptivo
--   error_code    VARCHAR(50)                         â€” NULL si Ã©xito; cÃ³digo si falla
--   updated_count INTEGER                              â€” NÃºmero de puntos reordenados
--
-- CÃ³digos de error:
--   ROUTE_REORDER_POINT_NOT_FOUND â€” AlgÃºn id_point del array no pertenece a la ruta
--   ROUTE_REORDER_JSON_ERROR      â€” JSON malformado
--   ROUTE_REORDER_CHECK           â€” AlgÃºn order <= 0 (violaciÃ³n de CHECK)
--   ROUTE_REORDER_ORDER_CONFLICT  â€” Dos puntos con el mismo order (violaciÃ³n de PK)
--   ROUTE_REORDER_ERROR           â€” Error inesperado
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_reorder_route_points(SMALLINT, TEXT);

CREATE OR REPLACE FUNCTION fun_reorder_route_points(
  wid_route     tab_route_points_assoc.id_route%TYPE,
  worder_json   TEXT,

  -- ParÃ¡metros OUT
  OUT success        BOOLEAN,
  OUT msg            TEXT,
  OUT error_code     VARCHAR(50),
  OUT updated_count  INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_item        JSONB;
  v_id_point    tab_route_points_assoc.id_point%TYPE;
  v_new_order   tab_route_points_assoc.point_order%TYPE;
  v_rows        INTEGER;
  v_total       INTEGER := 0;
  -- Orden temporal POSITIVO alto para evitar conflictos de PK durante el UPDATE.
  -- Debe ser > 0 para satisfacer CHECK (point_order > 0).
  -- Usamos 10000 + original para garantizar que no colisione con orders normales (1..N).
  v_temp_base   SMALLINT := 10000;
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  updated_count := 0;

  -- Paso 1: Pasar todos los point_order a valores temporales altos
  -- para evitar conflictos de PK al actualizar en cascada.
  -- Ejemplo: order 1 â†’ 10001, order 2 â†’ 10002, etc. (todos > 0, todos Ãºnicos)
  UPDATE tab_route_points_assoc
  SET    point_order = (v_temp_base + point_order)
  WHERE  id_route = wid_route;

  GET DIAGNOSTICS v_total = ROW_COUNT;

  IF v_total = 0 THEN
    msg        := 'Ruta no encontrada o sin puntos asignados (ID: ' || wid_route || ')';
    error_code := 'ROUTE_REORDER_POINT_NOT_FOUND';
    RETURN;
  END IF;

  -- Paso 2: Aplicar el nuevo orden desde el JSON
  FOR v_item IN
    SELECT value FROM jsonb_array_elements(worder_json::JSONB)
  LOOP
    v_id_point  := (v_item->>'id_point')::SMALLINT;
    v_new_order := (v_item->>'order')::SMALLINT;

    UPDATE tab_route_points_assoc
    SET    point_order = v_new_order
    WHERE  id_route = wid_route
      AND  id_point = v_id_point;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
      msg        := 'Punto (ID: ' || v_id_point || ') no pertenece a la ruta (ID: ' || wid_route || ')';
      error_code := 'ROUTE_REORDER_POINT_NOT_FOUND';
      RAISE EXCEPTION '%', msg;   -- fuerza ROLLBACK del bloque completo
    END IF;

    updated_count := updated_count + 1;
  END LOOP;

  success := TRUE;
  msg     := updated_count || ' punto(s) de la ruta (ID: ' || wid_route || ') reordenados exitosamente';

EXCEPTION
  WHEN SQLSTATE '22023' OR SQLSTATE 'P0001' THEN
    -- RAISE EXCEPTION lanzado internamente (punto no encontrado)
    updated_count := 0;
  WHEN invalid_text_representation OR invalid_parameter_value THEN
    msg           := 'JSON de orden invÃ¡lido: ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_JSON_ERROR';
    updated_count := 0;
  WHEN check_violation THEN
    msg           := 'Valor de order invÃ¡lido (debe ser > 0): ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_CHECK';
    updated_count := 0;
  WHEN unique_violation THEN
    msg           := 'Conflicto de orden: dos puntos con el mismo order: ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_ORDER_CONFLICT';
    updated_count := 0;
  WHEN OTHERS THEN
    msg           := 'Error inesperado: ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_ERROR';
    updated_count := 0;
END;
$$;


-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_reorder_route_points(SMALLINT, TEXT) IS
'v1.0 â€” Reordena atÃ³micamente los puntos de una ruta (tab_route_points_assoc). Usa valores temporales negativos para evitar conflictos de PK durante el UPDATE en cascada. Recibe el nuevo orden como JSON array [{id_point, order}].';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Reordenar 3 puntos de la ruta ID=1
-- Antes: punto 1 â†’ posiciÃ³n 1, punto 2 â†’ posiciÃ³n 2, punto 3 â†’ posiciÃ³n 3
-- DespuÃ©s (drag-and-drop): punto 3 â†’ posiciÃ³n 1, punto 1 â†’ posiciÃ³n 2, punto 2 â†’ posiciÃ³n 3
SELECT * FROM fun_reorder_route_points(
  1,
  '[{"id_point":3,"order":1},{"id_point":1,"order":2},{"id_point":2,"order":3}]'
);
-- success | msg                                          | error_code | updated_count
-- TRUE    | 3 punto(s) de la ruta (ID: 1) reordenados   | NULL       | 3

-- Error: punto 99 no pertenece a la ruta
SELECT * FROM fun_reorder_route_points(
  1,
  '[{"id_point":99,"order":1},{"id_point":1,"order":2}]'
);
-- success | msg                                                      | error_code                    | updated_count
-- FALSE   | Punto (ID: 99) no pertenece a la ruta (ID: 1)          | ROUTE_REORDER_POINT_NOT_FOUND | 0

-- Flujo recomendado desde el backend (despuÃ©s de un drag-and-drop):
--   const newOrder = points.map((p, i) => ({ id_point: p.id_point, order: i + 1 }))
--   pool.query(`SELECT * FROM fun_reorder_route_points($1, $2)`,
--              [id_route, JSON.stringify(newOrder)])

*/


-- =============================================
-- FUNCTION: fun_resolve_incident_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_resolve_incident_v1.0
-- =============================================
-- Resuelve un incidente reportado por un conductor.
--
-- ParÃ¡metros IN:
--   wid_incident      INTEGER           â€” ID del incidente
--
-- OUT:
--   success           BOOLEAN
--   msg               TEXT
--   error_code        VARCHAR(50)
--
-- CÃ³digos de error:
--   INCIDENT_NOT_FOUND   â€” id_incident no existe o ya estÃ¡ resuelto
--   INCIDENT_UPDATE_ERROR â€” error inesperado
-- =============================================

DROP FUNCTION IF EXISTS fun_resolve_incident(INTEGER);

CREATE OR REPLACE FUNCTION fun_resolve_incident(
  wid_trip_incident tab_trip_incidents.id_trip_incident%TYPE,

  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50)
)
LANGUAGE plpgsql AS $$
DECLARE
  v_updated INTEGER;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  UPDATE tab_trip_incidents
  SET 
    status_incident = 'resolved',
    resolved_at = NOW()
  WHERE 
    id_trip_incident = wid_trip_incident 
    AND status_incident = 'active';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    msg        := 'Incidente no encontrado o ya estaba resuelto.';
    error_code := 'INCIDENT_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Incidente marcado como resuelto exitosamente.';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_UPDATE_ERROR';
END;
$$;


-- =============================================
-- FUNCTION: fun_toggle_arl_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_arl v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Invierte el estado is_active de un registro
--   en tab_arl (activo â†’ inactivo / inactivo â†’ activo).
--
-- ParÃ¡metros (IN):
--   wid_arl         SMALLINT  â€” ID de la ARL
--
-- Retorna (OUT):
--   success         BOOLEAN     â€” TRUE si se actualizÃ³ correctamente
--   msg             TEXT        â€” Mensaje descriptivo
--   error_code      VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_arl      SMALLINT    â€” ID afectado (NULL si falla)
--   out_is_active   BOOLEAN     â€” Nuevo estado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_arl(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_arl(
  wid_arl         tab_arl.id_arl%TYPE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_arl    tab_arl.id_arl%TYPE,
  OUT out_name      tab_arl.name_arl%TYPE,
  OUT out_is_active tab_arl.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_arl    := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_arl
  SET    is_active = NOT is_active
  WHERE  id_arl    = wid_arl
  RETURNING id_arl, name_arl, is_active
  INTO out_id_arl, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la ARL con ID: ' || wid_arl;
    error_code := 'ARL_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'ARL ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente (ID: ' || out_id_arl || ')';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ARL_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_arl(SMALLINT) IS
'v1.0 â€” Invierte is_active de ARL en tab_arl. Retorna ARL_NOT_FOUND si el ID no existe. El mensaje indica si quedÃ³ activada o desactivada.';


-- =============================================
-- FUNCTION: fun_toggle_brand_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_brand v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Invierte el estado is_active de un registro
--   en tab_brands (activo â†’ inactivo / inactivo â†’ activo).
--
-- ParÃ¡metros (IN):
--   wid_brand       SMALLINT  â€” ID de la marca
--
-- Retorna (OUT):
--   success         BOOLEAN     â€” TRUE si se actualizÃ³ correctamente
--   msg             TEXT        â€” Mensaje descriptivo
--   error_code      VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_brand    SMALLINT    â€” ID afectado (NULL si falla)
--   out_is_active   BOOLEAN     â€” Nuevo estado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_brand(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_brand(
  wid_brand       tab_brands.id_brand%TYPE,

  -- ParÃ¡metros OUT
  OUT success        BOOLEAN,
  OUT msg            TEXT,
  OUT error_code     VARCHAR(50),
  OUT out_id_brand   tab_brands.id_brand%TYPE,
  OUT out_name       tab_brands.brand_name%TYPE,
  OUT out_is_active  tab_brands.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_brand  := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_brands
  SET    is_active = NOT is_active
  WHERE  id_brand  = wid_brand
  RETURNING id_brand, brand_name, is_active
  INTO out_id_brand, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la marca con ID: ' || wid_brand;
    error_code := 'BRAND_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Marca ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente (ID: ' || out_id_brand || ')';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BRAND_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_brand(SMALLINT) IS
'v1.0 â€” Invierte is_active de marca en tab_brands. Retorna BRAND_NOT_FOUND si el ID no existe. El mensaje indica si quedÃ³ activada o desactivada.';


-- =============================================
-- FUNCTION: fun_toggle_bus_status_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_bus_status v1.1
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Activa o desactiva un bus en tab_buses (campo is_active).
--   La validaciÃ³n de negocio (bus activo, usuario vÃ¡lido, etc.)
--   es responsabilidad del backend (Node.js).
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros (IN):
--   wplate_number  VARCHAR(6)  â€” Placa del bus (identificador Ãºnico, no PK)
--   wis_active     BOOLEAN     â€” TRUE = activar, FALSE = desactivar
--   wuser_update   SMALLINT    â€” Usuario que realiza el cambio (FK a tab_users)
--
-- Retorna (OUT):
--   success       BOOLEAN      â€” TRUE si se aplicÃ³ el cambio
--   msg           TEXT         â€” Mensaje descriptivo del resultado
--   error_code    VARCHAR(50)  â€” NULL si success = TRUE
--   out_id_bus    SMALLINT     â€” id_bus (PK) del bus modificado
--   new_status    BOOLEAN      â€” Nuevo valor de is_active
--
-- CÃ³digos de error:
--   BUS_NOT_FOUND    â€” La placa no existe en tab_buses
--   BUS_FK_VIOLATION â€” FK invÃ¡lida (usuario no existe)
--   BUS_UPDATE_ERROR â€” Error inesperado en el UPDATE
--
-- VersiÃ³n   : 1.1
-- Fecha     : 2026-03-15
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_bus_status(VARCHAR, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_bus_status(
  wplate_number  tab_buses.plate_number%TYPE,
  wis_active     BOOLEAN,
  wuser_update   tab_buses.user_update%TYPE,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT out_id_bus  tab_buses.id_bus%TYPE,
  OUT new_status  BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_plate  tab_buses.plate_number%TYPE;
  v_id_bus tab_buses.id_bus%TYPE;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_bus := NULL;
  new_status := NULL;

  v_plate := UPPER(TRIM(wplate_number));

  UPDATE tab_buses
  SET
    is_active   = wis_active,
    updated_at  = NOW(),
    user_update = wuser_update
  WHERE plate_number = v_plate
  RETURNING id_bus INTO v_id_bus;

  IF v_id_bus IS NULL THEN
    msg        := 'Bus no encontrado con placa: ' || v_plate;
    error_code := 'BUS_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  out_id_bus := v_id_bus;
  new_status := wis_active;
  msg        := 'Bus ' || v_plate || ' (id_bus=' || v_id_bus || ') '
                || CASE WHEN wis_active THEN 'activado' ELSE 'desactivado' END
                || ' exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario no vÃ¡lido: ' || SQLERRM;
    error_code := 'BUS_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BUS_UPDATE_ERROR';
END;
$$;

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar bus ABC123 (ejecutado por usuario 1)
SELECT * FROM fun_toggle_bus_status('ABC123', FALSE, 1);
-- success | msg                                         | error_code | out_id_bus | new_status
-- TRUE    | Bus ABC123 (id_bus=3) desactivado exitosamente | NULL    | 3          | FALSE

-- Activar bus previamente desactivado
SELECT * FROM fun_toggle_bus_status('ABC123', TRUE, 1);
-- success | msg                                       | error_code | out_id_bus | new_status
-- TRUE    | Bus ABC123 (id_bus=3) activado exitosamente | NULL    | 3          | TRUE

-- Placa inexistente
SELECT * FROM fun_toggle_bus_status('ZZZ999', FALSE, 1);
-- success | msg                                | error_code    | out_id_bus | new_status
-- FALSE   | Bus no encontrado con placa: ZZZ999 | BUS_NOT_FOUND | NULL      | NULL

*/


-- =============================================
-- FUNCTION: fun_toggle_company_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_company v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Invierte el estado is_active de una compaÃ±Ã­a
--   en tab_companies (activo â†’ inactivo / inactivo â†’ activo).
--   Registra auditorÃ­a: user_update + updated_at.
--
-- ParÃ¡metros (IN):
--   wid_company    SMALLINT  â€” ID de la compaÃ±Ã­a
--   wuser_update   SMALLINT  â€” ID del usuario que realiza el cambio
--
-- Retorna (OUT):
--   success          BOOLEAN      â€” TRUE si se actualizÃ³ correctamente
--   msg              TEXT         â€” Mensaje descriptivo
--   error_code       VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_company   SMALLINT     â€” ID afectado (NULL si falla)
--   out_company_name VARCHAR(100) â€” Nombre actual (NULL si falla)
--   out_nit_company  VARCHAR(15)  â€” NIT actual (NULL si falla)
--   out_is_active    BOOLEAN      â€” Nuevo estado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_company(SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_company(
  wid_company    tab_companies.id_company%TYPE,
  wuser_update   tab_companies.user_update%TYPE,

  -- ParÃ¡metros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_company   tab_companies.id_company%TYPE,
  OUT out_company_name tab_companies.company_name%TYPE,
  OUT out_nit_company  tab_companies.nit_company%TYPE,
  OUT out_is_active    tab_companies.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success          := FALSE;
  msg              := '';
  error_code       := NULL;
  out_id_company   := NULL;
  out_company_name := NULL;
  out_nit_company  := NULL;
  out_is_active    := NULL;

  UPDATE tab_companies
  SET
    is_active   = NOT is_active,
    updated_at  = NOW(),
    user_update = wuser_update
  WHERE id_company = wid_company
  RETURNING id_company, company_name, nit_company, is_active
  INTO out_id_company, out_company_name, out_nit_company, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la compaÃ±Ã­a con ID: ' || wid_company;
    error_code := 'COMPANY_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'CompaÃ±Ã­a ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente: ' || out_company_name;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario actualizador no vÃ¡lido: ' || SQLERRM;
    error_code := 'COMPANY_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'COMPANY_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_company(SMALLINT, SMALLINT) IS
'v1.0 â€” Invierte is_active de compaÃ±Ã­a en tab_companies. Registra user_update y updated_at. Retorna COMPANY_NOT_FOUND si el ID no existe.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar compaÃ±Ã­a
SELECT * FROM fun_toggle_company(1, 1);

-- Resultado exitoso (desactivada):
-- success | msg                                         | error_code | out_id_company | out_company_name | out_nit_company | out_is_active
-- --------+---------------------------------------------+------------+----------------+------------------+-----------------+--------------
-- true    | CompaÃ±Ã­a desactivada exitosamente: MetrolÃ­nea | NULL     | 1              | MetrolÃ­nea       | 9001234561      | false

-- Volver a activar
SELECT * FROM fun_toggle_company(1, 1);
-- out_is_active = true

-- ID no existe â†’ 404 en backend:
SELECT * FROM fun_toggle_company(99, 1);
-- success=false, error_code='COMPANY_NOT_FOUND'

*/


-- =============================================
-- FUNCTION: fun_toggle_driver_status_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_driver_status v1.0
-- Directorio: functions_v2
-- =============================================

-- DescripciÃ³n:
--   Activa o desactiva un conductor en tab_drivers (campo is_active).  
--   La validaciÃ³n de negocio (Ãºltimo conductor activo, estado actual, etc.)
--   es responsabilidad del backend (Node.js). Los constraints de la BD actÃºan como Ãºltima barrera.
-- ParÃ¡metros (IN):
--   wid_driver  BIGINT  â€” CÃ©dula del conductor a cambiar
--   wis_active  BOOLEAN â€” TRUE = activar, FALSE = desactivar       
-- Retorna (OUT):
--   success    BOOLEAN     â€” TRUE si se aplicÃ³ el cambio   
--   msg        TEXT        â€” Mensaje descriptivo del resultado
--   error_code VARCHAR(50) â€” NULL si success = TRUE
--   new_status BOOLEAN     â€” Nuevo valor de is_active
-- CÃ³digos de error:
--   DRIVER_NOT_FOUND   â€” La cÃ©dula no existe en tab_drivers
--   DRIVER_UPDATE_ERROR â€” Error inesperado en el UPDATE
-- VersiÃ³n   : 1.0      
-- Fecha     : 2026-03-11
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_driver_status(BIGINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_toggle_driver_status(
  wid_driver  tab_drivers.id_driver%TYPE,
  wis_active  BOOLEAN,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT new_status  BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;       
  new_status := NULL;

  UPDATE tab_drivers
  SET is_active = wis_active
  WHERE id_driver = wid_driver;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'El conductor no existe (id_driver: ' || COALESCE(wid_driver::TEXT, 'NULL') || ')';
    error_code := 'DRIVER_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  msg     := 'Estado del conductor actualizado exitosamente';   
    new_status := wis_active;
EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'DRIVER_UPDATE_ERROR';
END;
$$; 



-- =============================================
-- FUNCTION: fun_toggle_eps_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_eps v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Invierte el estado is_active de un registro
--   en tab_eps (activo â†’ inactivo / inactivo â†’ activo).
--
-- ParÃ¡metros (IN):
--   wid_eps         SMALLINT  â€” ID de la EPS
--
-- Retorna (OUT):
--   success         BOOLEAN   â€” TRUE si se actualizÃ³ correctamente
--   msg             TEXT      â€” Mensaje descriptivo
--   error_code      VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_eps      SMALLINT  â€” ID afectado (NULL si falla)
--   out_is_active   BOOLEAN   â€” Nuevo estado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_eps(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_eps(
  wid_eps         tab_eps.id_eps%TYPE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_eps    tab_eps.id_eps%TYPE,
  OUT out_name      tab_eps.name_eps%TYPE,
  OUT out_is_active tab_eps.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_eps    := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_eps
  SET    is_active = NOT is_active
  WHERE  id_eps    = wid_eps
  RETURNING id_eps, name_eps, is_active
  INTO out_id_eps, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la EPS con ID: ' || wid_eps;
    error_code := 'EPS_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'EPS ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente (ID: ' || out_id_eps || ')';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'EPS_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_eps(SMALLINT) IS
'v1.0 â€” Invierte is_active de EPS en tab_eps. Retorna EPS_NOT_FOUND si el ID no existe. El mensaje indica si quedÃ³ activada o desactivada.';


-- =============================================
-- FUNCTION: fun_toggle_incident_type_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_incident_type v1.0
-- Directorio: functions_v2
-- =============================================
DROP FUNCTION IF EXISTS fun_toggle_incident_type(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_incident_type(
  wid_incident tab_incident_types.id_incident%TYPE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_type   tab_incident_types.id_incident%TYPE,
  OUT out_name      tab_incident_types.name_incident%TYPE,
  OUT out_is_active tab_incident_types.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_type := NULL;
  out_name   := NULL;
  out_is_active := NULL;

  UPDATE tab_incident_types
  SET is_active = NOT is_active
  WHERE id_incident = wid_incident
  RETURNING id_incident, name_incident, is_active
  INTO out_id_type, out_name, out_is_active;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    msg        := 'Tipo de incidente no encontrado (ID: ' || wid_incident || ')';
    error_code := 'INCIDENT_TYPE_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Estado del tipo de incidente actualizado: ' || 
             CASE WHEN out_is_active THEN 'Activo' ELSE 'Inactivo' END;

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_TYPE_TOGGLE_ERROR';
END;
$$;


-- =============================================
-- FUNCTION: fun_toggle_insurance_type.sql
-- =============================================

-- ==========================================
-- CAMBIAR ESTADO DE TIPO DE SEGURO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_toggle_insurance_type(
    p_id_type tab_insurance_types.id_insurance_type%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_type tab_insurance_types.id_insurance_type%TYPE,
    out_name tab_insurance_types.name_insurance%TYPE,
    out_is_active tab_insurance_types.is_active%TYPE
) AS $$
DECLARE
    v_name VARCHAR(50);
    v_new_active BOOLEAN;
BEGIN
    UPDATE tab_insurance_types
    SET is_active = NOT is_active
    WHERE id_insurance_type = p_id_type
    RETURNING name_insurance, is_active INTO v_name, v_new_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de seguro no encontrado.'::TEXT, 'INSURANCE_TYPE_NOT_FOUND'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Estado actualizado.'::TEXT, NULL::VARCHAR, p_id_type, v_name, v_new_active;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- FUNCTION: fun_toggle_insurer_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_insurer v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Invierte el estado is_active de un registro
--   en tab_insurers (activo â†’ inactivo / inactivo â†’ activo).
--
-- ParÃ¡metros (IN):
--   wid_insurer       SMALLINT  â€” ID de la aseguradora
--
-- Retorna (OUT):
--   success           BOOLEAN     â€” TRUE si se actualizÃ³ correctamente
--   msg               TEXT        â€” Mensaje descriptivo
--   error_code        VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_insurer    SMALLINT    â€” ID afectado (NULL si falla)
--   out_is_active     BOOLEAN     â€” Nuevo estado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_insurer(SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_insurer(
  wid_insurer       tab_insurers.id_insurer%TYPE,

  -- ParÃ¡metros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_insurer   tab_insurers.id_insurer%TYPE,
  OUT out_name         tab_insurers.insurer_name%TYPE,
  OUT out_is_active    tab_insurers.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success        := FALSE;
  msg            := '';
  error_code     := NULL;
  out_id_insurer := NULL;
  out_name       := NULL;
  out_is_active  := NULL;

  UPDATE tab_insurers
  SET    is_active  = NOT is_active
  WHERE  id_insurer = wid_insurer
  RETURNING id_insurer, insurer_name, is_active
  INTO out_id_insurer, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la aseguradora con ID: ' || wid_insurer;
    error_code := 'INSURER_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Aseguradora ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente (ID: ' || out_id_insurer || ')';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INSURER_TOGGLE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_insurer(SMALLINT) IS
'v1.0 â€” Invierte is_active de aseguradora en tab_insurers. Retorna INSURER_NOT_FOUND si el ID no existe. El mensaje indica si quedÃ³ activada o desactivada.';


-- =============================================
-- FUNCTION: fun_toggle_route_point_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Activa o desactiva un punto de ruta en tab_route_points (campo is_active).
--   Regla de negocio: no se puede desactivar un punto que estÃ¡ activo en
--   una o mÃ¡s rutas (tab_route_points_assoc); esa validaciÃ³n es
--   responsabilidad del backend (Node.js) antes de llamar esta funciÃ³n.
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros (IN):
--   wid_point     tab_route_points.id_point%TYPE    â€” ID del punto a activar/desactivar
--   wis_active    tab_route_points.is_active%TYPE   â€” TRUE = activar, FALSE = desactivar
--   wuser_update  tab_route_points.user_update%TYPE â€” Usuario que realiza el cambio
--
-- Retorna (OUT):
--   success       BOOLEAN                           â€” TRUE si se aplicÃ³ el cambio
--   msg           TEXT                              â€” Mensaje descriptivo
--   error_code    VARCHAR(50)                       â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_point  tab_route_points.id_point%TYPE    â€” ID del punto modificado
--   new_status    tab_route_points.is_active%TYPE   â€” Nuevo valor de is_active
--
-- CÃ³digos de error:
--   ROUTE_POINT_NOT_FOUND    â€” El id_point no existe en tab_route_points
--   ROUTE_POINT_FK_VIOLATION â€” FK de user_update invÃ¡lida
--   ROUTE_POINT_UPDATE_ERROR â€” Error inesperado en el UPDATE
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_route_point(SMALLINT, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_route_point(
  wid_point     tab_route_points.id_point%TYPE,
  wis_active    tab_route_points.is_active%TYPE,
  wuser_update  tab_route_points.user_update%TYPE,

  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_point  tab_route_points.id_point%TYPE,
  OUT new_status    tab_route_points.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_point  tab_route_points.id_point%TYPE;
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_point := NULL;
  new_status   := NULL;

  UPDATE tab_route_points SET
    is_active   = wis_active,
    updated_at  = NOW(),
    user_update = wuser_update
  WHERE id_point = wid_point
  RETURNING id_point INTO v_id_point;

  IF v_id_point IS NULL THEN
    msg        := 'Punto de ruta no encontrado (ID: ' || wid_point || ')';
    error_code := 'ROUTE_POINT_NOT_FOUND';
    RETURN;
  END IF;

  out_id_point := v_id_point;
  new_status   := wis_active;
  success      := TRUE;
  msg          := 'Punto de ruta (ID: ' || out_id_point || ') '
                  || CASE WHEN wis_active THEN 'activado' ELSE 'desactivado' END
                  || ' exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario no vÃ¡lido (user_update): ' || SQLERRM;
    error_code := 'ROUTE_POINT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_route_point(SMALLINT, BOOLEAN, SMALLINT) IS
'v1.0 â€” Activa o desactiva un punto de ruta en tab_route_points. Usa RETURNING para detectar NOT FOUND. La regla de negocio (no desactivar si estÃ¡ en uso) debe validarla el backend antes de llamar esta funciÃ³n.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar punto ID=3 (ejecutado por usuario 1)
SELECT * FROM fun_toggle_route_point(3, FALSE, 1);
-- success | msg                                          | error_code | out_id_point | new_status
-- TRUE    | Punto de ruta (ID: 3) desactivado exitosamente | NULL    | 3            | FALSE

-- Activar punto previamente desactivado
SELECT * FROM fun_toggle_route_point(3, TRUE, 1);
-- success | msg                                        | error_code | out_id_point | new_status
-- TRUE    | Punto de ruta (ID: 3) activado exitosamente | NULL     | 3            | TRUE

-- ID inexistente
SELECT * FROM fun_toggle_route_point(99, FALSE, 1);
-- success | msg                                    | error_code              | out_id_point | new_status
-- FALSE   | Punto de ruta no encontrado (ID: 99)  | ROUTE_POINT_NOT_FOUND   | NULL         | NULL

*/


-- =============================================
-- FUNCTION: fun_toggle_route_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_route v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Activa o desactiva una ruta en tab_routes (campo is_active).
--   Reglas de negocio (validar en backend antes de llamar):
--     - No desactivar una ruta con viajes activos en tab_trips.
--     - No desactivar si hay turnos en curso que la referencian.
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros (IN):
--   wid_route     tab_routes.id_route%TYPE     â€” ID de la ruta a activar/desactivar
--   wis_active    tab_routes.is_active%TYPE    â€” TRUE = activar, FALSE = desactivar
--   wuser_update  tab_routes.user_update%TYPE  â€” Usuario que realiza el cambio
--
-- Retorna (OUT):
--   success       BOOLEAN                      â€” TRUE si se aplicÃ³ el cambio
--   msg           TEXT                         â€” Mensaje descriptivo
--   error_code    VARCHAR(50)                  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_route  tab_routes.id_route%TYPE     â€” ID de la ruta modificada
--   new_status    tab_routes.is_active%TYPE    â€” Nuevo valor de is_active
--
-- CÃ³digos de error:
--   ROUTE_NOT_FOUND    â€” El id_route no existe en tab_routes
--   ROUTE_FK_VIOLATION â€” FK de user_update invÃ¡lida
--   ROUTE_UPDATE_ERROR â€” Error inesperado
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_route(SMALLINT, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_toggle_route(
  wid_route     tab_routes.id_route%TYPE,
  wis_active    tab_routes.is_active%TYPE,
  wuser_update  tab_routes.user_update%TYPE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_route  tab_routes.id_route%TYPE,
  OUT new_status    tab_routes.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_route  tab_routes.id_route%TYPE;
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_route := NULL;
  new_status   := NULL;

  UPDATE tab_routes SET
    is_active   = wis_active,
    updated_at  = NOW(),
    user_update = wuser_update
  WHERE id_route = wid_route
  RETURNING id_route INTO v_id_route;

  IF v_id_route IS NULL THEN
    msg        := 'Ruta no encontrada (ID: ' || wid_route || ')';
    error_code := 'ROUTE_NOT_FOUND';
    RETURN;
  END IF;

  out_id_route := v_id_route;
  new_status   := wis_active;
  success      := TRUE;
  msg          := 'Ruta (ID: ' || out_id_route || ') '
                  || CASE WHEN wis_active THEN 'activada' ELSE 'desactivada' END
                  || ' exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario no vÃ¡lido (user_update): ' || SQLERRM;
    error_code := 'ROUTE_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_toggle_route(SMALLINT, BOOLEAN, SMALLINT) IS
'v1.0 â€” Activa o desactiva una ruta en tab_routes. La verificaciÃ³n de viajes/turnos activos debe hacerse en el backend antes de llamar esta funciÃ³n.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar ruta ID=1
SELECT * FROM fun_toggle_route(1, FALSE, 1);
-- success | msg                                | error_code | out_id_route | new_status
-- TRUE    | Ruta (ID: 1) desactivada exitosamente | NULL    | 1            | FALSE

-- Activar ruta
SELECT * FROM fun_toggle_route(1, TRUE, 1);
-- success | msg                               | error_code | out_id_route | new_status
-- TRUE    | Ruta (ID: 1) activada exitosamente | NULL      | 1            | TRUE

-- ID inexistente
SELECT * FROM fun_toggle_route(99, FALSE, 1);
-- success | msg                         | error_code      | out_id_route | new_status
-- FALSE   | Ruta no encontrada (ID: 99) | ROUTE_NOT_FOUND | NULL         | NULL

*/


-- =============================================
-- FUNCTION: fun_toggle_transit_doc_type.sql
-- =============================================

-- ==========================================
-- CAMBIAR ESTADO DE TIPO DE DOCUMENTO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_toggle_transit_doc_type(
    p_id_doc tab_transit_documents.id_doc%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_doc tab_transit_documents.id_doc%TYPE,
    out_name tab_transit_documents.name_doc%TYPE,
    out_is_active tab_transit_documents.is_active%TYPE
) AS $$
DECLARE
    v_name VARCHAR(100);
    v_new_active BOOLEAN;
BEGIN
    UPDATE tab_transit_documents
    SET is_active = NOT is_active
    WHERE id_doc = p_id_doc
    RETURNING name_doc, is_active INTO v_name, v_new_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de documento no encontrado.'::TEXT, 'TRANSIT_DOC_NOT_FOUND'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Estado actualizado.'::TEXT, NULL::VARCHAR, p_id_doc, v_name, v_new_active;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- FUNCTION: fun_toggle_user_status_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_toggle_user_status v2.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Activa o desactiva un usuario en tab_users (campo is_active).
--   La validaciÃ³n de negocio (Ãºltimo admin activo, estado actual, etc.)
--   es responsabilidad del backend (Node.js).
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros (IN):
--   wid_user    SMALLINT â€” ID del usuario a cambiar
--   wis_active  BOOLEAN  â€” TRUE = activar, FALSE = desactivar
--
-- Retorna (OUT):
--   success    BOOLEAN     â€” TRUE si se aplicÃ³ el cambio
--   msg        TEXT        â€” Mensaje descriptivo del resultado
--   error_code VARCHAR(50) â€” NULL si success = TRUE
--   new_status BOOLEAN     â€” Nuevo valor de is_active
--
-- CÃ³digos de error:
--   USER_NOT_FOUND   â€” El id_user no existe en tab_users
--   USER_UPDATE_ERROR â€” Error inesperado en el UPDATE
--
-- VersiÃ³n   : 2.0
-- Fecha     : 2026-03-11
-- =============================================

DROP FUNCTION IF EXISTS fun_toggle_user_status(SMALLINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_toggle_user_status(
  wid_user    tab_users.id_user%TYPE,
  wis_active  BOOLEAN,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT new_status  BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  new_status := NULL;

  UPDATE tab_users
  SET is_active = wis_active
  WHERE id_user = wid_user;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'Usuario no encontrado (id_user: ' || COALESCE(wid_user::TEXT, 'NULL') || ')';
    error_code := 'USER_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  new_status := wis_active;
  msg        := 'Usuario ' || CASE WHEN wis_active THEN 'activado' ELSE 'desactivado' END || ' exitosamente';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'USER_UPDATE_ERROR';
END;
$$;

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desactivar usuario con id_user = 2
SELECT * FROM fun_toggle_user_status(2, FALSE);
-- success | msg                              | error_code | new_status
-- TRUE    | Usuario desactivado exitosamente | NULL       | FALSE

-- Activar usuario previamente desactivado
SELECT * FROM fun_toggle_user_status(2, TRUE);
-- success | msg                            | error_code | new_status
-- TRUE    | Usuario activado exitosamente  | NULL       | TRUE

-- id_user inexistente
SELECT * FROM fun_toggle_user_status(999, FALSE);
-- success | msg                                    | error_code     | new_status
-- FALSE   | Usuario no encontrado (id_user: 999)   | USER_NOT_FOUND | NULL

*/


-- =============================================
-- FUNCTION: fun_unassign_driver.sql
-- =============================================

-- =============================================
-- fun_unassign_driver
-- desasigna al conductor activo de un bus (UPDATE en tab_bus_assignments)
-- =============================================
DROP FUNCTION IF EXISTS fun_unassign_driver(BIGINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_unassign_driver(
  wid_driver      tab_drivers.id_driver%TYPE,
  wunassigned_by  tab_users.id_user%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  UPDATE tab_bus_assignments
  SET unassigned_at = NOW(),
      unassigned_by = wunassigned_by
  WHERE id_driver   = wid_driver
    AND unassigned_at IS NULL;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'No se encontrÃ³ asignaciÃ³n activa para el conductor (id_driver: ' || COALESCE(wid_driver::TEXT, 'NULL') || ')';
    error_code := 'ASSIGNMENT_NOT_FOUND'; RETURN;
  END IF;

  success := TRUE;
  msg     := 'Conductor desasignado exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario de desasignaciÃ³n invÃ¡lido: ' || SQLERRM;
    error_code := 'UNASSIGNMENT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'UNASSIGNMENT_ERROR';
END;
$$;


-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Asignar conductor 12345678 al bus ABC123 (usuario 1 asigna)
SELECT * FROM fun_assign_driver('ABC123', 12345678, 1);
-- success | msg                             | error_code
-- TRUE    | Conductor asignado exitosamente | NULL

-- Intentar asignar cuando el bus o conductor ya tiene asignaciÃ³n activa
-- (uq_bus_active_assign o uq_driver_active_assign disparan unique_violation)
SELECT * FROM fun_assign_driver('ABC123', 99999999, 1);
-- success | msg                                                    | error_code
-- FALSE   | El bus o conductor ya tiene una asignaciÃ³n activa: ... | ASSIGNMENT_UNIQUE_VIOLATION

-- Bus o conductor no existen (FK constraint dispara foreign_key_violation)
SELECT * FROM fun_assign_driver('ZZZ000', 12345678, 1);
-- success | msg                                                      | error_code
-- FALSE   | Referencia invÃ¡lida (bus, conductor o usuario no existe) | ASSIGNMENT_FK_VIOLATION

-- Desasignar conductor 12345678 (usuario 1 realiza la desasignaciÃ³n)
SELECT * FROM fun_unassign_driver(12345678, 1);
-- success | msg                              | error_code
-- TRUE    | Conductor desasignado exitosamente | NULL

-- Intentar desasignar cuando no tiene asignaciÃ³n activa
SELECT * FROM fun_unassign_driver(12345678, 1);
-- success | msg                                                       | error_code
-- FALSE   | No se encontrÃ³ asignaciÃ³n activa para el conductor (...)  | ASSIGNMENT_NOT_FOUND

*/


-- =============================================
-- FUNCTION: fun_unassign_route_point_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_unassign_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Elimina la asociaciÃ³n de un punto con una ruta en tab_route_points_assoc.
--   Usa DELETE en lugar de is_active = FALSE porque la tabla pivote no
--   tiene campo de auditorÃ­a â€” una fila borrada no tiene historial relevante.
--   Si se necesita preservar el historial, usar is_active = FALSE directamente.
--
--   Reglas de negocio (validar en backend antes de llamar):
--     - No desasignar el primer o Ãºltimo punto si hay viajes activos en la ruta.
--     - Considerar si quedan al menos 2 puntos tras la eliminaciÃ³n.
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros (IN):
--   wid_route   tab_route_points_assoc.id_route%TYPE  â€” ID de la ruta
--   wid_point   tab_route_points_assoc.id_point%TYPE  â€” ID del punto a desasignar
--
-- Retorna (OUT):
--   success          BOOLEAN                                   â€” TRUE si se eliminÃ³
--   msg              TEXT                                      â€” Mensaje descriptivo
--   error_code       VARCHAR(50)                              â€” NULL si Ã©xito
--   out_id_route     tab_route_points_assoc.id_route%TYPE     â€” ID de la ruta (confirmaciÃ³n)
--   out_id_point     tab_route_points_assoc.id_point%TYPE     â€” ID del punto desasignado
--   out_point_order  tab_route_points_assoc.point_order%TYPE  â€” Orden que tenÃ­a en la ruta
--
-- CÃ³digos de error:
--   ROUTE_POINT_ASSOC_NOT_FOUND â€” La combinaciÃ³n (id_route, id_point) no existe
--   ROUTE_POINT_ASSOC_FK        â€” FK invÃ¡lida (raro en DELETE, pero posible)
--   ROUTE_POINT_ASSOC_ERROR     â€” Error inesperado
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_unassign_route_point(SMALLINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_unassign_route_point(
  wid_route   tab_route_points_assoc.id_route%TYPE,
  wid_point   tab_route_points_assoc.id_point%TYPE,

  -- ParÃ¡metros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_route     tab_route_points_assoc.id_route%TYPE,
  OUT out_id_point     tab_route_points_assoc.id_point%TYPE,
  OUT out_point_order  tab_route_points_assoc.point_order%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_point_order  tab_route_points_assoc.point_order%TYPE;
BEGIN

  success         := FALSE;
  msg             := '';
  error_code      := NULL;
  out_id_route    := NULL;
  out_id_point    := NULL;
  out_point_order := NULL;

  DELETE FROM tab_route_points_assoc
  WHERE  id_route = wid_route
    AND  id_point = wid_point
  RETURNING point_order INTO v_point_order;

  IF v_point_order IS NULL THEN
    msg        := 'AsociaciÃ³n no encontrada (ruta: ' || wid_route || ', punto: ' || wid_point || ')';
    error_code := 'ROUTE_POINT_ASSOC_NOT_FOUND';
    RETURN;
  END IF;

  out_id_route    := wid_route;
  out_id_point    := wid_point;
  out_point_order := v_point_order;
  success         := TRUE;
  msg             := 'Punto (ID: ' || wid_point || ') desasignado de ruta (ID: ' || wid_route
                     || '), posiciÃ³n liberada: ' || v_point_order;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Error de FK al eliminar asociaciÃ³n: ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_FK';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_ASSOC_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_unassign_route_point(SMALLINT, SMALLINT) IS
'v1.0 â€” Elimina la asociaciÃ³n de un punto con una ruta (DELETE en tab_route_points_assoc). Retorna el point_order que tenÃ­a para que el backend pueda reordenar si es necesario.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Desasignar punto ID=3 de ruta ID=1
SELECT * FROM fun_unassign_route_point(1, 3);
-- success | msg                                              | error_code | out_id_route | out_id_point | out_point_order
-- TRUE    | Punto (ID: 3) desasignado de ruta (ID: 1), posiciÃ³n liberada: 2 | NULL | 1  | 3            | 2

-- AsociaciÃ³n inexistente
SELECT * FROM fun_unassign_route_point(1, 99);
-- success | msg                                               | error_code                    | ...
-- FALSE   | AsociaciÃ³n no encontrada (ruta: 1, punto: 99)    | ROUTE_POINT_ASSOC_NOT_FOUND   | NULL

-- Flujo recomendado en el backend tras desasignar:
--   1. Llamar fun_unassign_route_point(id_route, id_point)
--   2. Si success = TRUE, llamar fun_reorder_route_points(id_route, [nuevo_orden])
--      para cerrar el hueco dejado por el punto eliminado.

*/


-- =============================================
-- FUNCTION: fun_unlink_driver_account_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_unlink_driver_account v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Desvincula la cuenta de sistema de un conductor.
--   En una transacciÃ³n atÃ³mica:
--     1. Elimina el rol Conductor de tab_user_roles (hard delete)
--     2. Desactiva el usuario en tab_users SOLO si no tiene otros roles activos
--     3. Elimina el vÃ­nculo de tab_driver_accounts (hard delete)
--
--   El usuario se preserva en tab_users (integridad referencial con auditorÃ­a).
--   La validaciÃ³n de negocio (conductor existe, tiene cuenta, no tiene viaje activo)
--   es responsabilidad del backend (Node.js).
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros:
--   wid_driver   BIGINT   â€” CÃ©dula del conductor
--   wunlinked_by SMALLINT â€” ID del admin que realiza la acciÃ³n. Default 1
--
-- Retorna (OUT):
--   success    BOOLEAN     â€” TRUE si se desvinculÃ³ correctamente
--   msg        TEXT        â€” Mensaje descriptivo del resultado
--   error_code VARCHAR(50) â€” NULL si success = TRUE
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-31
-- =============================================

DROP FUNCTION IF EXISTS fun_unlink_driver_account(BIGINT, SMALLINT);

CREATE OR REPLACE FUNCTION fun_unlink_driver_account(
  wid_driver    tab_drivers.id_driver%TYPE,
  wunlinked_by  tab_users.id_user%TYPE  DEFAULT 1,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_user  tab_users.id_user%TYPE;
BEGIN
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- Obtener el id_user vinculado al conductor
  SELECT id_user INTO v_id_user
  FROM tab_driver_accounts
  WHERE id_driver = wid_driver;

  IF v_id_user IS NULL THEN
    msg        := 'El conductor no tiene una cuenta vinculada';
    error_code := 'ACCOUNT_NOT_FOUND';
    RETURN;
  END IF;

  -- 1. Eliminar rol Conductor de tab_user_roles (hard delete)
  -- Hard delete para que el rol pueda reasignarse limpiamente en el futuro
  DELETE FROM tab_user_roles
  WHERE id_user = v_id_user
    AND id_role = 3;

  -- 2. Desactivar usuario en tab_users solo si no tiene otros roles activos
  IF NOT EXISTS (
    SELECT 1 FROM tab_user_roles
    WHERE id_user  = v_id_user
      AND id_role  <> 3
      AND is_active = TRUE
  ) THEN
    UPDATE tab_users
    SET is_active = FALSE
    WHERE id_user = v_id_user;
  END IF;

  -- 3. Eliminar vÃ­nculo de tab_driver_accounts
  DELETE FROM tab_driver_accounts
  WHERE id_driver = wid_driver;

  success := TRUE;
  msg     := 'Cuenta desvinculada exitosamente (usuario ID: ' || v_id_user || ')';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'No se puede desvincular: restricciÃ³n de integridad referencial: ' || SQLERRM;
    error_code := 'ACCOUNT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ACCOUNT_UNLINK_ERROR';
END;
$$;


-- =============================================
-- FUNCTION: fun_update_arl_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_arl v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza el nombre de un registro en tab_arl.
--   Normaliza el nombre (TRIM + mayÃºscula inicial).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wid_arl       SMALLINT     â€” ID de la ARL a actualizar
--   wname_arl     VARCHAR(60)  â€” Nuevo nombre de la ARL
--
-- Retorna (OUT):
--   success      BOOLEAN      â€” TRUE si se actualizÃ³ correctamente
--   msg          TEXT         â€” Mensaje descriptivo
--   error_code   VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_arl   SMALLINT     â€” ID actualizado (NULL si falla)
--   out_name     VARCHAR(60)  â€” Nombre actualizado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_arl(SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_arl(
  wid_arl       tab_arl.id_arl%TYPE,
  wname_arl     tab_arl.name_arl%TYPE,

  -- ParÃ¡metros OUT
  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50),
  OUT out_id_arl tab_arl.id_arl%TYPE,
  OUT out_name      tab_arl.name_arl%TYPE,
  OUT out_is_active tab_arl.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_arl    := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_arl
  SET    name_arl = INITCAP(TRIM(wname_arl))
  WHERE  id_arl   = wid_arl
  RETURNING id_arl, name_arl, is_active
  INTO out_id_arl, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la ARL con ID: ' || wid_arl;
    error_code := 'ARL_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'ARL actualizada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una ARL con ese nombre: ' || SQLERRM;
    error_code := 'ARL_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ARL_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_arl(SMALLINT, VARCHAR) IS
'v1.0 â€” Actualiza nombre de ARL en tab_arl. Normaliza con INITCAP/TRIM. Retorna ARL_NOT_FOUND si el ID no existe. ValidaciÃ³n de negocio delegada al backend.';


-- =============================================
-- FUNCTION: fun_update_brand_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_brand v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza el nombre de un registro en tab_brands.
--   Normaliza el nombre (TRIM + mayÃºscula inicial).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wid_brand     SMALLINT     â€” ID de la marca a actualizar
--   wbrand_name   VARCHAR(50)  â€” Nuevo nombre de la marca
--
-- Retorna (OUT):
--   success        BOOLEAN     â€” TRUE si se actualizÃ³ correctamente
--   msg            TEXT        â€” Mensaje descriptivo
--   error_code     VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_brand   SMALLINT    â€” ID actualizado (NULL si falla)
--   out_name       VARCHAR(50) â€” Nombre actualizado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_brand(SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_brand(
  wid_brand     tab_brands.id_brand%TYPE,
  wbrand_name   tab_brands.brand_name%TYPE,

  -- ParÃ¡metros OUT
  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_brand tab_brands.id_brand%TYPE,
  OUT out_name      tab_brands.brand_name%TYPE,
  OUT out_is_active tab_brands.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_brand  := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_brands
  SET    brand_name = INITCAP(TRIM(wbrand_name))
  WHERE  id_brand   = wid_brand
  RETURNING id_brand, brand_name, is_active
  INTO out_id_brand, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la marca con ID: ' || wid_brand;
    error_code := 'BRAND_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Marca actualizada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una marca con ese nombre: ' || SQLERRM;
    error_code := 'BRAND_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BRAND_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_brand(SMALLINT, VARCHAR) IS
'v1.0 â€” Actualiza nombre de marca en tab_brands. Normaliza con INITCAP/TRIM. Retorna BRAND_NOT_FOUND si el ID no existe. ValidaciÃ³n de negocio delegada al backend.';


-- =============================================
-- FUNCTION: fun_update_bus_v2.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_bus v2.1
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza los datos de un bus existente en tab_buses.
--   La placa se usa como identificador de bÃºsqueda (Ã­ndice Ãºnico) pero no se modifica.
--   El id_bus (PK surrogate GENERATED ALWAYS AS IDENTITY) nunca se modifica.
--   El estado (id_status/is_active) es gestionado por funciones separadas.
--   La validaciÃ³n de negocio es responsabilidad del backend (Node.js).
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros (IN):
--   wplate_number    VARCHAR(6)   â€” Placa del bus a actualizar (identificador, no se modifica)
--   wamb_code        VARCHAR(8)   â€” CÃ³digo AMB nuevo
--   wcode_internal   VARCHAR(5)   â€” CÃ³digo interno nuevo
--   wid_company      SMALLINT     â€” ID compaÃ±Ã­a FK
--   wmodel_year      SMALLINT     â€” AÃ±o modelo
--   wcapacity_bus    SMALLINT     â€” Pasajeros
--   wcolor_bus       VARCHAR(30)  â€” Color
--   wid_owner        BIGINT       â€” CÃ©dula propietario FK
--   wuser_update     SMALLINT     â€” Usuario que realiza el cambio FK
--   wid_brand        SMALLINT     â€” ID marca FK (DEFAULT NULL)
--   wmodel_name      VARCHAR      â€” Modelo (DEFAULT 'SA')
--   wchassis_number  VARCHAR      â€” Chasis (DEFAULT 'SA')
--   wphoto_url       VARCHAR      â€” URL foto (DEFAULT NULL)
--   wgps_device_id   VARCHAR      â€” Dispositivo GPS (DEFAULT NULL)
--   wcolor_app       VARCHAR(7)   â€” Color hex para la app (DEFAULT '#CCCCCC')
--
-- Retorna (OUT):
--   success      BOOLEAN      â€” TRUE si se actualizÃ³ correctamente
--   msg          TEXT         â€” Mensaje descriptivo
--   error_code   VARCHAR(50)  â€” NULL si success = TRUE
--   out_id_bus   SMALLINT     â€” id_bus (PK) del bus actualizado
--   out_plate    VARCHAR(6)   â€” Placa del bus actualizado
--
-- CÃ³digos de error:
--   BUS_NOT_FOUND        â€” La placa no existe en tab_buses
--   BUS_UNIQUE_VIOLATION â€” AMB, cÃ³digo interno o GPS duplicado
--   BUS_CHECK_VIOLATION  â€” Constraint CHECK violado
--   BUS_FK_VIOLATION     â€” FK invÃ¡lida (compaÃ±Ã­a, propietario o usuario)
--   BUS_UPDATE_ERROR     â€” Error inesperado en el UPDATE
--
-- Campos NO actualizables por esta funciÃ³n:
--   id_bus (PK surrogate), plate_number, id_status, is_active, created_at, user_create
--
-- VersiÃ³n   : 2.1
-- Fecha     : 2026-03-15
-- =============================================

DROP FUNCTION IF EXISTS fun_update_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_update_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_update_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_bus(
  wplate_number    tab_buses.plate_number%TYPE,
  wamb_code        tab_buses.amb_code%TYPE,
  wcode_internal   tab_buses.code_internal%TYPE,
  wid_company      tab_buses.id_company%TYPE,
  wmodel_year      tab_buses.model_year%TYPE,
  wcapacity_bus    tab_buses.capacity_bus%TYPE,
  wcolor_bus       tab_buses.color_bus%TYPE,
  wid_owner        tab_buses.id_owner%TYPE,
  wuser_update     tab_buses.user_update%TYPE,
  wid_brand        SMALLINT                                      DEFAULT NULL,
  wmodel_name      tab_buses.model_name%TYPE     DEFAULT 'SA',
  wchassis_number  tab_buses.chassis_number%TYPE DEFAULT 'SA',
  wphoto_url       tab_buses.photo_url%TYPE      DEFAULT NULL,
  wgps_device_id   tab_buses.gps_device_id%TYPE  DEFAULT NULL,
  wcolor_app       tab_buses.color_app%TYPE      DEFAULT '#CCCCCC',

  OUT success      BOOLEAN,
  OUT msg          TEXT,
  OUT error_code   VARCHAR(50),
  OUT out_id_bus   tab_buses.id_bus%TYPE,
  OUT out_plate    tab_buses.plate_number%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_plate  tab_buses.plate_number%TYPE;
  v_id_bus tab_buses.id_bus%TYPE;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_bus := NULL;
  out_plate  := NULL;

  v_plate := UPPER(TRIM(wplate_number));

  UPDATE tab_buses SET
    amb_code       = NULLIF(UPPER(TRIM(wamb_code)), ''),
    code_internal  = NULLIF(TRIM(wcode_internal), ''),
    id_company     = wid_company,
    id_brand       = wid_brand,
    model_name     = COALESCE(NULLIF(TRIM(wmodel_name), ''), 'SA'),
    model_year     = wmodel_year,
    capacity_bus   = wcapacity_bus,
    chassis_number = COALESCE(NULLIF(UPPER(TRIM(wchassis_number)), ''), 'SA'),
    color_bus      = TRIM(wcolor_bus),
    color_app      = COALESCE(NULLIF(TRIM(wcolor_app), ''), '#CCCCCC'),
    photo_url      = NULLIF(TRIM(wphoto_url), ''),
    gps_device_id  = NULLIF(TRIM(wgps_device_id), ''),
    id_owner       = wid_owner,
    updated_at     = NOW(),
    user_update    = wuser_update
  WHERE plate_number = v_plate
  RETURNING id_bus INTO v_id_bus;

  IF v_id_bus IS NULL THEN
    msg        := 'Bus no encontrado con placa: ' || v_plate;
    error_code := 'BUS_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  out_id_bus := v_id_bus;
  out_plate  := v_plate;
  msg        := 'Bus actualizado exitosamente: ' || v_plate || ' (id_bus=' || v_id_bus || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'AMB, cÃ³digo interno o GPS ya registrado en otro bus: ' || SQLERRM;
    error_code := 'BUS_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'RestricciÃ³n CHECK violada: ' || SQLERRM;
    error_code := 'BUS_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'FK invÃ¡lida (compaÃ±Ã­a, propietario o usuario): ' || SQLERRM;
    error_code := 'BUS_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'BUS_UPDATE_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_update_bus(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT, SMALLINT, VARCHAR, BIGINT, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) IS
'v2.1 â€” Actualiza bus en tab_buses. Busca por plate_number (Ãºnico), retorna id_bus (PK surrogate). NormalizaciÃ³n inline en SET. ValidaciÃ³n delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar bus completo
SELECT * FROM fun_update_bus(
  'ABC123',           -- plate_number (identifica el bus, no se modifica)
  'AMB-0010',         -- amb_code nuevo
  'B001',             -- code_internal
  1,                  -- id_company
  2020,               -- model_year
  45,                 -- capacity_bus
  'Blanco y azul',    -- color_bus
  10000000,           -- id_owner
  1,                  -- wuser_update
  2,                  -- wid_brand
  'OF 1721',          -- model_name
  'CH123456789',      -- chassis_number
  NULL,               -- photo_url
  '352099001761481',  -- gps_device_id
  '#1A73E8'           -- color_app
);

-- Actualizar solo campos obligatorios (opcionales quedan en DEFAULT)
SELECT * FROM fun_update_bus(
  'ABC123',
  'SA',
  'B001',
  1,
  2020,
  45,
  'Rojo',
  10000000,
  1
);

-- Resultado exitoso:
-- success | msg                                              | error_code | out_id_bus | out_plate
-- TRUE    | Bus actualizado exitosamente: ABC123 (id_bus=3)  | NULL       | 3          | ABC123

-- Error: bus no encontrado
-- success | msg                                | error_code    | out_id_bus | out_plate
-- FALSE   | Bus no encontrado con placa: ZZZ999 | BUS_NOT_FOUND | NULL       | NULL

-- Error: AMB ya registrado en otro bus (UNIQUE constraint)
-- success | msg                                          | error_code           | out_id_bus | out_plate
-- FALSE   | AMB, cÃ³digo interno o GPS ya registrado...   | BUS_UNIQUE_VIOLATION | NULL       | NULL

*/
-- 

-- =============================================
-- FUNCTION: fun_update_company_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_company v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza el nombre de una compaÃ±Ã­a en tab_companies.
--   El NIT (nit_company) es inmutable desde la app;
--   cualquier correcciÃ³n de NIT debe hacerse por DBA.
--   Normaliza el nombre (TRIM + INITCAP).
--   Registra auditorÃ­a: user_update + updated_at.
--
-- ParÃ¡metros (IN):
--   wid_company    SMALLINT     â€” ID de la compaÃ±Ã­a a actualizar
--   wcompany_name  VARCHAR(100) â€” Nuevo nombre de la compaÃ±Ã­a
--   wuser_update   SMALLINT     â€” ID del usuario que realiza el cambio
--
-- Retorna (OUT):
--   success          BOOLEAN      â€” TRUE si se actualizÃ³ correctamente
--   msg              TEXT         â€” Mensaje descriptivo
--   error_code       VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_company   SMALLINT     â€” ID actualizado (NULL si falla)
--   out_company_name VARCHAR(100) â€” Nombre actualizado (NULL si falla)
--   out_nit_company  VARCHAR(15)  â€” NIT actual (NULL si falla)
--   out_is_active    BOOLEAN      â€” Estado actual (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_company(SMALLINT, VARCHAR, SMALLINT);

CREATE OR REPLACE FUNCTION fun_update_company(
  wid_company    tab_companies.id_company%TYPE,
  wcompany_name  tab_companies.company_name%TYPE,
  wuser_update   tab_companies.user_update%TYPE,

  -- ParÃ¡metros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_company   tab_companies.id_company%TYPE,
  OUT out_company_name tab_companies.company_name%TYPE,
  OUT out_nit_company  tab_companies.nit_company%TYPE,
  OUT out_is_active    tab_companies.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success          := FALSE;
  msg              := '';
  error_code       := NULL;
  out_id_company   := NULL;
  out_company_name := NULL;
  out_nit_company  := NULL;
  out_is_active    := NULL;

  UPDATE tab_companies
  SET
    company_name = INITCAP(TRIM(wcompany_name)),
    updated_at   = NOW(),
    user_update  = wuser_update
  WHERE id_company = wid_company
  RETURNING id_company, company_name, nit_company, is_active
  INTO out_id_company, out_company_name, out_nit_company, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la compaÃ±Ã­a con ID: ' || wid_company;
    error_code := 'COMPANY_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'CompaÃ±Ã­a actualizada exitosamente: ' || out_company_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una compaÃ±Ã­a con ese nombre: ' || SQLERRM;
    error_code := 'COMPANY_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Usuario actualizador no vÃ¡lido: ' || SQLERRM;
    error_code := 'COMPANY_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'COMPANY_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_company(SMALLINT, VARCHAR, SMALLINT) IS
'v1.0 â€” Actualiza company_name en tab_companies. NIT es inmutable. Registra user_update y updated_at. Retorna COMPANY_NOT_FOUND si el ID no existe.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar nombre
SELECT * FROM fun_update_company(1, 'MetrolÃ­nea SAS', 1);

-- Resultado exitoso:
-- success | msg                                   | error_code | out_id_company | out_company_name | out_nit_company | out_is_active
-- --------+---------------------------------------+------------+----------------+------------------+-----------------+--------------
-- true    | CompaÃ±Ã­a actualizada exitosamente: .. | NULL       | 1              | MetrolÃ­nea Sas   | 9001234561      | true

-- ID no existe â†’ 404 en backend:
SELECT * FROM fun_update_company(99, 'Empresa X', 1);
-- success=false, error_code='COMPANY_NOT_FOUND'

-- Nombre duplicado â†’ 409 en backend:
SELECT * FROM fun_update_company(2, 'MetrolÃ­nea Sas', 1);
-- success=false, error_code='COMPANY_UNIQUE_VIOLATION'

*/


-- =============================================
-- FUNCTION: fun_update_driver_v2.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_driver v2.1
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza los datos de un conductor existente en tab_drivers.
--   La cÃ©dula (id_driver / PK) es inmutable: identifica al conductor
--   pero no se modifica.
--   El estado (id_status / is_active) solo puede cambiarse con esta
--   funciÃ³n a travÃ©s del parÃ¡metro wid_status; la activaciÃ³n/desactivaciÃ³n
--   lÃ³gica (is_active) debe gestionarse con una funciÃ³n dedicada.
--   La validaciÃ³n de negocio es responsabilidad del backend (Node.js).
--   Los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros obligatorios (IN):
--   wid_driver         BIGINT       â€” CÃ©dula del conductor a actualizar (PK, no se modifica)
--   wuser_update       SMALLINT     â€” Usuario que realiza el cambio FK
--
-- ParÃ¡metros opcionales (IN / con DEFAULT):
--   wname_driver       VARCHAR(100) â€” Nombre completo              (DEFAULT 'SIN NOMBRE')
--   waddress_driver    VARCHAR(200) â€” DirecciÃ³n                    (DEFAULT 'SIN DIRECCIÃ“N')
--   wphone_driver      VARCHAR(15)  â€” TelÃ©fono                     (DEFAULT '0900000000')
--   wemail_driver      VARCHAR(320) â€” Email                        (DEFAULT 'sa@sa.com')
--   wbirth_date        DATE         â€” Fecha de nacimiento          (DEFAULT '2000-01-01')
--   wlicense_cat       VARCHAR(2)   â€” CategorÃ­a licencia           (DEFAULT 'SA')
--   wlicense_exp       DATE         â€” Vencimiento licencia         (DEFAULT '2000-01-01')
--   wid_eps            SMALLINT     â€” EPS FK                       (DEFAULT 1)
--   wid_arl            SMALLINT     â€” ARL FK                       (DEFAULT 1)
--   wblood_type        VARCHAR(3)   â€” Tipo de sangre               (DEFAULT 'SA')
--   wemergency_contact VARCHAR(100) â€” Contacto emergencia          (DEFAULT 'SIN CONTACTO')
--   wemergency_phone   VARCHAR(15)  â€” TelÃ©fono emergencia          (DEFAULT '0900000000')
--   wdate_entry        DATE         â€” Fecha de ingreso             (DEFAULT CURRENT_DATE)
--   wid_status         SMALLINT     â€” Estado operativo FK          (DEFAULT 1)
--
-- Retorna (OUT):
--   success      BOOLEAN      â€” TRUE si se actualizÃ³ correctamente
--   msg          TEXT         â€” Mensaje descriptivo
--   error_code   VARCHAR(50)  â€” NULL si success = TRUE
--   out_driver   BIGINT       â€” CÃ©dula del conductor actualizado
--
-- CÃ³digos de error:
--   DRIVER_NOT_FOUND        â€” La cÃ©dula no existe en tab_drivers
--   DRIVER_UNIQUE_VIOLATION â€” Email duplicado en otro conductor
--   DRIVER_CHECK_VIOLATION  â€” Constraint CHECK violado (licencia, sangre, telÃ©fono, etc.)
--   DRIVER_FK_VIOLATION     â€” FK invÃ¡lida (eps, arl, status)
--   DRIVER_UPDATE_ERROR     â€” Error inesperado en el UPDATE
--
-- Campos NO actualizables por esta funciÃ³n:
--   id_driver (PK inmutable), is_active, created_at, user_create
--
-- VersiÃ³n   : 2.1  â€” Elimina wid_user (vÃ­nculo movido a tab_driver_accounts)
-- Fecha     : 2026-03-17
-- =============================================

DROP FUNCTION IF EXISTS fun_update_driver(BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_update_driver(BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT);

CREATE OR REPLACE FUNCTION fun_update_driver(
  -- wid_driver y wuser_update primero (identificador + auditorÃ­a requerida)
  -- resto en el mismo orden que las columnas de tab_drivers
  wid_driver          tab_drivers.id_driver%TYPE,
  wuser_update        tab_drivers.user_update%TYPE,
  wname_driver        tab_drivers.name_driver%TYPE       DEFAULT 'SIN NOMBRE',
  waddress_driver     tab_drivers.address_driver%TYPE    DEFAULT 'SIN DIRECCIÃ“N',
  wphone_driver       tab_drivers.phone_driver%TYPE      DEFAULT '0900000000',
  wemail_driver       tab_drivers.email_driver%TYPE      DEFAULT 'sa@sa.com',
  wbirth_date         tab_drivers.birth_date%TYPE        DEFAULT '2000-01-01',
  wgender_driver      tab_drivers.gender_driver%TYPE     DEFAULT 'O',
  wlicense_cat        tab_drivers.license_cat%TYPE       DEFAULT 'SA',
  wlicense_exp        tab_drivers.license_exp%TYPE       DEFAULT '2000-01-01',
  wid_eps             tab_drivers.id_eps%TYPE             DEFAULT 1,
  wid_arl             tab_drivers.id_arl%TYPE             DEFAULT 1,
  wblood_type         tab_drivers.blood_type%TYPE         DEFAULT 'SA',
  wemergency_contact  tab_drivers.emergency_contact%TYPE  DEFAULT 'SIN CONTACTO',
  wemergency_phone    tab_drivers.emergency_phone%TYPE    DEFAULT '0900000000',
  wdate_entry         tab_drivers.date_entry%TYPE         DEFAULT CURRENT_DATE,
  wid_status          tab_drivers.id_status%TYPE          DEFAULT 1,

  OUT success         BOOLEAN,
  OUT msg             TEXT,
  OUT error_code      VARCHAR(50),
  OUT out_driver      tab_drivers.id_driver%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_driver := NULL;

  UPDATE tab_drivers SET
    name_driver       = COALESCE(NULLIF(TRIM(wname_driver),            ''), 'SIN NOMBRE'),
    address_driver    = COALESCE(NULLIF(TRIM(waddress_driver),         ''), 'SIN DIRECCIÃ“N'),
    phone_driver      = COALESCE(NULLIF(TRIM(wphone_driver),           ''), '0900000000'),
    email_driver      = COALESCE(NULLIF(LOWER(TRIM(wemail_driver)),    ''), 'sa@sa.com'),
    birth_date        = COALESCE(wbirth_date,                              '2000-01-01'),
    gender_driver     = COALESCE(NULLIF(UPPER(TRIM(wgender_driver)),          ''), 'O'),
    license_cat       = COALESCE(NULLIF(TRIM(wlicense_cat),            ''), 'SA'),
    license_exp       = COALESCE(wlicense_exp,                             '2000-01-01'),
    id_eps            = wid_eps,
    id_arl            = wid_arl,
    blood_type        = COALESCE(NULLIF(TRIM(wblood_type),          ''), 'SA'),
    emergency_contact = COALESCE(NULLIF(TRIM(wemergency_contact),      ''), 'SIN CONTACTO'),
    emergency_phone   = COALESCE(NULLIF(TRIM(wemergency_phone),        ''), '0900000000'),
    date_entry        = COALESCE(wdate_entry,                              CURRENT_DATE),
    id_status         = wid_status,
    updated_at        = NOW(),
    user_update       = wuser_update
  WHERE id_driver = wid_driver;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'Conductor no encontrado con cÃ©dula: ' || wid_driver;
    error_code := 'DRIVER_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  out_driver := wid_driver;
  msg        := 'Conductor actualizado exitosamente (CÃ©dula: ' || wid_driver || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Email ya registrado en otro conductor: ' || SQLERRM;
    error_code := 'DRIVER_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'RestricciÃ³n CHECK violada: ' || SQLERRM;
    error_code := 'DRIVER_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave forÃ¡nea invÃ¡lida (eps, arl o status): ' || SQLERRM;
    error_code := 'DRIVER_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'DRIVER_UPDATE_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_update_driver(BIGINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, DATE, SMALLINT, SMALLINT, VARCHAR, VARCHAR, VARCHAR, DATE, SMALLINT) IS
'v2.1 â€” Actualiza conductor en tab_drivers. Eliminado wid_user (vÃ­nculo con tab_users movido a tab_driver_accounts). NormalizaciÃ³n inline en SET. ValidaciÃ³n delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar conductor completo
SELECT * FROM fun_update_driver(
  1015432876,          -- id_driver (cÃ©dula, no se modifica)
  1,                   -- user_update
  'Carlos A. PÃ©rez',   -- name_driver
  'Calle 50 # 30-20',  -- address_driver
  '3011234567',        -- phone_driver
  'carlos@nuevo.com',  -- email_driver
  '1990-05-15'::DATE,  -- birth_date
  'C2',                -- license_cat
  '2028-12-31'::DATE,  -- license_exp
  2,                   -- id_eps
  1,                   -- id_arl
  'O+',                -- blood_type
  'Ana PÃ©rez',         -- emergency_contact
  '3119876543',        -- emergency_phone
  '2024-01-15'::DATE,  -- date_entry
  1                    -- id_status
);
-- Para cambiar el vÃ­nculo con tab_users, usar tab_driver_accounts:
-- UPDATE tab_driver_accounts SET id_user = <nuevo_id_user> WHERE id_driver = 1015432876;

-- Actualizar solo campos obligatorios (opcionales quedan en DEFAULT)
SELECT * FROM fun_update_driver(
  1015432876,
  1
);

-- Resultado exitoso:
-- success | msg                                                    | error_code | out_driver
-- TRUE    | Conductor actualizado exitosamente (CÃ©dula: 1015432876) | NULL       | 1015432876

-- Error: conductor no encontrado
-- success | msg                                          | error_code       | out_driver
-- FALSE   | Conductor no encontrado con cÃ©dula: 9999999  | DRIVER_NOT_FOUND | NULL

-- Error: email duplicado en otro conductor
-- success | msg                                                  | error_code              | out_driver
-- FALSE   | Email o usuario de sistema ya registrado en otro...   | DRIVER_UNIQUE_VIOLATION | NULL

-- Error: categorÃ­a de licencia invÃ¡lida
-- success | msg                                  | error_code              | out_driver
-- FALSE   | RestricciÃ³n CHECK violada: ...detail... | DRIVER_CHECK_VIOLATION | NULL

*/


-- =============================================
-- FUNCTION: fun_update_eps_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_eps v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza el nombre de un registro en tab_eps.
--   Normaliza el nombre (TRIM + mayÃºscula inicial).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wid_eps       SMALLINT     â€” ID de la EPS a actualizar
--   wname_eps     VARCHAR(60)  â€” Nuevo nombre de la EPS
--
-- Retorna (OUT):
--   success      BOOLEAN      â€” TRUE si se actualizÃ³ correctamente
--   msg          TEXT         â€” Mensaje descriptivo
--   error_code   VARCHAR(50)  â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_eps   SMALLINT     â€” ID actualizado (NULL si falla)
--   out_name     VARCHAR(60)  â€” Nombre actualizado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_eps(SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_eps(
  wid_eps       tab_eps.id_eps%TYPE,
  wname_eps     tab_eps.name_eps%TYPE,

  -- ParÃ¡metros OUT
  OUT success    BOOLEAN,
  OUT msg        TEXT,
  OUT error_code VARCHAR(50),
  OUT out_id_eps tab_eps.id_eps%TYPE,
  OUT out_name      tab_eps.name_eps%TYPE,
  OUT out_is_active tab_eps.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success       := FALSE;
  msg           := '';
  error_code    := NULL;
  out_id_eps    := NULL;
  out_name      := NULL;
  out_is_active := NULL;

  UPDATE tab_eps
  SET    name_eps = INITCAP(TRIM(wname_eps))
  WHERE  id_eps   = wid_eps
  RETURNING id_eps, name_eps, is_active
  INTO out_id_eps, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la EPS con ID: ' || wid_eps;
    error_code := 'EPS_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'EPS actualizada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una EPS con ese nombre: ' || SQLERRM;
    error_code := 'EPS_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'EPS_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_eps(SMALLINT, VARCHAR) IS
'v1.0 â€” Actualiza nombre de EPS en tab_eps. Normaliza con INITCAP/TRIM. Retorna EPS_NOT_FOUND si el ID no existe. ValidaciÃ³n de negocio delegada al backend.';


-- =============================================
-- FUNCTION: fun_update_incident_type_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_incident_type v1.0
-- Directorio: functions_v2
-- =============================================
DROP FUNCTION IF EXISTS fun_update_incident_type(SMALLINT, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_incident_type(
  wid_incident   tab_incident_types.id_incident%TYPE,
  wname_incident tab_incident_types.name_incident%TYPE,
  wtag_incident  tab_incident_types.tag_incident%TYPE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_type   tab_incident_types.id_incident%TYPE,
  OUT out_name      tab_incident_types.name_incident%TYPE,
  OUT out_tag       tab_incident_types.tag_incident%TYPE,
  OUT out_is_active tab_incident_types.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_updated INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  out_id_type := NULL;
  out_name   := NULL;
  out_tag    := NULL;
  out_is_active := NULL;

  UPDATE tab_incident_types
  SET 
    name_incident = INITCAP(TRIM(wname_incident)),
    tag_incident  = LOWER(TRIM(wtag_incident))
  WHERE id_incident = wid_incident
  RETURNING id_incident, name_incident, tag_incident, is_active
  INTO out_id_type, out_name, out_tag, out_is_active;

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    msg        := 'Tipo de incidente no encontrado (ID: ' || wid_incident || ')';
    error_code := 'INCIDENT_TYPE_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Tipo de incidente actualizado exitosamente a: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe un incidente con ese nombre o tag: ' || SQLERRM;
    error_code := 'INCIDENT_TYPE_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INCIDENT_TYPE_UPDATE_ERROR';
END;
$$;


-- =============================================
-- FUNCTION: fun_update_insurance_type.sql
-- =============================================

-- ==========================================
-- ACTUALIZAR TIPO DE SEGURO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_update_insurance_type(
    p_id_type tab_insurance_types.id_insurance_type%TYPE,
    p_tag tab_insurance_types.tag_insurance%TYPE,
    p_name tab_insurance_types.name_insurance%TYPE,
    p_descrip tab_insurance_types.descrip_insurance%TYPE,
    p_mandatory tab_insurance_types.is_mandatory%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_type tab_insurance_types.id_insurance_type%TYPE,
    out_name tab_insurance_types.name_insurance%TYPE,
    out_is_active tab_insurance_types.is_active%TYPE
) AS $$
DECLARE
    v_active BOOLEAN;
BEGIN
    UPDATE tab_insurance_types
    SET tag_insurance = p_tag,
        name_insurance = p_name,
        descrip_insurance = p_descrip,
        is_mandatory = p_mandatory
    WHERE id_insurance_type = p_id_type
    RETURNING is_active INTO v_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de seguro no encontrado.'::TEXT, 'INSURANCE_TYPE_NOT_FOUND'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Tipo de seguro actualizado correctamente.'::TEXT, NULL::VARCHAR, p_id_type, p_name, v_active;
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un tipo de seguro con este nombre o tag.'::TEXT, 'INSURANCE_TYPE_UNIQUE_VIOLATION'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- FUNCTION: fun_update_insurer_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_insurer v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza el nombre de un registro en tab_insurers.
--   Normaliza el nombre (TRIM + mayÃºscula inicial).
--   La validaciÃ³n de negocio es responsabilidad
--   del backend (Node.js); los constraints de la
--   BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wid_insurer     SMALLINT     â€” ID de la aseguradora a actualizar
--   winsurer_name   VARCHAR(100) â€” Nuevo nombre de la aseguradora
--
-- Retorna (OUT):
--   success          BOOLEAN     â€” TRUE si se actualizÃ³ correctamente
--   msg              TEXT        â€” Mensaje descriptivo
--   error_code       VARCHAR(50) â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_insurer   SMALLINT    â€” ID actualizado (NULL si falla)
--   out_name         VARCHAR(100)â€” Nombre actualizado (NULL si falla)
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-30
-- =============================================

DROP FUNCTION IF EXISTS fun_update_insurer(SMALLINT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_insurer(
  wid_insurer     tab_insurers.id_insurer%TYPE,
  winsurer_name   tab_insurers.insurer_name%TYPE,

  -- ParÃ¡metros OUT
  OUT success          BOOLEAN,
  OUT msg              TEXT,
  OUT error_code       VARCHAR(50),
  OUT out_id_insurer   tab_insurers.id_insurer%TYPE,
  OUT out_name         tab_insurers.insurer_name%TYPE,
  OUT out_is_active    tab_insurers.is_active%TYPE
)
LANGUAGE plpgsql
AS $$
BEGIN

  success        := FALSE;
  msg            := '';
  error_code     := NULL;
  out_id_insurer := NULL;
  out_name       := NULL;
  out_is_active  := NULL;

  UPDATE tab_insurers
  SET    insurer_name = INITCAP(TRIM(winsurer_name))
  WHERE  id_insurer   = wid_insurer
  RETURNING id_insurer, insurer_name, is_active
  INTO out_id_insurer, out_name, out_is_active;

  IF NOT FOUND THEN
    msg        := 'No se encontrÃ³ la aseguradora con ID: ' || wid_insurer;
    error_code := 'INSURER_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Aseguradora actualizada exitosamente: ' || out_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una aseguradora con ese nombre: ' || SQLERRM;
    error_code := 'INSURER_UNIQUE_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'INSURER_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_insurer(SMALLINT, VARCHAR) IS
'v1.0 â€” Actualiza nombre de aseguradora en tab_insurers. Normaliza con INITCAP/TRIM. Retorna INSURER_NOT_FOUND si el ID no existe. ValidaciÃ³n de negocio delegada al backend.';


-- =============================================
-- FUNCTION: fun_update_route_point_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_route_point v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza los datos de un punto de ruta existente en tab_route_points.
--   El id_point se usa como identificador (PK) y nunca se modifica.
--   La validaciÃ³n de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   los constraints de la BD actÃºan como Ãºltima lÃ­nea de defensa.
--
-- ParÃ¡metros (IN):
--   wid_point      tab_route_points.id_point%TYPE      â€” ID del punto a actualizar
--   wname_point    tab_route_points.name_point%TYPE     â€” Nuevo nombre
--   wlat           DOUBLE PRECISION                     â€” Nueva latitud  (WGS-84)
--   wlng           DOUBLE PRECISION                     â€” Nueva longitud (WGS-84)
--   wpoint_type    tab_route_points.point_type%TYPE     â€” Tipo: 1=Parada, 2=Referencia
--   wdescrip_point tab_route_points.descrip_point%TYPE  â€” Nueva descripciÃ³n (DEFAULT NULL)
--   wis_checkpoint tab_route_points.is_checkpoint%TYPE  â€” Punto de control (DEFAULT FALSE)
--   wuser_update   tab_route_points.user_update%TYPE    â€” Usuario que realiza el cambio
--
-- Retorna (OUT):
--   success        BOOLEAN                              â€” TRUE si se actualizÃ³ correctamente
--   msg            TEXT                                 â€” Mensaje descriptivo
--   error_code     VARCHAR(50)                          â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_point   tab_route_points.id_point%TYPE       â€” ID del punto actualizado (NULL si falla)
--
-- CÃ³digos de error:
--   ROUTE_POINT_NOT_FOUND        â€” El id_point no existe en tab_route_points
--   ROUTE_POINT_CHECK_VIOLATION  â€” point_type fuera de rango (1 o 2)
--   ROUTE_POINT_FK_VIOLATION     â€” FK de user_update invÃ¡lida
--   ROUTE_POINT_UPDATE_ERROR     â€” Error inesperado en el UPDATE
--
-- Campos NO actualizables por esta funciÃ³n:
--   id_point (PK), is_active, created_at, user_create
--
-- VersiÃ³n   : 1.0
-- Fecha     : 2026-03-16
-- =============================================

DROP FUNCTION IF EXISTS fun_update_route_point(SMALLINT, VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, SMALLINT, TEXT, BOOLEAN, SMALLINT);

CREATE OR REPLACE FUNCTION fun_update_route_point(
  wid_point       tab_route_points.id_point%TYPE,
  wname_point     tab_route_points.name_point%TYPE,
  wlat            DOUBLE PRECISION,                            -- Latitud (sin columna directa en tab; almacena GEOMETRY)
  wlng            DOUBLE PRECISION,                            -- Longitud (Ã­dem)
  wpoint_type     tab_route_points.point_type%TYPE,
  wdescrip_point  tab_route_points.descrip_point%TYPE  DEFAULT NULL,
  wis_checkpoint  tab_route_points.is_checkpoint%TYPE  DEFAULT FALSE,
  wuser_update    tab_route_points.user_update%TYPE     DEFAULT 1,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_point  tab_route_points.id_point%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_point  tab_route_points.id_point%TYPE;
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_point := NULL;

  UPDATE tab_route_points SET
    name_point     = TRIM(wname_point),
    location_point = ST_SetSRID(ST_MakePoint(wlng, wlat), 4326),  -- PostGIS: MakePoint(lon, lat)
    point_type     = wpoint_type,
    descrip_point  = NULLIF(TRIM(wdescrip_point), ''),
    is_checkpoint  = wis_checkpoint,
    updated_at     = NOW(),
    user_update    = wuser_update
  WHERE id_point = wid_point
  RETURNING id_point INTO v_id_point;

  IF v_id_point IS NULL THEN
    msg        := 'Punto de ruta no encontrado (ID: ' || wid_point || ')';
    error_code := 'ROUTE_POINT_NOT_FOUND';
    RETURN;
  END IF;

  out_id_point := v_id_point;
  success      := TRUE;
  msg          := 'Punto de ruta actualizado exitosamente (ID: ' || out_id_point || ')';

EXCEPTION
  WHEN check_violation THEN
    msg        := 'Tipo de punto invÃ¡lido (point_type debe ser 1 o 2): ' || SQLERRM;
    error_code := 'ROUTE_POINT_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave forÃ¡nea invÃ¡lida (user_update): ' || SQLERRM;
    error_code := 'ROUTE_POINT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_POINT_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_route_point(SMALLINT, VARCHAR, DOUBLE PRECISION, DOUBLE PRECISION, SMALLINT, TEXT, BOOLEAN, SMALLINT) IS
'v1.0 â€” Actualiza un punto de ruta en tab_route_points identificado por id_point. Usa RETURNING para detectar NOT FOUND. No modifica id_point, is_active, created_at ni user_create.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar nombre y coordenadas del punto ID=1
SELECT * FROM fun_update_route_point(
  1,                                               -- id_point
  'Terminal del Norte (actualizado)',              -- name_point
  7.1250,                                          -- lat
  -73.1130,                                        -- lng
  1,                                               -- point_type = Parada
  'DescripciÃ³n actualizada',                       -- descrip_point
  TRUE,                                            -- is_checkpoint
  2                                                -- user_update
);

-- Resultado exitoso:
-- success | msg                                         | error_code | out_id_point
-- TRUE    | Punto de ruta actualizado exitosamente (ID:1) | NULL     | 1

-- Error: ID no existe
-- success | msg                                      | error_code               | out_id_point
-- FALSE   | Punto de ruta no encontrado (ID: 99)    | ROUTE_POINT_NOT_FOUND    | NULL

-- Error: point_type = 5
-- success | msg                                      | error_code                  | out_id_point
-- FALSE   | Tipo de punto invÃ¡lido (point_type ...)  | ROUTE_POINT_CHECK_VIOLATION | NULL

*/


-- =============================================
-- FUNCTION: fun_update_route_v1.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_route v1.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza los metadatos de una ruta existente en tab_routes.
--   El id_route es el identificador (PK) y nunca se modifica.
--   path_route NO es actualizable por esta funciÃ³n:
--     un cambio de trayecto implica crear una nueva ruta y desactivar la anterior.
--   La validaciÃ³n de formato es responsabilidad del frontend;
--   las reglas de negocio, del backend (Node.js);
--   los constraints de la BD actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros (IN):
--   wid_route             tab_routes.id_route%TYPE              â€” ID de la ruta a actualizar
--   wname_route           tab_routes.name_route%TYPE            â€” Nuevo nombre
--   wcolor_route          tab_routes.color_route%TYPE           â€” Color hex (#RRGGBB)
--   wid_company           tab_routes.id_company%TYPE            â€” FK a tab_companies
--   wuser_update          tab_routes.user_update%TYPE           â€” Usuario que realiza el cambio
--   wdescrip_route        tab_routes.descrip_route%TYPE         DEFAULT NULL
--   wfirst_trip           tab_routes.first_trip%TYPE            DEFAULT NULL
--   wlast_trip            tab_routes.last_trip%TYPE             DEFAULT NULL
--   wdeparture_route_sign tab_routes.departure_route_sign%TYPE  DEFAULT NULL
--   wreturn_route_sign    tab_routes.return_route_sign%TYPE     DEFAULT NULL
--
-- Retorna (OUT):
--   success       BOOLEAN                    â€” TRUE si se actualizÃ³ correctamente
--   msg           TEXT                       â€” Mensaje descriptivo
--   error_code    VARCHAR(50)                â€” NULL si Ã©xito; cÃ³digo si falla
--   out_id_route  tab_routes.id_route%TYPE   â€” ID de la ruta actualizada (NULL si falla)
--
-- CÃ³digos de error:
--   ROUTE_NOT_FOUND       â€” El id_route no existe en tab_routes
--   ROUTE_FK_VIOLATION    â€” FK invÃ¡lida (compaÃ±Ã­a o usuario no existe)
--   ROUTE_CHECK_VIOLATION â€” color invÃ¡lido o first_trip >= last_trip
--   ROUTE_UPDATE_ERROR    â€” Error inesperado
--
-- Campos NO actualizables por esta funciÃ³n:
--   id_route (PK), path_route, is_active, created_at, user_create
--
-- VersiÃ³n   : 1.3
-- Fecha     : 2026-04-17
-- =============================================

DROP FUNCTION IF EXISTS fun_update_route(SMALLINT, VARCHAR, VARCHAR, SMALLINT, SMALLINT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN);

CREATE OR REPLACE FUNCTION fun_update_route(
  wid_route              tab_routes.id_route%TYPE,
  wname_route            tab_routes.name_route%TYPE,
  wcolor_route           tab_routes.color_route%TYPE,
  wid_company            tab_routes.id_company%TYPE,
  wuser_update           tab_routes.user_update%TYPE,
  wdescrip_route         tab_routes.descrip_route%TYPE         DEFAULT NULL,
  wfirst_trip            tab_routes.first_trip%TYPE            DEFAULT NULL,
  wlast_trip             tab_routes.last_trip%TYPE             DEFAULT NULL,
  wdeparture_route_sign  tab_routes.departure_route_sign%TYPE  DEFAULT NULL,
  wreturn_route_sign     tab_routes.return_route_sign%TYPE     DEFAULT NULL,
  wroute_fare            tab_routes.route_fare%TYPE            DEFAULT 0,
  wis_circular           BOOLEAN                               DEFAULT TRUE,

  -- ParÃ¡metros OUT
  OUT success       BOOLEAN,
  OUT msg           TEXT,
  OUT error_code    VARCHAR(50),
  OUT out_id_route  tab_routes.id_route%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_route  tab_routes.id_route%TYPE;
BEGIN

  success      := FALSE;
  msg          := '';
  error_code   := NULL;
  out_id_route := NULL;

  UPDATE tab_routes SET
    name_route            = TRIM(wname_route),
    color_route           = UPPER(TRIM(wcolor_route)),
    id_company            = wid_company,
    descrip_route         = NULLIF(TRIM(wdescrip_route), ''),
    first_trip            = wfirst_trip,
    last_trip             = wlast_trip,
    departure_route_sign  = NULLIF(TRIM(wdeparture_route_sign), ''),
    return_route_sign     = NULLIF(TRIM(wreturn_route_sign), ''),
    route_fare            = GREATEST(wroute_fare, 0),
    is_circular           = COALESCE(wis_circular, FALSE),
    updated_at            = NOW(),
    user_update           = wuser_update
  WHERE id_route = wid_route
  RETURNING id_route INTO v_id_route;

  IF v_id_route IS NULL THEN
    msg        := 'Ruta no encontrada (ID: ' || wid_route || ')';
    error_code := 'ROUTE_NOT_FOUND';
    RETURN;
  END IF;

  out_id_route := v_id_route;
  success      := TRUE;
  msg          := 'Ruta (ID: ' || out_id_route || ') actualizada exitosamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'CompaÃ±Ã­a o usuario no existe: ' || SQLERRM;
    error_code := 'ROUTE_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Valor fuera de rango (color invÃ¡lido o first_trip >= last_trip): ' || SQLERRM;
    error_code := 'ROUTE_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_UPDATE_ERROR';
END;
$$;

-- =============================================
-- COMENTARIO
-- =============================================
COMMENT ON FUNCTION fun_update_route(SMALLINT, VARCHAR, VARCHAR, SMALLINT, SMALLINT, TEXT, TIME, TIME, VARCHAR, VARCHAR, SMALLINT, BOOLEAN) IS
'v1.2 â€” Actualiza los metadatos de una ruta (tab_routes), incluyendo route_fare (tarifa) e is_circular (circuito cerrado). path_route es inmutable.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar nombre y color
SELECT * FROM fun_update_route(
  1,                        -- id_route
  'Ruta 18 - Cabecera v2',  -- name_route
  '#764ba2',                -- color_route
  1,                        -- id_company
  2,                        -- user_update
  'DescripciÃ³n actualizada',
  '05:00:00',
  '23:00:00',
  'CABECERA â†’ CENTRO',
  'CENTRO â†’ CABECERA'
);
-- success | msg                                | error_code | out_id_route
-- TRUE    | Ruta (ID: 1) actualizada exitosamente | NULL    | 1

-- Error: ID no existe
-- success | msg                         | error_code      | out_id_route
-- FALSE   | Ruta no encontrada (ID: 99) | ROUTE_NOT_FOUND | NULL

*/


-- =============================================
-- FUNCTION: fun_update_transit_doc_type.sql
-- =============================================

-- ==========================================
-- ACTUALIZAR TIPO DE DOCUMENTO DE TRANSITO
-- ==========================================
CREATE OR REPLACE FUNCTION fun_update_transit_doc_type(
    p_id_doc tab_transit_documents.id_doc%TYPE,
    p_tag tab_transit_documents.tag_transit_doc%TYPE,
    p_name tab_transit_documents.name_doc%TYPE,
    p_descrip tab_transit_documents.descrip_doc%TYPE,
    p_mandatory tab_transit_documents.is_mandatory%TYPE,
    p_has_expiration tab_transit_documents.has_expiration%TYPE
)
RETURNS TABLE (
    success BOOLEAN,
    msg TEXT,
    error_code VARCHAR,
    out_id_doc tab_transit_documents.id_doc%TYPE,
    out_name tab_transit_documents.name_doc%TYPE,
    out_is_active tab_transit_documents.is_active%TYPE
) AS $$
DECLARE
    v_active BOOLEAN;
BEGIN
    UPDATE tab_transit_documents
    SET tag_transit_doc = p_tag,
        name_doc = p_name,
        descrip_doc = p_descrip,
        is_mandatory = p_mandatory,
        has_expiration = p_has_expiration
    WHERE id_doc = p_id_doc
    RETURNING is_active INTO v_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de documento no encontrado.'::TEXT, 'TRANSIT_DOC_NOT_FOUND'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Tipo de documento actualizado correctamente.'::TEXT, NULL::VARCHAR, p_id_doc, p_name, v_active;
    END IF;
EXCEPTION
    WHEN unique_violation THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un tipo de documento con este nombre o tag.'::TEXT, 'TRANSIT_DOC_UNIQUE_VIOLATION'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::SMALLINT, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: fun_update_trip_v1.sql
-- =============================================
-- =============================================
-- FUNCION: fun_update_trip v2.0
-- Directorio: functions_v2
-- =============================================
-- Descripcion:
--   Actualiza un viaje existente en tab_trips.
--   Soporta actualizaciones parciales:
--     NULL en parametro opcional = mantener valor actual (via COALESCE sobre fila leida)
--     0 en wid_bus / wid_driver  = desasignar (set a NULL)
--   Gestiona automaticamente:
--     started_at   -> se graba al transicionar a id_status = 3 (activo), solo si aun es NULL
--     completed_at -> se graba al transicionar a id_status = 4 (completado), solo si aun es NULL
--   Para cancelar un viaje (status=5, is_active=FALSE) usar fun_cancel_trip.
--
-- Parametros obligatorios (IN):
--   wid_trip     INTEGER  - ID del viaje a actualizar
--   wuser_update SMALLINT - Usuario que realiza el cambio
--
-- Parametros opcionales (IN / DEFAULT NULL = sin cambio):
--   wid_route    SMALLINT - Nueva ruta
--   wtrip_date   DATE     - Nueva fecha
--   wstart_time  TIME     - Nueva hora de inicio
--   wend_time    TIME     - Nueva hora de fin
--   wid_bus      SMALLINT - Nuevo bus  (NULL = sin cambio, 0 = desasignar)
--   wid_driver   BIGINT   - Nuevo conductor (NULL = sin cambio, 0 = desasignar)
--   wid_status   SMALLINT - Nuevo estado (1=pendiente, 2=asignado, 3=activo, 4=completado)
--                           Para cancelar un viaje usar fun_cancel_trip.
--
-- Retorna (OUT):
--   success      BOOLEAN
--   msg          TEXT
--   error_code   VARCHAR(50)
--   out_id_trip  INTEGER
--
-- Codigos de error:
--   TRIP_NOT_FOUND        - El viaje no existe o ya esta inactivo
--   TRIP_STATUS_INVALID   - Se intento usar status 5 (usar fun_cancel_trip)
--   TRIP_UNIQUE_VIOLATION - Conflicto de bus/conductor en misma fecha y hora
--   TRIP_CHECK_VIOLATION  - end_time <= start_time u otro CHECK
--   TRIP_FK_VIOLATION     - Ruta, bus, conductor o estado inexistentes
--   TRIP_UPDATE_ERROR     - Error inesperado
--
-- Version : 2.0
-- Fecha   : 2026-03-18
-- =============================================

-- Limpiar versiones anteriores
DROP FUNCTION IF EXISTS fun_update_trip(INTEGER, SMALLINT, SMALLINT, DATE, TIME, TIME, SMALLINT, BIGINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_update_trip(INTEGER, INTEGER,  TIME,     TIME, VARCHAR, SMALLINT);

CREATE OR REPLACE FUNCTION fun_update_trip(
  wid_trip       tab_trips.id_trip%TYPE,
  wuser_update   tab_trips.user_update%TYPE,
  wid_route      tab_trips.id_route%TYPE    DEFAULT NULL,
  wtrip_date     tab_trips.trip_date%TYPE   DEFAULT NULL,
  wstart_time    tab_trips.start_time%TYPE  DEFAULT NULL,
  wend_time      tab_trips.end_time%TYPE    DEFAULT NULL,
  wid_bus        tab_trips.id_bus%TYPE      DEFAULT NULL,
  wid_driver     tab_trips.id_driver%TYPE   DEFAULT NULL,
  wid_status     tab_trips.id_status%TYPE   DEFAULT NULL,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50),
  OUT out_id_trip tab_trips.id_trip%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_cur   tab_trips%ROWTYPE;
  v_rows  INTEGER;
BEGIN

  success     := FALSE;
  msg         := '';
  error_code  := NULL;
  out_id_trip := NULL;

  -- Leer fila actual para COALESCE y timestamps automaticos
  SELECT * INTO v_cur
  FROM tab_trips
  WHERE id_trip = wid_trip AND is_active = TRUE;

  IF NOT FOUND THEN
    msg        := 'Viaje no encontrado o inactivo (ID: ' || wid_trip || ')';
    error_code := 'TRIP_NOT_FOUND';
    RETURN;
  END IF;

  -- Prevenir uso incorrecto: cancelacion se hace con fun_cancel_trip
  IF wid_status = 5 THEN
    msg        := 'Para cancelar un viaje usar fun_cancel_trip';
    error_code := 'TRIP_STATUS_INVALID';
    RETURN;
  END IF;

  UPDATE tab_trips SET
    id_route    = COALESCE(wid_route,   v_cur.id_route),
    trip_date   = COALESCE(wtrip_date,  v_cur.trip_date),
    start_time  = COALESCE(wstart_time, v_cur.start_time),
    end_time    = COALESCE(wend_time,   v_cur.end_time),

    -- NULL = sin cambio | 0 = desasignar | >0 = asignar
    id_bus      = CASE
                    WHEN wid_bus IS NULL THEN v_cur.id_bus
                    WHEN wid_bus = 0    THEN NULL
                    ELSE wid_bus
                  END,
    id_driver   = CASE
                    WHEN wid_driver IS NULL THEN v_cur.id_driver
                    WHEN wid_driver = 0    THEN NULL
                    ELSE wid_driver
                  END,

    id_status   = COALESCE(wid_status, v_cur.id_status),

    -- Timestamps operacionales automaticos
    started_at   = CASE
                     WHEN wid_status = 3 AND v_cur.started_at IS NULL THEN NOW()
                     ELSE v_cur.started_at
                   END,
    completed_at = CASE
                     WHEN wid_status = 4 AND v_cur.completed_at IS NULL THEN NOW()
                     ELSE v_cur.completed_at
                   END,

    updated_at  = NOW(),
    user_update = wuser_update

  WHERE id_trip = wid_trip;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'No se pudo actualizar el viaje (ID: ' || wid_trip || ')';
    error_code := 'TRIP_NOT_FOUND';
    RETURN;
  END IF;

  success     := TRUE;
  out_id_trip := wid_trip;
  msg         := 'Viaje actualizado exitosamente (ID: ' || wid_trip || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Conflicto: bus o conductor ya tienen un viaje en esa fecha/hora: ' || SQLERRM;
    error_code := 'TRIP_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restriccion CHECK violada (ej: end_time > start_time): ' || SQLERRM;
    error_code := 'TRIP_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Ruta, bus, conductor o estado no encontrados: ' || SQLERRM;
    error_code := 'TRIP_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'TRIP_UPDATE_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_update_trip(INTEGER, SMALLINT, SMALLINT, DATE, TIME, TIME, SMALLINT, BIGINT, SMALLINT) IS
'v2.0 - Actualiza viaje con soporte parcial (NULL=sin cambio, 0=desasignar id_bus/id_driver). Gestiona started_at en status=3 y completed_at en status=4. Para cancelar usar fun_cancel_trip.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Cambiar solo el estado a activo (inicia turno) -> graba started_at
SELECT * FROM fun_update_trip(42, 1, wid_status => 3);

-- Cambiar solo el estado a completado -> graba completed_at
SELECT * FROM fun_update_trip(42, 1, wid_status => 4);

-- Cancelar viaje -> usar fun_cancel_trip
-- SELECT * FROM fun_cancel_trip(42, 1, 'Viaje cancelado por operaciones', FALSE);

-- Asignar bus y conductor, cambiar a asignado
SELECT * FROM fun_update_trip(42, 1, wid_bus => 3::SMALLINT, wid_driver => 1015432876, wid_status => 2);

-- Cambiar horario sin tocar status
SELECT * FROM fun_update_trip(42, 1,
  wstart_time => '06:00'::TIME,
  wend_time   => '07:30'::TIME
);

-- Desasignar bus (0 = set NULL en BD), volver a pendiente
SELECT * FROM fun_update_trip(42, 1, wid_bus => 0::SMALLINT, wid_status => 1);

*/


-- =============================================
-- FUNCTION: fun_update_user_v2.sql
-- =============================================
-- =============================================
-- FUNCIÃ“N: fun_update_user v2.0
-- Directorio: functions_v2
-- =============================================
-- DescripciÃ³n:
--   Actualiza el nombre completo y/o el email de un
--   usuario existente en tab_users.
--   Ambos campos son opcionales: si se pasa NULL se
--   conserva el valor actual (via COALESCE en el SET).
--   La validaciÃ³n de negocio es responsabilidad del
--   backend (Node.js); los constraints de la BD
--   actÃºan como Ãºltima barrera.
--
-- ParÃ¡metros:
--   wid_user    SMALLINT     â€” ID del usuario a actualizar
--   wfull_name  VARCHAR(100) â€” Nuevo nombre completo (NULL = no cambiar)
--   wemail_user VARCHAR(320) â€” Nuevo email (NULL = no cambiar)
--
-- Retorna (OUT):
--   success    BOOLEAN     â€” TRUE si se actualizÃ³ correctamente
--   msg        TEXT        â€” Mensaje descriptivo del resultado
--   error_code VARCHAR(50) â€” NULL si success = TRUE
--
-- CÃ³digos de error:
--   USER_NOT_FOUND        â€” El id_user no existe en tab_users
--   USER_UNIQUE_VIOLATION â€” Email ya en uso por otro usuario
--   USER_CHECK_VIOLATION  â€” Constraint CHECK violado
--   USER_UPDATE_ERROR     â€” Error inesperado en el UPDATE
--
-- VersiÃ³n   : 2.0
-- Fecha     : 2026-03-11
-- =============================================

DROP FUNCTION IF EXISTS fun_update_user(SMALLINT, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_user(
  wid_user     tab_users.id_user%TYPE,
  wfull_name   tab_users.full_name%TYPE   DEFAULT NULL,
  wemail_user  tab_users.email_user%TYPE  DEFAULT NULL,

  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql

AS $$
DECLARE
  v_rows INTEGER;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;

  UPDATE tab_users
  SET full_name  = COALESCE(NULLIF(TRIM(REGEXP_REPLACE(wfull_name, '\s+', ' ', 'g')), ''), full_name),
      email_user = COALESCE(NULLIF(LOWER(TRIM(wemail_user)), ''), email_user)
  WHERE id_user = wid_user;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN
    msg        := 'Usuario no encontrado (id_user: ' || COALESCE(wid_user::TEXT, 'NULL') || ')';
    error_code := 'USER_NOT_FOUND'; RETURN;
  END IF;

  success := TRUE;
  msg     := 'Usuario actualizado exitosamente';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'El email ya estÃ¡ en uso por otro usuario: ' || SQLERRM;
    error_code := 'USER_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'RestricciÃ³n CHECK violada: ' || SQLERRM;
    error_code := 'USER_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'USER_UPDATE_ERROR';
END;
$$;

COMMENT ON FUNCTION fun_update_user(SMALLINT, VARCHAR, VARCHAR) IS
'v2.0 â€” Actualiza full_name y/o email_user en tab_users. NULL = conservar valor actual (COALESCE en SET). ValidaciÃ³n delegada al backend y constraints de BD.';

-- =============================================
-- EJEMPLOS DE USO
-- =============================================
/*

-- Actualizar solo el nombre
SELECT * FROM fun_update_user(2, 'Carlos Alberto Gil', NULL);

-- Actualizar solo el email
SELECT * FROM fun_update_user(2, NULL, 'carlos.nuevo@bucarabus.com');

-- Actualizar ambos
SELECT * FROM fun_update_user(2, 'Carlos Alberto Gil', 'carlos.nuevo@bucarabus.com');

-- Resultado exitoso:
-- success | msg                              | error_code
-- TRUE    | Usuario actualizado exitosamente | NULL

-- Error: id_user no existe
-- success | msg                              | error_code
-- FALSE   | Usuario no encontrado (id_user: 99) | USER_NOT_FOUND

-- Error: email duplicado (UNIQUE constraint)
-- success | msg                                    | error_code
-- FALSE   | El email ya estÃ¡ en uso por otro ...   | USER_UNIQUE_VIOLATION

*/

-- =============================================
-- FUNCTION: fun_user_permissions.sql
-- =============================================
-- =============================================
-- BucaraBUS â€” FunciÃ³n: Overrides de Permisos por Usuario
-- Archivo: fun_user_permissions.sql
--
-- Principio arquitectÃ³nico: Esta funciÃ³n es una MUTACIÃ“N (DELETE + INSERT).
-- Las consultas SELECT de permisos efectivos viven en auth.service.js (Node.js).
-- =============================================

DROP FUNCTION IF EXISTS fun_update_user_permissions(INTEGER, JSONB, INTEGER);

CREATE OR REPLACE FUNCTION fun_update_user_permissions(
  wid_user        tab_users.id_user%TYPE,
  woverrides_json JSONB,
  wuser_update    tab_users.id_user%TYPE DEFAULT 1,

  -- ParÃ¡metros OUT siguiendo tu estÃ¡ndar v2
  OUT success     BOOLEAN,
  OUT msg         TEXT,
  OUT error_code  VARCHAR(50)
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_override      JSONB;
  v_perm_code     tab_permissions.code_permission%TYPE;
  v_is_granted    BOOLEAN;
  v_id_permission tab_permissions.id_permission%TYPE;
BEGIN
  -- Inicializar respuesta
  success    := FALSE;
  msg        := '';
  error_code := NULL;

  -- 1. Eliminar TODOS los overrides actuales del usuario (reemplazo atÃ³mico)
  DELETE FROM tab_user_permissions WHERE id_user = wid_user;

  -- 2. Insertar los nuevos overrides si se enviÃ³ un arreglo no vacÃ­o
  IF woverrides_json IS NOT NULL AND jsonb_array_length(woverrides_json) > 0 THEN
    FOR v_override IN SELECT jsonb_array_elements(woverrides_json)
    LOOP
      -- Casteo y extracciÃ³n del JSON
      v_perm_code  := UPPER(TRIM(v_override->>'code'));
      v_is_granted := (v_override->>'is_granted')::BOOLEAN;

      -- Buscar el id_permission por cÃ³digo
      SELECT id_permission
        INTO v_id_permission
        FROM tab_permissions
       WHERE code_permission = v_perm_code
         AND is_active = TRUE;

      -- Solo insertar si el permiso existe y es activo
      IF v_id_permission IS NOT NULL THEN
        INSERT INTO tab_user_permissions (id_user, id_permission, is_granted, assigned_by)
        VALUES (wid_user, v_id_permission, v_is_granted, wuser_update);
      END IF;

    END LOOP;
  END IF;

  success := TRUE;
  msg     := 'Permisos personalizados actualizados correctamente para el usuario ID: ' || wid_user;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario o permiso inexistente: ' || SQLERRM;
    error_code := 'USER_PERM_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado al actualizar permisos: ' || SQLERRM;
    error_code := 'USER_PERM_INTERNAL_ERROR';
END;
$$;


-- =============================================
-- FUNCTION: trigger_audit_trail.sql
-- =============================================

-- =============================================
-- 4. TRIGGERS
-- =============================================

-- â”€â”€ tab_companies â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_companies ON tab_companies;
CREATE TRIGGER trg_audit_companies
  BEFORE INSERT OR UPDATE OR DELETE ON tab_companies
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_company');

-- â”€â”€ tab_bus_owners â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_bus_owners ON tab_bus_owners;
CREATE TRIGGER trg_audit_bus_owners
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_owners
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_owner');

-- â”€â”€ tab_drivers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_drivers ON tab_drivers;
CREATE TRIGGER trg_audit_drivers
  BEFORE INSERT OR UPDATE OR DELETE ON tab_drivers
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_driver');

-- â”€â”€ tab_buses â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_buses ON tab_buses;
CREATE TRIGGER trg_audit_buses
  BEFORE INSERT OR UPDATE OR DELETE ON tab_buses
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_bus');

-- â”€â”€ tab_bus_insurance (PK compuesta: id_bus + id_insurance_type) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_bus_insurance ON tab_bus_insurance;
CREATE TRIGGER trg_audit_bus_insurance
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_insurance
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_bus|id_insurance_type');

-- â”€â”€ tab_bus_transit_docs (PK compuesta: id_doc + id_bus) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_bus_transit_docs ON tab_bus_transit_docs;
CREATE TRIGGER trg_audit_bus_transit_docs
  BEFORE INSERT OR UPDATE OR DELETE ON tab_bus_transit_docs
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_doc|id_bus');

-- â”€â”€ tab_routes (excluye path_route: geometrÃ­a PostGIS LineString) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_routes ON tab_routes;
CREATE TRIGGER trg_audit_routes
  BEFORE INSERT OR UPDATE OR DELETE ON tab_routes
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_route', 'path_route');

-- â”€â”€ tab_route_points (excluye location_point: geometrÃ­a PostGIS Point) â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_route_points ON tab_route_points;
CREATE TRIGGER trg_audit_route_points
  BEFORE INSERT OR UPDATE OR DELETE ON tab_route_points
  FOR EACH ROW EXECUTE FUNCTION fun_audit_full('id_point', 'location_point');

-- â”€â”€ tab_parameters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
DROP TRIGGER IF EXISTS trg_audit_parameters ON tab_parameters;
CREATE TRIGGER trg_audit_parameters
  BEFORE UPDATE ON tab_parameters
  FOR EACH ROW EXECUTE FUNCTION fun_audit_params();



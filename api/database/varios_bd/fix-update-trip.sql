-- =============================================
-- Script COMPLETO: Limpieza + Deploy fun_update_trip v3
-- =============================================
-- Ejecuta este archivo en DBeaver/pgAdmin para arreglar el error
-- =============================================

\echo '=========================================='
\echo 'PASO 1: Eliminando versiones anteriores...'
\echo '=========================================='

-- Eliminar TODAS las posibles versiones anteriores
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, TIME, TIME, VARCHAR, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, TIME, TIME, VARCHAR, SMALLINT) CASCADE;
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, TIME, TIME) CASCADE;
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, SMALLINT) CASCADE;
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS fun_update_trip(BIGINT, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS fun_update_trip CASCADE;

\echo 'Versiones anteriores eliminadas ✓'

\echo '=========================================='
\echo 'PASO 2: Creando fun_update_trip v3.0...'
\echo '=========================================='

-- =============================================
-- Función: fun_update_trip v3.0
-- =============================================
CREATE OR REPLACE FUNCTION fun_update_trip(
    -- Identificador del viaje a actualizar
    wid_trip         BIGINT,
    
    -- Auditoría
    wuser_update     INTEGER,
    
    -- Datos opcionales (NULL = mantener valor actual)
    wnew_start_time  TIME DEFAULT NULL,
    wnew_end_time    TIME DEFAULT NULL,
    wnew_plate       VARCHAR(6) DEFAULT NULL,
    wnew_status      SMALLINT DEFAULT NULL,
    
    -- Parámetros de salida
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT error_code   VARCHAR,
    OUT id_trip      BIGINT
)
LANGUAGE plpgsql AS $$

DECLARE
    v_trip_exists       BOOLEAN;
    v_current_start     TIME;
    v_current_end       TIME;
    v_current_plate     VARCHAR(6);
    v_current_id_user   INTEGER;
    v_current_status    SMALLINT;
    v_current_route     INTEGER;
    v_plate_clean       VARCHAR(6);
    v_new_id_user       INTEGER;
    v_bus_exists        BOOLEAN;
    v_bus_active        BOOLEAN;
    v_rows_affected     INTEGER;
    v_has_changes       BOOLEAN := FALSE;
    v_event_data        JSONB;
    
BEGIN
    -- ====================================
    -- 1. INICIALIZACIÓN
    -- ====================================
    success := FALSE;
    msg := '';
    error_code := NULL;
    id_trip := NULL;

    -- ====================================
    -- 2. VALIDACIÓN DEL USUARIO ACTUALIZADOR
    -- ====================================
    IF wuser_update != -1 AND NOT EXISTS(SELECT 1 FROM tab_users WHERE id_user = wuser_update) THEN
        msg := 'El usuario actualizador (id_user=' || wuser_update || ') no existe';
        error_code := 'USER_NOT_FOUND';
        RETURN;
    END IF;

    -- ====================================
    -- 3. VERIFICAR QUE EL VIAJE EXISTE
    -- ====================================
    SELECT 
        tab_trips.id_trip, id_route, start_time, end_time, plate_number, id_user, status_trip
    INTO 
        id_trip, v_current_route, v_current_start, v_current_end, 
        v_current_plate, v_current_id_user, v_current_status
    FROM tab_trips
    WHERE tab_trips.id_trip = wid_trip AND is_active = TRUE;

    IF id_trip IS NULL THEN
        msg := 'El viaje con ID ' || wid_trip || ' no existe o está eliminado';
        error_code := 'TRIP_NOT_FOUND';
        RETURN;
    END IF;

    RAISE NOTICE '[fun_update_trip] Viaje actual: ID=%, Ruta=%, Horario=%-%', 
        wid_trip, v_current_route, v_current_start, v_current_end;

    -- ====================================
    -- 4. VALIDAR HORARIOS
    -- ====================================
    IF wnew_start_time IS NOT NULL OR wnew_end_time IS NOT NULL THEN
        DECLARE
            v_final_start TIME;
            v_final_end   TIME;
        BEGIN
            v_final_start := COALESCE(wnew_start_time, v_current_start);
            v_final_end := COALESCE(wnew_end_time, v_current_end);
            
            IF v_final_end <= v_final_start THEN
                msg := 'Hora de fin (' || v_final_end || ') debe ser mayor a hora de inicio (' || v_final_start || ')';
                error_code := 'INVALID_TIME_RANGE';
                RETURN;
            END IF;
            
            v_has_changes := TRUE;
        END;
    END IF;

    -- ====================================
    -- 5. VALIDAR Y NORMALIZAR PLACA
    -- ====================================
    v_plate_clean := NULL;
    v_new_id_user := NULL;
    
    IF wnew_plate IS NOT NULL THEN
        -- String vacío = desasignar bus y conductor
        IF TRIM(wnew_plate) = '' THEN
            v_plate_clean := NULL;
            v_new_id_user := NULL;
            v_has_changes := TRUE;
        ELSE
            v_plate_clean := UPPER(TRIM(wnew_plate));
            
            -- Validar formato de placa (3 letras + 3 números)
            IF v_plate_clean !~ '^[A-Z]{3}[0-9]{3}$' THEN
                msg := 'Formato de placa inválido "' || v_plate_clean || '". Debe ser 3 letras + 3 números (ej: ABC123)';
                error_code := 'PLATE_INVALID_FORMAT';
                RETURN;
            END IF;
            
            -- Validar que el bus existe y obtener id_user del conductor
            SELECT 
                EXISTS(SELECT 1 FROM tab_buses WHERE plate_number = v_plate_clean),
                COALESCE((SELECT is_active FROM tab_buses WHERE plate_number = v_plate_clean), FALSE),
                (SELECT id_user FROM tab_buses WHERE plate_number = v_plate_clean)
            INTO v_bus_exists, v_bus_active, v_new_id_user;
            
            IF NOT v_bus_exists THEN
                msg := 'El bus con placa ' || v_plate_clean || ' no existe';
                error_code := 'BUS_NOT_FOUND';
                RETURN;
            END IF;
            
            IF NOT v_bus_active THEN
                msg := 'El bus con placa ' || v_plate_clean || ' está inactivo';
                error_code := 'BUS_INACTIVE';
                RETURN;
            END IF;
            
            -- Marcar cambio si es diferente
            IF v_plate_clean != v_current_plate OR (v_current_plate IS NULL AND v_plate_clean IS NOT NULL) THEN
                v_has_changes := TRUE;
            END IF;
        END IF;
    END IF;

    -- ====================================
    -- 6. VALIDAR ESTADO
    -- ====================================
    IF wnew_status IS NOT NULL THEN
        -- Validar rango (1-5)
        IF wnew_status NOT BETWEEN 1 AND 5 THEN
            msg := 'Estado inválido ' || wnew_status || '. Debe estar entre 1 (pending) y 5 (cancelled)';
            error_code := 'STATUS_INVALID';
            RETURN;
        END IF;
        
        -- Validar transiciones: no se puede revertir de completed (4) o cancelled (5)
        IF v_current_status IN (4, 5) AND wnew_status NOT IN (4, 5) THEN
            msg := 'No se puede cambiar un viaje completado/cancelado a otro estado';
            error_code := 'INVALID_STATUS_TRANSITION';
            RETURN;
        END IF;
        
        -- Validar consistencia: si se asigna bus, estado debe ser >= 2 (assigned)
        IF v_plate_clean IS NOT NULL AND wnew_status = 1 THEN
            msg := 'No se puede asignar bus a un viaje con estado "pending" (1). Use estado "assigned" (2) o superior';
            error_code := 'STATUS_INCONSISTENT_WITH_BUS';
            RETURN;
        END IF;
        
        -- Si se desasigna bus, estado debe volver a pending (1)
        IF wnew_plate IS NOT NULL AND TRIM(wnew_plate) = '' AND wnew_status != 1 THEN
            msg := 'Al desasignar el bus, el estado debe cambiar a "pending" (1)';
            error_code := 'STATUS_MUST_BE_PENDING';
            RETURN;
        END IF;
        
        IF wnew_status != v_current_status THEN
            v_has_changes := TRUE;
        END IF;
    END IF;

    -- ====================================
    -- 7. VERIFICAR QUE HAY CAMBIOS
    -- ====================================
    IF NOT v_has_changes THEN
        msg := 'No hay cambios para aplicar. Proporcione al menos un campo para actualizar';
        error_code := 'NO_CHANGES';
        RETURN;
    END IF;

    -- ====================================
    -- 8. ACTUALIZAR VIAJE
    -- ====================================
    BEGIN
        UPDATE tab_trips
        SET 
            start_time = COALESCE(wnew_start_time, start_time),
            end_time = COALESCE(wnew_end_time, end_time),
            plate_number = CASE 
                WHEN wnew_plate IS NOT NULL AND TRIM(wnew_plate) = '' THEN NULL
                WHEN v_plate_clean IS NOT NULL THEN v_plate_clean
                ELSE plate_number
            END,
            id_user = CASE 
                WHEN wnew_plate IS NOT NULL AND TRIM(wnew_plate) = '' THEN NULL
                WHEN v_new_id_user IS NOT NULL THEN v_new_id_user
                ELSE id_user
            END,
            status_trip = COALESCE(wnew_status, status_trip),
            updated_at = NOW(),
            user_update = wuser_update
        WHERE tab_trips.id_trip = wid_trip;
        
        GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
        
        IF v_rows_affected = 0 THEN
            msg := 'No se pudo actualizar el viaje (ID: ' || wid_trip || ')';
            error_code := 'TRIP_UPDATE_FAILED';
            RETURN;
        END IF;
        
        RAISE NOTICE '[fun_update_trip] Viaje actualizado exitosamente: ID=%', wid_trip;
        
    EXCEPTION
        WHEN unique_violation THEN
            msg := 'Error: Ya existe otro viaje con esa combinación de ruta, fecha y hora de inicio';
            error_code := 'TRIP_UPDATE_UNIQUE_VIOLATION';
            RETURN;
        WHEN foreign_key_violation THEN
            msg := 'Error de clave foránea: ' || SQLERRM;
            error_code := 'TRIP_UPDATE_FK_VIOLATION';
            RETURN;
        WHEN check_violation THEN
            msg := 'Error de restricción: ' || SQLERRM;
            error_code := 'TRIP_UPDATE_CHECK_VIOLATION';
            RETURN;
        WHEN OTHERS THEN
            msg := 'Error inesperado al actualizar viaje: ' || SQLERRM;
            error_code := 'TRIP_UPDATE_ERROR';
            RETURN;
    END;

    -- ====================================
    -- 9. REGISTRAR EVENTO (SI CAMBIÓ EL ESTADO)
    -- ====================================
    IF wnew_status IS NOT NULL AND wnew_status != v_current_status THEN
        BEGIN
            v_event_data := jsonb_build_object(
                'old_status', v_current_status,
                'new_status', wnew_status,
                'updated_by', wuser_update,
                'changes', jsonb_build_object(
                    'start_time', CASE WHEN wnew_start_time IS NOT NULL THEN wnew_start_time::TEXT ELSE NULL END,
                    'end_time', CASE WHEN wnew_end_time IS NOT NULL THEN wnew_end_time::TEXT ELSE NULL END,
                    'plate_number', CASE WHEN wnew_plate IS NOT NULL THEN v_plate_clean ELSE NULL END
                )
            );

            INSERT INTO tab_trip_events (
                id_event, id_trip, event_type, old_status, new_status, 
                event_data, performed_by, performed_at
            )
            VALUES (
                (SELECT COALESCE(MAX(id_event), 0) + 1 FROM tab_trip_events),
                wid_trip,
                'status_change',
                v_current_status,
                wnew_status,
                v_event_data,
                wuser_update,
                NOW()
            );

            RAISE NOTICE '[fun_update_trip] Evento registrado: status % → %', v_current_status, wnew_status;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '[fun_update_trip] Error al registrar evento: %', SQLERRM;
        END;
    END IF;

    -- ====================================
    -- 10. RETORNO EXITOSO
    -- ====================================
    success := TRUE;
    msg := 'Viaje actualizado correctamente';
    error_code := NULL;
    id_trip := wid_trip;

END;
$$;

COMMENT ON FUNCTION fun_update_trip IS 'v3.0 - Actualiza viaje con SMALLINT status y auto-asignación de conductor desde bus';

\echo 'fun_update_trip v3.0 creada exitosamente ✓'
\echo '=========================================='
\echo 'COMPLETADO - Función lista para usar'
\echo '=========================================='

-- Verificación
SELECT 
    proname AS function_name,
    pg_get_function_arguments(oid) AS parameters
FROM pg_proc 
WHERE proname = 'fun_update_trip'
ORDER BY oid DESC
LIMIT 1;

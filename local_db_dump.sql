--
-- PostgreSQL database dump
--

-- Dumped from database version 17.0
-- Dumped by pg_dump version 17.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: fun_assign_driver(smallint, bigint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_assign_driver(wid_bus smallint, wid_driver bigint, wassigned_by smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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


--
-- Name: fun_assign_role(smallint, smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_assign_role(wid_user smallint, wid_role smallint, wassigned_by smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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


--
-- Name: fun_assign_role_permission(smallint, character varying, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_assign_role_permission(wid_role smallint, wcode_permission character varying, wassigned_by smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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
    msg := 'El permiso con código ' || wcode_permission || ' no existe';
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
    msg := 'El rol ya tenía asignado este permiso';
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


--
-- Name: fun_assign_route_point(smallint, smallint, smallint, numeric, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_assign_route_point(wid_route smallint, wid_point smallint, wpoint_order smallint, wdist_from_start numeric DEFAULT NULL::numeric, weta_seconds integer DEFAULT NULL::integer, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT out_id_point smallint, OUT out_point_order smallint) RETURNS record
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


--
-- Name: FUNCTION fun_assign_route_point(wid_route smallint, wid_point smallint, wpoint_order smallint, wdist_from_start numeric, weta_seconds integer, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT out_id_point smallint, OUT out_point_order smallint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_assign_route_point(wid_route smallint, wid_point smallint, wpoint_order smallint, wdist_from_start numeric, weta_seconds integer, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT out_id_point smallint, OUT out_point_order smallint) IS 'v1.0 â€” Asigna un punto de ruta (tab_route_points) a una ruta (tab_routes) mediante tab_route_points_assoc. Un mismo punto puede asignarse a mÃºltiples rutas con orden, distancia y ETA propios.';


--
-- Name: fun_audit_full(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_audit_full() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
  v_row        RECORD;         -- Fila de referencia para extraer PK
  v_record_id  TEXT  := '';   -- PK construida
  v_changed_by SMALLINT;
  v_old_data   JSONB;
  v_new_data   JSONB;
  v_pk_cols    TEXT[];
  v_excl_cols  TEXT[];
  v_col        TEXT;
  v_val        TEXT;
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
$_$;


--
-- Name: FUNCTION fun_audit_full(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_audit_full() IS 'Trigger de auditoría para tablas con user_create + user_update.
   TG_ARGV[0]: columnas PK separadas por "|" (ej: "id_bus" o "id_bus|id_insurance_type").
   TG_ARGV[1]: columnas a excluir del JSONB, separadas por "|" (opcional, para PostGIS).
   Maneja INSERT, UPDATE y DELETE físico.';


--
-- Name: fun_audit_params(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_audit_params() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: FUNCTION fun_audit_params(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_audit_params() IS 'Trigger de auditoría exclusivo para tab_parameters.
   Solo procesa UPDATE (INSERT es seed de admin, sin user_create en la tabla).';


--
-- Name: fun_auto_activate_trips(date, time without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_auto_activate_trips(wp_date date, wp_time time without time zone) RETURNS void
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
        RAISE NOTICE 'fun_auto_activate_trips: % viaje(s) activado(s) automáticamente para %', v_rows, wp_date;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'fun_auto_activate_trips: error al activar viajes para % — % (%)',
            wp_date, SQLERRM, SQLSTATE;
END;
$$;


--
-- Name: fun_cancel_trip(integer, smallint, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_cancel_trip(wid_trip integer, wuser_cancel smallint, wcancellation_reason text DEFAULT NULL::text, wforce_cancel boolean DEFAULT false) RETURNS TABLE(success boolean, msg text, error_code text)
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


--
-- Name: FUNCTION fun_cancel_trip(wid_trip integer, wuser_cancel smallint, wcancellation_reason text, wforce_cancel boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_cancel_trip(wid_trip integer, wuser_cancel smallint, wcancellation_reason text, wforce_cancel boolean) IS 'Cancela un viaje: id_status=5, is_active=FALSE, completed_at=NOW(). Requiere wforce_cancel=TRUE para viajes en curso (status=3). Para actualizar datos del viaje sin cancelar usar fun_update_trip.';


--
-- Name: fun_cancel_trips_batch(smallint, date, smallint, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_cancel_trips_batch(wid_route smallint, wtrip_date date, wuser_cancel smallint, wcancellation_reason text DEFAULT NULL::text, wforce_cancel_active boolean DEFAULT false, OUT success boolean, OUT msg text, OUT error_code character varying, OUT trips_cancelled integer, OUT trips_active_skipped integer, OUT cancelled_ids integer[]) RETURNS record
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


--
-- Name: FUNCTION fun_cancel_trips_batch(wid_route smallint, wtrip_date date, wuser_cancel smallint, wcancellation_reason text, wforce_cancel_active boolean, OUT success boolean, OUT msg text, OUT error_code character varying, OUT trips_cancelled integer, OUT trips_active_skipped integer, OUT cancelled_ids integer[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_cancel_trips_batch(wid_route smallint, wtrip_date date, wuser_cancel smallint, wcancellation_reason text, wforce_cancel_active boolean, OUT success boolean, OUT msg text, OUT error_code character varying, OUT trips_cancelled integer, OUT trips_active_skipped integer, OUT cancelled_ids integer[]) IS 'v1.0 â€” Cancela en lote los viajes activos de una ruta/fecha. status=3 (en curso) solo se cancela con wforce_cancel_active=TRUE. Errores: NO_TRIPS_CANCELLED, BATCH_FK_VIOLATION, BATCH_CANCEL_ERROR.';


--
-- Name: fun_consume_password_reset_token(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_consume_password_reset_token(wtoken character varying, wpassword_hash character varying, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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
    msg        := 'El enlace de recuperación es inválido o ya expiró';
    error_code := 'RESET_TOKEN_INVALID';
    RETURN;
  END IF;

  -- Actualizar contraseña del usuario
  UPDATE tab_users
     SET pass_user = wpassword_hash
   WHERE id_user = v_id_user;

  -- Eliminar el token (uso único)
  DELETE FROM tab_password_reset_tokens WHERE id_token = v_id_token;

  success := TRUE;
  msg     := 'Contraseña actualizada correctamente';

EXCEPTION
  WHEN OTHERS THEN
    msg        := 'Error inesperado al restablecer contraseña: ' || SQLERRM;
    error_code := 'RESET_INTERNAL_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_consume_password_reset_token(wtoken character varying, wpassword_hash character varying, OUT success boolean, OUT msg text, OUT error_code character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_consume_password_reset_token(wtoken character varying, wpassword_hash character varying, OUT success boolean, OUT msg text, OUT error_code character varying) IS 'Valida el token, actualiza la contraseña y elimina el token (uso único). Atómico.';


--
-- Name: fun_create_arl(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_arl(wname_arl character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying) RETURNS record
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


--
-- Name: FUNCTION fun_create_arl(wname_arl character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_arl(wname_arl character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying) IS 'v1.0 â€” Crea ARL en tab_arl. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';


--
-- Name: fun_create_brand(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_brand(wbrand_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying) RETURNS record
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


--
-- Name: FUNCTION fun_create_brand(wbrand_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_brand(wbrand_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying) IS 'v1.0 â€” Crea marca en tab_brands. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';


--
-- Name: fun_create_bus(character varying, character varying, character varying, smallint, smallint, smallint, character varying, bigint, smallint, smallint, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_bus(wplate_number character varying, wamb_code character varying, wcode_internal character varying, wid_company smallint, wmodel_year smallint, wcapacity_bus smallint, wcolor_bus character varying, wid_owner bigint, wuser_create smallint, wid_brand smallint DEFAULT NULL::smallint, wmodel_name character varying DEFAULT 'SA'::character varying, wchassis_number character varying DEFAULT 'SA'::character varying, wphoto_url character varying DEFAULT NULL::character varying, wgps_device_id character varying DEFAULT NULL::character varying, wcolor_app character varying DEFAULT '#CCCCCC'::character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_bus smallint, OUT out_plate character varying) RETURNS record
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


--
-- Name: FUNCTION fun_create_bus(wplate_number character varying, wamb_code character varying, wcode_internal character varying, wid_company smallint, wmodel_year smallint, wcapacity_bus smallint, wcolor_bus character varying, wid_owner bigint, wuser_create smallint, wid_brand smallint, wmodel_name character varying, wchassis_number character varying, wphoto_url character varying, wgps_device_id character varying, wcolor_app character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_bus smallint, OUT out_plate character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_bus(wplate_number character varying, wamb_code character varying, wcode_internal character varying, wid_company smallint, wmodel_year smallint, wcapacity_bus smallint, wcolor_bus character varying, wid_owner bigint, wuser_create smallint, wid_brand smallint, wmodel_name character varying, wchassis_number character varying, wphoto_url character varying, wgps_device_id character varying, wcolor_app character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_bus smallint, OUT out_plate character varying) IS 'v2.1 â€” Crea bus en tab_buses. Normaliza texto e inserta directamente; retorna out_id_bus y out_plate. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';


--
-- Name: fun_create_company(character varying, character varying, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_company(wcompany_name character varying, wnit_company character varying, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying) RETURNS record
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
  msg     := 'Compañía creada exitosamente: ' || out_company_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una compañía con ese nombre o NIT: ' || SQLERRM;
    error_code := 'COMPANY_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Usuario creador no válido: ' || SQLERRM;
    error_code := 'COMPANY_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'COMPANY_INSERT_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_create_company(wcompany_name character varying, wnit_company character varying, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_company(wcompany_name character varying, wnit_company character varying, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying) IS 'v1.0 — Crea compañía en tab_companies. Normaliza company_name con INITCAP/TRIM, NIT con TRIM. Genera ID con MAX+1. Validación de negocio delegada al backend y constraints de BD.';


--
-- Name: fun_create_driver(bigint, character varying, character varying, character varying, character varying, date, character varying, character varying, date, smallint, smallint, character varying, character varying, character varying, date, smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_driver(wid_driver bigint, wname_driver character varying DEFAULT 'SIN NOMBRE'::character varying, waddress_driver character varying DEFAULT 'SIN DIRECCIÓN'::character varying, wphone_driver character varying DEFAULT '0900000000'::character varying, wemail_driver character varying DEFAULT 'sa@sa.com'::character varying, wbirth_date date DEFAULT '2000-01-01'::date, wgender_driver character varying DEFAULT 'O'::character varying, wlicense_cat character varying DEFAULT 'SA'::character varying, wlicense_exp date DEFAULT '2000-01-01'::date, wid_eps smallint DEFAULT 1, wid_arl smallint DEFAULT 1, wblood_type character varying DEFAULT 'SA'::character varying, wemergency_contact character varying DEFAULT 'SIN CONTACTO'::character varying, wemergency_phone character varying DEFAULT '0900000000'::character varying, wdate_entry date DEFAULT CURRENT_DATE, wid_status smallint DEFAULT 1, wuser_create smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_driver bigint) RETURNS record
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
    COALESCE(NULLIF(TRIM(waddress_driver),         ''), 'SIN DIRECCIÓN'),
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
  msg        := 'Conductor creado exitosamente (Cédula: ' || wid_driver || ')';


EXCEPTION
  WHEN unique_violation THEN
    msg        := 'La cédula o usuario de sistema ya existen: ' || SQLERRM;
    error_code := 'DRIVER_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave foránea inválida: ' || SQLERRM;
    error_code := 'DRIVER_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada: ' || SQLERRM;
    error_code := 'DRIVER_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'DRIVER_INSERT_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_create_driver(wid_driver bigint, wname_driver character varying, waddress_driver character varying, wphone_driver character varying, wemail_driver character varying, wbirth_date date, wgender_driver character varying, wlicense_cat character varying, wlicense_exp date, wid_eps smallint, wid_arl smallint, wblood_type character varying, wemergency_contact character varying, wemergency_phone character varying, wdate_entry date, wid_status smallint, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_driver bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_driver(wid_driver bigint, wname_driver character varying, waddress_driver character varying, wphone_driver character varying, wemail_driver character varying, wbirth_date date, wgender_driver character varying, wlicense_cat character varying, wlicense_exp date, wid_eps smallint, wid_arl smallint, wblood_type character varying, wemergency_contact character varying, wemergency_phone character varying, wdate_entry date, wid_status smallint, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_driver bigint) IS 'v2.1 — Crea conductor en tab_drivers. Eliminado wid_user (vínculo con tab_users movido a tab_driver_accounts). Normaliza texto; validación delegada al backend y constraints de BD.';


--
-- Name: fun_create_eps(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_eps(wname_eps character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying) RETURNS record
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


--
-- Name: FUNCTION fun_create_eps(wname_eps character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_eps(wname_eps character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying) IS 'v1.0 â€” Crea EPS en tab_eps. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';


--
-- Name: fun_create_incident(integer, smallint, numeric, numeric, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_incident(wid_trip integer, wid_incident smallint, wlat_incident numeric, wlng_incident numeric, wdescrip_incident text DEFAULT NULL::text, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip_incident integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_location  GEOMETRY(Point, 4326);
  v_desc      tab_trip_incidents.descrip_incident%TYPE;
BEGIN
  -- Inicializar respuestas
  success              := FALSE;
  msg                  := '';
  error_code           := NULL;
  out_id_trip_incident := NULL;

  -- 1. Normalización y Casteo
  v_desc     := NULLIF(TRIM(wdescrip_incident), '');
  v_location := ST_SetSRID(ST_MakePoint(wlng_incident::DOUBLE PRECISION, wlat_incident::DOUBLE PRECISION), 4326);

  -- 2. Inserción Atómica
  INSERT INTO tab_trip_incidents (
    id_trip, 
    id_incident, 
    descrip_incident,
    location_incident,
    status_incident,
    created_at
  ) VALUES (
    wid_trip, 
    wid_incident, 
    v_desc,
    v_location,
    'active',
    NOW()
  )
  RETURNING id_trip_incident INTO out_id_trip_incident;

  success := TRUE;
  msg     := 'Incidente reportado exitosamente (ID: ' || out_id_trip_incident || ')';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'El viaje o tipo de incidente no existe: ' || SQLERRM;
    error_code := 'INCIDENT_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Datos de incidente fuera de rango o estado inválido: ' || SQLERRM;
    error_code := 'INCIDENT_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado al registrar incidente: ' || SQLERRM;
    error_code := 'INCIDENT_INSERT_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_create_incident(wid_trip integer, wid_incident smallint, wlat_incident numeric, wlng_incident numeric, wdescrip_incident text, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip_incident integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_incident(wid_trip integer, wid_incident smallint, wlat_incident numeric, wlng_incident numeric, wdescrip_incident text, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip_incident integer) IS 'v2.0 — Registra incidentes de viaje convirtiendo coordenadas a PostGIS. Normaliza descripción y asegura integridad referencial.';


--
-- Name: fun_create_incident_type(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_incident_type(wname_incident character varying, wtag_incident character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_type smallint, OUT out_name character varying, OUT out_tag character varying) RETURNS record
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


--
-- Name: FUNCTION fun_create_incident_type(wname_incident character varying, wtag_incident character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_type smallint, OUT out_name character varying, OUT out_tag character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_incident_type(wname_incident character varying, wtag_incident character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_type smallint, OUT out_name character varying, OUT out_tag character varying) IS 'v1.0 — Crea un tipo de incidente. Normaliza nombre con INITCAP y tag con LOWER.';


--
-- Name: fun_create_insurance_type(character varying, character varying, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_insurance_type(p_tag character varying, p_name character varying, p_descrip text, p_mandatory boolean) RETURNS TABLE(success boolean, msg text, error_code character varying, out_id_type smallint)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fun_create_insurer(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_insurer(winsurer_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying) RETURNS record
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


--
-- Name: FUNCTION fun_create_insurer(winsurer_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_insurer(winsurer_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying) IS 'v1.0 â€” Crea aseguradora en tab_insurers. Normaliza nombre con INITCAP/TRIM, genera ID con MAX+1. ValidaciÃ³n de negocio delegada al backend y constraints de BD.';


--
-- Name: fun_create_password_reset_token(smallint, character varying, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_password_reset_token(wid_user smallint, wtoken character varying, wexpires_at timestamp with time zone, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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
  msg     := 'Token de recuperación creado correctamente';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario inexistente: ' || SQLERRM;
    error_code := 'RESET_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado al crear token: ' || SQLERRM;
    error_code := 'RESET_INTERNAL_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_create_password_reset_token(wid_user smallint, wtoken character varying, wexpires_at timestamp with time zone, OUT success boolean, OUT msg text, OUT error_code character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_password_reset_token(wid_user smallint, wtoken character varying, wexpires_at timestamp with time zone, OUT success boolean, OUT msg text, OUT error_code character varying) IS 'Elimina tokens anteriores del usuario e inserta uno nuevo. Atómico.';


--
-- Name: fun_create_permission(character varying, character varying, text, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_permission(wname_permission character varying, wcode_permission character varying, wdescrip_permission text DEFAULT NULL::text, wcode_parent character varying DEFAULT NULL::character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_perm smallint) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_id_parent SMALLINT := NULL;
BEGIN
  success     := FALSE;
  msg         := '';
  error_code  := NULL;
  out_id_perm := NULL;

  -- 1. Si se envió un código padre, buscamos su ID
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
    -- Si ya existe (unique constraint en code_permission), lo consideramos éxito para los seeds
    SELECT id_permission INTO out_id_perm FROM tab_permissions WHERE code_permission = wcode_permission;
    success := TRUE; 
    msg := 'El permiso ya existía';
  WHEN foreign_key_violation THEN
    success := FALSE;
    msg := 'Violación de llave foránea al crear permiso';
    error_code := SQLSTATE;
  WHEN OTHERS THEN
    success := FALSE;
    msg := 'Error inesperado al crear permiso: ' || SQLERRM;
    error_code := SQLSTATE;
END;
$$;


--
-- Name: fun_create_route(character varying, text, character varying, smallint, smallint, jsonb, text, time without time zone, time without time zone, character varying, character varying, smallint, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_route(wname_route character varying, wpath_route text, wcolor_route character varying, wid_company smallint, wuser_create smallint, wstops jsonb, wdescrip_route text DEFAULT NULL::text, wfirst_trip time without time zone DEFAULT NULL::time without time zone, wlast_trip time without time zone DEFAULT NULL::time without time zone, wdeparture_route_sign character varying DEFAULT NULL::character varying, wreturn_route_sign character varying DEFAULT NULL::character varying, wroute_fare smallint DEFAULT 0, wis_circular boolean DEFAULT false, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint) RETURNS record
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

  -- ── Validar que hay al menos 2 paradas ───────────────────────────────────
  v_stop_count := jsonb_array_length(COALESCE(wstops, '[]'::JSONB));
  IF v_stop_count < 2 THEN
    msg        := 'Se requieren al menos 2 paradas para crear una ruta. Recibidas: ' || v_stop_count;
    error_code := 'ROUTE_STOPS_EMPTY';
    RETURN;
  END IF;

  -- ── Convertir GeoJSON → GEOMETRY ─────────────────────────────────────────
  BEGIN
    v_path_geom := ST_SetSRID(ST_GeomFromGeoJSON(wpath_route), 4326);
  EXCEPTION WHEN OTHERS THEN
    msg        := 'GeoJSON de path_route inválido: ' || SQLERRM;
    error_code := 'ROUTE_GEOM_ERROR';
    RETURN;
  END;

  -- ── Insertar la ruta en tab_routes ────────────────────────────────────────
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
      msg        := 'Compañía o usuario no existe: ' || SQLERRM;
      error_code := 'ROUTE_FK_VIOLATION';
      RETURN;
    WHEN check_violation THEN
      msg        := 'Valor fuera de rango (color inválido o first_trip >= last_trip): ' || SQLERRM;
      error_code := 'ROUTE_CHECK_VIOLATION';
      RETURN;
    WHEN OTHERS THEN
      msg        := 'Error al insertar la ruta: ' || SQLERRM;
      error_code := 'ROUTE_INSERT_ERROR';
      RETURN;
  END;

  -- ── Insertar cada parada en tab_route_points_assoc ───────────────────────
  -- Iteramos el array JSONB en orden de índice (0-based).
  -- point_order empieza en 1.
  FOR v_stop IN SELECT * FROM jsonb_array_elements(wstops) LOOP

    v_order    := v_order + 1;
    v_id_point := (v_stop->>'id_point')::SMALLINT;
    v_dist     := NULLIF(v_stop->>'dist_from_start', '')::NUMERIC;
    v_eta      := NULLIF(v_stop->>'eta_seconds', '')::INTEGER;

    -- Verificar que el punto existe y está activo
    SELECT EXISTS (
      SELECT 1 FROM tab_route_points
      WHERE id_point = v_id_point
        AND is_active = TRUE
    ) INTO v_point_exists;

    IF NOT v_point_exists THEN
      msg        := 'La parada con id_point=' || v_id_point || ' no existe o está inactiva.';
      error_code := 'ROUTE_STOP_INVALID';
      -- Al retornar aquí sin COMMIT explícito, PL/pgSQL hace ROLLBACK automático
      -- de todo lo insertado en esta ejecución de la función.
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
        msg        := 'Conflicto de orden en posición ' || v_order || ' para la ruta.';
        error_code := 'ROUTE_STOP_ERROR';
        RAISE EXCEPTION 'ROUTE_STOP_ERROR: %', msg;
      WHEN foreign_key_violation THEN
        msg        := 'FK inválida para parada id_point=' || v_id_point;
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
    -- El RAISE EXCEPTION dentro del loop aterriza aquí.
    -- success ya es FALSE y msg / error_code ya están seteados arriba.
    -- Si por alguna razón no lo están, los forzamos:
    IF error_code IS NULL THEN
      error_code := 'ROUTE_INSERT_ERROR';
      msg        := 'Error inesperado: ' || SQLERRM;
    END IF;
    out_id_route := NULL;
END;
$$;


--
-- Name: FUNCTION fun_create_route(wname_route character varying, wpath_route text, wcolor_route character varying, wid_company smallint, wuser_create smallint, wstops jsonb, wdescrip_route text, wfirst_trip time without time zone, wlast_trip time without time zone, wdeparture_route_sign character varying, wreturn_route_sign character varying, wroute_fare smallint, wis_circular boolean, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_route(wname_route character varying, wpath_route text, wcolor_route character varying, wid_company smallint, wuser_create smallint, wstops jsonb, wdescrip_route text, wfirst_trip time without time zone, wlast_trip time without time zone, wdeparture_route_sign character varying, wreturn_route_sign character varying, wroute_fare smallint, wis_circular boolean, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint) IS 'v2.0 — Crea una ruta en tab_routes e inserta sus paradas en tab_route_points_assoc en una única transacción atómica.
wstops: JSONB array [{id_point, dist_from_start?, eta_seconds?}...] en el orden secuencial deseado.
Si cualquier parada falla, toda la ruta se revierte.';


--
-- Name: fun_create_route_point(character varying, double precision, double precision, smallint, text, boolean, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_route_point(wname_point character varying, wlat double precision, wlng double precision, wpoint_type smallint DEFAULT 1, wdescrip_point text DEFAULT NULL::text, wis_checkpoint boolean DEFAULT false, wuser_create smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint) RETURNS record
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


--
-- Name: FUNCTION fun_create_route_point(wname_point character varying, wlat double precision, wlng double precision, wpoint_type smallint, wdescrip_point text, wis_checkpoint boolean, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_route_point(wname_point character varying, wlat double precision, wlng double precision, wpoint_type smallint, wdescrip_point text, wis_checkpoint boolean, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint) IS 'v1.0 â€” Crea un punto de ruta en tab_route_points. Acepta lat/lng por separado y construye el GEOMETRY internamente con ST_MakePoint(lng, lat). Retorna out_id_point.';


--
-- Name: fun_create_transit_doc_type(character varying, character varying, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_transit_doc_type(p_tag character varying, p_name character varying, p_descrip text, p_mandatory boolean, p_has_expiration boolean) RETURNS TABLE(success boolean, msg text, error_code character varying, out_id_doc smallint)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fun_create_trip(smallint, date, time without time zone, time without time zone, smallint, smallint, bigint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_trip(wid_route smallint, wtrip_date date, wstart_time time without time zone, wend_time time without time zone, wuser_create smallint, wid_bus smallint DEFAULT NULL::smallint, wid_driver bigint DEFAULT NULL::bigint, wid_status smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip integer) RETURNS record
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


--
-- Name: FUNCTION fun_create_trip(wid_route smallint, wtrip_date date, wstart_time time without time zone, wend_time time without time zone, wuser_create smallint, wid_bus smallint, wid_driver bigint, wid_status smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_trip(wid_route smallint, wtrip_date date, wstart_time time without time zone, wend_time time without time zone, wuser_create smallint, wid_bus smallint, wid_driver bigint, wid_status smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip integer) IS 'v1.0 â€” Crea un viaje en tab_trips. id_trip generado por IDENTITY automÃ¡ticamente. ValidaciÃ³n de negocio delegada al backend y constraints de BD. CÃ³digos de error: TRIP_UNIQUE_VIOLATION, TRIP_CHECK_VIOLATION, TRIP_FK_VIOLATION, TRIP_INSERT_ERROR.';


--
-- Name: fun_create_trips_batch(smallint, date, jsonb, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_trips_batch(wid_route smallint, wtrip_date date, wtrips jsonb, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT trips_created integer, OUT trips_failed integer, OUT trip_ids integer[]) RETURNS record
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_trip     JSONB;
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


--
-- Name: FUNCTION fun_create_trips_batch(wid_route smallint, wtrip_date date, wtrips jsonb, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT trips_created integer, OUT trips_failed integer, OUT trip_ids integer[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_trips_batch(wid_route smallint, wtrip_date date, wtrips jsonb, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT trips_created integer, OUT trips_failed integer, OUT trip_ids integer[]) IS 'v1.0 â€” Crea viajes en lote desde JSONB. id_trip por IDENTITY. Un viaje fallido no aborta el batch. JSONB: [{start_time, end_time, id_bus?, id_driver?, id_status?}]. Errores por viaje en campo msg: TRIP_UNIQUE, TRIP_CHECK, TRIP_FK, TRIP_ERROR. Falla total: TRIPS_ARRAY_EMPTY, ALL_TRIPS_FAILED.';


--
-- Name: fun_create_user(character varying, character varying, character varying, smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_create_user(wemail_user character varying, wpass_user character varying, wfull_name character varying, wid_role smallint, wuser_create smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying, OUT id_user smallint) RETURNS record
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


--
-- Name: FUNCTION fun_create_user(wemail_user character varying, wpass_user character varying, wfull_name character varying, wid_role smallint, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT id_user smallint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_create_user(wemail_user character varying, wpass_user character varying, wfull_name character varying, wid_role smallint, wuser_create smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT id_user smallint) IS 'v2.0 â€” Crea usuario en tab_users + asigna rol en tab_user_roles. Normaliza email y nombre; validaciÃ³n de negocio delegada al backend y constraints de BD. id_user generado por IDENTITY (SMALLINT).';


--
-- Name: fun_finalize_expired_trips(date, time without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_finalize_expired_trips(wp_date date, wp_time time without time zone) RETURNS void
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
        RAISE NOTICE 'fun_finalize_expired_trips: % viaje(s) finalizado(s) automáticamente para %', v_rows, wp_date;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'fun_finalize_expired_trips: error al finalizar viajes vencidos para % — % (%)',
            wp_date, SQLERRM, SQLSTATE;
END;
$$;


--
-- Name: fun_link_driver_account(bigint, smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_link_driver_account(wid_driver bigint, wid_user smallint, wassigned_by smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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
    msg        := 'El conductor o el usuario ya tiene un vínculo activo: ' || SQLERRM;
    error_code := 'ACCOUNT_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Conductor o usuario no válido: ' || SQLERRM;
    error_code := 'ACCOUNT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ACCOUNT_LINK_ERROR';
END;
$$;


--
-- Name: fun_remove_role(smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_remove_role(wid_user smallint, wid_role smallint, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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


--
-- Name: fun_reorder_route_points(smallint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_reorder_route_points(wid_route smallint, worder_json text, OUT success boolean, OUT msg text, OUT error_code character varying, OUT updated_count integer) RETURNS record
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
  -- Ejemplo: order 1 → 10001, order 2 → 10002, etc. (todos > 0, todos únicos)
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
    msg           := 'JSON de orden inválido: ' || SQLERRM;
    error_code    := 'ROUTE_REORDER_JSON_ERROR';
    updated_count := 0;
  WHEN check_violation THEN
    msg           := 'Valor de order inválido (debe ser > 0): ' || SQLERRM;
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


--
-- Name: FUNCTION fun_reorder_route_points(wid_route smallint, worder_json text, OUT success boolean, OUT msg text, OUT error_code character varying, OUT updated_count integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_reorder_route_points(wid_route smallint, worder_json text, OUT success boolean, OUT msg text, OUT error_code character varying, OUT updated_count integer) IS 'v1.0 — Reordena atómicamente los puntos de una ruta (tab_route_points_assoc). Usa valores temporales negativos para evitar conflictos de PK durante el UPDATE en cascada. Recibe el nuevo orden como JSON array [{id_point, order}].';


--
-- Name: fun_resolve_incident(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_resolve_incident(wid_trip_incident integer, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: fun_toggle_arl(smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_arl(wid_arl smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: FUNCTION fun_toggle_arl(wid_arl smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_toggle_arl(wid_arl smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying, OUT out_is_active boolean) IS 'v1.0 â€” Invierte is_active de ARL en tab_arl. Retorna ARL_NOT_FOUND si el ID no existe. El mensaje indica si quedÃ³ activada o desactivada.';


--
-- Name: fun_toggle_brand(smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_brand(wid_brand smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: FUNCTION fun_toggle_brand(wid_brand smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_toggle_brand(wid_brand smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying, OUT out_is_active boolean) IS 'v1.0 â€” Invierte is_active de marca en tab_brands. Retorna BRAND_NOT_FOUND si el ID no existe. El mensaje indica si quedÃ³ activada o desactivada.';


--
-- Name: fun_toggle_bus_status(character varying, boolean, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_bus_status(wplate_number character varying, wis_active boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_bus smallint, OUT new_status boolean) RETURNS record
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


--
-- Name: fun_toggle_company(smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_company(wid_company smallint, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying, OUT out_is_active boolean) RETURNS record
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
    msg        := 'No se encontró la compañía con ID: ' || wid_company;
    error_code := 'COMPANY_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Compañía ' || CASE WHEN out_is_active THEN 'activada' ELSE 'desactivada' END
             || ' exitosamente: ' || out_company_name;

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'Usuario actualizador no válido: ' || SQLERRM;
    error_code := 'COMPANY_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'COMPANY_TOGGLE_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_toggle_company(wid_company smallint, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_toggle_company(wid_company smallint, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying, OUT out_is_active boolean) IS 'v1.0 — Invierte is_active de compañía en tab_companies. Registra user_update y updated_at. Retorna COMPANY_NOT_FOUND si el ID no existe.';


--
-- Name: fun_toggle_driver_status(bigint, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_driver_status(wid_driver bigint, wis_active boolean, OUT success boolean, OUT msg text, OUT error_code character varying, OUT new_status boolean) RETURNS record
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


--
-- Name: fun_toggle_eps(smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_eps(wid_eps smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: FUNCTION fun_toggle_eps(wid_eps smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_toggle_eps(wid_eps smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying, OUT out_is_active boolean) IS 'v1.0 â€” Invierte is_active de EPS en tab_eps. Retorna EPS_NOT_FOUND si el ID no existe. El mensaje indica si quedÃ³ activada o desactivada.';


--
-- Name: fun_toggle_incident_type(smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_incident_type(wid_incident smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_type smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: fun_toggle_insurance_type(smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_insurance_type(p_id_type smallint) RETURNS TABLE(success boolean, msg text, error_code character varying, out_id_type smallint, out_name character varying, out_is_active boolean)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fun_toggle_insurer(smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_insurer(wid_insurer smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: FUNCTION fun_toggle_insurer(wid_insurer smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_toggle_insurer(wid_insurer smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying, OUT out_is_active boolean) IS 'v1.0 â€” Invierte is_active de aseguradora en tab_insurers. Retorna INSURER_NOT_FOUND si el ID no existe. El mensaje indica si quedÃ³ activada o desactivada.';


--
-- Name: fun_toggle_route(smallint, boolean, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_route(wid_route smallint, wis_active boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT new_status boolean) RETURNS record
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


--
-- Name: FUNCTION fun_toggle_route(wid_route smallint, wis_active boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT new_status boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_toggle_route(wid_route smallint, wis_active boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT new_status boolean) IS 'v1.0 â€” Activa o desactiva una ruta en tab_routes. La verificaciÃ³n de viajes/turnos activos debe hacerse en el backend antes de llamar esta funciÃ³n.';


--
-- Name: fun_toggle_route_point(smallint, boolean, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_route_point(wid_point smallint, wis_active boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint, OUT new_status boolean) RETURNS record
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


--
-- Name: FUNCTION fun_toggle_route_point(wid_point smallint, wis_active boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint, OUT new_status boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_toggle_route_point(wid_point smallint, wis_active boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint, OUT new_status boolean) IS 'v1.0 â€” Activa o desactiva un punto de ruta en tab_route_points. Usa RETURNING para detectar NOT FOUND. La regla de negocio (no desactivar si estÃ¡ en uso) debe validarla el backend antes de llamar esta funciÃ³n.';


--
-- Name: fun_toggle_transit_doc_type(smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_transit_doc_type(p_id_doc smallint) RETURNS TABLE(success boolean, msg text, error_code character varying, out_id_doc smallint, out_name character varying, out_is_active boolean)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fun_toggle_user_status(smallint, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_toggle_user_status(wid_user smallint, wis_active boolean, OUT success boolean, OUT msg text, OUT error_code character varying, OUT new_status boolean) RETURNS record
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


--
-- Name: fun_unassign_driver(bigint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_unassign_driver(wid_driver bigint, wunassigned_by smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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


--
-- Name: fun_unassign_route_point(smallint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_unassign_route_point(wid_route smallint, wid_point smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT out_id_point smallint, OUT out_point_order smallint) RETURNS record
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


--
-- Name: FUNCTION fun_unassign_route_point(wid_route smallint, wid_point smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT out_id_point smallint, OUT out_point_order smallint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_unassign_route_point(wid_route smallint, wid_point smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint, OUT out_id_point smallint, OUT out_point_order smallint) IS 'v1.0 â€” Elimina la asociaciÃ³n de un punto con una ruta (DELETE en tab_route_points_assoc). Retorna el point_order que tenÃ­a para que el backend pueda reordenar si es necesario.';


--
-- Name: fun_unlink_driver_account(bigint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_unlink_driver_account(wid_driver bigint, wunlinked_by smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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

  -- 3. Eliminar vínculo de tab_driver_accounts
  DELETE FROM tab_driver_accounts
  WHERE id_driver = wid_driver;

  success := TRUE;
  msg     := 'Cuenta desvinculada exitosamente (usuario ID: ' || v_id_user || ')';

EXCEPTION
  WHEN foreign_key_violation THEN
    msg        := 'No se puede desvincular: restricción de integridad referencial: ' || SQLERRM;
    error_code := 'ACCOUNT_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ACCOUNT_UNLINK_ERROR';
END;
$$;


--
-- Name: fun_update_arl(smallint, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_arl(wid_arl smallint, wname_arl character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: FUNCTION fun_update_arl(wid_arl smallint, wname_arl character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_arl(wid_arl smallint, wname_arl character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_arl smallint, OUT out_name character varying, OUT out_is_active boolean) IS 'v1.0 â€” Actualiza nombre de ARL en tab_arl. Normaliza con INITCAP/TRIM. Retorna ARL_NOT_FOUND si el ID no existe. ValidaciÃ³n de negocio delegada al backend.';


--
-- Name: fun_update_brand(smallint, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_brand(wid_brand smallint, wbrand_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: FUNCTION fun_update_brand(wid_brand smallint, wbrand_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_brand(wid_brand smallint, wbrand_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_brand smallint, OUT out_name character varying, OUT out_is_active boolean) IS 'v1.0 â€” Actualiza nombre de marca en tab_brands. Normaliza con INITCAP/TRIM. Retorna BRAND_NOT_FOUND si el ID no existe. ValidaciÃ³n de negocio delegada al backend.';


--
-- Name: fun_update_bus(character varying, character varying, character varying, smallint, smallint, smallint, character varying, bigint, smallint, smallint, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_bus(wplate_number character varying, wamb_code character varying, wcode_internal character varying, wid_company smallint, wmodel_year smallint, wcapacity_bus smallint, wcolor_bus character varying, wid_owner bigint, wuser_update smallint, wid_brand smallint DEFAULT NULL::smallint, wmodel_name character varying DEFAULT 'SA'::character varying, wchassis_number character varying DEFAULT 'SA'::character varying, wphoto_url character varying DEFAULT NULL::character varying, wgps_device_id character varying DEFAULT NULL::character varying, wcolor_app character varying DEFAULT '#CCCCCC'::character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_bus smallint, OUT out_plate character varying) RETURNS record
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


--
-- Name: FUNCTION fun_update_bus(wplate_number character varying, wamb_code character varying, wcode_internal character varying, wid_company smallint, wmodel_year smallint, wcapacity_bus smallint, wcolor_bus character varying, wid_owner bigint, wuser_update smallint, wid_brand smallint, wmodel_name character varying, wchassis_number character varying, wphoto_url character varying, wgps_device_id character varying, wcolor_app character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_bus smallint, OUT out_plate character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_bus(wplate_number character varying, wamb_code character varying, wcode_internal character varying, wid_company smallint, wmodel_year smallint, wcapacity_bus smallint, wcolor_bus character varying, wid_owner bigint, wuser_update smallint, wid_brand smallint, wmodel_name character varying, wchassis_number character varying, wphoto_url character varying, wgps_device_id character varying, wcolor_app character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_bus smallint, OUT out_plate character varying) IS 'v2.1 â€” Actualiza bus en tab_buses. Busca por plate_number (Ãºnico), retorna id_bus (PK surrogate). NormalizaciÃ³n inline en SET. ValidaciÃ³n delegada al backend y constraints de BD.';


--
-- Name: fun_update_company(smallint, character varying, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_company(wid_company smallint, wcompany_name character varying, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying, OUT out_is_active boolean) RETURNS record
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
    msg        := 'No se encontró la compañía con ID: ' || wid_company;
    error_code := 'COMPANY_NOT_FOUND';
    RETURN;
  END IF;

  success := TRUE;
  msg     := 'Compañía actualizada exitosamente: ' || out_company_name;

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Ya existe una compañía con ese nombre: ' || SQLERRM;
    error_code := 'COMPANY_UNIQUE_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Usuario actualizador no válido: ' || SQLERRM;
    error_code := 'COMPANY_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'COMPANY_UPDATE_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_update_company(wid_company smallint, wcompany_name character varying, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_company(wid_company smallint, wcompany_name character varying, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_company smallint, OUT out_company_name character varying, OUT out_nit_company character varying, OUT out_is_active boolean) IS 'v1.0 — Actualiza company_name en tab_companies. NIT es inmutable. Registra user_update y updated_at. Retorna COMPANY_NOT_FOUND si el ID no existe.';


--
-- Name: fun_update_driver(bigint, smallint, character varying, character varying, character varying, character varying, date, character varying, character varying, date, smallint, smallint, character varying, character varying, character varying, date, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_driver(wid_driver bigint, wuser_update smallint, wname_driver character varying DEFAULT 'SIN NOMBRE'::character varying, waddress_driver character varying DEFAULT 'SIN DIRECCIÓN'::character varying, wphone_driver character varying DEFAULT '0900000000'::character varying, wemail_driver character varying DEFAULT 'sa@sa.com'::character varying, wbirth_date date DEFAULT '2000-01-01'::date, wgender_driver character varying DEFAULT 'O'::character varying, wlicense_cat character varying DEFAULT 'SA'::character varying, wlicense_exp date DEFAULT '2000-01-01'::date, wid_eps smallint DEFAULT 1, wid_arl smallint DEFAULT 1, wblood_type character varying DEFAULT 'SA'::character varying, wemergency_contact character varying DEFAULT 'SIN CONTACTO'::character varying, wemergency_phone character varying DEFAULT '0900000000'::character varying, wdate_entry date DEFAULT CURRENT_DATE, wid_status smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_driver bigint) RETURNS record
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
    address_driver    = COALESCE(NULLIF(TRIM(waddress_driver),         ''), 'SIN DIRECCIÓN'),
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
    msg        := 'Conductor no encontrado con cédula: ' || wid_driver;
    error_code := 'DRIVER_NOT_FOUND'; RETURN;
  END IF;

  success    := TRUE;
  out_driver := wid_driver;
  msg        := 'Conductor actualizado exitosamente (Cédula: ' || wid_driver || ')';

EXCEPTION
  WHEN unique_violation THEN
    msg        := 'Email ya registrado en otro conductor: ' || SQLERRM;
    error_code := 'DRIVER_UNIQUE_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Restricción CHECK violada: ' || SQLERRM;
    error_code := 'DRIVER_CHECK_VIOLATION';
  WHEN foreign_key_violation THEN
    msg        := 'Clave foránea inválida (eps, arl o status): ' || SQLERRM;
    error_code := 'DRIVER_FK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'DRIVER_UPDATE_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_update_driver(wid_driver bigint, wuser_update smallint, wname_driver character varying, waddress_driver character varying, wphone_driver character varying, wemail_driver character varying, wbirth_date date, wgender_driver character varying, wlicense_cat character varying, wlicense_exp date, wid_eps smallint, wid_arl smallint, wblood_type character varying, wemergency_contact character varying, wemergency_phone character varying, wdate_entry date, wid_status smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_driver bigint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_driver(wid_driver bigint, wuser_update smallint, wname_driver character varying, waddress_driver character varying, wphone_driver character varying, wemail_driver character varying, wbirth_date date, wgender_driver character varying, wlicense_cat character varying, wlicense_exp date, wid_eps smallint, wid_arl smallint, wblood_type character varying, wemergency_contact character varying, wemergency_phone character varying, wdate_entry date, wid_status smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_driver bigint) IS 'v2.1 — Actualiza conductor en tab_drivers. Eliminado wid_user (vínculo con tab_users movido a tab_driver_accounts). Normalización inline en SET. Validación delegada al backend y constraints de BD.';


--
-- Name: fun_update_eps(smallint, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_eps(wid_eps smallint, wname_eps character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: FUNCTION fun_update_eps(wid_eps smallint, wname_eps character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_eps(wid_eps smallint, wname_eps character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_eps smallint, OUT out_name character varying, OUT out_is_active boolean) IS 'v1.0 â€” Actualiza nombre de EPS en tab_eps. Normaliza con INITCAP/TRIM. Retorna EPS_NOT_FOUND si el ID no existe. ValidaciÃ³n de negocio delegada al backend.';


--
-- Name: fun_update_incident_type(smallint, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_incident_type(wid_incident smallint, wname_incident character varying, wtag_incident character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_type smallint, OUT out_name character varying, OUT out_tag character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: fun_update_insurance_type(character varying, character varying, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_insurance_type(p_id_type character varying, p_name character varying, p_descrip text, p_mandatory boolean) RETURNS TABLE(success boolean, msg text, error_code character varying, out_id_type character varying, out_name character varying, out_is_active boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_active BOOLEAN;
BEGIN
    UPDATE tab_insurance_types
    SET type_name = p_name,
        descrip_insurance = p_descrip,
        is_mandatory = p_mandatory
    WHERE id_insurance_type = p_id_type
    RETURNING is_active INTO v_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de seguro no encontrado.'::TEXT, 'INSURANCE_TYPE_NOT_FOUND'::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Tipo de seguro actualizado correctamente.'::TEXT, NULL::VARCHAR, p_id_type, p_name, v_active;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$;


--
-- Name: fun_update_insurance_type(smallint, character varying, character varying, text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_insurance_type(p_id_type smallint, p_tag character varying, p_name character varying, p_descrip text, p_mandatory boolean) RETURNS TABLE(success boolean, msg text, error_code character varying, out_id_type smallint, out_name character varying, out_is_active boolean)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fun_update_insurer(smallint, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_insurer(wid_insurer smallint, winsurer_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying, OUT out_is_active boolean) RETURNS record
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


--
-- Name: FUNCTION fun_update_insurer(wid_insurer smallint, winsurer_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying, OUT out_is_active boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_insurer(wid_insurer smallint, winsurer_name character varying, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_insurer smallint, OUT out_name character varying, OUT out_is_active boolean) IS 'v1.0 â€” Actualiza nombre de aseguradora en tab_insurers. Normaliza con INITCAP/TRIM. Retorna INSURER_NOT_FOUND si el ID no existe. ValidaciÃ³n de negocio delegada al backend.';


--
-- Name: fun_update_role_permissions(smallint, jsonb, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_role_permissions(wid_role smallint, wpermissions_json jsonb, wuser_update smallint DEFAULT 1) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fun_update_route(smallint, character varying, character varying, smallint, smallint, text, time without time zone, time without time zone, character varying, character varying, smallint, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_route(wid_route smallint, wname_route character varying, wcolor_route character varying, wid_company smallint, wuser_update smallint, wdescrip_route text DEFAULT NULL::text, wfirst_trip time without time zone DEFAULT NULL::time without time zone, wlast_trip time without time zone DEFAULT NULL::time without time zone, wdeparture_route_sign character varying DEFAULT NULL::character varying, wreturn_route_sign character varying DEFAULT NULL::character varying, wroute_fare smallint DEFAULT 0, wis_circular boolean DEFAULT true, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint) RETURNS record
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
    msg        := 'Compañía o usuario no existe: ' || SQLERRM;
    error_code := 'ROUTE_FK_VIOLATION';
  WHEN check_violation THEN
    msg        := 'Valor fuera de rango (color inválido o first_trip >= last_trip): ' || SQLERRM;
    error_code := 'ROUTE_CHECK_VIOLATION';
  WHEN OTHERS THEN
    msg        := 'Error inesperado: ' || SQLERRM;
    error_code := 'ROUTE_UPDATE_ERROR';
END;
$$;


--
-- Name: FUNCTION fun_update_route(wid_route smallint, wname_route character varying, wcolor_route character varying, wid_company smallint, wuser_update smallint, wdescrip_route text, wfirst_trip time without time zone, wlast_trip time without time zone, wdeparture_route_sign character varying, wreturn_route_sign character varying, wroute_fare smallint, wis_circular boolean, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_route(wid_route smallint, wname_route character varying, wcolor_route character varying, wid_company smallint, wuser_update smallint, wdescrip_route text, wfirst_trip time without time zone, wlast_trip time without time zone, wdeparture_route_sign character varying, wreturn_route_sign character varying, wroute_fare smallint, wis_circular boolean, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_route smallint) IS 'v1.2 — Actualiza los metadatos de una ruta (tab_routes), incluyendo route_fare (tarifa) e is_circular (circuito cerrado). path_route es inmutable.';


--
-- Name: fun_update_route_point(smallint, character varying, double precision, double precision, smallint, text, boolean, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_route_point(wid_point smallint, wname_point character varying, wlat double precision, wlng double precision, wpoint_type smallint, wdescrip_point text DEFAULT NULL::text, wis_checkpoint boolean DEFAULT false, wuser_update smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint) RETURNS record
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


--
-- Name: FUNCTION fun_update_route_point(wid_point smallint, wname_point character varying, wlat double precision, wlng double precision, wpoint_type smallint, wdescrip_point text, wis_checkpoint boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_route_point(wid_point smallint, wname_point character varying, wlat double precision, wlng double precision, wpoint_type smallint, wdescrip_point text, wis_checkpoint boolean, wuser_update smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_point smallint) IS 'v1.0 â€” Actualiza un punto de ruta en tab_route_points identificado por id_point. Usa RETURNING para detectar NOT FOUND. No modifica id_point, is_active, created_at ni user_create.';


--
-- Name: fun_update_transit_doc_type(character varying, character varying, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_transit_doc_type(p_id_doc character varying, p_name character varying, p_descrip text, p_mandatory boolean, p_has_expiration boolean) RETURNS TABLE(success boolean, msg text, error_code character varying, out_id_doc character varying, out_name character varying, out_is_active boolean)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_active BOOLEAN;
BEGIN
    UPDATE tab_transit_documents
    SET name_doc = p_name,
        descrip_doc = p_descrip,
        is_mandatory = p_mandatory,
        has_expiration = p_has_expiration
    WHERE id_doc = p_id_doc
    RETURNING is_active INTO v_active;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Tipo de documento no encontrado.'::TEXT, 'TRANSIT_DOC_NOT_FOUND'::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::BOOLEAN;
    ELSE
        RETURN QUERY SELECT TRUE, 'Tipo de documento actualizado correctamente.'::TEXT, NULL::VARCHAR, p_id_doc, p_name, v_active;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT FALSE, SQLERRM::TEXT, 'DB_ERROR'::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::BOOLEAN;
END;
$$;


--
-- Name: fun_update_transit_doc_type(smallint, character varying, character varying, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_transit_doc_type(p_id_doc smallint, p_tag character varying, p_name character varying, p_descrip text, p_mandatory boolean, p_has_expiration boolean) RETURNS TABLE(success boolean, msg text, error_code character varying, out_id_doc smallint, out_name character varying, out_is_active boolean)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fun_update_trip(integer, smallint, smallint, date, time without time zone, time without time zone, smallint, bigint, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_trip(wid_trip integer, wuser_update smallint, wid_route smallint DEFAULT NULL::smallint, wtrip_date date DEFAULT NULL::date, wstart_time time without time zone DEFAULT NULL::time without time zone, wend_time time without time zone DEFAULT NULL::time without time zone, wid_bus smallint DEFAULT NULL::smallint, wid_driver bigint DEFAULT NULL::bigint, wid_status smallint DEFAULT NULL::smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip integer) RETURNS record
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


--
-- Name: FUNCTION fun_update_trip(wid_trip integer, wuser_update smallint, wid_route smallint, wtrip_date date, wstart_time time without time zone, wend_time time without time zone, wid_bus smallint, wid_driver bigint, wid_status smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_trip(wid_trip integer, wuser_update smallint, wid_route smallint, wtrip_date date, wstart_time time without time zone, wend_time time without time zone, wid_bus smallint, wid_driver bigint, wid_status smallint, OUT success boolean, OUT msg text, OUT error_code character varying, OUT out_id_trip integer) IS 'v2.0 - Actualiza viaje con soporte parcial (NULL=sin cambio, 0=desasignar id_bus/id_driver). Gestiona started_at en status=3 y completed_at en status=4. Para cancelar usar fun_cancel_trip.';


--
-- Name: fun_update_user(smallint, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_user(wid_user smallint, wfull_name character varying DEFAULT NULL::character varying, wemail_user character varying DEFAULT NULL::character varying, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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


--
-- Name: FUNCTION fun_update_user(wid_user smallint, wfull_name character varying, wemail_user character varying, OUT success boolean, OUT msg text, OUT error_code character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fun_update_user(wid_user smallint, wfull_name character varying, wemail_user character varying, OUT success boolean, OUT msg text, OUT error_code character varying) IS 'v2.0 â€” Actualiza full_name y/o email_user en tab_users. NULL = conservar valor actual (COALESCE en SET). ValidaciÃ³n delegada al backend y constraints de BD.';


--
-- Name: fun_update_user_permissions(smallint, jsonb, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fun_update_user_permissions(wid_user smallint, woverrides_json jsonb, wuser_update smallint DEFAULT 1, OUT success boolean, OUT msg text, OUT error_code character varying) RETURNS record
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

  -- 1. Eliminar TODOS los overrides actuales del usuario (reemplazo atómico)
  DELETE FROM tab_user_permissions WHERE id_user = wid_user;

  -- 2. Insertar los nuevos overrides si se envió un arreglo no vacío
  IF woverrides_json IS NOT NULL AND jsonb_array_length(woverrides_json) > 0 THEN
    FOR v_override IN SELECT jsonb_array_elements(woverrides_json)
    LOOP
      -- Casteo y extracción del JSON
      v_perm_code  := UPPER(TRIM(v_override->>'code'));
      v_is_granted := (v_override->>'is_granted')::BOOLEAN;

      -- Buscar el id_permission por código
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: tab_arl; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_arl (
    id_arl smallint NOT NULL,
    name_arl character varying(60) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: tab_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_audit_log (
    id bigint NOT NULL,
    table_name character varying(50) NOT NULL,
    record_id text,
    operation character(1) NOT NULL,
    old_data jsonb,
    new_data jsonb,
    changed_by smallint,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_audit_op CHECK ((operation = ANY (ARRAY['I'::bpchar, 'U'::bpchar, 'D'::bpchar])))
);


--
-- Name: TABLE tab_audit_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_audit_log IS 'Registro inmutable de cambios en tablas críticas de BucaraBUS.';


--
-- Name: COLUMN tab_audit_log.record_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_audit_log.record_id IS 'PK del registro afectado. Para PKs compuestas se usa ''col1|col2''.';


--
-- Name: COLUMN tab_audit_log.old_data; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_audit_log.old_data IS 'Snapshot completo antes del cambio. NULL en INSERT. Geometría excluida.';


--
-- Name: COLUMN tab_audit_log.new_data; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_audit_log.new_data IS 'Snapshot completo después del cambio. NULL en DELETE. Geometría excluida.';


--
-- Name: COLUMN tab_audit_log.changed_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_audit_log.changed_by IS 'ID del usuario que realizó el cambio. Sin FK para preservar historial.';


--
-- Name: tab_audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_brands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_brands (
    id_brand smallint NOT NULL,
    brand_name character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE tab_brands; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_brands IS 'Catálogo de marcas de buses (Mercedes-Benz, Volvo, Scania, etc.).';


--
-- Name: tab_bus_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_bus_assignments (
    id_bus smallint NOT NULL,
    id_driver bigint NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    unassigned_at timestamp with time zone,
    assigned_by smallint DEFAULT 1 NOT NULL,
    unassigned_by smallint,
    CONSTRAINT chk_assignments_dates CHECK (((unassigned_at IS NULL) OR (unassigned_at >= assigned_at)))
);


--
-- Name: TABLE tab_bus_assignments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_bus_assignments IS 'Historial de asignaciones bus-conductor';


--
-- Name: COLUMN tab_bus_assignments.assigned_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_bus_assignments.assigned_by IS 'ID del usuario que realizó la asignación (FK a tab_users)';


--
-- Name: COLUMN tab_bus_assignments.unassigned_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_bus_assignments.unassigned_by IS 'ID del usuario que realizó la desasignación (FK a tab_users)';


--
-- Name: tab_bus_insurance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_bus_insurance (
    id_bus smallint NOT NULL,
    id_insurance_type smallint NOT NULL,
    id_insurance character varying(50) NOT NULL,
    id_insurer smallint NOT NULL,
    start_date_insu date NOT NULL,
    end_date_insu date NOT NULL,
    doc_url character varying(500),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    user_create smallint DEFAULT 1 NOT NULL,
    user_update smallint,
    CONSTRAINT chk_insurance_dates CHECK ((end_date_insu > start_date_insu))
);


--
-- Name: TABLE tab_bus_insurance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_bus_insurance IS 'Póliza vigente de cada tipo de seguro por bus. PK (id_bus, id_insurance_type) garantiza un único registro por tipo. Al renovar se hace DELETE + INSERT para que el trigger de auditoría registre ambos eventos. Vigencia: CURRENT_DATE BETWEEN start_date_insu AND end_date_insu.';


--
-- Name: tab_bus_owners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_bus_owners (
    id_owner bigint NOT NULL,
    full_name character varying(100) NOT NULL,
    phone_owner character varying(15) NOT NULL,
    email_owner character varying(320),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    user_create smallint DEFAULT 1 NOT NULL,
    user_update smallint,
    CONSTRAINT chk_owners_email CHECK (((email_owner IS NULL) OR ((email_owner)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_owners_phone CHECK (((phone_owner)::text ~ '^[0-9]{7,15}$'::text))
);


--
-- Name: TABLE tab_bus_owners; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_bus_owners IS 'Propietarios de buses. Un propietario puede tener múltiples buses.';


--
-- Name: tab_bus_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_bus_statuses (
    id_status smallint NOT NULL,
    status_name character varying(30) NOT NULL,
    descrip_status text,
    color_hex character varying(7),
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_bus_status_color CHECK (((color_hex IS NULL) OR ((color_hex)::text ~ '^#[0-9A-Fa-f]{6}$'::text)))
);


--
-- Name: TABLE tab_bus_statuses; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_bus_statuses IS 'Catálogo de estados operativos del bus: disponible, en_ruta, mantenimiento, fuera_de_servicio.';


--
-- Name: tab_bus_transit_docs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_bus_transit_docs (
    id_doc smallint NOT NULL,
    id_bus smallint NOT NULL,
    doc_number character varying(50) NOT NULL,
    init_date date,
    end_date date,
    doc_url character varying(500),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    user_create smallint DEFAULT 1 NOT NULL,
    user_update smallint,
    CONSTRAINT chk_transit_doc_dates CHECK ((end_date > init_date))
);


--
-- Name: TABLE tab_bus_transit_docs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_bus_transit_docs IS 'Documento de tránsito vigente de cada tipo por bus. PK (id_doc, id_bus) garantiza un único registro por tipo. Al renovar se hace DELETE + INSERT para que el trigger de auditoría registre ambos eventos. Vigencia: CURRENT_DATE BETWEEN init_date AND end_date.';


--
-- Name: tab_buses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_buses (
    id_bus smallint NOT NULL,
    plate_number character varying(6) NOT NULL,
    amb_code character varying(8) NOT NULL,
    code_internal character varying(5) NOT NULL,
    id_company smallint NOT NULL,
    id_brand smallint,
    model_name character varying(50) DEFAULT 'SIN MODELO'::character varying NOT NULL,
    model_year smallint DEFAULT 2000 NOT NULL,
    capacity_bus smallint DEFAULT 1 NOT NULL,
    chassis_number character varying(50) DEFAULT 'SIN CHASIS'::character varying NOT NULL,
    color_bus character varying(30) DEFAULT 'SIN COLOR'::character varying NOT NULL,
    color_app character varying(7) DEFAULT '#CCCCCC'::character varying,
    photo_url character varying(500) DEFAULT 'SIN FOTO'::character varying,
    gps_device_id character varying(20),
    id_owner bigint NOT NULL,
    id_status smallint DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    user_create smallint DEFAULT 1 NOT NULL,
    user_update smallint,
    CONSTRAINT chk_buses_amb_code_format CHECK ((((amb_code)::text ~ '^[A-Z]{3}-[0-9]{4}$'::text) OR ((amb_code)::text = 'SA'::text))),
    CONSTRAINT chk_buses_capacity CHECK (((capacity_bus > 0) AND (capacity_bus <= 70))),
    CONSTRAINT chk_buses_model_year CHECK ((model_year >= 1990)),
    CONSTRAINT chk_buses_plate_format CHECK (((plate_number)::text ~ '^[A-Z]{3}[0-9]{3}$'::text))
);


--
-- Name: TABLE tab_buses; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_buses IS 'Catálogo de buses del sistema de transporte. is_active = eliminación lógica; id_status = estado operativo.';


--
-- Name: COLUMN tab_buses.id_brand; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_buses.id_brand IS 'FK nullable a tab_brands. NULL = marca no especificada.';


--
-- Name: COLUMN tab_buses.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_buses.created_at IS 'Fecha y hora de creación del registro';


--
-- Name: COLUMN tab_buses.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_buses.updated_at IS 'Fecha y hora de última actualización';


--
-- Name: COLUMN tab_buses.user_create; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_buses.user_create IS 'ID del usuario administrador que creó el bus (FK a tab_users)';


--
-- Name: COLUMN tab_buses.user_update; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_buses.user_update IS 'ID del usuario administrador que actualizó el bus por última vez (FK a tab_users)';


--
-- Name: tab_buses_id_bus_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_buses ALTER COLUMN id_bus ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_buses_id_bus_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_companies (
    id_company smallint NOT NULL,
    company_name character varying(100) NOT NULL,
    nit_company character varying(15) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    user_create smallint DEFAULT 1 NOT NULL,
    user_update smallint,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: tab_driver_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_driver_accounts (
    id_driver bigint NOT NULL,
    id_user smallint NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_by smallint DEFAULT 1 NOT NULL
);


--
-- Name: tab_driver_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_driver_statuses (
    id_status smallint NOT NULL,
    status_name character varying(30) NOT NULL,
    descrip_status text,
    color_hex character varying(7),
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_driver_status_color CHECK (((color_hex IS NULL) OR ((color_hex)::text ~ '^#[0-9A-Fa-f]{6}$'::text)))
);


--
-- Name: TABLE tab_driver_statuses; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_driver_statuses IS 'Catálogo de estados operativos del conductor: disponible, en_viaje, descanso, incapacitado, vacaciones, ausente, inactivo.';


--
-- Name: tab_drivers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_drivers (
    id_driver bigint NOT NULL,
    name_driver character varying(100) DEFAULT 'SIN NOMBRE'::character varying NOT NULL,
    address_driver character varying(200) DEFAULT 'SIN DIRECCION'::character varying NOT NULL,
    phone_driver character varying(15) DEFAULT '0900000000'::character varying NOT NULL,
    email_driver character varying(320) DEFAULT 'sa@sa.com'::character varying NOT NULL,
    birth_date date DEFAULT '2000-01-01'::date NOT NULL,
    gender_driver character varying(2) DEFAULT 'SA'::character varying NOT NULL,
    license_cat character varying(2) DEFAULT 'SA'::character varying NOT NULL,
    license_exp date DEFAULT '2000-01-01'::date NOT NULL,
    id_eps smallint DEFAULT 1 NOT NULL,
    id_arl smallint DEFAULT 1 NOT NULL,
    blood_type character varying(3) DEFAULT 'SA'::character varying NOT NULL,
    emergency_contact character varying(100) DEFAULT 'SIN CONTACTO'::character varying NOT NULL,
    emergency_phone character varying(15) DEFAULT '0900000000'::character varying NOT NULL,
    date_entry date DEFAULT CURRENT_DATE NOT NULL,
    id_status smallint DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_create smallint DEFAULT 1 NOT NULL,
    updated_at timestamp with time zone,
    user_update smallint,
    CONSTRAINT chk_driver_blood_type CHECK (((blood_type)::text = ANY ((ARRAY['SA'::character varying, 'A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'AB+'::character varying, 'AB-'::character varying, 'O+'::character varying, 'O-'::character varying])::text[]))),
    CONSTRAINT chk_driver_email_format CHECK (((email_driver)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT chk_driver_emergency_phone CHECK (((emergency_phone)::text ~ '^[0-9]{7,15}$'::text)),
    CONSTRAINT chk_driver_gender CHECK (((gender_driver)::text = ANY ((ARRAY['M'::character varying, 'F'::character varying, 'O'::character varying, 'SA'::character varying])::text[]))),
    CONSTRAINT chk_driver_license_cat CHECK (((license_cat)::text = ANY ((ARRAY['SA'::character varying, 'C1'::character varying, 'C2'::character varying, 'C3'::character varying])::text[]))),
    CONSTRAINT chk_driver_phone_format CHECK (((phone_driver)::text ~ '^[0-9]{7,15}$'::text))
);


--
-- Name: TABLE tab_drivers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_drivers IS 'Perfil operativo del conductor, identificado por cédula (id_driver). El vínculo con tab_users (acceso al sistema) se gestiona en tab_driver_accounts.';


--
-- Name: COLUMN tab_drivers.user_create; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_drivers.user_create IS 'ID del usuario administrador que creó este conductor';


--
-- Name: COLUMN tab_drivers.user_update; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_drivers.user_update IS 'ID del usuario administrador que actualizó este conductor';


--
-- Name: tab_eps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_eps (
    id_eps smallint NOT NULL,
    name_eps character varying(60) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: tab_gps_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_gps_history (
    id_position bigint NOT NULL,
    id_bus smallint NOT NULL,
    id_trip integer,
    location_shot public.geometry(Point,4326) NOT NULL,
    speed numeric(5,2),
    recorded_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_gps_speed CHECK (((speed IS NULL) OR (speed >= (0)::numeric)))
)
PARTITION BY RANGE (recorded_at);


--
-- Name: TABLE tab_gps_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_gps_history IS 'Historial de posiciones GPS. Solo INSERT. Particionada mensualmente por recorded_at. Purgar particiones antiguas con DROP TABLE tab_gps_history_YYYY_MM.';


--
-- Name: tab_gps_history_2026_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_gps_history_2026_03 (
    id_position bigint NOT NULL,
    id_bus smallint NOT NULL,
    id_trip integer,
    location_shot public.geometry(Point,4326) NOT NULL,
    speed numeric(5,2),
    recorded_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_gps_speed CHECK (((speed IS NULL) OR (speed >= (0)::numeric)))
);


--
-- Name: tab_gps_history_2026_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_gps_history_2026_04 (
    id_position bigint NOT NULL,
    id_bus smallint NOT NULL,
    id_trip integer,
    location_shot public.geometry(Point,4326) NOT NULL,
    speed numeric(5,2),
    recorded_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_gps_speed CHECK (((speed IS NULL) OR (speed >= (0)::numeric)))
);


--
-- Name: tab_gps_history_2026_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_gps_history_2026_05 (
    id_position bigint NOT NULL,
    id_bus smallint NOT NULL,
    id_trip integer,
    location_shot public.geometry(Point,4326) NOT NULL,
    speed numeric(5,2),
    recorded_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_gps_speed CHECK (((speed IS NULL) OR (speed >= (0)::numeric)))
);


--
-- Name: tab_gps_history_id_position_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_gps_history ALTER COLUMN id_position ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_gps_history_id_position_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_incident_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_incident_types (
    id_incident smallint NOT NULL,
    name_incident character varying(50) NOT NULL,
    tag_incident character varying(20) NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: tab_incident_types_id_incident_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_incident_types ALTER COLUMN id_incident ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_incident_types_id_incident_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_insurance_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_insurance_types (
    id_insurance_type smallint NOT NULL,
    name_insurance character varying(50) NOT NULL,
    tag_insurance character varying(5),
    descrip_insurance text,
    is_mandatory boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: tab_insurance_types_id_insurance_type_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_insurance_types ALTER COLUMN id_insurance_type ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_insurance_types_id_insurance_type_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_insurers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_insurers (
    id_insurer smallint NOT NULL,
    insurer_name character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE tab_insurers; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_insurers IS 'Catálogo de aseguradoras.';


--
-- Name: tab_parameters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_parameters (
    param_key character varying(50) NOT NULL,
    param_value text NOT NULL,
    data_type character varying(20) DEFAULT 'string'::character varying NOT NULL,
    descrip_param text,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    user_update smallint,
    CONSTRAINT chk_parameters_type CHECK (((data_type)::text = ANY ((ARRAY['string'::character varying, 'integer'::character varying, 'float'::character varying, 'boolean'::character varying, 'time'::character varying, 'json'::character varying])::text[])))
);


--
-- Name: TABLE tab_parameters; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_parameters IS 'Parámetros y configuraciones globales del sistema (ej: MAX_WORK_HOUR)';


--
-- Name: tab_password_reset_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_password_reset_tokens (
    id_token integer NOT NULL,
    id_user integer NOT NULL,
    token character varying(128) NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '01:00:00'::interval) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE tab_password_reset_tokens; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_password_reset_tokens IS 'Tokens de un solo uso para recuperación de contraseña. Expiran en 1 hora.';


--
-- Name: tab_password_reset_tokens_id_token_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_password_reset_tokens ALTER COLUMN id_token ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_password_reset_tokens_id_token_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_permissions (
    id_permission smallint NOT NULL,
    name_permission character varying(100) NOT NULL,
    code_permission character varying(50) NOT NULL,
    id_parent smallint,
    descrip_permission text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tab_permissions_id_permission_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_permissions ALTER COLUMN id_permission ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_permissions_id_permission_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_role_permissions (
    id_role smallint NOT NULL,
    id_permission smallint NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_by smallint DEFAULT 1 NOT NULL
);


--
-- Name: tab_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_roles (
    id_role smallint NOT NULL,
    role_name character varying(30) DEFAULT 'ROL SIN NOMBRE'::character varying NOT NULL,
    descrip_role text,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE tab_roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_roles IS 'Catálogo de roles del sistema: Administrador, Turnador, Conductor.';


--
-- Name: tab_route_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_route_points (
    id_point smallint NOT NULL,
    point_type smallint DEFAULT 1 NOT NULL,
    name_point character varying(100) NOT NULL,
    location_point public.geometry(Point,4326) NOT NULL,
    descrip_point text,
    is_checkpoint boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    user_create smallint DEFAULT 1 NOT NULL,
    user_update smallint,
    CONSTRAINT chk_route_points_type CHECK ((point_type = ANY (ARRAY[1, 2])))
);


--
-- Name: tab_route_points_assoc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_route_points_assoc (
    id_route smallint NOT NULL,
    id_point smallint NOT NULL,
    point_order smallint NOT NULL,
    dist_from_start numeric(7,3),
    eta_seconds integer,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT chk_route_points_assoc_dist CHECK (((dist_from_start IS NULL) OR (dist_from_start >= (0)::numeric))),
    CONSTRAINT chk_route_points_assoc_eta CHECK (((eta_seconds IS NULL) OR (eta_seconds >= 0))),
    CONSTRAINT chk_route_points_assoc_order CHECK ((point_order > 0))
);


--
-- Name: tab_route_points_id_point_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_route_points ALTER COLUMN id_point ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_route_points_id_point_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_routes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_routes (
    id_route smallint NOT NULL,
    name_route character varying(100) NOT NULL,
    path_route public.geometry(LineString,4326) NOT NULL,
    descrip_route text,
    color_route character varying(7) NOT NULL,
    id_company smallint NOT NULL,
    first_trip time without time zone,
    last_trip time without time zone,
    departure_route_sign character varying(100),
    return_route_sign character varying(100),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    user_create smallint DEFAULT 1 NOT NULL,
    user_update smallint,
    route_fare smallint DEFAULT 0 NOT NULL,
    is_circular boolean DEFAULT true,
    CONSTRAINT chk_routes_color CHECK (((color_route)::text ~ '^#[0-9A-Fa-f]{6}$'::text)),
    CONSTRAINT chk_routes_trip_times CHECK (((first_trip IS NULL) OR (last_trip IS NULL) OR (first_trip < last_trip))),
    CONSTRAINT tab_routes_route_fare_check CHECK ((route_fare >= 0))
);


--
-- Name: TABLE tab_routes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_routes IS 'Catálogo de rutas con geometría PostGIS';


--
-- Name: COLUMN tab_routes.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_routes.created_at IS 'Fecha y hora de creación del registro';


--
-- Name: COLUMN tab_routes.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_routes.updated_at IS 'Fecha y hora de última actualización';


--
-- Name: COLUMN tab_routes.user_create; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_routes.user_create IS 'ID del usuario administrador que creó la ruta (FK a tab_users)';


--
-- Name: COLUMN tab_routes.user_update; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_routes.user_update IS 'ID del usuario administrador que actualizó la ruta por última vez (FK a tab_users)';


--
-- Name: tab_routes_id_route_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_routes ALTER COLUMN id_route ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_routes_id_route_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_transit_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_transit_documents (
    id_doc smallint NOT NULL,
    name_doc character varying(100) NOT NULL,
    tag_transit_doc character varying(5),
    descrip_doc text,
    is_mandatory boolean DEFAULT true NOT NULL,
    has_expiration boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: tab_transit_documents_id_doc_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_transit_documents ALTER COLUMN id_doc ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_transit_documents_id_doc_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_trip_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_trip_events (
    id_event integer NOT NULL,
    id_trip integer NOT NULL,
    event_type character varying(20) NOT NULL,
    old_status smallint,
    new_status smallint,
    event_data jsonb,
    performed_by smallint,
    performed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE tab_trip_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_trip_events IS 'Historial de eventos y cambios de estado de viajes (auditoría inmutable)';


--
-- Name: COLUMN tab_trip_events.event_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trip_events.event_type IS 'Tipo de evento: created, assigned, started, completed, cancelled, reactivated, deleted';


--
-- Name: COLUMN tab_trip_events.old_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trip_events.old_status IS 'Estado del viaje antes del evento';


--
-- Name: COLUMN tab_trip_events.new_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trip_events.new_status IS 'Estado del viaje después del evento';


--
-- Name: COLUMN tab_trip_events.event_data; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trip_events.event_data IS 'Datos adicionales del evento en formato JSON (timestamps, razones, etc.)';


--
-- Name: COLUMN tab_trip_events.performed_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trip_events.performed_by IS 'ID del usuario que ejecutó la acción (conductor, administrador, sistema)';


--
-- Name: COLUMN tab_trip_events.performed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trip_events.performed_at IS 'Timestamp exacto del evento';


--
-- Name: tab_trip_incidents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_trip_incidents (
    id_trip_incident integer NOT NULL,
    id_trip integer NOT NULL,
    id_incident smallint NOT NULL,
    descrip_incident text,
    location_incident public.geometry(Point,4326) NOT NULL,
    status_incident character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    CONSTRAINT chk_incident_status CHECK (((status_incident)::text = ANY ((ARRAY['active'::character varying, 'resolved'::character varying])::text[])))
);


--
-- Name: tab_trip_incidents_id_trip_incident_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_trip_incidents ALTER COLUMN id_trip_incident ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_trip_incidents_id_trip_incident_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_trip_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_trip_statuses (
    id_status smallint NOT NULL,
    status_name character varying(20) NOT NULL,
    descrip_status text,
    color_hex character varying(7),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_create smallint DEFAULT 1 NOT NULL,
    CONSTRAINT chk_trip_statuses_color CHECK (((color_hex IS NULL) OR ((color_hex)::text ~ '^#[0-9A-Fa-f]{6}$'::text)))
);


--
-- Name: TABLE tab_trip_statuses; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_trip_statuses IS 'Catálogo de estados de viajes (pending, assigned, active, completed, cancelled)';


--
-- Name: COLUMN tab_trip_statuses.user_create; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trip_statuses.user_create IS 'ID del usuario que creó el estado (FK a tab_users)';


--
-- Name: tab_trips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_trips (
    id_trip integer NOT NULL,
    id_route smallint NOT NULL,
    trip_date date NOT NULL,
    start_time time(0) without time zone NOT NULL,
    end_time time(0) without time zone NOT NULL,
    id_bus smallint,
    id_driver bigint,
    id_status smallint DEFAULT 1 NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    cancellation_reason text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_create smallint DEFAULT 1 NOT NULL,
    updated_at timestamp with time zone,
    user_update smallint,
    CONSTRAINT chk_trips_times CHECK ((end_time > start_time))
);


--
-- Name: TABLE tab_trips; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_trips IS 'Turnos/viajes programados para las rutas';


--
-- Name: COLUMN tab_trips.started_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trips.started_at IS 'Timestamp real de inicio del viaje (puede cambiar si se reactiva)';


--
-- Name: COLUMN tab_trips.completed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trips.completed_at IS 'Timestamp real de finalización del viaje (puede volver a NULL si se reactiva)';


--
-- Name: COLUMN tab_trips.cancellation_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trips.cancellation_reason IS 'Motivo de cancelación del viaje. Solo aplica cuando id_status = 5 (cancelado)';


--
-- Name: COLUMN tab_trips.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trips.is_active IS 'Indicador de eliminación lógica (FALSE = eliminado, TRUE = activo)';


--
-- Name: COLUMN tab_trips.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trips.created_at IS 'Fecha y hora de creación del registro';


--
-- Name: COLUMN tab_trips.user_create; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trips.user_create IS 'ID del usuario administrador que creó el turno/viaje (FK a tab_users)';


--
-- Name: COLUMN tab_trips.updated_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trips.updated_at IS 'Fecha y hora de última actualización';


--
-- Name: COLUMN tab_trips.user_update; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_trips.user_update IS 'ID del usuario administrador que actualizó el turno/viaje (FK a tab_users)';


--
-- Name: tab_trips_id_trip_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_trips ALTER COLUMN id_trip ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_trips_id_trip_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_user_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_user_permissions (
    id_user integer NOT NULL,
    id_permission integer NOT NULL,
    is_granted boolean NOT NULL,
    assigned_by integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: tab_user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_user_roles (
    id_user smallint NOT NULL,
    id_role smallint NOT NULL,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_by smallint DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE tab_user_roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_user_roles IS 'Relación muchos-a-muchos: un usuario puede tener múltiples roles activos.';


--
-- Name: tab_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tab_users (
    id_user smallint NOT NULL,
    full_name character varying(100) NOT NULL,
    email_user character varying(320) NOT NULL,
    pass_user character varying(60) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_users_email_format CHECK (((email_user)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))
);


--
-- Name: TABLE tab_users; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tab_users IS 'Tabla de identidad y autenticación de usuarios del sistema';


--
-- Name: COLUMN tab_users.created_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tab_users.created_at IS 'Fecha de creación del usuario. Sin trigger de auditoría: tabla gestionada solo por admin.';


--
-- Name: tab_users_id_user_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tab_users ALTER COLUMN id_user ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.tab_users_id_user_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tab_gps_history_2026_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_gps_history ATTACH PARTITION public.tab_gps_history_2026_03 FOR VALUES FROM ('2026-03-01 00:00:00-05') TO ('2026-04-01 00:00:00-05');


--
-- Name: tab_gps_history_2026_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_gps_history ATTACH PARTITION public.tab_gps_history_2026_04 FOR VALUES FROM ('2026-04-01 00:00:00-05') TO ('2026-05-01 00:00:00-05');


--
-- Name: tab_gps_history_2026_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_gps_history ATTACH PARTITION public.tab_gps_history_2026_05 FOR VALUES FROM ('2026-05-01 00:00:00-05') TO ('2026-06-01 00:00:00-05');


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: tab_arl; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_arl (id_arl, name_arl, created_at, is_active) FROM stdin;
1	Sura ARL	2026-03-30 11:38:14.649135-05	t
2	Positiva ARL	2026-03-30 11:38:14.649135-05	t
3	Colmena Seguros	2026-03-30 11:38:14.649135-05	t
4	Bolívar ARL	2026-03-30 11:38:14.649135-05	t
5	Axa Colpatria ARL	2026-03-30 11:38:14.649135-05	t
6	Liberty Seguros	2026-03-30 11:38:14.649135-05	t
8	Equidad Seguros	2026-03-30 11:38:14.649135-05	t
9	Arl_Nueva	2026-03-30 12:13:30.075063-05	t
7	Alfa ARL	2026-03-30 11:38:14.649135-05	t
\.


--
-- Data for Name: tab_audit_log; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_audit_log (id, table_name, record_id, operation, old_data, new_data, changed_by, changed_at) FROM stdin;
1	tab_buses	14	I	\N	{"id_bus": 14, "amb_code": "AMB-0056", "id_brand": 9, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-18T15:14:33.619578+00:00", "id_company": 5, "model_name": "citaro", "model_year": 2022, "updated_at": null, "user_create": 1, "user_update": null, "capacity_bus": 23, "plate_number": "HDS223", "code_internal": "0019", "gps_device_id": "233435452143", "chassis_number": "211454541324"}	1	2026-04-18 10:14:33.619578-05
2	tab_buses	14	U	{"id_bus": 14, "amb_code": "AMB-0056", "id_brand": 9, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-18T15:14:33.619578+00:00", "id_company": 5, "model_name": "citaro", "model_year": 2022, "updated_at": null, "user_create": 1, "user_update": null, "capacity_bus": 23, "plate_number": "HDS223", "code_internal": "0019", "gps_device_id": "233435452143", "chassis_number": "211454541324"}	{"id_bus": 14, "amb_code": "AMB-0056", "id_brand": 9, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-18T15:14:33.619578+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-18T15:17:13.941999+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 23, "plate_number": "HDS223", "code_internal": "0019", "gps_device_id": "233435452143", "chassis_number": "211454541324"}	1	2026-04-18 10:17:13.941999-05
3	tab_route_points	150	I	\N	{"id_point": 150, "is_active": true, "created_at": "2026-04-19T06:20:37.683624+00:00", "name_point": "Calle 18 ## 17-3, Comuna 4 Occidental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-19 01:20:37.683624-05
4	tab_route_points	151	I	\N	{"id_point": 151, "is_active": true, "created_at": "2026-04-19T06:20:40.804593+00:00", "name_point": "Calle 18 ## 17-3, Comuna 4 Occidental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-19 01:20:40.804593-05
5	tab_routes	31	I	\N	{"id_route": 31, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:37:12.650943+00:00", "first_trip": "05:08:00", "id_company": 1, "name_route": "ruta nuevo metodo", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": "cabecera"}	1	2026-04-19 01:37:12.650943-05
6	tab_routes	32	I	\N	{"id_route": 32, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:37:20.394842+00:00", "first_trip": "05:08:00", "id_company": 1, "name_route": "ruta nuevo metodo", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": "cabecera"}	1	2026-04-19 01:37:20.394842-05
7	tab_routes	33	I	\N	{"id_route": 33, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:48:07.285433+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta nuevo metodo", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 01:48:07.285433-05
8	tab_routes	34	I	\N	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 01:56:44.202767-05
9	tab_routes	35	I	\N	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 02:11:12.813633-05
10	tab_routes	36	I	\N	{"id_route": 36, "is_active": true, "last_trip": null, "created_at": "2026-04-19T15:55:37.496239+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta Z", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 10:55:37.496239-05
11	tab_routes	37	I	\N	{"id_route": 37, "is_active": true, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": null, "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 12:01:07.688554-05
12	tab_routes	34	U	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:27.440684+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:24:27.440684-05
13	tab_routes	34	U	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:27.440684+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:29.445334+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:24:29.445334-05
41	tab_route_points	152	I	\N	{"id_point": 152, "is_active": true, "created_at": "2026-04-20T05:27:05.412693+00:00", "name_point": "Calle 115 ## 31-4, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:27:05.412693-05
14	tab_routes	34	U	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:29.445334+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:30.743757+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:24:30.743757-05
15	tab_routes	34	U	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:30.743757+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:37.899707+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:24:37.899707-05
16	tab_routes	34	U	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:37.899707+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:39.353202+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:24:39.353202-05
17	tab_routes	35	U	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:25:10.252217+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:25:10.252217-05
18	tab_routes	34	U	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:24:39.353202+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:46:24.897161+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:46:24.897161-05
19	tab_routes	34	U	{"id_route": 34, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:46:24.897161+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 34, "is_active": false, "last_trip": null, "created_at": "2026-04-19T06:56:44.202767+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22", "route_fare": 3000, "updated_at": "2026-04-19T21:46:24.938054+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:46:24.938054-05
20	tab_routes	35	U	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:25:10.252217+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:04.621993+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:48:04.621993-05
21	tab_routes	35	U	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:04.621993+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:04.642928+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:48:04.642928-05
42	tab_route_points	153	I	\N	{"id_point": 153, "is_active": true, "created_at": "2026-04-20T05:27:07.615011+00:00", "name_point": "Calle 115 ## 31-4, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:27:07.615011-05
22	tab_routes	35	U	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:04.642928+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:07.082105+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:48:07.082105-05
23	tab_routes	35	U	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:07.082105+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:07.095818+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:48:07.095818-05
24	tab_routes	35	U	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:07.095818+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:17.243008+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:48:17.243008-05
25	tab_routes	35	U	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:17.243008+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:17.261398+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:48:17.261398-05
26	tab_routes	37	U	{"id_route": 37, "is_active": true, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": null, "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 37, "is_active": true, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:48:59.930811+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:48:59.930811-05
27	tab_routes	37	U	{"id_route": 37, "is_active": true, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:48:59.930811+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:48:59.947833+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:48:59.947833-05
28	tab_routes	37	U	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:48:59.947833+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:49:19.452589+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:49:19.452589-05
29	tab_routes	37	U	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:49:19.452589+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:49:19.465057+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:49:19.465057-05
43	tab_route_points	154	I	\N	{"id_point": 154, "is_active": true, "created_at": "2026-04-20T05:27:33.026847+00:00", "name_point": "Calle 68 #13-21, La Victoria", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:27:33.026847-05
30	tab_routes	37	U	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:49:19.465057+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:49:20.929475+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:49:20.929475-05
31	tab_routes	37	U	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:49:20.929475+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 37, "is_active": false, "last_trip": null, "created_at": "2026-04-19T17:01:07.688554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta11", "route_fare": 0, "updated_at": "2026-04-19T21:49:20.947305+00:00", "color_route": "#C1F20D", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:49:20.947305-05
32	tab_routes	33	U	{"id_route": 33, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:48:07.285433+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta nuevo metodo", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 33, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:48:07.285433+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta nuevo metodo hola", "route_fare": 0, "updated_at": "2026-04-19T21:50:23.043347+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:50:23.043347-05
33	tab_routes	36	U	{"id_route": 36, "is_active": true, "last_trip": null, "created_at": "2026-04-19T15:55:37.496239+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta Z", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 36, "is_active": true, "last_trip": null, "created_at": "2026-04-19T15:55:37.496239+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta Z", "route_fare": 0, "updated_at": "2026-04-19T21:53:46.978639+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": "hola", "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:53:46.978639-05
34	tab_routes	33	U	{"id_route": 33, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:48:07.285433+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta nuevo metodo hola", "route_fare": 0, "updated_at": "2026-04-19T21:50:23.043347+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 33, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:48:07.285433+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta nuevo metodo hola", "route_fare": 0, "updated_at": "2026-04-19T21:54:51.104665+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:54:51.104665-05
35	tab_routes	33	U	{"id_route": 33, "is_active": true, "last_trip": null, "created_at": "2026-04-19T06:48:07.285433+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta nuevo metodo hola", "route_fare": 0, "updated_at": "2026-04-19T21:54:51.104665+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 33, "is_active": false, "last_trip": null, "created_at": "2026-04-19T06:48:07.285433+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta nuevo metodo hola", "route_fare": 0, "updated_at": "2026-04-19T21:54:51.120098+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 16:54:51.120098-05
36	tab_routes	38	I	\N	{"id_route": 38, "is_active": true, "last_trip": null, "created_at": "2026-04-19T23:52:06.014044+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta L", "route_fare": 0, "updated_at": null, "color_route": "#667EEA", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 18:52:06.014044-05
37	tab_routes	39	I	\N	{"id_route": 39, "is_active": true, "last_trip": null, "created_at": "2026-04-20T01:20:51.578425+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta21", "route_fare": 0, "updated_at": null, "color_route": "#A6FF00", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 20:20:51.578425-05
38	tab_routes	40	I	\N	{"id_route": 40, "is_active": true, "last_trip": null, "created_at": "2026-04-20T02:08:02.795527+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta extraña", "route_fare": 0, "updated_at": null, "color_route": "#F73B3B", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 21:08:02.795527-05
39	tab_routes	41	I	\N	{"id_route": 41, "is_active": true, "last_trip": null, "created_at": "2026-04-20T03:42:51.764033+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta24", "route_fare": 0, "updated_at": null, "color_route": "#3C3F86", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 22:42:51.764033-05
40	tab_routes	42	I	\N	{"id_route": 42, "is_active": true, "last_trip": null, "created_at": "2026-04-20T04:51:49.887157+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta con OSM", "route_fare": 0, "updated_at": null, "color_route": "#F7963B", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-19 23:51:49.887157-05
44	tab_route_points	155	I	\N	{"id_point": 155, "is_active": true, "created_at": "2026-04-20T05:27:46.493621+00:00", "name_point": "Calle 68 #13-21, La Victoria", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:27:46.493621-05
45	tab_route_points	156	I	\N	{"id_point": 156, "is_active": true, "created_at": "2026-04-20T05:27:47.670095+00:00", "name_point": "Calle 68 #13-21, La Victoria", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:27:47.670095-05
46	tab_route_points	157	I	\N	{"id_point": 157, "is_active": true, "created_at": "2026-04-20T05:27:48.542372+00:00", "name_point": "Calle 68 #13-21, La Victoria", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:27:48.542372-05
47	tab_route_points	158	I	\N	{"id_point": 158, "is_active": true, "created_at": "2026-04-20T05:27:49.606472+00:00", "name_point": "Calle 68 #13-21, La Victoria", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:27:49.606472-05
48	tab_route_points	159	I	\N	{"id_point": 159, "is_active": true, "created_at": "2026-04-20T05:27:50.683996+00:00", "name_point": "Calle 68 #13-21, La Victoria", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:27:50.683996-05
49	tab_route_points	160	I	\N	{"id_point": 160, "is_active": true, "created_at": "2026-04-20T05:28:05.819701+00:00", "name_point": "Calle Boulevar Santander ## 16-63, Comuna 4 Occidental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:28:05.819701-05
50	tab_route_points	161	I	\N	{"id_point": 161, "is_active": true, "created_at": "2026-04-20T05:44:28.686296+00:00", "name_point": "Calle 14 ## 20-64, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:44:28.686296-05
51	tab_route_points	162	I	\N	{"id_point": 162, "is_active": true, "created_at": "2026-04-20T05:45:26.883475+00:00", "name_point": "Carrera 22 ## 15-51, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:45:26.883475-05
52	tab_route_points	163	I	\N	{"id_point": 163, "is_active": true, "created_at": "2026-04-20T05:45:58.655356+00:00", "name_point": "parada prueba3", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:45:58.655356-05
53	tab_route_points	163	U	{"id_point": 163, "is_active": true, "created_at": "2026-04-20T05:45:58.655356+00:00", "name_point": "parada prueba3", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 163, "is_active": true, "created_at": "2026-04-20T05:45:58.655356+00:00", "name_point": "parada prueba3", "point_type": 1, "updated_at": "2026-04-20T05:48:57.388335+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:48:57.388335-05
54	tab_route_points	164	I	\N	{"id_point": 164, "is_active": true, "created_at": "2026-04-20T05:53:15.148971+00:00", "name_point": "Carrera 31 ## 116-75, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:53:15.148971-05
55	tab_route_points	165	I	\N	{"id_point": 165, "is_active": true, "created_at": "2026-04-20T05:53:19.894301+00:00", "name_point": "Carrera 31 ## 116-75, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:53:19.894301-05
56	tab_route_points	166	I	\N	{"id_point": 166, "is_active": true, "created_at": "2026-04-20T05:53:27.382562+00:00", "name_point": "Carrera 32 ## 116-63, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:53:27.382562-05
57	tab_route_points	167	I	\N	{"id_point": 167, "is_active": true, "created_at": "2026-04-20T05:53:39.358047+00:00", "name_point": "Carrera 31 ## 114-27, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:53:39.358047-05
58	tab_route_points	168	I	\N	{"id_point": 168, "is_active": true, "created_at": "2026-04-20T05:55:30.949522+00:00", "name_point": "Calle 117 #33-2, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:55:30.949522-05
59	tab_route_points	169	I	\N	{"id_point": 169, "is_active": true, "created_at": "2026-04-20T05:56:08.825663+00:00", "name_point": "Carrera 33 ## 118-9, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 00:56:08.825663-05
60	tab_route_points	170	I	\N	{"id_point": 170, "is_active": true, "created_at": "2026-04-20T06:00:02.911516+00:00", "name_point": "Carrera 33 ## 74-40, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 01:00:02.911516-05
61	tab_route_points	171	I	\N	{"id_point": 171, "is_active": true, "created_at": "2026-04-20T06:00:45.518136+00:00", "name_point": "Carrera 33 ## 73-35, Comuna 16 Lagos del cacique", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 01:00:45.518136-05
62	tab_route_points	172	I	\N	{"id_point": 172, "is_active": true, "created_at": "2026-04-20T06:01:24.102239+00:00", "name_point": "Carrera 33 #7554, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 01:01:24.102239-05
63	tab_route_points	173	I	\N	{"id_point": 173, "is_active": true, "created_at": "2026-04-20T06:01:55.309504+00:00", "name_point": "Carrera 33 ## 74-20, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 01:01:55.309504-05
64	tab_route_points	174	I	\N	{"id_point": 174, "is_active": true, "created_at": "2026-04-20T06:02:39.409339+00:00", "name_point": "Carrera 33 #7556, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 01:02:39.409339-05
65	tab_route_points	175	I	\N	{"id_point": 175, "is_active": true, "created_at": "2026-04-20T06:04:24.778507+00:00", "name_point": "Transversal 93 ## 34-108, Sotomayor", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 01:04:24.778507-05
66	tab_buses	13	U	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": null, "user_create": 1, "user_update": null, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-20T23:32:18.60384+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	1	2026-04-20 18:32:18.60384-05
84	tab_route_points	191	I	\N	{"id_point": 191, "is_active": true, "created_at": "2026-04-21T22:32:38.726207+00:00", "name_point": "Diagonal 15 #47-10, Comuna 6 La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-21 17:32:38.726207-05
67	tab_buses	13	U	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-20T23:32:18.60384+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-20T23:33:47.018253+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	1	2026-04-20 18:33:47.018253-05
68	tab_buses	13	U	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-20T23:33:47.018253+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": false, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-20T23:46:12.113485+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	1	2026-04-20 18:46:12.113485-05
69	tab_route_points	176	I	\N	{"id_point": 176, "is_active": true, "created_at": "2026-04-21T01:51:07.844186+00:00", "name_point": "Carrera 21 ## 24-54, Comuna 4 Occidental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 20:51:07.844186-05
70	tab_route_points	177	I	\N	{"id_point": 177, "is_active": true, "created_at": "2026-04-21T01:51:07.914706+00:00", "name_point": "Carrera 21 ## 22-6, Comuna 4 Occidental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 20:51:07.914706-05
71	tab_route_points	178	I	\N	{"id_point": 178, "is_active": true, "created_at": "2026-04-21T01:51:07.930433+00:00", "name_point": "Carrera 21 ## 20-30, Comuna 4 Occidental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 20:51:07.930433-05
72	tab_route_points	179	I	\N	{"id_point": 179, "is_active": true, "created_at": "2026-04-21T02:07:57.990345+00:00", "name_point": "Carrera 18 ## 10-11, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 21:07:57.990345-05
73	tab_route_points	180	I	\N	{"id_point": 180, "is_active": true, "created_at": "2026-04-21T02:07:58.010317+00:00", "name_point": "Carrera 17 ## 9-50, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 21:07:58.010317-05
74	tab_route_points	181	I	\N	{"id_point": 181, "is_active": true, "created_at": "2026-04-21T02:07:58.031567+00:00", "name_point": "Calle 7 ## 17-44, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 21:07:58.031567-05
75	tab_route_points	182	I	\N	{"id_point": 182, "is_active": true, "created_at": "2026-04-21T02:07:58.046527+00:00", "name_point": "Calle 6 #18-56, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 21:07:58.046527-05
76	tab_route_points	183	I	\N	{"id_point": 183, "is_active": true, "created_at": "2026-04-21T02:07:58.060374+00:00", "name_point": "Calle 7 #19-32, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 21:07:58.060374-05
77	tab_route_points	184	I	\N	{"id_point": 184, "is_active": true, "created_at": "2026-04-21T02:07:58.073897+00:00", "name_point": "Calle 7 ## 20-43, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 21:07:58.073897-05
78	tab_route_points	185	I	\N	{"id_point": 185, "is_active": true, "created_at": "2026-04-21T02:07:58.089568+00:00", "name_point": "Calle 8 ## 20-57, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-20 21:07:58.089568-05
79	tab_route_points	186	I	\N	{"id_point": 186, "is_active": true, "created_at": "2026-04-21T22:32:38.630661+00:00", "name_point": "Carrera 15 ##28-75 a 28-3, Centro", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-21 17:32:38.630661-05
80	tab_route_points	187	I	\N	{"id_point": 187, "is_active": true, "created_at": "2026-04-21T22:32:38.687517+00:00", "name_point": "Diagonal 15 ##55-78, Comuna 6 La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-21 17:32:38.687517-05
81	tab_route_points	188	I	\N	{"id_point": 188, "is_active": true, "created_at": "2026-04-21T22:32:38.69611+00:00", "name_point": "Diagonal 15 #60-56, Comuna 6 La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-21 17:32:38.69611-05
82	tab_route_points	189	I	\N	{"id_point": 189, "is_active": true, "created_at": "2026-04-21T22:32:38.706066+00:00", "name_point": "Carrera 15 #3638, García Rovira", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-21 17:32:38.706066-05
83	tab_route_points	190	I	\N	{"id_point": 190, "is_active": true, "created_at": "2026-04-21T22:32:38.715605+00:00", "name_point": "Diagonal 15 #45-54, Comuna 5 Garcia Rovira", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-21 17:32:38.715605-05
85	tab_route_points	192	I	\N	{"id_point": 192, "is_active": true, "created_at": "2026-04-21T22:32:38.735446+00:00", "name_point": "Diagonal 15 #52-53", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-21 17:32:38.735446-05
86	tab_route_points	12	U	{"id_point": 12, "is_active": true, "created_at": "2026-04-03T00:55:46.970791+00:00", "name_point": "cr 22 con 45", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 12, "is_active": true, "created_at": "2026-04-03T00:55:46.970791+00:00", "name_point": "cr 22 con 45", "point_type": 1, "updated_at": "2026-04-21T22:39:30.689725+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-21 17:39:30.689725-05
87	tab_routes	43	I	\N	{"id_route": 43, "is_active": true, "last_trip": null, "created_at": "2026-04-22T00:57:56.187384+00:00", "first_trip": null, "id_company": 1, "name_route": "cr21-Cr22", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-21 19:57:56.187384-05
88	tab_buses	13	U	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": false, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-20T23:46:12.113485+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": false, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-22T01:25:03.170471+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	1	2026-04-21 20:25:03.170471-05
89	tab_buses	13	U	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": false, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-22T01:25:03.170471+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	{"id_bus": 13, "amb_code": "AMB-0258", "id_brand": 13, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": false, "photo_url": null, "created_at": "2026-04-15T05:02:48.060678+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2022, "updated_at": "2026-04-22T01:25:29.327643+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 39, "plate_number": "ABC316", "code_internal": "654", "gps_device_id": "2334354534454", "chassis_number": "21145454144464745"}	1	2026-04-21 20:25:29.327643-05
90	tab_buses	2	U	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": null, "user_create": 1, "user_update": null, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:26:06.359087+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	1	2026-04-21 20:26:06.359087-05
91	tab_buses	2	U	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:26:06.359087+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:26:47.514986+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	1	2026-04-21 20:26:47.514986-05
92	tab_buses	2	U	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:26:47.514986+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:28:08.292862+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	1	2026-04-21 20:28:08.292862-05
104	tab_route_points	197	I	\N	{"id_point": 197, "is_active": true, "created_at": "2026-04-23T23:35:44.990336+00:00", "name_point": "Avenida Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:44.990336-05
93	tab_buses	2	U	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:28:08.292862+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:28:27.106249+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	1	2026-04-21 20:28:27.106249-05
94	tab_buses	2	U	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:28:27.106249+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:28:46.336958+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	1	2026-04-21 20:28:46.336958-05
95	tab_buses	2	U	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:28:46.336958+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:51:51.378382+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	1	2026-04-21 20:51:51.378382-05
96	tab_buses	2	U	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:51:51.378382+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	{"id_bus": 2, "amb_code": "AMB-0022", "id_brand": 1, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": false, "photo_url": null, "created_at": "2026-03-31T22:27:26.116134+00:00", "id_company": 3, "model_name": "citaro", "model_year": 2023, "updated_at": "2026-04-22T01:51:51.428009+00:00", "user_create": 1, "user_update": 1, "capacity_bus": 40, "plate_number": "CIA158", "code_internal": "0032", "gps_device_id": "23343545212514", "chassis_number": "211454541412565"}	1	2026-04-21 20:51:51.428009-05
97	tab_routes	44	I	\N	{"id_route": 44, "is_active": true, "last_trip": null, "created_at": "2026-04-22T08:19:24.77943+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta rara", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-22 03:19:24.77943-05
98	tab_routes	45	I	\N	{"id_route": 45, "is_active": true, "last_trip": null, "created_at": "2026-04-22T08:40:09.585687+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta 22-21 rapida", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-22 03:40:09.585687-05
99	tab_route_points	193	I	\N	{"id_point": 193, "is_active": true, "created_at": "2026-04-22T08:41:18.847259+00:00", "name_point": "Calle 1nb ## 6-96, PASEO CATALUÑA", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-22 03:41:18.847259-05
100	tab_route_points	194	I	\N	{"id_point": 194, "is_active": true, "created_at": "2026-04-22T08:41:18.853954+00:00", "name_point": "Calle 1B ## 6-131, PASEO CATALUÑA", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-22 03:41:18.853954-05
101	tab_route_points	195	I	\N	{"id_point": 195, "is_active": true, "created_at": "2026-04-22T08:41:18.870844+00:00", "name_point": "Calle 1D ## 5-25, PASEO CATALUÑA", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-22 03:41:18.870844-05
102	tab_route_points	196	I	\N	{"id_point": 196, "is_active": true, "created_at": "2026-04-22T08:42:00.533414+00:00", "name_point": "Calle 1ª #6-06, PASEO CATALUÑA", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-22 03:42:00.533414-05
103	tab_routes	46	I	\N	{"id_route": 46, "is_active": true, "last_trip": null, "created_at": "2026-04-23T17:19:13.593252+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta22-21 nueva", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-23 12:19:13.593252-05
105	tab_route_points	198	I	\N	{"id_point": 198, "is_active": true, "created_at": "2026-04-23T23:35:45.044546+00:00", "name_point": "Calle 35", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.044546-05
106	tab_route_points	199	I	\N	{"id_point": 199, "is_active": true, "created_at": "2026-04-23T23:35:45.058342+00:00", "name_point": "Avenida Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.058342-05
107	tab_route_points	200	I	\N	{"id_point": 200, "is_active": true, "created_at": "2026-04-23T23:35:45.070831+00:00", "name_point": "Calle 41", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.070831-05
108	tab_route_points	201	I	\N	{"id_point": 201, "is_active": true, "created_at": "2026-04-23T23:35:45.09358+00:00", "name_point": "Avenida Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.09358-05
109	tab_route_points	202	I	\N	{"id_point": 202, "is_active": true, "created_at": "2026-04-23T23:35:45.11708+00:00", "name_point": "Avenida Carrera 33, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.11708-05
110	tab_route_points	203	I	\N	{"id_point": 203, "is_active": true, "created_at": "2026-04-23T23:35:45.129521+00:00", "name_point": "Avenida Carrera 33, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.129521-05
111	tab_route_points	204	I	\N	{"id_point": 204, "is_active": true, "created_at": "2026-04-23T23:35:45.141132+00:00", "name_point": "Avenida Carrera 33, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.141132-05
112	tab_route_points	205	I	\N	{"id_point": 205, "is_active": true, "created_at": "2026-04-23T23:35:45.153405+00:00", "name_point": "Avenida Calle 48", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.153405-05
113	tab_route_points	206	I	\N	{"id_point": 206, "is_active": true, "created_at": "2026-04-23T23:35:45.164202+00:00", "name_point": "Avenida Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.164202-05
114	tab_route_points	207	I	\N	{"id_point": 207, "is_active": true, "created_at": "2026-04-23T23:35:45.174374+00:00", "name_point": "Avenida Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.174374-05
115	tab_route_points	208	I	\N	{"id_point": 208, "is_active": true, "created_at": "2026-04-23T23:35:45.18647+00:00", "name_point": "Avenida Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.18647-05
116	tab_route_points	209	I	\N	{"id_point": 209, "is_active": true, "created_at": "2026-04-23T23:35:45.196465+00:00", "name_point": "Parque San Josemaría (Bloque 1)", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.196465-05
117	tab_route_points	210	I	\N	{"id_point": 210, "is_active": true, "created_at": "2026-04-23T23:35:45.206773+00:00", "name_point": "Avenida Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.206773-05
118	tab_route_points	211	I	\N	{"id_point": 211, "is_active": true, "created_at": "2026-04-23T23:35:45.220208+00:00", "name_point": "Calle 54", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.220208-05
119	tab_route_points	212	I	\N	{"id_point": 212, "is_active": true, "created_at": "2026-04-23T23:35:45.23108+00:00", "name_point": "Avenida Calle 56", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.23108-05
120	tab_route_points	213	I	\N	{"id_point": 213, "is_active": true, "created_at": "2026-04-23T23:35:45.239363+00:00", "name_point": "Calle 59", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.239363-05
121	tab_route_points	214	I	\N	{"id_point": 214, "is_active": true, "created_at": "2026-04-23T23:35:45.250658+00:00", "name_point": "Avenida Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.250658-05
122	tab_route_points	215	I	\N	{"id_point": 215, "is_active": true, "created_at": "2026-04-23T23:35:45.25994+00:00", "name_point": "Transversal Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.25994-05
123	tab_route_points	216	I	\N	{"id_point": 216, "is_active": true, "created_at": "2026-04-23T23:35:45.271592+00:00", "name_point": "Carrera 44", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.271592-05
124	tab_route_points	217	I	\N	{"id_point": 217, "is_active": true, "created_at": "2026-04-23T23:35:45.287036+00:00", "name_point": "Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.287036-05
125	tab_route_points	218	I	\N	{"id_point": 218, "is_active": true, "created_at": "2026-04-23T23:35:45.293498+00:00", "name_point": "Transversal Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.293498-05
126	tab_route_points	219	I	\N	{"id_point": 219, "is_active": true, "created_at": "2026-04-23T23:35:45.377566+00:00", "name_point": "Parque El Tejar", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.377566-05
127	tab_route_points	220	I	\N	{"id_point": 220, "is_active": true, "created_at": "2026-04-23T23:35:45.383097+00:00", "name_point": "Parqueadero C.C Cacique", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:35:45.383097-05
128	tab_route_points	221	I	\N	{"id_point": 221, "is_active": true, "created_at": "2026-04-23T23:42:52.389254+00:00", "name_point": "Avenida Carrera 33, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:42:52.389254-05
129	tab_route_points	222	I	\N	{"id_point": 222, "is_active": true, "created_at": "2026-04-23T23:42:52.418771+00:00", "name_point": "Avenida Carrera 33, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:42:52.418771-05
130	tab_route_points	223	I	\N	{"id_point": 223, "is_active": true, "created_at": "2026-04-23T23:42:52.43115+00:00", "name_point": "Calle 42", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:42:52.43115-05
131	tab_route_points	224	I	\N	{"id_point": 224, "is_active": true, "created_at": "2026-04-23T23:45:15.827433+00:00", "name_point": "Transversal Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:45:15.827433-05
132	tab_route_points	225	I	\N	{"id_point": 225, "is_active": true, "created_at": "2026-04-23T23:45:15.833004+00:00", "name_point": "Carrera 44", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:45:15.833004-05
133	tab_route_points	226	I	\N	{"id_point": 226, "is_active": true, "created_at": "2026-04-23T23:45:15.905637+00:00", "name_point": "Transversal Oriental, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:45:15.905637-05
134	tab_route_points	227	I	\N	{"id_point": 227, "is_active": true, "created_at": "2026-04-23T23:46:54.018915+00:00", "name_point": "Transversal Oriental, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:46:54.018915-05
135	tab_route_points	228	I	\N	{"id_point": 228, "is_active": true, "created_at": "2026-04-23T23:46:54.03046+00:00", "name_point": "Transversal Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:46:54.03046-05
136	tab_route_points	229	I	\N	{"id_point": 229, "is_active": true, "created_at": "2026-04-23T23:46:54.040343+00:00", "name_point": "Transversal Oriental, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:46:54.040343-05
137	tab_route_points	230	I	\N	{"id_point": 230, "is_active": true, "created_at": "2026-04-23T23:46:54.054045+00:00", "name_point": "Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:46:54.054045-05
138	tab_route_points	231	I	\N	{"id_point": 231, "is_active": true, "created_at": "2026-04-23T23:46:54.067745+00:00", "name_point": "Transversal Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 18:46:54.067745-05
139	tab_routes	47	I	\N	{"id_route": 47, "is_active": true, "last_trip": null, "created_at": "2026-04-24T00:06:39.777994+00:00", "first_trip": null, "id_company": 1, "name_route": "RUTA CACIQUE", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-23 19:06:39.777994-05
140	tab_route_points	232	I	\N	{"id_point": 232, "is_active": true, "created_at": "2026-04-24T00:36:11.243936+00:00", "name_point": "Túnel Avenida Carrera 27, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.243936-05
141	tab_route_points	233	I	\N	{"id_point": 233, "is_active": true, "created_at": "2026-04-24T00:36:11.271861+00:00", "name_point": "Parque de Los Niños", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.271861-05
142	tab_route_points	234	I	\N	{"id_point": 234, "is_active": true, "created_at": "2026-04-24T00:36:11.27927+00:00", "name_point": "Parque de Los Niños", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.27927-05
143	tab_route_points	235	I	\N	{"id_point": 235, "is_active": true, "created_at": "2026-04-24T00:36:11.287829+00:00", "name_point": "Calle 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.287829-05
144	tab_route_points	236	I	\N	{"id_point": 236, "is_active": true, "created_at": "2026-04-24T00:36:11.297783+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.297783-05
145	tab_route_points	237	I	\N	{"id_point": 237, "is_active": true, "created_at": "2026-04-24T00:36:11.313614+00:00", "name_point": "Avenida Carrera 27, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.313614-05
146	tab_route_points	238	I	\N	{"id_point": 238, "is_active": true, "created_at": "2026-04-24T00:36:11.325821+00:00", "name_point": "Calle 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.325821-05
147	tab_route_points	239	I	\N	{"id_point": 239, "is_active": true, "created_at": "2026-04-24T00:36:11.333197+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.333197-05
148	tab_route_points	240	I	\N	{"id_point": 240, "is_active": true, "created_at": "2026-04-24T00:36:11.341748+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.341748-05
149	tab_route_points	241	I	\N	{"id_point": 241, "is_active": true, "created_at": "2026-04-24T00:36:11.350035+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.350035-05
150	tab_route_points	242	I	\N	{"id_point": 242, "is_active": true, "created_at": "2026-04-24T00:36:11.35949+00:00", "name_point": "Calle 34", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.35949-05
151	tab_route_points	243	I	\N	{"id_point": 243, "is_active": true, "created_at": "2026-04-24T00:36:11.368643+00:00", "name_point": "Túnel Avenida Carrera 27, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.368643-05
152	tab_route_points	244	I	\N	{"id_point": 244, "is_active": true, "created_at": "2026-04-24T00:36:11.377359+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.377359-05
153	tab_route_points	245	I	\N	{"id_point": 245, "is_active": true, "created_at": "2026-04-24T00:36:11.385931+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.385931-05
154	tab_route_points	246	I	\N	{"id_point": 246, "is_active": true, "created_at": "2026-04-24T00:36:11.394551+00:00", "name_point": "Avenida Calle 36", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.394551-05
155	tab_route_points	247	I	\N	{"id_point": 247, "is_active": true, "created_at": "2026-04-24T00:36:11.402654+00:00", "name_point": "Avenida Carrera 27 # 36, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.402654-05
156	tab_route_points	248	I	\N	{"id_point": 248, "is_active": true, "created_at": "2026-04-24T00:36:11.412993+00:00", "name_point": "Avenida Carrera 27 #37-1, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.412993-05
157	tab_route_points	249	I	\N	{"id_point": 249, "is_active": true, "created_at": "2026-04-24T00:36:11.42929+00:00", "name_point": "Avenida Carrera 27 #37-1, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.42929-05
158	tab_route_points	250	I	\N	{"id_point": 250, "is_active": true, "created_at": "2026-04-24T00:36:11.439536+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.439536-05
159	tab_route_points	251	I	\N	{"id_point": 251, "is_active": true, "created_at": "2026-04-24T00:36:11.446497+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.446497-05
160	tab_route_points	252	I	\N	{"id_point": 252, "is_active": true, "created_at": "2026-04-24T00:36:11.453462+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.453462-05
161	tab_route_points	253	I	\N	{"id_point": 253, "is_active": true, "created_at": "2026-04-24T00:36:11.461513+00:00", "name_point": "Calle 41", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.461513-05
162	tab_route_points	254	I	\N	{"id_point": 254, "is_active": true, "created_at": "2026-04-24T00:36:11.468971+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.468971-05
163	tab_route_points	255	I	\N	{"id_point": 255, "is_active": true, "created_at": "2026-04-24T00:36:11.477836+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.477836-05
164	tab_route_points	256	I	\N	{"id_point": 256, "is_active": true, "created_at": "2026-04-24T00:36:11.486163+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.486163-05
165	tab_route_points	257	I	\N	{"id_point": 257, "is_active": true, "created_at": "2026-04-24T00:36:11.495139+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.495139-05
166	tab_route_points	258	I	\N	{"id_point": 258, "is_active": true, "created_at": "2026-04-24T00:36:11.502721+00:00", "name_point": "Avenida Calle 48", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.502721-05
167	tab_route_points	259	I	\N	{"id_point": 259, "is_active": true, "created_at": "2026-04-24T00:36:11.508524+00:00", "name_point": "Avenida Calle 48", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.508524-05
168	tab_route_points	260	I	\N	{"id_point": 260, "is_active": true, "created_at": "2026-04-24T00:36:11.515419+00:00", "name_point": "Calle 50 #26-85, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.515419-05
169	tab_route_points	261	I	\N	{"id_point": 261, "is_active": true, "created_at": "2026-04-24T00:36:11.524458+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.524458-05
170	tab_route_points	262	I	\N	{"id_point": 262, "is_active": true, "created_at": "2026-04-24T00:36:11.540392+00:00", "name_point": "Calle 51", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.540392-05
172	tab_route_points	264	I	\N	{"id_point": 264, "is_active": true, "created_at": "2026-04-24T00:36:11.568395+00:00", "name_point": "Carrera 27A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.568395-05
174	tab_route_points	266	I	\N	{"id_point": 266, "is_active": true, "created_at": "2026-04-24T00:36:11.593595+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.593595-05
171	tab_route_points	263	I	\N	{"id_point": 263, "is_active": true, "created_at": "2026-04-24T00:36:11.561384+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.561384-05
173	tab_route_points	265	I	\N	{"id_point": 265, "is_active": true, "created_at": "2026-04-24T00:36:11.588307+00:00", "name_point": "Carrera 27 #52-86, Comuna La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.588307-05
175	tab_route_points	267	I	\N	{"id_point": 267, "is_active": true, "created_at": "2026-04-24T00:36:11.599827+00:00", "name_point": "Carrera 24", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.599827-05
177	tab_route_points	269	I	\N	{"id_point": 269, "is_active": true, "created_at": "2026-04-24T00:36:11.613311+00:00", "name_point": "Avenida Carrera 27 #54-10, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.613311-05
179	tab_route_points	271	I	\N	{"id_point": 271, "is_active": true, "created_at": "2026-04-24T00:36:11.621442+00:00", "name_point": "Calle 55", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.621442-05
181	tab_route_points	273	I	\N	{"id_point": 273, "is_active": true, "created_at": "2026-04-24T00:36:11.628734+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.628734-05
183	tab_route_points	275	I	\N	{"id_point": 275, "is_active": true, "created_at": "2026-04-24T00:36:11.640752+00:00", "name_point": "Carrera 27, Comuna La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.640752-05
191	tab_route_points	283	I	\N	{"id_point": 283, "is_active": true, "created_at": "2026-04-24T00:36:11.680151+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.680151-05
192	tab_route_points	284	I	\N	{"id_point": 284, "is_active": true, "created_at": "2026-04-24T00:36:11.686148+00:00", "name_point": "Carrera 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.686148-05
176	tab_route_points	268	I	\N	{"id_point": 268, "is_active": true, "created_at": "2026-04-24T00:36:11.609329+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.609329-05
178	tab_route_points	270	I	\N	{"id_point": 270, "is_active": true, "created_at": "2026-04-24T00:36:11.617261+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.617261-05
180	tab_route_points	272	I	\N	{"id_point": 272, "is_active": true, "created_at": "2026-04-24T00:36:11.625168+00:00", "name_point": "Avenida Calle 56, Comuna La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.625168-05
182	tab_route_points	274	I	\N	{"id_point": 274, "is_active": true, "created_at": "2026-04-24T00:36:11.629117+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.629117-05
184	tab_route_points	276	I	\N	{"id_point": 276, "is_active": true, "created_at": "2026-04-24T00:36:11.63397+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.63397-05
185	tab_route_points	277	I	\N	{"id_point": 277, "is_active": true, "created_at": "2026-04-24T00:36:11.634656+00:00", "name_point": "Carrera 27 #52-86, Comuna La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.634656-05
186	tab_route_points	278	I	\N	{"id_point": 278, "is_active": true, "created_at": "2026-04-24T00:36:11.648917+00:00", "name_point": "Salida a Autopista Floridablanca", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.648917-05
187	tab_route_points	279	I	\N	{"id_point": 279, "is_active": true, "created_at": "2026-04-24T00:36:11.661843+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.661843-05
188	tab_route_points	280	I	\N	{"id_point": 280, "is_active": true, "created_at": "2026-04-24T00:36:11.668901+00:00", "name_point": "Salida a Autopista Floridablanca", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.668901-05
189	tab_route_points	281	I	\N	{"id_point": 281, "is_active": true, "created_at": "2026-04-24T00:36:11.673044+00:00", "name_point": "Salida a Autopista Floridablanca", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.673044-05
190	tab_route_points	282	I	\N	{"id_point": 282, "is_active": true, "created_at": "2026-04-24T00:36:11.676575+00:00", "name_point": "Carrera 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.676575-05
193	tab_route_points	286	I	\N	{"id_point": 286, "is_active": true, "created_at": "2026-04-24T00:36:11.689352+00:00", "name_point": "Carrera 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.689352-05
194	tab_route_points	285	I	\N	{"id_point": 285, "is_active": true, "created_at": "2026-04-24T00:36:11.680852+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.680852-05
195	tab_route_points	287	I	\N	{"id_point": 287, "is_active": true, "created_at": "2026-04-24T00:36:11.693105+00:00", "name_point": "Carrera 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.693105-05
196	tab_route_points	288	I	\N	{"id_point": 288, "is_active": true, "created_at": "2026-04-24T00:36:11.695997+00:00", "name_point": "Parque de Las Hormigas", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.695997-05
197	tab_route_points	289	I	\N	{"id_point": 289, "is_active": true, "created_at": "2026-04-24T00:36:11.699121+00:00", "name_point": "Avenida Calle 67, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.699121-05
198	tab_route_points	290	I	\N	{"id_point": 290, "is_active": true, "created_at": "2026-04-24T00:36:11.70489+00:00", "name_point": "Avenida Calle 67", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.70489-05
199	tab_route_points	291	I	\N	{"id_point": 291, "is_active": true, "created_at": "2026-04-24T00:36:11.707364+00:00", "name_point": "Avenida Calle 68", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.707364-05
200	tab_route_points	292	I	\N	{"id_point": 292, "is_active": true, "created_at": "2026-04-24T00:36:11.711206+00:00", "name_point": "Avenida Calle 67", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.711206-05
201	tab_route_points	293	I	\N	{"id_point": 293, "is_active": true, "created_at": "2026-04-24T00:36:11.714321+00:00", "name_point": "Transversal Oriental, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:36:11.714321-05
202	tab_routes	48	I	\N	{"id_route": 48, "is_active": true, "last_trip": null, "created_at": "2026-04-24T00:40:18.36649+00:00", "first_trip": null, "id_company": 1, "name_route": "RUTA CACIQUE2", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-23 19:40:18.36649-05
224	tab_route_points	314	I	\N	{"id_point": 314, "is_active": true, "created_at": "2026-04-24T00:56:32.966256+00:00", "name_point": "Calle 33 #27-11, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.966256-05
203	tab_routes	48	U	{"id_route": 48, "is_active": true, "last_trip": null, "created_at": "2026-04-24T00:40:18.36649+00:00", "first_trip": null, "id_company": 1, "name_route": "RUTA CACIQUE2", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 48, "is_active": true, "last_trip": null, "created_at": "2026-04-24T00:40:18.36649+00:00", "first_trip": null, "id_company": 1, "name_route": "RUTA CACIQUE2", "route_fare": 0, "updated_at": "2026-04-24T00:46:09.763221+00:00", "color_route": "#F73BD4", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-23 19:46:09.763221-05
204	tab_route_points	294	I	\N	{"id_point": 294, "is_active": true, "created_at": "2026-04-24T00:56:32.788873+00:00", "name_point": "Avenida Calle 56", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.788873-05
205	tab_route_points	295	I	\N	{"id_point": 295, "is_active": true, "created_at": "2026-04-24T00:56:32.811104+00:00", "name_point": "Avenida Carrera 27 #45-05, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.811104-05
206	tab_route_points	296	I	\N	{"id_point": 296, "is_active": true, "created_at": "2026-04-24T00:56:32.818444+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.818444-05
207	tab_route_points	297	I	\N	{"id_point": 297, "is_active": true, "created_at": "2026-04-24T00:56:32.825927+00:00", "name_point": "Avenida Carrera 27, Comuna Cabecera del Llano", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.825927-05
208	tab_route_points	298	I	\N	{"id_point": 298, "is_active": true, "created_at": "2026-04-24T00:56:32.832737+00:00", "name_point": "Calle 48 #27-38, Comuna La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.832737-05
209	tab_route_points	299	I	\N	{"id_point": 299, "is_active": true, "created_at": "2026-04-24T00:56:32.839943+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.839943-05
210	tab_route_points	300	I	\N	{"id_point": 300, "is_active": true, "created_at": "2026-04-24T00:56:32.848141+00:00", "name_point": "Carrera 27 #52-86, Comuna La Concordia", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.848141-05
211	tab_route_points	301	I	\N	{"id_point": 301, "is_active": true, "created_at": "2026-04-24T00:56:32.855956+00:00", "name_point": "Carrera 27A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.855956-05
212	tab_route_points	302	I	\N	{"id_point": 302, "is_active": true, "created_at": "2026-04-24T00:56:32.863223+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.863223-05
213	tab_route_points	303	I	\N	{"id_point": 303, "is_active": true, "created_at": "2026-04-24T00:56:32.869561+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.869561-05
214	tab_route_points	304	I	\N	{"id_point": 304, "is_active": true, "created_at": "2026-04-24T00:56:32.879162+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.879162-05
215	tab_route_points	305	I	\N	{"id_point": 305, "is_active": true, "created_at": "2026-04-24T00:56:32.890491+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.890491-05
216	tab_route_points	306	I	\N	{"id_point": 306, "is_active": true, "created_at": "2026-04-24T00:56:32.90116+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.90116-05
217	tab_route_points	307	I	\N	{"id_point": 307, "is_active": true, "created_at": "2026-04-24T00:56:32.914283+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.914283-05
218	tab_route_points	308	I	\N	{"id_point": 308, "is_active": true, "created_at": "2026-04-24T00:56:32.922806+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.922806-05
219	tab_route_points	309	I	\N	{"id_point": 309, "is_active": true, "created_at": "2026-04-24T00:56:32.931026+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.931026-05
220	tab_route_points	310	I	\N	{"id_point": 310, "is_active": true, "created_at": "2026-04-24T00:56:32.938215+00:00", "name_point": "Calle 34", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.938215-05
221	tab_route_points	311	I	\N	{"id_point": 311, "is_active": true, "created_at": "2026-04-24T00:56:32.946672+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.946672-05
222	tab_route_points	312	I	\N	{"id_point": 312, "is_active": true, "created_at": "2026-04-24T00:56:32.953017+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.953017-05
223	tab_route_points	313	I	\N	{"id_point": 313, "is_active": true, "created_at": "2026-04-24T00:56:32.961235+00:00", "name_point": "Calle 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.961235-05
225	tab_route_points	315	I	\N	{"id_point": 315, "is_active": true, "created_at": "2026-04-24T00:56:32.973645+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.973645-05
226	tab_route_points	316	I	\N	{"id_point": 316, "is_active": true, "created_at": "2026-04-24T00:56:32.980307+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.980307-05
227	tab_route_points	317	I	\N	{"id_point": 317, "is_active": true, "created_at": "2026-04-24T00:56:32.986897+00:00", "name_point": "Túnel Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 19:56:32.986897-05
228	tab_route_points	217	U	{"id_point": 217, "is_active": true, "created_at": "2026-04-23T23:35:45.287036+00:00", "name_point": "Carrera 33", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 217, "is_active": false, "created_at": "2026-04-23T23:35:45.287036+00:00", "name_point": "Carrera 33", "point_type": 1, "updated_at": "2026-04-24T01:35:37.661019+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-23 20:35:37.661019-05
229	tab_routes	49	I	\N	{"id_route": 49, "is_active": true, "last_trip": null, "created_at": "2026-04-24T01:38:17.330199+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta 27 hacia el norte", "route_fare": 0, "updated_at": null, "color_route": "#8F8332", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-23 20:38:17.330199-05
230	tab_routes	50	I	\N	{"id_route": 50, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:16:01.788554+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta 27 hasta 56", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-24 01:16:01.788554-05
231	tab_route_points	318	I	\N	{"id_point": 318, "is_active": true, "created_at": "2026-04-24T06:24:32.205382+00:00", "name_point": "Urbanización El Girasol", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:24:32.205382-05
232	tab_routes	51	I	\N	{"id_route": 51, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:24:58.192336+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Girasol", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-24 01:24:58.192336-05
233	tab_route_points	319	I	\N	{"id_point": 319, "is_active": true, "created_at": "2026-04-24T06:39:14.240735+00:00", "name_point": "Transversal Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:39:14.240735-05
234	tab_route_points	320	I	\N	{"id_point": 320, "is_active": true, "created_at": "2026-04-24T06:39:14.251273+00:00", "name_point": "Balcones de la Colina", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:39:14.251273-05
235	tab_route_points	321	I	\N	{"id_point": 321, "is_active": true, "created_at": "2026-04-24T06:39:14.258451+00:00", "name_point": "Calle 107A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:39:14.258451-05
236	tab_routes	52	I	\N	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-24 01:40:22.954942-05
237	tab_route_points	322	I	\N	{"id_point": 322, "is_active": true, "created_at": "2026-04-24T06:45:43.494003+00:00", "name_point": "Calle 11, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.494003-05
238	tab_route_points	323	I	\N	{"id_point": 323, "is_active": true, "created_at": "2026-04-24T06:45:43.501819+00:00", "name_point": "Carrera 18, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.501819-05
239	tab_route_points	324	I	\N	{"id_point": 324, "is_active": true, "created_at": "2026-04-24T06:45:43.508805+00:00", "name_point": "Carrera 18", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.508805-05
240	tab_route_points	325	I	\N	{"id_point": 325, "is_active": true, "created_at": "2026-04-24T06:45:43.515795+00:00", "name_point": "Calle 21 #18-32, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.515795-05
241	tab_route_points	326	I	\N	{"id_point": 326, "is_active": true, "created_at": "2026-04-24T06:45:43.52261+00:00", "name_point": "Carrera 18", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.52261-05
242	tab_route_points	327	I	\N	{"id_point": 327, "is_active": true, "created_at": "2026-04-24T06:45:43.530103+00:00", "name_point": "Carrera 18", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.530103-05
243	tab_route_points	328	I	\N	{"id_point": 328, "is_active": true, "created_at": "2026-04-24T06:45:43.53717+00:00", "name_point": "Calle 28, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.53717-05
244	tab_route_points	329	I	\N	{"id_point": 329, "is_active": true, "created_at": "2026-04-24T06:45:43.544223+00:00", "name_point": "Avenida Quebrada Seca", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.544223-05
245	tab_route_points	330	I	\N	{"id_point": 330, "is_active": true, "created_at": "2026-04-24T06:45:43.550169+00:00", "name_point": "Calle 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.550169-05
246	tab_route_points	331	I	\N	{"id_point": 331, "is_active": true, "created_at": "2026-04-24T06:45:43.558415+00:00", "name_point": "Boulevard Bolívar", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.558415-05
247	tab_route_points	332	I	\N	{"id_point": 332, "is_active": true, "created_at": "2026-04-24T06:45:43.565524+00:00", "name_point": "Carrera 18 #30-56, Comuna Centro", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.565524-05
248	tab_route_points	333	I	\N	{"id_point": 333, "is_active": true, "created_at": "2026-04-24T06:45:43.57369+00:00", "name_point": "Carrera 18", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.57369-05
249	tab_route_points	334	I	\N	{"id_point": 334, "is_active": true, "created_at": "2026-04-24T06:45:43.580761+00:00", "name_point": "Carrera 18, Comuna Centro", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.580761-05
250	tab_route_points	335	I	\N	{"id_point": 335, "is_active": true, "created_at": "2026-04-24T06:45:43.589179+00:00", "name_point": "Calle 17", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.589179-05
251	tab_route_points	336	I	\N	{"id_point": 336, "is_active": true, "created_at": "2026-04-24T06:45:43.59709+00:00", "name_point": "Carrera 18, Comuna Centro", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.59709-05
252	tab_route_points	337	I	\N	{"id_point": 337, "is_active": true, "created_at": "2026-04-24T06:45:43.6025+00:00", "name_point": "Boulevard Santander", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.6025-05
253	tab_route_points	338	I	\N	{"id_point": 338, "is_active": true, "created_at": "2026-04-24T06:45:43.609454+00:00", "name_point": "Carrera 18, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.609454-05
254	tab_route_points	339	I	\N	{"id_point": 339, "is_active": true, "created_at": "2026-04-24T06:45:43.616291+00:00", "name_point": "Calle 17", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 01:45:43.616291-05
255	tab_route_points	340	I	\N	{"id_point": 340, "is_active": true, "created_at": "2026-04-24T08:27:21.761282+00:00", "name_point": "680001", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.761282-05
256	tab_route_points	341	I	\N	{"id_point": 341, "is_active": true, "created_at": "2026-04-24T08:27:21.790662+00:00", "name_point": "Calle 8A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.790662-05
257	tab_route_points	342	I	\N	{"id_point": 342, "is_active": true, "created_at": "2026-04-24T08:27:21.800856+00:00", "name_point": "Calle 10A, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.800856-05
258	tab_route_points	343	I	\N	{"id_point": 343, "is_active": true, "created_at": "2026-04-24T08:27:21.811959+00:00", "name_point": "Calle 12", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.811959-05
259	tab_route_points	344	I	\N	{"id_point": 344, "is_active": true, "created_at": "2026-04-24T08:27:21.81914+00:00", "name_point": "Calle 8A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.81914-05
260	tab_route_points	345	I	\N	{"id_point": 345, "is_active": true, "created_at": "2026-04-24T08:27:21.832927+00:00", "name_point": "Carrera 18", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.832927-05
261	tab_route_points	346	I	\N	{"id_point": 346, "is_active": true, "created_at": "2026-04-24T08:27:21.841196+00:00", "name_point": "Boulevard Bolívar", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.841196-05
262	tab_route_points	347	I	\N	{"id_point": 347, "is_active": true, "created_at": "2026-04-24T08:27:21.850102+00:00", "name_point": "Parque Cristo Rey", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.850102-05
263	tab_route_points	348	I	\N	{"id_point": 348, "is_active": true, "created_at": "2026-04-24T08:27:21.861108+00:00", "name_point": "Calle 10, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:27:21.861108-05
264	tab_route_points	349	I	\N	{"id_point": 349, "is_active": true, "created_at": "2026-04-24T08:28:52.34884+00:00", "name_point": "Carrera 21, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:28:52.34884-05
265	tab_route_points	350	I	\N	{"id_point": 350, "is_active": true, "created_at": "2026-04-24T08:28:52.352292+00:00", "name_point": "Carrera 21", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:28:52.352292-05
266	tab_route_points	351	I	\N	{"id_point": 351, "is_active": true, "created_at": "2026-04-24T08:28:52.361464+00:00", "name_point": "Carrera 21", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:28:52.361464-05
267	tab_route_points	80	U	{"id_point": 80, "is_active": true, "created_at": "2026-04-17T17:50:26.644003+00:00", "name_point": "cr22#6", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 80, "is_active": false, "created_at": "2026-04-17T17:50:26.644003+00:00", "name_point": "cr22#6", "point_type": 1, "updated_at": "2026-04-24T08:29:30.929139+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:29:30.929139-05
268	tab_route_points	79	U	{"id_point": 79, "is_active": true, "created_at": "2026-04-17T17:50:11.566242+00:00", "name_point": "cr22#7", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 79, "is_active": false, "created_at": "2026-04-17T17:50:11.566242+00:00", "name_point": "cr22#7", "point_type": 1, "updated_at": "2026-04-24T08:29:35.597626+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:29:35.597626-05
269	tab_route_points	78	U	{"id_point": 78, "is_active": true, "created_at": "2026-04-17T17:50:00.146441+00:00", "name_point": "cr22#8", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 78, "is_active": false, "created_at": "2026-04-17T17:50:00.146441+00:00", "name_point": "cr22#8", "point_type": 1, "updated_at": "2026-04-24T08:29:41.19904+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:29:41.19904-05
270	tab_route_points	77	U	{"id_point": 77, "is_active": true, "created_at": "2026-04-17T17:49:51.224163+00:00", "name_point": "cr22#9", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 77, "is_active": false, "created_at": "2026-04-17T17:49:51.224163+00:00", "name_point": "cr22#9", "point_type": 1, "updated_at": "2026-04-24T08:29:46.804585+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:29:46.804585-05
274	tab_route_points	353	I	\N	{"id_point": 353, "is_active": true, "created_at": "2026-04-24T08:30:14.669649+00:00", "name_point": "Carrera 22", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:30:14.669649-05
275	tab_route_points	354	I	\N	{"id_point": 354, "is_active": true, "created_at": "2026-04-24T08:30:14.677826+00:00", "name_point": "Carrera 22", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:30:14.677826-05
271	tab_route_points	76	U	{"id_point": 76, "is_active": true, "created_at": "2026-04-17T17:49:42.380385+00:00", "name_point": "cr22#10", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 76, "is_active": false, "created_at": "2026-04-17T17:49:42.380385+00:00", "name_point": "cr22#10", "point_type": 1, "updated_at": "2026-04-24T08:29:51.590926+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:29:51.590926-05
272	tab_route_points	75	U	{"id_point": 75, "is_active": true, "created_at": "2026-04-17T17:49:33.245978+00:00", "name_point": "cr22#11", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 75, "is_active": false, "created_at": "2026-04-17T17:49:33.245978+00:00", "name_point": "cr22#11", "point_type": 1, "updated_at": "2026-04-24T08:29:58.456396+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:29:58.456396-05
273	tab_route_points	352	I	\N	{"id_point": 352, "is_active": true, "created_at": "2026-04-24T08:30:14.661918+00:00", "name_point": "Calle 7, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:30:14.661918-05
276	tab_route_points	355	I	\N	{"id_point": 355, "is_active": true, "created_at": "2026-04-24T08:30:14.683851+00:00", "name_point": "Carrera 23, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:30:14.683851-05
277	tab_route_points	356	I	\N	{"id_point": 356, "is_active": true, "created_at": "2026-04-24T08:30:14.691118+00:00", "name_point": "Calle 11, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:30:14.691118-05
278	tab_route_points	357	I	\N	{"id_point": 357, "is_active": true, "created_at": "2026-04-24T08:30:14.70023+00:00", "name_point": "Calle 11, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 03:30:14.70023-05
279	tab_route_points	144	U	{"id_point": 144, "is_active": true, "created_at": "2026-04-18T04:48:20.574114+00:00", "name_point": "Carrera 18 ## 5-46, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 144, "is_active": true, "created_at": "2026-04-18T04:48:20.574114+00:00", "name_point": "Carrera 18 ## 5-46, Comuna 3 San Francisco", "point_type": 1, "updated_at": "2026-04-25T01:45:17.553106+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-24 20:45:17.553106-05
280	tab_routes	53	I	\N	{"id_route": 53, "is_active": true, "last_trip": null, "created_at": "2026-04-25T05:12:05.297406+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta corta 18-21", "route_fare": 0, "updated_at": null, "color_route": "#3BF79F", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 00:12:05.297406-05
281	tab_route_points	358	I	\N	{"id_point": 358, "is_active": true, "created_at": "2026-04-25T05:17:51.064773+00:00", "name_point": "Avenida Carrera 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.064773-05
282	tab_route_points	359	I	\N	{"id_point": 359, "is_active": true, "created_at": "2026-04-25T05:17:51.094042+00:00", "name_point": "Parqueadero Estadio", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.094042-05
283	tab_route_points	360	I	\N	{"id_point": 360, "is_active": true, "created_at": "2026-04-25T05:17:51.105247+00:00", "name_point": "Unidad Deportiva Américo Montanini", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.105247-05
284	tab_route_points	361	I	\N	{"id_point": 361, "is_active": true, "created_at": "2026-04-25T05:17:51.115195+00:00", "name_point": "Parqueadero Estadio", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.115195-05
285	tab_route_points	362	I	\N	{"id_point": 362, "is_active": true, "created_at": "2026-04-25T05:17:51.125104+00:00", "name_point": "Rotonda Estadio, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.125104-05
286	tab_route_points	363	I	\N	{"id_point": 363, "is_active": true, "created_at": "2026-04-25T05:17:51.132818+00:00", "name_point": "Carrera 30 #14-27, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.132818-05
287	tab_route_points	364	I	\N	{"id_point": 364, "is_active": true, "created_at": "2026-04-25T05:17:51.141723+00:00", "name_point": "carrera 30 #16-41, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.141723-05
288	tab_route_points	365	I	\N	{"id_point": 365, "is_active": true, "created_at": "2026-04-25T05:17:51.149313+00:00", "name_point": "Carrera 30, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.149313-05
289	tab_route_points	366	I	\N	{"id_point": 366, "is_active": true, "created_at": "2026-04-25T05:17:51.157594+00:00", "name_point": "Carrera 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.157594-05
290	tab_route_points	367	I	\N	{"id_point": 367, "is_active": true, "created_at": "2026-04-25T05:17:51.170054+00:00", "name_point": "Calle 20 #30-27, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.170054-05
291	tab_route_points	368	I	\N	{"id_point": 368, "is_active": true, "created_at": "2026-04-25T05:17:51.179383+00:00", "name_point": "Calle 21", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.179383-05
292	tab_route_points	369	I	\N	{"id_point": 369, "is_active": true, "created_at": "2026-04-25T05:17:51.187511+00:00", "name_point": "Avenida Quebrada Seca, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.187511-05
293	tab_route_points	370	I	\N	{"id_point": 370, "is_active": true, "created_at": "2026-04-25T05:17:51.196001+00:00", "name_point": "Carrera 30 #29-01, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.196001-05
294	tab_route_points	371	I	\N	{"id_point": 371, "is_active": true, "created_at": "2026-04-25T05:17:51.204515+00:00", "name_point": "Calle 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.204515-05
295	tab_route_points	372	I	\N	{"id_point": 372, "is_active": true, "created_at": "2026-04-25T05:17:51.212405+00:00", "name_point": "Calle 31", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.212405-05
296	tab_route_points	373	I	\N	{"id_point": 373, "is_active": true, "created_at": "2026-04-25T05:17:51.221585+00:00", "name_point": "Calle 31", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.221585-05
297	tab_route_points	374	I	\N	{"id_point": 374, "is_active": true, "created_at": "2026-04-25T05:17:51.230486+00:00", "name_point": "Carrera 30", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.230486-05
298	tab_route_points	375	I	\N	{"id_point": 375, "is_active": true, "created_at": "2026-04-25T05:17:51.2406+00:00", "name_point": "Calle 33, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.2406-05
299	tab_route_points	376	I	\N	{"id_point": 376, "is_active": true, "created_at": "2026-04-25T05:17:51.25219+00:00", "name_point": "Calle 35 #30-15, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.25219-05
300	tab_route_points	377	I	\N	{"id_point": 377, "is_active": true, "created_at": "2026-04-25T05:17:51.267717+00:00", "name_point": "Calle 35, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.267717-05
301	tab_route_points	378	I	\N	{"id_point": 378, "is_active": true, "created_at": "2026-04-25T05:17:51.286312+00:00", "name_point": "Avenida Calle 36", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.286312-05
302	tab_route_points	379	I	\N	{"id_point": 379, "is_active": true, "created_at": "2026-04-25T05:17:51.301273+00:00", "name_point": "Avenida Calle 36", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.301273-05
303	tab_route_points	380	I	\N	{"id_point": 380, "is_active": true, "created_at": "2026-04-25T05:17:51.311937+00:00", "name_point": "Carrera 28", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.311937-05
304	tab_route_points	381	I	\N	{"id_point": 381, "is_active": true, "created_at": "2026-04-25T05:17:51.321492+00:00", "name_point": "Avenida Calle 36", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.321492-05
305	tab_route_points	382	I	\N	{"id_point": 382, "is_active": true, "created_at": "2026-04-25T05:17:51.332532+00:00", "name_point": "Avenida Carrera 27 #36-07, Comuna 13 - Oriental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:17:51.332532-05
306	tab_route_points	383	I	\N	{"id_point": 383, "is_active": true, "created_at": "2026-04-25T05:18:50.076432+00:00", "name_point": "Túnel Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.076432-05
307	tab_route_points	384	I	\N	{"id_point": 384, "is_active": true, "created_at": "2026-04-25T05:18:50.08171+00:00", "name_point": "Túnel Avenida Quebrada Seca", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.08171-05
308	tab_route_points	385	I	\N	{"id_point": 385, "is_active": true, "created_at": "2026-04-25T05:18:50.140236+00:00", "name_point": "Avenida Calle 14", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.140236-05
309	tab_route_points	386	I	\N	{"id_point": 386, "is_active": true, "created_at": "2026-04-25T05:18:50.171557+00:00", "name_point": "Cra 27 #12-27, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.171557-05
310	tab_route_points	387	I	\N	{"id_point": 387, "is_active": true, "created_at": "2026-04-25T05:18:50.19351+00:00", "name_point": "Avenida Carrera 27, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.19351-05
311	tab_route_points	388	I	\N	{"id_point": 388, "is_active": true, "created_at": "2026-04-25T05:18:50.199647+00:00", "name_point": "Túnel Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.199647-05
312	tab_route_points	389	I	\N	{"id_point": 389, "is_active": true, "created_at": "2026-04-25T05:18:50.206575+00:00", "name_point": "Calle 20", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.206575-05
313	tab_route_points	390	I	\N	{"id_point": 390, "is_active": true, "created_at": "2026-04-25T05:18:50.208949+00:00", "name_point": "Calle 18, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.208949-05
314	tab_route_points	391	I	\N	{"id_point": 391, "is_active": true, "created_at": "2026-04-25T05:18:50.216679+00:00", "name_point": "Parque Calle 16", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:18:50.216679-05
315	tab_routes	54	I	\N	{"id_route": 54, "is_active": true, "last_trip": null, "created_at": "2026-04-25T05:20:04.594691+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta 30-27", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 00:20:04.594691-05
316	tab_routes	54	U	{"id_route": 54, "is_active": true, "last_trip": null, "created_at": "2026-04-25T05:20:04.594691+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta 30-27", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 54, "is_active": true, "last_trip": null, "created_at": "2026-04-25T05:20:04.594691+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta 30-27", "route_fare": 0, "updated_at": "2026-04-25T05:20:25.043988+00:00", "color_route": "#F7E73B", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 00:20:25.043988-05
317	tab_route_points	392	I	\N	{"id_point": 392, "is_active": true, "created_at": "2026-04-25T05:21:44.827398+00:00", "name_point": "Calle 18, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.827398-05
318	tab_route_points	393	I	\N	{"id_point": 393, "is_active": true, "created_at": "2026-04-25T05:21:44.837937+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.837937-05
319	tab_route_points	394	I	\N	{"id_point": 394, "is_active": true, "created_at": "2026-04-25T05:21:44.847357+00:00", "name_point": "Calle 17", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.847357-05
320	tab_route_points	395	I	\N	{"id_point": 395, "is_active": true, "created_at": "2026-04-25T05:21:44.858685+00:00", "name_point": "Avenida Carrera 27", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.858685-05
321	tab_route_points	396	I	\N	{"id_point": 396, "is_active": true, "created_at": "2026-04-25T05:21:44.870299+00:00", "name_point": "Carrera 27 #13-34, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.870299-05
322	tab_route_points	397	I	\N	{"id_point": 397, "is_active": true, "created_at": "2026-04-25T05:21:44.883246+00:00", "name_point": "Cra 27 #12-27, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.883246-05
323	tab_route_points	398	I	\N	{"id_point": 398, "is_active": true, "created_at": "2026-04-25T05:21:44.897871+00:00", "name_point": "Calle 11, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.897871-05
324	tab_route_points	399	I	\N	{"id_point": 399, "is_active": true, "created_at": "2026-04-25T05:21:44.909547+00:00", "name_point": "Avenida Carrera 27, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.909547-05
325	tab_route_points	400	I	\N	{"id_point": 400, "is_active": true, "created_at": "2026-04-25T05:21:44.9193+00:00", "name_point": "Parque Caballo de Bolivar", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 00:21:44.9193-05
326	tab_routes	55	I	\N	{"id_route": 55, "is_active": true, "last_trip": null, "created_at": "2026-04-25T06:22:45.667582+00:00", "first_trip": null, "id_company": 1, "name_route": "RUTA18 NUEVA", "route_fare": 0, "updated_at": null, "color_route": "#E9B701", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 01:22:45.667582-05
327	tab_route_points	401	I	\N	{"id_point": 401, "is_active": true, "created_at": "2026-04-25T06:25:06.214278+00:00", "name_point": "Carrera 25", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 01:25:06.214278-05
328	tab_route_points	402	I	\N	{"id_point": 402, "is_active": true, "created_at": "2026-04-25T06:25:06.233497+00:00", "name_point": "Calle 15 #25-46, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 01:25:06.233497-05
329	tab_route_points	403	I	\N	{"id_point": 403, "is_active": true, "created_at": "2026-04-25T06:25:06.241849+00:00", "name_point": "Carrera 25 #16-52, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 01:25:06.241849-05
330	tab_route_points	404	I	\N	{"id_point": 404, "is_active": true, "created_at": "2026-04-25T06:25:06.253514+00:00", "name_point": "Carrera 25 #18-39, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 01:25:06.253514-05
331	tab_route_points	405	I	\N	{"id_point": 405, "is_active": true, "created_at": "2026-04-25T06:25:06.266137+00:00", "name_point": "Avenida Calle 14 #25-30, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 01:25:06.266137-05
332	tab_route_points	406	I	\N	{"id_point": 406, "is_active": true, "created_at": "2026-04-25T06:25:06.277253+00:00", "name_point": "Calle 19", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 01:25:06.277253-05
333	tab_route_points	407	I	\N	{"id_point": 407, "is_active": true, "created_at": "2026-04-25T06:25:06.288731+00:00", "name_point": "Carrera 25", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 01:25:06.288731-05
334	tab_route_points	408	I	\N	{"id_point": 408, "is_active": true, "created_at": "2026-04-25T06:25:06.301376+00:00", "name_point": "Carrera 25 #16-20, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 01:25:06.301376-05
335	tab_route_points	409	I	\N	{"id_point": 409, "is_active": true, "created_at": "2026-04-25T07:17:54.16488+00:00", "name_point": "Calle 8", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.16488-05
336	tab_route_points	410	I	\N	{"id_point": 410, "is_active": true, "created_at": "2026-04-25T07:17:54.189073+00:00", "name_point": "Carrera 16A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.189073-05
337	tab_route_points	411	I	\N	{"id_point": 411, "is_active": true, "created_at": "2026-04-25T07:17:54.203723+00:00", "name_point": "Carrera 15B", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.203723-05
338	tab_route_points	412	I	\N	{"id_point": 412, "is_active": true, "created_at": "2026-04-25T07:17:54.214978+00:00", "name_point": "Calle 11, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.214978-05
339	tab_route_points	413	I	\N	{"id_point": 413, "is_active": true, "created_at": "2026-04-25T07:17:54.225338+00:00", "name_point": "Calle 8", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.225338-05
340	tab_route_points	414	I	\N	{"id_point": 414, "is_active": true, "created_at": "2026-04-25T07:17:54.233321+00:00", "name_point": "Calle 9, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.233321-05
341	tab_route_points	415	I	\N	{"id_point": 415, "is_active": true, "created_at": "2026-04-25T07:17:54.239866+00:00", "name_point": "Carrera 24A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.239866-05
342	tab_route_points	416	I	\N	{"id_point": 416, "is_active": true, "created_at": "2026-04-25T07:17:54.248381+00:00", "name_point": "Carrera 21", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.248381-05
343	tab_route_points	417	I	\N	{"id_point": 417, "is_active": true, "created_at": "2026-04-25T07:17:54.255948+00:00", "name_point": "Carrera 24", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.255948-05
344	tab_route_points	418	I	\N	{"id_point": 418, "is_active": true, "created_at": "2026-04-25T07:17:54.264015+00:00", "name_point": "Calle 9 #23-61, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.264015-05
345	tab_route_points	419	I	\N	{"id_point": 419, "is_active": true, "created_at": "2026-04-25T07:17:54.272398+00:00", "name_point": "Calle 10A, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.272398-05
346	tab_route_points	420	I	\N	{"id_point": 420, "is_active": true, "created_at": "2026-04-25T07:17:54.279356+00:00", "name_point": "Calle 8A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.279356-05
347	tab_route_points	421	I	\N	{"id_point": 421, "is_active": true, "created_at": "2026-04-25T07:17:54.288324+00:00", "name_point": "Calle 12", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:17:54.288324-05
348	tab_route_points	422	I	\N	{"id_point": 422, "is_active": true, "created_at": "2026-04-25T07:18:35.156799+00:00", "name_point": "Calle 4", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:18:35.156799-05
349	tab_route_points	423	I	\N	{"id_point": 423, "is_active": true, "created_at": "2026-04-25T07:18:35.162163+00:00", "name_point": "Carrera 11", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:18:35.162163-05
350	tab_route_points	424	I	\N	{"id_point": 424, "is_active": true, "created_at": "2026-04-25T07:18:35.220855+00:00", "name_point": "Carrera 14", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:18:35.220855-05
351	tab_route_points	425	I	\N	{"id_point": 425, "is_active": true, "created_at": "2026-04-25T07:18:35.252731+00:00", "name_point": "Calle 0A", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:18:35.252731-05
352	tab_route_points	426	I	\N	{"id_point": 426, "is_active": true, "created_at": "2026-04-25T07:18:35.253092+00:00", "name_point": "Calle 3", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:18:35.253092-05
353	tab_route_points	427	I	\N	{"id_point": 427, "is_active": true, "created_at": "2026-04-25T07:18:35.252966+00:00", "name_point": "Avenida Carrera 15", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:18:35.252966-05
354	tab_route_points	428	I	\N	{"id_point": 428, "is_active": true, "created_at": "2026-04-25T07:18:35.346372+00:00", "name_point": "Carrera 13", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:18:35.346372-05
355	tab_route_points	429	I	\N	{"id_point": 429, "is_active": true, "created_at": "2026-04-25T07:23:24.392238+00:00", "name_point": "Calle 4", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:23:24.392238-05
356	tab_route_points	430	I	\N	{"id_point": 430, "is_active": true, "created_at": "2026-04-25T07:23:24.398305+00:00", "name_point": "Carrera 19", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:23:24.398305-05
357	tab_route_points	431	I	\N	{"id_point": 431, "is_active": true, "created_at": "2026-04-25T07:23:24.410004+00:00", "name_point": "Calle 6", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:23:24.410004-05
358	tab_route_points	432	I	\N	{"id_point": 432, "is_active": true, "created_at": "2026-04-25T07:23:24.419114+00:00", "name_point": "Calle 6", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:23:24.419114-05
423	tab_companies	4	I	\N	{"is_active": true, "created_at": "2026-05-11T21:17:35.936129-05:00", "id_company": 4, "updated_at": null, "nit_company": "800456789-4", "user_create": 1, "user_update": null, "company_name": "Cotrander"}	1	2026-05-11 21:17:35.936129-05
359	tab_route_points	190	U	{"id_point": 190, "is_active": true, "created_at": "2026-04-21T22:32:38.715605+00:00", "name_point": "Diagonal 15 #45-54, Comuna 5 Garcia Rovira", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 190, "is_active": true, "created_at": "2026-04-21T22:32:38.715605+00:00", "name_point": "Diagonal 15 #45-54, Comuna 5 Garcia Rovira", "point_type": 1, "updated_at": "2026-04-25T07:32:39.720403+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:32:39.720403-05
360	tab_route_points	190	U	{"id_point": 190, "is_active": true, "created_at": "2026-04-21T22:32:38.715605+00:00", "name_point": "Diagonal 15 #45-54, Comuna 5 Garcia Rovira", "point_type": 1, "updated_at": "2026-04-25T07:32:39.720403+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	{"id_point": 190, "is_active": true, "created_at": "2026-04-21T22:32:38.715605+00:00", "name_point": "Diagonal 15 #45-54, Comuna 5 Garcia Rovira", "point_type": 1, "updated_at": "2026-04-25T07:33:05.027469+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:33:05.027469-05
361	tab_route_points	190	U	{"id_point": 190, "is_active": true, "created_at": "2026-04-21T22:32:38.715605+00:00", "name_point": "Diagonal 15 #45-54, Comuna 5 Garcia Rovira", "point_type": 1, "updated_at": "2026-04-25T07:33:05.027469+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	{"id_point": 190, "is_active": false, "created_at": "2026-04-21T22:32:38.715605+00:00", "name_point": "Diagonal 15 #45-54, Comuna 5 Garcia Rovira", "point_type": 1, "updated_at": "2026-04-25T07:33:10.656666+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:33:10.656666-05
362	tab_route_points	327	U	{"id_point": 327, "is_active": true, "created_at": "2026-04-24T06:45:43.530103+00:00", "name_point": "Carrera 18", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 327, "is_active": false, "created_at": "2026-04-24T06:45:43.530103+00:00", "name_point": "Carrera 18", "point_type": 1, "updated_at": "2026-04-25T07:34:30.833579+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:34:30.833579-05
363	tab_route_points	180	U	{"id_point": 180, "is_active": true, "created_at": "2026-04-21T02:07:58.010317+00:00", "name_point": "Carrera 17 ## 9-50, Comuna 3 San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	{"id_point": 180, "is_active": true, "created_at": "2026-04-21T02:07:58.010317+00:00", "name_point": "aaa bbb", "point_type": 1, "updated_at": "2026-04-25T07:43:55.841319+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:43:55.841319-05
364	tab_route_points	180	U	{"id_point": 180, "is_active": true, "created_at": "2026-04-21T02:07:58.010317+00:00", "name_point": "aaa bbb", "point_type": 1, "updated_at": "2026-04-25T07:43:55.841319+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	{"id_point": 180, "is_active": false, "created_at": "2026-04-21T02:07:58.010317+00:00", "name_point": "aaa bbb", "point_type": 1, "updated_at": "2026-04-25T07:44:09.843117+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:44:09.843117-05
365	tab_route_points	180	U	{"id_point": 180, "is_active": false, "created_at": "2026-04-21T02:07:58.010317+00:00", "name_point": "aaa bbb", "point_type": 1, "updated_at": "2026-04-25T07:44:09.843117+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	{"id_point": 180, "is_active": true, "created_at": "2026-04-21T02:07:58.010317+00:00", "name_point": "aaa bbb", "point_type": 1, "updated_at": "2026-04-25T07:44:35.817974+00:00", "user_create": 1, "user_update": 1, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 02:44:35.817974-05
366	tab_routes	56	I	\N	{"id_route": 56, "is_active": true, "last_trip": null, "created_at": "2026-04-25T08:00:43.020119+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta rompoy", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 03:00:43.020119-05
367	tab_routes	57	I	\N	{"id_route": 57, "is_active": true, "last_trip": null, "created_at": "2026-04-25T08:13:56.814312+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta directa2", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 03:13:56.814312-05
368	tab_routes	58	I	\N	{"id_route": 58, "is_active": true, "last_trip": null, "created_at": "2026-04-25T08:15:08.63784+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta Z", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 03:15:08.63784-05
369	tab_routes	59	I	\N	{"id_route": 59, "is_active": true, "last_trip": null, "created_at": "2026-04-25T08:16:52.635771+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta centro comercial cacique", "route_fare": 0, "updated_at": null, "color_route": "#3BB8F7", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 03:16:52.635771-05
370	tab_routes	60	I	\N	{"id_route": 60, "is_active": true, "last_trip": null, "created_at": "2026-04-25T08:31:38.119402+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta larga", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 03:31:38.119402-05
371	tab_route_points	433	I	\N	{"id_point": 433, "is_active": true, "created_at": "2026-04-25T08:32:52.890153+00:00", "name_point": "Carrera 19 #22-03, Comuna Occidental", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 03:32:52.890153-05
372	tab_route_points	434	I	\N	{"id_point": 434, "is_active": true, "created_at": "2026-04-25T08:32:52.906666+00:00", "name_point": "Calle 24, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 03:32:52.906666-05
373	tab_route_points	435	I	\N	{"id_point": 435, "is_active": true, "created_at": "2026-04-25T08:32:52.912948+00:00", "name_point": "Carrera 18", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 03:32:52.912948-05
374	tab_routes	61	I	\N	{"id_route": 61, "is_active": true, "last_trip": null, "created_at": "2026-04-25T08:33:22.705341+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta cerrada", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 03:33:22.705341-05
375	tab_routes	40	U	{"id_route": 40, "is_active": true, "last_trip": null, "created_at": "2026-04-20T02:08:02.795527+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta extraña", "route_fare": 0, "updated_at": null, "color_route": "#F73B3B", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 40, "is_active": true, "last_trip": null, "created_at": "2026-04-20T02:08:02.795527+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta extraña", "route_fare": 0, "updated_at": "2026-04-25T16:24:15.983898+00:00", "color_route": "#F73B3B", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 11:24:15.983898-05
376	tab_routes	40	U	{"id_route": 40, "is_active": true, "last_trip": null, "created_at": "2026-04-20T02:08:02.795527+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta extraña", "route_fare": 0, "updated_at": "2026-04-25T16:24:15.983898+00:00", "color_route": "#F73B3B", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 40, "is_active": false, "last_trip": null, "created_at": "2026-04-20T02:08:02.795527+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta extraña", "route_fare": 0, "updated_at": "2026-04-25T16:24:16.035098+00:00", "color_route": "#F73B3B", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 11:24:16.035098-05
424	tab_route_points	439	I	\N	{"id_point": 439, "is_active": true, "created_at": "2026-05-13T05:12:36.048688+00:00", "name_point": "Calle 20 #22-20, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-05-13 00:12:36.048688-05
377	tab_routes	44	U	{"id_route": 44, "is_active": true, "last_trip": null, "created_at": "2026-04-22T08:19:24.77943+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta rara", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 44, "is_active": true, "last_trip": null, "created_at": "2026-04-22T08:19:24.77943+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta rara", "route_fare": 0, "updated_at": "2026-04-25T16:50:07.824478+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 11:50:07.824478-05
378	tab_routes	44	U	{"id_route": 44, "is_active": true, "last_trip": null, "created_at": "2026-04-22T08:19:24.77943+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta rara", "route_fare": 0, "updated_at": "2026-04-25T16:50:07.824478+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 44, "is_active": false, "last_trip": null, "created_at": "2026-04-22T08:19:24.77943+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta rara", "route_fare": 0, "updated_at": "2026-04-25T16:50:07.854724+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 11:50:07.854724-05
379	tab_routes	35	U	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-19T21:48:17.261398+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-25T17:03:19.149985+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:03:19.149985-05
380	tab_routes	35	U	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-25T17:03:19.149985+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-25T17:03:19.189759+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:03:19.189759-05
381	tab_routes	52	U	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": null, "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:16:26.279387+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:16:26.279387-05
382	tab_routes	52	U	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:16:26.279387+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:16:35.535708+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:16:35.535708-05
383	tab_routes	52	U	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:16:35.535708+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:16:48.857697+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:16:48.857697-05
384	tab_routes	35	U	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-25T17:03:19.189759+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-25T17:18:18.22361+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:18:18.22361-05
385	tab_routes	35	U	{"id_route": 35, "is_active": true, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-25T17:18:18.22361+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 35, "is_active": false, "last_trip": null, "created_at": "2026-04-19T07:11:12.813633+00:00", "first_trip": null, "id_company": 1, "name_route": "cr22 nueva", "route_fare": 0, "updated_at": "2026-04-25T17:18:18.243167+00:00", "color_route": "#667EEA", "is_circular": true, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:18:18.243167-05
386	tab_routes	52	U	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:16:48.857697+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:18:35.09179+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:18:35.09179-05
387	tab_routes	52	U	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:18:35.09179+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:30:04.478856+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:30:04.478856-05
388	tab_routes	52	U	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:30:04.478856+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	{"id_route": 52, "is_active": true, "last_trip": null, "created_at": "2026-04-24T06:40:22.954942+00:00", "first_trip": null, "id_company": 1, "name_route": "ruta al Campanazo", "route_fare": 0, "updated_at": "2026-04-25T17:31:06.88567+00:00", "color_route": "#3B82F6", "is_circular": false, "user_create": 1, "user_update": 1, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 12:31:06.88567-05
390	tab_buses	16	I	\N	{"id_bus": 16, "amb_code": "AMB-0213", "id_brand": 8, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-25T20:24:56.806325+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2025, "updated_at": null, "user_create": 1, "user_update": null, "capacity_bus": 36, "plate_number": "HDF225", "code_internal": "0067", "gps_device_id": "23343542653434", "chassis_number": "43434334"}	1	2026-04-25 15:24:56.806325-05
393	tab_route_points	436	I	\N	{"id_point": 436, "is_active": true, "created_at": "2026-04-25T20:34:14.993132+00:00", "name_point": "Carrera 25 #18-39, Comuna de San Francisco", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 15:34:14.993132-05
394	tab_route_points	437	I	\N	{"id_point": 437, "is_active": true, "created_at": "2026-04-25T20:34:14.999218+00:00", "name_point": "Calle 19", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 15:34:14.999218-05
395	tab_route_points	438	I	\N	{"id_point": 438, "is_active": true, "created_at": "2026-04-25T20:34:15.044609+00:00", "name_point": "Boulevard Bolívar", "point_type": 1, "updated_at": null, "user_create": 1, "user_update": null, "descrip_point": null, "is_checkpoint": false}	1	2026-04-25 15:34:15.044609-05
396	tab_routes	62	I	\N	{"id_route": 62, "is_active": true, "last_trip": null, "created_at": "2026-04-25T20:38:37.88482+00:00", "first_trip": null, "id_company": 4, "name_route": "RUTA ADSO", "route_fare": 0, "updated_at": null, "color_route": "#3BF78C", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-25 15:38:37.88482-05
397	tab_drivers	55414523	I	\N	{"id_arl": 3, "id_eps": 4, "id_driver": 55414523, "id_status": 1, "is_active": true, "birth_date": "1960-12-02", "blood_type": "O-", "created_at": "2026-04-29T00:59:50.869162+00:00", "date_entry": "2026-04-29", "updated_at": null, "license_cat": "C3", "license_exp": "2027-03-05", "name_driver": "carlos REINEL", "user_create": 1, "user_update": null, "email_driver": "carlos12@gmail.com", "phone_driver": "3104032985", "gender_driver": "SA", "address_driver": "Calle 12 #29-25", "emergency_phone": "3144427003", "emergency_contact": "carlos rivera Perez"}	1	2026-04-28 19:59:50.869162-05
398	tab_drivers	55414523	U	{"id_arl": 3, "id_eps": 4, "id_driver": 55414523, "id_status": 1, "is_active": true, "birth_date": "1960-12-02", "blood_type": "O-", "created_at": "2026-04-29T00:59:50.869162+00:00", "date_entry": "2026-04-29", "updated_at": null, "license_cat": "C3", "license_exp": "2027-03-05", "name_driver": "carlos REINEL", "user_create": 1, "user_update": null, "email_driver": "carlos12@gmail.com", "phone_driver": "3104032985", "gender_driver": "SA", "address_driver": "Calle 12 #29-25", "emergency_phone": "3144427003", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 3, "id_eps": 4, "id_driver": 55414523, "id_status": 1, "is_active": true, "birth_date": "1960-12-02", "blood_type": "O-", "created_at": "2026-04-29T00:59:50.869162+00:00", "date_entry": "2026-04-29", "updated_at": "2026-04-29T01:01:03.613631+00:00", "license_cat": "C3", "license_exp": "2027-03-05", "name_driver": "carlos REINEL Castro", "user_create": 1, "user_update": 1, "email_driver": "carlos12@gmail.com", "phone_driver": "3104032985", "gender_driver": "SA", "address_driver": "Calle 12 #29-25", "emergency_phone": "3144427003", "emergency_contact": "carlos rivera Perez"}	1	2026-04-28 20:01:03.613631-05
400	tab_drivers	55414123	I	\N	{"id_arl": 5, "id_eps": 9, "id_driver": 55414123, "id_status": 1, "is_active": true, "birth_date": "1960-12-02", "blood_type": "A+", "created_at": "2026-04-29T01:31:40.24211+00:00", "date_entry": "2026-04-29", "updated_at": null, "license_cat": "C2", "license_exp": "2027-03-05", "name_driver": "ANDRES LOPEZ", "user_create": 1, "user_update": null, "email_driver": "carlos12@gmail.com", "phone_driver": "3104032985", "gender_driver": "SA", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-04-28 20:31:40.24211-05
401	tab_drivers	55414123	U	{"id_arl": 5, "id_eps": 9, "id_driver": 55414123, "id_status": 1, "is_active": true, "birth_date": "1960-12-02", "blood_type": "A+", "created_at": "2026-04-29T01:31:40.24211+00:00", "date_entry": "2026-04-29", "updated_at": null, "license_cat": "C2", "license_exp": "2027-03-05", "name_driver": "ANDRES LOPEZ", "user_create": 1, "user_update": null, "email_driver": "carlos12@gmail.com", "phone_driver": "3104032985", "gender_driver": "SA", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 5, "id_eps": 9, "id_driver": 55414123, "id_status": 1, "is_active": true, "birth_date": "1960-12-02", "blood_type": "A+", "created_at": "2026-04-29T01:31:40.24211+00:00", "date_entry": "2026-04-29", "updated_at": "2026-04-29T01:32:04.433796+00:00", "license_cat": "C2", "license_exp": "2027-03-05", "name_driver": "ANDRES LOPEZ DIAZ", "user_create": 1, "user_update": 1, "email_driver": "carlos12@gmail.com", "phone_driver": "3104032985", "gender_driver": "SA", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-04-28 20:32:04.433796-05
404	tab_buses	21	I	\N	{"id_bus": 21, "amb_code": "AMB-0132", "id_brand": 9, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-29T06:38:20.897375+00:00", "id_company": 6, "model_name": "citaro", "model_year": 2023, "updated_at": null, "user_create": 1, "user_update": null, "capacity_bus": 44, "plate_number": "GDF455", "code_internal": "0123", "gps_device_id": "32323435443", "chassis_number": "2323234454"}	1	2026-04-29 01:38:20.897375-05
405	tab_buses	22	I	\N	{"id_bus": 22, "amb_code": "AMB-1332", "id_brand": 3, "id_owner": 1234567890, "color_app": "#CCCCCC", "color_bus": "blanco", "id_status": 1, "is_active": true, "photo_url": null, "created_at": "2026-04-29T06:47:39.563437+00:00", "id_company": 4, "model_name": "citaro", "model_year": 2023, "updated_at": null, "user_create": 1, "user_update": null, "capacity_bus": 44, "plate_number": "LDR422", "code_internal": "0719", "gps_device_id": "3232343767", "chassis_number": "2323234467"}	1	2026-04-29 01:47:39.563437-05
406	tab_routes	63	I	\N	{"id_route": 63, "is_active": true, "last_trip": null, "created_at": "2026-04-30T00:27:08.391358+00:00", "first_trip": null, "id_company": 1, "name_route": "cr 24 exclus", "route_fare": 0, "updated_at": null, "color_route": "#3BF773", "is_circular": false, "user_create": 1, "user_update": null, "descrip_route": null, "return_route_sign": null, "departure_route_sign": null}	1	2026-04-29 19:27:08.391358-05
407	tab_drivers	55414523	U	{"id_arl": 3, "id_eps": 4, "id_driver": 55414523, "id_status": 1, "is_active": true, "birth_date": "1960-12-02", "blood_type": "O-", "created_at": "2026-04-29T00:59:50.869162+00:00", "date_entry": "2026-04-29", "updated_at": "2026-04-29T01:01:03.613631+00:00", "license_cat": "C3", "license_exp": "2027-03-05", "name_driver": "carlos REINEL Castro", "user_create": 1, "user_update": 1, "email_driver": "carlos12@gmail.com", "phone_driver": "3104032985", "gender_driver": "SA", "address_driver": "Calle 12 #29-25", "emergency_phone": "3144427003", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 3, "id_eps": 4, "id_driver": 55414523, "id_status": 1, "is_active": true, "birth_date": "1960-12-02", "blood_type": "O-", "created_at": "2026-04-29T00:59:50.869162+00:00", "date_entry": "2026-04-29", "updated_at": "2026-05-02T02:48:36.466348+00:00", "license_cat": "C3", "license_exp": "2027-03-05", "name_driver": "carlos REINEL Castro", "user_create": 1, "user_update": 1, "email_driver": "carlos12@gmail.com", "phone_driver": "3104032985", "gender_driver": "SA", "address_driver": "Calle 12 #29-25", "emergency_phone": "3144427003", "emergency_contact": "carlos rivera Perez"}	1	2026-05-01 21:48:36.466348-05
409	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": null, "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": null, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:09:41.891686+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:09:41.891686-05
410	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:09:41.891686+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:09:57.503982+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:09:57.503982-05
411	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:09:57.503982+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:12:11.594467+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:12:11.594467-05
412	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:12:11.594467+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:19:01.866638+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:19:01.866638-05
413	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:19:01.866638+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:19:20.198558+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:19:20.198558-05
414	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:19:20.198558+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:19:56.08432+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:19:56.08432-05
415	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:19:56.08432+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:20:19.530409+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:20:19.530409-05
416	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:20:19.530409+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": false, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:43:25.763268+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:43:25.763268-05
417	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": false, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:43:25.763268+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": false, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:43:29.496641+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-07 19:43:29.496641-05
418	tab_drivers	454524124	U	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": false, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T00:43:29.496641+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	{"id_arl": 9, "id_eps": 4, "id_driver": 454524124, "id_status": 1, "is_active": true, "birth_date": "2007-05-08", "blood_type": "O-", "created_at": "2026-03-31T05:59:47.485094+00:00", "date_entry": "2026-03-31", "updated_at": "2026-05-08T07:43:33.470015+00:00", "license_cat": "C1", "license_exp": "2027-08-05", "name_driver": "Alejandro Sanz", "user_create": 1, "user_update": 1, "email_driver": "alejozrico441@gmail.com", "phone_driver": "3104032985", "gender_driver": "O", "address_driver": "Calle 12 #29-25", "emergency_phone": "3104032985", "emergency_contact": "carlos rivera Perez"}	1	2026-05-08 02:43:33.470015-05
419	tab_bus_owners	1234567890	I	\N	{"id_owner": 1234567890, "full_name": "Empresa de Transporte ABC", "is_active": true, "created_at": "2026-05-11T21:17:35.891875-05:00", "updated_at": null, "email_owner": "empresa@transporte.com", "phone_owner": "3001234567", "user_create": 1, "user_update": null}	1	2026-05-11 21:17:35.891875-05
420	tab_companies	1	I	\N	{"is_active": true, "created_at": "2026-05-11T21:17:35.936129-05:00", "id_company": 1, "updated_at": null, "nit_company": "9001234561", "user_create": 1, "user_update": null, "company_name": "Metrolínea"}	1	2026-05-11 21:17:35.936129-05
421	tab_companies	2	I	\N	{"is_active": true, "created_at": "2026-05-11T21:17:35.936129-05:00", "id_company": 2, "updated_at": null, "nit_company": "800234567-2", "user_create": 1, "user_update": null, "company_name": "Cotraoriente"}	1	2026-05-11 21:17:35.936129-05
422	tab_companies	3	I	\N	{"is_active": true, "created_at": "2026-05-11T21:17:35.936129-05:00", "id_company": 3, "updated_at": null, "nit_company": "800345678-3", "user_create": 1, "user_update": null, "company_name": "Cootransmagdalena"}	1	2026-05-11 21:17:35.936129-05
\.


--
-- Data for Name: tab_brands; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_brands (id_brand, brand_name, created_at, is_active) FROM stdin;
1	Mercedes-Benz	2026-03-30 11:38:14.649135-05	t
2	Volvo	2026-03-30 11:38:14.649135-05	t
3	Scania	2026-03-30 11:38:14.649135-05	t
4	Hino	2026-03-30 11:38:14.649135-05	t
5	Marcopolo	2026-03-30 11:38:14.649135-05	t
6	Busscar	2026-03-30 11:38:14.649135-05	t
7	Modasa	2026-03-30 11:38:14.649135-05	t
8	Superpolo	2026-03-30 11:38:14.649135-05	t
9	King Long	2026-03-30 11:38:14.649135-05	t
10	Yutong	2026-03-30 11:38:14.649135-05	t
11	Zhongtong	2026-03-30 11:38:14.649135-05	t
12	Mascarello	2026-03-30 11:38:14.649135-05	t
13	Nueva_Marca	2026-03-30 22:29:11.46017-05	t
\.


--
-- Data for Name: tab_bus_assignments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_bus_assignments (id_bus, id_driver, assigned_at, unassigned_at, assigned_by, unassigned_by) FROM stdin;
1	454524124	2026-03-31 01:12:10.200922-05	\N	1	\N
4	5454145443	2026-04-10 01:20:59.637039-05	\N	1	\N
7	52545454	2026-04-14 20:24:52.5896-05	\N	1	\N
8	52545454233	2026-04-14 20:55:42.180551-05	\N	1	\N
13	14545454	2026-04-15 00:40:35.987906-05	\N	1	\N
10	525454512	2026-04-15 00:40:41.25895-05	\N	1	\N
12	525454523	2026-04-15 00:40:46.619005-05	\N	1	\N
9	125454451	2026-04-15 00:45:15.503914-05	\N	1	\N
11	123525454	2026-04-15 00:45:20.026889-05	\N	1	\N
2	45452412	2026-03-31 17:27:54.3976-05	2026-04-20 15:54:40.722552-05	1	1
14	45452412	2026-04-25 11:12:49.864771-05	\N	1	\N
16	1454512323	2026-04-25 15:40:50.264997-05	\N	1	\N
21	55414123	2026-04-29 01:38:50.076835-05	\N	1	\N
\.


--
-- Data for Name: tab_bus_insurance; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_bus_insurance (id_bus, id_insurance_type, id_insurance, id_insurer, start_date_insu, end_date_insu, doc_url, created_at, updated_at, user_create, user_update) FROM stdin;
\.


--
-- Data for Name: tab_bus_owners; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_bus_owners (id_owner, full_name, phone_owner, email_owner, is_active, created_at, updated_at, user_create, user_update) FROM stdin;
1234567890	Empresa de Transporte ABC	3001234567	empresa@transporte.com	t	2026-03-30 11:38:14.649135-05	\N	1	\N
\.


--
-- Data for Name: tab_bus_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_bus_statuses (id_status, status_name, descrip_status, color_hex, is_active) FROM stdin;
1	disponible	Bus listo para ser asignado a un viaje	#4CAF50	t
2	en_ruta	Bus operando actualmente en un viaje	#2196F3	t
3	mantenimiento	Bus en taller, no disponible temporalmente	#FFA500	t
4	fuera_de_servicio	Bus con falla grave, requiere intervención	#F44336	t
\.


--
-- Data for Name: tab_bus_transit_docs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_bus_transit_docs (id_doc, id_bus, doc_number, init_date, end_date, doc_url, created_at, updated_at, user_create, user_update) FROM stdin;
\.


--
-- Data for Name: tab_buses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_buses (id_bus, plate_number, amb_code, code_internal, id_company, id_brand, model_name, model_year, capacity_bus, chassis_number, color_bus, color_app, photo_url, gps_device_id, id_owner, id_status, is_active, created_at, updated_at, user_create, user_update) FROM stdin;
4	RMC310	AMB-1050	0054	3	3	citaro	2023	40	2114545414125654	blanco	#CCCCCC	\N	233435452125143	1234567890	1	t	2026-04-02 01:06:46.096135-05	\N	1	\N
1	HDF222	AMB-0025	001	6	7	citaro	2023	41	21145454144464	blanco	#CCCCCC	\N	2334354534	1234567890	1	t	2026-03-30 22:39:21.953943-05	2026-04-14 20:26:51.138671-05	1	1
7	KIA159	AMB-0031	0061	5	3	citaro	2022	41	2114545414125421	blanco	#24c645	\N	2334354521121	1234567890	1	t	2026-04-14 20:24:35.870151-05	2026-04-14 20:27:11.177316-05	1	1
8	JDF125	AMB-0098	002	6	7	citaro	2022	41	21145454141254564	blanco	#1a9328	\N	233435452112644	1234567890	1	t	2026-04-14 20:53:36.060801-05	\N	1	\N
9	MKL123	AMB-0044	0023	2	8	citaro	2022	41	211452454554	blanco	#CCCCCC	\N	2334354265454	1234567890	1	t	2026-04-14 23:36:18.541915-05	\N	1	\N
10	DLA123	AMB-0045	0035	6	5	citaro	2022	41	211452454	blanco	#CCCCCC	\N	2334354265	1234567890	1	t	2026-04-14 23:37:15.48317-05	\N	1	\N
11	MRE123	AMB-0085	0087	6	12	citaro	2022	41	456454545415	blanco	#CCCCCC	\N	23343541125212	1234567890	1	t	2026-04-14 23:59:44.409433-05	\N	1	\N
12	JHD789	AMB-0032	321	6	10	citaro	2023	23	4564545454556	blanco	#CCCCCC	\N	123225454545	1234567890	1	t	2026-04-15 00:01:42.735368-05	\N	1	\N
14	HDS223	AMB-0056	0019	3	9	citaro	2022	23	211454541324	blanco	#CCCCCC	\N	233435452143	1234567890	1	t	2026-04-18 10:14:33.619578-05	2026-04-18 10:17:13.941999-05	1	1
13	ABC316	AMB-0258	654	6	13	citaro	2022	39	21145454144464745	blanco	#CCCCCC	\N	2334354534454	1234567890	1	f	2026-04-15 00:02:48.060678-05	2026-04-21 20:25:29.327643-05	1	1
2	CIA158	AMB-0022	0032	3	1	citaro	2023	40	211454541412565	blanco	#CCCCCC	\N	23343545212514	1234567890	1	f	2026-03-31 17:27:26.116134-05	2026-04-21 20:51:51.428009-05	1	1
16	HDF225	AMB-0213	0067	6	8	citaro	2025	36	43434334	blanco	#CCCCCC	\N	23343542653434	1234567890	1	t	2026-04-25 15:24:56.806325-05	\N	1	\N
21	GDF455	AMB-0132	0123	6	9	citaro	2023	44	2323234454	blanco	#CCCCCC	\N	32323435443	1234567890	1	t	2026-04-29 01:38:20.897375-05	\N	1	\N
22	LDR422	AMB-1332	0719	4	3	citaro	2023	44	2323234467	blanco	#CCCCCC	\N	3232343767	1234567890	1	t	2026-04-29 01:47:39.563437-05	\N	1	\N
\.


--
-- Data for Name: tab_companies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_companies (id_company, company_name, nit_company, created_at, updated_at, user_create, user_update, is_active) FROM stdin;
1	Metrolínea	9001234561	2026-03-30 11:38:14.649135-05	\N	1	\N	t
2	Cotraoriente	800234567-2	2026-03-30 11:38:14.649135-05	\N	1	\N	t
5	Compañia Ola	26546564	2026-03-30 22:27:52.732272-05	2026-03-30 22:38:46.262343-05	1	1	t
4	Cotrander	800456789-4	2026-03-30 11:38:14.649135-05	2026-03-30 22:41:53.097638-05	1	1	t
3	Cootransmagdalena	800345678-3	2026-03-30 11:38:14.649135-05	2026-03-30 23:51:24.768783-05	1	1	t
6	Compañia Principal	32545345435	2026-04-14 20:26:32.780844-05	\N	1	\N	t
\.


--
-- Data for Name: tab_driver_accounts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_driver_accounts (id_driver, id_user, assigned_at, assigned_by) FROM stdin;
45452412	3	2026-04-15 00:38:03.800365-05	1
454524124	2	2026-05-08 02:43:43.354825-05	1
\.


--
-- Data for Name: tab_driver_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_driver_statuses (id_status, status_name, descrip_status, color_hex, is_active) FROM stdin;
1	disponible	Conductor listo para recibir un viaje	#4CAF50	t
2	en_viaje	Conductor operando actualmente en un viaje	#2196F3	t
3	descanso	Conductor en pausa temporal	#FFA500	t
4	incapacitado	Conductor con incapacidad médica	#FF5722	t
5	vacaciones	Conductor en período de vacaciones	#9C27B0	t
6	ausente	Conductor no se presentó	#F44336	t
\.


--
-- Data for Name: tab_drivers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_drivers (id_driver, name_driver, address_driver, phone_driver, email_driver, birth_date, gender_driver, license_cat, license_exp, id_eps, id_arl, blood_type, emergency_contact, emergency_phone, date_entry, id_status, is_active, created_at, user_create, updated_at, user_update) FROM stdin;
45452412	Diomedes Diaz	Calle 12 #29-25	3104032985	perezrico441@gmail.com	1967-05-26	M	C2	2027-08-05	11	7	A+	carlos rivera Perez	3104032985	2026-03-31	1	t	2026-03-31 00:51:15.481511-05	1	\N	\N
5454145443	Silvestre Dangond	SIN DIRECCIÓN	3104032985	silver441@gmail.com	2000-05-05	SA	C1	2027-08-05	7	4	A+	carlos rivera Perez	3104032986	2026-04-02	1	t	2026-04-02 01:03:18.567811-05	1	\N	\N
52545454	Vicente Fernandez	Calle 12 #29-25	3115472586	vicente441@gmail.com	2002-03-05	SA	C2	2027-08-05	4	3	O+	carlos rivera Perez	3104032985	2026-04-10	1	t	2026-04-10 01:24:12.405224-05	1	\N	\N
52545454233	Hafit David	Calle 12 #29-25	3104022365	hafit@gmail.com	2002-03-05	SA	C3	2027-08-05	6	9	O-	carlos rivera Perez	3104032986	2026-04-15	1	t	2026-04-14 20:55:31.139619-05	1	\N	\N
525454512	RAUL SANTI	SIN DIRECCIÓN	3104022364	raul@gmail.com	2002-03-05	SA	C1	2027-08-05	5	3	B+	carlos rivera Perez	0900000000	2026-04-15	1	t	2026-04-15 00:13:55.000095-05	1	\N	\N
525454523	SILVIO BRITO	Calle 12 #29-25	3104022364	silvio@gmail.com	2002-03-05	SA	C2	2027-08-05	4	5	A+	carlos rivera Perez	3104032986	2026-04-15	1	t	2026-04-15 00:15:15.98129-05	1	\N	\N
14545454	PETER MANJARREZ	SIN DIRECCIÓN	3104022364	peter@gmail.com	2002-03-05	SA	C1	2027-08-05	2	3	B+	carlos rivera Perez	3104032986	2026-04-15	1	t	2026-04-15 00:17:24.924848-05	1	\N	\N
1454512323	RAFAEL OROZCO	SIN DIRECCIÓN	3104022364	rafa@gmail.com	2002-03-05	SA	C1	2027-08-05	3	6	B-	carlos rivera Perez	0900000000	2026-04-15	1	t	2026-04-15 00:41:45.914682-05	1	\N	\N
145232332	RICARDO JORGE	Calle 12 #29-25	3104022364	ricardo@gmail.com	2002-03-05	SA	C1	2027-08-05	4	5	A+	carlos rivera Perez	3104032986	2026-04-15	1	t	2026-04-15 00:42:26.710929-05	1	\N	\N
125454451	ELDER DAYAN	Calle 12 #29-25	3104022365	elder@hotmail.com	2000-08-05	SA	C1	2027-08-05	4	9	O+	carlos rivera Perez	3144427003	2026-04-15	1	t	2026-04-15 00:43:34.978523-05	1	\N	\N
123525454	LAMIN YAMAL	Calle 12 #29-25	3104022365	lamin@yahoo.com	2000-08-05	SA	C1	2027-08-05	4	5	O-	carlos rivera Perez	3144427003	2026-04-15	1	t	2026-04-15 00:44:51.142171-05	1	\N	\N
55414123	ANDRES LOPEZ DIAZ	Calle 12 #29-25	3104032985	carlos12@gmail.com	1960-12-02	SA	C2	2027-03-05	9	5	A+	carlos rivera Perez	3104032985	2026-04-29	1	t	2026-04-28 20:31:40.24211-05	1	2026-04-28 20:32:04.433796-05	1
55414523	carlos REINEL Castro	Calle 12 #29-25	3104032985	carlos12@gmail.com	1960-12-02	SA	C3	2027-03-05	4	3	O-	carlos rivera Perez	3144427003	2026-04-29	1	t	2026-04-28 19:59:50.869162-05	1	2026-05-01 21:48:36.466348-05	1
454524124	Alejandro Sanz	Calle 12 #29-25	3104032985	alejozrico441@gmail.com	2007-05-08	O	C1	2027-08-05	4	9	O-	carlos rivera Perez	3104032985	2026-03-31	1	t	2026-03-31 00:59:47.485094-05	1	2026-05-08 02:43:33.470015-05	1
\.


--
-- Data for Name: tab_eps; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_eps (id_eps, name_eps, created_at, is_active) FROM stdin;
2	Nueva EPS	2026-03-30 11:38:14.649135-05	t
3	Sanitas	2026-03-30 11:38:14.649135-05	t
4	Compensar EPS	2026-03-30 11:38:14.649135-05	t
5	Famisanar	2026-03-30 11:38:14.649135-05	t
6	Salud Total	2026-03-30 11:38:14.649135-05	t
7	Coomeva EPS	2026-03-30 11:38:14.649135-05	t
8	Coosalud	2026-03-30 11:38:14.649135-05	t
9	Mutual Ser	2026-03-30 11:38:14.649135-05	t
10	Cajacopi EPS	2026-03-30 11:38:14.649135-05	t
11	Eps_Rapida	2026-03-30 11:53:48.922933-05	t
1	Sura EPS	2026-03-30 11:38:14.649135-05	t
\.


--
-- Data for Name: tab_gps_history_2026_03; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_gps_history_2026_03 (id_position, id_bus, id_trip, location_shot, speed, recorded_at, received_at) FROM stdin;
\.


--
-- Data for Name: tab_gps_history_2026_04; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_gps_history_2026_04 (id_position, id_bus, id_trip, location_shot, speed, recorded_at, received_at) FROM stdin;
\.


--
-- Data for Name: tab_gps_history_2026_05; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_gps_history_2026_05 (id_position, id_bus, id_trip, location_shot, speed, recorded_at, received_at) FROM stdin;
\.


--
-- Data for Name: tab_incident_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_incident_types (id_incident, name_incident, tag_incident, is_active) FROM stdin;
1	Via Cerrada	via_cerrada	t
2	Protesta	protesta	t
\.


--
-- Data for Name: tab_insurance_types; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_insurance_types (id_insurance_type, name_insurance, tag_insurance, descrip_insurance, is_mandatory, is_active) FROM stdin;
1	Seguro Obligatorio de Tránsito (SOAT)	SOAT	Seguro obligatorio requerido por el Estado	t	t
2	Resp. Civil Contractual (RCC)	RCC	Póliza de responsabilidad civil contractual	t	t
3	Resp. Civil Extracontractual (RCE)	RCE	Póliza de responsabilidad civil extracontractual	t	t
4	SEGURO TODO RIESGOs	STR	\N	f	t
\.


--
-- Data for Name: tab_insurers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_insurers (id_insurer, insurer_name, created_at, is_active) FROM stdin;
1	Sura	2026-03-30 11:38:14.649135-05	t
2	Allianz	2026-03-30 11:38:14.649135-05	t
3	AXA Colpatria	2026-03-30 11:38:14.649135-05	t
4	Bolívar Seguros	2026-03-30 11:38:14.649135-05	t
5	Liberty Seguros	2026-03-30 11:38:14.649135-05	t
6	Seguros del Estado	2026-03-30 11:38:14.649135-05	t
7	La Previsora	2026-03-30 11:38:14.649135-05	t
8	Mapfre	2026-03-30 11:38:14.649135-05	t
9	HDI Seguros	2026-03-30 11:38:14.649135-05	t
10	Equidad Seguros	2026-03-30 11:38:14.649135-05	t
\.


--
-- Data for Name: tab_parameters; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_parameters (param_key, param_value, data_type, descrip_param, is_active, updated_at, user_update) FROM stdin;
MAX_WORK_HOUR	22:00:00	time	Hora máxima hasta la cual un conductor puede operar en la noche	t	2026-03-30 11:38:14.649135-05	1
MIN_REST_HOURS	8	integer	Horas mínimas de descanso requeridas entre turnos para conductores	t	2026-03-30 11:38:14.649135-05	1
GPS_TOLERANCE_METERS	50	integer	Metros de tolerancia para considerar que un bus llegó a una parada	t	2026-03-30 11:38:14.649135-05	1
\.


--
-- Data for Name: tab_password_reset_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_password_reset_tokens (id_token, id_user, token, expires_at, created_at) FROM stdin;
1	2	5f3e0fcd5f3ed250e817dcbdef69f6be47bca05065a72cdf9c262a5d0a5de447be3b28c627a9777eaf3f0d8ac5c9b140	2026-05-06 02:40:46.935-05	2026-05-06 01:40:46.938335-05
6	4	cd398a9270203fec6052ef62d598a9b1a80f7d0a05f5b4a47891d7a7606d69d0ca5635982e516fe99b0a4e2d971f112e	2026-05-06 19:58:23.517-05	2026-05-06 18:58:23.518479-05
\.


--
-- Data for Name: tab_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_permissions (id_permission, name_permission, code_permission, id_parent, descrip_permission, is_active, created_at) FROM stdin;
1	Módulo Buses	MODULE_BUSES	\N	Acceso al módulo de buses	t	2026-05-02 01:52:15.94207-05
2	Módulo Conductores	MODULE_DRIVERS	\N	Acceso al módulo de conductores	t	2026-05-02 01:52:15.94207-05
3	Módulo Rutas	MODULE_ROUTES	\N	Acceso al módulo de rutas	t	2026-05-02 01:52:15.94207-05
4	Módulo Turnos	MODULE_TRIPS	\N	Acceso al panel de turnos	t	2026-05-02 01:52:15.94207-05
5	Módulo Configuración	MODULE_SETTINGS	\N	Acceso a ajustes del sistema	t	2026-05-02 01:52:15.94207-05
6	Crear Buses	CREATE_BUSES	1	Añadir nuevos buses	t	2026-05-02 01:52:15.94207-05
7	Editar Buses	EDIT_BUSES	1	Modificar datos de buses	t	2026-05-02 01:52:15.94207-05
8	Eliminar Buses	DELETE_BUSES	1	Eliminar buses	t	2026-05-02 01:52:15.94207-05
9	Crear Conductores	CREATE_DRIVERS	2	Añadir conductores	t	2026-05-02 01:52:15.94207-05
10	Editar Conductores	EDIT_DRIVERS	2	Modificar conductores	t	2026-05-02 01:52:15.94207-05
11	Eliminar Conductores	DELETE_DRIVERS	2	Eliminar conductores	t	2026-05-02 01:52:15.94207-05
12	Crear Turnos	CREATE_TRIPS	4	Crear viajes individuales o masivos	t	2026-05-02 01:52:15.94207-05
13	Asignar Turnos	ASSIGN_TRIPS	4	Asignar bus/conductor a viajes	t	2026-05-02 01:52:15.94207-05
14	Cancelar Turnos	CANCEL_TRIPS	4	Cancelar viajes	t	2026-05-02 01:52:15.94207-05
15	Gestionar Usuarios	MANAGE_USERS	5	Crear usuarios y asignar roles	t	2026-05-02 01:52:15.94207-05
73	Módulo Paradas	MODULE_STOPS	\N	Acceso al módulo de paradas	t	2026-05-02 04:30:37.45459-05
21	Ver Buses	VIEW_BUSES	1	Ver lista de buses	t	2026-05-02 02:25:16.485772-05
75	Módulo Catálogos	MODULE_CATALOGS	\N	Acceso a catálogos del sistema	t	2026-05-02 04:30:37.45459-05
25	Ver Conductores	VIEW_DRIVERS	2	Ver lista de conductores	t	2026-05-02 02:25:16.485772-05
29	Ver Turnos	VIEW_TRIPS	4	Ver lista de viajes	t	2026-05-02 02:25:16.485772-05
85	Ver Rutas	VIEW_ROUTES	3	Ver listado de rutas	t	2026-05-02 04:30:37.45459-05
86	Crear Rutas	CREATE_ROUTES	3	Crear nuevas rutas	t	2026-05-02 04:30:37.45459-05
87	Editar Rutas	EDIT_ROUTES	3	Modificar rutas	t	2026-05-02 04:30:37.45459-05
88	Eliminar Rutas	DELETE_ROUTES	3	Eliminar rutas	t	2026-05-02 04:30:37.45459-05
89	Ver Paradas	VIEW_STOPS	73	Ver listado de paradas	t	2026-05-02 04:30:37.45459-05
90	Crear Paradas	CREATE_STOPS	73	Crear nuevas paradas	t	2026-05-02 04:30:37.45459-05
91	Editar Paradas	EDIT_STOPS	73	Editar y activar/desactivar	t	2026-05-02 04:30:37.45459-05
96	Crear Catálogos	CREATE_CATALOGS	75	Crear registros en catálogos	t	2026-05-02 04:30:37.45459-05
97	Editar Catálogos	EDIT_CATALOGS	75	Editar registros de catálogos	t	2026-05-02 04:30:37.45459-05
98	Activar Catálogos	TOGGLE_CATALOGS	75	Activar/desactivar registros	t	2026-05-02 04:30:37.45459-05
100	Crear Usuarios	CREATE_USERS	5	Crear nuevos usuarios	t	2026-05-02 04:30:37.45459-05
101	Editar Usuarios	EDIT_USERS	5	Editar datos de usuario	t	2026-05-02 04:30:37.45459-05
\.


--
-- Data for Name: tab_role_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_role_permissions (id_role, id_permission, assigned_at, assigned_by) FROM stdin;
2	6	2026-05-06 01:45:07.636246-05	1
2	7	2026-05-06 01:45:07.636246-05	1
2	12	2026-05-06 01:45:07.636246-05	1
2	13	2026-05-06 01:45:07.636246-05	1
2	14	2026-05-06 01:45:07.636246-05	1
2	29	2026-05-06 01:45:07.636246-05	1
2	85	2026-05-06 01:45:07.636246-05	1
2	86	2026-05-06 01:45:07.636246-05	1
1	21	2026-05-02 04:30:37.45459-05	1
1	6	2026-05-02 04:30:37.45459-05	1
1	7	2026-05-02 04:30:37.45459-05	1
1	8	2026-05-02 04:30:37.45459-05	1
1	25	2026-05-02 04:30:37.45459-05	1
1	9	2026-05-02 04:30:37.45459-05	1
1	10	2026-05-02 04:30:37.45459-05	1
1	11	2026-05-02 04:30:37.45459-05	1
1	85	2026-05-02 04:30:37.45459-05	1
1	86	2026-05-02 04:30:37.45459-05	1
1	87	2026-05-02 04:30:37.45459-05	1
1	88	2026-05-02 04:30:37.45459-05	1
1	89	2026-05-02 04:30:37.45459-05	1
1	90	2026-05-02 04:30:37.45459-05	1
1	91	2026-05-02 04:30:37.45459-05	1
1	29	2026-05-02 04:30:37.45459-05	1
1	12	2026-05-02 04:30:37.45459-05	1
1	13	2026-05-02 04:30:37.45459-05	1
1	14	2026-05-02 04:30:37.45459-05	1
1	96	2026-05-02 04:30:37.45459-05	1
1	97	2026-05-02 04:30:37.45459-05	1
1	98	2026-05-02 04:30:37.45459-05	1
1	15	2026-05-02 04:30:37.45459-05	1
1	100	2026-05-02 04:30:37.45459-05	1
1	101	2026-05-02 04:30:37.45459-05	1
\.


--
-- Data for Name: tab_roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_roles (id_role, role_name, descrip_role, is_active) FROM stdin;
1	Administrador	Administrador del sistema	t
2	Turnador	Turnador del sistema	t
3	Conductor	Conductor de buses del sistema	t
\.


--
-- Data for Name: tab_route_points; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_route_points (id_point, point_type, name_point, location_point, descrip_point, is_checkpoint, is_active, created_at, updated_at, user_create, user_update) FROM stdin;
1	1	cr27 con 36	0101000020E610000027CE8620314752C057DED6042D7F1C40	\N	f	t	2026-04-02 19:15:58.725631-05	\N	1	\N
2	1	el tony	0101000020E6100000B8F1C9E5354752C0B4C1176D6F801C40	\N	f	t	2026-04-02 19:18:23.265145-05	\N	1	\N
8	1	cr 22 # 17	0101000020E6100000491C12D8F04752C04063FA0C16861C40	\N	f	t	2026-04-02 19:25:53.776395-05	\N	1	\N
9	1	crr 22 # 18	0101000020E6100000045008E7ED4752C003E64BBB3B851C40	\N	f	t	2026-04-02 19:26:35.023255-05	\N	1	\N
10	1	cr 22 # 19	0101000020E61000000119BAEBEB4752C02DD423A362841C40	\N	f	t	2026-04-02 19:27:20.030672-05	\N	1	\N
7	1	cra 22#16	0101000020E610000040711FEBF34752C084FECC2814871C40	\N	f	f	2026-04-02 19:25:29.850374-05	2026-04-04 04:41:20.558452-05	1	1
6	1	crr 22 # 7	0101000020E6100000054D864A0A4852C06A3657A4548E1C40	\N	f	f	2026-04-02 19:23:37.776467-05	2026-04-04 04:41:26.766572-05	1	1
5	1	cr 22 con 15	0101000020E6100000066B1A65F74752C05B0A897F2E881C40	\N	f	t	2026-04-02 19:21:12.709589-05	2026-04-04 05:09:31.938554-05	1	1
3	1	calle 14#22	0101000020E610000027CE8651FF4752C08D33D9A3B28A1C40	\N	f	f	2026-04-02 19:20:02.995165-05	2026-04-04 05:22:58.297313-05	1	1
4	1	calle 14#22	0101000020E6100000C8F45AFEE54752C0E587C5D4C98B1C40	\N	f	f	2026-04-02 19:20:27.960159-05	2026-04-04 05:30:12.390676-05	1	1
11	1	parque Antonia Santos	0101000020E6100000AE40D3B1CA4752C00E5757F5B37D1C40	\N	f	t	2026-04-02 19:28:45.232068-05	2026-04-04 06:43:34.178184-05	1	1
13	1	crr 22 #35	0101000020E6100000066DB2C4BC4752C00B324F3F547B1C40	\N	f	t	2026-04-04 06:46:14.924696-05	\N	1	\N
14	1	cr 22 #36	0101000020E61000004B46AE2AB54752C00AE360392A7A1C40	\N	f	t	2026-04-04 06:47:33.17143-05	\N	1	\N
15	1	parque Simon Bolivar	0101000020E610000089988F3EB04752C056C166D582791C40	\N	f	t	2026-04-04 06:48:29.768404-05	\N	1	\N
54	1	cr22#50a	0101000020E6100000A0C95009804752C035B8DBAAD2731C40	\N	f	t	2026-04-17 12:43:22.559969-05	2026-04-17 12:43:51.308471-05	1	1
16	1	crr 22 # 39	0101000020E6100000C80E49FEA84752C03E8F4B1A8B781C40	\N	f	t	2026-04-04 06:50:32.328934-05	2026-04-04 06:51:51.461623-05	1	1
17	1	centro cr 15	0101000020E6100000C199BA39254852C037E40017227B1C40	\N	f	t	2026-04-04 06:56:52.464377-05	\N	1	\N
18	2	parada Cr33	0101000020E61000007C62F681274752C020636E66DE7B1C40	\N	f	t	2026-04-14 19:32:08.966701-05	2026-04-14 19:34:04.486687-05	1	1
20	1	cr 21 #21	0101000020E6100000DD12316FF34752C04E5284FF88821C40	\N	f	t	2026-04-17 12:26:39.474526-05	\N	1	\N
21	1	cr 21#22	0101000020E610000052B7BA7BEF4752C0B4C89FC591811C40	\N	f	t	2026-04-17 12:29:32.691014-05	\N	1	\N
23	1	cr21#28	0101000020E61000002277029DE74752C0EFA1BE53E17F1C40	\N	f	t	2026-04-17 12:30:41.195625-05	\N	1	\N
22	1	cr 21#24	0101000020E61000000F2F81C9EB4752C0A0F53DC1D0801C40	\N	f	t	2026-04-17 12:30:01.220861-05	2026-04-17 12:31:00.653136-05	1	1
24	1	cr 21#30	0101000020E61000006F8B0576E14752C07B302FB6A67E1C40	\N	f	t	2026-04-17 12:31:22.454921-05	\N	1	\N
25	1	cr21#31	0101000020E6100000E57D431CDD4752C03B7A9841DA7D1C40	\N	f	t	2026-04-17 12:31:41.987661-05	\N	1	\N
26	1	cr21#32	0101000020E61000006D8D6EEFD84752C0A15156CE377D1C40	\N	f	t	2026-04-17 12:32:06.575076-05	\N	1	\N
27	1	cr21 #33	0101000020E6100000BE9F4871D34752C033612731627C1C40	\N	f	t	2026-04-17 12:32:19.943987-05	\N	1	\N
28	1	cr21#34	0101000020E6100000DF028AF5CE4752C036C70579B07B1C40	\N	f	t	2026-04-17 12:32:40.34585-05	\N	1	\N
29	1	cr21#35	0101000020E6100000CFF91DE6C84752C0255F7786E17A1C40	\N	f	t	2026-04-17 12:33:00.244889-05	\N	1	\N
30	1	cr 21#36	0101000020E61000005CD87902C34752C02BCCC97D0D7A1C40	\N	f	t	2026-04-17 12:33:25.206642-05	\N	1	\N
31	1	cr21#37	0101000020E61000008162B9A5BD4752C0752344EF33791C40	\N	f	t	2026-04-17 12:33:38.141985-05	\N	1	\N
32	1	cr 21#39	0101000020E6100000B888F140B14752C0D997641A13781C40	\N	f	t	2026-04-17 12:34:05.920638-05	\N	1	\N
33	1	cr21#45	0101000020E61000000B1C0415A94752C0D6C779F6D1761C40	\N	f	t	2026-04-17 12:34:31.359789-05	\N	1	\N
34	1	cr21#40	0101000020E61000006EB695A9A24752C0FA681404D5751C40	\N	f	t	2026-04-17 12:36:00.755149-05	\N	1	\N
35	1	cr21#47	0101000020E61000008CF4C5BD9D4752C0E51D012D2E751C40	\N	f	t	2026-04-17 12:36:50.456627-05	\N	1	\N
36	1	cr21#48	0101000020E6100000CF3B81D4994752C08E78197A97741C40	\N	f	t	2026-04-17 12:37:05.877757-05	\N	1	\N
37	1	cr21#49	0101000020E61000006F0CFA74974752C03AE848D235741C40	\N	f	t	2026-04-17 12:37:21.25521-05	\N	1	\N
38	1	cr21#50	0101000020E61000006097FFF0934752C010B32AFEC1731C40	\N	f	t	2026-04-17 12:37:35.387994-05	\N	1	\N
39	1	cr21#50a	0101000020E61000006D8D2EA5904752C02E322B4657731C40	\N	f	t	2026-04-17 12:38:31.170628-05	\N	1	\N
40	1	cr21#51	0101000020E61000006197FF158D4752C0A9E998F3D8721C40	\N	f	t	2026-04-17 12:38:47.81428-05	\N	1	\N
41	1	cr21#51a	0101000020E6100000944282F4884752C0B56170E86E721C40	\N	f	t	2026-04-17 12:39:04.548354-05	\N	1	\N
42	1	cr21#52	0101000020E61000007CFED256844752C067E5CB41E6711C40	\N	f	t	2026-04-17 12:39:13.516384-05	\N	1	\N
43	1	cr21#53	0101000020E6100000CE6691817F4752C0ABBD8DCF55711C40	\N	f	t	2026-04-17 12:39:28.125455-05	\N	1	\N
44	1	cr21#54	0101000020E61000006F8B45AC7A4752C038843FE49E701C40	\N	f	t	2026-04-17 12:39:40.758495-05	\N	1	\N
46	1	cr21#56	0101000020E6100000901BC490704752C00A4C8440216F1C40	\N	f	t	2026-04-17 12:40:11.408299-05	\N	1	\N
45	1	cr21#55	0101000020E610000032BD5617754752C08204BB83BB6F1C40	\N	f	t	2026-04-17 12:39:51.832598-05	2026-04-17 12:40:23.941533-05	1	1
47	1	cr22#56	0101000020E610000027049051654752C07244A3B4266F1C40	\N	f	t	2026-04-17 12:41:19.891764-05	\N	1	\N
48	1	cr22#55	0101000020E6100000FC52CEBE684752C03966363ADC6F1C40	\N	f	t	2026-04-17 12:41:31.15662-05	\N	1	\N
49	1	cr22#54	0101000020E61000000CEFC6AA6D4752C05F5B6AD5D8701C40	\N	f	t	2026-04-17 12:41:46.229564-05	\N	1	\N
50	1	cr22#53	0101000020E6100000B9B345DA724752C095B87581B2711C40	\N	f	t	2026-04-17 12:42:11.859146-05	\N	1	\N
51	1	cr22#52	0101000020E6100000A9174D8B764752C0B5BFDA6346721C40	\N	f	t	2026-04-17 12:42:23.182826-05	\N	1	\N
52	1	cr22#51a	0101000020E6100000E8374AC37A4752C06A3EEAEDD1721C40	\N	f	t	2026-04-17 12:42:42.342277-05	\N	1	\N
53	1	cr22#51	0101000020E61000000E6E52397D4752C0CA958B3475731C40	\N	f	t	2026-04-17 12:42:56.659912-05	\N	1	\N
55	1	cr22#50	0101000020E6100000D73399D2884752C0DBE1FF6524741C40	\N	f	t	2026-04-17 12:43:41.922437-05	\N	1	\N
56	1	cr22#49	0101000020E61000004B2800B98B4752C02C3D1CB78D741C40	\N	f	t	2026-04-17 12:44:09.584447-05	\N	1	\N
57	1	cr22#48	0101000020E61000004657A6918D4752C071D69DB1CE741C40	\N	f	t	2026-04-17 12:44:22.340283-05	\N	1	\N
58	1	cr22#47	0101000020E6100000C8C04772924752C02DE47E9287751C40	\N	f	t	2026-04-17 12:44:37.551116-05	\N	1	\N
59	1	cr22#46b	0101000020E6100000EE751B9F964752C09B9A76DC13761C40	\N	f	t	2026-04-17 12:44:56.883204-05	\N	1	\N
60	1	cr22#46a	0101000020E61000000191DFEA994752C080AAA8C882761C40	\N	f	t	2026-04-17 12:45:18.483381-05	\N	1	\N
61	1	cr22#45	0101000020E61000000F065A669E4752C0ACEDA65F25771C40	\N	f	t	2026-04-17 12:45:31.815454-05	\N	1	\N
62	1	cr22#34	0101000020E6100000E20E5FC1BF4752C004677909F57B1C40	\N	f	t	2026-04-17 12:46:11.64168-05	\N	1	\N
63	1	cr22#33	0101000020E6100000C201C2BBC54752C0B321236FFC7C1C40	\N	f	t	2026-04-17 12:46:27.294355-05	\N	1	\N
64	1	cr22#31	0101000020E6100000DDEB3615CE4752C05AA0564D607E1C40	\N	f	t	2026-04-17 12:46:41.815822-05	\N	1	\N
65	1	cr22#30	0101000020E6100000D6EF8890D24752C0AD5DBF6D187F1C40	\N	f	t	2026-04-17 12:47:01.382947-05	\N	1	\N
66	1	cr22#28	0101000020E6100000B8343A36DA4752C0B687B62B6A801C40	\N	f	t	2026-04-17 12:47:14.929085-05	\N	1	\N
67	1	cr22#24	0101000020E610000043C147F5DE4752C0255A22A631811C40	\N	f	t	2026-04-17 12:47:36.957461-05	\N	1	\N
68	1	cr22#22	0101000020E610000055DC4BD3E24752C06B8A0CCBF7811C40	\N	f	t	2026-04-17 12:47:46.1469-05	\N	1	\N
69	1	cr22#21	0101000020E610000069F74FD0E54752C0900802C5B2821C40	\N	f	t	2026-04-17 12:47:58.27612-05	\N	1	\N
70	1	cr22#20	0101000020E6100000D69B5173E84752C0E2C64B6C9A831C40	\N	f	t	2026-04-17 12:48:22.521761-05	\N	1	\N
71	1	cr22#17	0101000020E610000069CA926FF34752C0EDF5DC9DFB861C40	\N	f	t	2026-04-17 12:48:36.274592-05	\N	1	\N
72	1	cr22#14	0101000020E6100000C2014226F94752C0655FD35FC9881C40	\N	f	t	2026-04-17 12:48:48.937695-05	\N	1	\N
73	1	cr22#13	0101000020E6100000E9B655E8FA4752C05D03BB6B76891C40	\N	f	t	2026-04-17 12:49:02.389799-05	\N	1	\N
74	1	cr22#12	0101000020E61000003A73CBDCFE4752C0A21B487E588A1C40	\N	f	t	2026-04-17 12:49:23.137505-05	\N	1	\N
19	1	cr21#20	0101000020E610000046BFDE4DF74752C03CE4471F5A831C40	\N	f	t	2026-04-17 01:21:40.57641-05	2026-04-17 12:51:46.597516-05	1	1
12	1	cr 22 con 45	0101000020E610000082A8FB00A44752C0F81BEDB8E1771C40	\N	f	t	2026-04-02 19:55:46.970791-05	2026-04-21 17:39:30.689725-05	1	1
78	1	cr22#8	0101000020E6100000987B54BD074852C0CE2C2986928D1C40	\N	f	f	2026-04-17 12:50:00.146441-05	2026-04-24 03:29:41.19904-05	1	1
77	1	cr22#9	0101000020E6100000FB52CEB7054852C0944132C4DB8C1C40	\N	f	f	2026-04-17 12:49:51.224163-05	2026-04-24 03:29:46.804585-05	1	1
76	1	cr22#10	0101000020E61000004D8ECF60024852C0FEC34CE2DA8B1C40	\N	f	f	2026-04-17 12:49:42.380385-05	2026-04-24 03:29:51.590926-05	1	1
75	1	cr22#11	0101000020E61000002189D671004852C09FEE9D5F2F8B1C40	\N	f	f	2026-04-17 12:49:33.245978-05	2026-04-24 03:29:58.456396-05	1	1
81	1	cra22#5	0101000020E6100000977B544C0F4852C0E1D7D16C06901C40	\N	f	t	2026-04-17 12:50:52.786388-05	\N	1	\N
82	1	cr22#19	0101000020E6100000D69B5107FA4752C0E6FAF67840841C40	\N	f	t	2026-04-17 12:52:17.450146-05	\N	1	\N
83	1	cr21#18	0101000020E6100000AA96D82BFB4752C0CAB7FB6EFB841C40	\N	f	t	2026-04-17 12:52:34.718902-05	\N	1	\N
84	1	cr21#17	0101000020E6100000D79B518BFD4752C0C0AD740EA7851C40	\N	f	t	2026-04-17 12:53:04.55651-05	\N	1	\N
85	1	rotonda San Francisco	0101000020E6100000E6E5FB20F74752C0D3962C253F861C40	\N	f	t	2026-04-17 12:53:37.589365-05	\N	1	\N
86	1	rotonda san francisco con21	0101000020E610000074C4570F014852C07E0C5CBDDC861C40	\N	f	t	2026-04-17 12:54:08.132709-05	2026-04-17 12:54:20.908825-05	1	1
87	1	cr21#16	0101000020E61000003FC330F0014852C062AA3C931F871C40	\N	f	t	2026-04-17 12:54:43.515685-05	\N	1	\N
88	1	cr21#15	0101000020E61000007C12540C044852C0B6F07D7ABD871C40	\N	f	t	2026-04-17 12:54:53.089143-05	\N	1	\N
89	1	cr21#14	0101000020E61000000E6E5282064852C084F267C995881C40	\N	f	t	2026-04-17 12:55:02.392134-05	\N	1	\N
90	1	cr21#13	0101000020E61000009FC95052094852C0B909D3766F891C40	\N	f	t	2026-04-17 12:55:15.907001-05	\N	1	\N
91	1	cr21#12	0101000020E61000008560D0380C4852C05B2167DD1D8A1C40	\N	f	t	2026-04-17 12:55:32.425768-05	\N	1	\N
92	1	cr21#11	0101000020E6100000575BD7A00D4852C09DB7E573D78A1C40	\N	f	t	2026-04-17 12:55:42.832011-05	\N	1	\N
93	1	cr21#10	0101000020E6100000D69BD143104852C0207A3EBAB68B1C40	\N	f	t	2026-04-17 12:55:56.966302-05	\N	1	\N
94	1	cr21#9a	0101000020E6100000220862C2114852C02971FBF23D8C1C40	\N	f	t	2026-04-17 12:56:18.777081-05	2026-04-17 12:56:27.115095-05	1	1
95	1	cr21#9	0101000020E61000003CF25657134852C03004D637BA8C1C40	\N	f	t	2026-04-17 12:57:20.488414-05	\N	1	\N
96	1	cr21#8	0101000020E610000029D7D2B6154852C07847FB03788D1C40	\N	f	t	2026-04-17 12:57:35.999754-05	\N	1	\N
97	1	cr21#7	0101000020E61000004440D3FF174852C057B107B94A8E1C40	\N	f	t	2026-04-17 12:57:45.503815-05	\N	1	\N
98	1	cr21#7	0101000020E6100000856050E61A4852C0C29EB770168F1C40	\N	f	t	2026-04-17 12:57:55.115527-05	\N	1	\N
99	1	cr21#5	0101000020E610000029D7D2451D4852C05B2C99BEE78F1C40	\N	f	t	2026-04-17 12:58:11.809373-05	\N	1	\N
100	1	Carrera 20 ## 14-26, Comuna 3 San Francisco	0101000020E6100000378E3067154852C03E142E9F7F881C40	\N	f	t	2026-04-17 15:09:42.317902-05	2026-04-17 15:20:20.923833-05	1	1
101	1	Carrera 15 #30-45, Centro	0101000020E610000030CD3DF82D4852C0E34C8B158E7C1C40	\N	f	t	2026-04-17 15:27:55.556107-05	\N	1	\N
102	1	Calle 6 #16-20, Comuna 3 San Francisco	0101000020E61000007C884A105B4852C079789111BF8E1C40	\N	f	t	2026-04-17 16:09:24.849847-05	\N	1	\N
103	1	Calle 11 ## 26-34, Comuna 3 San Francisco	0101000020E61000004630ACF9C34752C0B24D4D40398C1C40	\N	f	t	2026-04-17 16:25:29.1164-05	\N	1	\N
104	1	Calle 11 ## 26A-5, Comuna 3 San Francisco	0101000020E610000000BE9C2CBA4752C045873F45578C1C40	\N	f	t	2026-04-17 16:25:43.20332-05	\N	1	\N
105	1	Calle 11 ## 27-39, Comuna 3 San Francisco	0101000020E610000044DCB01CAC4752C006C82FEA658C1C40	\N	f	t	2026-04-17 16:25:51.728112-05	\N	1	\N
106	1	Calle 11 ## 28-19, Comuna 3 San Francisco	0101000020E6100000A10DE16EA14752C00D8D106B628C1C40	\N	f	t	2026-04-17 16:55:33.042641-05	\N	1	\N
107	1	Calle 11 ## 29-29, Comuna 3 San Francisco	0101000020E6100000B6A7306A934752C0BF871806618C1C40	\N	f	t	2026-04-17 16:55:42.472859-05	\N	1	\N
108	1	Calle 11 ## 25-44, Comuna 3 San Francisco	0101000020E610000001646211D14752C0B713A582118C1C40	\N	f	t	2026-04-17 16:55:53.16096-05	\N	1	\N
109	1	Calle 11 #2452, Comuna 3 San Francisco	0101000020E6100000DB0473E6DD4752C0EDD423B4E98B1C40	\N	f	t	2026-04-17 16:56:03.653074-05	\N	1	\N
110	1	Carrera 26 #1105, Comuna 3 San Francisco	0101000020E6100000E0BC1064CA4752C0A82F4C42268C1C40	\N	f	t	2026-04-17 16:59:29.814334-05	\N	1	\N
111	1	Calle 11 ## 24-11, Comuna 3 San Francisco	0101000020E61000004765647EE44752C0F252310FDF8B1C40	\N	f	t	2026-04-17 17:01:05.872153-05	\N	1	\N
112	1	Calle 11 ## 25-12, nueva	0101000020E61000007CAA5B00D74752C00DB49A84FC8B1C40	\N	f	t	2026-04-17 18:57:03.169114-05	\N	1	\N
113	1	Calle 11 ## 26-70, nueva2	0101000020E61000002A48E0BEBE4752C0082DCC8B468C1C40	\N	f	t	2026-04-17 18:58:00.909853-05	\N	1	\N
114	1	Carrera 23 ## 10-35, Comuna 3 San Francisco	0101000020E6100000E4FD1D48F54752C02A3A12BE0F8C1C40	\N	f	t	2026-04-17 19:42:33.149248-05	\N	1	\N
115	1	Calle 9 #1950, prueba3	0101000020E610000088856177274852C09E1CC69AB48C1C40	\N	f	t	2026-04-17 19:46:35.508504-05	\N	1	\N
116	1	Carrera 24 #1504, prueba4	0101000020E61000003F93A153DC4752C0EA66AB9681881C40	\N	f	t	2026-04-17 19:58:54.918727-05	\N	1	\N
117	1	Carrera 24 ## 12-61, prueba5	0101000020E6100000FEEDD579E24752C0F70D6755548A1C40	\N	f	t	2026-04-17 20:02:02.754101-05	\N	1	\N
118	1	Carrera 24 #11-44, prueba6	0101000020E6100000E588AF1DE54752C0801D7831418B1C40	\N	f	t	2026-04-17 20:04:14.500809-05	\N	1	\N
119	1	Carrera 24 #10-05, prueba7	0101000020E610000089FFB139E74752C0C643779E6E8C1C40	\N	f	t	2026-04-17 20:05:26.568611-05	\N	1	\N
120	1	Carrera 24 #964, preuba8	0101000020E610000042DAC38BE94752C0AEAD8DBFD28C1C40	\N	f	t	2026-04-17 20:06:13.159762-05	\N	1	\N
121	1	Carrera 24 #1648, prueba8	0101000020E610000000466775D84752C08B8E45F34E871C40	\N	f	t	2026-04-17 20:08:11.676681-05	\N	1	\N
122	1	Carrera 24 ## 9-29, preuba9	0101000020E6100000B463E0F1E94752C052590B09198D1C40	\N	f	t	2026-04-17 20:09:26.974956-05	\N	1	\N
123	1	Carrera 24 ## 17-69, prueba10	0101000020E610000099FA5FC3D44752C04585C3522E861C40	\N	f	t	2026-04-17 20:10:17.777605-05	\N	1	\N
124	1	Carrera 24 ## 13-23, prueba11	0101000020E61000001DDABBBBDD4752C0A8F2BB379C891C40	\N	f	t	2026-04-17 20:35:18.124502-05	\N	1	\N
125	1	Carrera 24 ## 18-46, prueba12	0101000020E61000002DD569D4D24752C0CD122C118C851C40	\N	f	t	2026-04-17 20:36:14.053098-05	\N	1	\N
126	1	Carrera 24 #1948, prueba13	0101000020E61000004CFDEF0ED04752C0D0346C9DAC841C40	\N	f	t	2026-04-17 20:37:33.791062-05	\N	1	\N
127	1	Carrera 24 ## 20-16, prueba14	0101000020E6100000FE9208D1CD4752C0147C2CD20F841C40	\N	f	t	2026-04-17 20:39:22.3221-05	\N	1	\N
128	1	Carrera 24 ## 18-76, prueba15	0101000020E61000007D91DF09D24752C0B0159CA942851C40	\N	f	t	2026-04-17 20:40:13.159307-05	\N	1	\N
129	1	Carrera 24 ## 21-36, prueba16	0101000020E610000052A339A7CA4752C03376267314831C40	\N	f	t	2026-04-17 20:40:45.515347-05	\N	1	\N
130	1	Carrera 24 #20-56, prueba20	0101000020E6100000AE6732DACC4752C04D09CE7D9E831C40	\N	f	t	2026-04-17 20:52:59.2765-05	\N	1	\N
131	1	Carrera 24 ## 14-26, prueba21	0101000020E6100000DD43C8BADD4752C0ADD9CCBBF8881C40	\N	f	t	2026-04-17 20:54:31.634602-05	\N	1	\N
132	1	Carrera 24 ## 22-15, prueba22	0101000020E6100000E76487EEC74752C0B57369A84C821C40	\N	f	t	2026-04-17 20:55:31.193383-05	\N	1	\N
133	1	Carrera 24 #18-04, prueba 10.1	0101000020E610000046BFDECBD34752C0F877AEE2DB851C40	\N	f	t	2026-04-17 21:01:14.274453-05	\N	1	\N
134	1	Carrera 24 ## 24-14, prueba23	0101000020E61000005A72EAAFC54752C004EAFF9BC5811C40	\N	f	t	2026-04-17 21:04:22.651343-05	\N	1	\N
135	1	Carrera 24 ## 22-41, prueba24	0101000020E610000023A069D4C64752C0BA10A89F0F821C40	\N	f	t	2026-04-17 21:05:02.497026-05	\N	1	\N
136	1	Carrera 24 ## 24-35, prueba26	0101000020E6100000E0D73980C44752C0EC646F4A83811C40	\N	f	t	2026-04-17 21:05:49.964968-05	\N	1	\N
137	1	Carrera 24 #2165, prueba30	0101000020E6100000B17E45D1C94752C011AF34EDCE821C40	\N	f	t	2026-04-17 21:17:13.196882-05	\N	1	\N
138	1	Carrera 24 #28-27, prueba31	0101000020E61000007F7BF517C34752C05D5CEE4B27811C40	\N	f	t	2026-04-17 21:18:28.656082-05	\N	1	\N
139	1	Carrera 24 #1546, prueba31	0101000020E610000079E7FF16DB4752C0C746E1D11E881C40	\N	f	t	2026-04-17 21:20:08.404577-05	\N	1	\N
140	1	Carrera 24 ## 21-1, prueba32	0101000020E61000006A765B72CB4752C02A85CD7B50831C40	\N	f	t	2026-04-17 21:26:11.379745-05	\N	1	\N
141	1	Carrera 24 #12A-36, prueba40	0101000020E6100000D2452973E04752C01D904DE2F0891C40	\N	f	t	2026-04-17 21:29:29.637017-05	\N	1	\N
142	1	Carrera 24 ## 10-44, prueba41	0101000020E6100000D14BEC7BE74752C0FDE1DC9A0B8C1C40	\N	f	t	2026-04-17 21:30:36.752717-05	\N	1	\N
143	1	Carrera 24 ## 15-75, prueba42	0101000020E6100000C52653F2D94752C073EA9ADECE871C40	\N	f	t	2026-04-17 21:33:29.127517-05	\N	1	\N
145	1	Carrera 18 #6-50, Comuna 3 San Francisco	0101000020E610000020FF4C7F464852C0178E5AE7918E1C40	\N	f	t	2026-04-17 23:48:33.604273-05	\N	1	\N
146	1	Carrera 18 ## 7-30, Comuna 3 San Francisco	0101000020E61000008885E1F9424852C04A6E9C78C08D1C40	\N	f	t	2026-04-17 23:49:26.653765-05	\N	1	\N
147	1	Carrera 18 ## 4-37, Comuna 3 San Francisco	0101000020E6100000FBC16EAA4A4852C0E0788C2C4F901C40	\N	f	t	2026-04-18 00:17:04.498278-05	\N	1	\N
79	1	cr22#7	0101000020E6100000A0C9508D0A4852C069424222888E1C40	\N	f	f	2026-04-17 12:50:11.566242-05	2026-04-24 03:29:35.597626-05	1	1
144	1	Carrera 18 ## 5-46, Comuna 3 San Francisco	0101000020E610000058C51B99474852C0C367EBE0608F1C40	\N	f	t	2026-04-17 23:48:20.574114-05	2026-04-24 20:45:17.553106-05	1	1
148	1	Carrera 18 ## 6-19, prueba uno	0101000020E6100000CE121A7B454852C01B8E30C0C98E1C40	\N	f	t	2026-04-18 00:17:51.176031-05	\N	1	\N
149	1	Calle 5 ## 18-11, seria dos	0101000020E6100000EB4E9D4D494852C01DF322F505901C40	\N	f	t	2026-04-18 00:22:04.121601-05	\N	1	\N
150	1	Calle 18 ## 17-3, Comuna 4 Occidental	0101000020E6100000D969D9B0334852C09A11EAA7DB841C40	\N	f	t	2026-04-19 01:20:37.683624-05	\N	1	\N
151	1	Calle 18 ## 17-3, Comuna 4 Occidental	0101000020E6100000D969D9B0334852C09A11EAA7DB841C40	\N	f	t	2026-04-19 01:20:40.804593-05	\N	1	\N
152	1	Calle 115 ## 31-4, Sotomayor	0101000020E61000007B4FE5B4A74652C09D853DEDF0571C40	\N	f	t	2026-04-20 00:27:05.412693-05	\N	1	\N
153	1	Calle 115 ## 31-4, Sotomayor	0101000020E61000007B4FE5B4A74652C09D853DEDF0571C40	\N	f	t	2026-04-20 00:27:07.615011-05	\N	1	\N
154	1	Calle 68 #13-21, La Victoria	0101000020E6100000E6948098844752C05F42058717641C40	\N	f	t	2026-04-20 00:27:33.026847-05	\N	1	\N
155	1	Calle 68 #13-21, La Victoria	0101000020E6100000E6948098844752C05F42058717641C40	\N	f	t	2026-04-20 00:27:46.493621-05	\N	1	\N
156	1	Calle 68 #13-21, La Victoria	0101000020E6100000E6948098844752C05F42058717641C40	\N	f	t	2026-04-20 00:27:47.670095-05	\N	1	\N
157	1	Calle 68 #13-21, La Victoria	0101000020E6100000E6948098844752C05F42058717641C40	\N	f	t	2026-04-20 00:27:48.542372-05	\N	1	\N
158	1	Calle 68 #13-21, La Victoria	0101000020E6100000E6948098844752C05F42058717641C40	\N	f	t	2026-04-20 00:27:49.606472-05	\N	1	\N
159	1	Calle 68 #13-21, La Victoria	0101000020E6100000E6948098844752C05F42058717641C40	\N	f	t	2026-04-20 00:27:50.683996-05	\N	1	\N
160	1	Calle Boulevar Santander ## 16-63, Comuna 4 Occidental	0101000020E6100000CFBBB1A0304852C0465B9544F6811C40	\N	f	t	2026-04-20 00:28:05.819701-05	\N	1	\N
161	1	Calle 14 ## 20-64, Comuna 3 San Francisco	0101000020E6100000A114ADDC0B4852C04BADF71BED881C40	\N	f	t	2026-04-20 00:44:28.686296-05	\N	1	\N
162	1	Carrera 22 ## 15-51, Comuna 3 San Francisco	0101000020E6100000BEA59C2FF64752C048FE60E0B9871C40	\N	f	t	2026-04-20 00:45:26.883475-05	\N	1	\N
163	1	parada prueba3	0101000020E6100000F8B1B527194852C06CF6D652D8871C40	\N	f	t	2026-04-20 00:45:58.655356-05	2026-04-20 00:48:57.388335-05	1	1
164	1	Carrera 31 ## 116-75, Sotomayor	0101000020E61000000AD9791B9B4652C00AF7CABC55571C40	\N	f	t	2026-04-20 00:53:15.148971-05	\N	1	\N
165	1	Carrera 31 ## 116-75, Sotomayor	0101000020E6100000A6643909A54652C0CB11329067571C40	\N	f	t	2026-04-20 00:53:19.894301-05	\N	1	\N
166	1	Carrera 32 ## 116-63, Sotomayor	0101000020E61000002C103D29934652C0F833BC5983571C40	\N	f	t	2026-04-20 00:53:27.382562-05	\N	1	\N
167	1	Carrera 31 ## 114-27, Sotomayor	0101000020E61000001B13622EA94652C02409C21550581C40	\N	f	t	2026-04-20 00:53:39.358047-05	\N	1	\N
168	1	Calle 117 #33-2, Sotomayor	0101000020E61000007C2C7DE8824652C0AC527AA697581C40	\N	f	t	2026-04-20 00:55:30.949522-05	\N	1	\N
169	1	Carrera 33 ## 118-9, Sotomayor	0101000020E610000022C495B3774652C05130630AD6581C40	\N	f	t	2026-04-20 00:56:08.825663-05	\N	1	\N
170	1	Carrera 33 ## 74-40, Sotomayor	0101000020E6100000E3C62DE6E74652C0E014562AA8681C40	\N	f	t	2026-04-20 01:00:02.911516-05	\N	1	\N
171	1	Carrera 33 ## 73-35, Comuna 16 Lagos del cacique	0101000020E610000089618731E94652C066F9BA0CFF691C40	\N	f	t	2026-04-20 01:00:45.518136-05	\N	1	\N
172	1	Carrera 33 #7554, Sotomayor	0101000020E61000001EF98381E74652C01938A0A52B681C40	\N	f	t	2026-04-20 01:01:24.102239-05	\N	1	\N
173	1	Carrera 33 ## 74-20, Sotomayor	0101000020E6100000DCBB067DE94652C0ABAE433525691C40	\N	f	t	2026-04-20 01:01:55.309504-05	\N	1	\N
174	1	Carrera 33 #7556, Sotomayor	0101000020E610000011FDDAFAE94652C0AEF199EC9F671C40	\N	f	t	2026-04-20 01:02:39.409339-05	\N	1	\N
175	1	Transversal 93 ## 34-108, Sotomayor	0101000020E61000000F61FC34EE4652C0E257ACE122671C40	\N	f	t	2026-04-20 01:04:24.778507-05	\N	1	\N
176	1	Carrera 21 ## 24-54, Comuna 4 Occidental	0101000020E6100000B3EF9C09EC4752C056217DB3B5801C40	\N	f	t	2026-04-20 20:51:07.844186-05	\N	1	\N
177	1	Carrera 21 ## 22-6, Comuna 4 Occidental	0101000020E610000077040F73F24752C0B729512603821C40	\N	f	t	2026-04-20 20:51:07.914706-05	\N	1	\N
178	1	Carrera 21 ## 20-30, Comuna 4 Occidental	0101000020E61000005DE26E1BF74752C08C45B4CA62831C40	\N	f	t	2026-04-20 20:51:07.930433-05	\N	1	\N
179	1	Carrera 18 ## 10-11, Comuna 3 San Francisco	0101000020E610000059C2DA183B4852C058E542E55F8B1C40	\N	f	t	2026-04-20 21:07:57.990345-05	\N	1	\N
181	1	Calle 7 ## 17-44, Comuna 3 San Francisco	0101000020E610000063F19BC24A4852C026AC8DB1138E1C40	\N	f	t	2026-04-20 21:07:58.031567-05	\N	1	\N
182	1	Calle 6 #18-56, Comuna 3 San Francisco	0101000020E61000009E060C923E4852C00D535BEA208F1C40	\N	f	t	2026-04-20 21:07:58.046527-05	\N	1	\N
183	1	Calle 7 #19-32, Comuna 3 San Francisco	0101000020E6100000BE6A65C22F4852C036AE7FD7678E1C40	\N	f	t	2026-04-20 21:07:58.060374-05	\N	1	\N
184	1	Calle 7 ## 20-43, Comuna 3 San Francisco	0101000020E61000005AD6FD63214852C019710168948E1C40	\N	f	t	2026-04-20 21:07:58.073897-05	\N	1	\N
185	1	Calle 8 ## 20-57, Comuna 3 San Francisco	0101000020E6100000B6D782DE1B4852C0B439CE6DC28D1C40	\N	f	t	2026-04-20 21:07:58.089568-05	\N	1	\N
186	1	Carrera 15 ##28-75 a 28-3, Centro	0101000020E61000008352B4722F4852C0679AB0FD647C1C40	\N	f	t	2026-04-21 17:32:38.630661-05	\N	1	\N
187	1	Diagonal 15 ##55-78, Comuna 6 La Concordia	0101000020E61000002497FF907E4752C0DAE731CA336F1C40	\N	f	t	2026-04-21 17:32:38.687517-05	\N	1	\N
188	1	Diagonal 15 #60-56, Comuna 6 La Concordia	0101000020E6100000323CF6B3584752C00A2B1554546D1C40	\N	f	t	2026-04-21 17:32:38.69611-05	\N	1	\N
189	1	Carrera 15 #3638, García Rovira	0101000020E61000001FBB0B94144852C0FDA36FD234781C40	\N	f	t	2026-04-21 17:32:38.706066-05	\N	1	\N
191	1	Diagonal 15 #47-10, Comuna 6 La Concordia	0101000020E6100000F4E0EEACDD4752C0F452B131AF731C40	\N	f	t	2026-04-21 17:32:38.726207-05	\N	1	\N
192	1	Diagonal 15 #52-53	0101000020E6100000925A28999C4752C07077D66EBB701C40	\N	f	t	2026-04-21 17:32:38.735446-05	\N	1	\N
193	1	Calle 1nb ## 6-96, PASEO CATALUÑA	0101000020E6100000C2A1B778784352C0C85C19541BFC1B40	\N	f	t	2026-04-22 03:41:18.847259-05	\N	1	\N
194	1	Calle 1B ## 6-131, PASEO CATALUÑA	0101000020E6100000C66E9F55664352C01DE736E15EF91B40	\N	f	t	2026-04-22 03:41:18.853954-05	\N	1	\N
195	1	Calle 1D ## 5-25, PASEO CATALUÑA	0101000020E610000026C808A8704352C0D769A4A5F2F61B40	\N	f	t	2026-04-22 03:41:18.870844-05	\N	1	\N
196	1	Calle 1ª #6-06, PASEO CATALUÑA	0101000020E6100000DDB6EF517F4352C04A9A3FA6B5F91B40	\N	f	t	2026-04-22 03:42:00.533414-05	\N	1	\N
197	1	Avenida Carrera 33	0101000020E6100000FE5F75E4484752C04E7ADFF8DA831C40	\N	f	t	2026-04-23 18:35:44.990336-05	\N	1	\N
198	1	Calle 35	0101000020E61000008C4AEA04344752C07DCA3159DC7F1C40	\N	f	t	2026-04-23 18:35:45.044546-05	\N	1	\N
199	1	Avenida Carrera 33	0101000020E610000076A4FACE2F4752C097016729597E1C40	\N	f	t	2026-04-23 18:35:45.058342-05	\N	1	\N
200	1	Calle 41	0101000020E610000049BC3C9D2B4752C09961A3ACDF7C1C40	\N	f	t	2026-04-23 18:35:45.070831-05	\N	1	\N
201	1	Avenida Carrera 33	0101000020E6100000E6E61BD13D4752C0EA3D95D39E821C40	\N	f	t	2026-04-23 18:35:45.09358-05	\N	1	\N
202	1	Avenida Carrera 33, Comuna Cabecera del Llano	0101000020E61000002D3F7095274752C0A7583508737B1C40	\N	f	t	2026-04-23 18:35:45.11708-05	\N	1	\N
203	1	Avenida Carrera 33, Comuna Cabecera del Llano	0101000020E6100000D68F4DF2234752C077871403247A1C40	\N	f	t	2026-04-23 18:35:45.129521-05	\N	1	\N
204	1	Avenida Carrera 33, Comuna Cabecera del Llano	0101000020E6100000D23AAA9A204752C0840F255AF2781C40	\N	f	t	2026-04-23 18:35:45.141132-05	\N	1	\N
205	1	Avenida Calle 48	0101000020E6100000CE1951DA1B4752C0B5C6A01342771C40	\N	f	t	2026-04-23 18:35:45.153405-05	\N	1	\N
206	1	Avenida Carrera 33	0101000020E61000007079AC19194752C000FF942A51761C40	\N	f	t	2026-04-23 18:35:45.164202-05	\N	1	\N
207	1	Avenida Carrera 33	0101000020E610000060CD0182394752C0B9718BF9B9811C40	\N	f	t	2026-04-23 18:35:45.174374-05	\N	1	\N
208	1	Avenida Carrera 33	0101000020E61000006C2409C2154752C03012DA722E751C40	\N	f	t	2026-04-23 18:35:45.18647-05	\N	1	\N
209	1	Parque San Josemaría (Bloque 1)	0101000020E6100000FC1873D7124752C081CD397826741C40	\N	f	t	2026-04-23 18:35:45.196465-05	\N	1	\N
210	1	Avenida Carrera 33	0101000020E6100000F33AE2900D4752C0024A438D42721C40	\N	f	t	2026-04-23 18:35:45.206773-05	\N	1	\N
211	1	Calle 54	0101000020E61000006616A1D80A4752C07B4D0F0A4A711C40	\N	f	t	2026-04-23 18:35:45.220208-05	\N	1	\N
212	1	Avenida Calle 56	0101000020E61000000D33349E084752C043FE99417C701C40	\N	f	t	2026-04-23 18:35:45.23108-05	\N	1	\N
213	1	Calle 59	0101000020E6100000C808A870044752C05D18E945ED6E1C40	\N	f	t	2026-04-23 18:35:45.239363-05	\N	1	\N
180	1	aaa bbb	0101000020E6100000810A47904A4852C08A8F4FC8CE8B1C40	\N	f	t	2026-04-20 21:07:58.010317-05	2026-04-25 02:44:35.817974-05	1	1
214	1	Avenida Carrera 33	0101000020E61000002AADBF25004752C093E34EE9606D1C40	\N	f	t	2026-04-23 18:35:45.250658-05	\N	1	\N
215	1	Transversal Oriental	0101000020E6100000EBAA402D064752C0C39FE1CD1A6C1C40	\N	f	t	2026-04-23 18:35:45.25994-05	\N	1	\N
216	1	Carrera 44	0101000020E61000008A03E8F7FD4652C0C504357C0B6B1C40	\N	f	t	2026-04-23 18:35:45.271592-05	\N	1	\N
218	1	Transversal Oriental	0101000020E61000002499D53BDC4652C00261A75835681C40	\N	f	t	2026-04-23 18:35:45.293498-05	\N	1	\N
219	1	Parque El Tejar	0101000020E610000038BA4A77D74652C032005471E3661C40	\N	f	t	2026-04-23 18:35:45.377566-05	\N	1	\N
220	1	Parqueadero C.C Cacique	0101000020E610000059897956D24652C047753A90F5641C40	\N	f	t	2026-04-23 18:35:45.383097-05	\N	1	\N
221	1	Avenida Carrera 33, Comuna 13 - Oriental	0101000020E6100000D3A57F492A4752C095826E2F697C1C40	\N	f	t	2026-04-23 18:42:52.389254-05	\N	1	\N
222	1	Avenida Carrera 33, Comuna Cabecera del Llano	0101000020E610000074EB353D284752C03BFF76D9AF7B1C40	\N	f	t	2026-04-23 18:42:52.418771-05	\N	1	\N
223	1	Calle 42	0101000020E6100000FD868906294752C046274BADF77B1C40	\N	f	t	2026-04-23 18:42:52.43115-05	\N	1	\N
224	1	Transversal Oriental	0101000020E61000000B60CAC0014752C079AF5A99F06B1C40	\N	f	t	2026-04-23 18:45:15.827433-05	\N	1	\N
225	1	Carrera 44	0101000020E6100000F29881CAF84652C0A9C29FE1CD6A1C40	\N	f	t	2026-04-23 18:45:15.833004-05	\N	1	\N
226	1	Transversal Oriental, Comuna Cabecera del Llano	0101000020E61000000EF96706F14652C0AFE94141296A1C40	\N	f	t	2026-04-23 18:45:15.905637-05	\N	1	\N
227	1	Transversal Oriental, Comuna Cabecera del Llano	0101000020E61000005E9D6340F64652C0E21FB6F4686A1C40	\N	f	t	2026-04-23 18:46:54.018915-05	\N	1	\N
228	1	Transversal Oriental	0101000020E6100000CA198A3BDE4652C019C91EA166681C40	\N	f	t	2026-04-23 18:46:54.03046-05	\N	1	\N
229	1	Transversal Oriental, Comuna Cabecera del Llano	0101000020E61000004A4563EDEF4652C03E9468C9E3691C40	\N	f	t	2026-04-23 18:46:54.040343-05	\N	1	\N
230	1	Carrera 33	0101000020E6100000E7012CF2EB4652C0B07092E68F691C40	\N	f	t	2026-04-23 18:46:54.054045-05	\N	1	\N
231	1	Transversal Oriental	0101000020E6100000D9CEF753E34652C068244223D8681C40	\N	f	t	2026-04-23 18:46:54.067745-05	\N	1	\N
232	1	Túnel Avenida Carrera 27, Comuna 13 - Oriental	0101000020E610000086AC6EF59C4752C0A29A92ACC3811C40	\N	f	t	2026-04-23 19:36:11.243936-05	\N	1	\N
233	1	Parque de Los Niños	0101000020E6100000514EB4AB904752C0880FECF82F801C40	\N	f	t	2026-04-23 19:36:11.271861-05	\N	1	\N
234	1	Parque de Los Niños	0101000020E6100000C30FCEA78E4752C028F1B913EC7F1C40	\N	f	t	2026-04-23 19:36:11.27927-05	\N	1	\N
235	1	Calle 30	0101000020E6100000C9E9EBF99A4752C03145B9347E811C40	\N	f	t	2026-04-23 19:36:11.287829-05	\N	1	\N
236	1	Avenida Carrera 27	0101000020E61000006B2C616D8C4752C072BF4351A07F1C40	\N	f	t	2026-04-23 19:36:11.297783-05	\N	1	\N
237	1	Avenida Carrera 27, Comuna 13 - Oriental	0101000020E610000066BD18CA894752C0A67C08AA467F1C40	\N	f	t	2026-04-23 19:36:11.313614-05	\N	1	\N
238	1	Calle 33	0101000020E61000000EF450DB864752C06E32AA0CE37E1C40	\N	f	t	2026-04-23 19:36:11.325821-05	\N	1	\N
239	1	Avenida Carrera 27	0101000020E6100000236937FA984752C08C4AEA0434811C40	\N	f	t	2026-04-23 19:36:11.333197-05	\N	1	\N
240	1	Avenida Carrera 27	0101000020E61000001C0A9FAD834752C05EF6EB4E777E1C40	\N	f	t	2026-04-23 19:36:11.341748-05	\N	1	\N
241	1	Avenida Carrera 27	0101000020E61000004162BB7B804752C0C51EDAC70A7E1C40	\N	f	t	2026-04-23 19:36:11.350035-05	\N	1	\N
242	1	Calle 34	0101000020E610000084B9DDCB7D4752C09EEE3CF19C7D1C40	\N	f	t	2026-04-23 19:36:11.35949-05	\N	1	\N
243	1	Túnel Avenida Carrera 27, Comuna 13 - Oriental	0101000020E6100000A1F2AFE5954752C0B5705985CD801C40	\N	f	t	2026-04-23 19:36:11.368643-05	\N	1	\N
244	1	Avenida Carrera 27	0101000020E610000091B586527B4752C06B44300E2E7D1C40	\N	f	t	2026-04-23 19:36:11.377359-05	\N	1	\N
245	1	Avenida Carrera 27	0101000020E610000057EBC4E5784752C0D34F38BBB57C1C40	\N	f	t	2026-04-23 19:36:11.385931-05	\N	1	\N
246	1	Avenida Calle 36	0101000020E61000001D210379764752C0349E08E23C7C1C40	\N	f	t	2026-04-23 19:36:11.394551-05	\N	1	\N
247	1	Avenida Carrera 27 # 36, Comuna 13 - Oriental	0101000020E61000008FFCC1C0734752C02A029CDEC57B1C40	\N	f	t	2026-04-23 19:36:11.402654-05	\N	1	\N
248	1	Avenida Carrera 27 #37-1, Comuna 13 - Oriental	0101000020E610000085D04197704752C04D1421753B7B1C40	\N	f	t	2026-04-23 19:36:11.412993-05	\N	1	\N
249	1	Avenida Carrera 27 #37-1, Comuna 13 - Oriental	0101000020E610000044FB58C16F4752C04243FF04177B1C40	\N	f	t	2026-04-23 19:36:11.42929-05	\N	1	\N
250	1	Avenida Carrera 27	0101000020E61000000FD4298F6E4752C081D1E5CDE17A1C40	\N	f	t	2026-04-23 19:36:11.439536-05	\N	1	\N
251	1	Avenida Carrera 27	0101000020E61000008D43FD2E6C4752C00F4240BE847A1C40	\N	f	t	2026-04-23 19:36:11.446497-05	\N	1	\N
252	1	Avenida Carrera 27	0101000020E61000000CCD751A694752C0F48B12F4177A1C40	\N	f	t	2026-04-23 19:36:11.453462-05	\N	1	\N
253	1	Calle 41	0101000020E610000072FA7ABE664752C08E59F624B0791C40	\N	f	t	2026-04-23 19:36:11.461513-05	\N	1	\N
254	1	Avenida Carrera 27	0101000020E61000005BECF659654752C0A648BE1248791C40	\N	f	t	2026-04-23 19:36:11.468971-05	\N	1	\N
255	1	Avenida Carrera 27	0101000020E61000009161156F644752C03A596ABDDF781C40	\N	f	t	2026-04-23 19:36:11.477836-05	\N	1	\N
256	1	Avenida Carrera 27	0101000020E61000008010C990634752C035971B0C75781C40	\N	f	t	2026-04-23 19:36:11.486163-05	\N	1	\N
257	1	Avenida Carrera 27	0101000020E6100000567DAEB6624752C0ADF6B0170A781C40	\N	f	t	2026-04-23 19:36:11.495139-05	\N	1	\N
258	1	Avenida Calle 48	0101000020E61000002DEA93DC614752C0A83462669F771C40	\N	f	t	2026-04-23 19:36:11.502721-05	\N	1	\N
259	1	Avenida Calle 48	0101000020E610000034DB15FA604752C0E831CA332F771C40	\N	f	t	2026-04-23 19:36:11.508524-05	\N	1	\N
260	1	Calle 50 #26-85, Comuna Cabecera del Llano	0101000020E6100000228AC91B604752C0A45016BEBE761C40	\N	f	t	2026-04-23 19:36:11.515419-05	\N	1	\N
261	1	Avenida Carrera 27	0101000020E6100000888384285F4752C0672C9ACE4E761C40	\N	f	t	2026-04-23 19:36:11.524458-05	\N	1	\N
262	1	Calle 51	0101000020E61000003543AA285E4752C09BAF928FDD751C40	\N	f	t	2026-04-23 19:36:11.540392-05	\N	1	\N
263	1	Avenida Carrera 27	0101000020E6100000B37E33315D4752C0CF328B506C751C40	\N	f	t	2026-04-23 19:36:11.561384-05	\N	1	\N
264	1	Carrera 27A	0101000020E61000001878EE3D5C4752C085949F54FB741C40	\N	f	t	2026-04-23 19:36:11.568395-05	\N	1	\N
265	1	Carrera 27 #52-86, Comuna La Concordia	0101000020E610000062C092AB584752C05B5EB9DE36731C40	\N	f	t	2026-04-23 19:36:11.588307-05	\N	1	\N
266	1	Avenida Carrera 27	0101000020E6100000C7B94DB8574752C006465ED6C4721C40	\N	f	t	2026-04-23 19:36:11.593595-05	\N	1	\N
267	1	Carrera 24	0101000020E610000015713AC9564752C0B8EA3A5453721C40	\N	f	t	2026-04-23 19:36:11.599827-05	\N	1	\N
268	1	Avenida Carrera 27	0101000020E61000007B6AF5D5554752C063D2DF4BE1711C40	\N	f	t	2026-04-23 19:36:11.609329-05	\N	1	\N
269	1	Avenida Carrera 27 #54-10, Comuna Cabecera del Llano	0101000020E6100000E063B0E2544752C01477BCC96F711C40	\N	f	t	2026-04-23 19:36:11.613311-05	\N	1	\N
270	1	Avenida Carrera 27	0101000020E61000002E1B9DF3534752C0433D7D04FE701C40	\N	f	t	2026-04-23 19:36:11.617261-05	\N	1	\N
271	1	Calle 55	0101000020E610000094145800534752C071033E3F8C701C40	\N	f	t	2026-04-23 19:36:11.621442-05	\N	1	\N
272	1	Avenida Calle 56, Comuna La Concordia	0101000020E6100000E2CB4411524752C09FC9FE791A701C40	\N	f	t	2026-04-23 19:36:11.625168-05	\N	1	\N
273	1	Avenida Carrera 27	0101000020E61000003C31EBC5504752C05C74B2D47A6F1C40	\N	f	t	2026-04-23 19:36:11.628734-05	\N	1	\N
275	1	Carrera 27, Comuna La Concordia	0101000020E61000006CE9D1544F4752C0B900344A976E1C40	\N	f	t	2026-04-23 19:36:11.640752-05	\N	1	\N
274	1	Avenida Carrera 27	0101000020E61000001F69705B5B4752C03CF6B3588A741C40	\N	f	t	2026-04-23 19:36:11.629117-05	\N	1	\N
276	1	Avenida Carrera 27	0101000020E6100000C651B9895A4752C0F357C85C19741C40	\N	f	t	2026-04-23 19:36:11.63397-05	\N	1	\N
277	1	Carrera 27 #52-86, Comuna La Concordia	0101000020E6100000FCC6D79E594752C02D98F8A3A8731C40	\N	f	t	2026-04-23 19:36:11.634656-05	\N	1	\N
278	1	Salida a Autopista Floridablanca	0101000020E6100000D2E28C614E4752C053CE177B2F6E1C40	\N	f	t	2026-04-23 19:36:11.648917-05	\N	1	\N
279	1	Avenida Carrera 27	0101000020E61000004F1E166A4D4752C0C0B33D7AC36D1C40	\N	f	t	2026-04-23 19:36:11.661843-05	\N	1	\N
280	1	Salida a Autopista Floridablanca	0101000020E6100000C7681D554D4752C09983A0A3556D1C40	\N	f	t	2026-04-23 19:36:11.668901-05	\N	1	\N
281	1	Salida a Autopista Floridablanca	0101000020E61000000858AB764D4752C028BA2EFCE06C1C40	\N	f	t	2026-04-23 19:36:11.673044-05	\N	1	\N
282	1	Carrera 30	0101000020E6100000CE8DE9094B4752C09A79724D816C1C40	\N	f	t	2026-04-23 19:36:11.676575-05	\N	1	\N
283	1	Avenida Carrera 27	0101000020E6100000E3E2A8DC444752C0C2D9AD65326C1C40	\N	f	t	2026-04-23 19:36:11.680151-05	\N	1	\N
284	1	Carrera 30	0101000020E610000063EE5A423E4752C07EE02A4F206C1C40	\N	f	t	2026-04-23 19:36:11.686148-05	\N	1	\N
286	1	Carrera 30	0101000020E61000003FADA23F344752C00DFAD2DB9F6B1C40	\N	f	t	2026-04-23 19:36:11.689352-05	\N	1	\N
285	1	Avenida Carrera 27	0101000020E6100000D1949D7E504752C0D481ACA7566F1C40	\N	f	t	2026-04-23 19:36:11.680852-05	\N	1	\N
292	1	Avenida Calle 67	0101000020E6100000C07B478D094752C0CA6FD1C9526B1C40	\N	f	t	2026-04-23 19:36:11.711206-05	\N	1	\N
287	1	Carrera 30	0101000020E6100000BA15C26A2C4752C03CDD79E2396B1C40	\N	f	t	2026-04-23 19:36:11.693105-05	\N	1	\N
293	1	Transversal Oriental, Comuna Cabecera del Llano	0101000020E6100000AC5791D1014752C0088F368E586B1C40	\N	f	t	2026-04-23 19:36:11.714321-05	\N	1	\N
288	1	Parque de Las Hormigas	0101000020E6100000C40AB77C244752C0751DAA29C96A1C40	\N	f	t	2026-04-23 19:36:11.695997-05	\N	1	\N
291	1	Avenida Calle 68	0101000020E6100000E19BA6CF0E4752C09D6516A1D86A1C40	\N	f	t	2026-04-23 19:36:11.707364-05	\N	1	\N
289	1	Avenida Calle 67, Comuna Cabecera del Llano	0101000020E61000002CA0504F1F4752C0486AA164726A1C40	\N	f	t	2026-04-23 19:36:11.699121-05	\N	1	\N
290	1	Avenida Calle 67	0101000020E61000000E846401134752C081E9B46E836A1C40	\N	f	t	2026-04-23 19:36:11.70489-05	\N	1	\N
294	1	Avenida Calle 56	0101000020E61000001975ADBD4F4752C0EAB46E83DA6F1C40	\N	f	t	2026-04-23 19:56:32.788873-05	\N	1	\N
295	1	Avenida Carrera 27 #45-05, Comuna Cabecera del Llano	0101000020E6100000E509849D624752C0C8940F41D5781C40	\N	f	t	2026-04-23 19:56:32.811104-05	\N	1	\N
296	1	Avenida Carrera 27	0101000020E6100000E2B19FC5524752C0209A79724D711C40	\N	f	t	2026-04-23 19:56:32.818444-05	\N	1	\N
297	1	Avenida Carrera 27, Comuna Cabecera del Llano	0101000020E6100000EC2E5052604752C0E7AA798EC8771C40	\N	f	t	2026-04-23 19:56:32.825927-05	\N	1	\N
298	1	Calle 48 #27-38, Comuna La Concordia	0101000020E61000001DE736E15E4752C0F92EA52E19771C40	\N	f	t	2026-04-23 19:56:32.832737-05	\N	1	\N
299	1	Avenida Carrera 27	0101000020E61000009599D2FA5B4752C062F6B2EDB4751C40	\N	f	t	2026-04-23 19:56:32.839943-05	\N	1	\N
300	1	Carrera 27 #52-86, Comuna La Concordia	0101000020E610000027C286A7574752C0C64D0D349F731C40	\N	f	t	2026-04-23 19:56:32.848141-05	\N	1	\N
301	1	Carrera 27A	0101000020E610000078B471C45A4752C09622F94A20751C40	\N	f	t	2026-04-23 19:56:32.855956-05	\N	1	\N
302	1	Avenida Carrera 27	0101000020E6100000F6EFFACC594752C01ADF1797AA741C40	\N	f	t	2026-04-23 19:56:32.863223-05	\N	1	\N
303	1	Avenida Carrera 27	0101000020E61000000A14B188614752C0C9552C7E53781C40	\N	f	t	2026-04-23 19:56:32.869561-05	\N	1	\N
304	1	Avenida Carrera 27	0101000020E6100000BE1248895D4752C0833463D174761C40	\N	f	t	2026-04-23 19:56:32.879162-05	\N	1	\N
305	1	Avenida Carrera 27	0101000020E610000074620FED634752C09A25016A6A791C40	\N	f	t	2026-04-23 19:56:32.890491-05	\N	1	\N
306	1	Avenida Carrera 27	0101000020E61000000053060E684752C0AF06280D357A1C40	\N	f	t	2026-04-23 19:56:32.90116-05	\N	1	\N
307	1	Avenida Carrera 27	0101000020E61000008638D6C56D4752C097395D16137B1C40	\N	f	t	2026-04-23 19:56:32.914283-05	\N	1	\N
308	1	Avenida Carrera 27	0101000020E6100000BF9A0304734752C0AC545051F57B1C40	\N	f	t	2026-04-23 19:56:32.922806-05	\N	1	\N
309	1	Avenida Carrera 27	0101000020E6100000751E15FF774752C0C74961DEE37C1C40	\N	f	t	2026-04-23 19:56:32.931026-05	\N	1	\N
310	1	Calle 34	0101000020E6100000A9DDAF027C4752C054724EECA17D1C40	\N	f	t	2026-04-23 19:56:32.938215-05	\N	1	\N
311	1	Avenida Carrera 27	0101000020E61000007100FDBE7F4752C097AAB4C5357E1C40	\N	f	t	2026-04-23 19:56:32.946672-05	\N	1	\N
312	1	Avenida Carrera 27	0101000020E61000007C462234824752C09775FF58887E1C40	\N	f	t	2026-04-23 19:56:32.953017-05	\N	1	\N
313	1	Calle 33	0101000020E610000004AE2B66844752C0B891B245D27E1C40	\N	f	t	2026-04-23 19:56:32.961235-05	\N	1	\N
314	1	Calle 33 #27-11, Comuna 13 - Oriental	0101000020E6100000EA03C93B874752C0C9B08A37327F1C40	\N	f	t	2026-04-23 19:56:32.966256-05	\N	1	\N
315	1	Avenida Carrera 27	0101000020E61000001349F4328A4752C00C7558E1967F1C40	\N	f	t	2026-04-23 19:56:32.973645-05	\N	1	\N
316	1	Avenida Carrera 27	0101000020E610000011C7BAB88D4752C0C7D79E5912801C40	\N	f	t	2026-04-23 19:56:32.980307-05	\N	1	\N
317	1	Túnel Avenida Carrera 27	0101000020E6100000250516C0944752C0A987687407811C40	\N	f	t	2026-04-23 19:56:32.986897-05	\N	1	\N
217	1	Carrera 33	0101000020E6100000BEBC00FBE84652C0BC3C9D2B4A691C40	\N	f	f	2026-04-23 18:35:45.287036-05	2026-04-23 20:35:37.661019-05	1	1
318	1	Urbanización El Girasol	0101000020E61000009F73B7EBA54652C00954FF2092611C40	\N	f	t	2026-04-24 01:24:32.205382-05	\N	1	\N
319	1	Transversal Oriental	0101000020E6100000C72DE6E7864652C0C3B645990D621C40	\N	f	t	2026-04-24 01:39:14.240735-05	\N	1	\N
320	1	Balcones de la Colina	0101000020E61000009D6340F67A4652C0BA84436FF1601C40	\N	f	t	2026-04-24 01:39:14.251273-05	\N	1	\N
321	1	Calle 107A	0101000020E6100000E294B9F9464652C05CAE7E6C925F1C40	\N	f	t	2026-04-24 01:39:14.258451-05	\N	1	\N
322	1	Calle 11, Comuna de San Francisco	0101000020E610000007B64AB0384852C0F9872D3D9A8A1C40	\N	f	t	2026-04-24 01:45:43.494003-05	\N	1	\N
323	1	Carrera 18, Comuna de San Francisco	0101000020E61000007D5EF1D4234852C01B0FB6D8ED831C40	\N	f	t	2026-04-24 01:45:43.501819-05	\N	1	\N
324	1	Carrera 18	0101000020E610000039F06AB9334852C0406D54A703891C40	\N	f	t	2026-04-24 01:45:43.508805-05	\N	1	\N
325	1	Calle 21 #18-32, Comuna de San Francisco	0101000020E61000004A07EBFF1C4852C0D55C6E30D4811C40	\N	f	t	2026-04-24 01:45:43.515795-05	\N	1	\N
326	1	Carrera 18	0101000020E610000022A81ABD1A4852C0DC4944F817811C40	\N	f	t	2026-04-24 01:45:43.52261-05	\N	1	\N
328	1	Calle 28, Comuna de San Francisco	0101000020E610000072158BDF144852C0A0FEB3E6C77F1C40	\N	f	t	2026-04-24 01:45:43.53717-05	\N	1	\N
329	1	Avenida Quebrada Seca	0101000020E61000006FF4311F104852C00D198F52097F1C40	\N	f	t	2026-04-24 01:45:43.544223-05	\N	1	\N
330	1	Calle 30	0101000020E61000002AFEEF880A4852C053CE177B2F7E1C40	\N	f	t	2026-04-24 01:45:43.550169-05	\N	1	\N
331	1	Boulevard Bolívar	0101000020E6100000894336902E4852C054909F8D5C871C40	\N	f	t	2026-04-24 01:45:43.558415-05	\N	1	\N
332	1	Carrera 18 #30-56, Comuna Centro	0101000020E610000009C4EBFA054852C0E27327D87F7D1C40	\N	f	t	2026-04-24 01:45:43.565524-05	\N	1	\N
333	1	Carrera 18	0101000020E610000059315C1D004852C001A777F17E7C1C40	\N	f	t	2026-04-24 01:45:43.57369-05	\N	1	\N
334	1	Carrera 18, Comuna Centro	0101000020E6100000FD12F1D6F94752C030BABC395C7B1C40	\N	f	t	2026-04-24 01:45:43.580761-05	\N	1	\N
335	1	Calle 17	0101000020E61000004A24D1CB284852C046D1031F83851C40	\N	f	t	2026-04-24 01:45:43.589179-05	\N	1	\N
336	1	Carrera 18, Comuna Centro	0101000020E6100000D769A4A5F24752C05AD6FD63217A1C40	\N	f	t	2026-04-24 01:45:43.59709-05	\N	1	\N
337	1	Boulevard Santander	0101000020E610000025AFCE31204852C0ABAFAE0AD4821C40	\N	f	t	2026-04-24 01:45:43.6025-05	\N	1	\N
338	1	Carrera 18, Comuna de San Francisco	0101000020E61000003A2174D0254852C064213A048E841C40	\N	f	t	2026-04-24 01:45:43.609454-05	\N	1	\N
339	1	Calle 17	0101000020E6100000C6DD205A2B4852C0A54BFF9254861C40	\N	f	t	2026-04-24 01:45:43.616291-05	\N	1	\N
340	1	680001	0101000020E610000060048D99444852C0D53DB2B96A8E1C40	\N	f	t	2026-04-24 03:27:21.761282-05	\N	1	\N
341	1	Calle 8A	0101000020E610000003983270404852C06C0A6476168D1C40	\N	f	t	2026-04-24 03:27:21.790662-05	\N	1	\N
342	1	Calle 10A, Comuna de San Francisco	0101000020E610000077F52A323A4852C0B3EA73B5158B1C40	\N	f	t	2026-04-24 03:27:21.800856-05	\N	1	\N
343	1	Calle 12	0101000020E610000049D92269374852C08D98D9E7318A1C40	\N	f	t	2026-04-24 03:27:21.811959-05	\N	1	\N
344	1	Calle 8A	0101000020E61000005001309E414852C005C58F31778D1C40	\N	f	t	2026-04-24 03:27:21.81914-05	\N	1	\N
345	1	Carrera 18	0101000020E61000003E7958A8354852C077483140A2891C40	\N	f	t	2026-04-24 03:27:21.832927-05	\N	1	\N
346	1	Boulevard Bolívar	0101000020E6100000105D50DF324852C0C95A43A9BD881C40	\N	f	t	2026-04-24 03:27:21.841196-05	\N	1	\N
347	1	Parque Cristo Rey	0101000020E6100000CFA44DD53D4852C0514F1F813F8C1C40	\N	f	t	2026-04-24 03:27:21.850102-05	\N	1	\N
348	1	Calle 10, Comuna de San Francisco	0101000020E610000035B8AD2D3C4852C096CFF23CB88B1C40	\N	f	t	2026-04-24 03:27:21.861108-05	\N	1	\N
349	1	Carrera 21, Comuna de San Francisco	0101000020E6100000047289230F4852C0E1EF17B3258B1C40	\N	f	t	2026-04-24 03:28:52.34884-05	\N	1	\N
350	1	Carrera 21	0101000020E610000001857AFA084852C04B3E761728891C40	\N	f	t	2026-04-24 03:28:52.352292-05	\N	1	\N
351	1	Carrera 21	0101000020E6100000A69718CBF44752C0C286A757CA821C40	\N	f	t	2026-04-24 03:28:52.361464-05	\N	1	\N
80	1	cr22#6	0101000020E6100000BB32D1460D4852C090C3BCD05A8F1C40	\N	f	f	2026-04-17 12:50:26.644003-05	2026-04-24 03:29:30.929139-05	1	1
352	1	Calle 7, Comuna de San Francisco	0101000020E610000040BE840A0E4852C09B594B01698F1C40	\N	f	t	2026-04-24 03:30:14.661918-05	\N	1	\N
353	1	Carrera 22	0101000020E610000012A27C410B4852C03CA583F57F8E1C40	\N	f	t	2026-04-24 03:30:14.669649-05	\N	1	\N
354	1	Carrera 22	0101000020E6100000F6F065A2084852C0F30181CEA48D1C40	\N	f	t	2026-04-24 03:30:14.677826-05	\N	1	\N
355	1	Carrera 23, Comuna de San Francisco	0101000020E6100000BC404981054852C0DE8FDB2F9F8C1C40	\N	f	t	2026-04-24 03:30:14.683851-05	\N	1	\N
356	1	Calle 11, Comuna de San Francisco	0101000020E61000003AB01C21034852C073B8567BD88B1C40	\N	f	t	2026-04-24 03:30:14.691118-05	\N	1	\N
357	1	Calle 11, Comuna de San Francisco	0101000020E6100000899B53C9004852C0C4211B48178B1C40	\N	f	t	2026-04-24 03:30:14.70023-05	\N	1	\N
358	1	Avenida Carrera 30	0101000020E6100000CA4E3FA88B4752C07E71A94A5B8C1C40	\N	f	t	2026-04-25 00:17:51.064773-05	\N	1	\N
359	1	Parqueadero Estadio	0101000020E610000017B83CD68C4752C0BF81C98D228B1C40	\N	f	t	2026-04-25 00:17:51.094042-05	\N	1	\N
360	1	Unidad Deportiva Américo Montanini	0101000020E6100000179E978A8D4752C0F3565D876A8A1C40	\N	f	t	2026-04-25 00:17:51.105247-05	\N	1	\N
361	1	Parqueadero Estadio	0101000020E610000047567E198C4752C07F32C687D98B1C40	\N	f	t	2026-04-25 00:17:51.115195-05	\N	1	\N
327	1	Carrera 18	0101000020E61000002FA4C343184852C055FB743C66801C40	\N	f	f	2026-04-24 01:45:43.530103-05	2026-04-25 02:34:30.833579-05	1	1
362	1	Rotonda Estadio, Comuna 13 - Oriental	0101000020E610000021E4BCFF8F4752C082AAD1AB018A1C40	\N	f	t	2026-04-25 00:17:51.125104-05	\N	1	\N
363	1	Carrera 30 #14-27, Comuna 13 - Oriental	0101000020E6100000BEA085048C4752C0EA07759142891C40	\N	f	t	2026-04-25 00:17:51.132818-05	\N	1	\N
364	1	carrera 30 #16-41, Comuna 13 - Oriental	0101000020E61000006DAE9AE7884752C091F3FE3F4E881C40	\N	f	t	2026-04-25 00:17:51.141723-05	\N	1	\N
365	1	Carrera 30, Comuna 13 - Oriental	0101000020E6100000D9CC21A9854752C0CBD765F84F871C40	\N	f	t	2026-04-25 00:17:51.149313-05	\N	1	\N
366	1	Carrera 30	0101000020E61000003A3DEFC6824752C0AB4203B16C861C40	\N	f	t	2026-04-25 00:17:51.157594-05	\N	1	\N
367	1	Calle 20 #30-27, Comuna 13 - Oriental	0101000020E6100000A741D13C804752C03AAE4676A5851C40	\N	f	t	2026-04-25 00:17:51.170054-05	\N	1	\N
368	1	Calle 21	0101000020E6100000315F5E807D4752C09C14E63DCE841C40	\N	f	t	2026-04-25 00:17:51.179383-05	\N	1	\N
369	1	Avenida Quebrada Seca, Comuna 13 - Oriental	0101000020E61000003E5B07077B4752C065E256410C841C40	\N	f	t	2026-04-25 00:17:51.187511-05	\N	1	\N
370	1	Carrera 30 #29-01, Comuna 13 - Oriental	0101000020E610000081B22957784752C01DCBBBEA01831C40	\N	f	t	2026-04-25 00:17:51.196001-05	\N	1	\N
371	1	Calle 30	0101000020E610000037FFAF3A724752C04B00FE2955821C40	\N	f	t	2026-04-25 00:17:51.204515-05	\N	1	\N
372	1	Calle 31	0101000020E61000000FBA84436F4752C046787B1002821C40	\N	f	t	2026-04-25 00:17:51.212405-05	\N	1	\N
373	1	Calle 31	0101000020E6100000ED65DB696B4752C0307F85CC95811C40	\N	f	t	2026-04-25 00:17:51.221585-05	\N	1	\N
374	1	Carrera 30	0101000020E6100000508C2C99634752C0A41CCC26C0801C40	\N	f	t	2026-04-25 00:17:51.230486-05	\N	1	\N
375	1	Calle 33, Comuna 13 - Oriental	0101000020E61000000727A25F5B4752C0BCCCB051D67F1C40	\N	f	t	2026-04-25 00:17:51.2406-05	\N	1	\N
376	1	Calle 35 #30-15, Comuna 13 - Oriental	0101000020E6100000A67F492A534752C0DA39CD02ED7E1C40	\N	f	t	2026-04-25 00:17:51.25219-05	\N	1	\N
377	1	Calle 35, Comuna 13 - Oriental	0101000020E61000009DA1B8E34D4752C003ECA353577E1C40	\N	f	t	2026-04-25 00:17:51.267717-05	\N	1	\N
378	1	Avenida Calle 36	0101000020E61000004208C897504752C0A30227DBC07D1C40	\N	f	t	2026-04-25 00:17:51.286312-05	\N	1	\N
379	1	Avenida Calle 36	0101000020E6100000E02F664B564752C08786C5A86B7D1C40	\N	f	t	2026-04-25 00:17:51.301273-05	\N	1	\N
380	1	Carrera 28	0101000020E61000003F6F2A52614752C094DE37BEF67C1C40	\N	f	t	2026-04-25 00:17:51.311937-05	\N	1	\N
381	1	Avenida Calle 36	0101000020E610000017618A72694752C0001B1021AE7C1C40	\N	f	t	2026-04-25 00:17:51.321492-05	\N	1	\N
382	1	Avenida Carrera 27 #36-07, Comuna 13 - Oriental	0101000020E61000007FDFBF79714752C0C82764E76D7C1C40	\N	f	t	2026-04-25 00:17:51.332532-05	\N	1	\N
383	1	Túnel Avenida Carrera 27	0101000020E61000002235ED629A4752C0852348A5D8811C40	\N	f	t	2026-04-25 00:18:50.076432-05	\N	1	\N
384	1	Túnel Avenida Quebrada Seca	0101000020E610000005508C2C994752C078B306EFAB821C40	\N	f	t	2026-04-25 00:18:50.08171-05	\N	1	\N
385	1	Avenida Calle 14	0101000020E61000006F0C01C0B14752C006A1BC8FA3891C40	\N	f	t	2026-04-25 00:18:50.140236-05	\N	1	\N
386	1	Cra 27 #12-27, Comuna de San Francisco	0101000020E610000004560E2DB24752C05837DE1D198B1C40	\N	f	t	2026-04-25 00:18:50.171557-05	\N	1	\N
387	1	Avenida Carrera 27, Comuna de San Francisco	0101000020E610000052F355F2B14752C0B72A89EC838C1C40	\N	f	t	2026-04-25 00:18:50.19351-05	\N	1	\N
388	1	Túnel Avenida Carrera 27	0101000020E61000001E17D522A24752C08176871403841C40	\N	f	t	2026-04-25 00:18:50.199647-05	\N	1	\N
389	1	Calle 20	0101000020E6100000BD72BD6DA64752C0DA38622D3E851C40	\N	f	t	2026-04-25 00:18:50.206575-05	\N	1	\N
390	1	Calle 18, Comuna de San Francisco	0101000020E610000056116E32AA4752C0336FD575A8861C40	\N	f	t	2026-04-25 00:18:50.208949-05	\N	1	\N
391	1	Parque Calle 16	0101000020E6100000309FAC18AE4752C0BE67244223881C40	\N	f	t	2026-04-25 00:18:50.216679-05	\N	1	\N
392	1	Calle 18, Comuna de San Francisco	0101000020E61000004F20EC14AB4752C0009013268C861C40	\N	f	t	2026-04-25 00:21:44.827398-05	\N	1	\N
393	1	Avenida Carrera 27	0101000020E61000008E59F624B04752C0F777B6476F881C40	\N	f	t	2026-04-25 00:21:44.837937-05	\N	1	\N
394	1	Calle 17	0101000020E6100000367689EAAD4752C06A15FDA199871C40	\N	f	t	2026-04-25 00:21:44.847357-05	\N	1	\N
395	1	Avenida Carrera 27	0101000020E6100000EC134031B24752C0F581E49D43891C40	\N	f	t	2026-04-25 00:21:44.858685-05	\N	1	\N
396	1	Carrera 27 #13-34, Comuna de San Francisco	0101000020E6100000FD4AE7C3B34752C0F9653046248A1C40	\N	f	t	2026-04-25 00:21:44.870299-05	\N	1	\N
397	1	Cra 27 #12-27, Comuna de San Francisco	0101000020E6100000A4198BA6B34752C06FF1F09E038B1C40	\N	f	t	2026-04-25 00:21:44.883246-05	\N	1	\N
398	1	Calle 11, Comuna de San Francisco	0101000020E610000092AE997CB34752C00211E2CAD98B1C40	\N	f	t	2026-04-25 00:21:44.897871-05	\N	1	\N
399	1	Avenida Carrera 27, Comuna de San Francisco	0101000020E610000027F8A6E9B34752C0787FBC57AD8C1C40	\N	f	t	2026-04-25 00:21:44.909547-05	\N	1	\N
400	1	Parque Caballo de Bolivar	0101000020E6100000A297512CB74752C04436902E368D1C40	\N	f	t	2026-04-25 00:21:44.9193-05	\N	1	\N
401	1	Carrera 25	0101000020E61000000A9E42AED44752C06AC020E9D38A1C40	\N	f	t	2026-04-25 01:25:06.214278-05	\N	1	\N
402	1	Calle 15 #25-46, Comuna de San Francisco	0101000020E6100000EBE5779ACC4752C0F163CC5D4B881C40	\N	f	t	2026-04-25 01:25:06.233497-05	\N	1	\N
403	1	Carrera 25 #16-52, Comuna de San Francisco	0101000020E6100000E6762FF7C94752C053CA6B2574871C40	\N	f	t	2026-04-25 01:25:06.241849-05	\N	1	\N
404	1	Carrera 25 #18-39, Comuna de San Francisco	0101000020E6100000FA97A432C54752C05CCAF962EF851C40	\N	f	t	2026-04-25 01:25:06.253514-05	\N	1	\N
405	1	Avenida Calle 14 #25-30, Comuna de San Francisco	0101000020E6100000B4226AA2CF4752C056F2B1BB40891C40	\N	f	t	2026-04-25 01:25:06.266137-05	\N	1	\N
406	1	Calle 19	0101000020E610000079211D1EC24752C0363E93FDF3841C40	\N	f	t	2026-04-25 01:25:06.277253-05	\N	1	\N
407	1	Carrera 25	0101000020E6100000DB300A82C74752C0D8BB3FDEAB861C40	\N	f	t	2026-04-25 01:25:06.288731-05	\N	1	\N
408	1	Carrera 25 #16-20, Comuna de San Francisco	0101000020E6100000F7C77BD5CA4752C05378D0ECBA871C40	\N	f	t	2026-04-25 01:25:06.301376-05	\N	1	\N
409	1	Calle 8	0101000020E61000008C4AEA04344852C0AF7C96E7C18D1C40	\N	f	t	2026-04-25 02:17:54.16488-05	\N	1	\N
410	1	Carrera 16A	0101000020E610000023A46E675F4852C0CAA65CE15D8E1C40	\N	f	t	2026-04-25 02:17:54.189073-05	\N	1	\N
411	1	Carrera 15B	0101000020E61000002864E76D6C4852C02FA4C343188F1C40	\N	f	t	2026-04-25 02:17:54.203723-05	\N	1	\N
412	1	Calle 11, Comuna de San Francisco	0101000020E6100000BD361B2B314852C0C5AD8218E88A1C40	\N	f	t	2026-04-25 02:17:54.214978-05	\N	1	\N
413	1	Calle 8	0101000020E6100000BDFF8F13264852C031B2648EE58D1C40	\N	f	t	2026-04-25 02:17:54.225338-05	\N	1	\N
414	1	Calle 9, Comuna de San Francisco	0101000020E6100000CAA48636004852C0A4A65D4C338D1C40	\N	f	t	2026-04-25 02:17:54.233321-05	\N	1	\N
415	1	Carrera 24A	0101000020E6100000840F255AF24752C017299485AF8F1C40	\N	f	t	2026-04-25 02:17:54.239866-05	\N	1	\N
416	1	Carrera 21	0101000020E610000005DD5ED2184852C07B336ABE4A8E1C40	\N	f	t	2026-04-25 02:17:54.248381-05	\N	1	\N
417	1	Carrera 24	0101000020E61000008577B988EF4752C0693BA6EECA8E1C40	\N	f	t	2026-04-25 02:17:54.255948-05	\N	1	\N
418	1	Calle 9 #23-61, Comuna de San Francisco	0101000020E6100000CFF3A78DEA4752C032FFE89B348D1C40	\N	f	t	2026-04-25 02:17:54.264015-05	\N	1	\N
419	1	Calle 10A, Comuna de San Francisco	0101000020E610000006836BEEE84752C0EA211ADD418C1C40	\N	f	t	2026-04-25 02:17:54.272398-05	\N	1	\N
420	1	Calle 8A	0101000020E61000005A643BDF4F4852C071CCB227818D1C40	\N	f	t	2026-04-25 02:17:54.279356-05	\N	1	\N
421	1	Calle 12	0101000020E61000004451A04FE44752C091D3D7F3358B1C40	\N	f	t	2026-04-25 02:17:54.288324-05	\N	1	\N
422	1	Calle 4	0101000020E6100000166A4DF38E4852C0C4D155BABB8E1C40	\N	f	t	2026-04-25 02:18:35.156799-05	\N	1	\N
423	1	Carrera 11	0101000020E6100000B20FB22C984852C0D594641D8E8E1C40	\N	f	t	2026-04-25 02:18:35.162163-05	\N	1	\N
424	1	Carrera 14	0101000020E61000007689EAAD814852C0DAC534D3BD8E1C40	\N	f	t	2026-04-25 02:18:35.220855-05	\N	1	\N
425	1	Calle 0A	0101000020E610000062A2410A9E4852C08F8AFF3BA2921C40	\N	f	t	2026-04-25 02:18:35.252731-05	\N	1	\N
426	1	Calle 3	0101000020E61000007711A628974852C0A5BBEB6CC88F1C40	\N	f	t	2026-04-25 02:18:35.253092-05	\N	1	\N
427	1	Avenida Carrera 15	0101000020E6100000C170AE61864852C00CE9F010C68F1C40	\N	f	t	2026-04-25 02:18:35.252966-05	\N	1	\N
428	1	Carrera 13	0101000020E6100000575F5D15A84852C04912842BA0901C40	\N	f	t	2026-04-25 02:18:35.346372-05	\N	1	\N
429	1	Calle 4	0101000020E6100000BB2BBB60704852C02713B70A62901C40	\N	f	t	2026-04-25 02:23:24.392238-05	\N	1	\N
430	1	Carrera 19	0101000020E61000003CDD79E2394852C0CD94D6DF12901C40	\N	f	t	2026-04-25 02:23:24.398305-05	\N	1	\N
431	1	Calle 6	0101000020E6100000D34ECDE5064852C061FC34EECD8F1C40	\N	f	t	2026-04-25 02:23:24.410004-05	\N	1	\N
432	1	Calle 6	0101000020E610000013D38558FD4752C09F55664AEB8F1C40	\N	f	t	2026-04-25 02:23:24.419114-05	\N	1	\N
190	1	Diagonal 15 #45-54, Comuna 5 Garcia Rovira	0101000020E6100000AE0CAA0D4E4852C0967A1684F26E1C40	\N	f	f	2026-04-21 17:32:38.715605-05	2026-04-25 02:33:10.656666-05	1	1
433	1	Carrera 19 #22-03, Comuna Occidental	0101000020E61000005ED72FD80D4852C0C49448A297811C40	\N	f	t	2026-04-25 03:32:52.890153-05	\N	1	\N
434	1	Calle 24, Comuna de San Francisco	0101000020E6100000B0C91AF5104852C07172BF4351801C40	\N	f	t	2026-04-25 03:32:52.906666-05	\N	1	\N
435	1	Carrera 18	0101000020E61000004698A25C1A4852C00ADB4FC6F8801C40	\N	f	t	2026-04-25 03:32:52.912948-05	\N	1	\N
436	1	Carrera 25 #18-39, Comuna de San Francisco	0101000020E610000030F31DFCC44752C09BAF928FDD851C40	\N	f	t	2026-04-25 15:34:14.993132-05	\N	1	\N
437	1	Calle 19	0101000020E610000061DF4E22C24752C0BED9E6C6F4841C40	\N	f	t	2026-04-25 15:34:14.999218-05	\N	1	\N
438	1	Boulevard Bolívar	0101000020E610000092CB7F48BF4752C06B9F8EC70C841C40	\N	f	t	2026-04-25 15:34:15.044609-05	\N	1	\N
439	1	Calle 20 #22-20, Comuna de San Francisco	0101000020E61000008F1B7E37DD4752C0312592E865841C40	\N	f	t	2026-05-13 00:12:36.048688-05	\N	1	\N
\.


--
-- Data for Name: tab_route_points_assoc; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_route_points_assoc (id_route, id_point, point_order, dist_from_start, eta_seconds, is_active) FROM stdin;
33	111	10	\N	\N	t
37	122	1	\N	\N	t
37	120	2	\N	\N	t
37	119	3	\N	\N	t
37	142	4	\N	\N	t
37	111	5	\N	\N	t
37	109	6	\N	\N	t
37	112	7	\N	\N	t
37	108	8	\N	\N	t
34	74	1	\N	\N	t
34	73	2	\N	\N	t
34	72	3	\N	\N	t
34	5	4	\N	\N	t
34	71	5	\N	\N	t
34	8	6	\N	\N	t
34	9	7	\N	\N	t
34	10	8	\N	\N	t
35	71	1	\N	\N	t
35	8	2	\N	\N	t
35	9	3	\N	\N	t
35	10	4	\N	\N	t
35	70	5	\N	\N	t
35	69	6	\N	\N	t
35	68	7	\N	\N	t
35	67	8	\N	\N	t
35	66	9	\N	\N	t
35	65	10	\N	\N	t
35	64	11	\N	\N	t
35	11	12	\N	\N	t
35	63	13	\N	\N	t
35	62	14	\N	\N	t
35	13	15	\N	\N	t
35	14	16	\N	\N	t
35	15	17	\N	\N	t
35	16	18	\N	\N	t
35	61	19	\N	\N	t
36	131	1	\N	\N	t
36	116	2	\N	\N	t
36	139	3	\N	\N	t
36	143	4	\N	\N	t
36	121	5	\N	\N	t
36	123	6	\N	\N	t
36	133	7	\N	\N	t
36	9	8	\N	\N	t
36	10	9	\N	\N	t
36	70	10	\N	\N	t
37	110	9	\N	\N	t
37	103	10	\N	\N	t
37	113	11	\N	\N	t
37	104	12	\N	\N	t
37	105	13	\N	\N	t
37	106	14	\N	\N	t
37	107	15	\N	\N	t
38	66	1	\N	\N	t
38	65	2	\N	\N	t
38	64	3	\N	\N	t
38	11	4	\N	\N	t
38	63	5	\N	\N	t
38	27	6	\N	\N	t
40	93	1	\N	\N	t
40	92	2	\N	\N	t
40	95	3	\N	\N	t
40	98	4	\N	\N	t
40	99	5	\N	\N	t
40	81	6	\N	\N	t
40	80	7	\N	\N	t
40	79	8	\N	\N	t
40	78	9	\N	\N	t
40	77	10	\N	\N	t
41	128	1	\N	\N	t
41	126	2	\N	\N	t
41	127	3	\N	\N	t
41	130	4	\N	\N	t
41	140	5	\N	\N	t
41	129	6	\N	\N	t
41	137	7	\N	\N	t
41	132	8	\N	\N	t
41	135	9	\N	\N	t
41	134	10	\N	\N	t
41	136	11	\N	\N	t
41	138	12	\N	\N	t
42	81	1	\N	\N	t
42	80	2	\N	\N	t
42	79	3	\N	\N	t
42	78	4	\N	\N	t
42	77	5	\N	\N	t
42	76	6	\N	\N	t
42	75	7	\N	\N	t
42	74	8	\N	\N	t
42	73	9	\N	\N	t
42	72	10	\N	\N	t
42	5	11	\N	\N	t
42	71	12	\N	\N	t
42	8	13	\N	\N	t
42	85	14	\N	\N	t
42	85	15	\N	\N	t
42	9	16	\N	\N	t
42	10	17	\N	\N	t
42	70	18	\N	\N	t
42	69	19	\N	\N	t
42	68	20	\N	\N	t
42	67	21	\N	\N	t
42	66	22	\N	\N	t
42	65	23	\N	\N	t
42	64	24	\N	\N	t
42	11	25	\N	\N	t
42	63	26	\N	\N	t
42	62	27	\N	\N	t
42	13	28	\N	\N	t
42	14	29	\N	\N	t
42	15	30	\N	\N	t
42	16	31	\N	\N	t
39	83	1	\N	\N	t
39	84	2	\N	\N	t
39	85	3	\N	\N	t
39	86	4	\N	\N	t
39	87	5	\N	\N	t
39	88	6	\N	\N	t
39	163	7	\N	\N	t
39	89	8	\N	\N	t
39	161	9	\N	\N	t
39	90	10	\N	\N	t
39	91	11	\N	\N	t
42	161	32	\N	\N	t
39	92	12	\N	\N	t
39	93	13	\N	\N	t
39	94	14	\N	\N	t
42	163	33	\N	\N	t
33	83	1	\N	\N	t
33	86	2	\N	\N	t
33	84	3	\N	\N	t
33	82	4	\N	\N	t
33	87	5	\N	\N	t
33	88	6	\N	\N	t
33	89	7	\N	\N	t
33	90	8	\N	\N	t
33	91	9	\N	\N	t
43	81	1	\N	\N	t
43	80	2	\N	\N	t
43	79	3	\N	\N	t
43	78	4	\N	\N	t
43	77	5	\N	\N	t
43	76	6	\N	\N	t
43	75	7	\N	\N	t
43	74	8	\N	\N	t
43	73	9	\N	\N	t
43	72	10	\N	\N	t
43	5	11	\N	\N	t
43	162	12	\N	\N	t
43	71	13	\N	\N	t
43	8	14	\N	\N	t
43	9	15	\N	\N	t
43	10	16	\N	\N	t
43	70	17	\N	\N	t
43	69	18	\N	\N	t
43	68	19	\N	\N	t
43	67	20	\N	\N	t
43	66	21	\N	\N	t
43	65	22	\N	\N	t
43	64	23	\N	\N	t
43	11	24	\N	\N	t
43	63	25	\N	\N	t
43	62	26	\N	\N	t
43	13	27	\N	\N	t
43	14	28	\N	\N	t
43	15	29	\N	\N	t
43	16	30	\N	\N	t
43	12	31	\N	\N	t
43	61	32	\N	\N	t
43	60	33	\N	\N	t
43	59	34	\N	\N	t
43	58	35	\N	\N	t
43	57	36	\N	\N	t
43	56	37	\N	\N	t
43	55	38	\N	\N	t
43	54	39	\N	\N	t
43	53	40	\N	\N	t
43	52	41	\N	\N	t
43	51	42	\N	\N	t
43	42	43	\N	\N	t
43	41	44	\N	\N	t
43	40	45	\N	\N	t
43	39	46	\N	\N	t
43	38	47	\N	\N	t
43	37	48	\N	\N	t
43	36	49	\N	\N	t
43	35	50	\N	\N	t
43	34	51	\N	\N	t
43	33	52	\N	\N	t
43	32	53	\N	\N	t
43	31	54	\N	\N	t
43	30	55	\N	\N	t
43	29	56	\N	\N	t
43	28	57	\N	\N	t
43	27	58	\N	\N	t
43	26	59	\N	\N	t
43	25	60	\N	\N	t
43	24	61	\N	\N	t
43	23	62	\N	\N	t
43	176	63	\N	\N	t
43	22	64	\N	\N	t
43	21	65	\N	\N	t
43	177	66	\N	\N	t
43	20	67	\N	\N	t
43	19	68	\N	\N	t
43	178	69	\N	\N	t
43	82	70	\N	\N	t
43	83	71	\N	\N	t
43	84	72	\N	\N	t
43	85	73	\N	\N	t
43	86	74	\N	\N	t
43	87	75	\N	\N	t
43	88	76	\N	\N	t
43	89	77	\N	\N	t
43	90	78	\N	\N	t
43	91	79	\N	\N	t
43	92	80	\N	\N	t
43	93	81	\N	\N	t
43	94	82	\N	\N	t
43	95	83	\N	\N	t
43	96	84	\N	\N	t
43	97	85	\N	\N	t
43	98	86	\N	\N	t
43	99	87	\N	\N	t
44	81	1	\N	\N	t
44	80	2	\N	\N	t
44	79	3	\N	\N	t
44	78	4	\N	\N	t
44	77	5	\N	\N	t
44	76	6	\N	\N	t
44	75	7	\N	\N	t
44	74	8	\N	\N	t
44	73	9	\N	\N	t
44	72	10	\N	\N	t
44	5	11	\N	\N	t
44	162	12	\N	\N	t
44	71	13	\N	\N	t
44	8	14	\N	\N	t
44	9	15	\N	\N	t
44	10	16	\N	\N	t
44	70	17	\N	\N	t
44	69	18	\N	\N	t
44	68	19	\N	\N	t
44	67	20	\N	\N	t
44	66	21	\N	\N	t
44	65	22	\N	\N	t
44	64	23	\N	\N	t
44	11	24	\N	\N	t
44	63	25	\N	\N	t
44	62	26	\N	\N	t
44	13	27	\N	\N	t
44	14	28	\N	\N	t
44	15	29	\N	\N	t
44	16	30	\N	\N	t
44	12	31	\N	\N	t
44	61	32	\N	\N	t
44	33	33	\N	\N	t
44	32	34	\N	\N	t
44	31	35	\N	\N	t
44	30	36	\N	\N	t
44	29	37	\N	\N	t
44	28	38	\N	\N	t
44	27	39	\N	\N	t
44	26	40	\N	\N	t
44	25	41	\N	\N	t
44	24	42	\N	\N	t
44	23	43	\N	\N	t
44	176	44	\N	\N	t
44	22	45	\N	\N	t
44	21	46	\N	\N	t
44	177	47	\N	\N	t
44	20	48	\N	\N	t
44	19	49	\N	\N	t
44	178	50	\N	\N	t
44	82	51	\N	\N	t
44	83	52	\N	\N	t
44	84	53	\N	\N	t
44	85	54	\N	\N	t
44	131	55	\N	\N	t
44	116	56	\N	\N	t
44	139	57	\N	\N	t
44	143	58	\N	\N	t
44	121	59	\N	\N	t
44	123	60	\N	\N	t
44	133	61	\N	\N	t
44	125	62	\N	\N	t
44	128	63	\N	\N	t
44	126	64	\N	\N	t
44	127	65	\N	\N	t
44	130	66	\N	\N	t
44	140	67	\N	\N	t
44	129	68	\N	\N	t
44	137	69	\N	\N	t
44	132	70	\N	\N	t
44	135	71	\N	\N	t
44	134	72	\N	\N	t
44	136	73	\N	\N	t
44	138	74	\N	\N	t
45	46	1	\N	\N	t
45	45	2	\N	\N	t
45	44	3	\N	\N	t
45	43	4	\N	\N	t
45	42	5	\N	\N	t
45	41	6	\N	\N	t
45	40	7	\N	\N	t
45	39	8	\N	\N	t
45	38	9	\N	\N	t
45	37	10	\N	\N	t
45	36	11	\N	\N	t
45	35	12	\N	\N	t
45	34	13	\N	\N	t
45	33	14	\N	\N	t
45	32	15	\N	\N	t
45	31	16	\N	\N	t
45	30	17	\N	\N	t
45	29	18	\N	\N	t
45	28	19	\N	\N	t
45	27	20	\N	\N	t
45	26	21	\N	\N	t
45	25	22	\N	\N	t
45	24	23	\N	\N	t
45	65	24	\N	\N	t
45	64	25	\N	\N	t
45	11	26	\N	\N	t
45	63	27	\N	\N	t
45	62	28	\N	\N	t
45	13	29	\N	\N	t
45	14	30	\N	\N	t
45	15	31	\N	\N	t
45	16	32	\N	\N	t
45	12	33	\N	\N	t
45	61	34	\N	\N	t
45	60	35	\N	\N	t
45	59	36	\N	\N	t
45	58	37	\N	\N	t
45	57	38	\N	\N	t
45	56	39	\N	\N	t
45	55	40	\N	\N	t
45	54	41	\N	\N	t
45	53	42	\N	\N	t
45	52	43	\N	\N	t
45	51	44	\N	\N	t
45	50	45	\N	\N	t
45	49	46	\N	\N	t
45	48	47	\N	\N	t
46	81	1	\N	\N	t
46	80	2	\N	\N	t
46	79	3	\N	\N	t
46	78	4	\N	\N	t
46	77	5	\N	\N	t
46	76	6	\N	\N	t
46	75	7	\N	\N	t
46	74	8	\N	\N	t
46	73	9	\N	\N	t
46	72	10	\N	\N	t
46	5	11	\N	\N	t
46	162	12	\N	\N	t
46	71	13	\N	\N	t
46	8	14	\N	\N	t
46	9	15	\N	\N	t
46	10	16	\N	\N	t
46	70	17	\N	\N	t
46	69	18	\N	\N	t
46	68	19	\N	\N	t
46	67	20	\N	\N	t
46	66	21	\N	\N	t
46	65	22	\N	\N	t
46	64	23	\N	\N	t
46	11	24	\N	\N	t
46	63	25	\N	\N	t
46	62	26	\N	\N	t
46	13	27	\N	\N	t
46	14	28	\N	\N	t
46	15	29	\N	\N	t
46	16	30	\N	\N	t
46	12	31	\N	\N	t
46	61	32	\N	\N	t
46	60	33	\N	\N	t
46	59	34	\N	\N	t
46	58	35	\N	\N	t
46	57	36	\N	\N	t
46	56	37	\N	\N	t
46	55	38	\N	\N	t
46	54	39	\N	\N	t
46	53	40	\N	\N	t
46	52	41	\N	\N	t
46	51	42	\N	\N	t
46	50	43	\N	\N	t
46	49	44	\N	\N	t
46	48	45	\N	\N	t
46	47	46	\N	\N	t
46	46	47	\N	\N	t
46	45	48	\N	\N	t
46	44	49	\N	\N	t
46	43	50	\N	\N	t
46	42	51	\N	\N	t
46	41	52	\N	\N	t
46	40	53	\N	\N	t
46	39	54	\N	\N	t
46	38	55	\N	\N	t
46	37	56	\N	\N	t
46	36	57	\N	\N	t
46	35	58	\N	\N	t
46	34	59	\N	\N	t
46	33	60	\N	\N	t
46	32	61	\N	\N	t
46	31	62	\N	\N	t
46	30	63	\N	\N	t
46	29	64	\N	\N	t
46	28	65	\N	\N	t
46	27	66	\N	\N	t
46	26	67	\N	\N	t
46	25	68	\N	\N	t
46	24	69	\N	\N	t
46	23	70	\N	\N	t
46	176	71	\N	\N	t
46	22	72	\N	\N	t
46	21	73	\N	\N	t
46	177	74	\N	\N	t
46	20	75	\N	\N	t
46	19	76	\N	\N	t
46	178	77	\N	\N	t
46	82	78	\N	\N	t
46	83	79	\N	\N	t
46	84	80	\N	\N	t
46	85	81	\N	\N	t
46	86	82	\N	\N	t
46	87	83	\N	\N	t
46	88	84	\N	\N	t
46	89	85	\N	\N	t
46	90	86	\N	\N	t
46	91	87	\N	\N	t
46	92	88	\N	\N	t
46	93	89	\N	\N	t
46	94	90	\N	\N	t
46	180	91	\N	\N	t
46	148	92	\N	\N	t
46	145	93	\N	\N	t
46	181	94	\N	\N	t
46	182	95	\N	\N	t
47	197	1	\N	\N	t
47	201	2	\N	\N	t
47	207	3	\N	\N	t
47	2	4	\N	\N	t
47	198	5	\N	\N	t
47	1	6	\N	\N	t
47	199	7	\N	\N	t
47	200	8	\N	\N	t
47	221	9	\N	\N	t
47	223	10	\N	\N	t
47	18	11	\N	\N	t
47	222	12	\N	\N	t
47	202	13	\N	\N	t
47	203	14	\N	\N	t
47	204	15	\N	\N	t
47	205	16	\N	\N	t
47	206	17	\N	\N	t
47	208	18	\N	\N	t
47	209	19	\N	\N	t
47	210	20	\N	\N	t
47	211	21	\N	\N	t
47	212	22	\N	\N	t
47	213	23	\N	\N	t
47	214	24	\N	\N	t
47	215	25	\N	\N	t
47	216	26	\N	\N	t
47	225	27	\N	\N	t
47	227	28	\N	\N	t
47	226	29	\N	\N	t
47	229	30	\N	\N	t
47	230	31	\N	\N	t
47	217	32	\N	\N	t
47	173	33	\N	\N	t
47	231	34	\N	\N	t
47	228	35	\N	\N	t
47	218	36	\N	\N	t
47	219	37	\N	\N	t
47	220	38	\N	\N	t
48	232	1	\N	\N	t
48	235	2	\N	\N	t
48	239	3	\N	\N	t
48	243	4	\N	\N	t
48	233	5	\N	\N	t
48	234	6	\N	\N	t
48	236	7	\N	\N	t
48	237	8	\N	\N	t
48	238	9	\N	\N	t
48	240	10	\N	\N	t
48	241	11	\N	\N	t
48	242	12	\N	\N	t
48	244	13	\N	\N	t
48	245	14	\N	\N	t
48	246	15	\N	\N	t
48	247	16	\N	\N	t
48	248	17	\N	\N	t
48	249	18	\N	\N	t
48	250	19	\N	\N	t
48	251	20	\N	\N	t
48	252	21	\N	\N	t
48	253	22	\N	\N	t
48	254	23	\N	\N	t
48	255	24	\N	\N	t
48	256	25	\N	\N	t
48	257	26	\N	\N	t
48	258	27	\N	\N	t
48	259	28	\N	\N	t
48	260	29	\N	\N	t
48	261	30	\N	\N	t
48	262	31	\N	\N	t
48	263	32	\N	\N	t
48	264	33	\N	\N	t
48	274	34	\N	\N	t
48	276	35	\N	\N	t
48	277	36	\N	\N	t
48	265	37	\N	\N	t
48	266	38	\N	\N	t
48	267	39	\N	\N	t
48	268	40	\N	\N	t
48	269	41	\N	\N	t
48	270	42	\N	\N	t
48	271	43	\N	\N	t
48	272	44	\N	\N	t
48	273	45	\N	\N	t
48	285	46	\N	\N	t
48	275	47	\N	\N	t
48	278	48	\N	\N	t
48	279	49	\N	\N	t
48	280	50	\N	\N	t
48	281	51	\N	\N	t
48	282	52	\N	\N	t
48	283	53	\N	\N	t
48	284	54	\N	\N	t
48	286	55	\N	\N	t
48	287	56	\N	\N	t
48	288	57	\N	\N	t
48	289	58	\N	\N	t
48	290	59	\N	\N	t
48	291	60	\N	\N	t
48	292	61	\N	\N	t
48	293	62	\N	\N	t
48	216	63	\N	\N	t
48	225	64	\N	\N	t
48	227	65	\N	\N	t
48	226	66	\N	\N	t
48	229	67	\N	\N	t
48	230	68	\N	\N	t
48	217	69	\N	\N	t
48	173	70	\N	\N	t
48	231	71	\N	\N	t
48	228	72	\N	\N	t
48	218	73	\N	\N	t
48	219	74	\N	\N	t
48	220	75	\N	\N	t
49	294	1	\N	\N	t
49	296	2	\N	\N	t
49	300	3	\N	\N	t
49	302	4	\N	\N	t
49	301	5	\N	\N	t
49	299	6	\N	\N	t
49	304	7	\N	\N	t
49	298	8	\N	\N	t
49	297	9	\N	\N	t
49	303	10	\N	\N	t
49	295	11	\N	\N	t
49	305	12	\N	\N	t
49	306	13	\N	\N	t
49	307	14	\N	\N	t
49	308	15	\N	\N	t
49	309	16	\N	\N	t
49	310	17	\N	\N	t
49	311	18	\N	\N	t
49	312	19	\N	\N	t
49	313	20	\N	\N	t
49	314	21	\N	\N	t
49	315	22	\N	\N	t
49	316	23	\N	\N	t
49	317	24	\N	\N	t
50	232	1	\N	\N	t
50	235	2	\N	\N	t
50	239	3	\N	\N	t
50	243	4	\N	\N	t
50	233	5	\N	\N	t
50	234	6	\N	\N	t
50	236	7	\N	\N	t
50	237	8	\N	\N	t
50	238	9	\N	\N	t
50	240	10	\N	\N	t
50	241	11	\N	\N	t
50	242	12	\N	\N	t
50	244	13	\N	\N	t
50	245	14	\N	\N	t
50	246	15	\N	\N	t
50	247	16	\N	\N	t
50	248	17	\N	\N	t
50	249	18	\N	\N	t
50	250	19	\N	\N	t
50	251	20	\N	\N	t
50	252	21	\N	\N	t
50	253	22	\N	\N	t
50	254	23	\N	\N	t
50	255	24	\N	\N	t
50	256	25	\N	\N	t
50	257	26	\N	\N	t
50	258	27	\N	\N	t
50	259	28	\N	\N	t
50	260	29	\N	\N	t
50	261	30	\N	\N	t
50	262	31	\N	\N	t
50	263	32	\N	\N	t
50	264	33	\N	\N	t
50	274	34	\N	\N	t
50	276	35	\N	\N	t
50	277	36	\N	\N	t
50	265	37	\N	\N	t
50	266	38	\N	\N	t
50	267	39	\N	\N	t
50	268	40	\N	\N	t
50	269	41	\N	\N	t
50	270	42	\N	\N	t
50	271	43	\N	\N	t
50	272	44	\N	\N	t
51	232	1	\N	\N	t
51	235	2	\N	\N	t
51	239	3	\N	\N	t
51	243	4	\N	\N	t
51	233	5	\N	\N	t
51	234	6	\N	\N	t
51	236	7	\N	\N	t
51	237	8	\N	\N	t
51	238	9	\N	\N	t
51	240	10	\N	\N	t
51	241	11	\N	\N	t
51	242	12	\N	\N	t
51	244	13	\N	\N	t
51	245	14	\N	\N	t
51	246	15	\N	\N	t
51	247	16	\N	\N	t
51	248	17	\N	\N	t
51	249	18	\N	\N	t
51	250	19	\N	\N	t
51	251	20	\N	\N	t
51	252	21	\N	\N	t
51	253	22	\N	\N	t
51	254	23	\N	\N	t
51	255	24	\N	\N	t
51	256	25	\N	\N	t
51	257	26	\N	\N	t
51	258	27	\N	\N	t
51	259	28	\N	\N	t
51	260	29	\N	\N	t
51	261	30	\N	\N	t
51	262	31	\N	\N	t
51	263	32	\N	\N	t
51	264	33	\N	\N	t
51	274	34	\N	\N	t
51	276	35	\N	\N	t
51	277	36	\N	\N	t
51	265	37	\N	\N	t
51	266	38	\N	\N	t
51	267	39	\N	\N	t
51	268	40	\N	\N	t
51	269	41	\N	\N	t
51	270	42	\N	\N	t
51	271	43	\N	\N	t
51	272	44	\N	\N	t
51	273	45	\N	\N	t
51	285	46	\N	\N	t
51	275	47	\N	\N	t
51	278	48	\N	\N	t
51	279	49	\N	\N	t
51	280	50	\N	\N	t
51	281	51	\N	\N	t
51	282	52	\N	\N	t
51	283	53	\N	\N	t
51	284	54	\N	\N	t
51	286	55	\N	\N	t
51	287	56	\N	\N	t
51	288	57	\N	\N	t
51	289	58	\N	\N	t
51	290	59	\N	\N	t
51	291	60	\N	\N	t
51	292	61	\N	\N	t
51	293	62	\N	\N	t
51	216	63	\N	\N	t
51	227	64	\N	\N	t
51	229	65	\N	\N	t
51	230	66	\N	\N	t
51	231	67	\N	\N	t
51	228	68	\N	\N	t
51	218	69	\N	\N	t
51	219	70	\N	\N	t
51	220	71	\N	\N	t
51	318	72	\N	\N	t
52	232	1	\N	\N	t
52	235	2	\N	\N	t
52	239	3	\N	\N	t
52	243	4	\N	\N	t
52	233	5	\N	\N	t
52	234	6	\N	\N	t
52	236	7	\N	\N	t
52	237	8	\N	\N	t
52	238	9	\N	\N	t
52	240	10	\N	\N	t
52	241	11	\N	\N	t
52	242	12	\N	\N	t
52	244	13	\N	\N	t
52	245	14	\N	\N	t
52	246	15	\N	\N	t
52	247	16	\N	\N	t
52	248	17	\N	\N	t
52	249	18	\N	\N	t
52	250	19	\N	\N	t
52	251	20	\N	\N	t
52	252	21	\N	\N	t
52	253	22	\N	\N	t
52	254	23	\N	\N	t
52	255	24	\N	\N	t
52	256	25	\N	\N	t
52	257	26	\N	\N	t
52	258	27	\N	\N	t
52	259	28	\N	\N	t
52	260	29	\N	\N	t
52	261	30	\N	\N	t
52	262	31	\N	\N	t
52	263	32	\N	\N	t
52	264	33	\N	\N	t
52	274	34	\N	\N	t
52	276	35	\N	\N	t
52	277	36	\N	\N	t
52	265	37	\N	\N	t
52	266	38	\N	\N	t
52	267	39	\N	\N	t
52	268	40	\N	\N	t
52	269	41	\N	\N	t
52	270	42	\N	\N	t
52	271	43	\N	\N	t
52	272	44	\N	\N	t
52	273	45	\N	\N	t
52	285	46	\N	\N	t
52	275	47	\N	\N	t
52	278	48	\N	\N	t
52	279	49	\N	\N	t
52	280	50	\N	\N	t
52	281	51	\N	\N	t
52	282	52	\N	\N	t
52	283	53	\N	\N	t
52	284	54	\N	\N	t
52	286	55	\N	\N	t
52	287	56	\N	\N	t
52	288	57	\N	\N	t
52	289	58	\N	\N	t
52	290	59	\N	\N	t
52	291	60	\N	\N	t
52	292	61	\N	\N	t
52	293	62	\N	\N	t
52	216	63	\N	\N	t
52	227	64	\N	\N	t
52	229	65	\N	\N	t
52	230	66	\N	\N	t
52	231	67	\N	\N	t
52	228	68	\N	\N	t
52	218	69	\N	\N	t
52	219	70	\N	\N	t
52	220	71	\N	\N	t
52	319	72	\N	\N	t
52	320	73	\N	\N	t
52	321	74	\N	\N	t
53	347	1	\N	\N	t
53	348	2	\N	\N	t
53	179	3	\N	\N	t
53	342	4	\N	\N	t
53	322	5	\N	\N	t
53	343	6	\N	\N	t
53	345	7	\N	\N	t
53	324	8	\N	\N	t
53	346	9	\N	\N	t
53	331	10	\N	\N	t
53	339	11	\N	\N	t
53	335	12	\N	\N	t
53	338	13	\N	\N	t
53	323	14	\N	\N	t
53	337	15	\N	\N	t
53	325	16	\N	\N	t
53	326	17	\N	\N	t
53	327	18	\N	\N	t
53	328	19	\N	\N	t
53	329	20	\N	\N	t
53	330	21	\N	\N	t
53	332	22	\N	\N	t
53	333	23	\N	\N	t
53	334	24	\N	\N	t
53	336	25	\N	\N	t
53	30	26	\N	\N	t
53	29	27	\N	\N	t
53	28	28	\N	\N	t
53	27	29	\N	\N	t
53	26	30	\N	\N	t
53	25	31	\N	\N	t
53	24	32	\N	\N	t
53	23	33	\N	\N	t
53	176	34	\N	\N	t
53	22	35	\N	\N	t
53	21	36	\N	\N	t
53	177	37	\N	\N	t
53	20	38	\N	\N	t
53	351	39	\N	\N	t
53	19	40	\N	\N	t
53	178	41	\N	\N	t
53	82	42	\N	\N	t
53	83	43	\N	\N	t
53	84	44	\N	\N	t
53	85	45	\N	\N	t
53	87	46	\N	\N	t
53	88	47	\N	\N	t
53	89	48	\N	\N	t
53	350	49	\N	\N	t
53	90	50	\N	\N	t
53	91	51	\N	\N	t
53	92	52	\N	\N	t
53	349	53	\N	\N	t
53	93	54	\N	\N	t
53	94	55	\N	\N	t
53	95	56	\N	\N	t
54	358	1	\N	\N	t
54	361	2	\N	\N	t
54	359	3	\N	\N	t
54	360	4	\N	\N	t
54	362	5	\N	\N	t
54	363	6	\N	\N	t
54	364	7	\N	\N	t
54	365	8	\N	\N	t
54	366	9	\N	\N	t
54	367	10	\N	\N	t
54	368	11	\N	\N	t
54	369	12	\N	\N	t
54	370	13	\N	\N	t
54	371	14	\N	\N	t
54	372	15	\N	\N	t
54	373	16	\N	\N	t
54	374	17	\N	\N	t
54	375	18	\N	\N	t
54	376	19	\N	\N	t
54	377	20	\N	\N	t
54	378	21	\N	\N	t
54	379	22	\N	\N	t
54	380	23	\N	\N	t
54	381	24	\N	\N	t
54	382	25	\N	\N	t
54	309	26	\N	\N	t
54	310	27	\N	\N	t
54	311	28	\N	\N	t
54	312	29	\N	\N	t
54	313	30	\N	\N	t
54	314	31	\N	\N	t
54	315	32	\N	\N	t
54	316	33	\N	\N	t
54	317	34	\N	\N	t
54	383	35	\N	\N	t
54	384	36	\N	\N	t
54	388	37	\N	\N	t
54	389	38	\N	\N	t
54	390	39	\N	\N	t
54	391	40	\N	\N	t
54	385	41	\N	\N	t
54	386	42	\N	\N	t
54	105	43	\N	\N	t
54	106	44	\N	\N	t
54	107	45	\N	\N	t
55	322	1	\N	\N	t
55	343	2	\N	\N	t
55	345	3	\N	\N	t
55	324	4	\N	\N	t
55	346	5	\N	\N	t
55	331	6	\N	\N	t
55	339	7	\N	\N	t
55	335	8	\N	\N	t
55	338	9	\N	\N	t
55	323	10	\N	\N	t
55	337	11	\N	\N	t
55	325	12	\N	\N	t
55	326	13	\N	\N	t
55	327	14	\N	\N	t
55	328	15	\N	\N	t
55	329	16	\N	\N	t
55	330	17	\N	\N	t
55	332	18	\N	\N	t
55	333	19	\N	\N	t
55	334	20	\N	\N	t
55	336	21	\N	\N	t
55	30	22	\N	\N	t
55	29	23	\N	\N	t
55	28	24	\N	\N	t
55	27	25	\N	\N	t
55	26	26	\N	\N	t
55	25	27	\N	\N	t
55	24	28	\N	\N	t
55	23	29	\N	\N	t
55	176	30	\N	\N	t
55	22	31	\N	\N	t
55	21	32	\N	\N	t
55	177	33	\N	\N	t
55	20	34	\N	\N	t
55	351	35	\N	\N	t
55	19	36	\N	\N	t
55	178	37	\N	\N	t
55	82	38	\N	\N	t
55	83	39	\N	\N	t
55	84	40	\N	\N	t
55	85	41	\N	\N	t
55	87	42	\N	\N	t
55	88	43	\N	\N	t
55	89	44	\N	\N	t
55	350	45	\N	\N	t
55	90	46	\N	\N	t
55	91	47	\N	\N	t
55	92	48	\N	\N	t
55	349	49	\N	\N	t
55	93	50	\N	\N	t
55	94	51	\N	\N	t
55	95	52	\N	\N	t
55	96	53	\N	\N	t
55	98	54	\N	\N	t
55	99	55	\N	\N	t
56	84	1	\N	\N	t
56	85	2	\N	\N	t
56	87	3	\N	\N	t
56	88	4	\N	\N	t
56	89	5	\N	\N	t
56	350	6	\N	\N	t
56	90	7	\N	\N	t
56	91	8	\N	\N	t
56	92	9	\N	\N	t
56	349	10	\N	\N	t
56	93	11	\N	\N	t
56	94	12	\N	\N	t
56	95	13	\N	\N	t
56	96	14	\N	\N	t
56	354	15	\N	\N	t
56	355	16	\N	\N	t
56	356	17	\N	\N	t
56	357	18	\N	\N	t
56	74	19	\N	\N	t
56	73	20	\N	\N	t
56	72	21	\N	\N	t
56	5	22	\N	\N	t
56	162	23	\N	\N	t
56	71	24	\N	\N	t
56	8	25	\N	\N	t
56	9	26	\N	\N	t
56	10	27	\N	\N	t
56	70	28	\N	\N	t
56	69	29	\N	\N	t
56	67	30	\N	\N	t
56	65	31	\N	\N	t
56	64	32	\N	\N	t
56	11	33	\N	\N	t
56	63	34	\N	\N	t
56	62	35	\N	\N	t
56	13	36	\N	\N	t
56	14	37	\N	\N	t
56	15	38	\N	\N	t
57	70	1	\N	\N	t
57	69	2	\N	\N	t
57	67	3	\N	\N	t
57	65	4	\N	\N	t
57	64	5	\N	\N	t
57	11	6	\N	\N	t
57	63	7	\N	\N	t
57	62	8	\N	\N	t
57	13	9	\N	\N	t
57	14	10	\N	\N	t
57	15	11	\N	\N	t
57	16	12	\N	\N	t
57	12	13	\N	\N	t
57	61	14	\N	\N	t
57	60	15	\N	\N	t
57	59	16	\N	\N	t
57	58	17	\N	\N	t
57	57	18	\N	\N	t
57	56	19	\N	\N	t
57	55	20	\N	\N	t
57	54	21	\N	\N	t
57	53	22	\N	\N	t
57	52	23	\N	\N	t
57	51	24	\N	\N	t
57	50	25	\N	\N	t
57	49	26	\N	\N	t
57	48	27	\N	\N	t
57	47	28	\N	\N	t
58	328	1	\N	\N	t
58	329	2	\N	\N	t
58	330	3	\N	\N	t
58	332	4	\N	\N	t
58	333	5	\N	\N	t
58	334	6	\N	\N	t
58	336	7	\N	\N	t
58	24	8	\N	\N	t
58	65	9	\N	\N	t
58	64	10	\N	\N	t
58	11	11	\N	\N	t
58	63	12	\N	\N	t
58	62	13	\N	\N	t
58	13	14	\N	\N	t
58	14	15	\N	\N	t
58	15	16	\N	\N	t
58	16	17	\N	\N	t
58	12	18	\N	\N	t
58	61	19	\N	\N	t
58	60	20	\N	\N	t
59	393	1	\N	\N	t
59	394	2	\N	\N	t
59	392	3	\N	\N	t
59	232	4	\N	\N	t
59	235	5	\N	\N	t
59	239	6	\N	\N	t
59	243	7	\N	\N	t
59	233	8	\N	\N	t
59	234	9	\N	\N	t
59	236	10	\N	\N	t
59	237	11	\N	\N	t
59	238	12	\N	\N	t
59	240	13	\N	\N	t
59	241	14	\N	\N	t
59	242	15	\N	\N	t
59	244	16	\N	\N	t
59	245	17	\N	\N	t
59	246	18	\N	\N	t
59	247	19	\N	\N	t
59	248	20	\N	\N	t
59	249	21	\N	\N	t
59	250	22	\N	\N	t
59	251	23	\N	\N	t
59	252	24	\N	\N	t
59	253	25	\N	\N	t
59	254	26	\N	\N	t
59	255	27	\N	\N	t
59	256	28	\N	\N	t
59	257	29	\N	\N	t
59	258	30	\N	\N	t
59	259	31	\N	\N	t
59	260	32	\N	\N	t
59	261	33	\N	\N	t
59	262	34	\N	\N	t
59	263	35	\N	\N	t
59	264	36	\N	\N	t
59	274	37	\N	\N	t
59	276	38	\N	\N	t
59	277	39	\N	\N	t
59	265	40	\N	\N	t
59	266	41	\N	\N	t
59	267	42	\N	\N	t
59	268	43	\N	\N	t
59	269	44	\N	\N	t
59	270	45	\N	\N	t
59	271	46	\N	\N	t
59	272	47	\N	\N	t
59	273	48	\N	\N	t
59	285	49	\N	\N	t
59	275	50	\N	\N	t
59	278	51	\N	\N	t
59	279	52	\N	\N	t
59	280	53	\N	\N	t
59	281	54	\N	\N	t
59	282	55	\N	\N	t
59	283	56	\N	\N	t
59	284	57	\N	\N	t
59	286	58	\N	\N	t
59	287	59	\N	\N	t
59	288	60	\N	\N	t
59	289	61	\N	\N	t
59	290	62	\N	\N	t
59	291	63	\N	\N	t
59	292	64	\N	\N	t
59	293	65	\N	\N	t
59	216	66	\N	\N	t
59	227	67	\N	\N	t
59	229	68	\N	\N	t
59	230	69	\N	\N	t
60	88	1	\N	\N	t
60	89	2	\N	\N	t
60	72	3	\N	\N	t
60	5	4	\N	\N	t
60	162	5	\N	\N	t
60	71	6	\N	\N	t
60	8	7	\N	\N	t
60	9	8	\N	\N	t
60	10	9	\N	\N	t
60	70	10	\N	\N	t
60	69	11	\N	\N	t
60	127	12	\N	\N	t
60	130	13	\N	\N	t
60	140	14	\N	\N	t
60	129	15	\N	\N	t
60	137	16	\N	\N	t
60	232	17	\N	\N	t
60	235	18	\N	\N	t
60	239	19	\N	\N	t
60	243	20	\N	\N	t
60	233	21	\N	\N	t
60	234	22	\N	\N	t
60	236	23	\N	\N	t
60	237	24	\N	\N	t
60	238	25	\N	\N	t
60	240	26	\N	\N	t
60	241	27	\N	\N	t
60	242	28	\N	\N	t
60	244	29	\N	\N	t
60	245	30	\N	\N	t
60	246	31	\N	\N	t
60	247	32	\N	\N	t
60	248	33	\N	\N	t
60	249	34	\N	\N	t
60	250	35	\N	\N	t
60	251	36	\N	\N	t
60	252	37	\N	\N	t
60	253	38	\N	\N	t
60	254	39	\N	\N	t
60	255	40	\N	\N	t
60	256	41	\N	\N	t
60	257	42	\N	\N	t
60	258	43	\N	\N	t
60	259	44	\N	\N	t
60	260	45	\N	\N	t
60	261	46	\N	\N	t
60	262	47	\N	\N	t
60	263	48	\N	\N	t
60	264	49	\N	\N	t
60	274	50	\N	\N	t
60	276	51	\N	\N	t
60	277	52	\N	\N	t
60	265	53	\N	\N	t
60	266	54	\N	\N	t
60	267	55	\N	\N	t
60	268	56	\N	\N	t
60	269	57	\N	\N	t
60	270	58	\N	\N	t
60	271	59	\N	\N	t
60	272	60	\N	\N	t
60	273	61	\N	\N	t
60	285	62	\N	\N	t
60	275	63	\N	\N	t
60	278	64	\N	\N	t
60	279	65	\N	\N	t
60	280	66	\N	\N	t
60	281	67	\N	\N	t
60	282	68	\N	\N	t
60	283	69	\N	\N	t
60	284	70	\N	\N	t
60	286	71	\N	\N	t
60	287	72	\N	\N	t
60	288	73	\N	\N	t
60	289	74	\N	\N	t
60	290	75	\N	\N	t
60	291	76	\N	\N	t
60	292	77	\N	\N	t
60	293	78	\N	\N	t
60	216	79	\N	\N	t
60	227	80	\N	\N	t
60	229	81	\N	\N	t
60	230	82	\N	\N	t
60	231	83	\N	\N	t
60	228	84	\N	\N	t
60	218	85	\N	\N	t
60	219	86	\N	\N	t
61	433	1	\N	\N	t
61	434	2	\N	\N	t
61	326	3	\N	\N	t
61	435	4	\N	\N	t
62	363	1	\N	\N	t
62	364	2	\N	\N	t
62	365	3	\N	\N	t
62	366	4	\N	\N	t
62	367	5	\N	\N	t
62	368	6	\N	\N	t
62	369	7	\N	\N	t
62	370	8	\N	\N	t
62	371	9	\N	\N	t
62	372	10	\N	\N	t
62	373	11	\N	\N	t
62	374	12	\N	\N	t
62	375	13	\N	\N	t
62	376	14	\N	\N	t
62	377	15	\N	\N	t
62	378	16	\N	\N	t
62	379	17	\N	\N	t
62	380	18	\N	\N	t
62	381	19	\N	\N	t
62	382	20	\N	\N	t
62	309	21	\N	\N	t
62	310	22	\N	\N	t
62	311	23	\N	\N	t
62	312	24	\N	\N	t
62	313	25	\N	\N	t
62	314	26	\N	\N	t
62	315	27	\N	\N	t
62	316	28	\N	\N	t
62	317	29	\N	\N	t
62	383	30	\N	\N	t
63	418	1	\N	\N	t
63	122	2	\N	\N	t
63	120	3	\N	\N	t
63	142	4	\N	\N	t
63	118	5	\N	\N	t
63	421	6	\N	\N	t
63	117	7	\N	\N	t
63	141	8	\N	\N	t
63	131	9	\N	\N	t
63	116	10	\N	\N	t
63	139	11	\N	\N	t
63	143	12	\N	\N	t
63	121	13	\N	\N	t
63	123	14	\N	\N	t
63	133	15	\N	\N	t
63	125	16	\N	\N	t
63	130	17	\N	\N	t
\.


--
-- Data for Name: tab_routes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_routes (id_route, name_route, path_route, descrip_route, color_route, id_company, first_trip, last_trip, departure_route_sign, return_route_sign, is_active, created_at, updated_at, user_create, user_update, route_fare, is_circular) FROM stdin;
33	ruta nuevo metodo hola	0102000020E61000001C000000F17EDC7EF94752C0AEEFC34142841C40F7216FB9FA4752C053245F09A4841C40EA5910CAFB4752C0F17EDC7EF9841C40253E7782FD4752C04014CC9882851C40A245B6F3FD4752C0BD8C62B9A5851C4030B8E68EFE4752C05116BEBED6851C40DE91B1DAFC4752C02EC55565DF851C40B5183C4CFB4752C0C2F7FE06ED851C406E861BF0F94752C00CAEB9A3FF851C4087FC3383F84752C07EACE0B721861C402EE57CB1F74752C0A52E19C748861C40E61E12BEF74752C033FB3C4679861C40939048DBF84752C09F5912A0A6861C4009A7052FFA4752C0BB44F5D6C0861C400873BB97FB4752C0821C9430D3861C406D1E87C1FC4752C06688635DDC861C40FB5C6DC5FE4752C0D74CBED9E6861C40F437A110014852C0546EA296E6861C40D50451F7014852C0546EA296E6861C40056F48A3024852C0271763601D871C40E17EC003034852C0F98557923C871C40213A048E044852C05EF23FF9BB871C409E279EB3054852C0E675C4211B881C403EEB1A2D074852C00249D8B793881C405BD07B63084852C0C32E8A1EF8881C402B1895D4094852C03F726BD26D891C4030BB270F0B4852C0051555BFD2891C401288D7F50B4852C03E25E7C41E8A1C40	\N	#667EEA	1	\N	\N	\N	\N	f	2026-04-19 01:48:07.285433-05	2026-04-19 16:54:51.120098-05	1	1	0	t
38	ruta L	0102000020E6100000170000001FF64201DB4752C04F3E3DB665801C40388600E0D84752C0C1FD800706801C405C76887FD84752C0897E6DFDF47F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C402B6D718DCF4752C0075F984C157C1C4012F758FAD04752C0AC8E1CE90C7C1C4095D5743DD14752C01E537765177C1C409A5E622CD34752C0D94125AE637C1C40	\N	#667EEA	1	\N	\N	\N	\N	t	2026-04-19 18:52:06.014044-05	\N	1	\N	0	f
39	ruta21	0102000020E61000002B000000EA5910CAFB4752C06FA0C03BF9841C40253E7782FD4752C04014CC9882851C40A245B6F3FD4752C0BD8C62B9A5851C40070B2769FE4752C0C85D8429CA851C4019761893FE4752C0D9B11188D7851C40C64FE3DEFC4752C034828DEBDF851C409DD66D50FB4752C04B9352D0ED851C403F027FF8F94752C0126BF12900861C40575EF23FF94752C0AB5AD2510E861C40939048DBF84752C012A5BDC117861C4087FC3383F84752C07EACE0B721861C40813FFCFCF74752C0613596B036861C4058923CD7F74752C056D80C7041861C402EE57CB1F74752C0CD599F724C861C40A52F849CF74752C03F3BE0BA62861C40B79A75C6F74752C0B01C210379861C40DA70581AF84752C0882B67EF8C861C40E02D90A0F84752C055C03DCF9F861C40F855B950F94752C093FC885FB1861C4021E9D32AFA4752C03E23111AC1861C403811FDDAFA4752C0274C18CDCA861C400873BB97FB4752C0821C9430D3861C40856055BDFC4752C0EE23B726DD861C405A7F4B00FE4752C03E7AC37DE4861C40E9D7D64FFF4752C0E883656CE8861C4047ACC5A7004852C0F4FDD478E9861C407CED9925014852C06B6281AFE8861C40BDC282FB014852C05A2BDA1CE7861C40B7EBA529024852C0F9D7F2CAF5861C40E17EC003034852C0F98557923C871C40213A048E044852C05EF23FF9BB871C4086E5CFB7054852C0E675C4211B881C403EEB1A2D074852C00249D8B793881C405BD07B63084852C0C32E8A1EF8881C402B1895D4094852C03F726BD26D891C4030BB270F0B4852C0051555BFD2891C40FA4509FA0B4852C03E25E7C41E8A1C404D86E3F90C4852C0CB48BDA7728A1C4082AD122C0E4852C081B4FF01D68A1C4022718FA50F4852C02AE09EE74F8B1C403F56F0DB104852C0F18288D4B48B1C40A301BC05124852C0075F984C158C1C4008C72C7B124852C0292499D53B8C1C40	\N	#A6FF00	1	\N	\N	\N	\N	t	2026-04-19 20:20:51.578425-05	\N	1	\N	0	f
35	cr22 nueva	0102000020E61000002E000000F44E05DCF34752C0AA9ECC3FFA861C40AEBCE47FF24752C066BD18CA89861C4097AE601BF14752C0F5F3A62215861C402C2CB81FF04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C4050508A56EE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C4094DBF63DEA4752C05471E316F3831C40D027F224E94752C07CB4386398831C40D732198EE74752C078B81D1A16831C40D28F8653E64752C0B115342DB1821C4091D442C9E44752C05723BBD232821C408C31B08EE34752C03067B62BF4811C4004CAA65CE14752C0F2423A3C84811C40CFBC1C76DF4752C053E8BCC62E811C4012143FC6DC4752C0AF795567B5801C40373811FDDA4752C04F3E3DB665801C4073B8567BD84752C0897E6DFDF47F1C4074D2FBC6D74752C0C289E8D7D67F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C406ADAC534D34752C007793D98147F1C40A0353FFED24752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C4001DA56B3CE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C4075E95F92CA4752C0210725CCB47D1C4005C4245CC84752C010E84CDA547D1C40EECF4543C64752C0B08F4E5DF97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C00708E6E8F17B1C40EC3026FDBD4752C02A711DE38A7B1C402E54FEB5BC4752C05E85949F547B1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C405C1FD61BB54752C03E42CD902A7A1C4068E7340BB44752C016C09481037A1C4011381268B04752C01781B1BE81791C40787FBC57AD4752C0F05014E813791C404A97FE25A94752C01920D1048A781C408F56B5A4A34752C0F8FE06EDD5771C40DD41EC4CA14752C0DC82A5BA80771C40C042E6CAA04752C015AB06616E771C40F01472A59E4752C06BF3FFAA23771C40	\N	#667EEA	1	\N	\N	\N	\N	f	2026-04-19 02:11:12.813633-05	2026-04-25 12:18:18.243167-05	1	1	0	t
41	ruta24	0102000020E61000001100000071E5EC9DD14752C01958C7F143851C407D93A641D14752C0D5415E0F26851C40C58D5BCCCF4752C0B96E4A79AD841C40DDE9CE13CF4752C037FFAF3A72841C40724D81CCCE4752C03D821B295B841C40C0EAC891CE4752C0F888981249841C40DE03745FCE4752C0CB83F41439841C40FC1C1F2DCE4752C09204E10A28841C40C0046EDDCD4752C00A2FC1A90F841C404A0856D5CB4752C0A56B26DF6C831C403F74417DCB4752C0EFAD484C50831C401CEC4D0CC94752C084D6C39789821C40F92F1004C84752C06E5166834C821C40E2218C9FC64752C0630CACE3F8811C403CA1D79FC44752C0E10B93A982811C40B40584D6C34752C0647616BD53811C40E4A3C519C34752C081B3942C27811C40	\N	#3C3F86	1	\N	\N	\N	\N	t	2026-04-19 22:42:51.764033-05	\N	1	\N	0	f
37	ruta11	0102000020E61000001F000000C45F9335EA4752C0FF1F274C188D1C40293FA9F6E94752C09F758D96038D1C40838AAA5FE94752C09487855AD38C1C40E2AC889AE84752C07288B839958C1C40AD6BB41CE84752C0B13385CE6B8C1C4048A643A7E74752C08F6E8445458C1C40C5C72764E74752C03A3E5A9C318C1C4048C0E8F2E64752C02F6D382C0D8C1C4090A0F831E64752C09BC6F65AD08B1C40E4486760E44752C0DAE55B1FD68B1C40A643A7E7DD4752C0B2F4A10BEA8B1C40BB7EC16ED84752C0EB73B515FB8B1C40A4703D0AD74752C0185C7347FF8B1C400A6AF816D64752C0B7EBA529028C1C404CC11A67D34752C012BC218D0A8C1C40836A8313D14752C0DF3312A1118C1C4075E95F92CA4752C0B742588D258C1C407BC03C64CA4752C0BDFF8F13268C1C40DDB243FCC34752C01230BABC398C1C4075CC79C6BE4752C03F355EBA498C1C40DBF97E6ABC4752C00CAD4ECE508C1C4083161230BA4752C05646239F578C1C4036AD1402B94752C07E71A94A5B8C1C40EBABAB02B54752C07E8E8F16678C1C40397D3D5FB34752C0016DAB59678C1C403AB187F6B14752C0016DAB59678C1C4072DC291DAC4752C0F5F23B4D668C1C40E753C72AA54752C0679AB0FD648C1C401F317A6EA14752C061DD7877648C1C40B8E68EFE974752C050A6D1E4628C1C40C6302768934752C0C80A7E1B628C1C40	\N	#C1F20D	1	\N	\N	\N	\N	f	2026-04-19 12:01:07.688554-05	2026-04-19 16:49:20.947305-05	1	1	0	t
34	ruta22	0102000020E610000013000000BF44BC75FE4752C03DB665C0598A1C40FCAA5CA8FC4752C088D68A36C7891C40D9EE1EA0FB4752C0834E081D74891C409EF0129CFA4752C09A779CA223891C4009C1AA7AF94752C0BDFDB968C8881C4010CCD1E3F74752C03BE0BA6246881C40BD715298F74752C0B30A9B012E881C40658EE55DF54752C07638BA4A77871C406B65C22FF54752C0D1CE691668871C40A0C03BF9F44752C0984F560C57871C40F44E05DCF34752C0AA9ECC3FFA861C40AEBCE47FF24752C066BD18CA89861C4097AE601BF14752C0F5F3A62215861C402C2CB81FF04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C4050508A56EE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C40	\N	#667EEA	1	\N	\N	\N	\N	f	2026-04-19 01:56:44.202767-05	2026-04-19 16:46:24.938054-05	1	1	3000	t
42	ruta con OSM	0102000020E610000051000000BC9179E40F4852C033A5F5B704901C40228B34F10E4852C0D369DD06B58F1C405ED72FD80D4852C06D54A703598F1C40355EBA490C4852C0639B5434D68E1C40B39943520B4852C07AC4E8B9858E1C4019ADA3AA094852C01AF8510DFB8D1C405BD07B63084852C01536035C908D1C40143E5B07074852C0C11DA8531E8D1C40A3CA30EE064852C0664D2CF0158D1C40BB26A435064852C0DE205A2BDA8C1C403F53AF5B044852C0514F1F813F8C1C403AB01C21034852C073B8567BD88B1C408E3EE603024852C0F7AE415F7A8B1C40F437A110014852C036035C902D8B1C40309E4143FF4752C0153944DC9C8A1C40BF44BC75FE4752C03DB665C0598A1C405A7F4B00FE4752C0276BD443348A1C40FCAA5CA8FC4752C088D68A36C7891C40D9EE1EA0FB4752C0834E081D74891C409EF0129CFA4752C09A779CA223891C40F17EDC7EF94752C0BDFDB968C8881C4010CCD1E3F74752C03BE0BA6246881C40BD715298F74752C0B30A9B012E881C4047753A90F54752C01AA20A7F86871C40658EE55DF54752C07638BA4A77871C406B65C22FF54752C0D1CE691668871C40A0C03BF9F44752C0984F560C57871C40A69718CBF44752C0ED28CE5147871C40F44E05DCF34752C0AA9ECC3FFA861C40AEBCE47FF24752C066BD18CA89861C4097AE601BF14752C0F5F3A62215861C40DE8E705AF04752C040DF162CD5851C406D1B4641F04752C06DAAEE91CD851C4014EAE923F04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C40FDC1C073EF4752C035B742588D851C40390EBC5AEE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C4094DBF63DEA4752C05471E316F3831C40D027F224E94752C07CB4386398831C40D732198EE74752C078B81D1A16831C40D28F8653E64752C0B115342DB1821C4091D442C9E44752C05723BBD232821C408C31B08EE34752C03067B62BF4811C40EC87D860E14752C0F2423A3C84811C40B77A4E7ADF4752C053E8BCC62E811C4012143FC6DC4752C0AF795567B5801C401FF64201DB4752C04F3E3DB665801C40388600E0D84752C0C1FD800706801C405C76887FD84752C0897E6DFDF47F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C08AE6012CF27B1C40D4EE5701BE4752C02A711DE38A7B1C40171230BABC4752C05E85949F547B1C40A7069ACFB94752C02BBEA1F0D97A1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C40C539EAE8B84752C0A3CB9BC3B57A1C405C1FD61BB54752C0C020E9D32A7A1C4068E7340BB44752C016C09481037A1C400B613596B04752C05B5D4E0988791C4011381268B04752C01781B1BE81791C40603DEE5BAD4752C0F05014E813791C4062D9CC21A94752C01920D1048A781C40	\N	#F7963B	1	\N	\N	\N	\N	t	2026-04-19 23:51:49.887157-05	\N	1	\N	0	f
36	ruta Z	0102000020E61000001800000030134548DD4752C0D9226937FA881C40B325AB22DC4752C0EB71DF6A9D881C40780DFAD2DB4752C0CF86FC3383881C405B28999CDA4752C01FD8F15F20881C4008E8BE9CD94752C0360186E5CF871C4026016A6AD94752C009FCE1E7BF871C40DF6E490ED84752C04EB6813B50871C4098DC28B2D64752C09EEA909BE1861C4010751F80D44752C08F006E162F861C40F37519FED34752C04510E7E104861C40D576137CD34752C012143FC6DC851C4095D5743DD14752C0D5415E0F26851C40724D81CCCE4752C03D821B295B841C40064CE0D6DD4752C02524D236FE841C401D5A643BDF4752C0CA8D226B0D851C40F1475167EE4752C046459C4EB2851C402C2CB81FF04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C4050508A56EE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C4094DBF63DEA4752C05471E316F3831C40D027F224E94752C07CB4386398831C40	hola	#667EEA	1	\N	\N	\N	\N	t	2026-04-19 10:55:37.496239-05	2026-04-19 16:53:46.978639-05	1	1	0	t
40	ruta extraña	0102000020E61000002D0000003F56F0DB104852C0F18288D4B48B1C40A301BC05124852C0075F984C158C1C40D36BB3B1124852C0F06AB933138C1C40BE16F4DE184852C0A1F7C610008C1C40ADF9F197164852C0419AB1683A8B1C403999B855104852C014ECBFCE4D8B1C4022718FA50F4852C02AE09EE74F8B1C408E3EE603024852C0F7AE415F7A8B1C40309E4143FF4752C0153944DC9C8A1C404D86E3F90C4852C0CB48BDA7728A1C4082AD122C0E4852C081B4FF01D68A1C4022718FA50F4852C02AE09EE74F8B1C40A301BC05124852C0075F984C158C1C40325A4755134852C0A036AAD3818C1C4079060DFD134852C0EF004F5AB88C1C4007793D98144852C01C5DA5BBEB8C1C4061AA99B5144852C0772D211FF48C1C406519E258174852C04E29AF95D08D1C406A882AFC194852C013EE9579AB8E1C403FA7203F1B4852C090149161158F1C403F73D6A71C4852C084BC1E4C8A8F1C40EBE40CC51D4852C067F3380CE68F1C408BA8893E1F4852C09F77634161901C4002D9EBDD1F4852C00B62A06B5F901C4007962364204852C0FA2AF9D85D901C404E452A8C2D4852C05587DC0C37901C40A9DE1AD82A4852C0A6B6D4415E8F1C409E616A4B1D4852C0F0A65B76888F1C403F73D6A71C4852C084BC1E4C8A8F1C40228B34F10E4852C0D369DD06B58F1C407616BD53014852C01D5A643BDF8F1C40F2CF0CE2034852C0874ECFBBB1901C40483140A2094852C0D1ADD7F4A0901C402F6D382C0D4852C060E97C7896901C409E44847F114852C0545227A089901C40BC9179E40F4852C033A5F5B704901C40228B34F10E4852C0D369DD06B58F1C405ED72FD80D4852C06D54A703598F1C40355EBA490C4852C0639B5434D68E1C40B39943520B4852C07AC4E8B9858E1C4019ADA3AA094852C01AF8510DFB8D1C405BD07B63084852C01536035C908D1C40143E5B07074852C0C11DA8531E8D1C40A3CA30EE064852C0664D2CF0158D1C40BB26A435064852C0DE205A2BDA8C1C40	\N	#F73B3B	1	\N	\N	\N	\N	f	2026-04-19 21:08:02.795527-05	2026-04-25 11:24:16.035098-05	1	1	0	f
43	cr21-Cr22	0102000020E610000004010000BC9179E40F4852C033A5F5B704901C40228B34F10E4852C0D369DD06B58F1C405ED72FD80D4852C06D54A703598F1C40355EBA490C4852C0639B5434D68E1C40B39943520B4852C07AC4E8B9858E1C4019ADA3AA094852C01AF8510DFB8D1C405BD07B63084852C01536035C908D1C40143E5B07074852C0C11DA8531E8D1C40A3CA30EE064852C0664D2CF0158D1C40BB26A435064852C0DE205A2BDA8C1C403F53AF5B044852C0514F1F813F8C1C403AB01C21034852C073B8567BD88B1C408E3EE603024852C0F7AE415F7A8B1C40F437A110014852C036035C902D8B1C40309E4143FF4752C0153944DC9C8A1C40BF44BC75FE4752C03DB665C0598A1C405A7F4B00FE4752C0276BD443348A1C40FCAA5CA8FC4752C088D68A36C7891C40D9EE1EA0FB4752C0834E081D74891C409EF0129CFA4752C09A779CA223891C40F17EDC7EF94752C0BDFDB968C8881C4010CCD1E3F74752C03BE0BA6246881C40BD715298F74752C0B30A9B012E881C4047753A90F54752C01AA20A7F86871C40658EE55DF54752C07638BA4A77871C406B65C22FF54752C0D1CE691668871C40A0C03BF9F44752C0984F560C57871C40A69718CBF44752C0ED28CE5147871C40F44E05DCF34752C0AA9ECC3FFA861C40AEBCE47FF24752C066BD18CA89861C4097AE601BF14752C0F5F3A62215861C40DE8E705AF04752C040DF162CD5851C406D1B4641F04752C06DAAEE91CD851C4014EAE923F04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C40FDC1C073EF4752C035B742588D851C40390EBC5AEE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C4094DBF63DEA4752C05471E316F3831C40D027F224E94752C07CB4386398831C40D732198EE74752C078B81D1A16831C40D28F8653E64752C0B115342DB1821C4091D442C9E44752C05723BBD232821C408C31B08EE34752C03067B62BF4811C40EC87D860E14752C0F2423A3C84811C40B77A4E7ADF4752C053E8BCC62E811C4012143FC6DC4752C0AF795567B5801C401FF64201DB4752C04F3E3DB665801C40388600E0D84752C0C1FD800706801C405C76887FD84752C0897E6DFDF47F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C08AE6012CF27B1C40D4EE5701BE4752C02A711DE38A7B1C40171230BABC4752C05E85949F547B1C40A7069ACFB94752C02BBEA1F0D97A1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C40C539EAE8B84752C0A3CB9BC3B57A1C405C1FD61BB54752C0C020E9D32A7A1C4068E7340BB44752C016C09481037A1C400B613596B04752C05B5D4E0988791C4011381268B04752C01781B1BE81791C40603DEE5BAD4752C0F05014E813791C4062D9CC21A94752C01920D1048A781C40CEDDAE97A64752C01955867137781C4082A8FB00A44752C0F81BEDB8E1771C408F56B5A4A34752C0F8FE06EDD5771C40185A9D9CA14752C0530438BD8B771C40DD41EC4CA14752C0DC82A5BA80771C40C042E6CAA04752C015AB06616E771C4055A69883A04752C0A9A3E36A64771C40D8D2A3A99E4752C06BF3FFAA23771C406893C3279D4752C0321D3A3DEF761C406E6AA0F99C4752C0F4FDD478E9761C40BC07E8BE9C4752C0992D5915E1761C404BAE62F19B4752C06B0BCF4BC5761C40166D8E739B4752C0B0AD9FFEB3761C40ECBFCE4D9B4752C0FA298E03AF761C40462575029A4752C011AAD4EC81761C4088484DBB984752C0AB08371955761C406CCB80B3944752C0BDE3141DC9751C407F8461C0924752C05DC5E23785751C40753E3C4B904752C03B8C497F2F751C407558E1968F4752C01327F73B14751C4010AD156D8E4752C0AD855968E7741C40E1421EC18D4752C014799274CD741C404165FCFB8C4752C0534145D5AF741C408F5033A48A4752C07B849A2155741C40EF8CB62A894752C0D106600322741C40C1560916874752C0C02154A9D9731C40234910AE804752C092AD2EA704741C40008DD2A57F4752C00A9E42AED4731C4018CFA0A17F4752C08202EFE4D3731C401903EB387E4752C0BBB6B75B92731C40F67AF7C77B4752C0679E5C5320731C401B8524B37A4752C0C2DD59BBED721C4015C8EC2C7A4752C0B7291E17D5721C4087890629784752C0469A780778721C40DB17D00B774752C090A2CEDC43721C40F964C570754752C0630CACE3F8711C40AFB48CD47B4752C01FD95C35CF711C405E2D7766824752C0ADBD4F55A1711C40E6948098844752C00262122EE4711C40F1F44A59864752C046B247A819721C404F95EF19894752C0D4D51D8B6D721C4000AAB8718B4752C056629E95B4721C409F1F46088F4752C078D503E621731C40DA03ADC0904752C0B0ABC95356731C40B5DFDA89924752C0FF756EDA8C731C4048C153C8954752C0AF2479AEEF731C4041B62C5F974752C00A698D4127741C40350873BB974752C09221C7D633741C40CA37DBDC984752C0BF60376C5B741C4069C70DBF9B4752C0D0D6C1C1DE741C409126DE019E4752C0963FDF162C751C4078962023A04752C02A0307B474751C40B37A87DBA14752C0299485AFAF751C405A2F8672A24752C001A3CB9BC3751C40D636C5E3A24752C029EB3713D3751C4000CADFBDA34752C06744696FF0751C40B22C98F8A34752C0B79A75C6F7751C409413ED2AA44752C0841266DAFE751C40C37DE4D6A44752C012A5BDC117761C40F9BEB854A54752C05B5B785E2A761C40815A0C1EA64752C09F71E14048761C409F5912A0A64752C06C06B8205B761C40FD2D01F8A74752C08EE89E758D761C40C2FBAA5CA84752C0B073D3669C761C403E03EACDA84752C06614CB2DAD761C40505436ACA94752C049BA66F2CD761C403D9B559FAB4752C0E23AC61517771C400740DCD5AB4752C0B56FEEAF1E771C4054C37E4FAC4752C08104C58F31771C40789961A3AC4752C00400C79E3D771C404EB857E6AD4752C0988922A46E771C4094162EABB04752C0A208A9DBD9771C401CB28174B14752C0D02A33A5F5771C40408864C8B14752C041EF8D2100781C4004560E2DB24752C0A839799109781C40B7B8C667B24752C0E658DE550F781C4093C83EC8B24752C0581D39D219781C401E6B4606B94752C0E0F76F5E9C781C403B3602F1BA4752C09015FC36C4781C40E8C1DD59BB4752C01E8B6D52D1781C404D874ECFBB4752C0BD378600E0781C40705D3123BC4752C04033880FEC781C400473F4F8BD4752C034677DCA31791C40DAAB8F87BE4752C017F032C346791C40BB2A508BC14752C07782FDD7B9791C40D11E2FA4C34752C055DFF945097A1C403596B036C64752C07CF2B0506B7A1C40B874CC79C64752C0E8F9D346757A1C4005F86EF3C64752C0AFD172A0877A1C40B85A272EC74752C00F5F268A907A1C40581EA4A7C84752C0706072A3C87A1C40FED2A23EC94752C06420CF2EDF7A1C40AA2A3410CB4752C053978C63247B1C40215B96AFCB4752C0D5AF743E3C7B1C40315EF3AACE4752C0D4D17135B27B1C40F5F75278D04752C0DA3C0E83F97B1C4012F758FAD04752C0AC8E1CE90C7C1C4095D5743DD14752C01E537765177C1C409A5E622CD34752C0D94125AE637C1C40B01EF7ADD64752C0BBECD79DEE7C1C40037976F9D64752C0392BA226FA7C1C406E15C440D74752C0B0AC3429057D1C4038BA4A77D74752C0889E94490D7D1C40E52B8194D84752C0EE3F321D3A7D1C40CC9BC3B5DA4752C00ABC934F8F7D1C40B9E2E2A8DC4752C0D6E1E82ADD7D1C406420CF2EDF4752C014E97E4E417E1C40572426A8E14752C0D5CE30B5A57E1C40570A815CE24752C00E6B2A8BC27E1C4014E7A8A3E34752C04641F0F8F67E1C40207BBDFBE34752C090F7AA95097F1C404451A04FE44752C0C976BE9F1A7F1C40D2C3D0EAE44752C0293E3E213B7F1C40261E5036E54752C06D37C1374D7F1C402A8D98D9E74752C028D4D347E07F1C402368CC24EA4752C099BA2BBB60801C408DD0CFD4EB4752C03DD2E0B6B6801C40F71E2E39EE4752C07099D36531811C40A376BF0AF04752C069C4CC3E8F811C406CCD565EF24752C00876FC1708821C4065C22FF5F34752C06DE2E47E87821C405323F433F54752C0280B5F5FEB821C4052EFA99CF64752C0EFCA2E185C831C409981CAF8F74752C082E50819C8831C40F17EDC7EF94752C02C11A8FE41841C40F7216FB9FA4752C053245F09A4841C40EA5910CAFB4752C06FA0C03BF9841C40253E7782FD4752C04014CC9882851C40A245B6F3FD4752C0BD8C62B9A5851C40070B2769FE4752C0C85D8429CA851C4019761893FE4752C0D9B11188D7851C40C64FE3DEFC4752C034828DEBDF851C409DD66D50FB4752C04B9352D0ED851C403F027FF8F94752C0126BF12900861C40575EF23FF94752C0AB5AD2510E861C40939048DBF84752C012A5BDC117861C4087FC3383F84752C07EACE0B721861C40813FFCFCF74752C0613596B036861C4058923CD7F74752C056D80C7041861C402EE57CB1F74752C0CD599F724C861C40A52F849CF74752C03F3BE0BA62861C40B79A75C6F74752C0B01C210379861C40DA70581AF84752C0882B67EF8C861C40E02D90A0F84752C055C03DCF9F861C40F855B950F94752C093FC885FB1861C4021E9D32AFA4752C03E23111AC1861C403811FDDAFA4752C0274C18CDCA861C400873BB97FB4752C0821C9430D3861C40856055BDFC4752C0EE23B726DD861C405A7F4B00FE4752C03E7AC37DE4861C40E9D7D64FFF4752C0E883656CE8861C4047ACC5A7004852C0F4FDD478E9861C407CED9925014852C06B6281AFE8861C40BDC282FB014852C05A2BDA1CE7861C40B7EBA529024852C0F9D7F2CAF5861C40E17EC003034852C0F98557923C871C40213A048E044852C05EF23FF9BB871C4086E5CFB7054852C0E675C4211B881C403EEB1A2D074852C00249D8B793881C405BD07B63084852C0C32E8A1EF8881C402B1895D4094852C03F726BD26D891C4030BB270F0B4852C0051555BFD2891C40FA4509FA0B4852C03E25E7C41E8A1C404D86E3F90C4852C0CB48BDA7728A1C4082AD122C0E4852C081B4FF01D68A1C4022718FA50F4852C02AE09EE74F8B1C403F56F0DB104852C0F18288D4B48B1C40A301BC05124852C0075F984C158C1C40325A4755134852C0A036AAD3818C1C4079060DFD134852C0EF004F5AB88C1C4007793D98144852C01C5DA5BBEB8C1C4061AA99B5144852C0772D211FF48C1C4089230F44164852C07C293C68768D1C406519E258174852C04E29AF95D08D1C403561FBC9184852C0E1606F62488E1C406A882AFC194852C013EE9579AB8E1C403FA7203F1B4852C090149161158F1C403F73D6A71C4852C084BC1E4C8A8F1C40EBE40CC51D4852C067F3380CE68F1C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-21 19:57:56.187384-05	\N	1	\N	0	f
45	ruta 22-21 rapida	0102000020E6100000A100000067B796C9704752C07FFACF9A1F6F1C40DDCD531D724752C0C34A0515556F1C4066834C32724752C0EA758BC0586F1C4078EE3D5C724752C02F52280B5F6F1C40C571E0D5724752C07808E3A7716F1C409016670C734752C056B77A4E7A6F1C40FA7E6ABC744752C034F790F0BD6F1C40F3599E07774752C0172EABB019701C4080643A747A4752C04912842BA0701C402BA226FA7C4752C0FE7DC68503711C408942CBBA7F4752C0647616BD53711C405E2D7766824752C0ADBD4F55A1711C40E6948098844752C00262122EE4711C40F1F44A59864752C046B247A819721C404F95EF19894752C0D4D51D8B6D721C4000AAB8718B4752C056629E95B4721C409F1F46088F4752C078D503E621731C40DA03ADC0904752C0B0ABC95356731C40B5DFDA89924752C0FF756EDA8C731C4048C153C8954752C0AF2479AEEF731C4041B62C5F974752C00A698D4127741C40350873BB974752C09221C7D633741C40CA37DBDC984752C0BF60376C5B741C4069C70DBF9B4752C0D0D6C1C1DE741C409126DE019E4752C0963FDF162C751C4078962023A04752C02A0307B474751C40B37A87DBA14752C0299485AFAF751C405A2F8672A24752C001A3CB9BC3751C40D636C5E3A24752C029EB3713D3751C4000CADFBDA34752C06744696FF0751C40B22C98F8A34752C0B79A75C6F7751C409413ED2AA44752C0841266DAFE751C40C37DE4D6A44752C012A5BDC117761C40F9BEB854A54752C05B5B785E2A761C40815A0C1EA64752C09F71E14048761C409F5912A0A64752C06C06B8205B761C40FD2D01F8A74752C08EE89E758D761C40C2FBAA5CA84752C0B073D3669C761C403E03EACDA84752C06614CB2DAD761C40505436ACA94752C049BA66F2CD761C403D9B559FAB4752C0E23AC61517771C400740DCD5AB4752C0B56FEEAF1E771C4054C37E4FAC4752C08104C58F31771C40789961A3AC4752C00400C79E3D771C404EB857E6AD4752C0988922A46E771C4094162EABB04752C0A208A9DBD9771C401CB28174B14752C0D02A33A5F5771C40408864C8B14752C041EF8D2100781C4004560E2DB24752C0A839799109781C40B7B8C667B24752C0E658DE550F781C4093C83EC8B24752C0581D39D219781C401E6B4606B94752C0E0F76F5E9C781C403B3602F1BA4752C09015FC36C4781C40E8C1DD59BB4752C01E8B6D52D1781C404D874ECFBB4752C0BD378600E0781C40705D3123BC4752C04033880FEC781C400473F4F8BD4752C034677DCA31791C40DAAB8F87BE4752C017F032C346791C40BB2A508BC14752C07782FDD7B9791C40D11E2FA4C34752C055DFF945097A1C403596B036C64752C07CF2B0506B7A1C40B874CC79C64752C0E8F9D346757A1C4005F86EF3C64752C0AFD172A0877A1C40B85A272EC74752C00F5F268A907A1C40581EA4A7C84752C0706072A3C87A1C40FED2A23EC94752C06420CF2EDF7A1C40AA2A3410CB4752C053978C63247B1C40215B96AFCB4752C0D5AF743E3C7B1C40315EF3AACE4752C0D4D17135B27B1C40F5F75278D04752C0DA3C0E83F97B1C4012F758FAD04752C0AC8E1CE90C7C1C4095D5743DD14752C01E537765177C1C409A5E622CD34752C0D94125AE637C1C40B01EF7ADD64752C0BBECD79DEE7C1C40037976F9D64752C0392BA226FA7C1C406E15C440D74752C0B0AC3429057D1C4038BA4A77D74752C0889E94490D7D1C40E52B8194D84752C0EE3F321D3A7D1C40CC9BC3B5DA4752C00ABC934F8F7D1C40B9E2E2A8DC4752C0D6E1E82ADD7D1C406420CF2EDF4752C014E97E4E417E1C40572426A8E14752C0D5CE30B5A57E1C40570A815CE24752C00E6B2A8BC27E1C4014E7A8A3E34752C04641F0F8F67E1C40207BBDFBE34752C090F7AA95097F1C404451A04FE44752C0C976BE9F1A7F1C400953944BE34752C06EE00ED4297F1C40FC3905F9D94752C0DEE34C13B67F1C400EBF9B6ED94752C039B4C876BE7F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C08AE6012CF27B1C40D4EE5701BE4752C02A711DE38A7B1C40171230BABC4752C05E85949F547B1C40A7069ACFB94752C02BBEA1F0D97A1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C40C539EAE8B84752C0A3CB9BC3B57A1C405C1FD61BB54752C0C020E9D32A7A1C4068E7340BB44752C016C09481037A1C400B613596B04752C05B5D4E0988791C4011381268B04752C01781B1BE81791C40603DEE5BAD4752C0F05014E813791C4062D9CC21A94752C01920D1048A781C40CEDDAE97A64752C01955867137781C4082A8FB00A44752C0F81BEDB8E1771C408F56B5A4A34752C0F8FE06EDD5771C40185A9D9CA14752C0530438BD8B771C40DD41EC4CA14752C0DC82A5BA80771C40C042E6CAA04752C015AB06616E771C4055A69883A04752C0A9A3E36A64771C40D8D2A3A99E4752C06BF3FFAA23771C406893C3279D4752C0321D3A3DEF761C406E6AA0F99C4752C0F4FDD478E9761C40BC07E8BE9C4752C0992D5915E1761C404BAE62F19B4752C06B0BCF4BC5761C40166D8E739B4752C0B0AD9FFEB3761C40ECBFCE4D9B4752C0FA298E03AF761C40462575029A4752C011AAD4EC81761C4088484DBB984752C0AB08371955761C406CCB80B3944752C0BDE3141DC9751C407F8461C0924752C05DC5E23785751C40753E3C4B904752C03B8C497F2F751C407558E1968F4752C01327F73B14751C4010AD156D8E4752C0AD855968E7741C40E1421EC18D4752C014799274CD741C404165FCFB8C4752C0534145D5AF741C408F5033A48A4752C07B849A2155741C40EF8CB62A894752C0D106600322741C40C1560916874752C0C02154A9D9731C40234910AE804752C092AD2EA704741C40008DD2A57F4752C00A9E42AED4731C4018CFA0A17F4752C08202EFE4D3731C401903EB387E4752C0BBB6B75B92731C40F67AF7C77B4752C0679E5C5320731C401B8524B37A4752C0C2DD59BBED721C4015C8EC2C7A4752C0B7291E17D5721C4087890629784752C0469A780778721C40DB17D00B774752C090A2CEDC43721C40F964C570754752C0630CACE3F8711C40B3EC4960734752C041F0F8F6AE711C401A1A4F04714752C031EE06D15A711C40B554DE8E704752C07590D78349711C4061FA5E43704752C05F7F129F3B711C405C7171546E4752C08D62B9A5D5701C407044F7AC6B4752C0A4FACE2F4A701C407769C361694752C05B5CE333D96F1C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-22 03:40:09.585687-05	\N	1	\N	0	f
46	ruta22-21 nueva	0102000020E610000031010000BC9179E40F4852C033A5F5B704901C40228B34F10E4852C0D369DD06B58F1C405ED72FD80D4852C06D54A703598F1C40355EBA490C4852C0639B5434D68E1C40B39943520B4852C07AC4E8B9858E1C4019ADA3AA094852C01AF8510DFB8D1C405BD07B63084852C01536035C908D1C40143E5B07074852C0C11DA8531E8D1C40A3CA30EE064852C0664D2CF0158D1C40BB26A435064852C0DE205A2BDA8C1C403F53AF5B044852C0514F1F813F8C1C403AB01C21034852C073B8567BD88B1C408E3EE603024852C0F7AE415F7A8B1C40F437A110014852C036035C902D8B1C40309E4143FF4752C0153944DC9C8A1C40BF44BC75FE4752C03DB665C0598A1C405A7F4B00FE4752C0276BD443348A1C40FCAA5CA8FC4752C088D68A36C7891C40D9EE1EA0FB4752C0834E081D74891C409EF0129CFA4752C09A779CA223891C40F17EDC7EF94752C0BDFDB968C8881C4010CCD1E3F74752C03BE0BA6246881C40BD715298F74752C0B30A9B012E881C4047753A90F54752C01AA20A7F86871C40658EE55DF54752C07638BA4A77871C406B65C22FF54752C0D1CE691668871C40A0C03BF9F44752C0984F560C57871C40A69718CBF44752C0ED28CE5147871C40F44E05DCF34752C0AA9ECC3FFA861C40AEBCE47FF24752C066BD18CA89861C4097AE601BF14752C0F5F3A62215861C40DE8E705AF04752C040DF162CD5851C406D1B4641F04752C06DAAEE91CD851C4014EAE923F04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C40FDC1C073EF4752C035B742588D851C40390EBC5AEE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C4094DBF63DEA4752C05471E316F3831C40D027F224E94752C07CB4386398831C40D732198EE74752C078B81D1A16831C40D28F8653E64752C0B115342DB1821C4091D442C9E44752C05723BBD232821C408C31B08EE34752C03067B62BF4811C40EC87D860E14752C0F2423A3C84811C40B77A4E7ADF4752C053E8BCC62E811C4012143FC6DC4752C0AF795567B5801C401FF64201DB4752C04F3E3DB665801C40388600E0D84752C0C1FD800706801C405C76887FD84752C0897E6DFDF47F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C08AE6012CF27B1C40D4EE5701BE4752C02A711DE38A7B1C40171230BABC4752C05E85949F547B1C40A7069ACFB94752C02BBEA1F0D97A1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C40C539EAE8B84752C0A3CB9BC3B57A1C405C1FD61BB54752C0C020E9D32A7A1C4068E7340BB44752C016C09481037A1C400B613596B04752C05B5D4E0988791C4011381268B04752C01781B1BE81791C40603DEE5BAD4752C0F05014E813791C4062D9CC21A94752C01920D1048A781C40CEDDAE97A64752C01955867137781C4082A8FB00A44752C0F81BEDB8E1771C408F56B5A4A34752C0F8FE06EDD5771C40185A9D9CA14752C0530438BD8B771C40DD41EC4CA14752C0DC82A5BA80771C40C042E6CAA04752C015AB06616E771C4055A69883A04752C0A9A3E36A64771C40D8D2A3A99E4752C06BF3FFAA23771C406893C3279D4752C0321D3A3DEF761C406E6AA0F99C4752C0F4FDD478E9761C40BC07E8BE9C4752C0992D5915E1761C404BAE62F19B4752C06B0BCF4BC5761C40166D8E739B4752C0B0AD9FFEB3761C40ECBFCE4D9B4752C0FA298E03AF761C40462575029A4752C011AAD4EC81761C4088484DBB984752C0AB08371955761C406CCB80B3944752C0BDE3141DC9751C407F8461C0924752C05DC5E23785751C40753E3C4B904752C03B8C497F2F751C407558E1968F4752C01327F73B14751C4010AD156D8E4752C0AD855968E7741C40E1421EC18D4752C014799274CD741C404165FCFB8C4752C0534145D5AF741C408F5033A48A4752C07B849A2155741C40EF8CB62A894752C0D106600322741C40C1560916874752C0C02154A9D9731C40234910AE804752C092AD2EA704741C40008DD2A57F4752C00A9E42AED4731C4018CFA0A17F4752C08202EFE4D3731C401903EB387E4752C0BBB6B75B92731C40F67AF7C77B4752C0679E5C5320731C401B8524B37A4752C0C2DD59BBED721C4015C8EC2C7A4752C0B7291E17D5721C4087890629784752C0469A780778721C40DB17D00B774752C090A2CEDC43721C40F964C570754752C0630CACE3F8711C40B3EC4960734752C041F0F8F6AE711C401A1A4F04714752C031EE06D15A711C40B554DE8E704752C07590D78349711C4061FA5E43704752C05F7F129F3B711C405C7171546E4752C08D62B9A5D5701C407044F7AC6B4752C0A4FACE2F4A701C407769C361694752C05B5CE333D96F1C40779D0DF9674752C06728EE78936F1C40EFE714E4674752C03FFD67CD8F6F1C4066321CCF674752C01215AA9B8B6F1C40D1E80E62674752C034492C29776F1C400744882B674752C0BDC799266C6F1C404F3E3DB6654752C0357EE195246F1C4003EFE4D3634752C046CD57C9C76E1C40200890A1634752C08B8C0E48C26E1C40A9BD88B6634752C085B2F0F5B56E1C40B5519D0E644752C0A703594FAD6E1C40B98C9B1A684752C0B96FB54E5C6E1C40959C137B684752C0E73A8DB4546E1C40F8C5A52A6D4752C0E00ED4298F6E1C40454948A46D4752C02AC58EC6A16E1C4015AB06616E4752C0EBFCDB65BF6E1C4067B796C9704752C07FFACF9A1F6F1C4067B796C9704752C07FFACF9A1F6F1C40DDCD531D724752C0C34A0515556F1C4066834C32724752C0EA758BC0586F1C4078EE3D5C724752C02F52280B5F6F1C40C571E0D5724752C07808E3A7716F1C409016670C734752C056B77A4E7A6F1C40FA7E6ABC744752C034F790F0BD6F1C40F3599E07774752C0172EABB019701C4080643A747A4752C04912842BA0701C402BA226FA7C4752C0FE7DC68503711C408942CBBA7F4752C0647616BD53711C405E2D7766824752C0ADBD4F55A1711C40E6948098844752C00262122EE4711C40F1F44A59864752C046B247A819721C404F95EF19894752C0D4D51D8B6D721C4000AAB8718B4752C056629E95B4721C409F1F46088F4752C078D503E621731C40DA03ADC0904752C0B0ABC95356731C40B5DFDA89924752C0FF756EDA8C731C4048C153C8954752C0AF2479AEEF731C4041B62C5F974752C00A698D4127741C40350873BB974752C09221C7D633741C40CA37DBDC984752C0BF60376C5B741C4069C70DBF9B4752C0D0D6C1C1DE741C409126DE019E4752C0963FDF162C751C4078962023A04752C02A0307B474751C40B37A87DBA14752C0299485AFAF751C405A2F8672A24752C001A3CB9BC3751C40D636C5E3A24752C029EB3713D3751C4000CADFBDA34752C06744696FF0751C40B22C98F8A34752C0B79A75C6F7751C409413ED2AA44752C0841266DAFE751C40C37DE4D6A44752C012A5BDC117761C40F9BEB854A54752C05B5B785E2A761C40815A0C1EA64752C09F71E14048761C409F5912A0A64752C06C06B8205B761C40FD2D01F8A74752C08EE89E758D761C40C2FBAA5CA84752C0B073D3669C761C403E03EACDA84752C06614CB2DAD761C40505436ACA94752C049BA66F2CD761C403D9B559FAB4752C0E23AC61517771C400740DCD5AB4752C0B56FEEAF1E771C4054C37E4FAC4752C08104C58F31771C40789961A3AC4752C00400C79E3D771C404EB857E6AD4752C0988922A46E771C4094162EABB04752C0A208A9DBD9771C401CB28174B14752C0D02A33A5F5771C40408864C8B14752C041EF8D2100781C4004560E2DB24752C0A839799109781C40B7B8C667B24752C0E658DE550F781C4093C83EC8B24752C0581D39D219781C401E6B4606B94752C0E0F76F5E9C781C403B3602F1BA4752C09015FC36C4781C40E8C1DD59BB4752C01E8B6D52D1781C404D874ECFBB4752C0BD378600E0781C40705D3123BC4752C04033880FEC781C400473F4F8BD4752C034677DCA31791C40DAAB8F87BE4752C017F032C346791C40BB2A508BC14752C07782FDD7B9791C40D11E2FA4C34752C055DFF945097A1C403596B036C64752C07CF2B0506B7A1C40B874CC79C64752C0E8F9D346757A1C4005F86EF3C64752C0AFD172A0877A1C40B85A272EC74752C00F5F268A907A1C40581EA4A7C84752C0706072A3C87A1C40FED2A23EC94752C06420CF2EDF7A1C40AA2A3410CB4752C053978C63247B1C40215B96AFCB4752C0D5AF743E3C7B1C40315EF3AACE4752C0D4D17135B27B1C40F5F75278D04752C0DA3C0E83F97B1C4012F758FAD04752C0AC8E1CE90C7C1C4095D5743DD14752C01E537765177C1C409A5E622CD34752C0D94125AE637C1C40B01EF7ADD64752C0BBECD79DEE7C1C40037976F9D64752C0392BA226FA7C1C406E15C440D74752C0B0AC3429057D1C4038BA4A77D74752C0889E94490D7D1C40E52B8194D84752C0EE3F321D3A7D1C40CC9BC3B5DA4752C00ABC934F8F7D1C40B9E2E2A8DC4752C0D6E1E82ADD7D1C406420CF2EDF4752C014E97E4E417E1C40572426A8E14752C0D5CE30B5A57E1C40570A815CE24752C00E6B2A8BC27E1C4014E7A8A3E34752C04641F0F8F67E1C40207BBDFBE34752C090F7AA95097F1C404451A04FE44752C0C976BE9F1A7F1C40D2C3D0EAE44752C0293E3E213B7F1C40261E5036E54752C06D37C1374D7F1C402A8D98D9E74752C028D4D347E07F1C402368CC24EA4752C099BA2BBB60801C408DD0CFD4EB4752C03DD2E0B6B6801C40F71E2E39EE4752C07099D36531811C40A376BF0AF04752C069C4CC3E8F811C406CCD565EF24752C00876FC1708821C4065C22FF5F34752C06DE2E47E87821C405323F433F54752C0280B5F5FEB821C4052EFA99CF64752C0EFCA2E185C831C409981CAF8F74752C082E50819C8831C40F17EDC7EF94752C02C11A8FE41841C40F7216FB9FA4752C053245F09A4841C40EA5910CAFB4752C06FA0C03BF9841C40253E7782FD4752C04014CC9882851C40A245B6F3FD4752C0BD8C62B9A5851C40070B2769FE4752C0C85D8429CA851C4019761893FE4752C0D9B11188D7851C40C64FE3DEFC4752C034828DEBDF851C409DD66D50FB4752C04B9352D0ED851C403F027FF8F94752C0126BF12900861C40575EF23FF94752C0AB5AD2510E861C40939048DBF84752C012A5BDC117861C4087FC3383F84752C07EACE0B721861C40813FFCFCF74752C0613596B036861C4058923CD7F74752C056D80C7041861C402EE57CB1F74752C0CD599F724C861C40A52F849CF74752C03F3BE0BA62861C40B79A75C6F74752C0B01C210379861C40DA70581AF84752C0882B67EF8C861C40E02D90A0F84752C055C03DCF9F861C40F855B950F94752C093FC885FB1861C4021E9D32AFA4752C03E23111AC1861C403811FDDAFA4752C0274C18CDCA861C400873BB97FB4752C0821C9430D3861C40856055BDFC4752C0EE23B726DD861C405A7F4B00FE4752C03E7AC37DE4861C40E9D7D64FFF4752C0E883656CE8861C4047ACC5A7004852C0F4FDD478E9861C407CED9925014852C06B6281AFE8861C40BDC282FB014852C05A2BDA1CE7861C40B7EBA529024852C0F9D7F2CAF5861C40E17EC003034852C0F98557923C871C40213A048E044852C05EF23FF9BB871C4086E5CFB7054852C0E675C4211B881C403EEB1A2D074852C00249D8B793881C405BD07B63084852C0C32E8A1EF8881C402B1895D4094852C03F726BD26D891C4030BB270F0B4852C0051555BFD2891C40FA4509FA0B4852C03E25E7C41E8A1C404D86E3F90C4852C0CB48BDA7728A1C4082AD122C0E4852C081B4FF01D68A1C4022718FA50F4852C02AE09EE74F8B1C403F56F0DB104852C0F18288D4B48B1C40A301BC05124852C0075F984C158C1C40D36BB3B1124852C0F06AB933138C1C40BE16F4DE184852C0A1F7C610008C1C408A8EE4F21F4852C035D3BD4EEA8B1C40B9E177D32D4852C06347E350BF8B1C40B8B06EBC3B4852C090BB0853948B1C407B67B455494852C0CAA99D616A8B1C40810A47904A4852C08A8F4FC8CE8B1C409818CBF44B4852C0DFA7AAD0408C1C40098CF50D4C4852C0B7990AF1488C1C40D8D30E7F4D4852C0BC783F6EBF8C1C40C634D3BD4E4852C088D860E1248D1C409B1F7F69514852C0C501F4FBFE8D1C402844C021544852C0B8AE9811DE8E1C40F12F82C64C4852C02F4D11E0F48E1C407DCF4884464852C0029F1F46088F1C40DCF126BF454852C05247C7D5C88E1C40EFAA07CC434852C091D09673298E1C4063F19BC24A4852C026AC8DB1138E1C409B1F7F69514852C0C501F4FBFE8D1C402844C021544852C0B8AE9811DE8E1C40F12F82C64C4852C02F4D11E0F48E1C407DCF4884464852C0029F1F46088F1C409E060C923E4852C00D535BEA208F1C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-23 12:19:13.593252-05	\N	1	\N	0	f
47	RUTA CACIQUE	0102000020E6100000C7000000FE5F75E4484752C04E7ADFF8DA831C40E294B9F9464752C07CD11E2FA4831C401958C7F1434752C0D2FC31AD4D831C40E6E61BD13D4752C0EA3D95D39E821C40053411363C4752C0FC00A43671821C40234DBC033C4752C03A03232F6B821C40A06EA0C03B4752C06E8B321B64821C40BE874B8E3B4752C024F25D4A5D821C407C98BD6C3B4752C062F4DC4257821C403BA92F4B3B4752C0072461DF4E821C40FAB9A1293B4752C0A796ADF545821C4060CD0182394752C0B9718BF9B9811C40DDEEE53E394752C0C4B12E6EA3811C40A33EC91D364752C0938E72309B801C40A915A6EF354752C076C075C58C801C403E7958A8354752C07C43E1B375801C4032CB9E04364752C05AD5928E72801C405B5EB9DE364752C088A06AF46A801C406B64575A464752C02E910BCEE07F1C40E603029D494752C07216F6B4C37F1C40925B936E4B4752C0451152B7B37F1C408C6A11514C4752C0F0FD0DDAAB7F1C406E5166834C4752C0E4BD6A65C27F1C405038BBB54C4752C06C76A4FACE7F1C40B5FD2B2B4D4752C0334E4354E17F1C402F35423F534752C0F9122A38BC801C407C9BFEEC474752C03DD7F7E120811C40DCD440F3394752C003B4AD669D811C40DDEEE53E394752C0C4B12E6EA3811C40A33EC91D364752C0938E72309B801C40A915A6EF354752C076C075C58C801C403E7958A8354752C07C43E1B375801C40D3DC0A61354752C06058FE7C5B801C408C4AEA04344752C07DCA3159DC7F1C40F700DD97334752C05648F949B57F1C405E143DF0314752C0DAAD65321C7F1C401C25AFCE314752C0CE16105A0F7F1C400ABABDA4314752C0A7CEA3E2FF7E1C4028D36872314752C063D520CCED7E1C40A60EF27A304752C09697FC4FFE7E1C40E126A3CA304752C0C976BE9F1A7F1C40ABCB2901314752C0132D793C2D7F1C40D4449F8F324752C0128942CBBA7F1C40809C3061344752C082C64CA25E801C4062838593344752C0386744696F801C408C3045B9344752C0C11F7EFE7B801C40F7E6374C344752C07C9A931799801C40EB5223F4334752C04EECA17DAC801C4080B6D5AC334752C0D7A4DB12B9801C40E831CA332F4752C0361FD7868A811C40598B4F01304752C0E1455F419A811C40A4A65D4C334752C03D80457EFD801C4039D6C56D344752C01024EF1CCA801C40E561A1D6344752C0438F183DB7801C40207A5226354752C02C7E5358A9801C4074D4D171354752C03E7B2E5393801C40B5C35F93354752C02D27A1F485801C403E7958A8354752C07C43E1B375801C40D3DC0A61354752C06058FE7C5B801C40F700DD97334752C05648F949B57F1C405E143DF0314752C0DAAD65321C7F1C401C25AFCE314752C0CE16105A0F7F1C400ABABDA4314752C0A7CEA3E2FF7E1C4028D36872314752C063D520CCED7E1C407670B037314752C07A8F334DD87E1C4076A4FACE2F4752C097016729597E1C4094BDA59C2F4752C05308E412477E1C407EC9C6832D4752C0D7169E978A7D1C4049BC3C9D2B4752C09961A3ACDF7C1C40DE1FEF552B4752C00BCF4BC5C67C1C40091B9E5E294752C095B7239C167C1C4056B8E523294752C03ACAC16C027C1C40FD868906294752C046274BADF77B1C4092EA3BBF284752C03B730F09DF7B1C406AA510C8254752C09D4830D5CC7A1C40D68F4DF2234752C077871403247A1C4053CBD6FA224752C0399D64ABCB791C40B9AAECBB224752C0C1FEEBDCB4791C400C1F1153224752C028D53E1D8F791C40D23AAA9A204752C0840F255AF2781C407366BB421F4752C0524832AB77781C403E25E7C41E4752C0E6E95C514A781C40B6BDDD921C4752C06ADB300A82771C407AA52C431C4752C0AF601BF164771C406F1118EB1B4752C0ED28CE5147771C40CE1951DA1B4752C0B5C6A01342771C40D53E1D8F194752C0B6D9588979761C40E1ECD632194752C0D8F0F44A59761C407079AC19194752C000FF942A51761C406BD619DF174752C073A1F2AFE5751C402A1BD654164752C04C37894160751C406C2409C2154752C03012DA722E751C401FA16648154752C0E621533E04751C404391EEE7144752C074232C2AE2741C40FC1873D7124752C081CD397826741C4080113466124752C0C6353E93FD731C405C3B5112124752C0FF40B96DDF731C4038656EBE114752C02DD2C43BC0731C40DA907F66104752C00685419946731C40286211C30E4752C0297AE063B0721C408884EFFD0D4752C0ACAA97DF69721C40F33AE2900D4752C0024A438D42721C408E75711B0D4752C0BE16F4DE18721C40FA4509FA0B4752C0E17F2BD9B1711C406616A1D80A4752C07B4D0F0A4A711C40FB93F8DC094752C032E9EFA5F0701C40DEAE97A6084752C077A38FF980701C400D33349E084752C043FE99417C701C4055F99E91084752C055185B0872701C402B4CDF6B084752C01C9947FE60701C40EA5C514A084752C0FA0D130D52701C40C0AF9124084752C0C18EFF0241701C408597E0D4074752C0441669E21D701C4008AA46AF064752C0FB9463B2B86F1C4027F73B14054752C0CE50DCF1266F1C40C808A870044752C05D18E945ED6E1C402E02637D034752C0A7C98CB7956E1C40649126DE014752C0DCF5D214016E1C4035272F32014752C04E0CC9C9C46D1C409B20EA3E004752C09E7AA4C16D6D1C402AADBF25004752C093E34EE9606D1C4071732A19004752C0D7A205685B6D1C4000000000004752C016889E94496D1C405F0839EFFF4652C0EE3F321D3A6D1C4047C66AF3FF4652C01CEE23B7266D1C40A1F7C610004752C07D24253D0C6D1C409B20EA3E004752C094DE37BEF66C1C403541D47D004752C0DE3D40F7E56C1C40B24813EF004752C08350DEC7D16C1C40F31DFCC4014752C03F3A75E5B36C1C4027F73B14054752C0514F1F813F6C1C40EBAA402D064752C0C39FE1CD1A6C1C403E05C078064752C0D976DA1A116C1C40663046240A4752C0A1F2AFE5956B1C40B265F9BA0C4752C05E68AED3486B1C40352A70B20D4752C0698B6B7C266B1C403999B855104752C05F46B1DCD26A1C40CEE2C5C2104752C0DC4AAFCDC66A1C4033A83638114752C064C91CCBBB6A1C402123A0C2114752C07026A60BB16A1C4080113466124752C07B832F4CA66A1C4097395D16134752C09DD497A59D6A1C4079060DFD134752C0C5E23785956A1C408753E6E61B4752C0158BDF14566A1C406EDDCD531D4752C0938FDD054A6A1C40FD8348861C4752C0D1747632386A1C40102384471B4752C03D7C9928426A1C4002D6AA5D134752C059BE2EC37F6A1C4002F04FA9124752C0A9143B1A876A1C40AF95D05D124752C0CB82893F8A6A1C4027FA7C94114752C0378AAC35946A1C409E5E29CB104752C0C042E6CAA06A1C40B0E3BF40104752C0BAA29410AC6A1C404B1E4FCB0F4752C03D9E961FB86A1C40704221020E4752C03C2F151BF36A1C402F6D382C0D4752C069519FE40E6B1C40535DC0CB0C4752C0E1D231E7196B1C40A6D1E4620C4752C05E11FC6F256B1C402ACAA5F10B4752C0CA181F662F6B1C409B711AA20A4752C080D6FCF84B6B1C404374081C094752C069FF03AC556B1C4061A75835084752C01409A69A596B1C404A7F2F85074752C0ADDBA0F65B6B1C4020EC14AB064752C0BE1248895D6B1C400F9BC8CC054752C047AE9B525E6B1C40CEC5DFF6044752C0C4CF7F0F5E6B1C40DA8D3EE6034752C0B398D87C5C6B1C40B7D100DE024752C09CA4F9635A6B1C40E789E76C014752C080F3E2C4576B1C409B20EA3E004752C04D1421753B6B1C408A03E8F7FD4652C0C504357C0B6B1C405E9D6340F64652C0E21FB6F4686A1C404A4563EDEF4652C03E9468C9E3691C40E7012CF2EB4652C0B07092E68F691C40E7012CF2EB4652C0B07092E68F691C40BEBC00FBE84652C0BC3C9D2B4A691C40BEBC00FBE84652C0BC3C9D2B4A691C40DCBB067DE94652C0ABAE433525691C40DCBB067DE94652C0ABAE433525691C40D9CEF753E34652C068244223D8681C40D9CEF753E34652C068244223D8681C40CA198A3BDE4652C019C91EA166681C40CA198A3BDE4652C019C91EA166681C402499D53BDC4652C00261A75835681C402499D53BDC4652C00261A75835681C40E98024ECDB4652C01938A0A52B681C409CFD8172DB4652C0581D39D219681C40EF71A609DB4652C09CBF098508681C4013622EA9DA4652C0D5E76A2BF6671C4090831266DA4652C00953944BE3671C4031957EC2D94652C0D07CCEDDAE671C40852348A5D84652C0D1949D7E50671C4038BA4A77D74652C032005471E3661C405DC47762D64652C077D7D9907F661C401618B2BAD54652C056D80C7041661C403A22DFA5D44652C07EFE7BF0DA651C4010751F80D44652C067EDB60BCD651C400BEC3191D24652C0522976340E651C4059897956D24652C047753A90F5641C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-23 19:06:39.777994-05	\N	1	\N	0	f
48	RUTA CACIQUE2	0102000020E6100000D200000086AC6EF59C4752C0A29A92ACC3811C40F16261889C4752C09146054EB6811C40168733BF9A4752C0D6743DD175811C40E15F048D994752C0EDF483BA48811C40236937FA984752C08C4AEA0434811C40F4FE3F4E984752C00475CAA31B811C4066C0594A964752C0376C5B94D9801C4025EB7074954752C09E5F94A0BF801C4085419946934752C0821DFF0582801C40D42CD0EE904752C06C7BBB2539801C40514EB4AB904752C0880FECF82F801C401C2785798F4752C050560C5707801C400BF0DDE68D4752C094A12AA6D27F1C408811C2A38D4752C0341477BCC97F1C400533A6608D4752C0D386C3D2C07F1C40E25CC30C8D4752C05C0531D0B57F1C406B2C616D8C4752C072BF4351A07F1C40836E2F698C4752C06D020CCB9F7F1C407976F9D6874752C0DA73999A047F1C40F697DD93874752C0F607CA6DFB7E1C4002469737874752C0740CC85EEF7E1C400EF450DB864752C06E32AA0CE37E1C404A26A776864752C0E0BC38F1D57E1C404162BB7B804752C0C51EDAC70A7E1C40D0EE9062804752C0A3B08BA2077E1C402463B5F97F4752C08C9FC6BDF97D1C408F19A88C7F4752C06A1492CCEA7D1C4060AFB0E07E4752C026FE28EACC7D1C4044183F8D7B4752C05A2A6F47387D1C4091B586527B4752C06B44300E2E7D1C4050C6F8307B4752C0B003E78C287D1C402CF015DD7A4752C08E78B29B197D1C406EF9484A7A4752C0CC4065FCFB7C1C40BDFE243E774752C03F6F2A52617C1C40C3D50110774752C062C092AB587C1C40117349D5764752C0EA3E00A94D7C1C401D210379764752C0349E08E23C7C1C40946B0A64764752C08A9466F3387C1C40A019C407764752C056D28A6F287C1C401764CBF2754752C0B742588D257C1C403DD68C0C724752C08507CDAE7B7B1C40792288F3704752C0FDF7E0B54B7B1C4085D04197704752C04D1421753B7B1C408CF50D4C6E4752C081B4FF01D67A1C40CEFE40B96D4752C00FD3BEB9BF7A1C4075CDE49B6D4752C05F0CE544BB7A1C40045ABA826D4752C0B4024356B77A1C4075E789E76C4752C0BA85AE44A07A1C40C284D1AC6C4752C05FB532E1977A1C408D43FD2E6C4752C00F4240BE847A1C408D43FD2E6C4752C08D63247B847A1C409B594B01694752C0CC608C48147A1C40B98C9B1A684752C0446E861BF0791C405A9E0777674752C022C66B5ED5791C40664CC11A674752C0D80FB1C1C2791C409CA73AE4664752C05BD1E638B7791C4072FA7ABE664752C08E59F624B0791C409013268C664752C02252D32EA6791C40EA5E27F5654752C01D3EE94482791C407FC2D9AD654752C0F5D8960167791C405BECF659654752C0236AA2CF47791C409161156F644752C03A596ABDDF781C40E5D53906644752C04C1C7920B2781C4044DE72F5634752C0D49AE61DA7781C408BA4DDE8634752C07F87A2409F781C401A31B3CF634752C06876DD5B91781C40508C2C99634752C0683C11C479781C4026DF6C73634752C019C91EA166781C40567DAEB6624752C0ADF6B0170A781C40452C62D8614752C097FDBAD39D771C40A4349BC7614752C03C2D3F7095771C401B7FA2B2614752C0488AC8B08A771C4099A0866F614752C0F33CB83B6B771C4034DB15FA604752C0E831CA332F771C40702711E15F4752C0D89E5912A0761C40888384285F4752C0672C9ACE4E761C405F0A0F9A5D4752C0E59A02999D751C40B37E33315D4752C0CF328B506C751C401E3526C45C4752C024B5503239751C4013BBB6B75B4752C0581B6327BC741C4090DC9A745B4752C0CA6B257497741C401F69705B5B4752C03CF6B3588A741C4036AB3E575B4752C09D66817687741C40F5BBB0355B4752C0D68EE21C75741C405A9BC6F65A4752C06490BB0853741C407E8B4E965A4752C032772D211F741C400D18247D5A4752C02123A0C211741C40FCC6D79E594752C02D98F8A3A8731C40F1660DDE574752C0C860C5A9D6721C40C7B94DB8574752C006465ED6C4721C400F9A5DF7564752C0A6ED5F5969721C4051A39064564752C0BE33DAAA24721C40E606431D564752C0CF13CFD902721C407B6AF5D5554752C063D2DF4BE1711C40F2B4FCC0554752C0F10D85CFD6711C4057941282554752C0BE2EC37FBA711C402E1B9DF3534752C0433D7D04FE701C407CB8E4B8534752C09EB64604E3701C40E2CB4411524752C09FC9FE791A701C4000E5EFDE514752C09F8F32E202701C4083DDB06D514752C0D960E124CD6F1C40FA27B858514752C0EF37DA71C36F1C407172BF43514752C089EDEE01BA6F1C405F07CE19514752C023861DC6A46F1C407D2079E7504752C0A06D35EB8C6F1C403C31EBC5504752C05C74B2D47A6F1C40CBD765F84F4752C0EBC726F9116F1C40CBD765F84F4752C0C328081EDF6E1C400133DFC14F4752C0BE310400C76E1C406CE9D1544F4752C0B900344A976E1C402BFA43334F4752C09C3237DF886E1C40E44D7E8B4E4752C0096F0F42406E1C4067463F1A4E4752C0033E3F8C106E1C40B4E386DF4D4752C0E7525C55F66D1C40BABA63B14D4752C015014EEFE26D1C404F1E166A4D4752C0C0B33D7AC36D1C40DEAAEB504D4752C0CB10C7BAB86D1C409DBB5D2F4D4752C0DC0DA2B5A26D1C40448A01124D4752C05AF5B9DA8A6D1C40730E9E094D4752C043E4F4F57C6D1C40FCC3961E4D4752C005A8A9656B6D1C4097E4805D4D4752C0F9F36DC1526D1C4032056B9C4D4752C0FF76D9AF3B6D1C40BABA63B14D4752C03E5C72DC296D1C4073F4F8BD4D4752C07D410B09186D1C4043705CC64D4752C0CC5D4BC8076D1C40A37895B54D4752C016BD5301F76C1C40D8D30E7F4D4752C0446B459BE36C1C400858AB764D4752C028BA2EFCE06C1C40CD3FFA264D4752C0BC95253ACB6C1C40687A89B14C4752C04AB4E4F1B46C1C40A983BC1E4C4752C0616EF7729F6C1C404A95287B4B4752C01D75745C8D6C1C40AAB706B64A4752C0BCCADAA6786C1C406FB9FAB1494752C03F6F2A52616C1C40ABEB504D494752C0EA5BE674596C1C40C347C494484752C078978BF84E6C1C40F3E505D8474752C0952BBCCB456C1C405308E412474752C0C2F693313E6C1C40CA6C9049464752C084D72E6D386C1C40363D2828454752C04B75012F336C1C40E3E2A8DC444752C0C2D9AD65326C1C403D484F91434752C0A06B5F402F6C1C40F1129CFA404752C0F661BD512B6C1C4021B1DD3D404752C0E52A16BF296C1C40390D51853F4752C0459BE3DC266C1C40E00F3FFF3D4752C0F0879FFF1E6C1C4028F04E3E3D4752C0B72572C1196C1C4038A27BD6354752C0E04BE141B36B1C403FADA23F344752C00DFAD2DB9F6B1C4056EF703B344752C08B1BB7989F6B1C40279F1EDB324752C0D57ABFD18E6B1C40ACFF73982F4752C09604A8A9656B1C408F1A13622E4752C069FF03AC556B1C40BA15C26A2C4752C03CDD79E2396B1C40D97C5C1B2A4752C0DB15FA60196B1C40DAFE9595264752C0488C9E5BE86A1C4005FA449E244752C08C118942CB6A1C40C40AB77C244752C0751DAA29C96A1C406536C824234752C015731074B46A1C409CC58B85214752C076A911FA996A1C40E4D9E55B1F4752C0D105F52D736A1C4008E412471E4752C0F9F6AE415F6A1C4032AB77B81D4752C0F31C91EF526A1C406EDDCD531D4752C0938FDD054A6A1C40FD8348861C4752C0D1747632386A1C40102384471B4752C03D7C9928426A1C4002D6AA5D134752C059BE2EC37F6A1C400E846401134752C081E9B46E836A1C4002F04FA9124752C0A9143B1A876A1C40AF95D05D124752C0CB82893F8A6A1C4027FA7C94114752C0378AAC35946A1C409E5E29CB104752C0C042E6CAA06A1C40B0E3BF40104752C0BAA29410AC6A1C404B1E4FCB0F4752C03D9E961FB86A1C40704221020E4752C03C2F151BF36A1C402F6D382C0D4752C069519FE40E6B1C40535DC0CB0C4752C0E1D231E7196B1C40A6D1E4620C4752C05E11FC6F256B1C402ACAA5F10B4752C0CA181F662F6B1C409B711AA20A4752C080D6FCF84B6B1C40C07B478D094752C0CA6FD1C9526B1C404374081C094752C069FF03AC556B1C4061A75835084752C01409A69A596B1C404A7F2F85074752C0ADDBA0F65B6B1C4020EC14AB064752C0BE1248895D6B1C400F9BC8CC054752C047AE9B525E6B1C40CEC5DFF6044752C0C4CF7F0F5E6B1C40DA8D3EE6034752C0B398D87C5C6B1C40B7D100DE024752C09CA4F9635A6B1C40E789E76C014752C080F3E2C4576B1C409B20EA3E004752C04D1421753B6B1C408A03E8F7FD4652C0C504357C0B6B1C405E9D6340F64652C0E21FB6F4686A1C404A4563EDEF4652C03E9468C9E3691C40E7012CF2EB4652C0B07092E68F691C40E7012CF2EB4652C0B07092E68F691C40BEBC00FBE84652C0BC3C9D2B4A691C40BEBC00FBE84652C0BC3C9D2B4A691C40DCBB067DE94652C0ABAE433525691C40DCBB067DE94652C0ABAE433525691C40D9CEF753E34652C068244223D8681C40D9CEF753E34652C068244223D8681C40CA198A3BDE4652C019C91EA166681C40CA198A3BDE4652C019C91EA166681C402499D53BDC4652C00261A75835681C402499D53BDC4652C00261A75835681C4038BA4A77D74652C032005471E3661C4038BA4A77D74652C032005471E3661C4059897956D24652C047753A90F5641C40	\N	#F73BD4	1	\N	\N	\N	\N	t	2026-04-23 19:40:18.36649-05	2026-04-23 19:46:09.763221-05	1	1	0	f
49	ruta 27 hacia el norte	0102000020E61000005B0000001975ADBD4F4752C0EAB46E83DA6F1C408AE8D7D64F4752C067F3380CE66F1C400DC7F319504752C050560C5707701C40E2CB4411524752C0F3E670ADF6701C40E2B19FC5524752C0209A79724D711C40465D6BEF534752C0965AEF37DA711C407C9E3F6D544752C019CA897615721C40FE7C5BB0544752C0F1F5B52E35721C4086E464E2564752C05001309E41731C4027C286A7574752C0C64D0D349F731C40D90A9A96584752C010ECF82F10741C401AFA27B8584752C04E2844C021741C40732B84D5584752C05F7CD11E2F741C40F609A018594752C0D17AF83251741C4049641F64594752C0E108522976741C40F6EFFACC594752C01ADF1797AA741C40F0181EFB594752C08BC058DFC0741C408448861C5B4752C063F19BC24A751C400DFE7E315B4752C04C1AA37554751C409599D2FA5B4752C062F6B2EDB4751C40FA449E245D4752C078465B9544761C40BE1248895D4752C0833463D174761C401DE736E15E4752C0F92EA52E19771C40340F60915F4752C00FEECEDA6D771C408E40BCAE5F4752C09D6340F67A771C40FFB3E6C75F4752C09D8026C286771C40C9586DFE5F4752C031D0B52FA0771C40EC2E5052604752C0E7AA798EC8771C40635FB2F1604752C0A8565F5D15781C406902452C624752C0B20FB22C98781C40213CDA38624752C0F6EB4E779E781C40DA756F45624752C0C9207711A6781C401B65FD66624752C0A12FBDFDB9781C40E509849D624752C0C8940F41D5781C40DF180280634752C0F0C4AC1743791C40A9BD88B6634752C0D90A9A9658791C4074620FED634752C09A25016A6A791C400E83F92B644752C078F17EDC7E791C409161156F644752C028D53E1D8F791C4002D53F88644752C061376C5B94791C405B069CA5644752C02DAF5C6F9B791C407FDC7EF9644752C006BEA25BAF791C4002BB9A3C654752C0B0E42A16BF791C40F03504C7654752C0C1559E40D8791C40A298BC01664752C0331AF9BCE2791C405AB8ACC2664752C00B462575027A1C402A1A6B7F674752C04F5C8E57207A1C400053060E684752C0AF06280D357A1C4023DBF97E6A4752C081069B3A8F7A1C406A87BF266B4752C015562AA8A87A1C40DBFAE93F6B4752C03D81B053AC7A1C40342C465D6B4752C06A696E85B07A1C40DBE044F46B4752C0E107E753C77A1C40A585CB2A6C4752C0BFB67EFACF7A1C40228D0A9C6C4752C0F8359204E17A1C408638D6C56D4752C097395D16137B1C407365506D704752C06E30D461857B1C40BF9A0304734752C0AC545051F57B1C4036B1C057744752C018D00B772E7C1C400056478E744752C0FB3BDBA3377C1C406BF294D5744752C0FB58C16F437C1C40177E703E754752C05089EB18577C1C40DC4B1AA3754752C023DBF97E6A7C1C40751E15FF774752C0C74961DEE37C1C40D40CA9A2784752C0B0AC3429057D1C40E0A0BDFA784752C0EEE87FB9167D1C4033FB3C46794752C01631EC30267D1C40C26D6DE1794752C03E963E74417D1C40A9DDAF027C4752C054724EECA17D1C40AE80423D7D4752C02CD8463CD97D1C40E998F38C7D4752C048A643A7E77D1C400D6FD6E07D4752C0E7525C55F67D1C401EC022BF7E4752C0A88AA9F4137E1C407100FDBE7F4752C097AAB4C5357E1C40C9C9C4AD824752C04759BF99987E1C4004AE2B66844752C0B891B245D27E1C4069739CDB844752C063B83A00E27E1C404583143C854752C06E4F90D8EE7E1C400951BEA0854752C07FA31D37FC7E1C4098C3EE3B864752C05D6F9BA9107F1C401349F4328A4752C00C7558E1967F1C40897956D28A4752C0F0FD0DDAAB7F1C40950D6B2A8B4752C06D3CD862B77F1C40A1A17F828B4752C06D59BE2EC37F1C40AD3594DA8B4752C06C76A4FACE7F1C4012FB04508C4752C094BE1072DE7F1C402EC6C03A8E4752C08EAF3DB324801C40ABCDFFAB8E4752C01C42959A3D801C40151C5E10914752C0051901158E801C40BBB6B75B924752C0BAF3C473B6801C40250516C0944752C0A987687407811C40	\N	#8F8332	1	\N	\N	\N	\N	t	2026-04-23 20:38:17.330199-05	\N	1	\N	0	f
50	ruta 27 hasta 56	0102000020E61000006300000086AC6EF59C4752C0A29A92ACC3811C40F16261889C4752C09146054EB6811C40168733BF9A4752C0D6743DD175811C40E15F048D994752C0EDF483BA48811C40236937FA984752C08C4AEA0434811C40F4FE3F4E984752C00475CAA31B811C4066C0594A964752C0376C5B94D9801C4025EB7074954752C09E5F94A0BF801C4085419946934752C0821DFF0582801C40D42CD0EE904752C06C7BBB2539801C40514EB4AB904752C0880FECF82F801C401C2785798F4752C050560C5707801C400BF0DDE68D4752C094A12AA6D27F1C408811C2A38D4752C0341477BCC97F1C400533A6608D4752C0D386C3D2C07F1C40E25CC30C8D4752C05C0531D0B57F1C406B2C616D8C4752C072BF4351A07F1C40836E2F698C4752C06D020CCB9F7F1C407976F9D6874752C0DA73999A047F1C40F697DD93874752C0F607CA6DFB7E1C4002469737874752C0740CC85EEF7E1C400EF450DB864752C06E32AA0CE37E1C404A26A776864752C0E0BC38F1D57E1C404162BB7B804752C0C51EDAC70A7E1C40D0EE9062804752C0A3B08BA2077E1C402463B5F97F4752C08C9FC6BDF97D1C408F19A88C7F4752C06A1492CCEA7D1C4060AFB0E07E4752C026FE28EACC7D1C4044183F8D7B4752C05A2A6F47387D1C4091B586527B4752C06B44300E2E7D1C4050C6F8307B4752C0B003E78C287D1C402CF015DD7A4752C08E78B29B197D1C406EF9484A7A4752C0CC4065FCFB7C1C40BDFE243E774752C03F6F2A52617C1C40C3D50110774752C062C092AB587C1C40117349D5764752C0EA3E00A94D7C1C401D210379764752C0349E08E23C7C1C40946B0A64764752C08A9466F3387C1C40A019C407764752C056D28A6F287C1C401764CBF2754752C0B742588D257C1C403DD68C0C724752C08507CDAE7B7B1C40792288F3704752C0FDF7E0B54B7B1C4085D04197704752C04D1421753B7B1C408CF50D4C6E4752C081B4FF01D67A1C40CEFE40B96D4752C00FD3BEB9BF7A1C4075CDE49B6D4752C05F0CE544BB7A1C40045ABA826D4752C0B4024356B77A1C4075E789E76C4752C0BA85AE44A07A1C40C284D1AC6C4752C05FB532E1977A1C408D43FD2E6C4752C00F4240BE847A1C408D43FD2E6C4752C08D63247B847A1C409B594B01694752C0CC608C48147A1C40B98C9B1A684752C0446E861BF0791C405A9E0777674752C022C66B5ED5791C40664CC11A674752C0D80FB1C1C2791C409CA73AE4664752C05BD1E638B7791C4072FA7ABE664752C08E59F624B0791C409013268C664752C02252D32EA6791C40EA5E27F5654752C01D3EE94482791C407FC2D9AD654752C0F5D8960167791C405BECF659654752C0236AA2CF47791C409161156F644752C03A596ABDDF781C40E5D53906644752C04C1C7920B2781C4044DE72F5634752C0D49AE61DA7781C408BA4DDE8634752C07F87A2409F781C401A31B3CF634752C06876DD5B91781C40508C2C99634752C0683C11C479781C4026DF6C73634752C019C91EA166781C40567DAEB6624752C0ADF6B0170A781C40452C62D8614752C097FDBAD39D771C40A4349BC7614752C03C2D3F7095771C401B7FA2B2614752C0488AC8B08A771C4099A0866F614752C0F33CB83B6B771C4034DB15FA604752C0E831CA332F771C40702711E15F4752C0D89E5912A0761C40888384285F4752C0672C9ACE4E761C405F0A0F9A5D4752C0E59A02999D751C40B37E33315D4752C0CF328B506C751C401E3526C45C4752C024B5503239751C4013BBB6B75B4752C0581B6327BC741C4090DC9A745B4752C0CA6B257497741C401F69705B5B4752C03CF6B3588A741C4036AB3E575B4752C09D66817687741C40F5BBB0355B4752C0D68EE21C75741C405A9BC6F65A4752C06490BB0853741C407E8B4E965A4752C032772D211F741C400D18247D5A4752C02123A0C211741C40FCC6D79E594752C02D98F8A3A8731C40F1660DDE574752C0C860C5A9D6721C40C7B94DB8574752C006465ED6C4721C400F9A5DF7564752C0A6ED5F5969721C4051A39064564752C0BE33DAAA24721C40E606431D564752C0CF13CFD902721C407B6AF5D5554752C063D2DF4BE1711C40F2B4FCC0554752C0F10D85CFD6711C4057941282554752C0BE2EC37FBA711C402E1B9DF3534752C0433D7D04FE701C407CB8E4B8534752C09EB64604E3701C40E2CB4411524752C09FC9FE791A701C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-24 01:16:01.788554-05	\N	1	\N	0	f
51	ruta al Girasol	0102000020E6100000FD00000086AC6EF59C4752C0A29A92ACC3811C40F16261889C4752C09146054EB6811C40168733BF9A4752C0D6743DD175811C40E15F048D994752C0EDF483BA48811C40236937FA984752C08C4AEA0434811C40F4FE3F4E984752C00475CAA31B811C4066C0594A964752C0376C5B94D9801C4025EB7074954752C09E5F94A0BF801C4085419946934752C0821DFF0582801C40D42CD0EE904752C06C7BBB2539801C40514EB4AB904752C0880FECF82F801C401C2785798F4752C050560C5707801C400BF0DDE68D4752C094A12AA6D27F1C408811C2A38D4752C0341477BCC97F1C400533A6608D4752C0D386C3D2C07F1C40E25CC30C8D4752C05C0531D0B57F1C406B2C616D8C4752C072BF4351A07F1C40836E2F698C4752C06D020CCB9F7F1C407976F9D6874752C0DA73999A047F1C40F697DD93874752C0F607CA6DFB7E1C4002469737874752C0740CC85EEF7E1C400EF450DB864752C06E32AA0CE37E1C404A26A776864752C0E0BC38F1D57E1C404162BB7B804752C0C51EDAC70A7E1C40D0EE9062804752C0A3B08BA2077E1C402463B5F97F4752C08C9FC6BDF97D1C408F19A88C7F4752C06A1492CCEA7D1C4060AFB0E07E4752C026FE28EACC7D1C4044183F8D7B4752C05A2A6F47387D1C4091B586527B4752C06B44300E2E7D1C4050C6F8307B4752C0B003E78C287D1C402CF015DD7A4752C08E78B29B197D1C406EF9484A7A4752C0CC4065FCFB7C1C40BDFE243E774752C03F6F2A52617C1C40C3D50110774752C062C092AB587C1C40117349D5764752C0EA3E00A94D7C1C401D210379764752C0349E08E23C7C1C40946B0A64764752C08A9466F3387C1C40A019C407764752C056D28A6F287C1C401764CBF2754752C0B742588D257C1C403DD68C0C724752C08507CDAE7B7B1C40792288F3704752C0FDF7E0B54B7B1C4085D04197704752C04D1421753B7B1C408CF50D4C6E4752C081B4FF01D67A1C40CEFE40B96D4752C00FD3BEB9BF7A1C4075CDE49B6D4752C05F0CE544BB7A1C40045ABA826D4752C0B4024356B77A1C4075E789E76C4752C0BA85AE44A07A1C40C284D1AC6C4752C05FB532E1977A1C408D43FD2E6C4752C00F4240BE847A1C408D43FD2E6C4752C08D63247B847A1C409B594B01694752C0CC608C48147A1C40B98C9B1A684752C0446E861BF0791C405A9E0777674752C022C66B5ED5791C40664CC11A674752C0D80FB1C1C2791C409CA73AE4664752C05BD1E638B7791C4072FA7ABE664752C08E59F624B0791C409013268C664752C02252D32EA6791C40EA5E27F5654752C01D3EE94482791C407FC2D9AD654752C0F5D8960167791C405BECF659654752C0236AA2CF47791C409161156F644752C03A596ABDDF781C40E5D53906644752C04C1C7920B2781C4044DE72F5634752C0D49AE61DA7781C408BA4DDE8634752C07F87A2409F781C401A31B3CF634752C06876DD5B91781C40508C2C99634752C0683C11C479781C4026DF6C73634752C019C91EA166781C40567DAEB6624752C0ADF6B0170A781C40452C62D8614752C097FDBAD39D771C40A4349BC7614752C03C2D3F7095771C401B7FA2B2614752C0488AC8B08A771C4099A0866F614752C0F33CB83B6B771C4034DB15FA604752C0E831CA332F771C40702711E15F4752C0D89E5912A0761C40888384285F4752C0672C9ACE4E761C405F0A0F9A5D4752C0E59A02999D751C40B37E33315D4752C0CF328B506C751C401E3526C45C4752C024B5503239751C4013BBB6B75B4752C0581B6327BC741C4090DC9A745B4752C0CA6B257497741C401F69705B5B4752C03CF6B3588A741C4036AB3E575B4752C09D66817687741C40F5BBB0355B4752C0D68EE21C75741C405A9BC6F65A4752C06490BB0853741C407E8B4E965A4752C032772D211F741C400D18247D5A4752C02123A0C211741C40FCC6D79E594752C02D98F8A3A8731C40F1660DDE574752C0C860C5A9D6721C40C7B94DB8574752C006465ED6C4721C400F9A5DF7564752C0A6ED5F5969721C4051A39064564752C0BE33DAAA24721C40E606431D564752C0CF13CFD902721C407B6AF5D5554752C063D2DF4BE1711C40F2B4FCC0554752C0F10D85CFD6711C4057941282554752C0BE2EC37FBA711C402E1B9DF3534752C0433D7D04FE701C407CB8E4B8534752C09EB64604E3701C40E2CB4411524752C09FC9FE791A701C4000E5EFDE514752C09F8F32E202701C4083DDB06D514752C0D960E124CD6F1C40FA27B858514752C0EF37DA71C36F1C407172BF43514752C089EDEE01BA6F1C405F07CE19514752C023861DC6A46F1C407D2079E7504752C0A06D35EB8C6F1C403C31EBC5504752C05C74B2D47A6F1C40CBD765F84F4752C0EBC726F9116F1C40CBD765F84F4752C0C328081EDF6E1C400133DFC14F4752C0BE310400C76E1C406CE9D1544F4752C0B900344A976E1C402BFA43334F4752C09C3237DF886E1C40E44D7E8B4E4752C0096F0F42406E1C4067463F1A4E4752C0033E3F8C106E1C40B4E386DF4D4752C0E7525C55F66D1C40BABA63B14D4752C015014EEFE26D1C404F1E166A4D4752C0C0B33D7AC36D1C40DEAAEB504D4752C0CB10C7BAB86D1C409DBB5D2F4D4752C0DC0DA2B5A26D1C40448A01124D4752C05AF5B9DA8A6D1C40730E9E094D4752C043E4F4F57C6D1C40FCC3961E4D4752C005A8A9656B6D1C4097E4805D4D4752C0F9F36DC1526D1C4032056B9C4D4752C0FF76D9AF3B6D1C40BABA63B14D4752C03E5C72DC296D1C4073F4F8BD4D4752C07D410B09186D1C4043705CC64D4752C0CC5D4BC8076D1C40A37895B54D4752C016BD5301F76C1C40D8D30E7F4D4752C0446B459BE36C1C400858AB764D4752C028BA2EFCE06C1C40CD3FFA264D4752C0BC95253ACB6C1C40687A89B14C4752C04AB4E4F1B46C1C40A983BC1E4C4752C0616EF7729F6C1C404A95287B4B4752C01D75745C8D6C1C40AAB706B64A4752C0BCCADAA6786C1C406FB9FAB1494752C03F6F2A52616C1C40ABEB504D494752C0EA5BE674596C1C40C347C494484752C078978BF84E6C1C40F3E505D8474752C0952BBCCB456C1C405308E412474752C0C2F693313E6C1C40CA6C9049464752C084D72E6D386C1C40363D2828454752C04B75012F336C1C40E3E2A8DC444752C0C2D9AD65326C1C403D484F91434752C0A06B5F402F6C1C40F1129CFA404752C0F661BD512B6C1C4021B1DD3D404752C0E52A16BF296C1C40390D51853F4752C0459BE3DC266C1C40E00F3FFF3D4752C0F0879FFF1E6C1C4028F04E3E3D4752C0B72572C1196C1C4038A27BD6354752C0E04BE141B36B1C403FADA23F344752C00DFAD2DB9F6B1C4056EF703B344752C08B1BB7989F6B1C40279F1EDB324752C0D57ABFD18E6B1C40ACFF73982F4752C09604A8A9656B1C408F1A13622E4752C069FF03AC556B1C40BA15C26A2C4752C03CDD79E2396B1C40D97C5C1B2A4752C0DB15FA60196B1C40DAFE9595264752C0488C9E5BE86A1C4005FA449E244752C08C118942CB6A1C40C40AB77C244752C0751DAA29C96A1C406536C824234752C015731074B46A1C409CC58B85214752C076A911FA996A1C40E4D9E55B1F4752C0D105F52D736A1C4008E412471E4752C0F9F6AE415F6A1C4032AB77B81D4752C0F31C91EF526A1C406EDDCD531D4752C0938FDD054A6A1C40FD8348861C4752C0D1747632386A1C40102384471B4752C03D7C9928426A1C4002D6AA5D134752C059BE2EC37F6A1C400E846401134752C081E9B46E836A1C4002F04FA9124752C0A9143B1A876A1C40AF95D05D124752C0CB82893F8A6A1C4027FA7C94114752C0378AAC35946A1C409E5E29CB104752C0C042E6CAA06A1C40B0E3BF40104752C0BAA29410AC6A1C404B1E4FCB0F4752C03D9E961FB86A1C40704221020E4752C03C2F151BF36A1C402F6D382C0D4752C069519FE40E6B1C40535DC0CB0C4752C0E1D231E7196B1C40A6D1E4620C4752C05E11FC6F256B1C402ACAA5F10B4752C0CA181F662F6B1C409B711AA20A4752C080D6FCF84B6B1C40C07B478D094752C0CA6FD1C9526B1C404374081C094752C069FF03AC556B1C4061A75835084752C01409A69A596B1C404A7F2F85074752C0ADDBA0F65B6B1C4020EC14AB064752C0BE1248895D6B1C400F9BC8CC054752C047AE9B525E6B1C40CEC5DFF6044752C0C4CF7F0F5E6B1C40DA8D3EE6034752C0B398D87C5C6B1C40B7D100DE024752C09CA4F9635A6B1C40E789E76C014752C080F3E2C4576B1C409B20EA3E004752C04D1421753B6B1C408A03E8F7FD4652C0C504357C0B6B1C405E9D6340F64652C0E21FB6F4686A1C404A4563EDEF4652C03E9468C9E3691C40F699B33EE54652C0B7D100DE02691C40D9CEF753E34652C068244223D8681C40CE88D2DEE04652C0967B8159A1681C40768BC058DF4652C0A75B76887F681C4018D1764CDD4652C0354069A851681C40B30B06D7DC4652C0C47B0E2C47681C403604C765DC4652C0B8E4B8533A681C402499D53BDC4652C00261A75835681C40E98024ECDB4652C01938A0A52B681C409CFD8172DB4652C0581D39D219681C40EF71A609DB4652C09CBF098508681C4013622EA9DA4652C0D5E76A2BF6671C4090831266DA4652C00953944BE3671C4031957EC2D94652C0D07CCEDDAE671C40852348A5D84652C0D1949D7E50671C4038BA4A77D74652C032005471E3661C405DC47762D64652C077D7D9907F661C401618B2BAD54652C056D80C7041661C403A22DFA5D44652C07EFE7BF0DA651C4010751F80D44652C067EDB60BCD651C400BEC3191D24652C0522976340E651C4059897956D24652C047753A90F5641C40CA1649BBD14652C01FB935E9B6641C40DC9BDF30D14652C047AAEFFCA2641C40666B7D91D04652C00F2BDCF291641C403CD862B7CF4652C048533D997F641C409CFA40F2CE4652C0B42094F771641C4049BA66F2CD4652C026AB22DC64641C4026FE28EACC4652C01A14CD0358641C4092CEC0C8CB4652C01AF7E6374C641C402D23F59ECA4652C0BA69334E43641C40F224E99AC94652C087C43D963E641C403448C153C84652C0E7340BB43B641C406534F279C54652C0768D96033D641C4079211D1EC24652C0FE28EACC3D641C40A9D903ADC04652C0D12346CF2D641C40986E1283C04652C0B4722F302B641C40DF4E22C2BF4652C0373465A71F641C404548DDCEBE4652C07619FED30D641C40B7D5AC33BE4652C0D1AFAD9FFE631C40F8DEDFA0BD4652C02C29779FE3631C4016F88A6EBD4652C0541A31B3CF631C408D429259BD4652C0774EB340BB631C40C1012D5DC14652C0C72B103D29631C40A2B437F8C24652C0E44BA8E0F0621C40C0B33D7AC34652C0844A5CC7B8621C40AE484C50C34652C07EFCA5457D621C400E6B2A8BC24652C0FCA9F1D24D621C405C3CBCE7C04652C0F19E03CB11621C4057CD7344BE4652C0BE8575E3DD611C40C539EAE8B84652C0BFF4F6E7A2611C40BB270F0BB54652C0C47762D68B611C401C7E37DDB24652C0E10B93A982611C40CBBF9657AE4652C025CB49287D611C4078B306EFAB4652C01F0E12A27C611C40029D499BAA4652C0C45A7C0A80611C4086AFAF75A94652C0EC8502B683611C409F73B7EBA54652C00954FF2092611C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-24 01:24:58.192336-05	\N	1	\N	0	f
53	ruta corta 18-21	0102000020E6100000B2000000CFA44DD53D4852C0514F1F813F8C1C40B8B06EBC3B4852C090BB0853948B1C4059C2DA183B4852C058E542E55F8B1C40A1A2EA573A4852C036E675C4218B1C4066A4DE53394852C0B43C0FEECE8A1C4007B64AB0384852C0F9872D3D9A8A1C40797764AC364852C0FFAECF9CF5891C403E7958A8354852C077483140A2891C40A47213B5344852C02E01F8A754891C4039F06AB9334852C0406D54A703891C4004C93B87324852C090BE49D3A0881C4081EA1F44324852C0A7785C548B881C40164ED2FC314852C0B2B8FFC874881C404CA94BC6314852C07A39ECBE63881C408104C58F314852C03BFDA02E52881C4059A5F44C2F4852C05F9B8D9598871C40894336902E4852C054909F8D5C871C40CB80B3942C4852C06631B1F9B8861C40C6DD205A2B4852C0A54BFF9254861C40F69507E9294852C01D8EAED2DD851C4033E202D0284852C046D1031F83851C4039ED2939274852C04792205C01851C403A2174D0254852C064213A048E841C40C40AB77C244852C0486B0C3A21841C407D5EF1D4234852C01B0FB6D8ED831C40A182C30B224852C099D4D00660831C40609335EA214852C02810768A55831C4095EEAEB3214852C07DE9EDCF45831C40B3075A81214852C05B5EB9DE36831C40D120054F214852C03F90BC7328831C4025AFCE31204852C0ABAFAE0AD4821C4026E318C91E4852C0A6ED5F5969821C404A07EBFF1C4852C0D55C6E30D4811C4098BED7101C4852C0809BC58B85811C4022A81ABD1A4852C0DC4944F817811C40D53E1D8F194852C0438F183DB7801C402FA4C343184852C055FB743C66801C40C4211B48174852C033FCA71B28801C4072158BDF144852C0A0FEB3E6C77F1C40AF95D05D124852C0DF180280637F1C406FF4311F104852C00D198F52097F1C406A6B44300E4852C0C98E8D40BC7E1C40FFCEF6E80D4852C0520DFB3DB17E1C40DC12B9E00C4852C0A2EF6E65897E1C40000341800C4852C0862172FA7A7E1C402AFEEF880A4852C053CE177B2F7E1C404374081C094852C0FE463B6EF87D1C4009C4EBFA054852C0E27327D87F7D1C401C7DCC07044852C0B5DD04DF347D1C40E63BF889034852C0E38BF678217D1C40B1FA230C034852C005C078060D7D1C4034F3E49A024852C02DB1321AF97C1C4059315C1D004852C001A777F17E7C1C406CD097DEFE4752C0F0DE5163427C1C4001344A97FE4752C0DF8AC404357C1C40C51B9947FE4752C03A2174D0257C1C402BFBAE08FE4752C0B2683A3B197C1C40EFE2FDB8FD4752C08463963D097C1C40FB90B75CFD4752C0C3482F6AF77B1C4090F46915FD4752C035D3BD4EEA7B1C4085949F54FB4752C0F705F4C29D7B1C40FD12F1D6F94752C030BABC395C7B1C405778978BF84752C0CAFB389A237B1C40FF942A51F64752C0200A664CC17A1C40FA25E2ADF34752C04356B77A4E7A1C40D769A4A5F24752C05AD6FD63217A1C40F6D03E56F04752C00B98C0ADBB791C409D9FE238F04752C0D235936FB6791C40446E861BF04752C01CB28174B1791C400E2DB29DEF4752C0ABD0402C9B791C4003B34291EE4752C0728BF9B9A1791C40B612BA4BE24752C0C18F6AD8EF791C40F81BEDB8E14752C0EE77280AF4791C40DA1CE736E14752C01C60E63BF8791C409370218FE04752C0603C8386FE791C40E7E44526E04752C010035DFB027A1C40B1A371A8DF4752C0D200DE02097A1C40768BC058DF4752C0FFE89B340D7A1C40B2BD16F4DE4752C0BB29E5B5127A1C4094BE1072DE4752C00A80F10C1A7A1C40E275FD82DD4752C07C444C89247A1C4060B1868BDC4752C05AF3E32F2D7A1C4090696D1ADB4752C0C6FA0626377A1C40202A8D98D94752C0A4A99ECC3F7A1C408066101FD84752C065A71FD4457A1C4068588CBAD64752C082583673487A1C4081CEA44DD54752C07C9BFEEC477A1C40A6F27684D34752C060EAE74D457A1C40F38FBE49D34752C0F3E2C4573B7A1C409CE09BA6CF4752C09F73B7EBA5791C403D0CAD4ECE4752C0CDCAF6216F791C40D252793BC24752C04A9A3FA6B5791C40BB2A508BC14752C07782FDD7B9791C40D11E2FA4C34752C055DFF945097A1C403596B036C64752C07CF2B0506B7A1C40B874CC79C64752C0E8F9D346757A1C4005F86EF3C64752C0AFD172A0877A1C40B85A272EC74752C00F5F268A907A1C40581EA4A7C84752C0706072A3C87A1C40FED2A23EC94752C06420CF2EDF7A1C40AA2A3410CB4752C053978C63247B1C40215B96AFCB4752C0D5AF743E3C7B1C40315EF3AACE4752C0D4D17135B27B1C40F5F75278D04752C0DA3C0E83F97B1C4012F758FAD04752C0AC8E1CE90C7C1C4095D5743DD14752C01E537765177C1C409A5E622CD34752C0D94125AE637C1C40B01EF7ADD64752C0BBECD79DEE7C1C40037976F9D64752C0392BA226FA7C1C406E15C440D74752C0B0AC3429057D1C4038BA4A77D74752C0889E94490D7D1C40E52B8194D84752C0EE3F321D3A7D1C40CC9BC3B5DA4752C00ABC934F8F7D1C40B9E2E2A8DC4752C0D6E1E82ADD7D1C406420CF2EDF4752C014E97E4E417E1C40572426A8E14752C0D5CE30B5A57E1C40570A815CE24752C00E6B2A8BC27E1C4014E7A8A3E34752C04641F0F8F67E1C40207BBDFBE34752C090F7AA95097F1C404451A04FE44752C0C976BE9F1A7F1C40D2C3D0EAE44752C0293E3E213B7F1C40261E5036E54752C06D37C1374D7F1C402A8D98D9E74752C028D4D347E07F1C402368CC24EA4752C099BA2BBB60801C408DD0CFD4EB4752C03DD2E0B6B6801C40F71E2E39EE4752C07099D36531811C40A376BF0AF04752C069C4CC3E8F811C406CCD565EF24752C00876FC1708821C4065C22FF5F34752C06DE2E47E87821C405323F433F54752C0280B5F5FEB821C4052EFA99CF64752C0EFCA2E185C831C409981CAF8F74752C082E50819C8831C40F17EDC7EF94752C02C11A8FE41841C40F7216FB9FA4752C053245F09A4841C40EA5910CAFB4752C06FA0C03BF9841C40253E7782FD4752C04014CC9882851C40A245B6F3FD4752C0BD8C62B9A5851C40070B2769FE4752C0C85D8429CA851C4019761893FE4752C0D9B11188D7851C40C64FE3DEFC4752C034828DEBDF851C409DD66D50FB4752C04B9352D0ED851C403F027FF8F94752C0126BF12900861C40575EF23FF94752C0AB5AD2510E861C40939048DBF84752C012A5BDC117861C4087FC3383F84752C07EACE0B721861C40813FFCFCF74752C0613596B036861C4058923CD7F74752C056D80C7041861C402EE57CB1F74752C0CD599F724C861C40A52F849CF74752C03F3BE0BA62861C40B79A75C6F74752C0B01C210379861C40DA70581AF84752C0882B67EF8C861C40E02D90A0F84752C055C03DCF9F861C40F855B950F94752C093FC885FB1861C4021E9D32AFA4752C03E23111AC1861C403811FDDAFA4752C0274C18CDCA861C400873BB97FB4752C0821C9430D3861C40856055BDFC4752C0EE23B726DD861C405A7F4B00FE4752C03E7AC37DE4861C40E9D7D64FFF4752C0E883656CE8861C4047ACC5A7004852C0F4FDD478E9861C40BDC282FB014852C05A2BDA1CE7861C40B7EBA529024852C0F9D7F2CAF5861C40056F48A3024852C0271763601D871C40E17EC003034852C0F98557923C871C40213A048E044852C05EF23FF9BB871C4086E5CFB7054852C0E675C4211B881C403EEB1A2D074852C00249D8B793881C405BD07B63084852C0C32E8A1EF8881C4001857AFA084852C04B3E761728891C4030BB270F0B4852C0051555BFD2891C40FA4509FA0B4852C03E25E7C41E8A1C404D86E3F90C4852C0CB48BDA7728A1C4082AD122C0E4852C081B4FF01D68A1C4022718FA50F4852C02AE09EE74F8B1C403F56F0DB104852C0F18288D4B48B1C40A301BC05124852C0075F984C158C1C40325A4755134852C0A036AAD3818C1C4079060DFD134852C0EF004F5AB88C1C40	\N	#3BF79F	1	\N	\N	\N	\N	t	2026-04-25 00:12:05.297406-05	\N	1	\N	0	f
63	cr 24 exclus	0102000020E610000023000000CFF3A78DEA4752C032FFE89B348D1C40293FA9F6E94752C09F758D96038D1C40E2AC889AE84752C07288B839958C1C4048A643A7E74752C08F6E8445458C1C40C5C72764E74752C03A3E5A9C318C1C4048C0E8F2E64752C02F6D382C0D8C1C4090A0F831E64752C09BC6F65AD08B1C406DFE5F75E44752C0A2276552438B1C40037CB779E34752C03672DD94F28A1C40698F17D2E14752C0048E041A6C8A1C40E6B0FB8EE14752C021054F21578A1C40BD1DE1B4E04752C0A435069D108A1C40529B38B9DF4752C0C7D8092FC1891C4088F6B182DF4752C0889CBE9EAF891C400BEF7211DF4752C08388D4B48B891C4029081EDFDE4752C0D8614CFA7B891C405E6397A8DE4752C01D041DAD6A891C40AC00DF6DDE4752C04AB20E4757891C40F99D2633DE4752C001FC53AA44891C4030134548DD4752C056444DF4F9881C40B325AB22DC4752C0EB71DF6A9D881C405B28999CDA4752C01FD8F15F20881C400EBF9B6ED94752C009FCE1E7BF871C40DF6E490ED84752C04EB6813B50871C4098DC28B2D64752C09EEA909BE1861C40F8325184D44752C08F006E162F861C40F37519FED34752C04510E7E104861C4053B29C84D24752C0B2D826158D851C407D93A641D14752C0D5415E0F26851C40DDE9CE13CF4752C037FFAF3A72841C40724D81CCCE4752C03D821B295B841C40C0EAC891CE4752C0F888981249841C40DE03745FCE4752C0CB83F41439841C40FC1C1F2DCE4752C09204E10A28841C40A9F6E978CC4752C0CC0A45BA9F831C40	\N	#3BF773	1	\N	\N	\N	\N	t	2026-04-29 19:27:08.391358-05	\N	1	\N	0	f
54	ruta 30-27	0102000020E6100000C2000000CA4E3FA88B4752C07E71A94A5B8C1C40836E2F698C4752C03B8BDEA9808B1C40C45DBD8A8C4752C07A53910A638B1C4017B83CD68C4752C0BF81C98D228B1C404DF910548D4752C0871A8524B38A1C40BE6C3B6D8D4752C02C2D23F59E8A1C40179E978A8D4752C0F3565D876A8A1C40A053909F8D4752C049F60835438A1C40F984ECBC8D4752C049D92269378A1C402332ACE28D4752C03E42CD902A8A1C408ECEF9298E4752C03868AF3E1E8A1C40221807978E4752C03E0801F9128A1C4045D4449F8F4752C0CC43A67C088A1C409EEBFB70904752C02D978DCEF9891C40BCEA01F3904752C0EE5A423EE8891C40B6132521914752C0D28C45D3D9891C40CE55F31C914752C0B00111E2CA891C40EB6E9EEA904752C0171230BABC891C40E0DA8992904752C017F549EEB0891C407B15191D904752C0A530EF71A6891C4045D4449F8F4752C0501DAB949E891C409F1F46088F4752C00684D6C397891C401D5BCF108E4752C0390CE6AF90891C40BE6C3B6D8D4752C0D3C1FA3F87891C4029232E008D4752C0EF552B137E891C405F7EA7C98C4752C0AB798EC877891C4094D920938C4752C0C25087156E891C40BEA085048C4752C0EA07759142891C40B340BB438A4752C018946934B9881C406DAE9AE7884752C091F3FE3F4E881C40E42CEC69874752C01A6D5512D9871C40D9CC21A9854752C0CBD765F84F871C40878C47A9844752C0715985CD00871C403A3DEFC6824752C0AB4203B16C861C4088F4DBD7814752C00C056C0723861C40A741D13C804752C03AAE4676A5851C40721AA20A7F4752C03BC6151747851C40315F5E807D4752C09C14E63DCE841C40738236397C4752C064CA87A06A841C403E5B07077B4752C065E256410C841C406EDFA3FE7A4752C0C652245F09841C404A09C1AA7A4752C021CCED5EEE831C40B6BFB33D7A4752C08D5F7825C9831C4074D0251C7A4752C0D20149D8B7831C40A454C2137A4752C088687407B1831C40EB1A2D077A4752C0B5334C6DA9831C404B2366F6794752C027BEDA519C831C40D9AF3BDD794752C01C0A9FAD83831C402176A6D0794752C01CEDB8E177831C404B3D0B42794752C061FE0A992B831C40AA454431794752C0679E5C5320831C405114E813794752C01D05888219831C406F2D93E1784752C0C2340C1F11831C4081B22957784752C01DCBBBEA01831C40ED82C135774752C0C2C073EFE1821C408925E5EE734752C057EE056685821C4037FFAF3A724752C04B00FE2955821C40CC96AC8A704752C0C9AD49B725821C4092E68F696D4752C09180D1E5CD811C40ED65DB696B4752C0307F85CC95811C404833164D674752C0C5724BAB21811C40075E2D77664752C0E7A6CD380D811C40312592E8654752C0D1950854FF801C40EA78CC40654752C020B24813EF801C40508C2C99634752C0A41CCC26C0801C40058BC3995F4752C0D2E28C614E801C400727A25F5B4752C0BCCCB051D67F1C40EBC37AA3564752C08AE8D7D64F7F1C40A67F492A534752C0DA39CD02ED7E1C408411FB04504752C091D5AD9E937E1C409DA1B8E34D4752C003ECA353577E1C40742843554C4752C0A3073E062B7E1C40D34A21904B4752C037E33444157E1C4080D6FCF84B4752C0ED4960730E7E1C401E32E543504752C0DC645419C67D1C404208C897504752C0A30227DBC07D1C408F71C5C5514752C0548F34B8AD7D1C40ED45B41D534752C0EE27637C987D1C4034D8D479544752C0105CE509847D1C4051BD35B0554752C05ABBED42737D1C406D54A703594752C00B0E2F88487D1C402B31CF4A5A4752C06B6116DA397D1C4090DC9A745B4752C06687F8872D7D1C40E6577380604752C066136058FE7C1C403F6F2A52614752C094DE37BEF67C1C4057975302624752C0CD237F30F07C1C40D94125AE634752C02D776682E17C1C4017618A72694752C0001B1021AE7C1C4040C05AB56B4752C0A52DAEF1997C1C4074999A046F4752C0780B24287E7C1C40EAAF5758704752C0959F54FB747C1C407FDFBF79714752C0C82764E76D7C1C40723106D6714752C02E55698B6B7C1C4053CA6B25744752C01844A4A65D7C1C4071C971A7744752C0F5D555815A7C1C40177E703E754752C05089EB18577C1C40DC4B1AA3754752C023DBF97E6A7C1C40751E15FF774752C0C74961DEE37C1C40D40CA9A2784752C0B0AC3429057D1C40E0A0BDFA784752C0EEE87FB9167D1C4033FB3C46794752C01631EC30267D1C40C26D6DE1794752C03E963E74417D1C40A9DDAF027C4752C054724EECA17D1C40AE80423D7D4752C02CD8463CD97D1C40E998F38C7D4752C048A643A7E77D1C400D6FD6E07D4752C0E7525C55F67D1C401EC022BF7E4752C0A88AA9F4137E1C407100FDBE7F4752C097AAB4C5357E1C40C9C9C4AD824752C04759BF99987E1C4004AE2B66844752C0B891B245D27E1C4069739CDB844752C063B83A00E27E1C404583143C854752C06E4F90D8EE7E1C400951BEA0854752C07FA31D37FC7E1C4098C3EE3B864752C05D6F9BA9107F1C401349F4328A4752C00C7558E1967F1C40897956D28A4752C0F0FD0DDAAB7F1C40950D6B2A8B4752C06D3CD862B77F1C40A1A17F828B4752C06D59BE2EC37F1C40AD3594DA8B4752C06C76A4FACE7F1C4012FB04508C4752C094BE1072DE7F1C402EC6C03A8E4752C08EAF3DB324801C40ABCDFFAB8E4752C01C42959A3D801C40151C5E10914752C0051901158E801C40BBB6B75B924752C0BAF3C473B6801C40250516C0944752C0A987687407811C406B7D91D0964752C09DBB5D2F4D811C40FAD51C20984752C0863B17467A811C403A9160AA994752C0635E471CB2811C402EE3A6069A4752C08BA6B393C1811C40B1C1C2499A4752C09180D1E5CD811C402235ED629A4752C0852348A5D8811C40DB6E826F9A4752C04CDE0033DF811C40DB6E826F9A4752C069C9E369F9811C40C90391459A4752C06803B00111821C40D5B14AE9994752C0D427B9C326821C404C16F71F994752C007077B1343821C40294014CC984752C04660AC6F60821C40B8CCE9B2984752C095F0845E7F821C4011FE45D0984752C07E3672DD94821C4005508C2C994752C078B306EFAB821C40ED0DBE30994752C0014F5AB8AC821C40224F92AE994752C050C24CDBBF821C400AF31E679A4752C023145B41D3821C404BC8073D9B4752C0459F8F32E2821C40B64AB0389C4752C0D314014EEF821C408C69A67B9D4752C06C04E275FD821C400E2E1D739E4752C0A5660FB402831C40672B2FF99F4752C044300E2E1D831C408A01124DA04752C011A8FE4124831C40F59D5F94A04752C0008E3D7B2E831C40D784B4C6A04752C011E2CAD93B831C405A63D009A14752C04F58E20165831C40309C6B98A14752C049A0C1A6CE831C4054724EECA14752C049F7730AF2831C401E17D522A24752C08176871403841C409B1E1494A24752C00F26C5C727841C400C789961A34752C09DF2E84658841C4094F947DFA44752C08C868C47A9841C40ED2AA4FCA44752C0FD4AE7C3B3841C40884B8E3BA54752C07AA69718CB841C40226C787AA54752C0F701486DE2841C40BD72BD6DA64752C0DA38622D3E851C4051A2258FA74752C0731074B4AA851C401AF9BCE2A94752C06C7A50508A861C4056116E32AA4752C0336FD575A8861C40D8BB3FDEAB4752C0041DAD6A49871C4013D4F02DAC4752C04833164D67871C407E703E75AC4752C0F833BC5983871C40A703594FAD4752C07520EBA9D5871C40548F34B8AD4752C02BFBAE08FE871C40309FAC18AE4752C0BE67244223881C40A112D731AE4752C02A6F47382D881C400CAF2479AE4752C0C93846B247881C40BE11DDB3AE4752C058CB9D9960881C409AED0A7DB04752C0DF3653211E891C401DCC26C0B04752C00C59DDEA39891C406F0C01C0B14752C006A1BC8FA3891C40693524EEB14752C0D235936FB6891C4093E2E313B24752C0003B376DC6891C40D4D17135B24752C08EB0A888D3891C4046459C4EB24752C0D2A92B9FE5891C40B7B8C667B24752C0EE940ED6FF891C408D0B0742B24752C08CBAD6DEA78A1C4004560E2DB24752C05837DE1D198B1C4004560E2DB24752C0471D1D57238B1C40635E471CB24752C0965B5A0D898B1C403AB187F6B14752C0016DAB59678C1C40B115342DB14752C07E8E8F16678C1C4072DC291DAC4752C0F5F23B4D668C1C40BD8C62B9A54752C0EA78CC40658C1C40E753C72AA54752C0679AB0FD648C1C401F317A6EA14752C061DD7877648C1C40B8E68EFE974752C050A6D1E4628C1C40C6302768934752C0C80A7E1B628C1C40	\N	#F7E73B	1	\N	\N	\N	\N	t	2026-04-25 00:20:04.594691-05	2026-04-25 00:20:25.043988-05	1	1	0	f
55	RUTA18 NUEVA	0102000020E6100000B500000007B64AB0384852C0F9872D3D9A8A1C40797764AC364852C0FFAECF9CF5891C403E7958A8354852C077483140A2891C40A47213B5344852C02E01F8A754891C4039F06AB9334852C0406D54A703891C4004C93B87324852C090BE49D3A0881C4081EA1F44324852C0A7785C548B881C40164ED2FC314852C0B2B8FFC874881C404CA94BC6314852C07A39ECBE63881C408104C58F314852C03BFDA02E52881C4059A5F44C2F4852C05F9B8D9598871C40894336902E4852C054909F8D5C871C40CB80B3942C4852C06631B1F9B8861C40C6DD205A2B4852C0A54BFF9254861C40F69507E9294852C01D8EAED2DD851C4033E202D0284852C046D1031F83851C4039ED2939274852C04792205C01851C403A2174D0254852C064213A048E841C40C40AB77C244852C0486B0C3A21841C407D5EF1D4234852C01B0FB6D8ED831C40A182C30B224852C099D4D00660831C40609335EA214852C02810768A55831C4095EEAEB3214852C07DE9EDCF45831C40B3075A81214852C05B5EB9DE36831C40D120054F214852C03F90BC7328831C4025AFCE31204852C0ABAFAE0AD4821C4026E318C91E4852C0A6ED5F5969821C404A07EBFF1C4852C0D55C6E30D4811C4098BED7101C4852C0809BC58B85811C4022A81ABD1A4852C0DC4944F817811C40D53E1D8F194852C0438F183DB7801C402FA4C343184852C055FB743C66801C40C4211B48174852C033FCA71B28801C4072158BDF144852C0A0FEB3E6C77F1C40AF95D05D124852C0DF180280637F1C406FF4311F104852C00D198F52097F1C406A6B44300E4852C0C98E8D40BC7E1C40FFCEF6E80D4852C0520DFB3DB17E1C40DC12B9E00C4852C0A2EF6E65897E1C40000341800C4852C0862172FA7A7E1C402AFEEF880A4852C053CE177B2F7E1C404374081C094852C0FE463B6EF87D1C4009C4EBFA054852C0E27327D87F7D1C401C7DCC07044852C0B5DD04DF347D1C40E63BF889034852C0E38BF678217D1C40B1FA230C034852C005C078060D7D1C4034F3E49A024852C02DB1321AF97C1C4059315C1D004852C001A777F17E7C1C406CD097DEFE4752C0F0DE5163427C1C4001344A97FE4752C0DF8AC404357C1C40C51B9947FE4752C03A2174D0257C1C402BFBAE08FE4752C0B2683A3B197C1C40EFE2FDB8FD4752C08463963D097C1C40FB90B75CFD4752C0C3482F6AF77B1C4090F46915FD4752C035D3BD4EEA7B1C4085949F54FB4752C0F705F4C29D7B1C40FD12F1D6F94752C030BABC395C7B1C405778978BF84752C0CAFB389A237B1C40FF942A51F64752C0200A664CC17A1C40FA25E2ADF34752C04356B77A4E7A1C40D769A4A5F24752C05AD6FD63217A1C40F6D03E56F04752C00B98C0ADBB791C409D9FE238F04752C0D235936FB6791C40446E861BF04752C01CB28174B1791C400E2DB29DEF4752C0ABD0402C9B791C4003B34291EE4752C0728BF9B9A1791C40B612BA4BE24752C0C18F6AD8EF791C40F81BEDB8E14752C0EE77280AF4791C40DA1CE736E14752C01C60E63BF8791C409370218FE04752C0603C8386FE791C40E7E44526E04752C010035DFB027A1C40B1A371A8DF4752C0D200DE02097A1C40768BC058DF4752C0FFE89B340D7A1C40B2BD16F4DE4752C0BB29E5B5127A1C4094BE1072DE4752C00A80F10C1A7A1C40E275FD82DD4752C07C444C89247A1C4060B1868BDC4752C05AF3E32F2D7A1C4090696D1ADB4752C0C6FA0626377A1C40202A8D98D94752C0A4A99ECC3F7A1C408066101FD84752C065A71FD4457A1C4068588CBAD64752C082583673487A1C4081CEA44DD54752C07C9BFEEC477A1C40A6F27684D34752C060EAE74D457A1C40F38FBE49D34752C0F3E2C4573B7A1C409CE09BA6CF4752C09F73B7EBA5791C403D0CAD4ECE4752C0CDCAF6216F791C40D252793BC24752C04A9A3FA6B5791C40BB2A508BC14752C07782FDD7B9791C40D11E2FA4C34752C055DFF945097A1C403596B036C64752C07CF2B0506B7A1C40B874CC79C64752C0E8F9D346757A1C4005F86EF3C64752C0AFD172A0877A1C40B85A272EC74752C00F5F268A907A1C40581EA4A7C84752C0706072A3C87A1C40FED2A23EC94752C06420CF2EDF7A1C40AA2A3410CB4752C053978C63247B1C40215B96AFCB4752C0D5AF743E3C7B1C40315EF3AACE4752C0D4D17135B27B1C40F5F75278D04752C0DA3C0E83F97B1C4012F758FAD04752C0AC8E1CE90C7C1C4095D5743DD14752C01E537765177C1C409A5E622CD34752C0D94125AE637C1C40B01EF7ADD64752C0BBECD79DEE7C1C40037976F9D64752C0392BA226FA7C1C406E15C440D74752C0B0AC3429057D1C4038BA4A77D74752C0889E94490D7D1C40E52B8194D84752C0EE3F321D3A7D1C40CC9BC3B5DA4752C00ABC934F8F7D1C40B9E2E2A8DC4752C0D6E1E82ADD7D1C406420CF2EDF4752C014E97E4E417E1C40572426A8E14752C0D5CE30B5A57E1C40570A815CE24752C00E6B2A8BC27E1C4014E7A8A3E34752C04641F0F8F67E1C40207BBDFBE34752C090F7AA95097F1C404451A04FE44752C0C976BE9F1A7F1C40D2C3D0EAE44752C0293E3E213B7F1C40261E5036E54752C06D37C1374D7F1C402A8D98D9E74752C028D4D347E07F1C402368CC24EA4752C099BA2BBB60801C408DD0CFD4EB4752C03DD2E0B6B6801C40F71E2E39EE4752C07099D36531811C40A376BF0AF04752C069C4CC3E8F811C406CCD565EF24752C00876FC1708821C4065C22FF5F34752C06DE2E47E87821C405323F433F54752C0280B5F5FEB821C4052EFA99CF64752C0EFCA2E185C831C409981CAF8F74752C082E50819C8831C40F17EDC7EF94752C02C11A8FE41841C40F7216FB9FA4752C053245F09A4841C40EA5910CAFB4752C06FA0C03BF9841C40253E7782FD4752C04014CC9882851C40A245B6F3FD4752C0BD8C62B9A5851C40070B2769FE4752C0C85D8429CA851C4019761893FE4752C0D9B11188D7851C40C64FE3DEFC4752C034828DEBDF851C409DD66D50FB4752C04B9352D0ED851C403F027FF8F94752C0126BF12900861C40575EF23FF94752C0AB5AD2510E861C40939048DBF84752C012A5BDC117861C4087FC3383F84752C07EACE0B721861C40813FFCFCF74752C0613596B036861C4058923CD7F74752C056D80C7041861C402EE57CB1F74752C0CD599F724C861C40A52F849CF74752C03F3BE0BA62861C40B79A75C6F74752C0B01C210379861C40DA70581AF84752C0882B67EF8C861C40E02D90A0F84752C055C03DCF9F861C40F855B950F94752C093FC885FB1861C4021E9D32AFA4752C03E23111AC1861C403811FDDAFA4752C0274C18CDCA861C400873BB97FB4752C0821C9430D3861C40856055BDFC4752C0EE23B726DD861C405A7F4B00FE4752C03E7AC37DE4861C40E9D7D64FFF4752C0E883656CE8861C4047ACC5A7004852C0F4FDD478E9861C40BDC282FB014852C05A2BDA1CE7861C40B7EBA529024852C0F9D7F2CAF5861C40056F48A3024852C0271763601D871C40E17EC003034852C0F98557923C871C40213A048E044852C05EF23FF9BB871C4086E5CFB7054852C0E675C4211B881C403EEB1A2D074852C00249D8B793881C405BD07B63084852C0C32E8A1EF8881C4001857AFA084852C04B3E761728891C4030BB270F0B4852C0051555BFD2891C40FA4509FA0B4852C03E25E7C41E8A1C404D86E3F90C4852C0CB48BDA7728A1C4082AD122C0E4852C081B4FF01D68A1C4022718FA50F4852C02AE09EE74F8B1C403F56F0DB104852C0F18288D4B48B1C40A301BC05124852C0075F984C158C1C40325A4755134852C0A036AAD3818C1C4079060DFD134852C0EF004F5AB88C1C4007793D98144852C01C5DA5BBEB8C1C4061AA99B5144852C0772D211FF48C1C4089230F44164852C07C293C68768D1C406519E258174852C04E29AF95D08D1C406A882AFC194852C013EE9579AB8E1C403FA7203F1B4852C090149161158F1C403F73D6A71C4852C084BC1E4C8A8F1C40EBE40CC51D4852C067F3380CE68F1C40	\N	#E9B701	1	\N	\N	\N	\N	t	2026-04-25 01:22:45.667582-05	\N	1	\N	0	f
56	ruta rompoy	0102000020E610000076000000A245B6F3FD4752C0BD8C62B9A5851C40070B2769FE4752C0C85D8429CA851C4019761893FE4752C0D9B11188D7851C40C64FE3DEFC4752C034828DEBDF851C409DD66D50FB4752C04B9352D0ED851C403F027FF8F94752C0126BF12900861C40575EF23FF94752C0AB5AD2510E861C40939048DBF84752C012A5BDC117861C4087FC3383F84752C07EACE0B721861C40813FFCFCF74752C0613596B036861C4058923CD7F74752C056D80C7041861C402EE57CB1F74752C0CD599F724C861C40A52F849CF74752C03F3BE0BA62861C40B79A75C6F74752C0B01C210379861C40DA70581AF84752C0882B67EF8C861C40E02D90A0F84752C055C03DCF9F861C40F855B950F94752C093FC885FB1861C4021E9D32AFA4752C03E23111AC1861C403811FDDAFA4752C0274C18CDCA861C400873BB97FB4752C0821C9430D3861C40856055BDFC4752C0EE23B726DD861C405A7F4B00FE4752C03E7AC37DE4861C40E9D7D64FFF4752C0E883656CE8861C4047ACC5A7004852C0F4FDD478E9861C40BDC282FB014852C05A2BDA1CE7861C40B7EBA529024852C0F9D7F2CAF5861C40056F48A3024852C0271763601D871C40E17EC003034852C0F98557923C871C40213A048E044852C05EF23FF9BB871C4086E5CFB7054852C0E675C4211B881C403EEB1A2D074852C00249D8B793881C405BD07B63084852C0C32E8A1EF8881C4001857AFA084852C04B3E761728891C4030BB270F0B4852C0051555BFD2891C40FA4509FA0B4852C03E25E7C41E8A1C404D86E3F90C4852C0CB48BDA7728A1C4082AD122C0E4852C081B4FF01D68A1C4022718FA50F4852C02AE09EE74F8B1C403F56F0DB104852C0F18288D4B48B1C40A301BC05124852C0075F984C158C1C40325A4755134852C0A036AAD3818C1C4079060DFD134852C0EF004F5AB88C1C4007793D98144852C01C5DA5BBEB8C1C4061AA99B5144852C0772D211FF48C1C4089230F44164852C07C293C68768D1C406519E258174852C04E29AF95D08D1C4019ADA3AA094852C01AF8510DFB8D1C40F6F065A2084852C0F30181CEA48D1C40143E5B07074852C0C11DA8531E8D1C40A3CA30EE064852C0664D2CF0158D1C40BC404981054852C0DE8FDB2F9F8C1C403F53AF5B044852C0514F1F813F8C1C403AB01C21034852C073B8567BD88B1C408E3EE603024852C0F7AE415F7A8B1C40899B53C9004852C0C4211B48178B1C40309E4143FF4752C0153944DC9C8A1C40BF44BC75FE4752C03DB665C0598A1C405A7F4B00FE4752C0276BD443348A1C40FCAA5CA8FC4752C088D68A36C7891C40D9EE1EA0FB4752C0834E081D74891C409EF0129CFA4752C09A779CA223891C40F17EDC7EF94752C0BDFDB968C8881C4010CCD1E3F74752C03BE0BA6246881C40BD715298F74752C0B30A9B012E881C4047753A90F54752C01AA20A7F86871C40658EE55DF54752C07638BA4A77871C406B65C22FF54752C0D1CE691668871C40A0C03BF9F44752C0984F560C57871C40A69718CBF44752C0ED28CE5147871C40F44E05DCF34752C0AA9ECC3FFA861C40AEBCE47FF24752C066BD18CA89861C4097AE601BF14752C0F5F3A62215861C40DE8E705AF04752C040DF162CD5851C406D1B4641F04752C06DAAEE91CD851C4014EAE923F04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C40FDC1C073EF4752C035B742588D851C40390EBC5AEE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C4094DBF63DEA4752C05471E316F3831C40D027F224E94752C07CB4386398831C40D732198EE74752C078B81D1A16831C40D28F8653E64752C0B115342DB1821C4091D442C9E44752C05723BBD232821C40EC87D860E14752C0F2423A3C84811C40B77A4E7ADF4752C053E8BCC62E811C4012143FC6DC4752C0AF795567B5801C40388600E0D84752C0C1FD800706801C405C76887FD84752C0897E6DFDF47F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C08AE6012CF27B1C40D4EE5701BE4752C02A711DE38A7B1C40171230BABC4752C05E85949F547B1C40A7069ACFB94752C02BBEA1F0D97A1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C40C539EAE8B84752C0A3CB9BC3B57A1C405C1FD61BB54752C0C020E9D32A7A1C4068E7340BB44752C016C09481037A1C400B613596B04752C05B5D4E0988791C4011381268B04752C01781B1BE81791C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-25 03:00:43.020119-05	\N	1	\N	0	f
57	ruta directa2	0102000020E610000057000000D027F224E94752C07CB4386398831C40D732198EE74752C078B81D1A16831C40D28F8653E64752C0B115342DB1821C4091D442C9E44752C05723BBD232821C40EC87D860E14752C0F2423A3C84811C40B77A4E7ADF4752C053E8BCC62E811C4012143FC6DC4752C0AF795567B5801C40388600E0D84752C0C1FD800706801C405C76887FD84752C0897E6DFDF47F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C08AE6012CF27B1C40D4EE5701BE4752C02A711DE38A7B1C40171230BABC4752C05E85949F547B1C40A7069ACFB94752C02BBEA1F0D97A1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C40C539EAE8B84752C0A3CB9BC3B57A1C405C1FD61BB54752C0C020E9D32A7A1C4068E7340BB44752C016C09481037A1C400B613596B04752C05B5D4E0988791C4011381268B04752C01781B1BE81791C40603DEE5BAD4752C0F05014E813791C4062D9CC21A94752C01920D1048A781C40CEDDAE97A64752C01955867137781C4082A8FB00A44752C0F81BEDB8E1771C408F56B5A4A34752C0F8FE06EDD5771C40185A9D9CA14752C0530438BD8B771C40DD41EC4CA14752C0DC82A5BA80771C40C042E6CAA04752C015AB06616E771C4055A69883A04752C0A9A3E36A64771C40D8D2A3A99E4752C06BF3FFAA23771C406893C3279D4752C0321D3A3DEF761C406E6AA0F99C4752C0F4FDD478E9761C40BC07E8BE9C4752C0992D5915E1761C404BAE62F19B4752C06B0BCF4BC5761C40166D8E739B4752C0B0AD9FFEB3761C40ECBFCE4D9B4752C0FA298E03AF761C40462575029A4752C011AAD4EC81761C4088484DBB984752C0AB08371955761C406CCB80B3944752C0BDE3141DC9751C407F8461C0924752C05DC5E23785751C40753E3C4B904752C03B8C497F2F751C407558E1968F4752C01327F73B14751C4010AD156D8E4752C0AD855968E7741C40E1421EC18D4752C014799274CD741C404165FCFB8C4752C0534145D5AF741C408F5033A48A4752C07B849A2155741C40EF8CB62A894752C0D106600322741C40C1560916874752C0C02154A9D9731C40234910AE804752C092AD2EA704741C40008DD2A57F4752C00A9E42AED4731C4018CFA0A17F4752C08202EFE4D3731C401903EB387E4752C0BBB6B75B92731C40F67AF7C77B4752C0679E5C5320731C401B8524B37A4752C0C2DD59BBED721C4015C8EC2C7A4752C0B7291E17D5721C4087890629784752C0469A780778721C40DB17D00B774752C090A2CEDC43721C40F964C570754752C0630CACE3F8711C40B3EC4960734752C041F0F8F6AE711C401A1A4F04714752C031EE06D15A711C40B554DE8E704752C07590D78349711C4061FA5E43704752C05F7F129F3B711C405C7171546E4752C08D62B9A5D5701C407044F7AC6B4752C0A4FACE2F4A701C407769C361694752C05B5CE333D96F1C40779D0DF9674752C06728EE78936F1C40EFE714E4674752C03FFD67CD8F6F1C4066321CCF674752C01215AA9B8B6F1C40D1E80E62674752C034492C29776F1C400744882B674752C0BDC799266C6F1C404F3E3DB6654752C0357EE195246F1C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-25 03:13:56.814312-05	\N	1	\N	0	f
58	ruta Z	0102000020E61000005200000072158BDF144852C0A0FEB3E6C77F1C40AF95D05D124852C0DF180280637F1C406FF4311F104852C00D198F52097F1C406A6B44300E4852C0C98E8D40BC7E1C40FFCEF6E80D4852C0520DFB3DB17E1C40DC12B9E00C4852C0A2EF6E65897E1C40000341800C4852C0862172FA7A7E1C402AFEEF880A4852C053CE177B2F7E1C404374081C094852C0FE463B6EF87D1C4009C4EBFA054852C0E27327D87F7D1C401C7DCC07044852C0B5DD04DF347D1C40E63BF889034852C0E38BF678217D1C40B1FA230C034852C005C078060D7D1C4034F3E49A024852C02DB1321AF97C1C4059315C1D004852C001A777F17E7C1C406CD097DEFE4752C0F0DE5163427C1C4001344A97FE4752C0DF8AC404357C1C40C51B9947FE4752C03A2174D0257C1C402BFBAE08FE4752C0B2683A3B197C1C40EFE2FDB8FD4752C08463963D097C1C40FB90B75CFD4752C0C3482F6AF77B1C4090F46915FD4752C035D3BD4EEA7B1C4085949F54FB4752C0F705F4C29D7B1C40FD12F1D6F94752C030BABC395C7B1C405778978BF84752C0CAFB389A237B1C40FF942A51F64752C0200A664CC17A1C40FA25E2ADF34752C04356B77A4E7A1C40D769A4A5F24752C05AD6FD63217A1C40D769A4A5F24752C05AD6FD63217A1C406F8B0576E14752C07B302FB6A67E1C40572426A8E14752C0D5CE30B5A57E1C40570A815CE24752C00E6B2A8BC27E1C4014E7A8A3E34752C04641F0F8F67E1C40207BBDFBE34752C090F7AA95097F1C404451A04FE44752C0C976BE9F1A7F1C400953944BE34752C06EE00ED4297F1C40FC3905F9D94752C0DEE34C13B67F1C400EBF9B6ED94752C039B4C876BE7F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C08AE6012CF27B1C40D4EE5701BE4752C02A711DE38A7B1C40171230BABC4752C05E85949F547B1C40A7069ACFB94752C02BBEA1F0D97A1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C40C539EAE8B84752C0A3CB9BC3B57A1C405C1FD61BB54752C0C020E9D32A7A1C4068E7340BB44752C016C09481037A1C400B613596B04752C05B5D4E0988791C4011381268B04752C01781B1BE81791C40603DEE5BAD4752C0F05014E813791C4062D9CC21A94752C01920D1048A781C40CEDDAE97A64752C01955867137781C4082A8FB00A44752C0F81BEDB8E1771C408F56B5A4A34752C0F8FE06EDD5771C40185A9D9CA14752C0530438BD8B771C40DD41EC4CA14752C0DC82A5BA80771C40C042E6CAA04752C015AB06616E771C4055A69883A04752C0A9A3E36A64771C40D8D2A3A99E4752C06BF3FFAA23771C406893C3279D4752C0321D3A3DEF761C406E6AA0F99C4752C0F4FDD478E9761C40BC07E8BE9C4752C0992D5915E1761C404BAE62F19B4752C06B0BCF4BC5761C40166D8E739B4752C0B0AD9FFEB3761C40ECBFCE4D9B4752C0FA298E03AF761C40462575029A4752C011AAD4EC81761C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-25 03:15:08.63784-05	\N	1	\N	0	f
59	ruta centro comercial cacique	0102000020E6100000EE0000008E59F624B04752C0F777B6476F881C409430D3F6AF4752C0355D4F745D881C40F90FE9B7AF4752C01F2FA4C343881C408E739B70AF4752C00801F9122A881C4089B663EAAE4752C0ECDB4944F8871C40367689EAAD4752C06A15FDA199871C40B3976DA7AD4752C0D6C56D3480871C40603DEE5BAD4752C0A9A3E36A64871C4024253D0CAD4752C0E2AE5E4546871C404F20EC14AB4752C0009013268C861C40AE282504AB4752C039D55A9885861C4015562AA8A84752C03AAE4676A5851C40E61F7D93A64752C05872158BDF841C404CFF9254A64752C0537B116DC7841C40815A0C1EA64752C0DBDC989EB0841C409F73B7EBA54752C06FB88FDC9A841C4076FA415DA44752C0658BA4DDE8831C40533E0455A34752C0CD3FFA264D831C40124F7633A34752C0BCCE86FC33831C40E2CAD93BA34752C0EF39B01C21831C400C789961A34752C0EF1CCA5015831C4006A1BC8FA34752C03F390A1005831C40FAF202ECA34752C0BC202235ED821C40D02B9E7AA44752C056D636C5E3821C408E226B0DA54752C03A083A5AD5821C40645B069CA54752C06D73637AC2821C406A183E22A64752C07E703E75AC821C40ECF65965A64752C0A087DA368C821C4093C5FD47A64752C00D384BC972821C4070EF1AF4A54752C0F609A01859821C4058C7F143A54752C05DFDD8243F821C40CA54C1A8A44752C02A3BFDA02E821C4082A8FB00A44752C01EA4A7C821821C4089997D1EA34752C08B71FE2614821C40E8BB5B59A24752C02AE44A3D0B821C4066F7E461A14752C052F2EA1C03821C403D64CA87A04752C0240A2DEBFE811C40DE8FDB2F9F4752C0FDC1C073EF811C40F6EB4E779E4752C0081F4AB4E4811C40A968ACFD9D4752C0302DEA93DC811C405CE509849D4752C04CC11A67D3811C4027A435069D4752C0B98E71C5C5811C4086AC6EF59C4752C0A29A92ACC3811C40F16261889C4752C09146054EB6811C40168733BF9A4752C0D6743DD175811C40E15F048D994752C0EDF483BA48811C40236937FA984752C08C4AEA0434811C40F4FE3F4E984752C00475CAA31B811C4066C0594A964752C0376C5B94D9801C4025EB7074954752C09E5F94A0BF801C4085419946934752C0821DFF0582801C40D42CD0EE904752C06C7BBB2539801C40514EB4AB904752C0880FECF82F801C401C2785798F4752C050560C5707801C400BF0DDE68D4752C094A12AA6D27F1C408811C2A38D4752C0341477BCC97F1C400533A6608D4752C0D386C3D2C07F1C40E25CC30C8D4752C05C0531D0B57F1C406B2C616D8C4752C072BF4351A07F1C40836E2F698C4752C06D020CCB9F7F1C407976F9D6874752C0DA73999A047F1C40F697DD93874752C0F607CA6DFB7E1C4002469737874752C0740CC85EEF7E1C400EF450DB864752C06E32AA0CE37E1C404A26A776864752C0E0BC38F1D57E1C404162BB7B804752C0C51EDAC70A7E1C40D0EE9062804752C0A3B08BA2077E1C402463B5F97F4752C08C9FC6BDF97D1C408F19A88C7F4752C06A1492CCEA7D1C4060AFB0E07E4752C026FE28EACC7D1C4044183F8D7B4752C05A2A6F47387D1C4091B586527B4752C06B44300E2E7D1C4050C6F8307B4752C0B003E78C287D1C402CF015DD7A4752C08E78B29B197D1C406EF9484A7A4752C0CC4065FCFB7C1C40BDFE243E774752C03F6F2A52617C1C40C3D50110774752C062C092AB587C1C40117349D5764752C0EA3E00A94D7C1C401D210379764752C0349E08E23C7C1C40946B0A64764752C08A9466F3387C1C40A019C407764752C056D28A6F287C1C401764CBF2754752C0B742588D257C1C403DD68C0C724752C08507CDAE7B7B1C40792288F3704752C0FDF7E0B54B7B1C4085D04197704752C04D1421753B7B1C408CF50D4C6E4752C081B4FF01D67A1C40CEFE40B96D4752C00FD3BEB9BF7A1C4075CDE49B6D4752C05F0CE544BB7A1C40045ABA826D4752C0B4024356B77A1C4075E789E76C4752C0BA85AE44A07A1C40C284D1AC6C4752C05FB532E1977A1C408D43FD2E6C4752C00F4240BE847A1C408D43FD2E6C4752C08D63247B847A1C409B594B01694752C0CC608C48147A1C40B98C9B1A684752C0446E861BF0791C405A9E0777674752C022C66B5ED5791C40664CC11A674752C0D80FB1C1C2791C409CA73AE4664752C05BD1E638B7791C4072FA7ABE664752C08E59F624B0791C409013268C664752C02252D32EA6791C40EA5E27F5654752C01D3EE94482791C407FC2D9AD654752C0F5D8960167791C405BECF659654752C0236AA2CF47791C409161156F644752C03A596ABDDF781C40E5D53906644752C04C1C7920B2781C4044DE72F5634752C0D49AE61DA7781C408BA4DDE8634752C07F87A2409F781C401A31B3CF634752C06876DD5B91781C40508C2C99634752C0683C11C479781C4026DF6C73634752C019C91EA166781C40567DAEB6624752C0ADF6B0170A781C40452C62D8614752C097FDBAD39D771C40A4349BC7614752C03C2D3F7095771C401B7FA2B2614752C0488AC8B08A771C4099A0866F614752C0F33CB83B6B771C4034DB15FA604752C0E831CA332F771C40702711E15F4752C0D89E5912A0761C40888384285F4752C0672C9ACE4E761C405F0A0F9A5D4752C0E59A02999D751C40B37E33315D4752C0CF328B506C751C401E3526C45C4752C024B5503239751C4013BBB6B75B4752C0581B6327BC741C4090DC9A745B4752C0CA6B257497741C401F69705B5B4752C03CF6B3588A741C4036AB3E575B4752C09D66817687741C40F5BBB0355B4752C0D68EE21C75741C405A9BC6F65A4752C06490BB0853741C407E8B4E965A4752C032772D211F741C400D18247D5A4752C02123A0C211741C40FCC6D79E594752C02D98F8A3A8731C40F1660DDE574752C0C860C5A9D6721C40C7B94DB8574752C006465ED6C4721C400F9A5DF7564752C0A6ED5F5969721C4051A39064564752C0BE33DAAA24721C40E606431D564752C0CF13CFD902721C407B6AF5D5554752C063D2DF4BE1711C40F2B4FCC0554752C0F10D85CFD6711C4057941282554752C0BE2EC37FBA711C402E1B9DF3534752C0433D7D04FE701C407CB8E4B8534752C09EB64604E3701C40E2CB4411524752C09FC9FE791A701C4000E5EFDE514752C09F8F32E202701C4083DDB06D514752C0D960E124CD6F1C40FA27B858514752C0EF37DA71C36F1C407172BF43514752C089EDEE01BA6F1C405F07CE19514752C023861DC6A46F1C407D2079E7504752C0A06D35EB8C6F1C403C31EBC5504752C05C74B2D47A6F1C40CBD765F84F4752C0EBC726F9116F1C40CBD765F84F4752C0C328081EDF6E1C400133DFC14F4752C0BE310400C76E1C406CE9D1544F4752C0B900344A976E1C402BFA43334F4752C09C3237DF886E1C40E44D7E8B4E4752C0096F0F42406E1C4067463F1A4E4752C0033E3F8C106E1C40B4E386DF4D4752C0E7525C55F66D1C40BABA63B14D4752C015014EEFE26D1C404F1E166A4D4752C0C0B33D7AC36D1C40DEAAEB504D4752C0CB10C7BAB86D1C409DBB5D2F4D4752C0DC0DA2B5A26D1C40448A01124D4752C05AF5B9DA8A6D1C40730E9E094D4752C043E4F4F57C6D1C40FCC3961E4D4752C005A8A9656B6D1C4097E4805D4D4752C0F9F36DC1526D1C4032056B9C4D4752C0FF76D9AF3B6D1C40BABA63B14D4752C03E5C72DC296D1C4073F4F8BD4D4752C07D410B09186D1C4043705CC64D4752C0CC5D4BC8076D1C40A37895B54D4752C016BD5301F76C1C40D8D30E7F4D4752C0446B459BE36C1C400858AB764D4752C028BA2EFCE06C1C40CD3FFA264D4752C0BC95253ACB6C1C40687A89B14C4752C04AB4E4F1B46C1C40A983BC1E4C4752C0616EF7729F6C1C404A95287B4B4752C01D75745C8D6C1C40AAB706B64A4752C0BCCADAA6786C1C406FB9FAB1494752C03F6F2A52616C1C40ABEB504D494752C0EA5BE674596C1C40C347C494484752C078978BF84E6C1C40F3E505D8474752C0952BBCCB456C1C405308E412474752C0C2F693313E6C1C40CA6C9049464752C084D72E6D386C1C40363D2828454752C04B75012F336C1C40E3E2A8DC444752C0C2D9AD65326C1C403D484F91434752C0A06B5F402F6C1C40F1129CFA404752C0F661BD512B6C1C4021B1DD3D404752C0E52A16BF296C1C40390D51853F4752C0459BE3DC266C1C40E00F3FFF3D4752C0F0879FFF1E6C1C4028F04E3E3D4752C0B72572C1196C1C4038A27BD6354752C0E04BE141B36B1C403FADA23F344752C00DFAD2DB9F6B1C4056EF703B344752C08B1BB7989F6B1C40279F1EDB324752C0D57ABFD18E6B1C40ACFF73982F4752C09604A8A9656B1C408F1A13622E4752C069FF03AC556B1C40BA15C26A2C4752C03CDD79E2396B1C40D97C5C1B2A4752C0DB15FA60196B1C40DAFE9595264752C0488C9E5BE86A1C4005FA449E244752C08C118942CB6A1C40C40AB77C244752C0751DAA29C96A1C406536C824234752C015731074B46A1C409CC58B85214752C076A911FA996A1C40E4D9E55B1F4752C0D105F52D736A1C4008E412471E4752C0F9F6AE415F6A1C4032AB77B81D4752C0F31C91EF526A1C406EDDCD531D4752C0938FDD054A6A1C40FD8348861C4752C0D1747632386A1C40102384471B4752C03D7C9928426A1C4002D6AA5D134752C059BE2EC37F6A1C400E846401134752C081E9B46E836A1C4002F04FA9124752C0A9143B1A876A1C40AF95D05D124752C0CB82893F8A6A1C4027FA7C94114752C0378AAC35946A1C409E5E29CB104752C0C042E6CAA06A1C40B0E3BF40104752C0BAA29410AC6A1C404B1E4FCB0F4752C03D9E961FB86A1C40704221020E4752C03C2F151BF36A1C402F6D382C0D4752C069519FE40E6B1C40535DC0CB0C4752C0E1D231E7196B1C40A6D1E4620C4752C05E11FC6F256B1C402ACAA5F10B4752C0CA181F662F6B1C409B711AA20A4752C080D6FCF84B6B1C40C07B478D094752C0CA6FD1C9526B1C404374081C094752C069FF03AC556B1C4061A75835084752C01409A69A596B1C404A7F2F85074752C0ADDBA0F65B6B1C4020EC14AB064752C0BE1248895D6B1C400F9BC8CC054752C047AE9B525E6B1C40CEC5DFF6044752C0C4CF7F0F5E6B1C40DA8D3EE6034752C0B398D87C5C6B1C40B7D100DE024752C09CA4F9635A6B1C40E789E76C014752C080F3E2C4576B1C409B20EA3E004752C04D1421753B6B1C408A03E8F7FD4652C0C504357C0B6B1C405E9D6340F64652C0E21FB6F4686A1C404A4563EDEF4652C03E9468C9E3691C40E7012CF2EB4652C0B07092E68F691C40	\N	#3BB8F7	1	\N	\N	\N	\N	t	2026-04-25 03:16:52.635771-05	\N	1	\N	0	f
60	ruta larga	0102000020E610000012010000213A048E044852C05EF23FF9BB871C4086E5CFB7054852C0E675C4211B881C403EEB1A2D074852C00249D8B793881C405BD07B63084852C0C32E8A1EF8881C409EF0129CFA4752C09A779CA223891C40F17EDC7EF94752C0BDFDB968C8881C4010CCD1E3F74752C03BE0BA6246881C40BD715298F74752C0B30A9B012E881C4047753A90F54752C01AA20A7F86871C40658EE55DF54752C07638BA4A77871C406B65C22FF54752C0D1CE691668871C40A0C03BF9F44752C0984F560C57871C40A69718CBF44752C0ED28CE5147871C40F44E05DCF34752C0AA9ECC3FFA861C40AEBCE47FF24752C066BD18CA89861C4097AE601BF14752C0F5F3A62215861C40DE8E705AF04752C040DF162CD5851C406D1B4641F04752C06DAAEE91CD851C4014EAE923F04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C40FDC1C073EF4752C035B742588D851C40390EBC5AEE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C4094DBF63DEA4752C05471E316F3831C40D027F224E94752C07CB4386398831C40D732198EE74752C078B81D1A16831C40D28F8653E64752C0B115342DB1821C4091D442C9E44752C05723BBD232821C40AA471ADCD64752C0B24AE9995E821C40F0A5F0A0D94752C0D2DF4BE141831C40AD4ECE50DC4752C02CBAF59A1E841C40EF2076A6D04752C0C0266BD443841C40132BA391CF4752C05FB69DB646841C40DE03745FCE4752C0CB83F41439841C40FC1C1F2DCE4752C09204E10A28841C40C0046EDDCD4752C00A2FC1A90F841C404A0856D5CB4752C0A56B26DF6C831C403F74417DCB4752C0EFAD484C50831C401CEC4D0CC94752C084D6C39789821C40D656EC2FBB4752C05C1FD61BB5821C40B8205B96AF4752C0E411DC48D9821C409B3BFA5FAE4752C08F1B7E37DD821C4054A9D903AD4752C0066344A2D0821C40EBA86A82A84752C012691B7FA2821C40575F5D15A84752C05628D2FD9C821C40E02EFB75A74752C05CC823B891821C4069FE98D6A64752C040FA264D83821C4093C5FD47A64752C00D384BC972821C4070EF1AF4A54752C0F609A01859821C4058C7F143A54752C05DFDD8243F821C40CA54C1A8A44752C02A3BFDA02E821C4082A8FB00A44752C01EA4A7C821821C4089997D1EA34752C08B71FE2614821C40E8BB5B59A24752C02AE44A3D0B821C4066F7E461A14752C052F2EA1C03821C403D64CA87A04752C0240A2DEBFE811C40DE8FDB2F9F4752C0FDC1C073EF811C40F6EB4E779E4752C0081F4AB4E4811C40A968ACFD9D4752C0302DEA93DC811C405CE509849D4752C04CC11A67D3811C4027A435069D4752C0B98E71C5C5811C4086AC6EF59C4752C0A29A92ACC3811C40F16261889C4752C09146054EB6811C40168733BF9A4752C0D6743DD175811C40E15F048D994752C0EDF483BA48811C40236937FA984752C08C4AEA0434811C40F4FE3F4E984752C00475CAA31B811C4066C0594A964752C0376C5B94D9801C4025EB7074954752C09E5F94A0BF801C4085419946934752C0821DFF0582801C40D42CD0EE904752C06C7BBB2539801C40514EB4AB904752C0880FECF82F801C401C2785798F4752C050560C5707801C400BF0DDE68D4752C094A12AA6D27F1C408811C2A38D4752C0341477BCC97F1C400533A6608D4752C0D386C3D2C07F1C40E25CC30C8D4752C05C0531D0B57F1C406B2C616D8C4752C072BF4351A07F1C40836E2F698C4752C06D020CCB9F7F1C407976F9D6874752C0DA73999A047F1C40F697DD93874752C0F607CA6DFB7E1C4002469737874752C0740CC85EEF7E1C400EF450DB864752C06E32AA0CE37E1C404A26A776864752C0E0BC38F1D57E1C404162BB7B804752C0C51EDAC70A7E1C40D0EE9062804752C0A3B08BA2077E1C402463B5F97F4752C08C9FC6BDF97D1C408F19A88C7F4752C06A1492CCEA7D1C4060AFB0E07E4752C026FE28EACC7D1C4044183F8D7B4752C05A2A6F47387D1C4091B586527B4752C06B44300E2E7D1C4050C6F8307B4752C0B003E78C287D1C402CF015DD7A4752C08E78B29B197D1C406EF9484A7A4752C0CC4065FCFB7C1C40BDFE243E774752C03F6F2A52617C1C40C3D50110774752C062C092AB587C1C40117349D5764752C0EA3E00A94D7C1C401D210379764752C0349E08E23C7C1C40946B0A64764752C08A9466F3387C1C40A019C407764752C056D28A6F287C1C401764CBF2754752C0B742588D257C1C403DD68C0C724752C08507CDAE7B7B1C40792288F3704752C0FDF7E0B54B7B1C4085D04197704752C04D1421753B7B1C408CF50D4C6E4752C081B4FF01D67A1C40CEFE40B96D4752C00FD3BEB9BF7A1C4075CDE49B6D4752C05F0CE544BB7A1C40045ABA826D4752C0B4024356B77A1C4075E789E76C4752C0BA85AE44A07A1C40C284D1AC6C4752C05FB532E1977A1C408D43FD2E6C4752C00F4240BE847A1C408D43FD2E6C4752C08D63247B847A1C409B594B01694752C0CC608C48147A1C40B98C9B1A684752C0446E861BF0791C405A9E0777674752C022C66B5ED5791C40664CC11A674752C0D80FB1C1C2791C409CA73AE4664752C05BD1E638B7791C4072FA7ABE664752C08E59F624B0791C409013268C664752C02252D32EA6791C40EA5E27F5654752C01D3EE94482791C407FC2D9AD654752C0F5D8960167791C405BECF659654752C0236AA2CF47791C409161156F644752C03A596ABDDF781C40E5D53906644752C04C1C7920B2781C4044DE72F5634752C0D49AE61DA7781C408BA4DDE8634752C07F87A2409F781C401A31B3CF634752C06876DD5B91781C40508C2C99634752C0683C11C479781C4026DF6C73634752C019C91EA166781C40567DAEB6624752C0ADF6B0170A781C40452C62D8614752C097FDBAD39D771C40A4349BC7614752C03C2D3F7095771C401B7FA2B2614752C0488AC8B08A771C4099A0866F614752C0F33CB83B6B771C4034DB15FA604752C0E831CA332F771C40702711E15F4752C0D89E5912A0761C40888384285F4752C0672C9ACE4E761C405F0A0F9A5D4752C0E59A02999D751C40B37E33315D4752C0CF328B506C751C401E3526C45C4752C024B5503239751C4013BBB6B75B4752C0581B6327BC741C4090DC9A745B4752C0CA6B257497741C401F69705B5B4752C03CF6B3588A741C4036AB3E575B4752C09D66817687741C40F5BBB0355B4752C0D68EE21C75741C405A9BC6F65A4752C06490BB0853741C407E8B4E965A4752C032772D211F741C400D18247D5A4752C02123A0C211741C40FCC6D79E594752C02D98F8A3A8731C40F1660DDE574752C0C860C5A9D6721C40C7B94DB8574752C006465ED6C4721C400F9A5DF7564752C0A6ED5F5969721C4051A39064564752C0BE33DAAA24721C40E606431D564752C0CF13CFD902721C407B6AF5D5554752C063D2DF4BE1711C40F2B4FCC0554752C0F10D85CFD6711C4057941282554752C0BE2EC37FBA711C402E1B9DF3534752C0433D7D04FE701C407CB8E4B8534752C09EB64604E3701C40E2CB4411524752C09FC9FE791A701C4000E5EFDE514752C09F8F32E202701C4083DDB06D514752C0D960E124CD6F1C40FA27B858514752C0EF37DA71C36F1C407172BF43514752C089EDEE01BA6F1C405F07CE19514752C023861DC6A46F1C407D2079E7504752C0A06D35EB8C6F1C403C31EBC5504752C05C74B2D47A6F1C40CBD765F84F4752C0EBC726F9116F1C40CBD765F84F4752C0C328081EDF6E1C400133DFC14F4752C0BE310400C76E1C406CE9D1544F4752C0B900344A976E1C402BFA43334F4752C09C3237DF886E1C40E44D7E8B4E4752C0096F0F42406E1C4067463F1A4E4752C0033E3F8C106E1C40B4E386DF4D4752C0E7525C55F66D1C40BABA63B14D4752C015014EEFE26D1C404F1E166A4D4752C0C0B33D7AC36D1C40DEAAEB504D4752C0CB10C7BAB86D1C409DBB5D2F4D4752C0DC0DA2B5A26D1C40448A01124D4752C05AF5B9DA8A6D1C40730E9E094D4752C043E4F4F57C6D1C40FCC3961E4D4752C005A8A9656B6D1C4097E4805D4D4752C0F9F36DC1526D1C4032056B9C4D4752C0FF76D9AF3B6D1C40BABA63B14D4752C03E5C72DC296D1C4073F4F8BD4D4752C07D410B09186D1C4043705CC64D4752C0CC5D4BC8076D1C40A37895B54D4752C016BD5301F76C1C40D8D30E7F4D4752C0446B459BE36C1C400858AB764D4752C028BA2EFCE06C1C40CD3FFA264D4752C0BC95253ACB6C1C40687A89B14C4752C04AB4E4F1B46C1C40A983BC1E4C4752C0616EF7729F6C1C404A95287B4B4752C01D75745C8D6C1C40AAB706B64A4752C0BCCADAA6786C1C406FB9FAB1494752C03F6F2A52616C1C40ABEB504D494752C0EA5BE674596C1C40C347C494484752C078978BF84E6C1C40F3E505D8474752C0952BBCCB456C1C405308E412474752C0C2F693313E6C1C40CA6C9049464752C084D72E6D386C1C40363D2828454752C04B75012F336C1C40E3E2A8DC444752C0C2D9AD65326C1C403D484F91434752C0A06B5F402F6C1C40F1129CFA404752C0F661BD512B6C1C4021B1DD3D404752C0E52A16BF296C1C40390D51853F4752C0459BE3DC266C1C40E00F3FFF3D4752C0F0879FFF1E6C1C4028F04E3E3D4752C0B72572C1196C1C4038A27BD6354752C0E04BE141B36B1C403FADA23F344752C00DFAD2DB9F6B1C4056EF703B344752C08B1BB7989F6B1C40279F1EDB324752C0D57ABFD18E6B1C40ACFF73982F4752C09604A8A9656B1C408F1A13622E4752C069FF03AC556B1C40BA15C26A2C4752C03CDD79E2396B1C40D97C5C1B2A4752C0DB15FA60196B1C40DAFE9595264752C0488C9E5BE86A1C4005FA449E244752C08C118942CB6A1C40C40AB77C244752C0751DAA29C96A1C406536C824234752C015731074B46A1C409CC58B85214752C076A911FA996A1C40E4D9E55B1F4752C0D105F52D736A1C4008E412471E4752C0F9F6AE415F6A1C4032AB77B81D4752C0F31C91EF526A1C406EDDCD531D4752C0938FDD054A6A1C40FD8348861C4752C0D1747632386A1C40102384471B4752C03D7C9928426A1C4002D6AA5D134752C059BE2EC37F6A1C400E846401134752C081E9B46E836A1C4002F04FA9124752C0A9143B1A876A1C40AF95D05D124752C0CB82893F8A6A1C4027FA7C94114752C0378AAC35946A1C409E5E29CB104752C0C042E6CAA06A1C40B0E3BF40104752C0BAA29410AC6A1C404B1E4FCB0F4752C03D9E961FB86A1C40704221020E4752C03C2F151BF36A1C402F6D382C0D4752C069519FE40E6B1C40535DC0CB0C4752C0E1D231E7196B1C40A6D1E4620C4752C05E11FC6F256B1C402ACAA5F10B4752C0CA181F662F6B1C409B711AA20A4752C080D6FCF84B6B1C40C07B478D094752C0CA6FD1C9526B1C404374081C094752C069FF03AC556B1C4061A75835084752C01409A69A596B1C404A7F2F85074752C0ADDBA0F65B6B1C4020EC14AB064752C0BE1248895D6B1C400F9BC8CC054752C047AE9B525E6B1C40CEC5DFF6044752C0C4CF7F0F5E6B1C40DA8D3EE6034752C0B398D87C5C6B1C40B7D100DE024752C09CA4F9635A6B1C40E789E76C014752C080F3E2C4576B1C409B20EA3E004752C04D1421753B6B1C408A03E8F7FD4652C0C504357C0B6B1C405E9D6340F64652C0E21FB6F4686A1C404A4563EDEF4652C03E9468C9E3691C40F699B33EE54652C0B7D100DE02691C40D9CEF753E34652C068244223D8681C40CE88D2DEE04652C0967B8159A1681C40768BC058DF4652C0A75B76887F681C4018D1764CDD4652C0354069A851681C40B30B06D7DC4652C0C47B0E2C47681C403604C765DC4652C0B8E4B8533A681C402499D53BDC4652C00261A75835681C40E98024ECDB4652C01938A0A52B681C409CFD8172DB4652C0581D39D219681C40EF71A609DB4652C09CBF098508681C4013622EA9DA4652C0D5E76A2BF6671C4090831266DA4652C00953944BE3671C4031957EC2D94652C0D07CCEDDAE671C40852348A5D84652C0D1949D7E50671C4038BA4A77D74652C032005471E3661C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-25 03:31:38.119402-05	\N	1	\N	0	f
61	ruta cerrada	0102000020E6100000120000005ED72FD80D4852C0C49448A297811C400B630B410E4852C0D505BCCCB0811C4006BD3786004852C0302DEA93DC811C40B37C5D86FF4752C0ADBD4F55A1811C40F59F353FFE4752C00F9D9E7763811C407FBDC282FB4752C0E275FD82DD801C402575029A084852C03E5E488787801C40F5D6C056094852C00AB952CF82801C40B0C91AF5104852C07172BF4351801C40C4211B48174852C033FCA71B28801C40C1374D9F1D4852C07D21E4BCFF7F1C4088F2052D244852C03FABCC94D67F1C40F931E6AE254852C072FE261422801C40D40D1478274852C0821DFF0582801C40D97C5C1B2A4852C0A3957B8159811C4098BED7101C4852C0809BC58B85811C4022A81ABD1A4852C0DC4944F817811C404698A25C1A4852C00ADB4FC6F8801C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-25 03:33:22.705341-05	\N	1	\N	0	f
44	ruta rara	0102000020E6100000D9000000BC9179E40F4852C033A5F5B704901C40228B34F10E4852C0D369DD06B58F1C405ED72FD80D4852C06D54A703598F1C40355EBA490C4852C0639B5434D68E1C40B39943520B4852C07AC4E8B9858E1C4019ADA3AA094852C01AF8510DFB8D1C405BD07B63084852C01536035C908D1C40143E5B07074852C0C11DA8531E8D1C40A3CA30EE064852C0664D2CF0158D1C40BB26A435064852C0DE205A2BDA8C1C403F53AF5B044852C0514F1F813F8C1C403AB01C21034852C073B8567BD88B1C408E3EE603024852C0F7AE415F7A8B1C40F437A110014852C036035C902D8B1C40309E4143FF4752C0153944DC9C8A1C40BF44BC75FE4752C03DB665C0598A1C405A7F4B00FE4752C0276BD443348A1C40FCAA5CA8FC4752C088D68A36C7891C40D9EE1EA0FB4752C0834E081D74891C409EF0129CFA4752C09A779CA223891C40F17EDC7EF94752C0BDFDB968C8881C4010CCD1E3F74752C03BE0BA6246881C40BD715298F74752C0B30A9B012E881C4047753A90F54752C01AA20A7F86871C40658EE55DF54752C07638BA4A77871C406B65C22FF54752C0D1CE691668871C40A0C03BF9F44752C0984F560C57871C40A69718CBF44752C0ED28CE5147871C40F44E05DCF34752C0AA9ECC3FFA861C40AEBCE47FF24752C066BD18CA89861C4097AE601BF14752C0F5F3A62215861C40DE8E705AF04752C040DF162CD5851C406D1B4641F04752C06DAAEE91CD851C4014EAE923F04752C001A3CB9BC3851C40A94D9CDCEF4752C012A0A696AD851C40DFA815A6EF4752C05CFFAECF9C851C40FDC1C073EF4752C035B742588D851C40390EBC5AEE4752C0302FC03E3A851C405184D4EDEC4752C0A88E554ACF841C40C32B499EEB4752C09752978C63841C4094DBF63DEA4752C05471E316F3831C40D027F224E94752C07CB4386398831C40D732198EE74752C078B81D1A16831C40D28F8653E64752C0B115342DB1821C4091D442C9E44752C05723BBD232821C408C31B08EE34752C03067B62BF4811C40EC87D860E14752C0F2423A3C84811C40B77A4E7ADF4752C053E8BCC62E811C4012143FC6DC4752C0AF795567B5801C401FF64201DB4752C04F3E3DB665801C40388600E0D84752C0C1FD800706801C405C76887FD84752C0897E6DFDF47F1C4074D2FBC6D74752C0C289E8D7D67F1C408080B56AD74752C01D2098A3C77F1C407BDD2230D64752C0616BB6F2927F1C402E742502D54752C04089CF9D607F1C405298F738D34752C007793D98147F1C4088F37002D34752C0A7EB89AE0B7F1C408F183DB7D04752C00874266DAA7E1C40191C25AFCE4752C0B96FB54E5C7E1C40569C6A2DCC4752C01AF8510DFB7D1C408C2B2E8ECA4752C0210725CCB47D1C403A05F9D9C84752C0F92D3A596A7D1C40B726DD96C84752C07632384A5E7D1C4005C4245CC84752C010E84CDA547D1C4082E50819C84752C016889E94497D1C40EECF4543C64752C0336E6AA0F97C1C40F0517FBDC24752C034F5BA45607C1C40CDC98B4CC04752C08AE6012CF27B1C40D4EE5701BE4752C02A711DE38A7B1C40171230BABC4752C05E85949F547B1C40A7069ACFB94752C02BBEA1F0D97A1C40C51F459DB94752C0D6AA5D13D27A1C404818062CB94752C086376BF0BE7A1C40C539EAE8B84752C0A3CB9BC3B57A1C405C1FD61BB54752C0C020E9D32A7A1C4068E7340BB44752C016C09481037A1C400B613596B04752C05B5D4E0988791C4011381268B04752C01781B1BE81791C40603DEE5BAD4752C0F05014E813791C4062D9CC21A94752C01920D1048A781C40CEDDAE97A64752C01955867137781C4082A8FB00A44752C0F81BEDB8E1771C408F56B5A4A34752C0F8FE06EDD5771C40185A9D9CA14752C0530438BD8B771C40DD41EC4CA14752C0DC82A5BA80771C40C042E6CAA04752C015AB06616E771C4055A69883A04752C0A9A3E36A64771C40D8D2A3A99E4752C06BF3FFAA23771C406893C3279D4752C0321D3A3DEF761C406E6AA0F99C4752C0F4FDD478E9761C40BC07E8BE9C4752C0992D5915E1761C4097FDBAD39D4752C0C13BF9F4D8761C40FD2D01F8A74752C08EE89E758D761C40C2FBAA5CA84752C0B073D3669C761C403E03EACDA84752C06614CB2DAD761C40505436ACA94752C049BA66F2CD761C403D9B559FAB4752C0E23AC61517771C400740DCD5AB4752C0B56FEEAF1E771C4054C37E4FAC4752C08104C58F31771C40789961A3AC4752C00400C79E3D771C404EB857E6AD4752C0988922A46E771C4094162EABB04752C0A208A9DBD9771C401CB28174B14752C0D02A33A5F5771C40408864C8B14752C041EF8D2100781C4004560E2DB24752C0A839799109781C40B7B8C667B24752C0E658DE550F781C4093C83EC8B24752C0581D39D219781C401E6B4606B94752C0E0F76F5E9C781C403B3602F1BA4752C09015FC36C4781C40E8C1DD59BB4752C01E8B6D52D1781C404D874ECFBB4752C0BD378600E0781C40705D3123BC4752C04033880FEC781C400473F4F8BD4752C034677DCA31791C40DAAB8F87BE4752C017F032C346791C40BB2A508BC14752C07782FDD7B9791C40D11E2FA4C34752C055DFF945097A1C403596B036C64752C07CF2B0506B7A1C40B874CC79C64752C0E8F9D346757A1C4005F86EF3C64752C0AFD172A0877A1C40B85A272EC74752C00F5F268A907A1C40581EA4A7C84752C0706072A3C87A1C40FED2A23EC94752C06420CF2EDF7A1C40AA2A3410CB4752C053978C63247B1C40215B96AFCB4752C0D5AF743E3C7B1C40315EF3AACE4752C0D4D17135B27B1C40F5F75278D04752C0DA3C0E83F97B1C4012F758FAD04752C0AC8E1CE90C7C1C4095D5743DD14752C01E537765177C1C409A5E622CD34752C0D94125AE637C1C40B01EF7ADD64752C0BBECD79DEE7C1C40037976F9D64752C0392BA226FA7C1C406E15C440D74752C0B0AC3429057D1C4038BA4A77D74752C0889E94490D7D1C40E52B8194D84752C0EE3F321D3A7D1C40CC9BC3B5DA4752C00ABC934F8F7D1C40B9E2E2A8DC4752C0D6E1E82ADD7D1C406420CF2EDF4752C014E97E4E417E1C40572426A8E14752C0D5CE30B5A57E1C40570A815CE24752C00E6B2A8BC27E1C4014E7A8A3E34752C04641F0F8F67E1C40207BBDFBE34752C090F7AA95097F1C404451A04FE44752C0C976BE9F1A7F1C40D2C3D0EAE44752C0293E3E213B7F1C40261E5036E54752C06D37C1374D7F1C402A8D98D9E74752C028D4D347E07F1C402368CC24EA4752C099BA2BBB60801C408DD0CFD4EB4752C03DD2E0B6B6801C40F71E2E39EE4752C07099D36531811C40A376BF0AF04752C069C4CC3E8F811C406CCD565EF24752C00876FC1708821C4065C22FF5F34752C06DE2E47E87821C405323F433F54752C0280B5F5FEB821C4052EFA99CF64752C0EFCA2E185C831C409981CAF8F74752C082E50819C8831C40F17EDC7EF94752C02C11A8FE41841C40F7216FB9FA4752C053245F09A4841C40EA5910CAFB4752C06FA0C03BF9841C40253E7782FD4752C04014CC9882851C40A245B6F3FD4752C0BD8C62B9A5851C40070B2769FE4752C0C85D8429CA851C4019761893FE4752C0D9B11188D7851C40C64FE3DEFC4752C034828DEBDF851C409DD66D50FB4752C04B9352D0ED851C403F027FF8F94752C0126BF12900861C40575EF23FF94752C0AB5AD2510E861C40939048DBF84752C012A5BDC117861C4087FC3383F84752C07EACE0B721861C40813FFCFCF74752C0613596B036861C4058923CD7F74752C056D80C7041861C402EE57CB1F74752C0CD599F724C861C40A52F849CF74752C03F3BE0BA62861C40B79A75C6F74752C0B01C210379861C40DA70581AF84752C0882B67EF8C861C40E02D90A0F84752C055C03DCF9F861C40F855B950F94752C093FC885FB1861C4021E9D32AFA4752C03E23111AC1861C4080F10C1AFA4752C05534D6FECE861C40DFF94509FA4752C0821C9430D3861C40FD12F1D6F94752C0F99D2633DE861C404BB0389CF94752C0546EA296E6861C40B08F4E5DF94752C02D6002B7EE861C40A0C03BF9F44752C0984F560C57871C40772D211FF44752C0761BD47E6B871C408E1EBFB7E94752C06EBF7CB262881C4006836BEEE84752C0B875374F75881C405D15A8C5E04752C0D9B3E73235891C40B760A92EE04752C07E1D386744891C40BD512B4CDF4752C0789ACC785B891C405E6397A8DE4752C01D041DAD6A891C40AC00DF6DDE4752C04AB20E4757891C40F99D2633DE4752C001FC53AA44891C4030134548DD4752C056444DF4F9881C40B325AB22DC4752C0EB71DF6A9D881C405B28999CDA4752C01FD8F15F20881C400EBF9B6ED94752C009FCE1E7BF871C40DF6E490ED84752C04EB6813B50871C4098DC28B2D64752C09EEA909BE1861C40F8325184D44752C08F006E162F861C40F37519FED34752C04510E7E104861C4053B29C84D24752C0B2D826158D851C407D93A641D14752C0D5415E0F26851C40C58D5BCCCF4752C0B96E4A79AD841C40DDE9CE13CF4752C037FFAF3A72841C40724D81CCCE4752C03D821B295B841C40C0EAC891CE4752C0F888981249841C40DE03745FCE4752C0CB83F41439841C40FC1C1F2DCE4752C09204E10A28841C40C0046EDDCD4752C00A2FC1A90F841C404A0856D5CB4752C0A56B26DF6C831C403F74417DCB4752C0EFAD484C50831C401CEC4D0CC94752C084D6C39789821C40F92F1004C84752C06E5166834C821C40E2218C9FC64752C0630CACE3F8811C403CA1D79FC44752C0E10B93A982811C40B40584D6C34752C0647616BD53811C40E4A3C519C34752C081B3942C27811C40	\N	#3B82F6	1	\N	\N	\N	\N	f	2026-04-22 03:19:24.77943-05	2026-04-25 11:50:07.854724-05	1	1	0	f
52	ruta al Campanazo	0102000020E61000006701000086AC6EF59C4752C0A29A92ACC3811C40F16261889C4752C09146054EB6811C40168733BF9A4752C0D6743DD175811C40E15F048D994752C0EDF483BA48811C40236937FA984752C08C4AEA0434811C40F4FE3F4E984752C00475CAA31B811C4066C0594A964752C0376C5B94D9801C4025EB7074954752C09E5F94A0BF801C4085419946934752C0821DFF0582801C40D42CD0EE904752C06C7BBB2539801C40514EB4AB904752C0880FECF82F801C401C2785798F4752C050560C5707801C400BF0DDE68D4752C094A12AA6D27F1C408811C2A38D4752C0341477BCC97F1C400533A6608D4752C0D386C3D2C07F1C40E25CC30C8D4752C05C0531D0B57F1C406B2C616D8C4752C072BF4351A07F1C40836E2F698C4752C06D020CCB9F7F1C407976F9D6874752C0DA73999A047F1C40F697DD93874752C0F607CA6DFB7E1C4002469737874752C0740CC85EEF7E1C400EF450DB864752C06E32AA0CE37E1C404A26A776864752C0E0BC38F1D57E1C404162BB7B804752C0C51EDAC70A7E1C40D0EE9062804752C0A3B08BA2077E1C402463B5F97F4752C08C9FC6BDF97D1C408F19A88C7F4752C06A1492CCEA7D1C4060AFB0E07E4752C026FE28EACC7D1C4044183F8D7B4752C05A2A6F47387D1C4091B586527B4752C06B44300E2E7D1C4050C6F8307B4752C0B003E78C287D1C402CF015DD7A4752C08E78B29B197D1C406EF9484A7A4752C0CC4065FCFB7C1C40BDFE243E774752C03F6F2A52617C1C40C3D50110774752C062C092AB587C1C40117349D5764752C0EA3E00A94D7C1C401D210379764752C0349E08E23C7C1C40946B0A64764752C08A9466F3387C1C40A019C407764752C056D28A6F287C1C401764CBF2754752C0B742588D257C1C403DD68C0C724752C08507CDAE7B7B1C40792288F3704752C0FDF7E0B54B7B1C4085D04197704752C04D1421753B7B1C408CF50D4C6E4752C081B4FF01D67A1C40CEFE40B96D4752C00FD3BEB9BF7A1C4075CDE49B6D4752C05F0CE544BB7A1C40045ABA826D4752C0B4024356B77A1C4075E789E76C4752C0BA85AE44A07A1C40C284D1AC6C4752C05FB532E1977A1C408D43FD2E6C4752C00F4240BE847A1C408D43FD2E6C4752C08D63247B847A1C409B594B01694752C0CC608C48147A1C40B98C9B1A684752C0446E861BF0791C405A9E0777674752C022C66B5ED5791C40664CC11A674752C0D80FB1C1C2791C409CA73AE4664752C05BD1E638B7791C4072FA7ABE664752C08E59F624B0791C409013268C664752C02252D32EA6791C40EA5E27F5654752C01D3EE94482791C407FC2D9AD654752C0F5D8960167791C405BECF659654752C0236AA2CF47791C409161156F644752C03A596ABDDF781C40E5D53906644752C04C1C7920B2781C4044DE72F5634752C0D49AE61DA7781C408BA4DDE8634752C07F87A2409F781C401A31B3CF634752C06876DD5B91781C40508C2C99634752C0683C11C479781C4026DF6C73634752C019C91EA166781C40567DAEB6624752C0ADF6B0170A781C40452C62D8614752C097FDBAD39D771C40A4349BC7614752C03C2D3F7095771C401B7FA2B2614752C0488AC8B08A771C4099A0866F614752C0F33CB83B6B771C4034DB15FA604752C0E831CA332F771C40702711E15F4752C0D89E5912A0761C40888384285F4752C0672C9ACE4E761C405F0A0F9A5D4752C0E59A02999D751C40B37E33315D4752C0CF328B506C751C401E3526C45C4752C024B5503239751C4013BBB6B75B4752C0581B6327BC741C4090DC9A745B4752C0CA6B257497741C401F69705B5B4752C03CF6B3588A741C4036AB3E575B4752C09D66817687741C40F5BBB0355B4752C0D68EE21C75741C405A9BC6F65A4752C06490BB0853741C407E8B4E965A4752C032772D211F741C400D18247D5A4752C02123A0C211741C40FCC6D79E594752C02D98F8A3A8731C40F1660DDE574752C0C860C5A9D6721C40C7B94DB8574752C006465ED6C4721C400F9A5DF7564752C0A6ED5F5969721C4051A39064564752C0BE33DAAA24721C40E606431D564752C0CF13CFD902721C407B6AF5D5554752C063D2DF4BE1711C40F2B4FCC0554752C0F10D85CFD6711C4057941282554752C0BE2EC37FBA711C402E1B9DF3534752C0433D7D04FE701C407CB8E4B8534752C09EB64604E3701C40E2CB4411524752C09FC9FE791A701C4000E5EFDE514752C09F8F32E202701C4083DDB06D514752C0D960E124CD6F1C40FA27B858514752C0EF37DA71C36F1C407172BF43514752C089EDEE01BA6F1C405F07CE19514752C023861DC6A46F1C407D2079E7504752C0A06D35EB8C6F1C403C31EBC5504752C05C74B2D47A6F1C40CBD765F84F4752C0EBC726F9116F1C40CBD765F84F4752C0C328081EDF6E1C400133DFC14F4752C0BE310400C76E1C406CE9D1544F4752C0B900344A976E1C402BFA43334F4752C09C3237DF886E1C40E44D7E8B4E4752C0096F0F42406E1C4067463F1A4E4752C0033E3F8C106E1C40B4E386DF4D4752C0E7525C55F66D1C40BABA63B14D4752C015014EEFE26D1C404F1E166A4D4752C0C0B33D7AC36D1C40DEAAEB504D4752C0CB10C7BAB86D1C409DBB5D2F4D4752C0DC0DA2B5A26D1C40448A01124D4752C05AF5B9DA8A6D1C40730E9E094D4752C043E4F4F57C6D1C40FCC3961E4D4752C005A8A9656B6D1C4097E4805D4D4752C0F9F36DC1526D1C4032056B9C4D4752C0FF76D9AF3B6D1C40BABA63B14D4752C03E5C72DC296D1C4073F4F8BD4D4752C07D410B09186D1C4043705CC64D4752C0CC5D4BC8076D1C40A37895B54D4752C016BD5301F76C1C40D8D30E7F4D4752C0446B459BE36C1C400858AB764D4752C028BA2EFCE06C1C40CD3FFA264D4752C0BC95253ACB6C1C40687A89B14C4752C04AB4E4F1B46C1C40A983BC1E4C4752C0616EF7729F6C1C404A95287B4B4752C01D75745C8D6C1C40AAB706B64A4752C0BCCADAA6786C1C406FB9FAB1494752C03F6F2A52616C1C40ABEB504D494752C0EA5BE674596C1C40C347C494484752C078978BF84E6C1C40F3E505D8474752C0952BBCCB456C1C405308E412474752C0C2F693313E6C1C40CA6C9049464752C084D72E6D386C1C40363D2828454752C04B75012F336C1C40E3E2A8DC444752C0C2D9AD65326C1C403D484F91434752C0A06B5F402F6C1C40F1129CFA404752C0F661BD512B6C1C4021B1DD3D404752C0E52A16BF296C1C40390D51853F4752C0459BE3DC266C1C40E00F3FFF3D4752C0F0879FFF1E6C1C4028F04E3E3D4752C0B72572C1196C1C4038A27BD6354752C0E04BE141B36B1C403FADA23F344752C00DFAD2DB9F6B1C4056EF703B344752C08B1BB7989F6B1C40279F1EDB324752C0D57ABFD18E6B1C40ACFF73982F4752C09604A8A9656B1C408F1A13622E4752C069FF03AC556B1C40BA15C26A2C4752C03CDD79E2396B1C40D97C5C1B2A4752C0DB15FA60196B1C40DAFE9595264752C0488C9E5BE86A1C4005FA449E244752C08C118942CB6A1C40C40AB77C244752C0751DAA29C96A1C406536C824234752C015731074B46A1C409CC58B85214752C076A911FA996A1C40E4D9E55B1F4752C0D105F52D736A1C4008E412471E4752C0F9F6AE415F6A1C4032AB77B81D4752C0F31C91EF526A1C406EDDCD531D4752C0938FDD054A6A1C40FD8348861C4752C0D1747632386A1C40102384471B4752C03D7C9928426A1C4002D6AA5D134752C059BE2EC37F6A1C400E846401134752C081E9B46E836A1C4002F04FA9124752C0A9143B1A876A1C40AF95D05D124752C0CB82893F8A6A1C4027FA7C94114752C0378AAC35946A1C409E5E29CB104752C0C042E6CAA06A1C40B0E3BF40104752C0BAA29410AC6A1C404B1E4FCB0F4752C03D9E961FB86A1C40704221020E4752C03C2F151BF36A1C402F6D382C0D4752C069519FE40E6B1C40535DC0CB0C4752C0E1D231E7196B1C40A6D1E4620C4752C05E11FC6F256B1C402ACAA5F10B4752C0CA181F662F6B1C409B711AA20A4752C080D6FCF84B6B1C40C07B478D094752C0CA6FD1C9526B1C404374081C094752C069FF03AC556B1C4061A75835084752C01409A69A596B1C404A7F2F85074752C0ADDBA0F65B6B1C4020EC14AB064752C0BE1248895D6B1C400F9BC8CC054752C047AE9B525E6B1C40CEC5DFF6044752C0C4CF7F0F5E6B1C40DA8D3EE6034752C0B398D87C5C6B1C40B7D100DE024752C09CA4F9635A6B1C40E789E76C014752C080F3E2C4576B1C409B20EA3E004752C04D1421753B6B1C408A03E8F7FD4652C0C504357C0B6B1C405E9D6340F64652C0E21FB6F4686A1C404A4563EDEF4652C03E9468C9E3691C40F699B33EE54652C0B7D100DE02691C40D9CEF753E34652C068244223D8681C40CE88D2DEE04652C0967B8159A1681C40768BC058DF4652C0A75B76887F681C4018D1764CDD4652C0354069A851681C40B30B06D7DC4652C0C47B0E2C47681C403604C765DC4652C0B8E4B8533A681C402499D53BDC4652C00261A75835681C40E98024ECDB4652C01938A0A52B681C409CFD8172DB4652C0581D39D219681C40EF71A609DB4652C09CBF098508681C4013622EA9DA4652C0D5E76A2BF6671C4090831266DA4652C00953944BE3671C4031957EC2D94652C0D07CCEDDAE671C40852348A5D84652C0D1949D7E50671C4038BA4A77D74652C032005471E3661C405DC47762D64652C077D7D9907F661C401618B2BAD54652C056D80C7041661C403A22DFA5D44652C07EFE7BF0DA651C4010751F80D44652C067EDB60BCD651C400BEC3191D24652C0522976340E651C4059897956D24652C047753A90F5641C40CA1649BBD14652C01FB935E9B6641C40DC9BDF30D14652C047AAEFFCA2641C40666B7D91D04652C00F2BDCF291641C403CD862B7CF4652C048533D997F641C409CFA40F2CE4652C0B42094F771641C4049BA66F2CD4652C026AB22DC64641C4026FE28EACC4652C01A14CD0358641C4092CEC0C8CB4652C01AF7E6374C641C402D23F59ECA4652C0BA69334E43641C40F224E99AC94652C087C43D963E641C403448C153C84652C0E7340BB43B641C406534F279C54652C0768D96033D641C4079211D1EC24652C0FE28EACC3D641C40A30227DBC04652C070D05E7D3C641C4050C24CDBBF4652C0D1402C9B39641C4086376BF0BE4652C08C648F5033641C40228C9FC6BD4652C098C1189128641C40B709F7CABC4652C02CBAF59A1E641C40BEFA78E8BB4652C07636E49F19641C4005DB8827BB4652C0E22021CA17641C40240ED940BA4652C0E22021CA17641C408FDE701FB94652C0F91400E319641C400D349F73B74652C059A2B3CC22641C40143FC6DCB54652C0DC9DB5DB2E641C4062105839B44652C0541F48DE39641C40452BF702B34652C0151DC9E53F641C402E1D739EB14652C048C2BE9D44641C40E78A5242B04652C06473D53C47641C40126C5CFFAE4652C0ED0E290648641C4072A8DF85AD4652C06A300DC347641C40D7A19A92AC4652C0E294B9F946641C40AE0E80B8AB4652C0533C2EAA45641C40857B65DEAA4652C0378B170B43641C40088ECBB8A94652C08C81751C3F641C40984EEB36A84652C0C5C6BC8E38641C406A183E22A64652C0D6E07D552E641C4058E1968FA44652C081CD397826641C407157AF22A34652C032772D211F641C40DD41EC4CA14652C0325A475513641C4073D9E89C9F4652C0A4E4D53906641C409126DE019E4652C00438BD8BF7631C40BC07E8BE9C4652C07C7F83F6EA631C404BC8073D9B4652C04E7ADFF8DA631C40CFDA6D179A4652C0AFCDC64ACC631C40F9BB77D4984652C0F46F97FDBA631C40B900344A974652C07CD11E2FA4631C403656629E954652C0DD0720B589631C40F0C34142944652C0C11C3D7E6F631C400820B589934652C011397D3D5F631C404A29E8F6924652C0F46A80D250631C407AC7293A924652C0B071FDBB3E631C40FCA5457D924652C0DE1FEF552B631C40F0F78BD9924652C061E124CD1F631C4097AC8A70934652C07D7555A016631C407F501729944652C0C2340C1F11631C40EFA99CF6944652C033DC80CF0F631C40D74D29AF954652C078B81D1A16631C40FAD51C20984652C0008E3D7B2E631C402101A3CB9B4652C094FAB2B453631C407427D87F9D4652C04F3BFC3559631C408B4F01309E4652C08E3D7B2E53631C4097E315889E4652C01C7920B248631C40BBD39D279E4652C01C3F541A31631C40D9EC48F59D4652C0176536C824631C405628D2FD9C4652C0508D976E12631C40A5F9635A9B4652C0F5824F73F2621C402235ED629A4652C0CE001764CB621C40EDF318E5994652C0D3669C86A8621C40B1DB6795994652C05131CEDF84621C4040683D7C994652C04643C6A354621C40F2B0506B9A4652C074B7EBA529621C409274CDE49B4652C07FBDC282FB611C403FE603029D4652C0E0F3C308E1611C40E6CE4C309C4652C04704E3E0D2611C40B7989F1B9A4652C0750470B378611C40DCF0BBE9964652C01BF5108DEE601C402A8E03AF964652C0A930B610E4601C407E1CCD91954652C082919735B1601C40C03FA54A944652C07C43E1B375601C40F0F78BD9924652C0056B9C4D47601C408D800A47904652C0EF02250516601C40640795B88E4652C05BD07B6308601C40D0F1D1E28C4652C055F65D11FC5F1C401EDD088B8A4652C09415C3D501601C40EF8CB62A894652C09432A9A10D601C40DE550F98874652C00B0BEE073C601C40B5C2F4BD864652C0D21C59F965601C4032E4D87A864652C076C075C58C601C402079E750864652C0876BB587BD601C401AA20A7F864652C01B2FDD2406611C4014CB2DAD864652C06493FC885F611C40CD04C3B9864652C0425F7AFB73611C4056BABBCE864652C0E7C8CA2F83611C40624ED026874652C0BE4BA94BC6611C406825ADF8864652C00859164CFC611C40C72DE6E7864652C0C3B645990D621C40F7B182DF864652C041F50F2219621C400A9FAD83834652C01442075DC2611C40641EF983814652C0E6E5B0FB8E611C4071CCB227814652C0809BC58B85611C4008CC43A67C4652C0158F8B6A11611C409D6340F67A4652C0BA84436FF1601C40D3D85E0B7A4652C0FE261422E0601C40DAE38574784652C0BA2D910BCE601C4046B41D53774652C02CB81FF0C0601C4070952710764652C02C9B3924B5601C40A14D0E9F744652C0B519A721AA601C4054E41071734652C03D98141F9F601C40F052EA92714652C0C6F99B5088601C4008C90226704652C0B5A50EF27A601C40B6BC72BD6D4652C0E353008C67601C4094347F4C6B4652C09F5A7D7555601C400CCD751A694652C05B61FA5E43601C4036AE7FD7674652C0F4F928232E601C4054E1CFF0664652C022A81ABD1A601C4084656CE8664652C0C7D79E5912601C40B4E908E0664652C0B68311FB04601C40D102B4AD664652C02EAEF199EC5F1C40496760E4654652C0B1524145D55F1C40552FBFD3644652C078D32D3BC45F1C40E5EFDE51634652C0C2323674B35F1C4051C07630624652C0944A7842AF5F1C40DAA9B9DC604652C0789961A3AC5F1C406A6AD95A5F4652C017299485AF5F1C40D06394675E4652C0D369DD06B55F1C40410B09185D4652C02E3A596ABD5F1C4030BABC395C4652C02E573F36C95F1C40ADDBA0F65B4652C0F511F8C3CF5F1C4084622B685A4652C061191BBAD95F1C407311DF89594652C006668522DD5F1C403813D385584652C07DCA3159DC5F1C40AABA4736574652C0BCCCB051D65F1C40C216BB7D564652C05682C5E1CC5F1C40E0490B97554652C034F790F0BD5F1C4093E00D69544652C02E1D739EB15F1C408E57207A524652C0C8B5A1629C5F1C404208C897504652C0B1A4DC7D8E5F1C408445459C4E4652C0D3F544D7855F1C40321F10E84C4652C0D3F544D7855F1C40D34A21904B4652C05C9198A0865F1C409F71E140484652C0C2DB8310905F1C40E294B9F9464652C05CAE7E6C925F1C40	\N	#3B82F6	1	\N	\N	\N	\N	t	2026-04-24 01:40:22.954942-05	2026-04-25 12:31:06.88567-05	1	1	0	f
62	RUTA ADSO	0102000020E610000068000000BEA085048C4752C0EA07759142891C40B340BB438A4752C018946934B9881C406DAE9AE7884752C091F3FE3F4E881C40E42CEC69874752C01A6D5512D9871C40D9CC21A9854752C0CBD765F84F871C40878C47A9844752C0715985CD00871C403A3DEFC6824752C0AB4203B16C861C4088F4DBD7814752C00C056C0723861C40A741D13C804752C03AAE4676A5851C40721AA20A7F4752C03BC6151747851C40315F5E807D4752C09C14E63DCE841C40738236397C4752C064CA87A06A841C403E5B07077B4752C065E256410C841C406EDFA3FE7A4752C0C652245F09841C404A09C1AA7A4752C021CCED5EEE831C40B6BFB33D7A4752C08D5F7825C9831C4074D0251C7A4752C0D20149D8B7831C40A454C2137A4752C088687407B1831C40EB1A2D077A4752C0B5334C6DA9831C404B2366F6794752C027BEDA519C831C40D9AF3BDD794752C01C0A9FAD83831C402176A6D0794752C01CEDB8E177831C404B3D0B42794752C061FE0A992B831C40AA454431794752C0679E5C5320831C405114E813794752C01D05888219831C406F2D93E1784752C0C2340C1F11831C4081B22957784752C01DCBBBEA01831C40ED82C135774752C0C2C073EFE1821C408925E5EE734752C057EE056685821C4037FFAF3A724752C04B00FE2955821C40CC96AC8A704752C0C9AD49B725821C4092E68F696D4752C09180D1E5CD811C40ED65DB696B4752C0307F85CC95811C404833164D674752C0C5724BAB21811C40075E2D77664752C0E7A6CD380D811C40312592E8654752C0D1950854FF801C40EA78CC40654752C020B24813EF801C40508C2C99634752C0A41CCC26C0801C40058BC3995F4752C0D2E28C614E801C400727A25F5B4752C0BCCCB051D67F1C40EBC37AA3564752C08AE8D7D64F7F1C40A67F492A534752C0DA39CD02ED7E1C408411FB04504752C091D5AD9E937E1C409DA1B8E34D4752C003ECA353577E1C40742843554C4752C0A3073E062B7E1C40D34A21904B4752C037E33444157E1C4080D6FCF84B4752C0ED4960730E7E1C401E32E543504752C0DC645419C67D1C404208C897504752C0A30227DBC07D1C408F71C5C5514752C0548F34B8AD7D1C40ED45B41D534752C0EE27637C987D1C4034D8D479544752C0105CE509847D1C4051BD35B0554752C05ABBED42737D1C406D54A703594752C00B0E2F88487D1C402B31CF4A5A4752C06B6116DA397D1C4090DC9A745B4752C06687F8872D7D1C40E6577380604752C066136058FE7C1C403F6F2A52614752C094DE37BEF67C1C4057975302624752C0CD237F30F07C1C40D94125AE634752C02D776682E17C1C4017618A72694752C0001B1021AE7C1C4040C05AB56B4752C0A52DAEF1997C1C4074999A046F4752C0780B24287E7C1C40EAAF5758704752C0959F54FB747C1C407FDFBF79714752C0C82764E76D7C1C40723106D6714752C02E55698B6B7C1C4053CA6B25744752C01844A4A65D7C1C4071C971A7744752C0F5D555815A7C1C40177E703E754752C05089EB18577C1C40DC4B1AA3754752C023DBF97E6A7C1C40751E15FF774752C0C74961DEE37C1C40D40CA9A2784752C0B0AC3429057D1C40E0A0BDFA784752C0EEE87FB9167D1C4033FB3C46794752C01631EC30267D1C40C26D6DE1794752C03E963E74417D1C40A9DDAF027C4752C054724EECA17D1C40AE80423D7D4752C02CD8463CD97D1C40E998F38C7D4752C048A643A7E77D1C400D6FD6E07D4752C0E7525C55F67D1C401EC022BF7E4752C0A88AA9F4137E1C407100FDBE7F4752C097AAB4C5357E1C40C9C9C4AD824752C04759BF99987E1C4004AE2B66844752C0B891B245D27E1C4069739CDB844752C063B83A00E27E1C404583143C854752C06E4F90D8EE7E1C400951BEA0854752C07FA31D37FC7E1C4098C3EE3B864752C05D6F9BA9107F1C401349F4328A4752C00C7558E1967F1C40897956D28A4752C0F0FD0DDAAB7F1C40950D6B2A8B4752C06D3CD862B77F1C40A1A17F828B4752C06D59BE2EC37F1C40AD3594DA8B4752C06C76A4FACE7F1C4012FB04508C4752C094BE1072DE7F1C402EC6C03A8E4752C08EAF3DB324801C40ABCDFFAB8E4752C01C42959A3D801C40151C5E10914752C0051901158E801C40BBB6B75B924752C0BAF3C473B6801C40250516C0944752C0A987687407811C406B7D91D0964752C09DBB5D2F4D811C40FAD51C20984752C0863B17467A811C403A9160AA994752C0635E471CB2811C402EE3A6069A4752C08BA6B393C1811C40B1C1C2499A4752C09180D1E5CD811C402235ED629A4752C0852348A5D8811C40	\N	#3BF78C	4	\N	\N	\N	\N	t	2026-04-25 15:38:37.88482-05	\N	1	\N	0	f
\.


--
-- Data for Name: tab_transit_documents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_transit_documents (id_doc, name_doc, tag_transit_doc, descrip_doc, is_mandatory, has_expiration, is_active) FROM stdin;
1	Revisión Tecnomecánica	TECNO	Certificado de revisión técnico-mecánica y de emisiones	t	t	t
2	Licencia de Tránsito	LTC	Tarjeta de propiedad del vehículo	t	f	t
3	Tarjeta de Operacións	TOP	Documento que autoriza la prestación del servicio de transporte	t	t	t
\.


--
-- Data for Name: tab_trip_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_trip_events (id_event, id_trip, event_type, old_status, new_status, event_data, performed_by, performed_at) FROM stdin;
\.


--
-- Data for Name: tab_trip_incidents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_trip_incidents (id_trip_incident, id_trip, id_incident, descrip_incident, location_incident, status_incident, created_at, resolved_at) FROM stdin;
\.


--
-- Data for Name: tab_trip_statuses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_trip_statuses (id_status, status_name, descrip_status, color_hex, is_active, created_at, user_create) FROM stdin;
1	pendiente	Viaje programado sin asignar	#FFA500	t	2026-03-30 11:38:14.649135-05	1
2	asignado	Viaje asignado a conductor y bus	#2196F3	t	2026-03-30 11:38:14.649135-05	1
3	activo	Viaje en curso	#4CAF50	t	2026-03-30 11:38:14.649135-05	1
4	completado	Viaje completado exitosamente	#9E9E9E	t	2026-03-30 11:38:14.649135-05	1
5	cancelado	Viaje cancelado	#F44336	t	2026-03-30 11:38:14.649135-05	1
\.


--
-- Data for Name: tab_trips; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_trips (id_trip, id_route, trip_date, start_time, end_time, id_bus, id_driver, id_status, started_at, completed_at, cancellation_reason, is_active, created_at, user_create, updated_at, user_update) FROM stdin;
77	43	2026-04-26	21:00:00	22:00:00	10	525454512	4	2026-04-26 21:00:17.85428-05	2026-04-26 22:14:38.823153-05	\N	t	2026-04-26 20:24:57.158827-05	1	2026-04-26 22:14:38.823153-05	1
49	33	2026-04-19	12:20:00	13:20:00	2	45452412	4	2026-04-19 12:20:02.001639-05	2026-04-19 13:20:02.550898-05	\N	t	2026-04-19 12:19:14.0256-05	1	2026-04-19 13:20:02.550898-05	1
50	36	2026-04-21	21:03:00	21:50:00	1	454524124	3	2026-04-21 21:03:12.834134-05	\N	\N	t	2026-04-21 21:03:10.663338-05	1	2026-04-21 21:03:12.834134-05	1
51	43	2026-04-22	21:04:00	22:04:00	8	52545454233	4	2026-04-22 21:04:03.92189-05	2026-04-22 22:04:42.191191-05	\N	t	2026-04-22 21:04:01.53071-05	1	2026-04-22 22:04:42.191191-05	1
124	54	2026-04-30	02:52:00	03:52:00	16	1454512323	4	\N	2026-04-30 19:08:45.673641-05	\N	t	2026-04-30 02:22:16.314849-05	1	2026-04-30 19:08:45.673641-05	1
122	54	2026-04-30	02:22:00	03:22:00	21	55414123	4	2026-04-30 02:22:18.037567-05	2026-04-30 19:08:45.673641-05	\N	t	2026-04-30 02:22:16.314849-05	1	2026-04-30 19:08:45.673641-05	1
123	54	2026-04-30	02:23:00	03:37:00	1	454524124	4	2026-04-30 02:23:01.103968-05	2026-04-30 19:08:45.673641-05	\N	t	2026-04-30 02:22:16.314849-05	1	2026-04-30 19:08:45.673641-05	1
52	43	2026-04-23	11:59:00	12:59:00	1	454524124	4	2026-04-23 11:59:02.31556-05	2026-04-23 12:59:37.335625-05	\N	t	2026-04-23 11:57:27.510853-05	1	2026-04-23 12:59:37.335625-05	1
54	46	2026-04-23	12:21:00	13:21:00	8	52545454233	4	2026-04-23 12:21:02.284338-05	2026-04-23 13:21:37.358264-05	\N	t	2026-04-23 12:20:45.427503-05	1	2026-04-23 13:21:37.358264-05	1
55	49	2026-04-23	20:43:00	21:43:00	8	52545454233	3	2026-04-23 20:43:00.6378-05	\N	\N	t	2026-04-23 20:42:59.517763-05	1	2026-04-23 20:43:00.6378-05	1
56	50	2026-04-24	01:17:00	02:17:00	12	525454523	4	2026-04-24 01:17:01.393187-05	2026-04-24 02:17:02.045474-05	\N	t	2026-04-24 01:16:52.48829-05	1	2026-04-24 02:17:02.045474-05	1
127	36	2026-04-30	19:16:00	19:50:00	21	55414123	4	2026-04-30 19:16:00.222952-05	2026-04-30 19:50:08.954625-05	\N	t	2026-04-30 19:14:12.073639-05	1	2026-04-30 19:50:08.954625-05	1
53	46	2026-04-24	12:20:00	13:20:00	8	52545454233	4	2026-04-24 12:26:06.257783-05	2026-04-24 13:20:29.831095-05	\N	t	2026-04-23 12:19:45.851408-05	1	2026-04-24 13:20:29.831095-05	1
126	36	2026-04-30	19:15:00	20:15:00	16	1454512323	4	2026-04-30 19:15:01.176438-05	2026-04-30 20:15:54.208526-05	\N	t	2026-04-30 19:13:13.31513-05	1	2026-04-30 20:15:54.208526-05	1
90	36	2026-04-27	08:00:00	09:00:00	\N	\N	5	\N	2026-04-27 03:16:50.20392-05	Viaje cancelado desde interfaz	f	2026-04-27 03:09:01.948686-05	1	2026-04-27 03:16:50.20392-05	1
57	48	2026-04-24	21:17:00	22:30:00	1	454524124	4	2026-04-24 21:17:01.279934-05	2026-04-24 23:10:12.288542-05	\N	t	2026-04-24 21:16:46.471335-05	1	2026-04-24 23:10:12.288542-05	1
129	38	2026-04-30	20:27:00	21:30:00	1	454524124	4	2026-04-30 20:27:27.111982-05	2026-04-30 21:32:07.783283-05	\N	t	2026-04-30 20:26:42.621094-05	1	2026-04-30 21:32:07.783283-05	1
82	36	2026-04-27	06:00:00	07:00:00	\N	\N	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:09:01.948686-05	1	2026-04-27 19:00:17.560343-05	1
83	36	2026-04-27	06:15:00	07:15:00	10	525454512	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:09:01.948686-05	1	2026-04-27 19:00:17.560343-05	1
84	36	2026-04-27	06:30:00	07:30:00	1	454524124	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:09:01.948686-05	1	2026-04-27 19:00:17.560343-05	1
58	47	2026-04-25	01:37:00	02:37:00	12	525454523	4	2026-04-25 01:37:00.930461-05	2026-04-25 02:37:22.871027-05	\N	t	2026-04-25 01:36:34.907197-05	1	2026-04-25 02:37:22.871027-05	1
59	49	2026-04-25	01:41:00	02:41:00	1	454524124	4	2026-04-25 01:41:14.525058-05	2026-04-25 02:41:07.497435-05	\N	t	2026-04-25 01:40:33.232855-05	1	2026-04-25 02:41:07.497435-05	1
60	55	2026-04-25	01:42:00	02:42:00	8	52545454233	4	2026-04-25 01:42:13.914086-05	2026-04-25 02:42:01.878581-05	\N	t	2026-04-25 01:41:13.385367-05	1	2026-04-25 02:42:01.878581-05	1
61	39	2026-04-25	01:43:00	02:43:00	14	\N	4	2026-04-25 01:43:01.615233-05	2026-04-25 02:43:05.252248-05	\N	t	2026-04-25 01:41:58.361036-05	1	2026-04-25 02:43:05.252248-05	1
85	36	2026-04-27	06:45:00	07:45:00	16	1454512323	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:09:01.948686-05	1	2026-04-27 19:00:17.560343-05	1
86	36	2026-04-27	07:00:00	08:00:00	14	45452412	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:09:01.948686-05	1	2026-04-27 19:00:17.560343-05	1
62	47	2026-04-25	03:02:00	03:50:00	1	454524124	4	2026-04-25 03:02:05.704512-05	2026-04-25 11:00:51.134821-05	\N	t	2026-04-25 03:02:04.339406-05	1	2026-04-25 11:00:51.134821-05	1
92	36	2026-04-27	08:41:00	09:41:00	\N	\N	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:15:01.601613-05	1	2026-04-27 19:00:17.560343-05	1
93	36	2026-04-27	09:21:00	10:21:00	\N	\N	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:15:01.601613-05	1	2026-04-27 19:00:17.560343-05	1
63	52	2026-04-25	12:14:00	12:50:00	14	45452412	4	2026-04-25 12:14:09.355531-05	2026-04-25 12:58:55.055542-05	\N	t	2026-04-25 12:13:31.135035-05	1	2026-04-25 12:58:55.055542-05	1
87	36	2026-04-27	07:15:00	08:15:00	8	52545454233	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:09:01.948686-05	1	2026-04-27 19:00:17.560343-05	1
131	41	2026-04-30	20:52:00	21:52:00	16	1454512323	4	2026-04-30 20:52:54.546903-05	2026-04-30 21:52:52.971649-05	\N	t	2026-04-30 20:51:31.349159-05	1	2026-04-30 21:52:52.971649-05	1
64	41	2026-04-25	14:19:00	14:50:00	1	454524124	4	2026-04-25 14:19:05.518157-05	2026-04-25 14:50:21.051567-05	\N	t	2026-04-25 14:18:57.900485-05	1	2026-04-25 14:50:21.051567-05	1
65	62	2026-04-25	15:44:00	16:00:00	1	454524124	4	2026-04-25 15:44:04.377496-05	2026-04-25 16:00:21.353461-05	\N	t	2026-04-25 15:44:01.656177-05	1	2026-04-25 16:00:21.353461-05	1
140	38	2026-05-02	07:15:00	08:15:00	\N	\N	5	\N	2026-05-02 04:57:04.769311-05	Viaje cancelado desde interfaz	f	2026-05-02 04:56:03.177419-05	2	2026-05-02 04:57:04.769311-05	2
143	38	2026-05-02	08:00:00	09:00:00	\N	\N	5	\N	2026-05-02 04:57:08.577076-05	Viaje cancelado desde interfaz	f	2026-05-02 04:56:03.177419-05	2	2026-05-02 04:57:08.577076-05	2
142	38	2026-05-02	07:45:00	08:45:00	\N	\N	5	\N	2026-05-02 04:57:11.01761-05	Viaje cancelado desde interfaz	f	2026-05-02 04:56:03.177419-05	2	2026-05-02 04:57:11.01761-05	2
135	38	2026-05-02	06:00:00	07:00:00	\N	\N	4	\N	2026-05-02 11:13:34.799834-05	\N	t	2026-05-02 04:56:03.177419-05	2	2026-05-02 11:13:34.799834-05	1
66	38	2026-04-26	14:40:00	15:41:00	1	454524124	4	2026-04-26 14:40:00.775268-05	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:39:24.284035-05	1	2026-04-26 19:40:50.429666-05	1
68	39	2026-04-26	15:15:00	16:15:00	\N	\N	4	\N	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:59:50.840229-05	1	2026-04-26 19:40:50.429666-05	1
69	39	2026-04-26	15:30:00	16:30:00	\N	\N	4	\N	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:59:50.840229-05	1	2026-04-26 19:40:50.429666-05	1
70	39	2026-04-26	15:45:00	16:45:00	\N	\N	4	\N	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:59:50.840229-05	1	2026-04-26 19:40:50.429666-05	1
71	39	2026-04-26	16:00:00	17:00:00	\N	\N	4	\N	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:59:50.840229-05	1	2026-04-26 19:40:50.429666-05	1
72	39	2026-04-26	16:15:00	17:15:00	\N	\N	4	\N	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:59:50.840229-05	1	2026-04-26 19:40:50.429666-05	1
73	39	2026-04-26	16:30:00	17:30:00	\N	\N	4	\N	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:59:50.840229-05	1	2026-04-26 19:40:50.429666-05	1
74	39	2026-04-26	16:45:00	17:45:00	\N	\N	4	\N	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:59:50.840229-05	1	2026-04-26 19:40:50.429666-05	1
67	39	2026-04-26	15:00:00	16:00:00	1	454524124	4	2026-04-26 15:00:07.069821-05	2026-04-26 19:40:50.429666-05	\N	t	2026-04-26 14:59:50.840229-05	1	2026-04-26 19:40:50.429666-05	1
75	41	2026-04-26	19:42:00	20:42:00	1	454524124	4	2026-04-26 19:42:05.918669-05	2026-04-26 20:42:01.826843-05	\N	t	2026-04-26 19:42:04.649998-05	1	2026-04-26 20:42:01.826843-05	1
76	42	2026-04-26	19:43:00	20:43:00	16	1454512323	4	2026-04-26 19:43:21.263143-05	2026-04-26 20:43:17.858235-05	\N	t	2026-04-26 19:43:19.96807-05	1	2026-04-26 20:43:17.858235-05	1
79	41	2026-04-26	20:38:00	20:51:00	8	52545454233	4	2026-04-26 20:38:01.909366-05	2026-04-26 20:51:01.651656-05	\N	t	2026-04-26 20:37:28.208656-05	1	2026-04-26 20:51:01.651656-05	1
78	45	2026-04-26	20:36:00	20:57:00	14	45452412	4	2026-04-26 20:36:01.028089-05	2026-04-26 20:57:02.83914-05	\N	t	2026-04-26 20:35:39.064863-05	1	2026-04-26 20:57:02.83914-05	1
80	41	2026-04-26	20:53:00	21:30:00	8	52545454233	4	2026-04-26 20:53:15.62478-05	2026-04-26 21:30:17.866391-05	\N	t	2026-04-26 20:53:12.797904-05	1	2026-04-26 21:30:17.866391-05	1
81	41	2026-04-26	20:54:00	21:30:00	16	1454512323	4	2026-04-26 20:54:02.833888-05	2026-04-26 21:30:17.866391-05	\N	t	2026-04-26 20:53:12.797904-05	1	2026-04-26 21:30:17.866391-05	1
94	36	2026-04-27	08:42:00	09:42:00	\N	\N	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:16:55.753547-05	1	2026-04-27 19:00:17.560343-05	1
95	36	2026-04-27	09:22:00	10:22:00	\N	\N	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:16:55.753547-05	1	2026-04-27 19:00:17.560343-05	1
88	36	2026-04-27	07:30:00	08:30:00	11	123525454	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:09:01.948686-05	1	2026-04-27 19:00:17.560343-05	1
89	36	2026-04-27	07:45:00	08:45:00	4	5454145443	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:09:01.948686-05	1	2026-04-27 19:00:17.560343-05	1
91	36	2026-04-27	08:01:00	09:01:00	9	125454451	4	\N	2026-04-27 19:00:17.560343-05	\N	t	2026-04-27 03:15:01.601613-05	1	2026-04-27 19:00:17.560343-05	1
125	36	2026-04-30	19:14:00	20:14:00	1	454524124	4	2026-04-30 19:14:13.364335-05	2026-04-30 20:14:54.218272-05	\N	t	2026-04-30 19:12:57.183132-05	1	2026-04-30 20:14:54.218272-05	1
128	38	2026-04-30	19:50:00	20:50:00	10	525454512	4	2026-04-30 19:50:08.942164-05	2026-04-30 20:50:07.225419-05	\N	t	2026-04-30 19:49:02.166491-05	1	2026-04-30 20:50:07.225419-05	1
130	39	2026-04-30	20:50:00	21:52:00	21	55414123	4	2026-04-30 20:50:07.221521-05	2026-04-30 21:52:52.971649-05	\N	t	2026-04-30 20:50:05.625799-05	1	2026-04-30 21:52:52.971649-05	1
96	38	2026-04-27	19:10:00	20:10:00	16	1454512323	4	2026-04-27 19:11:17.027015-05	2026-04-27 20:12:08.438394-05	\N	t	2026-04-27 19:09:20.733617-05	1	2026-04-27 20:12:08.438394-05	1
97	38	2026-04-27	19:40:00	20:40:00	14	45452412	4	2026-04-27 19:51:01.605349-05	2026-04-27 20:40:15.85911-05	\N	t	2026-04-27 19:09:20.733617-05	1	2026-04-27 20:40:15.85911-05	1
98	38	2026-04-27	19:41:00	20:41:00	7	52545454	4	2026-04-27 19:51:01.605349-05	2026-04-27 20:41:15.897541-05	\N	t	2026-04-27 19:20:12.715362-05	1	2026-04-27 20:41:15.897541-05	1
99	38	2026-04-27	19:42:00	20:42:00	1	454524124	4	2026-04-27 19:53:14.25502-05	2026-04-27 20:42:15.855899-05	\N	t	2026-04-27 19:27:14.392026-05	1	2026-04-27 20:42:15.855899-05	1
102	38	2026-04-27	20:58:00	21:40:00	16	1454512323	3	2026-04-27 20:58:02.002928-05	\N	\N	t	2026-04-27 20:57:50.42288-05	1	2026-04-27 20:58:02.002928-05	1
100	38	2026-04-27	19:59:00	20:59:00	12	525454523	4	2026-04-27 20:12:08.43187-05	2026-04-27 20:59:16.207633-05	\N	t	2026-04-27 19:57:21.652108-05	1	2026-04-27 20:59:16.207633-05	1
132	36	2026-05-01	02:10:00	03:10:00	21	55414123	4	2026-05-01 02:11:03.641971-05	2026-05-01 11:39:20.329465-05	\N	t	2026-05-01 02:07:26.409165-05	1	2026-05-01 11:39:20.329465-05	1
103	38	2026-04-27	21:00:00	21:40:00	16	1454512323	3	2026-04-27 21:00:15.855664-05	\N	\N	t	2026-04-27 20:59:34.719926-05	1	2026-04-27 21:00:15.855664-05	1
101	38	2026-04-27	20:13:00	21:13:00	16	1454512323	4	2026-04-27 20:13:36.323105-05	2026-04-27 21:13:16.169046-05	\N	t	2026-04-27 20:12:33.249916-05	1	2026-04-27 21:13:16.169046-05	1
133	36	2026-05-01	02:25:00	03:25:00	1	454524124	4	2026-05-01 02:25:02.307232-05	2026-05-01 11:39:20.329465-05	\N	t	2026-05-01 02:07:26.409165-05	1	2026-05-01 11:39:20.329465-05	1
134	36	2026-05-01	02:40:00	03:40:00	16	1454512323	4	2026-05-01 02:50:40.852214-05	2026-05-01 11:39:20.329465-05	\N	t	2026-05-01 02:07:26.409165-05	1	2026-05-01 11:39:20.329465-05	1
141	38	2026-05-02	07:30:00	08:30:00	\N	\N	5	\N	2026-05-02 04:57:13.044028-05	Viaje cancelado desde interfaz	f	2026-05-02 04:56:03.177419-05	2	2026-05-02 04:57:13.044028-05	2
136	38	2026-05-02	06:15:00	07:15:00	\N	\N	4	\N	2026-05-02 11:13:34.799834-05	\N	t	2026-05-02 04:56:03.177419-05	2	2026-05-02 11:13:34.799834-05	1
137	38	2026-05-02	06:30:00	07:30:00	\N	\N	4	\N	2026-05-02 11:13:34.799834-05	\N	t	2026-05-02 04:56:03.177419-05	2	2026-05-02 11:13:34.799834-05	1
138	38	2026-05-02	06:45:00	07:45:00	\N	\N	4	\N	2026-05-02 11:13:34.799834-05	\N	t	2026-05-02 04:56:03.177419-05	2	2026-05-02 11:13:34.799834-05	1
139	38	2026-05-02	07:00:00	08:00:00	\N	\N	4	\N	2026-05-02 11:13:34.799834-05	\N	t	2026-05-02 04:56:03.177419-05	2	2026-05-02 11:13:34.799834-05	1
104	38	2026-04-28	14:30:00	15:30:00	1	454524124	4	2026-04-28 14:30:27.939786-05	2026-04-28 15:30:11.96316-05	\N	t	2026-04-28 13:52:37.083251-05	1	2026-04-28 15:30:11.96316-05	1
145	36	2026-05-08	03:15:00	04:15:00	\N	\N	4	\N	2026-05-08 10:44:57.857077-05	\N	t	2026-05-08 02:44:45.604147-05	1	2026-05-08 10:44:57.857077-05	1
146	36	2026-05-08	03:45:00	04:45:00	\N	\N	4	\N	2026-05-08 10:44:57.857077-05	\N	t	2026-05-08 02:44:45.604147-05	1	2026-05-08 10:44:57.857077-05	1
144	36	2026-05-08	02:45:00	03:45:00	1	454524124	4	2026-05-08 02:45:56.178965-05	2026-05-08 10:44:57.857077-05	\N	t	2026-05-08 02:44:45.604147-05	1	2026-05-08 10:44:57.857077-05	1
111	41	2026-04-28	15:53:00	15:59:00	\N	\N	4	\N	2026-04-28 15:59:05.966757-05	\N	t	2026-04-28 15:53:12.419545-05	1	2026-04-28 15:59:05.966757-05	1
112	41	2026-04-28	15:54:00	16:00:00	\N	\N	4	\N	2026-04-28 16:00:12.263238-05	\N	t	2026-04-28 15:53:12.419545-05	1	2026-04-28 16:00:12.263238-05	1
113	41	2026-04-28	15:55:00	16:00:00	\N	\N	4	\N	2026-04-28 16:00:12.263238-05	\N	t	2026-04-28 15:53:12.419545-05	1	2026-04-28 16:00:12.263238-05	1
105	39	2026-04-28	15:03:00	16:03:00	16	1454512323	4	2026-04-28 15:03:11.945066-05	2026-04-28 16:03:11.971213-05	\N	t	2026-04-28 15:02:46.037755-05	1	2026-04-28 16:03:11.971213-05	1
147	36	2026-05-11	01:35:00	02:55:00	1	454524124	4	2026-05-11 01:35:57.455403-05	2026-05-11 11:52:06.830824-05	\N	t	2026-05-11 01:34:43.620483-05	1	2026-05-11 11:52:19.390703-05	2
119	41	2026-04-29	17:16:00	18:16:00	12	525454523	5	\N	2026-04-28 16:15:05.518209-05	Viaje cancelado desde interfaz	f	2026-04-28 16:14:09.658528-05	1	2026-04-28 16:15:05.518209-05	1
106	39	2026-04-28	15:18:00	16:18:00	14	45452412	4	2026-04-28 15:18:11.957458-05	2026-04-28 16:18:12.437599-05	\N	t	2026-04-28 15:02:46.037755-05	1	2026-04-28 16:18:12.437599-05	1
107	39	2026-04-28	15:33:00	16:33:00	8	52545454233	4	2026-04-28 15:33:11.955384-05	2026-04-28 16:33:11.960388-05	\N	t	2026-04-28 15:02:46.037755-05	1	2026-04-28 16:33:11.960388-05	1
108	39	2026-04-28	15:48:00	16:48:00	10	525454512	4	2026-04-28 15:48:12.284519-05	2026-04-28 16:48:12.270426-05	\N	t	2026-04-28 15:02:46.037755-05	1	2026-04-28 16:48:12.270426-05	1
109	39	2026-04-28	15:49:00	16:49:00	12	525454523	4	2026-04-28 15:49:12.003681-05	2026-04-28 16:49:12.29737-05	\N	t	2026-04-28 15:03:28.745739-05	1	2026-04-28 16:49:12.29737-05	1
150	39	2026-05-11	12:02:00	13:02:00	1	454524124	4	2026-05-11 12:02:12.88534-05	2026-05-11 19:03:53.200488-05	\N	t	2026-05-11 12:01:54.762176-05	1	2026-05-11 19:03:53.200488-05	1
151	39	2026-05-12	03:06:00	04:06:00	1	454524124	4	2026-05-12 03:06:13.033786-05	2026-05-12 04:06:32.019886-05	\N	t	2026-05-12 03:05:28.654776-05	1	2026-05-12 04:06:32.019886-05	1
120	41	2026-04-28	17:03:00	18:20:00	14	45452412	4	2026-04-28 17:03:19.798841-05	2026-04-28 18:25:14.740611-05	\N	t	2026-04-28 16:59:01.671584-05	1	2026-04-28 18:25:14.740611-05	1
153	42	2026-05-12	11:13:00	12:13:00	21	55414123	4	2026-05-12 11:13:01.288349-05	2026-05-12 12:13:13.009107-05	\N	t	2026-05-12 11:12:31.740119-05	1	2026-05-12 12:13:13.009107-05	1
110	39	2026-04-28	18:20:00	19:30:00	8	52545454233	4	2026-04-28 18:25:14.710737-05	2026-04-28 19:30:08.891376-05	\N	t	2026-04-28 15:03:28.745739-05	1	2026-04-28 19:30:08.891376-05	1
121	41	2026-04-28	18:45:00	19:45:00	14	45452412	4	2026-04-28 18:45:01.283262-05	2026-04-28 19:53:46.938674-05	\N	t	2026-04-28 18:44:44.867338-05	1	2026-04-28 19:53:46.938674-05	1
114	41	2026-04-29	16:15:00	17:15:00	10	525454512	4	\N	2026-04-29 18:52:19.916023-05	\N	t	2026-04-28 16:12:12.659613-05	1	2026-04-29 18:52:19.916023-05	1
115	41	2026-04-29	16:30:00	17:30:00	16	1454512323	4	\N	2026-04-29 18:52:19.916023-05	\N	t	2026-04-28 16:12:12.659613-05	1	2026-04-29 18:52:19.916023-05	1
116	41	2026-04-29	16:45:00	17:45:00	1	454524124	4	\N	2026-04-29 18:52:19.916023-05	\N	t	2026-04-28 16:12:12.659613-05	1	2026-04-29 18:52:19.916023-05	1
117	41	2026-04-29	17:00:00	18:00:00	14	45452412	4	\N	2026-04-29 18:52:19.916023-05	\N	t	2026-04-28 16:12:12.659613-05	1	2026-04-29 18:52:19.916023-05	1
118	41	2026-04-29	17:15:00	18:15:00	\N	\N	4	\N	2026-04-29 18:52:19.916023-05	\N	t	2026-04-28 16:12:12.659613-05	1	2026-04-29 18:52:19.916023-05	1
152	41	2026-05-12	10:51:00	11:52:00	1	454524124	4	2026-05-12 10:51:00.114872-05	2026-05-12 11:52:40.992794-05	\N	t	2026-05-12 10:51:00.050768-05	1	2026-05-12 11:52:40.992794-05	1
149	38	2026-05-12	12:01:00	13:01:00	1	454524124	4	2026-05-12 12:01:13.303988-05	2026-05-12 13:01:22.279715-05	\N	t	2026-05-11 12:00:25.735408-05	1	2026-05-12 13:01:22.279715-05	1
148	36	2026-05-13	06:00:00	06:50:00	1	454524124	4	\N	2026-05-13 18:26:40.075916-05	\N	t	2026-05-11 01:35:43.584285-05	1	2026-05-13 18:26:40.075916-05	1
\.


--
-- Data for Name: tab_user_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_user_permissions (id_user, id_permission, is_granted, assigned_by, created_at) FROM stdin;
\.


--
-- Data for Name: tab_user_roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_user_roles (id_user, id_role, assigned_at, assigned_by, is_active) FROM stdin;
1	1	2026-03-30 11:38:14.649135-05	1	t
2	2	2026-03-31 02:09:49.233167-05	1	t
2	3	2026-05-05 19:57:57.790846-05	1	t
4	2	2026-05-06 01:44:33.073543-05	1	t
3	2	2026-05-06 12:01:47.426928-05	1	t
3	3	2026-04-15 00:37:28.39235-05	1	f
\.


--
-- Data for Name: tab_users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tab_users (id_user, full_name, email_user, pass_user, is_active, created_at) FROM stdin;
1	Sistema Bucarabus	system@bucarabus.com	$2b$10$EmofMuRN7LVvjNvI74yxkOXey5/1MyPEqBjQLUqPqazSvWOeBGMgy	t	2026-04-18 10:12:01.30155-05
2	JOSE CASTRO	jose@bucarabus.com	$2b$10$awsIZWEkbN170nGyrAUbHemu/rYvaRz2SDhRx0XwiwetZA0mz0CaC	t	2026-04-18 10:12:01.30155-05
3	diomedes diaz	diomedes@bucarabus.com	$2b$10$Xu.ZSt0MNpxAqFZftTbqkeuqpQl1hz8idAilFd2QQRmAJGw1OWFOS	t	2026-04-18 10:12:01.30155-05
4	JAIME PEREZ	perezrico441@gmail.com	$2b$10$Z.TaMWn32AzWClSRiHSZU.UW.BFihS1YQntYoY2RPYRo7uef3ZXfq	t	2026-05-06 01:44:33.073543-05
\.


--
-- Name: tab_audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_audit_log_id_seq', 424, true);


--
-- Name: tab_buses_id_bus_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_buses_id_bus_seq', 23, true);


--
-- Name: tab_gps_history_id_position_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_gps_history_id_position_seq', 1, false);


--
-- Name: tab_incident_types_id_incident_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_incident_types_id_incident_seq', 2, true);


--
-- Name: tab_insurance_types_id_insurance_type_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_insurance_types_id_insurance_type_seq', 7, true);


--
-- Name: tab_password_reset_tokens_id_token_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_password_reset_tokens_id_token_seq', 6, true);


--
-- Name: tab_permissions_id_permission_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_permissions_id_permission_seq', 101, true);


--
-- Name: tab_route_points_id_point_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_route_points_id_point_seq', 439, true);


--
-- Name: tab_routes_id_route_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_routes_id_route_seq', 63, true);


--
-- Name: tab_transit_documents_id_doc_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_transit_documents_id_doc_seq', 6, true);


--
-- Name: tab_trip_incidents_id_trip_incident_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_trip_incidents_id_trip_incident_seq', 1, false);


--
-- Name: tab_trips_id_trip_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_trips_id_trip_seq', 153, true);


--
-- Name: tab_users_id_user_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.tab_users_id_user_seq', 5, true);


--
-- Name: tab_arl pk_arl; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_arl
    ADD CONSTRAINT pk_arl PRIMARY KEY (id_arl);


--
-- Name: tab_audit_log pk_audit_log; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_audit_log
    ADD CONSTRAINT pk_audit_log PRIMARY KEY (id);


--
-- Name: tab_brands pk_brands; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_brands
    ADD CONSTRAINT pk_brands PRIMARY KEY (id_brand);


--
-- Name: tab_bus_assignments pk_bus_assignments; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_assignments
    ADD CONSTRAINT pk_bus_assignments PRIMARY KEY (id_bus, id_driver, assigned_at);


--
-- Name: tab_bus_insurance pk_bus_insurance; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_insurance
    ADD CONSTRAINT pk_bus_insurance PRIMARY KEY (id_bus, id_insurance_type);


--
-- Name: tab_bus_owners pk_bus_owners; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_owners
    ADD CONSTRAINT pk_bus_owners PRIMARY KEY (id_owner);


--
-- Name: tab_bus_statuses pk_bus_statuses; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_statuses
    ADD CONSTRAINT pk_bus_statuses PRIMARY KEY (id_status);


--
-- Name: tab_bus_transit_docs pk_bus_transit_docs; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_transit_docs
    ADD CONSTRAINT pk_bus_transit_docs PRIMARY KEY (id_doc, id_bus);


--
-- Name: tab_buses pk_buses; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT pk_buses PRIMARY KEY (id_bus);


--
-- Name: tab_companies pk_companies; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_companies
    ADD CONSTRAINT pk_companies PRIMARY KEY (id_company);


--
-- Name: tab_driver_accounts pk_driver_accounts; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_driver_accounts
    ADD CONSTRAINT pk_driver_accounts PRIMARY KEY (id_driver);


--
-- Name: tab_driver_statuses pk_driver_statuses; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_driver_statuses
    ADD CONSTRAINT pk_driver_statuses PRIMARY KEY (id_status);


--
-- Name: tab_drivers pk_drivers; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_drivers
    ADD CONSTRAINT pk_drivers PRIMARY KEY (id_driver);


--
-- Name: tab_eps pk_eps; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_eps
    ADD CONSTRAINT pk_eps PRIMARY KEY (id_eps);


--
-- Name: tab_gps_history pk_gps_history; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_gps_history
    ADD CONSTRAINT pk_gps_history PRIMARY KEY (id_position, recorded_at);


--
-- Name: tab_insurance_types pk_insurance_types; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_insurance_types
    ADD CONSTRAINT pk_insurance_types PRIMARY KEY (id_insurance_type);


--
-- Name: tab_insurers pk_insurers; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_insurers
    ADD CONSTRAINT pk_insurers PRIMARY KEY (id_insurer);


--
-- Name: tab_parameters pk_parameters; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_parameters
    ADD CONSTRAINT pk_parameters PRIMARY KEY (param_key);


--
-- Name: tab_permissions pk_permissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_permissions
    ADD CONSTRAINT pk_permissions PRIMARY KEY (id_permission);


--
-- Name: tab_role_permissions pk_role_permissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_role_permissions
    ADD CONSTRAINT pk_role_permissions PRIMARY KEY (id_role, id_permission);


--
-- Name: tab_roles pk_roles; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_roles
    ADD CONSTRAINT pk_roles PRIMARY KEY (id_role);


--
-- Name: tab_route_points pk_route_points; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_route_points
    ADD CONSTRAINT pk_route_points PRIMARY KEY (id_point);


--
-- Name: tab_route_points_assoc pk_route_points_assoc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_route_points_assoc
    ADD CONSTRAINT pk_route_points_assoc PRIMARY KEY (id_route, point_order);


--
-- Name: tab_routes pk_routes; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_routes
    ADD CONSTRAINT pk_routes PRIMARY KEY (id_route);


--
-- Name: tab_transit_documents pk_transit_documents; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_transit_documents
    ADD CONSTRAINT pk_transit_documents PRIMARY KEY (id_doc);


--
-- Name: tab_trip_events pk_trip_events; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_events
    ADD CONSTRAINT pk_trip_events PRIMARY KEY (id_event);


--
-- Name: tab_trip_statuses pk_trip_statuses; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_statuses
    ADD CONSTRAINT pk_trip_statuses PRIMARY KEY (id_status);


--
-- Name: tab_trips pk_trips; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trips
    ADD CONSTRAINT pk_trips PRIMARY KEY (id_trip);


--
-- Name: tab_user_permissions pk_user_permissions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_user_permissions
    ADD CONSTRAINT pk_user_permissions PRIMARY KEY (id_user, id_permission);


--
-- Name: tab_user_roles pk_user_roles; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_user_roles
    ADD CONSTRAINT pk_user_roles PRIMARY KEY (id_user, id_role);


--
-- Name: tab_users pk_users; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_users
    ADD CONSTRAINT pk_users PRIMARY KEY (id_user);


--
-- Name: tab_arl tab_arl_name_arl_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_arl
    ADD CONSTRAINT tab_arl_name_arl_key UNIQUE (name_arl);


--
-- Name: tab_brands tab_brands_brand_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_brands
    ADD CONSTRAINT tab_brands_brand_name_key UNIQUE (brand_name);


--
-- Name: tab_bus_statuses tab_bus_statuses_status_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_statuses
    ADD CONSTRAINT tab_bus_statuses_status_name_key UNIQUE (status_name);


--
-- Name: tab_buses tab_buses_code_internal_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT tab_buses_code_internal_key UNIQUE (code_internal);


--
-- Name: tab_buses tab_buses_gps_device_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT tab_buses_gps_device_id_key UNIQUE (gps_device_id);


--
-- Name: tab_companies tab_companies_company_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_companies
    ADD CONSTRAINT tab_companies_company_name_key UNIQUE (company_name);


--
-- Name: tab_companies tab_companies_nit_company_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_companies
    ADD CONSTRAINT tab_companies_nit_company_key UNIQUE (nit_company);


--
-- Name: tab_driver_statuses tab_driver_statuses_status_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_driver_statuses
    ADD CONSTRAINT tab_driver_statuses_status_name_key UNIQUE (status_name);


--
-- Name: tab_eps tab_eps_name_eps_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_eps
    ADD CONSTRAINT tab_eps_name_eps_key UNIQUE (name_eps);


--
-- Name: tab_gps_history_2026_03 tab_gps_history_2026_03_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_gps_history_2026_03
    ADD CONSTRAINT tab_gps_history_2026_03_pkey PRIMARY KEY (id_position, recorded_at);


--
-- Name: tab_gps_history_2026_04 tab_gps_history_2026_04_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_gps_history_2026_04
    ADD CONSTRAINT tab_gps_history_2026_04_pkey PRIMARY KEY (id_position, recorded_at);


--
-- Name: tab_gps_history_2026_05 tab_gps_history_2026_05_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_gps_history_2026_05
    ADD CONSTRAINT tab_gps_history_2026_05_pkey PRIMARY KEY (id_position, recorded_at);


--
-- Name: tab_incident_types tab_incident_types_name_incident_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_incident_types
    ADD CONSTRAINT tab_incident_types_name_incident_key UNIQUE (name_incident);


--
-- Name: tab_incident_types tab_incident_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_incident_types
    ADD CONSTRAINT tab_incident_types_pkey PRIMARY KEY (id_incident);


--
-- Name: tab_incident_types tab_incident_types_tag_incident_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_incident_types
    ADD CONSTRAINT tab_incident_types_tag_incident_key UNIQUE (tag_incident);


--
-- Name: tab_insurers tab_insurers_insurer_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_insurers
    ADD CONSTRAINT tab_insurers_insurer_name_key UNIQUE (insurer_name);


--
-- Name: tab_password_reset_tokens tab_password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_password_reset_tokens
    ADD CONSTRAINT tab_password_reset_tokens_pkey PRIMARY KEY (id_token);


--
-- Name: tab_password_reset_tokens tab_password_reset_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_password_reset_tokens
    ADD CONSTRAINT tab_password_reset_tokens_token_key UNIQUE (token);


--
-- Name: tab_permissions tab_permissions_code_permission_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_permissions
    ADD CONSTRAINT tab_permissions_code_permission_key UNIQUE (code_permission);


--
-- Name: tab_trip_incidents tab_trip_incidents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_incidents
    ADD CONSTRAINT tab_trip_incidents_pkey PRIMARY KEY (id_trip_incident);


--
-- Name: tab_trip_statuses tab_trip_statuses_status_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_statuses
    ADD CONSTRAINT tab_trip_statuses_status_name_key UNIQUE (status_name);


--
-- Name: tab_users tab_users_email_user_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_users
    ADD CONSTRAINT tab_users_email_user_key UNIQUE (email_user);


--
-- Name: tab_bus_owners uq_bus_owners_email; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_owners
    ADD CONSTRAINT uq_bus_owners_email UNIQUE (email_owner);


--
-- Name: tab_driver_accounts uq_driver_accounts; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_driver_accounts
    ADD CONSTRAINT uq_driver_accounts UNIQUE (id_user);


--
-- Name: tab_insurance_types uq_insurance_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_insurance_types
    ADD CONSTRAINT uq_insurance_name UNIQUE (name_insurance);


--
-- Name: tab_bus_insurance uq_insurance_number; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_insurance
    ADD CONSTRAINT uq_insurance_number UNIQUE (id_insurance);


--
-- Name: tab_insurance_types uq_insurance_tag; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_insurance_types
    ADD CONSTRAINT uq_insurance_tag UNIQUE (tag_insurance);


--
-- Name: tab_transit_documents uq_transit_doc_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_transit_documents
    ADD CONSTRAINT uq_transit_doc_name UNIQUE (name_doc);


--
-- Name: tab_transit_documents uq_transit_doc_tag; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_transit_documents
    ADD CONSTRAINT uq_transit_doc_tag UNIQUE (tag_transit_doc);


--
-- Name: idx_assignments_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assignments_driver ON public.tab_bus_assignments USING btree (id_driver);


--
-- Name: idx_audit_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_record ON public.tab_audit_log USING btree (table_name, record_id, changed_at DESC);


--
-- Name: idx_audit_table; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_table ON public.tab_audit_log USING btree (table_name, changed_at DESC);


--
-- Name: idx_audit_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_user ON public.tab_audit_log USING btree (changed_by, changed_at DESC);


--
-- Name: idx_buses_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_buses_status ON public.tab_buses USING btree (id_status);


--
-- Name: idx_driver_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_driver_active ON public.tab_drivers USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_driver_license_exp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_driver_license_exp ON public.tab_drivers USING btree (license_exp);


--
-- Name: idx_driver_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_driver_status ON public.tab_drivers USING btree (id_status);


--
-- Name: idx_gps_history_bus_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gps_history_bus_time ON ONLY public.tab_gps_history USING btree (id_bus, recorded_at DESC);


--
-- Name: idx_gps_history_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gps_history_location ON ONLY public.tab_gps_history USING gist (location_shot);


--
-- Name: idx_gps_history_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gps_history_received ON ONLY public.tab_gps_history USING btree (received_at DESC);


--
-- Name: idx_gps_history_trip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_gps_history_trip ON ONLY public.tab_gps_history USING btree (id_trip, recorded_at DESC) WHERE (id_trip IS NOT NULL);


--
-- Name: idx_insurance_bus; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_insurance_bus ON public.tab_bus_insurance USING btree (id_bus);


--
-- Name: idx_insurance_end_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_insurance_end_date ON public.tab_bus_insurance USING btree (end_date_insu);


--
-- Name: idx_permissions_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_permissions_code ON public.tab_permissions USING btree (code_permission);


--
-- Name: idx_permissions_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_permissions_parent ON public.tab_permissions USING btree (id_parent);


--
-- Name: idx_prt_id_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prt_id_user ON public.tab_password_reset_tokens USING btree (id_user);


--
-- Name: idx_prt_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_prt_token ON public.tab_password_reset_tokens USING btree (token);


--
-- Name: idx_role_permissions_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_permissions_role ON public.tab_role_permissions USING btree (id_role);


--
-- Name: idx_route_points_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_route_points_active ON public.tab_route_points USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_route_points_checkpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_route_points_checkpoint ON public.tab_route_points USING btree (is_checkpoint) WHERE (is_checkpoint = true);


--
-- Name: idx_route_points_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_route_points_location ON public.tab_route_points USING gist (location_point);


--
-- Name: idx_route_points_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_route_points_type ON public.tab_route_points USING btree (point_type);


--
-- Name: idx_routes_path_gist; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_routes_path_gist ON public.tab_routes USING gist (path_route);


--
-- Name: idx_rpa_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rpa_active ON public.tab_route_points_assoc USING btree (id_route) WHERE (is_active = true);


--
-- Name: idx_rpa_point; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rpa_point ON public.tab_route_points_assoc USING btree (id_point);


--
-- Name: idx_rpa_route; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rpa_route ON public.tab_route_points_assoc USING btree (id_route, point_order);


--
-- Name: idx_transit_docs_bus; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transit_docs_bus ON public.tab_bus_transit_docs USING btree (id_bus);


--
-- Name: idx_transit_docs_end_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_transit_docs_end_date ON public.tab_bus_transit_docs USING btree (end_date);


--
-- Name: idx_trip_events_performed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trip_events_performed_by ON public.tab_trip_events USING btree (performed_by) WHERE (performed_by IS NOT NULL);


--
-- Name: idx_trip_events_trip_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trip_events_trip_date ON public.tab_trip_events USING btree (id_trip, performed_at DESC);


--
-- Name: idx_trip_incidents_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trip_incidents_active ON public.tab_trip_incidents USING btree (status_incident, created_at DESC) WHERE ((status_incident)::text = 'active'::text);


--
-- Name: idx_trip_incidents_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trip_incidents_location ON public.tab_trip_incidents USING gist (location_incident);


--
-- Name: idx_trips_active_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trips_active_status ON public.tab_trips USING btree (id_status, trip_date) WHERE (is_active = true);


--
-- Name: idx_trips_bus; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trips_bus ON public.tab_trips USING btree (id_bus) WHERE (id_bus IS NOT NULL);


--
-- Name: idx_trips_driver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trips_driver ON public.tab_trips USING btree (id_driver) WHERE (id_driver IS NOT NULL);


--
-- Name: idx_trips_route_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_trips_route_date ON public.tab_trips USING btree (id_route, trip_date);


--
-- Name: idx_user_permissions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_permissions_user ON public.tab_user_permissions USING btree (id_user);


--
-- Name: idx_user_roles_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_roles_active ON public.tab_user_roles USING btree (id_user) WHERE (is_active = true);


--
-- Name: idx_user_roles_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_roles_role ON public.tab_user_roles USING btree (id_role);


--
-- Name: tab_gps_history_2026_03_id_bus_recorded_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_03_id_bus_recorded_at_idx ON public.tab_gps_history_2026_03 USING btree (id_bus, recorded_at DESC);


--
-- Name: tab_gps_history_2026_03_id_trip_recorded_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_03_id_trip_recorded_at_idx ON public.tab_gps_history_2026_03 USING btree (id_trip, recorded_at DESC) WHERE (id_trip IS NOT NULL);


--
-- Name: tab_gps_history_2026_03_location_shot_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_03_location_shot_idx ON public.tab_gps_history_2026_03 USING gist (location_shot);


--
-- Name: tab_gps_history_2026_03_received_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_03_received_at_idx ON public.tab_gps_history_2026_03 USING btree (received_at DESC);


--
-- Name: tab_gps_history_2026_04_id_bus_recorded_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_04_id_bus_recorded_at_idx ON public.tab_gps_history_2026_04 USING btree (id_bus, recorded_at DESC);


--
-- Name: tab_gps_history_2026_04_id_trip_recorded_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_04_id_trip_recorded_at_idx ON public.tab_gps_history_2026_04 USING btree (id_trip, recorded_at DESC) WHERE (id_trip IS NOT NULL);


--
-- Name: tab_gps_history_2026_04_location_shot_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_04_location_shot_idx ON public.tab_gps_history_2026_04 USING gist (location_shot);


--
-- Name: tab_gps_history_2026_04_received_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_04_received_at_idx ON public.tab_gps_history_2026_04 USING btree (received_at DESC);


--
-- Name: tab_gps_history_2026_05_id_bus_recorded_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_05_id_bus_recorded_at_idx ON public.tab_gps_history_2026_05 USING btree (id_bus, recorded_at DESC);


--
-- Name: tab_gps_history_2026_05_id_trip_recorded_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_05_id_trip_recorded_at_idx ON public.tab_gps_history_2026_05 USING btree (id_trip, recorded_at DESC) WHERE (id_trip IS NOT NULL);


--
-- Name: tab_gps_history_2026_05_location_shot_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_05_location_shot_idx ON public.tab_gps_history_2026_05 USING gist (location_shot);


--
-- Name: tab_gps_history_2026_05_received_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tab_gps_history_2026_05_received_at_idx ON public.tab_gps_history_2026_05 USING btree (received_at DESC);


--
-- Name: uq_bus_active_assign; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_bus_active_assign ON public.tab_bus_assignments USING btree (id_bus) WHERE (unassigned_at IS NULL);


--
-- Name: uq_buses_amb_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_buses_amb_code ON public.tab_buses USING btree (amb_code) WHERE ((amb_code)::text <> 'SA'::text);


--
-- Name: uq_buses_plate_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_buses_plate_number ON public.tab_buses USING btree (plate_number);


--
-- Name: uq_driver_active_assign; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_driver_active_assign ON public.tab_bus_assignments USING btree (id_driver) WHERE (unassigned_at IS NULL);


--
-- Name: tab_gps_history_2026_03_id_bus_recorded_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_bus_time ATTACH PARTITION public.tab_gps_history_2026_03_id_bus_recorded_at_idx;


--
-- Name: tab_gps_history_2026_03_id_trip_recorded_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_trip ATTACH PARTITION public.tab_gps_history_2026_03_id_trip_recorded_at_idx;


--
-- Name: tab_gps_history_2026_03_location_shot_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_location ATTACH PARTITION public.tab_gps_history_2026_03_location_shot_idx;


--
-- Name: tab_gps_history_2026_03_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.pk_gps_history ATTACH PARTITION public.tab_gps_history_2026_03_pkey;


--
-- Name: tab_gps_history_2026_03_received_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_received ATTACH PARTITION public.tab_gps_history_2026_03_received_at_idx;


--
-- Name: tab_gps_history_2026_04_id_bus_recorded_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_bus_time ATTACH PARTITION public.tab_gps_history_2026_04_id_bus_recorded_at_idx;


--
-- Name: tab_gps_history_2026_04_id_trip_recorded_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_trip ATTACH PARTITION public.tab_gps_history_2026_04_id_trip_recorded_at_idx;


--
-- Name: tab_gps_history_2026_04_location_shot_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_location ATTACH PARTITION public.tab_gps_history_2026_04_location_shot_idx;


--
-- Name: tab_gps_history_2026_04_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.pk_gps_history ATTACH PARTITION public.tab_gps_history_2026_04_pkey;


--
-- Name: tab_gps_history_2026_04_received_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_received ATTACH PARTITION public.tab_gps_history_2026_04_received_at_idx;


--
-- Name: tab_gps_history_2026_05_id_bus_recorded_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_bus_time ATTACH PARTITION public.tab_gps_history_2026_05_id_bus_recorded_at_idx;


--
-- Name: tab_gps_history_2026_05_id_trip_recorded_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_trip ATTACH PARTITION public.tab_gps_history_2026_05_id_trip_recorded_at_idx;


--
-- Name: tab_gps_history_2026_05_location_shot_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_location ATTACH PARTITION public.tab_gps_history_2026_05_location_shot_idx;


--
-- Name: tab_gps_history_2026_05_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.pk_gps_history ATTACH PARTITION public.tab_gps_history_2026_05_pkey;


--
-- Name: tab_gps_history_2026_05_received_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_gps_history_received ATTACH PARTITION public.tab_gps_history_2026_05_received_at_idx;


--
-- Name: tab_bus_insurance trg_audit_bus_insurance; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_bus_insurance BEFORE INSERT OR DELETE OR UPDATE ON public.tab_bus_insurance FOR EACH ROW EXECUTE FUNCTION public.fun_audit_full('id_bus|id_insurance_type');


--
-- Name: tab_bus_owners trg_audit_bus_owners; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_bus_owners BEFORE INSERT OR DELETE OR UPDATE ON public.tab_bus_owners FOR EACH ROW EXECUTE FUNCTION public.fun_audit_full('id_owner');


--
-- Name: tab_bus_transit_docs trg_audit_bus_transit_docs; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_bus_transit_docs BEFORE INSERT OR DELETE OR UPDATE ON public.tab_bus_transit_docs FOR EACH ROW EXECUTE FUNCTION public.fun_audit_full('id_doc|id_bus');


--
-- Name: tab_buses trg_audit_buses; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_buses BEFORE INSERT OR DELETE OR UPDATE ON public.tab_buses FOR EACH ROW EXECUTE FUNCTION public.fun_audit_full('id_bus');


--
-- Name: tab_companies trg_audit_companies; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_companies BEFORE INSERT OR DELETE OR UPDATE ON public.tab_companies FOR EACH ROW EXECUTE FUNCTION public.fun_audit_full('id_company');


--
-- Name: tab_drivers trg_audit_drivers; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_drivers BEFORE INSERT OR DELETE OR UPDATE ON public.tab_drivers FOR EACH ROW EXECUTE FUNCTION public.fun_audit_full('id_driver');


--
-- Name: tab_parameters trg_audit_parameters; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_parameters BEFORE UPDATE ON public.tab_parameters FOR EACH ROW EXECUTE FUNCTION public.fun_audit_params();


--
-- Name: tab_route_points trg_audit_route_points; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_route_points BEFORE INSERT OR DELETE OR UPDATE ON public.tab_route_points FOR EACH ROW EXECUTE FUNCTION public.fun_audit_full('id_point', 'location_point');


--
-- Name: tab_routes trg_audit_routes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_routes BEFORE INSERT OR DELETE OR UPDATE ON public.tab_routes FOR EACH ROW EXECUTE FUNCTION public.fun_audit_full('id_route', 'path_route');


--
-- Name: tab_bus_assignments fk_assignments_assigned_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_assignments
    ADD CONSTRAINT fk_assignments_assigned_by FOREIGN KEY (assigned_by) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_bus_assignments fk_assignments_bus; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_assignments
    ADD CONSTRAINT fk_assignments_bus FOREIGN KEY (id_bus) REFERENCES public.tab_buses(id_bus) ON DELETE RESTRICT;


--
-- Name: tab_bus_assignments fk_assignments_driver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_assignments
    ADD CONSTRAINT fk_assignments_driver FOREIGN KEY (id_driver) REFERENCES public.tab_drivers(id_driver) ON DELETE RESTRICT;


--
-- Name: tab_bus_assignments fk_assignments_unassigned_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_assignments
    ADD CONSTRAINT fk_assignments_unassigned_by FOREIGN KEY (unassigned_by) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_buses fk_buses_brand; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT fk_buses_brand FOREIGN KEY (id_brand) REFERENCES public.tab_brands(id_brand) ON DELETE RESTRICT;


--
-- Name: tab_buses fk_buses_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT fk_buses_company FOREIGN KEY (id_company) REFERENCES public.tab_companies(id_company) ON DELETE RESTRICT;


--
-- Name: tab_buses fk_buses_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT fk_buses_created_by FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_buses fk_buses_owner; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT fk_buses_owner FOREIGN KEY (id_owner) REFERENCES public.tab_bus_owners(id_owner) ON DELETE RESTRICT;


--
-- Name: tab_buses fk_buses_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT fk_buses_status FOREIGN KEY (id_status) REFERENCES public.tab_bus_statuses(id_status) ON DELETE RESTRICT;


--
-- Name: tab_buses fk_buses_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_buses
    ADD CONSTRAINT fk_buses_updated_by FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_companies fk_companies_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_companies
    ADD CONSTRAINT fk_companies_created_by FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_companies fk_companies_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_companies
    ADD CONSTRAINT fk_companies_updated_by FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_driver_accounts fk_da_assigned_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_driver_accounts
    ADD CONSTRAINT fk_da_assigned_by FOREIGN KEY (assigned_by) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_driver_accounts fk_da_driver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_driver_accounts
    ADD CONSTRAINT fk_da_driver FOREIGN KEY (id_driver) REFERENCES public.tab_drivers(id_driver);


--
-- Name: tab_driver_accounts fk_da_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_driver_accounts
    ADD CONSTRAINT fk_da_user FOREIGN KEY (id_user) REFERENCES public.tab_users(id_user);


--
-- Name: tab_drivers fk_drivers_arl; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_drivers
    ADD CONSTRAINT fk_drivers_arl FOREIGN KEY (id_arl) REFERENCES public.tab_arl(id_arl) ON DELETE RESTRICT;


--
-- Name: tab_drivers fk_drivers_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_drivers
    ADD CONSTRAINT fk_drivers_created_by FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_drivers fk_drivers_eps; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_drivers
    ADD CONSTRAINT fk_drivers_eps FOREIGN KEY (id_eps) REFERENCES public.tab_eps(id_eps) ON DELETE RESTRICT;


--
-- Name: tab_drivers fk_drivers_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_drivers
    ADD CONSTRAINT fk_drivers_status FOREIGN KEY (id_status) REFERENCES public.tab_driver_statuses(id_status) ON DELETE RESTRICT;


--
-- Name: tab_drivers fk_drivers_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_drivers
    ADD CONSTRAINT fk_drivers_updated_by FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_gps_history fk_gps_history_bus; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.tab_gps_history
    ADD CONSTRAINT fk_gps_history_bus FOREIGN KEY (id_bus) REFERENCES public.tab_buses(id_bus) ON DELETE RESTRICT;


--
-- Name: tab_gps_history fk_gps_history_trip; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.tab_gps_history
    ADD CONSTRAINT fk_gps_history_trip FOREIGN KEY (id_trip) REFERENCES public.tab_trips(id_trip) ON DELETE SET NULL;


--
-- Name: tab_bus_insurance fk_insurance_bus; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_insurance
    ADD CONSTRAINT fk_insurance_bus FOREIGN KEY (id_bus) REFERENCES public.tab_buses(id_bus) ON DELETE RESTRICT;


--
-- Name: tab_bus_insurance fk_insurance_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_insurance
    ADD CONSTRAINT fk_insurance_created_by FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_bus_insurance fk_insurance_insurer; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_insurance
    ADD CONSTRAINT fk_insurance_insurer FOREIGN KEY (id_insurer) REFERENCES public.tab_insurers(id_insurer) ON DELETE RESTRICT;


--
-- Name: tab_bus_insurance fk_insurance_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_insurance
    ADD CONSTRAINT fk_insurance_type FOREIGN KEY (id_insurance_type) REFERENCES public.tab_insurance_types(id_insurance_type) ON DELETE RESTRICT;


--
-- Name: tab_bus_insurance fk_insurance_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_insurance
    ADD CONSTRAINT fk_insurance_updated_by FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_bus_owners fk_owners_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_owners
    ADD CONSTRAINT fk_owners_created_by FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_bus_owners fk_owners_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_owners
    ADD CONSTRAINT fk_owners_updated_by FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_parameters fk_parameters_updated; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_parameters
    ADD CONSTRAINT fk_parameters_updated FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_permissions fk_permissions_parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_permissions
    ADD CONSTRAINT fk_permissions_parent FOREIGN KEY (id_parent) REFERENCES public.tab_permissions(id_permission) ON DELETE CASCADE;


--
-- Name: tab_role_permissions fk_role_permissions_assigned_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_role_permissions
    ADD CONSTRAINT fk_role_permissions_assigned_by FOREIGN KEY (assigned_by) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_role_permissions fk_role_permissions_permission; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_role_permissions
    ADD CONSTRAINT fk_role_permissions_permission FOREIGN KEY (id_permission) REFERENCES public.tab_permissions(id_permission) ON DELETE CASCADE;


--
-- Name: tab_role_permissions fk_role_permissions_role; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_role_permissions
    ADD CONSTRAINT fk_role_permissions_role FOREIGN KEY (id_role) REFERENCES public.tab_roles(id_role) ON DELETE CASCADE;


--
-- Name: tab_route_points_assoc fk_route_points_assoc_point; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_route_points_assoc
    ADD CONSTRAINT fk_route_points_assoc_point FOREIGN KEY (id_point) REFERENCES public.tab_route_points(id_point) ON DELETE RESTRICT;


--
-- Name: tab_route_points_assoc fk_route_points_assoc_route; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_route_points_assoc
    ADD CONSTRAINT fk_route_points_assoc_route FOREIGN KEY (id_route) REFERENCES public.tab_routes(id_route);


--
-- Name: tab_route_points fk_route_points_create; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_route_points
    ADD CONSTRAINT fk_route_points_create FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_route_points fk_route_points_update; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_route_points
    ADD CONSTRAINT fk_route_points_update FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_routes fk_routes_company; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_routes
    ADD CONSTRAINT fk_routes_company FOREIGN KEY (id_company) REFERENCES public.tab_companies(id_company) ON DELETE RESTRICT;


--
-- Name: tab_routes fk_routes_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_routes
    ADD CONSTRAINT fk_routes_created_by FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_routes fk_routes_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_routes
    ADD CONSTRAINT fk_routes_updated_by FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_bus_transit_docs fk_transit_doc_bus; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_transit_docs
    ADD CONSTRAINT fk_transit_doc_bus FOREIGN KEY (id_bus) REFERENCES public.tab_buses(id_bus) ON DELETE RESTRICT;


--
-- Name: tab_bus_transit_docs fk_transit_doc_created; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_transit_docs
    ADD CONSTRAINT fk_transit_doc_created FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_bus_transit_docs fk_transit_doc_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_transit_docs
    ADD CONSTRAINT fk_transit_doc_type FOREIGN KEY (id_doc) REFERENCES public.tab_transit_documents(id_doc) ON DELETE RESTRICT;


--
-- Name: tab_bus_transit_docs fk_transit_doc_updated; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_bus_transit_docs
    ADD CONSTRAINT fk_transit_doc_updated FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_trip_events fk_trip_events_new_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_events
    ADD CONSTRAINT fk_trip_events_new_status FOREIGN KEY (new_status) REFERENCES public.tab_trip_statuses(id_status) ON DELETE RESTRICT;


--
-- Name: tab_trip_events fk_trip_events_old_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_events
    ADD CONSTRAINT fk_trip_events_old_status FOREIGN KEY (old_status) REFERENCES public.tab_trip_statuses(id_status) ON DELETE RESTRICT;


--
-- Name: tab_trip_events fk_trip_events_performed_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_events
    ADD CONSTRAINT fk_trip_events_performed_by FOREIGN KEY (performed_by) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_trip_events fk_trip_events_trip; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_events
    ADD CONSTRAINT fk_trip_events_trip FOREIGN KEY (id_trip) REFERENCES public.tab_trips(id_trip) ON DELETE RESTRICT;


--
-- Name: tab_trip_statuses fk_trip_statuses_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_statuses
    ADD CONSTRAINT fk_trip_statuses_created_by FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_trips fk_trips_bus; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trips
    ADD CONSTRAINT fk_trips_bus FOREIGN KEY (id_bus) REFERENCES public.tab_buses(id_bus) ON DELETE SET NULL;


--
-- Name: tab_trips fk_trips_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trips
    ADD CONSTRAINT fk_trips_created_by FOREIGN KEY (user_create) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_trips fk_trips_driver; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trips
    ADD CONSTRAINT fk_trips_driver FOREIGN KEY (id_driver) REFERENCES public.tab_drivers(id_driver) ON DELETE SET NULL;


--
-- Name: tab_trips fk_trips_route; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trips
    ADD CONSTRAINT fk_trips_route FOREIGN KEY (id_route) REFERENCES public.tab_routes(id_route) ON DELETE RESTRICT;


--
-- Name: tab_trips fk_trips_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trips
    ADD CONSTRAINT fk_trips_status FOREIGN KEY (id_status) REFERENCES public.tab_trip_statuses(id_status) ON DELETE RESTRICT;


--
-- Name: tab_trips fk_trips_updated_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trips
    ADD CONSTRAINT fk_trips_updated_by FOREIGN KEY (user_update) REFERENCES public.tab_users(id_user) ON DELETE SET NULL;


--
-- Name: tab_user_permissions fk_user_permissions_assigned_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_user_permissions
    ADD CONSTRAINT fk_user_permissions_assigned_by FOREIGN KEY (assigned_by) REFERENCES public.tab_users(id_user);


--
-- Name: tab_user_permissions fk_user_permissions_permission; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_user_permissions
    ADD CONSTRAINT fk_user_permissions_permission FOREIGN KEY (id_permission) REFERENCES public.tab_permissions(id_permission);


--
-- Name: tab_user_permissions fk_user_permissions_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_user_permissions
    ADD CONSTRAINT fk_user_permissions_user FOREIGN KEY (id_user) REFERENCES public.tab_users(id_user);


--
-- Name: tab_user_roles fk_user_roles_assigned; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_user_roles
    ADD CONSTRAINT fk_user_roles_assigned FOREIGN KEY (assigned_by) REFERENCES public.tab_users(id_user) ON DELETE SET DEFAULT;


--
-- Name: tab_user_roles fk_user_roles_role; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_user_roles
    ADD CONSTRAINT fk_user_roles_role FOREIGN KEY (id_role) REFERENCES public.tab_roles(id_role) ON DELETE RESTRICT;


--
-- Name: tab_user_roles fk_user_roles_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_user_roles
    ADD CONSTRAINT fk_user_roles_user FOREIGN KEY (id_user) REFERENCES public.tab_users(id_user);


--
-- Name: tab_password_reset_tokens tab_password_reset_tokens_id_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_password_reset_tokens
    ADD CONSTRAINT tab_password_reset_tokens_id_user_fkey FOREIGN KEY (id_user) REFERENCES public.tab_users(id_user);


--
-- Name: tab_trip_incidents tab_trip_incidents_id_incident_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_incidents
    ADD CONSTRAINT tab_trip_incidents_id_incident_fkey FOREIGN KEY (id_incident) REFERENCES public.tab_incident_types(id_incident);


--
-- Name: tab_trip_incidents tab_trip_incidents_id_trip_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tab_trip_incidents
    ADD CONSTRAINT tab_trip_incidents_id_trip_fkey FOREIGN KEY (id_trip) REFERENCES public.tab_trips(id_trip);


--
-- PostgreSQL database dump complete
--


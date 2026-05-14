-- =============================================
-- DEPLOY: fun_create_user v3.0 - IDs Secuenciales
-- =============================================
-- Este script despliega la versión 3.0 de fun_create_user
-- que genera IDs de forma secuencial (MAX + 1)
--
-- Ejecutar en: PostgreSQL 12+
-- Base de datos: db_bucarabus
-- Usuario: dlastre (o bucarabus_user)
-- =============================================

-- Eliminar versiones anteriores
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS fun_create_user(tab_users.email%TYPE, tab_users.password_hash%TYPE, tab_users.full_name%TYPE, tab_users.avatar_url%TYPE, tab_users.user_create%TYPE);

-- Crear función v3.0
CREATE OR REPLACE FUNCTION fun_create_user(
  wemail         tab_users.email%TYPE,
  wpassword_hash tab_users.password_hash%TYPE,
  wfull_name     tab_users.full_name%TYPE,
  wuser_create   tab_users.user_create%TYPE,
  wavatar_url    tab_users.avatar_url%TYPE DEFAULT NULL,
  OUT success    BOOLEAN,
  OUT msg        VARCHAR,
  OUT error_code VARCHAR,
  OUT id_user    tab_users.id_user%TYPE
)
LANGUAGE plpgsql
AS $$
DECLARE
  -- Variables de validación
  v_user_exists  BOOLEAN;
  v_email_exists BOOLEAN;
  v_email_clean  tab_users.email%TYPE;
  v_name_clean   tab_users.full_name%TYPE;
  
  -- Variables para generación de ID
  v_generated_id tab_users.id_user%TYPE;
  
  -- Variable para rol
  v_role_exists  BOOLEAN;

BEGIN
  -- Inicialización
  success := FALSE;
  msg := '';
  error_code := NULL;
  id_user := NULL;
  
  RAISE NOTICE '[fun_create_user] Iniciando creación de usuario: %', wemail;
  
  -- VALIDAR USUARIO CREADOR
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE tab_users.id_user = wuser_create AND tab_users.is_active = TRUE
  ) INTO v_user_exists;
  
  IF NOT v_user_exists THEN
    msg := 'El usuario creador no existe o está inactivo (ID: ' || wuser_create || ')';
    error_code := 'USER_CREATE_NOT_FOUND';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- VALIDAR NOMBRE COMPLETO
  IF wfull_name IS NULL OR TRIM(wfull_name) = '' THEN
    msg := 'El nombre completo no puede estar vacío';
    error_code := 'NAME_NULL_EMPTY';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  v_name_clean := TRIM(REGEXP_REPLACE(wfull_name, '\s+', ' ', 'g'));
  
  IF LENGTH(v_name_clean) < 2 THEN
    msg := 'El nombre debe tener al menos 2 caracteres. Recibido: "' || v_name_clean || '"';
    error_code := 'NAME_TOO_SHORT';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF LENGTH(v_name_clean) > 100 THEN
    msg := 'El nombre no puede exceder 100 caracteres. Recibido: ' || LENGTH(v_name_clean) || ' caracteres';
    error_code := 'NAME_TOO_LONG';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF v_name_clean !~ '^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ'' -]+$' THEN
    msg := 'El nombre contiene caracteres no permitidos. Solo se permiten letras, espacios, guiones y apóstrofes';
    error_code := 'NAME_INVALID_CHARS';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF v_name_clean !~ '[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ]' THEN
    msg := 'El nombre debe contener al menos una letra';
    error_code := 'NAME_NO_LETTERS';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- VALIDAR EMAIL
  IF wemail IS NULL OR TRIM(wemail) = '' THEN
    msg := 'El email no puede estar vacío';
    error_code := 'EMAIL_NULL_EMPTY';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  v_email_clean := LOWER(TRIM(wemail));
  
  IF LENGTH(v_email_clean) < 5 OR LENGTH(v_email_clean) > 320 THEN
    msg := 'El email debe tener entre 5 y 320 caracteres. Recibido: ' || LENGTH(v_email_clean) || ' caracteres';
    error_code := 'EMAIL_INVALID_LENGTH';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF v_email_clean !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
    msg := 'El email tiene formato inválido. Debe ser usuario@dominio.com';
    error_code := 'EMAIL_INVALID_FORMAT';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  SELECT EXISTS(
    SELECT 1 FROM tab_users 
    WHERE email = v_email_clean
  ) INTO v_email_exists;
  
  IF v_email_exists THEN
    msg := 'El email ya está registrado: ' || v_email_clean;
    error_code := 'EMAIL_DUPLICATE';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- VALIDAR PASSWORD HASH
  IF wpassword_hash IS NULL OR TRIM(wpassword_hash) = '' THEN
    msg := 'El password hash no puede estar vacío';
    error_code := 'PASSWORD_HASH_NULL_EMPTY';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF LENGTH(wpassword_hash) != 60 THEN
    msg := 'El password hash debe tener exactamente 60 caracteres (bcrypt). Recibido: ' || LENGTH(wpassword_hash) || ' caracteres';
    error_code := 'PASSWORD_HASH_INVALID_LENGTH';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  IF wpassword_hash !~ '^\$2[ayb]\$[0-9]{2}\$[A-Za-z0-9./]{53}$' THEN
    msg := 'El password hash debe tener formato bcrypt válido ($2a$/$2b$/$2y$ + rounds + salt + hash)';
    error_code := 'PASSWORD_HASH_INVALID_FORMAT';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- VALIDAR AVATAR URL (OPCIONAL)
  IF wavatar_url IS NOT NULL THEN
    IF LENGTH(wavatar_url) > 500 THEN
      msg := 'La URL del avatar no puede exceder 500 caracteres. Recibido: ' || LENGTH(wavatar_url) || ' caracteres';
      error_code := 'AVATAR_URL_TOO_LONG';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
    END IF;
    
    IF wavatar_url !~ '^https?://' THEN
      msg := 'La URL del avatar debe comenzar con http:// o https://';
      error_code := 'AVATAR_URL_INVALID_FORMAT';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
    END IF;
  END IF;
  
  -- GENERAR ID DE USUARIO (SECUENCIAL)
  SELECT COALESCE(MAX(tab_users.id_user), 0) + 1 INTO v_generated_id FROM tab_users;
  
  RAISE NOTICE '[fun_create_user] ID generado (secuencial): %', v_generated_id;
  
  -- VALIDAR ROL PASAJERO EXISTE
  SELECT EXISTS(
    SELECT 1 FROM tab_roles 
    WHERE id_role = 1 AND is_active = TRUE
  ) INTO v_role_exists;
  
  IF NOT v_role_exists THEN
    msg := 'Error: El rol de Pasajero (id_role = 1) no existe o está inactivo';
    error_code := 'ROLE_PASSENGER_NOT_FOUND';
    RAISE NOTICE '[fun_create_user] ERROR: %', msg;
    RETURN;
  END IF;
  
  -- INSERTAR USUARIO EN TAB_USERS
  BEGIN
    INSERT INTO tab_users (
      id_user,
      email,
      password_hash,
      full_name,
      avatar_url,
      user_create
    )
    VALUES (
      v_generated_id,
      v_email_clean,
      wpassword_hash,
      v_name_clean,
      wavatar_url,
      wuser_create
    );
    
    RAISE NOTICE '[fun_create_user] Usuario insertado en tab_users: %', v_generated_id;
    
  EXCEPTION
    WHEN unique_violation THEN
      msg := 'Error: El email ya está registrado (violación UNIQUE): ' || v_email_clean;
      error_code := 'USER_INSERT_UNIQUE_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN not_null_violation THEN
      msg := 'Error: Falta un campo obligatorio al crear el usuario';
      error_code := 'USER_INSERT_NOT_NULL_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación de clave foránea al crear el usuario (user_create inválido: ' || wuser_create || ')';
      error_code := 'USER_INSERT_FK_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN check_violation THEN
      msg := 'Error: Violación de restricción CHECK al crear el usuario (email format)';
      error_code := 'USER_INSERT_CHECK_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al insertar usuario: ' || SQLERRM;
      error_code := 'USER_INSERT_ERROR';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
  END;
  
  -- ASIGNAR ROL PASAJERO AUTOMÁTICAMENTE
  BEGIN
    INSERT INTO tab_user_roles (
      id_user,
      id_role,
      assigned_by
    )
    VALUES (
      v_generated_id,
      1,  -- Rol Pasajero
      wuser_create
    );
    
    RAISE NOTICE '[fun_create_user] Rol Pasajero asignado al usuario: %', v_generated_id;
    
  EXCEPTION
    WHEN unique_violation THEN
      msg := 'Error: Violación UNIQUE al asignar rol (usuario ya tiene el rol)';
      error_code := 'USER_ROLE_INSERT_UNIQUE_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN foreign_key_violation THEN
      msg := 'Error: Violación FK al asignar rol (usuario o rol no existe)';
      error_code := 'USER_ROLE_INSERT_FK_VIOLATION';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
      
    WHEN OTHERS THEN
      msg := 'Error inesperado al asignar rol: ' || SQLERRM;
      error_code := 'USER_ROLE_INSERT_ERROR';
      RAISE NOTICE '[fun_create_user] ERROR: %', msg;
      RETURN;
  END;
  
  -- RETORNO EXITOSO
  success := TRUE;
  msg := 'Usuario creado exitosamente con rol Pasajero';
  error_code := NULL;
  id_user := v_generated_id;
  
  RAISE NOTICE '[fun_create_user] Éxito: Usuario % creado con ID %', v_email_clean, v_generated_id;
  
END;
$$;

-- Agregar comentario
COMMENT ON FUNCTION fun_create_user IS 
'v3.0 - Crea usuario con ID secuencial (MAX+1). Valida email, nombre, password hash bcrypt. Asigna rol Pasajero automáticamente.';

-- =============================================
-- PRUEBA RÁPIDA
-- =============================================

-- Verificar que la función fue creada
\df fun_create_user

-- =============================================
-- FIN DEL DEPLOY
-- =============================================

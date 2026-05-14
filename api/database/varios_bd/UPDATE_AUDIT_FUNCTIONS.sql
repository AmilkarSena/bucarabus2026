-- =============================================
-- ACTUALIZACIÓN DE FUNCIONES CON CAMPOS DE AUDITORÍA
-- Archivo consolidado con todas las funciones que usan user_create y user_update
-- Ejecutar en orden para actualizar la base de datos
-- =============================================

-- =============================================
-- 1. fun_create_user (con user_create)
-- =============================================

DROP TYPE IF EXISTS user_created_type CASCADE;
CREATE TYPE user_created_type AS (
    user_id         INTEGER,
    user_email      VARCHAR(320),
    user_name       VARCHAR(100),
    assigned_role   INTEGER,
    created_date    TIMESTAMPTZ
);

DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_user(
    p_email VARCHAR(320),
    p_password_hash VARCHAR(60),
    p_full_name VARCHAR(100),
    p_avatar_url VARCHAR(500) DEFAULT NULL,
    p_user_create VARCHAR(100) DEFAULT 'system'
)
RETURNS user_created_type AS $$
DECLARE
    v_id                INTEGER;
    v_last_id           INTEGER;
    v_random            INTEGER;
    v_epoch_2025        CONSTANT INTEGER := 1735689600;
    v_email_clean       VARCHAR(320);
    v_name_clean        VARCHAR(100);
    v_email_exists      BOOLEAN;
    v_role_id           CONSTANT INTEGER := 1;
BEGIN
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        RAISE EXCEPTION 'El email es obligatorio' USING HINT = 'INVALID_EMAIL';
    END IF;
    
    v_email_clean := LOWER(TRIM(p_email));
    
    IF v_email_clean !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$' THEN
        RAISE EXCEPTION 'Formato de email inválido: %', v_email_clean USING HINT = 'INVALID_EMAIL_FORMAT';
    END IF;

    IF LENGTH(v_email_clean) > 320 THEN
        RAISE EXCEPTION 'El email excede el máximo de 320 caracteres' USING HINT = 'EMAIL_TOO_LONG';
    END IF;

    SELECT EXISTS(SELECT 1 FROM tab_users WHERE email = v_email_clean) INTO v_email_exists;
    
    IF v_email_exists THEN
        RAISE EXCEPTION 'El email % ya está registrado', v_email_clean USING HINT = 'EMAIL_ALREADY_EXISTS';
    END IF;

    IF p_password_hash IS NULL OR TRIM(p_password_hash) = '' THEN
        RAISE EXCEPTION 'El hash de contraseña es obligatorio' USING HINT = 'MISSING_PASSWORD';
    END IF;

    IF LENGTH(p_password_hash) != 60 THEN
        RAISE EXCEPTION 'El hash de contraseña debe tener 60 caracteres (bcrypt)' USING HINT = 'INVALID_PASSWORD_HASH';
    END IF;

    IF p_full_name IS NULL OR TRIM(p_full_name) = '' THEN
        RAISE EXCEPTION 'El nombre completo es obligatorio' USING HINT = 'INVALID_NAME';
    END IF;
    
    v_name_clean := TRIM(p_full_name);
    
    IF LENGTH(v_name_clean) < 3 THEN
        RAISE EXCEPTION 'El nombre debe tener al menos 3 caracteres' USING HINT = 'NAME_TOO_SHORT';
    END IF;

    SELECT COALESCE(MAX(id_user), 0) INTO v_last_id FROM tab_users;
    v_random := FLOOR(RANDOM() * 1000)::INTEGER;
    v_id := v_epoch_2025 + v_last_id + 1 + v_random;

    INSERT INTO tab_users (
        id_user,
        email,
        password_hash,
        full_name,
        avatar_url,
        created_at,
        user_create,
        is_active
    ) VALUES (
        v_id,
        v_email_clean,
        p_password_hash,
        v_name_clean,
        p_avatar_url,
        NOW(),
        p_user_create,
        true
    );

    INSERT INTO tab_user_roles (id_user, id_role, assigned_at, is_active)
    VALUES (v_id, v_role_id, NOW(), TRUE);

    RETURN (
        SELECT ROW(
            u.id_user,
            u.email,
            u.full_name,
            ur.id_role,
            u.created_at
        )::user_created_type
        FROM tab_users u
        LEFT JOIN tab_user_roles ur ON u.id_user = ur.id_user
        WHERE u.id_user = v_id
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fun_create_user IS 'Crear nuevo usuario con generación automática de ID y asignación de rol (con auditoría user_create)';

-- =============================================
-- 2. fun_update_user (con user_update)
-- =============================================

DROP FUNCTION IF EXISTS fun_update_user(INTEGER, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_user(
    p_id_user INTEGER,
    p_full_name VARCHAR(100) DEFAULT NULL,
    p_avatar_url VARCHAR(500) DEFAULT NULL,
    p_user_update VARCHAR(100) DEFAULT 'system'
)
RETURNS TABLE(
    id_user INTEGER,
    email VARCHAR(320),
    full_name VARCHAR(100),
    avatar_url VARCHAR(500),
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_name_clean VARCHAR(100);
    v_user_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM tab_users u WHERE u.id_user = p_id_user) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'El usuario con ID % no existe', p_id_user USING HINT = 'USER_NOT_FOUND';
    END IF;

    IF p_full_name IS NOT NULL THEN
        v_name_clean := TRIM(p_full_name);
        
        IF v_name_clean = '' THEN
            RAISE EXCEPTION 'El nombre no puede estar vacío' USING HINT = 'INVALID_NAME';
        END IF;
        
        IF LENGTH(v_name_clean) < 3 THEN
            RAISE EXCEPTION 'El nombre debe tener al menos 3 caracteres' USING HINT = 'NAME_TOO_SHORT';
        END IF;
    END IF;

    UPDATE tab_users
    SET 
        full_name = COALESCE(v_name_clean, tab_users.full_name),
        avatar_url = COALESCE(p_avatar_url, tab_users.avatar_url),
        updated_at = NOW(),
        user_update = p_user_update
    WHERE tab_users.id_user = p_id_user;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se pudo actualizar el usuario' USING HINT = 'UPDATE_FAILED';
    END IF;

    RETURN QUERY
    SELECT 
        u.id_user,
        u.email,
        u.full_name,
        u.avatar_url,
        u.updated_at
    FROM tab_users u
    WHERE u.id_user = p_id_user;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fun_update_user IS 'Actualizar datos del usuario: full_name y/o avatar_url (con auditoría user_update)';

-- =============================================
-- 3. fun_create_driver (con user_create)
-- =============================================

DROP TYPE IF EXISTS driver_created_type CASCADE;
CREATE TYPE driver_created_type AS (
    user_id         INTEGER,
    user_email      VARCHAR(320),
    user_name       VARCHAR(100),
    driver_id_card  DECIMAL(12,0),
    driver_license  VARCHAR(2),
    license_expiry  DATE,
    created_date    TIMESTAMPTZ
);

DROP FUNCTION IF EXISTS fun_create_driver(
    VARCHAR, VARCHAR, VARCHAR, DECIMAL, VARCHAR, VARCHAR, DATE, VARCHAR, TEXT, VARCHAR
);

CREATE OR REPLACE FUNCTION fun_create_driver(
    p_email             VARCHAR(320),
    p_password_hash     VARCHAR(60),
    p_full_name         VARCHAR(100),
    p_id_card           DECIMAL(12,0),
    p_cel               VARCHAR(15),
    p_license_cat       VARCHAR(2),
    p_license_exp       DATE,
    p_avatar_url        VARCHAR(500) DEFAULT NULL,
    p_address_driver    TEXT DEFAULT NULL,
    p_user_create       VARCHAR(100) DEFAULT 'system'
)
RETURNS driver_created_type AS $$
DECLARE
    v_id                INTEGER;
    v_last_id           INTEGER;
    v_random            INTEGER;
    v_epoch_2025        CONSTANT INTEGER := 1735689600;
    v_email_clean       VARCHAR(320);
    v_name_clean        VARCHAR(100);
    v_valid_licenses    VARCHAR[] := ARRAY['C1', 'C2', 'C3'];
    v_card_exists       BOOLEAN;
    v_email_exists      BOOLEAN;
BEGIN
    IF p_email IS NULL OR TRIM(p_email) = '' THEN
        RAISE EXCEPTION 'El email es obligatorio' USING HINT = 'INVALID_EMAIL';
    END IF;
    
    v_email_clean := LOWER(TRIM(p_email));
    
    IF v_email_clean !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$' THEN
        RAISE EXCEPTION 'Formato de email inválido: %', v_email_clean USING HINT = 'INVALID_EMAIL_FORMAT';
    END IF;

    SELECT EXISTS(SELECT 1 FROM tab_users WHERE email = v_email_clean) INTO v_email_exists;
    IF v_email_exists THEN
        RAISE EXCEPTION 'El email % ya está registrado', v_email_clean USING HINT = 'EMAIL_ALREADY_EXISTS';
    END IF;

    IF p_password_hash IS NULL OR LENGTH(p_password_hash) != 60 THEN
        RAISE EXCEPTION 'Hash de contraseña inválido (debe ser bcrypt de 60 caracteres)' USING HINT = 'INVALID_PASSWORD';
    END IF;

    IF p_full_name IS NULL OR TRIM(p_full_name) = '' THEN
        RAISE EXCEPTION 'El nombre completo es obligatorio' USING HINT = 'INVALID_NAME';
    END IF;
    
    v_name_clean := TRIM(p_full_name);
    IF LENGTH(v_name_clean) < 3 THEN
        RAISE EXCEPTION 'El nombre debe tener al menos 3 caracteres' USING HINT = 'NAME_TOO_SHORT';
    END IF;

    IF p_id_card IS NULL OR p_id_card <= 0 THEN
        RAISE EXCEPTION 'La cédula es inválida' USING HINT = 'INVALID_ID_CARD';
    END IF;

    SELECT EXISTS(SELECT 1 FROM tab_driver_details WHERE id_card = p_id_card) INTO v_card_exists;
    IF v_card_exists THEN
        RAISE EXCEPTION 'La cédula % ya está registrada', p_id_card USING HINT = 'ID_CARD_ALREADY_EXISTS';
    END IF;

    IF p_cel IS NULL OR p_cel !~ '^[0-9]{7,15}$' THEN
        RAISE EXCEPTION 'El teléfono debe contener entre 7 y 15 dígitos' USING HINT = 'INVALID_PHONE';
    END IF;

    IF NOT (UPPER(p_license_cat) = ANY(v_valid_licenses)) THEN
        RAISE EXCEPTION 'Categoría de licencia inválida. Debe ser: C1, C2 o C3' USING HINT = 'INVALID_LICENSE';
    END IF;

    IF p_license_exp IS NULL OR p_license_exp <= CURRENT_DATE THEN
        RAISE EXCEPTION 'La licencia está vencida o expira hoy' USING HINT = 'LICENSE_EXPIRED';
    END IF;

    SELECT COALESCE(MAX(id_user), 0) INTO v_last_id FROM tab_users;
    v_random := FLOOR(RANDOM() * 1000)::INTEGER;
    v_id := v_epoch_2025 + v_last_id + 1 + v_random;

    INSERT INTO tab_users (
        id_user,
        email,
        password_hash,
        full_name,
        avatar_url,
        created_at,
        user_create,
        is_active
    ) VALUES (
        v_id,
        v_email_clean,
        p_password_hash,
        v_name_clean,
        NULLIF(TRIM(p_avatar_url), ''),
        NOW(),
        p_user_create,
        TRUE
    );

    INSERT INTO tab_user_roles (id_user, id_role, assigned_at, is_active)
    VALUES (v_id, 2, NOW(), TRUE);
    
    INSERT INTO tab_driver_details (
        id_card,
        id_user,
        cel,
        license_cat,
        license_exp,
        address_driver,
        date_entry,
        available,
        status_driver,
        created_at,
        user_create
    ) VALUES (
        p_id_card,
        v_id,
        TRIM(p_cel),
        UPPER(p_license_cat),
        p_license_exp,
        NULLIF(TRIM(p_address_driver), ''),
        CURRENT_DATE,
        TRUE,
        TRUE,
        NOW(),
        p_user_create
    );
    
    RETURN (
        SELECT ROW(
            u.id_user,
            u.email,
            u.full_name,
            dd.id_card,
            dd.license_cat,
            dd.license_exp,
            u.created_at
        )::driver_created_type
        FROM tab_users u
        INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
        WHERE u.id_user = v_id
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 4. fun_update_driver (con user_update)
-- =============================================

DROP FUNCTION IF EXISTS fun_update_driver(INTEGER, VARCHAR, VARCHAR, VARCHAR, BOOLEAN, VARCHAR, DATE, TEXT, VARCHAR, BOOLEAN, VARCHAR);

CREATE OR REPLACE FUNCTION fun_update_driver(
    p_id_user           INTEGER,
    p_full_name         VARCHAR(100),
    p_cel               VARCHAR(15),
    p_license_cat       VARCHAR(2),
    p_license_exp       DATE,
    p_address_driver    TEXT DEFAULT NULL,
    p_avatar_url        VARCHAR(500) DEFAULT NULL,
    p_available         BOOLEAN DEFAULT TRUE,
    p_user_update       VARCHAR(100) DEFAULT 'system'
)
RETURNS TABLE(
    id_user         INTEGER,
    email           VARCHAR(320),
    full_name       VARCHAR(100),
    avatar_url      VARCHAR(500),
    id_card         DECIMAL(12,0),
    cel             VARCHAR(15),
    license_cat     VARCHAR(2),
    license_exp     DATE,
    address_driver  TEXT,
    available       BOOLEAN,
    updated_at      TIMESTAMPTZ
) AS $$
DECLARE
    v_name_clean        VARCHAR(100);
    v_valid_licenses    VARCHAR[] := ARRAY['C1', 'C2', 'C3'];
    v_user_exists       BOOLEAN;
    v_is_driver         BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM tab_users u WHERE u.id_user = p_id_user
    ) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'El usuario con ID % no existe', p_id_user USING HINT = 'USER_NOT_FOUND';
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM tab_user_roles ur 
        WHERE ur.id_user = p_id_user 
          AND ur.id_role = 2 
          AND ur.is_active = true
    ) INTO v_is_driver;
    
    IF NOT v_is_driver THEN
        RAISE EXCEPTION 'El usuario no es un conductor activo' USING HINT = 'NOT_A_DRIVER';
    END IF;

    IF p_full_name IS NULL OR TRIM(p_full_name) = '' THEN
        RAISE EXCEPTION 'El nombre completo es obligatorio' USING HINT = 'INVALID_NAME';
    END IF;
    
    v_name_clean := TRIM(p_full_name);
    
    IF LENGTH(v_name_clean) < 3 THEN
        RAISE EXCEPTION 'El nombre debe tener al menos 3 caracteres' USING HINT = 'NAME_TOO_SHORT';
    END IF;

    IF p_cel IS NULL OR TRIM(p_cel) = '' THEN
        RAISE EXCEPTION 'El teléfono es obligatorio' USING HINT = 'INVALID_PHONE';
    END IF;

    IF p_cel !~ '^[0-9]{7,15}$' THEN
        RAISE EXCEPTION 'El teléfono debe contener entre 7 y 15 dígitos' USING HINT = 'INVALID_PHONE_FORMAT';
    END IF;

    IF p_license_cat IS NULL OR NOT (UPPER(p_license_cat) = ANY(v_valid_licenses)) THEN
        RAISE EXCEPTION 'Categoría de licencia inválida. Debe ser: C1, C2 o C3' USING HINT = 'INVALID_LICENSE_CATEGORY';
    END IF;

    IF p_license_exp IS NULL THEN
        RAISE EXCEPTION 'La fecha de expiración de la licencia es obligatoria' USING HINT = 'MISSING_LICENSE_EXP';
    END IF;
    
    IF p_license_exp <= CURRENT_DATE THEN
        RAISE EXCEPTION 'La licencia está vencida o expira hoy' USING HINT = 'LICENSE_EXPIRED';
    END IF;

    UPDATE tab_users 
    SET full_name = v_name_clean,
        avatar_url = NULLIF(TRIM(p_avatar_url), ''),
        updated_at = NOW(),
        user_update = p_user_update
    WHERE id_user = p_id_user;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se pudo actualizar el usuario' USING HINT = 'UPDATE_FAILED';
    END IF;

    UPDATE tab_driver_details 
    SET cel = TRIM(p_cel),
        license_cat = UPPER(p_license_cat),
        license_exp = p_license_exp,
        address_driver = NULLIF(TRIM(p_address_driver), ''),
        available = COALESCE(p_available, TRUE),
        updated_at = NOW(),
        user_update = p_user_update
    WHERE id_user = p_id_user;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontraron detalles del conductor para actualizar' USING HINT = 'DRIVER_DETAILS_NOT_FOUND';
    END IF;

    RETURN QUERY
    SELECT 
        u.id_user,
        u.email,
        u.full_name,
        u.avatar_url,
        dd.id_card,
        dd.cel,
        dd.license_cat,
        dd.license_exp,
        dd.address_driver,
        dd.available,
        u.updated_at
    FROM tab_users u
    INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
    WHERE u.id_user = p_id_user;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fun_update_driver IS 'Actualiza los datos de un conductor (usuario + detalles) con auditoría user_update';

-- =============================================
-- FIN DE ACTUALIZACIÓN
-- =============================================

SELECT 'Funciones actualizadas exitosamente con campos de auditoría' AS resultado;

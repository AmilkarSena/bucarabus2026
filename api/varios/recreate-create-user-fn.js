import pg from 'pg'
import dotenv from 'dotenv'
dotenv.config()

const { Pool } = pg
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'db_bucarabus',
  user: 'postgres',
  password: process.env.DB_POSTGRES_PASSWORD || ''
})

const sql = `
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, TEXT, VARCHAR, SMALLINT, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, TEXT, VARCHAR, SMALLINT);
DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT);

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
  wwemail_clean   tab_users.email_user%TYPE;
  wwname_clean    tab_users.full_name%TYPE;
  wwid_user       tab_users.id_user%TYPE;
BEGIN

  success    := FALSE;
  msg        := '';
  error_code := NULL;
  id_user    := NULL;

  -- 1. VALIDAR EMAIL
  IF wemail_user IS NULL OR TRIM(wemail_user) = '' THEN
    msg := 'El email no puede estar vacio'; error_code := 'EMAIL_EMPTY'; RETURN;
  END IF;

  wwemail_clean := LOWER(TRIM(wemail_user));

  IF LENGTH(wwemail_clean) < 5 OR LENGTH(wwemail_clean) > 320 THEN
    msg := 'El email debe tener entre 5 y 320 caracteres'; error_code := 'EMAIL_INVALID_LENGTH'; RETURN;
  END IF;

  IF wwemail_clean !~ '^[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}$' THEN
    msg := 'El email tiene formato invalido'; error_code := 'EMAIL_INVALID_FORMAT'; RETURN;
  END IF;

  SELECT tab_users.id_user INTO wwid_user
  FROM tab_users
  WHERE tab_users.email_user = wwemail_clean;

  IF FOUND THEN
    msg := 'El email ya esta registrado: ' || wwemail_clean; error_code := 'EMAIL_DUPLICATE'; RETURN;
  END IF;

  -- 2. VALIDAR ROL
  IF wid_role IS NULL THEN
    msg := 'El id_role es obligatorio'; error_code := 'ROLE_NULL'; RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM tab_roles WHERE tab_roles.id_role = wid_role AND is_active = TRUE) THEN
    msg := 'El rol indicado no existe o esta inactivo (id_role: ' || wid_role || ')'; error_code := 'ROLE_NOT_FOUND'; RETURN;
  END IF;

  -- 3. VALIDAR NOMBRE
  IF wfull_name IS NULL OR TRIM(wfull_name) = '' THEN
    msg := 'El nombre completo no puede estar vacio'; error_code := 'NAME_EMPTY'; RETURN;
  END IF;

  wwname_clean := TRIM(REGEXP_REPLACE(wfull_name, '\\s+', ' ', 'g'));

  IF LENGTH(wwname_clean) < 2 THEN
    msg := 'El nombre debe tener al menos 2 caracteres'; error_code := 'NAME_TOO_SHORT'; RETURN;
  END IF;

  IF LENGTH(wwname_clean) > 100 THEN
    msg := 'El nombre no puede exceder 100 caracteres'; error_code := 'NAME_TOO_LONG'; RETURN;
  END IF;

  -- 4. VALIDAR PASSWORD HASH
  IF wpass_user IS NULL OR wpass_user = '' THEN
    msg := 'El password hash no puede estar vacio'; error_code := 'PASSWORD_HASH_EMPTY'; RETURN;
  END IF;

  IF LENGTH(wpass_user) != 60 THEN
    msg := 'El password hash debe tener exactamente 60 caracteres (bcrypt). Recibidos: ' || LENGTH(wpass_user);
    error_code := 'PASSWORD_HASH_INVALID_LENGTH'; RETURN;
  END IF;

  IF wpass_user !~ '^\\$2[ayb]\\$[0-9]{2}\\$[A-Za-z0-9./]{53}$' THEN
    msg := 'El password hash debe tener formato bcrypt valido ($2b$10$...)'; error_code := 'PASSWORD_HASH_INVALID_FORMAT'; RETURN;
  END IF;

  -- 5. GENERAR ID
  SELECT COALESCE(MAX(tab_users.id_user), 0) + 1
    INTO wwid_user
  FROM tab_users;

  -- 6. INSERTAR USUARIO
  BEGIN
    INSERT INTO tab_users (id_user, full_name, email_user, pass_user, is_active)
    VALUES (wwid_user, wwname_clean, wwemail_clean, wpass_user, TRUE);
  EXCEPTION
    WHEN unique_violation THEN
      msg := 'Error de duplicado al insertar el usuario'; error_code := 'INSERT_UNIQUE_VIOLATION'; RETURN;
    WHEN OTHERS THEN
      msg := 'Error al insertar usuario: ' || SQLERRM; error_code := 'INSERT_ERROR'; RETURN;
  END;

  -- 7. ASIGNAR ROL
  BEGIN
    INSERT INTO tab_user_roles (id_user, id_role, assigned_at, assigned_by, is_active)
    VALUES (wwid_user, wid_role, NOW(), wuser_create, TRUE);
  EXCEPTION
    WHEN unique_violation THEN
      msg := 'Error: el usuario ya tiene ese rol asignado'; error_code := 'ROLE_ASSIGN_DUPLICATE'; RETURN;
    WHEN foreign_key_violation THEN
      msg := 'Error FK al asignar rol'; error_code := 'ROLE_ASSIGN_FK_VIOLATION'; RETURN;
    WHEN OTHERS THEN
      msg := 'Error al asignar rol: ' || SQLERRM; error_code := 'ROLE_ASSIGN_ERROR'; RETURN;
  END;

  -- 8. EXITO
  success    := TRUE;
  msg        := 'Usuario creado exitosamente';
  error_code := NULL;
  id_user    := wwid_user;

END;
$$;

GRANT EXECUTE ON FUNCTION fun_create_user(VARCHAR, VARCHAR, VARCHAR, SMALLINT, SMALLINT) TO bucarabus_user;
`

try {
  await pool.query(sql)
  console.log('✅ fun_create_user recreada correctamente')
} catch (e) {
  console.error('❌ Error:', e.message)
} finally {
  await pool.end()
  process.exit(0)
}

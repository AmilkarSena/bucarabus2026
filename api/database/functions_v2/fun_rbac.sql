-- =============================================
-- BucaraBUS - Funciones Almacenadas para RBAC Jerárquico
-- Estandarizado con validaciones Backend y manejo de Excepciones BD
-- =============================================

-- ---------------------------------------------------------
-- 1. Función para crear un permiso
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS fun_create_permission(VARCHAR, VARCHAR, TEXT, VARCHAR);

CREATE OR REPLACE FUNCTION fun_create_permission(
  wname_permission    tab_permissions.name_permission%TYPE,
  wcode_permission    tab_permissions.code_permission%TYPE,
  wdescrip_permission tab_permissions.descrip_permission%TYPE DEFAULT NULL,
  wcode_parent        tab_permissions.code_permission%TYPE    DEFAULT NULL,

  -- Parámetros OUT
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

-- ---------------------------------------------------------
-- 2. Función para asignar permiso a un rol
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS fun_assign_role_permission(SMALLINT, VARCHAR, SMALLINT);

CREATE OR REPLACE FUNCTION fun_assign_role_permission(
  wid_role         tab_role_permissions.id_role%TYPE,
  wcode_permission tab_permissions.code_permission%TYPE,
  wassigned_by     tab_role_permissions.assigned_by%TYPE DEFAULT 1,

  -- Parámetros OUT
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

-- ---------------------------------------------------------
-- 3. fun_get_user_permissions ELIMINADA
-- La consulta de permisos es un SELECT puro → vive en auth.service.js (Node.js)
-- Principio: la BD solo gestiona mutaciones (INSERT/UPDATE/DELETE).
-- ---------------------------------------------------------
DROP FUNCTION IF EXISTS fun_get_user_permissions(INTEGER);

-- ---------------------------------------------------------
-- 4. Función para actualizar masivamente los permisos de un rol
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
    -- 1. Crear Jerarquía de Módulos (Raíces)
    PERFORM fun_create_permission('Módulo Buses',       'MODULE_BUSES',     'Acceso al módulo de buses');
    PERFORM fun_create_permission('Módulo Conductores', 'MODULE_DRIVERS',   'Acceso al módulo de conductores');
    PERFORM fun_create_permission('Módulo Rutas',       'MODULE_ROUTES',    'Acceso al módulo de rutas');
    PERFORM fun_create_permission('Módulo Paradas',     'MODULE_STOPS',     'Acceso al módulo de paradas');
    PERFORM fun_create_permission('Módulo Turnos',      'MODULE_TRIPS',     'Acceso al panel de turnos');
    PERFORM fun_create_permission('Módulo Catálogos',   'MODULE_CATALOGS',  'Acceso a catálogos del sistema');
    PERFORM fun_create_permission('Módulo Configuración','MODULE_SETTINGS', 'Acceso a ajustes del sistema');

    -- 2. Permisos de Buses
    PERFORM fun_create_permission('Ver Buses',      'VIEW_BUSES',    'Ver lista de buses',       'MODULE_BUSES');
    PERFORM fun_create_permission('Crear Buses',    'CREATE_BUSES',  'Añadir nuevos buses',      'MODULE_BUSES');
    PERFORM fun_create_permission('Editar Buses',   'EDIT_BUSES',    'Modificar datos de buses', 'MODULE_BUSES');
    PERFORM fun_create_permission('Eliminar Buses', 'DELETE_BUSES',  'Eliminar buses',           'MODULE_BUSES');

    -- 3. Permisos de Conductores
    PERFORM fun_create_permission('Ver Conductores',      'VIEW_DRIVERS',    'Ver lista de conductores', 'MODULE_DRIVERS');
    PERFORM fun_create_permission('Crear Conductores',    'CREATE_DRIVERS',  'Añadir conductores',       'MODULE_DRIVERS');
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

    -- 7. Permisos de Catálogos (EPS, ARL, Marcas, Compañías, Aseguradoras)
    PERFORM fun_create_permission('Crear Catálogos',    'CREATE_CATALOGS',  'Crear registros en catálogos',           'MODULE_CATALOGS');
    PERFORM fun_create_permission('Editar Catálogos',   'EDIT_CATALOGS',    'Editar registros de catálogos',          'MODULE_CATALOGS');
    PERFORM fun_create_permission('Activar Catálogos',  'TOGGLE_CATALOGS',  'Activar/desactivar registros',           'MODULE_CATALOGS');

    -- 8. Permisos de Configuración (Usuarios)
    PERFORM fun_create_permission('Gestionar Usuarios', 'MANAGE_USERS',  'Asignar roles y permisos',     'MODULE_SETTINGS');
    PERFORM fun_create_permission('Crear Usuarios',     'CREATE_USERS',  'Crear nuevos usuarios',        'MODULE_SETTINGS');
    PERFORM fun_create_permission('Editar Usuarios',    'EDIT_USERS',    'Editar datos de usuario',      'MODULE_SETTINGS');

    -- =============================================
    -- ASIGNACIONES DE ROLES (Seed inicial)
    -- Las asignaciones pueden cambiarse desde el Panel de Permisos
    -- =============================================
    
    -- Limpiar asignaciones previas para evitar "permisos fantasma" de corridas anteriores
    DELETE FROM tab_role_permissions;
    
    -- ADMINISTRADOR: Todos los permisos de todos los módulos
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



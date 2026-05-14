-- Tabla de usuarios
CREATE TABLE tab_users (
  id_user       INTEGER NOT NULL,
  email         VARCHAR(320) UNIQUE NOT NULL,
  password_hash VARCHAR(60) NOT NULL,
  full_name     VARCHAR(100) NOT NULL,
  avatar_url    VARCHAR(500),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ,
  user_create   INTEGER NOT NULL DEFAULT 1735689600,  -- FK a tab_users(id_user), default = usuario sistema
  user_update   INTEGER,                              -- FK a tab_users(id_user)
  last_login    TIMESTAMPTZ,
  is_active     BOOLEAN NOT NULL DEFAULT true,

  PRIMARY KEY (id_user),

  CONSTRAINT chk_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT fk_users_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_users_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL
);

CREATE INDEX idx_users_email ON tab_users(LOWER(email));
CREATE INDEX idx_users_active ON tab_users(is_active) WHERE is_active = true;
CREATE INDEX idx_users_created_by ON tab_users(user_create);
CREATE INDEX idx_users_updated_by ON tab_users(user_update) WHERE user_update IS NOT NULL;

CREATE TABLE tab_roles (
  id_role     SMALLINT PRIMARY KEY,
  role_name   VARCHAR(50) NOT NULL,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ,
  user_create INTEGER NOT NULL DEFAULT 1735689600,  -- FK a tab_users(id_user)
  user_update INTEGER,                              -- FK a tab_users(id_user)
  
  CONSTRAINT fk_roles_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_roles_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL
);

CREATE TABLE tab_user_roles (
  id_user     INTEGER NOT NULL REFERENCES tab_users(id_user),
  id_role     SMALLINT NOT NULL REFERENCES tab_roles(id_role),
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  assigned_by INTEGER REFERENCES tab_users(id_user),
  is_active   BOOLEAN NOT NULL DEFAULT true,
  
  PRIMARY KEY (id_user, id_role)
);

CREATE TABLE tab_driver_details (
  id_card           DECIMAL(12,0)   NOT NULL,                -- cédula conductor
  id_user           INTEGER         NOT NULL UNIQUE REFERENCES tab_users(id_user), 
  cel               VARCHAR(15)     NOT NULL,                -- telefono conductor
  available         BOOLEAN         NOT NULL DEFAULT TRUE,   -- disponibilidad conductor
  license_cat       VARCHAR(2)      NOT NULL,                -- categoria licencia
  license_exp       DATE            NOT NULL,                -- fecha expiracion licencia
  address_driver    TEXT,                                    -- direccion conductor
  date_entry        DATE            NOT NULL DEFAULT (CURRENT_DATE),
  status_driver     BOOLEAN         NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),  -- fecha_creacion
  user_create       INTEGER         NOT NULL DEFAULT 1735689600,  -- FK a tab_users(id_user)
  updated_at        TIMESTAMPTZ,                             -- fecha_actualizacion
  user_update       INTEGER,                                 -- FK a tab_users(id_user)
  
  CONSTRAINT pk_drivers_details       PRIMARY KEY (id_card),
  CONSTRAINT chk_drivers_license_cat  CHECK (license_cat IN ('C1', 'C2', 'C3')),
  CONSTRAINT chk_drivers_cel_format   CHECK (cel ~ '^[0-9]{7,15}$'),
  CONSTRAINT chk_drivers_license_exp  CHECK (license_exp > date_entry),
  CONSTRAINT fk_drivers_created_by    FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_drivers_updated_by    FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL
);

---RUTAS FAVORITAS

CREATE TABLE IF NOT EXISTS tab_favorite_routes (
    id_user   INTEGER NOT NULL,
    id_route INTEGER NOT NULL,
    added_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT pk_favorite_routes PRIMARY KEY (id_user,id_route),
    CONSTRAINT fk_fav_route_user   FOREIGN KEY (id_user) REFERENCES tab_users(id_user),
    CONSTRAINT fk_fav_route_route FOREIGN KEY (id_route) REFERENCES tab_routes(id_route)
);

CREATE INDEX idx_fav_user ON tab_favorite_routes(id_user);
CREATE INDEX idx_fav_route ON tab_favorite_routes(id_route);
CREATE INDEX idx_fav_added ON tab_favorite_routes(added_at DESC);

-- ============================================
-- INSERTAR USUARIO DEL SISTEMA (debe existir primero por las FKs)
-- ============================================

-- Usuario especial para operaciones del sistema
-- Este usuario es autorreferenciado en user_create
INSERT INTO tab_users (
  id_user,
  email,
  password_hash,
  full_name,
  created_at,
  user_create,
  is_active
) VALUES (
  1735689600,  -- ID fijo = epoch 2025-01-01
  'system@bucarabus.local',
  '$2b$10$SYSTEMUSERDUMMYHASH0000000000000000000000000000000',
  'Sistema Bucarabus',
  NOW(),
  1735689600,  -- Se referencia a sí mismo
  TRUE
)
ON CONFLICT (id_user) DO NOTHING;

-- ============================================
-- INSERTAR ROLES INICIALES
-- ============================================

INSERT INTO tab_roles (id_role, role_name, user_create) VALUES
  (1, 'Pasajero', 1735689600),
  (2, 'Conductor', 1735689600),
  (3, 'Supervisor', 1735689600),
  (4, 'Administrador', 1735689600)
ON CONFLICT (id_role) DO NOTHING;

-- Asignar rol de administrador al usuario del sistema
INSERT INTO tab_user_roles (id_user, id_role, assigned_at, is_active)
VALUES (1735689600, 4, NOW(), TRUE)
ON CONFLICT (id_user, id_role) DO NOTHING;

-- ============================================
-- COMENTARIOS
-- ============================================

COMMENT ON TABLE tab_users IS 'Tabla base de usuarios del sistema (pasajeros, conductores, supervisores, administradores)';
COMMENT ON TABLE tab_roles IS 'Catálogo de roles del sistema';
COMMENT ON TABLE tab_user_roles IS 'Relación muchos-a-muchos: un usuario puede tener múltiples roles';
COMMENT ON TABLE tab_driver_details IS 'Información específica para usuarios con rol de conductor';
COMMENT ON TABLE tab_favorite_routes IS 'Rutas favoritas de los usuarios';

COMMENT ON COLUMN tab_users.user_create IS 'ID del usuario que creó este registro (FK a tab_users)';
COMMENT ON COLUMN tab_users.user_update IS 'ID del usuario que actualizó por última vez (FK a tab_users)';
COMMENT ON COLUMN tab_roles.user_create IS 'ID del usuario administrador que creó este rol';
COMMENT ON COLUMN tab_roles.user_update IS 'ID del usuario administrador que actualizó este rol';
COMMENT ON COLUMN tab_driver_details.user_create IS 'ID del usuario administrador que creó este conductor';
COMMENT ON COLUMN tab_driver_details.user_update IS 'ID del usuario administrador que actualizó este conductor';
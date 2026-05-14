-- =============================================
-- BucaraBUS - Base de Datos Principal
-- Sistema de gestión de transporte público
-- =============================================
-- Version: 2.0
-- Fecha: Febrero 2025
-- Arquitectura: PostgreSQL + PostGIS
-- =============================================

-- =============================================
-- 1. EXTENSIONES
-- =============================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- =============================================
-- 2. LIMPIEZA (DROP en orden inverso de dependencias)
-- =============================================

-- Orden inverso de dependencias FK (hoja → raíz)
-- Nivel 5: tablas que dependen de tab_trips
DROP TABLE IF EXISTS tab_trip_incidents;       -- → tab_trips, tab_incident_types
DROP TABLE IF EXISTS tab_gps_history;          -- → tab_buses, tab_trips
DROP TABLE IF EXISTS tab_trip_events;          -- → tab_trips, tab_trip_statuses, tab_users

-- Nivel 4: tablas que dependen de tab_routes / tab_buses / tab_drivers
DROP TABLE IF EXISTS tab_route_points_assoc;   -- → tab_routes, tab_route_points
DROP TABLE IF EXISTS tab_trips;                -- → tab_routes, tab_buses, tab_drivers, tab_trip_statuses, tab_users

-- Nivel 3: tablas que dependen de tab_buses / tab_routes / tab_drivers
DROP TABLE IF EXISTS tab_bus_assignments;      -- → tab_buses, tab_drivers, tab_users
DROP TABLE IF EXISTS tab_bus_transit_docs;     -- → tab_transit_documents, tab_buses, tab_users
DROP TABLE IF EXISTS tab_bus_insurance;        -- → tab_buses, tab_insurance_types, tab_insurers, tab_users
DROP TABLE IF EXISTS tab_route_points;         -- → tab_users

-- Nivel 2: tablas que dependen de tab_companies / tab_brands / tab_bus_owners / tab_drivers
DROP TABLE IF EXISTS tab_buses;                -- → tab_companies, tab_brands, tab_bus_owners, tab_bus_statuses, tab_users
DROP TABLE IF EXISTS tab_routes;               -- → tab_companies, tab_users
DROP TABLE IF EXISTS tab_driver_accounts;      -- → tab_drivers, tab_users

-- Nivel 1b: catálogos de segundo nivel
DROP TABLE IF EXISTS tab_drivers;              -- → tab_driver_statuses, tab_eps, tab_arl, tab_users
DROP TABLE IF EXISTS tab_bus_owners;           -- → tab_users
DROP TABLE IF EXISTS tab_insurers;             -- sin FK relevantes
DROP TABLE IF EXISTS tab_transit_documents;    -- sin FK relevantes
DROP TABLE IF EXISTS tab_insurance_types;      -- sin FK relevantes
DROP TABLE IF EXISTS tab_brands;               -- sin FK relevantes

-- RBAC: dependen de tab_roles, tab_permissions, tab_users
DROP TABLE IF EXISTS tab_user_permissions;     -- → tab_users, tab_permissions
DROP TABLE IF EXISTS tab_role_permissions;     -- → tab_roles, tab_permissions
DROP TABLE IF EXISTS tab_permissions;          -- → tab_permissions (self-ref padre)

-- Nivel 1a: tablas que dependen solo de tab_users / tab_roles
DROP TABLE IF EXISTS tab_user_roles;           -- → tab_users, tab_roles
DROP TABLE IF EXISTS tab_trip_statuses;        -- → tab_users
DROP TABLE IF EXISTS tab_companies;            -- → tab_users
DROP TABLE IF EXISTS tab_parameters;           -- → tab_users

-- Catálogos raíz (sin dependencias entrantes de otras tablas)
DROP TABLE IF EXISTS tab_driver_statuses;
DROP TABLE IF EXISTS tab_bus_statuses;
DROP TABLE IF EXISTS tab_eps;
DROP TABLE IF EXISTS tab_arl;
DROP TABLE IF EXISTS tab_incident_types;
DROP TABLE IF EXISTS tab_roles;
DROP TABLE IF EXISTS tab_users;

-- Tablas legacy/obsoletas
DROP TABLE IF EXISTS tab_subscriptions;
DROP TABLE IF EXISTS trips;



-- =============================================
-- 3. TABLAS PRINCIPALES (en orden de dependencias)
-- =============================================

-- --------------------------------------------
-- 3.1 TABLA: tab_users
-- Descripción: Tabla base de usuarios del sistema
-- --------------------------------------------

CREATE TABLE tab_users (
  id_user       SMALLINT        GENERATED ALWAYS AS IDENTITY,       -- ID único del usuario
  full_name     VARCHAR(100)    NOT NULL,                       -- Nombre completo del usuario
  email_user    VARCHAR(320)    UNIQUE NOT NULL,                -- Correo electrónico del usuario
  pass_user     VARCHAR(60)     NOT NULL,                       -- Hash de la contraseña del usuario
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,          -- Indica si el usuario está activo

  CONSTRAINT pk_users PRIMARY KEY (id_user),
  CONSTRAINT chk_users_email_format CHECK (email_user ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- --------------------------------------------
-- 3.1.1 TABLA: tab_roles
-- Descripción: Catálogo de roles del sistema
-- --------------------------------------------

CREATE TABLE tab_roles (
  id_role       SMALLINT        NOT NULL,                          -- ID único del rol
  role_name     VARCHAR(30)     NOT NULL DEFAULT 'ROL SIN NOMBRE', -- Nombre del rol
  descrip_role  TEXT,                                              -- Descripción del rol
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,             -- Indica si el rol está activo

  CONSTRAINT pk_roles PRIMARY KEY (id_role)
);

-- --------------------------------------------
-- 3.1.2 TABLA: tab_user_roles
-- Descripción: Relación muchos-a-muchos usuario-rol
-- --------------------------------------------

CREATE TABLE tab_user_roles (
  id_user       SMALLINT        NOT NULL,                       -- ID del usuario
  id_role       SMALLINT        NOT NULL,                       -- ID del rol
  assigned_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),         -- Fecha de asignación
  assigned_by   SMALLINT        NOT NULL DEFAULT 1,            -- ID del usuario que asignó el rol
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,          -- Indica si la asignación está activa

  CONSTRAINT pk_user_roles          PRIMARY KEY (id_user, id_role),
  CONSTRAINT fk_user_roles_user     FOREIGN KEY (id_user)      REFERENCES tab_users(id_user),
  CONSTRAINT fk_user_roles_role     FOREIGN KEY (id_role)      REFERENCES tab_roles(id_role) ON DELETE RESTRICT,
  CONSTRAINT fk_user_roles_assigned FOREIGN KEY (assigned_by)  REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
);

CREATE TABLE tab_eps (
  id_eps          SMALLINT        NOT NULL,
  name_eps        VARCHAR(60)     NOT NULL UNIQUE,
  created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  is_active       BOOLEAN         NOT NULL DEFAULT TRUE,

  CONSTRAINT pk_eps PRIMARY KEY (id_eps)
);

CREATE TABLE tab_arl (
  id_arl          SMALLINT        NOT NULL,
  name_arl        VARCHAR(60)     NOT NULL UNIQUE,
  created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  is_active       BOOLEAN         NOT NULL DEFAULT TRUE,

  CONSTRAINT pk_arl PRIMARY KEY (id_arl)
);

-- Tabla de Compañías de Transporte
CREATE TABLE tab_companies (
  id_company      SMALLINT        NOT NULL,               -- ID único de la Compañía
  company_name    VARCHAR(100)    NOT NULL UNIQUE,        -- Nombre de la Compañía
  nit_company     VARCHAR(15)     NOT NULL UNIQUE,        -- NIT de la Compañía
  created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(), -- Fecha de creación de la Compañía
  updated_at      TIMESTAMPTZ,                            -- Fecha de actualización de la Compañía
  user_create     SMALLINT        NOT NULL DEFAULT 1,    -- ID del usuario que creó el registro
  user_update     SMALLINT,                                -- ID del usuario que actualizó el registro
  is_active       BOOLEAN         NOT NULL DEFAULT TRUE,  -- Indica si la Compañía está activa

  CONSTRAINT pk_companies PRIMARY KEY (id_company),
  CONSTRAINT fk_companies_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_companies_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL
);

-- --------------------------------------------
-- 3.X TABLA: tab_parameters
-- Descripción: Parámetros y configuraciones globales del sistema
-- --------------------------------------------

CREATE TABLE tab_parameters (
  param_key       VARCHAR(50)     NOT NULL,                        -- Clave del parámetro (ej: 'MAX_WORK_HOUR')
  param_value     TEXT            NOT NULL,                        -- Valor del parámetro
  data_type       VARCHAR(20)     NOT NULL DEFAULT 'string',       -- Tipo: string, integer, float, boolean, time, json
  descrip_param   TEXT,                                            -- Descripción de para qué sirve
  is_active       BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si la regla está en vigencia
  updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Cuándo se modificó por última vez
  user_update     SMALLINT,                                        -- Quién lo modificó (FK a tab_users)

  CONSTRAINT pk_parameters           PRIMARY KEY (param_key),
  CONSTRAINT fk_parameters_updated   FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT chk_parameters_type     CHECK (data_type IN ('string', 'integer', 'float', 'boolean', 'time', 'json'))
);

-- --------------------------------------------
-- 3.2 TABLA: tab_driver_statuses
-- Descripción: Catálogo de estados operativos del conductor
-- --------------------------------------------

CREATE TABLE tab_driver_statuses (
  id_status      SMALLINT        NOT NULL,                        -- ID del estado
  status_name    VARCHAR(30)     NOT NULL UNIQUE,                 -- Nombre del estado
  descrip_status TEXT,                                            -- Descripción del estado
  color_hex      VARCHAR(7),                                      -- Color en formato #RRGGBB
  is_active      BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el estado está activo

  CONSTRAINT pk_driver_statuses       PRIMARY KEY (id_status),
  CONSTRAINT chk_driver_status_color  CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$')
);



CREATE TABLE tab_drivers (
  id_driver         BIGINT          NOT NULL,                                           -- Cédula de identidad del conductor
  name_driver       VARCHAR(100)    NOT NULL DEFAULT 'SIN NOMBRE',                      -- Nombre completo del conductor
  address_driver    VARCHAR(200)    NOT NULL DEFAULT 'SIN DIRECCION',                   -- Dirección del conductor
  phone_driver      VARCHAR(15)     NOT NULL DEFAULT '0900000000',                      -- Teléfono del conductor
  email_driver      VARCHAR(320)    NOT NULL DEFAULT 'sa@sa.com',                       -- Correo electrónico del conductor
  birth_date        DATE            NOT NULL DEFAULT '2000-01-01',                      -- Fecha de nacimiento del conductor
  gender_driver     VARCHAR(2)      NOT NULL DEFAULT 'SA',                              -- Género del conductor (M=Masc, F=Fem, T=Trans, NB=No binario, SA=Sin asignar)
  photo_url         VARCHAR(500)    NOT NULL DEFAULT 'SIN FOTO',                        -- URL de la foto del conductor EJ: https://storage.googleapis.com/bucarabus/photos/cedula123.jpg
  license_cat       VARCHAR(2)      NOT NULL DEFAULT 'SA',                              -- Categoría de licencia del conductor
  license_exp       DATE            NOT NULL DEFAULT '2000-01-01',                      -- Fecha de expiración de la licencia
  id_eps            SMALLINT        NOT NULL DEFAULT 1,                                 -- ID de la EPS a la que pertenece el conductor
  id_arl            SMALLINT        NOT NULL DEFAULT 1,                                 -- ID de la ARL a la que pertenece el conductor
  blood_type        VARCHAR(3)      NOT NULL DEFAULT 'SA',                              -- Tipo de sangre del conductor
  emergency_contact VARCHAR(100)    NOT NULL DEFAULT 'SIN CONTACTO',                    -- Contacto de emergencia del conductor
  emergency_phone   VARCHAR(15)     NOT NULL DEFAULT '0900000000',                      -- Teléfono de emergencia del conductor
  date_entry        DATE            NOT NULL DEFAULT CURRENT_DATE,                      -- Fecha de entrada del conductor
  id_status         SMALLINT        NOT NULL DEFAULT 1,                                 -- Estado operativo (FK a tab_driver_statuses)
  is_active         BOOLEAN         NOT NULL DEFAULT TRUE,                              -- Indica si el conductor está activo
  created_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),                             -- Fecha de creación del registro
  user_create       SMALLINT        NOT NULL DEFAULT 1,                                 -- ID del usuario que creó el registro
  updated_at        TIMESTAMPTZ,                                                        -- Fecha de actualización del registro
  user_update       SMALLINT,                                                           -- ID del usuario que actualizó el registro
  
  CONSTRAINT pk_drivers                   PRIMARY KEY (id_driver),
  CONSTRAINT fk_drivers_status            FOREIGN KEY (id_status)     REFERENCES tab_driver_statuses(id_status) ON DELETE RESTRICT,
  CONSTRAINT fk_drivers_created_by        FOREIGN KEY (user_create)   REFERENCES tab_users(id_user)             ON DELETE SET DEFAULT,
  CONSTRAINT fk_drivers_updated_by        FOREIGN KEY (user_update)   REFERENCES tab_users(id_user)             ON DELETE SET NULL,
  CONSTRAINT fk_drivers_eps               FOREIGN KEY (id_eps)        REFERENCES tab_eps(id_eps)                ON DELETE RESTRICT,
  CONSTRAINT fk_drivers_arl               FOREIGN KEY (id_arl)        REFERENCES tab_arl(id_arl)                ON DELETE RESTRICT,
  CONSTRAINT chk_driver_license_cat       CHECK (license_cat IN ('SA', 'C1', 'C2', 'C3')),            
  CONSTRAINT chk_driver_blood_type        CHECK (blood_type IN ('SA', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
  CONSTRAINT chk_driver_email_format      CHECK (email_driver ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  CONSTRAINT chk_driver_phone_format      CHECK (phone_driver ~ '^[0-9]{7,15}$'),
  CONSTRAINT chk_driver_emergency_phone   CHECK (emergency_phone ~ '^[0-9]{7,15}$'),
  CONSTRAINT chk_driver_gender            CHECK (gender_driver IN ('M', 'F', 'O', 'SA'))
);

CREATE TABLE tab_driver_accounts (
  id_driver    BIGINT      NOT NULL,
  id_user      SMALLINT    NOT NULL,
  assigned_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_by  SMALLINT    NOT NULL DEFAULT 1,

  CONSTRAINT pk_driver_accounts  PRIMARY KEY (id_driver),
  CONSTRAINT uq_driver_accounts  UNIQUE (id_user),
  CONSTRAINT fk_da_driver        FOREIGN KEY (id_driver)   REFERENCES tab_drivers(id_driver),
  CONSTRAINT fk_da_user          FOREIGN KEY (id_user)     REFERENCES tab_users(id_user),
  CONSTRAINT fk_da_assigned_by   FOREIGN KEY (assigned_by) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
);
-- --------------------------------------------
-- 3.4 TABLA: tab_bus_owners
-- Descripción: Propietarios de buses
-- --------------------------------------------

CREATE TABLE tab_bus_owners (
  id_owner      BIGINT          NOT NULL,                        -- Cédula de identidad del propietario
  full_name     VARCHAR(100)    NOT NULL,                        -- Nombre completo del propietario
  phone_owner   VARCHAR(15)     NOT NULL,                        -- Teléfono del propietario
  email_owner   VARCHAR(320),                                    -- Correo electrónico del propietario
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el propietario está activo
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Fecha de creación del registro
  updated_at    TIMESTAMPTZ,                                     -- Fecha de actualización del registro
  user_create   SMALLINT        NOT NULL DEFAULT 1,             -- ID del usuario que creó el registro
  user_update   SMALLINT,                                         -- ID del usuario que actualizó el registro

  CONSTRAINT pk_bus_owners            PRIMARY KEY (id_owner),
  CONSTRAINT uq_bus_owners_email      UNIQUE (email_owner),          -- Un propietario no puede tener email duplicado (pero puede ser NULL)
  CONSTRAINT fk_owners_created_by     FOREIGN KEY (user_create)  REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_owners_updated_by     FOREIGN KEY (user_update)  REFERENCES tab_users(id_user) ON DELETE SET NULL,
  CONSTRAINT chk_owners_phone         CHECK (phone_owner ~ '^[0-9]{7,15}$'),
  CONSTRAINT chk_owners_email         CHECK (email_owner IS NULL OR email_owner ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- --------------------------------------------
-- 3.4.1 TABLA: tab_bus_statuses
-- Descripción: Catálogo de estados operativos del bus
-- --------------------------------------------

CREATE TABLE tab_bus_statuses (
  id_status      SMALLINT        NOT NULL,                        -- ID del estado
  status_name    VARCHAR(30)     NOT NULL UNIQUE,                 -- Nombre del estado
  descrip_status TEXT,                                            -- Descripción del estado
  color_hex      VARCHAR(7),                                      -- Color en formato #RRGGBB
  is_active      BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el estado está activo

  CONSTRAINT pk_bus_statuses        PRIMARY KEY (id_status),
  CONSTRAINT chk_bus_status_color   CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- --------------------------------------------
-- 3.4.2 TABLA: tab_brands
-- Descripción: Catálogo de marcas de buses
-- --------------------------------------------

CREATE TABLE tab_brands (
  id_brand      SMALLINT        NOT NULL,
  brand_name    VARCHAR(50)     NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,

  CONSTRAINT pk_brands PRIMARY KEY (id_brand)
);

-- --------------------------------------------
-- 3.5 TABLA: tab_buses
-- Descripción: Catálogo de buses del sistema
-- --------------------------------------------

CREATE TABLE tab_buses (
  id_bus          SMALLINT        GENERATED ALWAYS AS IDENTITY,    -- ID interno del bus (no se usa en la lógica, solo para PK surrogate)
  plate_number    VARCHAR(6)      NOT NULL,                        -- Número de placa del bus
  amb_code        VARCHAR(8)      NOT NULL,                        -- Codigo AMB del bus
  code_internal   VARCHAR(5)      NOT NULL UNIQUE,                 -- Código interno de la empresa para el bus
  id_company      SMALLINT        NOT NULL,                        -- ID de la Compañía a la que pertenece el bus
  id_brand        SMALLINT        NULL,                            -- Marca del bus (FK a tab_brands)
  model_name      VARCHAR(50)     NOT NULL DEFAULT 'SIN MODELO',   -- Modelo del bus (ej: OF 1721, King Long)
  model_year      SMALLINT        NOT NULL DEFAULT 2000,           -- Año del modelo del bus
  capacity_bus    SMALLINT        NOT NULL DEFAULT 1,             -- Capacidad del bus
  chassis_number  VARCHAR(50)     NOT NULL DEFAULT 'SIN CHASIS',   -- Número de chasis del bus
  color_bus       VARCHAR(30)     NOT NULL DEFAULT 'SIN COLOR',    -- Color del bus
  color_app       VARCHAR(7)      DEFAULT '#CCCCCC',             -- Color en formato #RRGGBB para mostrar en la app
  photo_url       VARCHAR(500)    DEFAULT 'SIN FOTO',              -- URL de la foto del bus EJ: https://storage.googleapis.com/bucarabus/photos/placa123.jpg
  gps_device_id   VARCHAR(20)     UNIQUE,                          -- IMEI o serial del dispositivo GPS instalado en el bus
  id_owner        BIGINT          NOT NULL,                        -- Cédula del propietario (FK a tab_bus_owners)
  id_status       SMALLINT        NOT NULL DEFAULT 1,              -- Estado operativo del bus (FK a tab_bus_statuses)
  is_active       BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el bus está activo (eliminación lógica)
  created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Fecha de creación del registro
  updated_at      TIMESTAMPTZ,                                     -- Fecha de actualización del registro
  user_create     SMALLINT        NOT NULL DEFAULT 1,              -- ID del usuario que creó el registro
  user_update     SMALLINT,                                        -- ID del usuario que actualizó el registro
  
  CONSTRAINT pk_buses                 PRIMARY KEY (id_bus),
  CONSTRAINT fk_buses_created_by      FOREIGN KEY (user_create)   REFERENCES tab_users(id_user)        ON DELETE SET DEFAULT,
  CONSTRAINT fk_buses_updated_by      FOREIGN KEY (user_update)   REFERENCES tab_users(id_user)        ON DELETE SET NULL,
  CONSTRAINT fk_buses_company         FOREIGN KEY (id_company)    REFERENCES tab_companies(id_company) ON DELETE RESTRICT,
  CONSTRAINT fk_buses_owner           FOREIGN KEY (id_owner)      REFERENCES tab_bus_owners(id_owner)  ON DELETE RESTRICT,
  CONSTRAINT fk_buses_status          FOREIGN KEY (id_status)     REFERENCES tab_bus_statuses(id_status) ON DELETE RESTRICT,
  CONSTRAINT fk_buses_brand           FOREIGN KEY (id_brand)      REFERENCES tab_brands(id_brand)        ON DELETE RESTRICT,
  CONSTRAINT chk_buses_plate_format   CHECK (plate_number ~ '^[A-Z]{3}[0-9]{3}$'),
  CONSTRAINT chk_buses_amb_code_format CHECK (amb_code ~ '^[A-Z]{3}-[0-9]{4}$' OR amb_code = 'SA'),
  CONSTRAINT chk_buses_model_year     CHECK (model_year >= 1990),
  CONSTRAINT chk_buses_capacity       CHECK (capacity_bus > 0 AND capacity_bus <= 70)

);

-- --------------------------------------------
-- 3.5.1 TABLA: tab_insurance_types
-- Descripción: Catálogo de tipos de seguro vehicular
-- --------------------------------------------

CREATE TABLE tab_insurance_types (
  id_insurance_type  SMALLINT        GENERATED ALWAYS AS IDENTITY,
  name_insurance     VARCHAR(50)     NOT NULL,                        -- Nombre completo del tipo
  tag_insurance      VARCHAR(5)      NULL,                            -- Abreviatura (SOAT, RCC, etc.)
  descrip_insurance  TEXT,                                            -- Descripción del seguro
  is_mandatory       BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si es obligatorio para operar
  is_active          BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el tipo está activo

  CONSTRAINT pk_insurance_types PRIMARY KEY (id_insurance_type),
  CONSTRAINT uq_insurance_tag   UNIQUE (tag_insurance),
  CONSTRAINT uq_insurance_name  UNIQUE (name_insurance)
);

-- --------------------------------------------
-- 3.5.2 TABLA: tab_insurers
-- Descripción: Catálogo de aseguradoras
-- --------------------------------------------

CREATE TABLE tab_insurers (
  id_insurer    SMALLINT        NOT NULL,
  insurer_name  VARCHAR(100)    NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,

  CONSTRAINT pk_insurers PRIMARY KEY (id_insurer)
);

-- --------------------------------------------
-- 3.5.3 TABLA: tab_bus_insurance
-- Descripción: Póliza vigente de cada tipo de seguro por bus.
--              Un solo registro por (bus, tipo). Al renovar: DELETE + INSERT (el trigger de auditoría captura ambos).
-- --------------------------------------------

CREATE TABLE tab_bus_insurance (
  id_bus             SMALLINT        NOT NULL,                        -- ID interno del bus (parte del PK)
  id_insurance_type  SMALLINT        NOT NULL,                        -- Tipo de seguro (parte del PK)
  id_insurance       VARCHAR(50)     NOT NULL,                        -- Número de póliza emitido por la aseguradora
  id_insurer         SMALLINT        NOT NULL,                        -- Aseguradora (FK a tab_insurers)
  start_date_insu    DATE            NOT NULL,                        -- Fecha de inicio de vigencia
  end_date_insu      DATE            NOT NULL,                        -- Fecha de vencimiento
  doc_url            VARCHAR(500),                                    -- URL del documento del seguro
  created_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Fecha de creación del registro
  updated_at         TIMESTAMPTZ,                                     -- Fecha de última actualización
  user_create        SMALLINT        NOT NULL DEFAULT 1,              -- ID del usuario que creó el registro
  user_update        SMALLINT,                                        -- ID del usuario que actualizó el registro

  CONSTRAINT pk_bus_insurance              PRIMARY KEY (id_bus, id_insurance_type),
  CONSTRAINT uq_insurance_number           UNIQUE (id_insurance),
  CONSTRAINT fk_insurance_bus              FOREIGN KEY (id_bus)             REFERENCES tab_buses(id_bus)                                  ON DELETE RESTRICT,
  CONSTRAINT fk_insurance_type             FOREIGN KEY (id_insurance_type)  REFERENCES tab_insurance_types(id_insurance_type)             ON DELETE RESTRICT,
  CONSTRAINT fk_insurance_insurer          FOREIGN KEY (id_insurer)         REFERENCES tab_insurers(id_insurer)                           ON DELETE RESTRICT,
  CONSTRAINT fk_insurance_created_by       FOREIGN KEY (user_create)        REFERENCES tab_users(id_user)                                 ON DELETE SET DEFAULT,
  CONSTRAINT fk_insurance_updated_by       FOREIGN KEY (user_update)        REFERENCES tab_users(id_user)                                 ON DELETE SET NULL,
  CONSTRAINT chk_insurance_dates           CHECK (end_date_insu > start_date_insu)
);



-- --------------------------------------------
-- 3.5.4 TABLA: tab_transit_documents
-- Descripción: Catálogo de documentos de tránsito (TECNO, Tarjeta de Operación, etc.)
-- --------------------------------------------

CREATE TABLE tab_transit_documents (
  id_doc            SMALLINT        GENERATED ALWAYS AS IDENTITY,
  name_doc          VARCHAR(100)    NOT NULL,                        -- Nombre descriptivo del documento
  tag_transit_doc   VARCHAR(5)      NULL,                            -- Abreviatura (TECNO, LTC, etc.)
  descrip_doc       TEXT,                                            -- Descripción del documento
  is_mandatory      BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el documento es obligatorio para operar
  has_expiration    BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el documento tiene vencimiento
  is_active         BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el documento está activo

  CONSTRAINT pk_transit_documents  PRIMARY KEY (id_doc),
  CONSTRAINT uq_transit_doc_tag    UNIQUE (tag_transit_doc),
  CONSTRAINT uq_transit_doc_name   UNIQUE (name_doc)
);

-- --------------------------------------------
-- 3.5.5 TABLA: tab_bus_transit_docs
-- Descripción: Documento de tránsito vigente de cada tipo por bus.
--              Un solo registro por (tipo, bus). Al renovar: DELETE + INSERT (el trigger de auditoría captura ambos).
-- --------------------------------------------

CREATE TABLE tab_bus_transit_docs (
  id_doc         SMALLINT        NOT NULL,                        -- ID del documento (parte del PK)
  id_bus         SMALLINT        NOT NULL,                        -- ID interno del bus (parte del PK)
  doc_number     VARCHAR(50)     NOT NULL,                        -- Número del documento específico para ese bus
  init_date      DATE            NOT NULL,                        -- Fecha de emisión del documento
  end_date       DATE            NOT NULL,                        -- Fecha de vencimiento del documento
  doc_url        VARCHAR(500),                                    -- URL del documento escaneado
  created_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Fecha de creación del registro
  updated_at     TIMESTAMPTZ,                                     -- Fecha de última actualización
  user_create    SMALLINT        NOT NULL DEFAULT 1,              -- ID del usuario que creó el registro
  user_update    SMALLINT,                                        -- ID del usuario que actualizó el registro

  CONSTRAINT pk_bus_transit_docs          PRIMARY KEY (id_doc, id_bus),
  CONSTRAINT fk_transit_doc_type          FOREIGN KEY (id_doc)       REFERENCES tab_transit_documents(id_doc) ON DELETE RESTRICT,
  CONSTRAINT fk_transit_doc_bus           FOREIGN KEY (id_bus)       REFERENCES tab_buses(id_bus)       ON DELETE RESTRICT,
  CONSTRAINT fk_transit_doc_created       FOREIGN KEY (user_create)  REFERENCES tab_users(id_user)            ON DELETE SET DEFAULT,
  CONSTRAINT fk_transit_doc_updated       FOREIGN KEY (user_update)  REFERENCES tab_users(id_user)            ON DELETE SET NULL,
  CONSTRAINT chk_transit_doc_dates        CHECK (end_date > init_date)
);

-- --------------------------------------------
-- 3.6 TABLA: tab_routes
-- Descripción: Catálogo de rutas con geometría PostGIS
-- --------------------------------------------

CREATE TABLE tab_routes (
  id_route             SMALLINT GENERATED ALWAYS AS IDENTITY,                   -- ID único de la ruta
  name_route           VARCHAR(100)                     NOT NULL,               -- Nombre de la ruta
  path_route           GEOMETRY(LineString, 4326)       NOT NULL,               -- Ruta en formato LineString
  descrip_route        TEXT,                                                    -- Descripción de la ruta
  color_route          VARCHAR(7)                       NOT NULL,               -- Color de la ruta
  id_company           SMALLINT                         NOT NULL,               -- ID de la Compañía a la que pertenece la ruta
  first_trip           TIME,                                                    -- Hora del primer viaje del día
  last_trip            TIME,                                                    -- Hora del último viaje del día
  departure_route_sign VARCHAR(100),                                            -- Cartel frontal: dirección saliente
  return_route_sign    VARCHAR(100),                                            -- Cartel frontal: dirección retorno
  route_fare           SMALLINT                        NOT NULL DEFAULT 0,     -- Tarifa de la ruta
  is_circular          BOOLEAN                          NOT NULL DEFAULT TRUE,  -- TRUE si la ruta es un circuito cerrado
  is_active            BOOLEAN                          NOT NULL DEFAULT TRUE,  -- Indica si la ruta está activa
  created_at           TIMESTAMPTZ                      NOT NULL DEFAULT NOW(), -- Fecha de creación del registro
  updated_at           TIMESTAMPTZ,                                             -- Fecha de actualización del registro
  user_create          SMALLINT                         NOT NULL DEFAULT 1,     -- ID del usuario que creó el registro
  user_update          SMALLINT,                                                -- ID del usuario que actualizó el registro

  CONSTRAINT pk_routes             PRIMARY KEY (id_route),
  CONSTRAINT fk_routes_company     FOREIGN KEY (id_company)   REFERENCES tab_companies(id_company) ON DELETE RESTRICT,
  CONSTRAINT fk_routes_created_by  FOREIGN KEY (user_create)  REFERENCES tab_users(id_user)        ON DELETE SET DEFAULT,
  CONSTRAINT fk_routes_updated_by  FOREIGN KEY (user_update)  REFERENCES tab_users(id_user)        ON DELETE SET NULL,
  CONSTRAINT chk_routes_color      CHECK (color_route ~ '^#[0-9A-Fa-f]{6}$'),
  CONSTRAINT chk_routes_trip_times CHECK (first_trip IS NULL OR last_trip IS NULL OR first_trip < last_trip)
);

-- --------------------------------------------
-- 3.7 TABLA: tab_route_points
-- Descripción: Catálogo global de puntos de ruta.
--   point_type: 1 = Parada (pasajeros), 2 = Referencia (hito/navegación)
--   is_checkpoint = TRUE si el punto es además punto de control operacional.
--   Una misma parada puede pertenecer a múltiples rutas (vía assoc).
-- --------------------------------------------

CREATE TABLE tab_route_points (
  id_point          SMALLINT        GENERATED ALWAYS AS IDENTITY,  -- PK autoincremental
  point_type        SMALLINT        NOT NULL DEFAULT 1,             -- 1=Parada  2=Referencia
  name_point        VARCHAR(100)    NOT NULL,                       -- Nombre del punto
  location_point    GEOMETRY(Point, 4326) NOT NULL,                 -- Coordenadas GPS
  descrip_point     TEXT,                                           -- Descripción adicional
  is_checkpoint     BOOLEAN         NOT NULL DEFAULT FALSE,          -- Punto de control operacional
  is_active         BOOLEAN         NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ,
  user_create       SMALLINT        NOT NULL DEFAULT 1,
  user_update       SMALLINT,

  CONSTRAINT pk_route_points         PRIMARY KEY (id_point),
  CONSTRAINT chk_route_points_type   CHECK (point_type IN (1, 2)),
  CONSTRAINT fk_route_points_create  FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT fk_route_points_update  FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL
);

-- --------------------------------------------
-- 3.7.1 TABLA: tab_route_points_assoc
-- Descripción: Asigna puntos a rutas con orden, distancia
--              acumulada y tiempo estimado desde el inicio.
-- --------------------------------------------

CREATE TABLE tab_route_points_assoc (
  id_route          SMALLINT        NOT NULL,                       -- FK → tab_routes
  id_point          SMALLINT        NOT NULL,                       -- FK → tab_route_points
  point_order       SMALLINT        NOT NULL,                       -- Posición en la ruta (1, 2, 3…)
  dist_from_start   NUMERIC(7,3),                                   -- km acumulados desde el inicio
  eta_seconds       INTEGER,                                        -- Tiempo estimado (s) desde el inicio
  is_active         BOOLEAN         NOT NULL DEFAULT TRUE,

  CONSTRAINT pk_route_points_assoc        PRIMARY KEY (id_route, point_order),
  -- uq_route_points_assoc_point eliminado: una parada puede aparecer más de una vez en la misma ruta
  CONSTRAINT fk_route_points_assoc_route  FOREIGN KEY (id_route)  REFERENCES tab_routes(id_route),
  CONSTRAINT fk_route_points_assoc_point  FOREIGN KEY (id_point)  REFERENCES tab_route_points(id_point)  ON DELETE RESTRICT,
  CONSTRAINT chk_route_points_assoc_order CHECK (point_order > 0),
  CONSTRAINT chk_route_points_assoc_dist  CHECK (dist_from_start IS NULL OR dist_from_start >= 0),
  CONSTRAINT chk_route_points_assoc_eta   CHECK (eta_seconds     IS NULL OR eta_seconds     >= 0)
);


-- --------------------------------------------
-- 3.8 TABLA: tab_bus_assignments
-- Descripción: Historial de asignaciones bus-conductor
-- --------------------------------------------

CREATE TABLE tab_bus_assignments (
  id_bus        SMALLINT        NOT NULL,                        -- ID interno del bus
  id_driver     BIGINT          NOT NULL,                        -- Cédula del conductor (FK a tab_drivers)
  assigned_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Fecha y hora de inicio de la asignación
  unassigned_at TIMESTAMPTZ,                                     -- Fecha y hora de fin de la asignación (NULL = activa)
  assigned_by   SMALLINT        NOT NULL DEFAULT 1,              -- ID del usuario que realizó la asignación
  unassigned_by SMALLINT,                                        -- ID del usuario que realizó la desasignación
  
  CONSTRAINT pk_bus_assignments             PRIMARY KEY (id_bus, id_driver, assigned_at),
  CONSTRAINT fk_assignments_bus             FOREIGN KEY (id_bus)  REFERENCES tab_buses(id_bus) ON DELETE RESTRICT,
  CONSTRAINT fk_assignments_driver          FOREIGN KEY (id_driver)     REFERENCES tab_drivers(id_driver)    ON DELETE RESTRICT,
  CONSTRAINT fk_assignments_assigned_by     FOREIGN KEY (assigned_by)   REFERENCES tab_users(id_user)      ON DELETE SET DEFAULT,
  CONSTRAINT fk_assignments_unassigned_by   FOREIGN KEY (unassigned_by) REFERENCES tab_users(id_user)      ON DELETE SET NULL,
  CONSTRAINT chk_assignments_dates          CHECK (unassigned_at IS NULL OR unassigned_at >= assigned_at)
);

-- --------------------------------------------
-- 3.9 TABLA: tab_trip_statuses
-- Descripción: Catálogo de estados de viajes
-- --------------------------------------------

CREATE TABLE tab_trip_statuses (
  id_status      SMALLINT        NOT NULL,                        -- ID del estado
  status_name    VARCHAR(20)     NOT NULL UNIQUE,                 -- Nombre del estado
  descrip_status TEXT,                                            -- Descripción del estado
  color_hex      VARCHAR(7),                                      -- Color del estado
  is_active      BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el estado está activo
  created_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Fecha de creación del registro
  user_create    SMALLINT        NOT NULL DEFAULT 1,              -- ID del usuario que creó el registro
  
  CONSTRAINT pk_trip_statuses               PRIMARY KEY (id_status),
  CONSTRAINT fk_trip_statuses_created_by    FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT,
  CONSTRAINT chk_trip_statuses_color        CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- --------------------------------------------
-- 3.10 TABLA: tab_trips
-- Descripción: Turnos/viajes programados para las rutas
-- --------------------------------------------
CREATE TABLE tab_trips (
  id_trip              INTEGER         GENERATED ALWAYS AS IDENTITY,    -- ID del viaje
  id_route             SMALLINT        NOT NULL,                        -- ID de la ruta
  trip_date            DATE            NOT NULL,                        -- Fecha del viaje
  start_time           TIME(0)         NOT NULL,                        -- Hora de inicio del viaje
  end_time             TIME(0)         NOT NULL,                        -- Hora de fin del viaje
  id_bus               SMALLINT,                                        -- ID interno del bus (FK a tab_buses)
  id_driver            BIGINT,                                          -- Cédula del conductor (FK a tab_drivers)
  id_status            SMALLINT        NOT NULL DEFAULT 1,              -- Estado 1 = pending
  started_at           TIMESTAMPTZ,                                     -- Timestamps reales de operación 
  completed_at         TIMESTAMPTZ,                                     -- Timestamps reales de operación 
  cancellation_reason  TEXT,                                            -- Razón de cancelación (solo cuando id_status = 5)
  is_active            BOOLEAN         NOT NULL DEFAULT TRUE,           -- Indica si el viaje está activo
  created_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Fecha de creación del registro
  user_create          SMALLINT        NOT NULL DEFAULT 1,              -- ID del usuario que creó el registro
  updated_at           TIMESTAMPTZ,                                     -- Fecha de actualización del registro
  user_update          SMALLINT,                                        -- ID del usuario que actualizó el registro
  
  CONSTRAINT pk_trips             PRIMARY KEY (id_trip),
  CONSTRAINT fk_trips_route       FOREIGN KEY (id_route)    REFERENCES tab_routes(id_route)         ON DELETE RESTRICT,
  CONSTRAINT fk_trips_bus         FOREIGN KEY (id_bus)      REFERENCES tab_buses(id_bus)            ON DELETE SET NULL,
  CONSTRAINT fk_trips_driver      FOREIGN KEY (id_driver)   REFERENCES tab_drivers(id_driver)       ON DELETE SET NULL,
  CONSTRAINT fk_trips_status      FOREIGN KEY (id_status)   REFERENCES tab_trip_statuses(id_status) ON DELETE RESTRICT,
  CONSTRAINT fk_trips_created_by  FOREIGN KEY (user_create) REFERENCES tab_users(id_user)           ON DELETE SET DEFAULT,
  CONSTRAINT fk_trips_updated_by  FOREIGN KEY (user_update) REFERENCES tab_users(id_user)           ON DELETE SET NULL,
  CONSTRAINT chk_trips_times      CHECK (end_time > start_time)
);

-- --------------------------------------------
-- 3.11 TABLA: tab_trip_events
-- Descripción: Historial de cambios de estado de viajes (auditoría completa)
-- --------------------------------------------

CREATE TABLE tab_trip_events (
  -- ERROR CORREGIDO: era INTEGER NOT NULL sin GENERATED, no puede ser PK autoincremental
  id_event        INTEGER         GENERATED ALWAYS AS IDENTITY,    -- ID del evento
  id_trip         INTEGER         NOT NULL,                        -- ID del viaje
  event_type      VARCHAR(20)     NOT NULL,                        -- Tipo de evento
  old_status      SMALLINT,                                        -- Estado anterior
  new_status      SMALLINT,                                        -- Estado nuevo
  event_data      JSONB,                                           -- Datos del evento
  performed_by    SMALLINT,                                        -- ID del usuario que realizó el cambio
  performed_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),          -- Fecha de creación del registro  
  
  CONSTRAINT pk_trip_events               PRIMARY KEY (id_event),
  CONSTRAINT fk_trip_events_trip          FOREIGN KEY (id_trip)                 REFERENCES tab_trips(id_trip)           ON DELETE RESTRICT,
  CONSTRAINT fk_trip_events_old_status    FOREIGN KEY (old_status)              REFERENCES tab_trip_statuses(id_status) ON DELETE RESTRICT,
  CONSTRAINT fk_trip_events_new_status    FOREIGN KEY (new_status)              REFERENCES tab_trip_statuses(id_status) ON DELETE RESTRICT,
  CONSTRAINT fk_trip_events_performed_by  FOREIGN KEY (performed_by)            REFERENCES tab_users(id_user)           ON DELETE SET NULL
);

-- --------------------------------------------
-- 3.12 TABLA: tab_gps_history
-- Descripción: Historial de posiciones GPS por bus/viaje.
--              Solo INSERT, nunca UPDATE. Particionada por mes.
--              La posición en tiempo real se maneja vía WebSocket en memoria.
-- --------------------------------------------

CREATE TABLE tab_gps_history (
  id_position   BIGINT          NOT NULL  GENERATED ALWAYS AS IDENTITY, -- ID autoincremental
  id_bus        SMALLINT        NOT NULL,                               -- ID interno del bus
  id_trip       INTEGER,                                                -- Viaje activo (nullable)
  location_shot GEOMETRY(Point, 4326) NOT NULL,                        -- Posición GPS (lon, lat)
  speed         NUMERIC(5,2),                                           -- Velocidad en km/h
  recorded_at   TIMESTAMPTZ     NOT NULL,                               -- Timestamp del dispositivo GPS
  received_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),                 -- Timestamp de recepción en servidor

  CONSTRAINT pk_gps_history             PRIMARY KEY (id_position, recorded_at),
  CONSTRAINT fk_gps_history_bus         FOREIGN KEY (id_bus)   REFERENCES tab_buses(id_bus)       ON DELETE RESTRICT,
  CONSTRAINT fk_gps_history_trip        FOREIGN KEY (id_trip)  REFERENCES tab_trips(id_trip)      ON DELETE SET NULL,
  CONSTRAINT chk_gps_speed              CHECK (speed IS NULL OR speed >= 0)
) PARTITION BY RANGE (recorded_at);

-- Particiones mensuales (crear una nueva cada mes)
CREATE TABLE tab_gps_history_2026_03
  PARTITION OF tab_gps_history
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE tab_gps_history_2026_04
  PARTITION OF tab_gps_history
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE tab_gps_history_2026_05
  PARTITION OF tab_gps_history
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- --------------------------------------------
-- 3.14 TABLA: tab_incident_types
-- Descripción: Catálogo de tipos de incidentes reportables
-- --------------------------------------------
CREATE TABLE tab_incident_types (
  id_incident      SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name_incident    VARCHAR(50) NOT NULL UNIQUE,
  tag_incident     VARCHAR(20) NOT NULL UNIQUE,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

-- --------------------------------------------
-- 3.15 TABLA: tab_trip_incidents
-- Descripción: Registra incidentes reportados por conductores
-- en tiempo real durante un viaje activo.
-- --------------------------------------------
CREATE TABLE tab_trip_incidents (
  id_trip_incident INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_trip          INTEGER NOT NULL REFERENCES tab_trips(id_trip),
  id_incident      SMALLINT NOT NULL REFERENCES tab_incident_types(id_incident),
  descrip_incident TEXT,
  location_incident GEOMETRY(Point, 4326) NOT NULL,
  status_incident  VARCHAR(20) NOT NULL DEFAULT 'active'
    CONSTRAINT chk_incident_status CHECK (status_incident IN ('active', 'resolved')),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at      TIMESTAMPTZ
);


-- =============================================
-- BucaraBUS - Tablas para Roles y Permisos Jerárquicos
-- =============================================

-- =============================================
-- 1. TABLA: tab_permissions
-- Descripción: Catálogo de permisos disponibles con estructura de árbol
-- =============================================
CREATE TABLE IF NOT EXISTS tab_permissions (
  id_permission SMALLINT GENERATED ALWAYS AS IDENTITY,
  name_permission VARCHAR(100) NOT NULL,
  code_permission VARCHAR(50) NOT NULL UNIQUE,  -- Ej: CREATE_BUSES, MODULE_TRIPS
  id_parent SMALLINT,                           -- FK para jerarquía (Null = Raíz)
  descrip_permission TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT pk_permissions PRIMARY KEY (id_permission),
  CONSTRAINT fk_permissions_parent FOREIGN KEY (id_parent) REFERENCES tab_permissions(id_permission) ON DELETE CASCADE
);

-- Índices para búsqueda rápida
CREATE INDEX IF NOT EXISTS idx_permissions_code ON tab_permissions(code_permission);
CREATE INDEX IF NOT EXISTS idx_permissions_parent ON tab_permissions(id_parent);

-- =============================================
-- 2. TABLA: tab_role_permissions
-- Descripción: Relación muchos a muchos entre roles y permisos
-- =============================================
CREATE TABLE IF NOT EXISTS tab_role_permissions (
  id_role SMALLINT NOT NULL,
  id_permission SMALLINT NOT NULL,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  assigned_by SMALLINT NOT NULL DEFAULT 1,
  
  CONSTRAINT pk_role_permissions PRIMARY KEY (id_role, id_permission),
  CONSTRAINT fk_role_permissions_role FOREIGN KEY (id_role) REFERENCES tab_roles(id_role) ON DELETE CASCADE,
  CONSTRAINT fk_role_permissions_permission FOREIGN KEY (id_permission) REFERENCES tab_permissions(id_permission) ON DELETE CASCADE,
  CONSTRAINT fk_role_permissions_assigned_by FOREIGN KEY (assigned_by) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
);

-- Índice para búsqueda rápida de permisos por rol
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON tab_role_permissions(id_role);

-- =============================================
-- 3. TABLA: tab_user_permissions
-- Descripción: Overrides individuales de permisos por usuario (Hybrid RBAC)
--   is_granted = TRUE  → Allow: permiso extra que el rol no tiene
--   is_granted = FALSE → Deny: revocar un permiso que el rol sí tiene
--
-- NOTA: Los usuarios NUNCA se borran, solo se inactivan (is_active = FALSE).
-- Por eso no se usa ON DELETE CASCADE/SET NULL — el RESTRICT por defecto protege
-- la integridad si accidentalmente se intentara borrar un usuario con overrides.
-- =============================================
CREATE TABLE IF NOT EXISTS tab_user_permissions (
  -- ERROR CORREGIDO: era INTEGER pero tab_users.id_user y tab_permissions.id_permission son SMALLINT
  id_user       SMALLINT NOT NULL,
  id_permission SMALLINT NOT NULL,
  is_granted    BOOLEAN  NOT NULL,   -- TRUE = allow (extra), FALSE = deny (revocar)
  assigned_by   SMALLINT,            -- Quién asignó el override (trazabilidad)
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_user_permissions PRIMARY KEY (id_user, id_permission),
  CONSTRAINT fk_user_permissions_user        FOREIGN KEY (id_user)       REFERENCES tab_users(id_user),
  CONSTRAINT fk_user_permissions_permission  FOREIGN KEY (id_permission) REFERENCES tab_permissions(id_permission),
  CONSTRAINT fk_user_permissions_assigned_by FOREIGN KEY (assigned_by)   REFERENCES tab_users(id_user)
);

-- Índice para resolución rápida de overrides al calcular permisos efectivos
CREATE INDEX IF NOT EXISTS idx_user_permissions_user ON tab_user_permissions(id_user);







-- Índice espacial para incidentes
CREATE INDEX idx_trip_incidents_location ON tab_trip_incidents USING GIST(location_incident);

-- Índice para consultar incidentes activos rápidamente (mapa del pasajero)
CREATE INDEX idx_trip_incidents_active ON tab_trip_incidents(status_incident, created_at DESC)
  WHERE status_incident = 'active';

-- =============================================
-- Índices - tab_drivers
CREATE INDEX idx_driver_status      ON tab_drivers(id_status);
CREATE INDEX idx_driver_license_exp ON tab_drivers(license_exp);
CREATE INDEX idx_driver_active      ON tab_drivers(is_active) WHERE is_active = TRUE;
-- =============================================

-- Índices - tab_user_roles
CREATE INDEX idx_user_roles_role ON tab_user_roles(id_role);
CREATE INDEX idx_user_roles_active ON tab_user_roles(id_user) WHERE is_active = TRUE;

-- Índices - tab_buses
CREATE INDEX idx_buses_status ON tab_buses(id_status);
CREATE UNIQUE INDEX uq_buses_plate_number ON tab_buses(plate_number);     -- plate_number sigue siendo único, pero ya no es PK
CREATE UNIQUE INDEX uq_buses_amb_code     ON tab_buses(amb_code) WHERE amb_code <> 'SA';

-- Índices - tab_bus_assignments (garantizan una sola asignación activa por bus/conductor)
CREATE UNIQUE INDEX uq_bus_active_assign    ON tab_bus_assignments(id_bus)    WHERE unassigned_at IS NULL;
CREATE UNIQUE INDEX uq_driver_active_assign ON tab_bus_assignments(id_driver) WHERE unassigned_at IS NULL;

-- Índices - tab_bus_insurance
CREATE INDEX idx_insurance_bus         ON tab_bus_insurance(id_bus);
CREATE INDEX idx_insurance_end_date    ON tab_bus_insurance(end_date_insu);

-- Índices - tab_bus_transit_docs
CREATE INDEX idx_transit_docs_bus      ON tab_bus_transit_docs(id_bus);
CREATE INDEX idx_transit_docs_end_date ON tab_bus_transit_docs(end_date);

-- Índices - tab_routes
CREATE INDEX idx_routes_path_gist ON tab_routes USING GIST(path_route);
-- ERROR CORREGIDO: start_area y end_area no existen en tab_routes, índices eliminados
-- (Agregar esas columnas primero si se necesitan en el futuro)

-- Índices - tab_route_points
CREATE INDEX idx_route_points_location    ON tab_route_points USING GIST(location_point);
CREATE INDEX idx_route_points_active      ON tab_route_points(is_active)     WHERE is_active = TRUE;
CREATE INDEX idx_route_points_type        ON tab_route_points(point_type);
CREATE INDEX idx_route_points_checkpoint  ON tab_route_points(is_checkpoint) WHERE is_checkpoint = TRUE;

-- Índices - tab_route_points_assoc
CREATE INDEX idx_rpa_route   ON tab_route_points_assoc(id_route, point_order);
CREATE INDEX idx_rpa_point   ON tab_route_points_assoc(id_point);
CREATE INDEX idx_rpa_active  ON tab_route_points_assoc(id_route) WHERE is_active = TRUE;


-- Índices - tab_bus_assignments
CREATE INDEX idx_assignments_driver ON tab_bus_assignments(id_driver);

-- Índices - tab_trips
CREATE INDEX idx_trips_route_date    ON tab_trips(id_route, trip_date);
CREATE INDEX idx_trips_bus           ON tab_trips(id_bus)     WHERE id_bus IS NOT NULL;
CREATE INDEX idx_trips_driver        ON tab_trips(id_driver)  WHERE id_driver IS NOT NULL;
CREATE INDEX idx_trips_active_status ON tab_trips(id_status, trip_date) WHERE is_active = TRUE;

-- Índices - tab_trip_events
CREATE INDEX idx_trip_events_trip_date ON tab_trip_events(id_trip, performed_at DESC);
CREATE INDEX idx_trip_events_performed_by ON tab_trip_events(performed_by) WHERE performed_by IS NOT NULL;

-- Índices - tab_gps_history (aplicados a cada partición automáticamente)
CREATE INDEX idx_gps_history_bus_time    ON tab_gps_history(id_bus, recorded_at DESC);
CREATE INDEX idx_gps_history_trip        ON tab_gps_history(id_trip, recorded_at DESC) WHERE id_trip IS NOT NULL;
CREATE INDEX idx_gps_history_location    ON tab_gps_history USING GIST(location_shot);
CREATE INDEX idx_gps_history_received    ON tab_gps_history(received_at DESC);

-- =============================================
-- 5. DATOS INICIALES (SEEDS)
-- =============================================

-- --------------------------------------------
-- 5.1 Usuario del Sistema
-- --------------------------------------------

INSERT INTO tab_users (
  full_name,
  email_user,
  pass_user,
  is_active
) VALUES (
  'Sistema Bucarabus',
  'system@bucarabus.com',
  '$2b$10$EmofMuRN7LVvjNvI74yxkOXey5/1MyPEqBjQLUqPqazSvWOeBGMgy',
  TRUE
)
ON CONFLICT (email_user) DO NOTHING;


-- --------------------------------------------
-- 5.2 Propietarios de Buses  (ERA: 5.1 duplicado — corregido)
-- --------------------------------------------
INSERT INTO tab_bus_owners (id_owner, full_name, phone_owner, email_owner, user_create) VALUES
  (1234567890, 'Empresa de Transporte ABC', '3001234567', 'empresa@transporte.com', 1)
ON CONFLICT (id_owner) DO NOTHING;









-- --------------------------------------------
-- 5.2 Roles del Sistema
-- --------------------------------------------

INSERT INTO tab_roles (id_role, role_name, descrip_role) VALUES
  (1, 'Administrador',     'Administrador del sistema'),
  (2, 'Turnador',    'Turnador del sistema'),
  (3, 'Conductor', 'Conductor de buses del sistema')
ON CONFLICT (id_role) DO NOTHING;

-- --------------------------------------------
-- 5.3 Asignar rol al usuario del sistema
-- --------------------------------------------

INSERT INTO tab_user_roles (id_user, id_role, assigned_at, is_active)
VALUES (1, 1, NOW(), TRUE)
ON CONFLICT (id_user, id_role) DO NOTHING;

-- --------------------------------------------
-- 5.4 Estados de Viajes (Trip Statuses)
-- --------------------------------------------

INSERT INTO tab_trip_statuses (id_status, status_name, descrip_status, color_hex,user_create) VALUES
  (1, 'pendiente', 'Viaje programado sin asignar', '#FFA500', 1),
  (2, 'asignado', 'Viaje asignado a conductor y bus', '#2196F3', 1),
  (3, 'activo', 'Viaje en curso', '#4CAF50', 1),
  (4, 'completado', 'Viaje completado exitosamente', '#9E9E9E', 1),
  (5, 'cancelado', 'Viaje cancelado', '#F44336', 1)
ON CONFLICT (id_status) DO NOTHING;

-- --------------------------------------------
-- 5.4.1 Estados de Buses
-- --------------------------------------------

INSERT INTO tab_bus_statuses (id_status, status_name, descrip_status, color_hex) VALUES
  (1, 'disponible',       'Bus listo para ser asignado a un viaje',          '#4CAF50'),
  (2, 'en_ruta',          'Bus operando actualmente en un viaje',            '#2196F3'),
  (3, 'mantenimiento',    'Bus en taller, no disponible temporalmente',       '#FFA500'),
  (4, 'fuera_de_servicio','Bus con falla grave, requiere intervención',       '#F44336')
ON CONFLICT (id_status) DO NOTHING;

-- --------------------------------------------
-- 5.4.2 Marcas de Buses
-- --------------------------------------------

INSERT INTO tab_brands (id_brand, brand_name) VALUES
  (1,  'Mercedes-Benz'),
  (2,  'Volvo'),
  (3,  'Scania'),
  (4,  'Hino'),
  (5,  'Marcopolo'),
  (6,  'Busscar'),
  (7,  'Modasa'),
  (8,  'Superpolo'),
  (9,  'King Long'),
  (10, 'Yutong'),
  (11, 'Zhongtong'),
  (12, 'Mascarello')
ON CONFLICT (id_brand) DO NOTHING;

-- --------------------------------------------
-- 5.4.3 Estados de Conductores
-- --------------------------------------------

INSERT INTO tab_driver_statuses (id_status, status_name, descrip_status, color_hex) VALUES
  (1, 'disponible',   'Conductor listo para recibir un viaje',         '#4CAF50'),
  (2, 'en_viaje',     'Conductor operando actualmente en un viaje',    '#2196F3'),
  (3, 'descanso',     'Conductor en pausa temporal',                   '#FFA500'),
  (4, 'incapacitado', 'Conductor con incapacidad médica',              '#FF5722'),
  (5, 'vacaciones',   'Conductor en período de vacaciones',            '#9C27B0'),
  (6, 'ausente',      'Conductor no se presentó',                      '#F44336')
ON CONFLICT (id_status) DO NOTHING;

-- --------------------------------------------
-- 5.4.4 Tipos de Seguro
-- --------------------------------------------

INSERT INTO tab_insurance_types (name_insurance, tag_insurance, descrip_insurance) VALUES
  ('Seg. Obligatorio de Tránsito',  'SOAT', 'Póliza obligatoria de accidentes de tránsito'),
  ('Resp. Civil Contractual',       'RCC',  'Responsabilidad civil con pasajeros a bordo'),
  ('Resp. Civil Extracontractual',  'RCE',  'Responsabilidad civil con terceros afectados')
ON CONFLICT DO NOTHING;

-- --------------------------------------------
-- 5.4.5 Documentos de Tránsito
-- --------------------------------------------

INSERT INTO tab_transit_documents (name_doc, tag_transit_doc, descrip_doc, is_mandatory, has_expiration) VALUES
  ('Revisión Tecnomecánica',    'TECNO', 'Certificado de revisión técnico-mecánica y de gases emitido por CDA', TRUE, TRUE),
  ('Tarjeta de Operación',      'TOP',   'Habilitación para operar en el sistema de transporte público',        TRUE, TRUE),
  ('Licencia de Tránsito',      'LTC',   'Certificado de propiedad del vehículo expedido por el RUNT',          TRUE, FALSE)
ON CONFLICT DO NOTHING;

-- --------------------------------------------
-- 5.4.6 Aseguradoras
-- --------------------------------------------

INSERT INTO tab_insurers (id_insurer, insurer_name) VALUES
  (1,  'Sura'),
  (2,  'Allianz'),
  (3,  'AXA Colpatria'),
  (4,  'Bolívar Seguros'),
  (5,  'Liberty Seguros'),
  (6,  'Seguros del Estado'),
  (7,  'La Previsora'),
  (8,  'Mapfre'),
  (9,  'HDI Seguros'),
  (10, 'Equidad Seguros')
ON CONFLICT (id_insurer) DO NOTHING;

-- --------------------------------------------
-- 5.5 Compañías de Transporte
-- --------------------------------------------

INSERT INTO tab_companies (id_company, company_name, nit_company, user_create) VALUES
  (1, 'Metrolínea', '9001234561', 1),
  (2, 'Cotraoriente', '800234567-2', 1),
  (3, 'Cootransmagdalena', '800345678-3', 1),
  (4, 'Cotrander', '800456789-4', 1)
ON CONFLICT (id_company) DO NOTHING;

-- --------------------------------------------
-- 5.6 EPS (Entidades Promotoras de Salud)
-- --------------------------------------------

INSERT INTO tab_eps (id_eps, name_eps) VALUES
  (1,  'Sura EPS'),
  (2,  'Nueva EPS'),
  (3,  'Sanitas'),
  (4,  'Compensar EPS'),
  (5,  'Famisanar'),
  (6,  'Salud Total'),
  (7,  'Coomeva EPS'),
  (8,  'Coosalud'),
  (9,  'Mutual Ser'),
  (10, 'Cajacopi EPS')
ON CONFLICT (id_eps) DO NOTHING;

-- --------------------------------------------
-- 5.7 ARL (Administradoras de Riesgos Laborales)
-- --------------------------------------------

INSERT INTO tab_arl (id_arl, name_arl) VALUES
  (1, 'Sura ARL'),
  (2, 'Positiva ARL'),
  (3, 'Colmena Seguros'),
  (4, 'Bolívar ARL'),
  (5, 'Axa Colpatria ARL'),
  (6, 'Liberty Seguros'),
  (7, 'Alfa ARL'),
  (8, 'Equidad Seguros')
ON CONFLICT (id_arl) DO NOTHING;

-- --------------------------------------------
-- 5.8 Tipos de Incidentes
-- --------------------------------------------

INSERT INTO tab_incident_types (name_incident, tag_incident) VALUES
  ('Vía cerrada', 'road_closed'),
  ('Accidente', 'accident'),
  ('Protesta/Bloqueo', 'protest'),
  ('Desvío', 'detour'),
  ('Inundación', 'flood'),
  ('Peligro en vía', 'danger')
ON CONFLICT (name_incident) DO NOTHING;

-- --------------------------------------------
-- 5.9 Parámetros del Sistema
-- --------------------------------------------

INSERT INTO tab_parameters (param_key, param_value, data_type, descrip_param, user_update) VALUES
  ('MAX_WORK_HOUR', '22:00:00', 'time', 'Hora máxima hasta la cual un conductor puede operar en la noche', 1),
  ('MIN_REST_HOURS', '8', 'integer', 'Horas mínimas de descanso requeridas entre turnos para conductores', 1),
  ('GPS_TOLERANCE_METERS', '50', 'integer', 'Metros de tolerancia para considerar que un bus llegó a una parada', 1)
ON CONFLICT (param_key) DO NOTHING;


-- =============================================
-- 6. COMENTARIOS DE DOCUMENTACIÓN
-- =============================================

-- Comentarios de tablas
COMMENT ON TABLE tab_users IS 'Tabla de identidad y autenticación de usuarios del sistema';
COMMENT ON TABLE tab_parameters IS 'Parámetros y configuraciones globales del sistema (ej: MAX_WORK_HOUR)';
COMMENT ON TABLE tab_roles IS 'Catálogo de roles del sistema: Administrador, Turnador, Conductor.';
COMMENT ON TABLE tab_user_roles IS 'Relación muchos-a-muchos: un usuario puede tener múltiples roles activos.';
COMMENT ON TABLE tab_drivers IS 'Perfil operativo del conductor, identificado por cédula (id_driver). El vínculo con tab_users (acceso al sistema) se gestiona en tab_driver_accounts.';
COMMENT ON TABLE tab_driver_accounts IS 'Tabla puente entre tab_drivers y tab_users. Un conductor puede existir sin cuenta de sistema (PK=id_driver, UNIQUE id_user garantiza 1 cuenta por conductor).';
COMMENT ON TABLE tab_bus_owners IS 'Propietarios de buses. Un propietario puede tener múltiples buses.';
COMMENT ON TABLE tab_bus_statuses IS 'Catálogo de estados operativos del bus: disponible, en_ruta, mantenimiento, fuera_de_servicio.';
COMMENT ON TABLE tab_driver_statuses IS 'Catálogo de estados operativos del conductor: disponible, en_viaje, descanso, incapacitado, vacaciones, ausente, inactivo.';
COMMENT ON TABLE tab_brands IS 'Catálogo de marcas de buses (Mercedes-Benz, Volvo, Scania, etc.).';
COMMENT ON TABLE tab_buses IS 'Catálogo de buses del sistema de transporte. is_active = eliminación lógica; id_status = estado operativo.';
COMMENT ON COLUMN tab_buses.id_brand IS 'FK nullable a tab_brands. NULL = marca no especificada.';
COMMENT ON TABLE tab_insurance_types IS 'Catálogo de tipos de póliza vehicular: SOAT, RCC, RCE. TECNO no es seguro → ver tab_transit_documents.';
COMMENT ON TABLE tab_transit_documents IS 'Catálogo de documentos de tránsito: TECNO, Tarjeta de Operación (TOP), Licencia de Tránsito (LTC).';
COMMENT ON TABLE tab_bus_transit_docs IS 'Documento de tránsito vigente de cada tipo por bus. PK (id_doc, id_bus) garantiza un único registro por tipo. Al renovar se hace DELETE + INSERT para que el trigger de auditoría registre ambos eventos. Vigencia: CURRENT_DATE BETWEEN init_date AND end_date.';
COMMENT ON TABLE tab_insurers IS 'Catálogo de aseguradoras.';
COMMENT ON TABLE tab_bus_insurance IS 'Póliza vigente de cada tipo de seguro por bus. PK (id_bus, id_insurance_type) garantiza un único registro por tipo. Al renovar se hace DELETE + INSERT para que el trigger de auditoría registre ambos eventos. Vigencia: CURRENT_DATE BETWEEN start_date_insu AND end_date_insu.';
COMMENT ON TABLE tab_routes IS 'Catálogo de rutas con geometría PostGIS';
COMMENT ON TABLE tab_bus_assignments IS 'Historial de asignaciones bus-conductor';
COMMENT ON TABLE tab_trip_statuses IS 'Catálogo de estados de viajes (pending, assigned, active, completed, cancelled)';
COMMENT ON TABLE tab_trips IS 'Turnos/viajes programados para las rutas';
COMMENT ON TABLE tab_trip_events IS 'Historial de eventos y cambios de estado de viajes (auditoría inmutable)';
COMMENT ON TABLE tab_gps_history IS 'Historial de posiciones GPS. Solo INSERT. Particionada mensualmente por recorded_at. Purgar particiones antiguas con DROP TABLE tab_gps_history_YYYY_MM.';

-- Comentarios de campos de auditoría - tab_drivers
COMMENT ON COLUMN tab_drivers.user_create IS 'ID del usuario administrador que creó este conductor';
COMMENT ON COLUMN tab_drivers.user_update IS 'ID del usuario administrador que actualizó este conductor';

-- Comentarios de campos de auditoría - tab_buses
COMMENT ON COLUMN tab_buses.user_create IS 'ID del usuario administrador que creó el bus (FK a tab_users)';
COMMENT ON COLUMN tab_buses.user_update IS 'ID del usuario administrador que actualizó el bus por última vez (FK a tab_users)';
COMMENT ON COLUMN tab_buses.created_at IS 'Fecha y hora de creación del registro';
COMMENT ON COLUMN tab_buses.updated_at IS 'Fecha y hora de última actualización';

-- Comentarios de campos de auditoría - tab_routes
COMMENT ON COLUMN tab_routes.user_create IS 'ID del usuario administrador que creó la ruta (FK a tab_users)';
COMMENT ON COLUMN tab_routes.user_update IS 'ID del usuario administrador que actualizó la ruta por última vez (FK a tab_users)';
COMMENT ON COLUMN tab_routes.created_at IS 'Fecha y hora de creación del registro';
COMMENT ON COLUMN tab_routes.updated_at IS 'Fecha y hora de última actualización';

-- Comentarios de campos de auditoría - tab_bus_assignments
COMMENT ON COLUMN tab_bus_assignments.assigned_by IS 'ID del usuario que realizó la asignación (FK a tab_users)';
COMMENT ON COLUMN tab_bus_assignments.unassigned_by IS 'ID del usuario que realizó la desasignación (FK a tab_users)';


-- Comentarios de campos de auditoría - tab_trip_statuses
COMMENT ON COLUMN tab_trip_statuses.user_create IS 'ID del usuario que creó el estado (FK a tab_users)';

-- Comentarios de campos de auditoría - tab_trips
COMMENT ON COLUMN tab_trips.user_create IS 'ID del usuario administrador que creó el turno/viaje (FK a tab_users)';
COMMENT ON COLUMN tab_trips.user_update IS 'ID del usuario administrador que actualizó el turno/viaje (FK a tab_users)';
COMMENT ON COLUMN tab_trips.created_at IS 'Fecha y hora de creación del registro';
COMMENT ON COLUMN tab_trips.updated_at IS 'Fecha y hora de última actualización';
COMMENT ON COLUMN tab_trips.started_at IS 'Timestamp real de inicio del viaje (puede cambiar si se reactiva)';
COMMENT ON COLUMN tab_trips.completed_at IS 'Timestamp real de finalización del viaje (puede volver a NULL si se reactiva)';
COMMENT ON COLUMN tab_trips.cancellation_reason IS 'Motivo de cancelación del viaje. Solo aplica cuando id_status = 5 (cancelado)';
COMMENT ON COLUMN tab_trips.is_active IS 'Indicador de eliminación lógica (FALSE = eliminado, TRUE = activo)';

-- Comentarios de campos - tab_trip_events
COMMENT ON COLUMN tab_trip_events.event_type IS 'Tipo de evento: created, assigned, started, completed, cancelled, reactivated, deleted';
COMMENT ON COLUMN tab_trip_events.old_status IS 'Estado del viaje antes del evento';
COMMENT ON COLUMN tab_trip_events.new_status IS 'Estado del viaje después del evento';
COMMENT ON COLUMN tab_trip_events.event_data IS 'Datos adicionales del evento en formato JSON (timestamps, razones, etc.)';
COMMENT ON COLUMN tab_trip_events.performed_by IS 'ID del usuario que ejecutó la acción (conductor, administrador, sistema)';
COMMENT ON COLUMN tab_trip_events.performed_at IS 'Timestamp exacto del evento';

COMMENT ON TABLE tab_incident_types IS 'Catálogo de tipos de incidentes reportables por conductores.';
COMMENT ON TABLE tab_trip_incidents IS 'Incidentes reportados por conductores en tiempo real durante un viaje activo.';

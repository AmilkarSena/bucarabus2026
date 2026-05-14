# REPORTE DE REVISIÓN: fun_create_driver

**Fecha**: 2025-01-01  
**Archivo**: `fun_create_driver.sql`  
**Versión**: v2.0  
**Tipo**: Stored Function PostgreSQL  

---

## 1. RESUMEN EJECUTIVO

### Estado Inicial
La función `fun_create_driver` presentaba **errores críticos** que impedirían su funcionamiento:

- ❌ **Error Crítico de Tipo**: Parámetro `p_user_create VARCHAR(100)` usado en campos `INTEGER`
- ❌ **Tipo de Retorno Complejo**: Usaba tipo personalizado `driver_created_type` innecesario
- ❌ **Sin Validación**: No verificaba que el usuario creador existiera
- ❌ **assigned_by NULL**: En asignación de rol debería ser el usuario creador
- ⚠️ **Uso de RAISE EXCEPTION**: Es mejor usar OUT parameters para manejar errores
- ⚠️ **Campos extras**: Incluía `date_entry` y `created_at` que tienen DEFAULT

### Estado Final
✅ Función completamente reescrita con:
- Parámetro `wuser_create INTEGER` (tipo correcto)
- OUT parameters estándar: `success`, `msg`, `error_code`, `id_user`, `id_card`
- Validación completa del usuario creador
- Campo `assigned_by` correctamente asignado
- Manejo de errores con bloques TRY-CATCH
- Simplificación de INSERT (usa DEFAULT donde corresponde)
- 29 códigos de error específicos

---

## 2. ERRORES CRÍTICOS ENCONTRADOS

### Error 1: Incompatibilidad de Tipos en user_create (CRÍTICO)

**Descripción**: El parámetro `p_user_create` era `VARCHAR(100) DEFAULT 'system'` pero se usaba en campos que son `INTEGER NOT NULL`.

**Código Problemático**:
```sql
-- LÍNEA 38 (Declaración)
p_user_create VARCHAR(100) DEFAULT 'system',

-- LÍNEA 260 (INSERT tab_users)
INSERT INTO tab_users (
    ...
    user_create,
    is_active
) VALUES (
    ...
    p_user_create,  -- ❌ ERROR: VARCHAR(100) → INTEGER NOT NULL
    TRUE
);

-- LÍNEA 296 (INSERT tab_driver_details)
INSERT INTO tab_driver_details (
    ...
    user_create
) VALUES (
    ...
    p_user_create  -- ❌ ERROR: VARCHAR(100) → INTEGER NOT NULL
);
```

**Esquema Real**:
```sql
-- tab_users
user_create INTEGER NOT NULL DEFAULT 1735689600
CONSTRAINT fk_users_created_by FOREIGN KEY (user_create) 
    REFERENCES tab_users(id_user) ON DELETE SET DEFAULT DEFERRABLE INITIALLY DEFERRED

-- tab_driver_details
user_create INTEGER NOT NULL DEFAULT 1735689600
CONSTRAINT fk_driver_details_created_by FOREIGN KEY (user_create) 
    REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
```

**Impacto**: 
- ❌ **PostgreSQL error**: "column is of type integer but expression is of type character varying"
- ❌ **Función completamente inoperable**
- ❌ **Bloqueo total de creación de conductores**

**Solución Aplicada**:
```sql
-- Cambio de parámetro
p_user_create VARCHAR(100) DEFAULT 'system' 
→ 
wuser_create tab_users.user_create%TYPE  -- INTEGER

-- Uso correcto
INSERT INTO tab_users (..., user_create) 
VALUES (..., wuser_create)  -- ✅ INTEGER → INTEGER

INSERT INTO tab_driver_details (..., user_create) 
VALUES (..., wuser_create)  -- ✅ INTEGER → INTEGER
```

---

### Error 2: Sin Validación del Usuario Creador (ALTO)

**Descripción**: La función no verificaba que el usuario creador (`p_user_create`) existiera o estuviera activo antes de usarlo.

**Código Problemático**:
```sql
-- No había validación en ninguna parte
-- Se usaba directamente en INSERT sin verificar
```

**Impacto**:
- ❌ **Error FK en runtime** si el usuario no existe
- ⚠️ **Auditoría corrupta** si se usa ID inválido
- ⚠️ **Mensaje de error genérico** sin indicar el problema real

**Solución Aplicada**:
```sql
-- Líneas 68-78 (Nueva validación)
SELECT EXISTS(
    SELECT 1 
    FROM tab_users 
    WHERE tab_users.id_user = wuser_create 
      AND is_active = TRUE
) INTO v_user_exists;

IF NOT v_user_exists THEN
    msg := 'El usuario creador no existe o está inactivo (ID: ' || wuser_create || ')';
    error_code := 'USER_CREATE_NOT_FOUND';
    RETURN;
END IF;
```

---

### Error 3: assigned_by NULL en Asignación de Rol (MEDIO)

**Descripción**: Cuando se asignaba el rol de conductor, el campo `assigned_by` se dejaba como NULL, perdiendo la trazabilidad.

**Código Problemático**:
```sql
-- LÍNEA 278
INSERT INTO tab_user_roles (
    id_user,
    id_role,
    assigned_at,
    assigned_by,  -- ❌ NULL
    is_active
) VALUES (
    v_id,
    2,
    NOW(),
    NULL,  -- ❌ Debería ser el usuario creador
    TRUE
);
```

**Esquema Real**:
```sql
CREATE TABLE tab_user_roles (
    ...
    assigned_by INTEGER,  -- FK a tab_users (permitía NULL pero es mejor registrarlo)
    ...
    CONSTRAINT fk_user_roles_assigned_by FOREIGN KEY (assigned_by) 
        REFERENCES tab_users(id_user) ON DELETE SET NULL
);
```

**Impacto**:
- ⚠️ **Auditoría incompleta**: No se sabe quién asignó el rol
- ⚠️ **Rastro perdido**: Imposible rastrear la acción

**Solución Aplicada**:
```sql
-- Líneas 347-360
INSERT INTO tab_user_roles (
    id_user,
    id_role,
    assigned_by,
    is_active
) VALUES (
    v_new_id,
    2,
    wuser_create,  -- ✅ Registra quién asignó el rol
    TRUE
);
```

---

### Error 4: Tipo de Retorno Complejo Innecesario (MEDIO)

**Descripción**: La función usaba un tipo personalizado `driver_created_type` que es más difícil de consumir desde el backend.

**Código Problemático**:
```sql
-- LÍNEAS 7-15
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

-- LÍNEA 39
RETURNS driver_created_type AS $$

-- LÍNEAS 305-318 (Retorno complejo)
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
```

**Impacto**:
- ⚠️ **Backend complejo**: Requiere manejo especial del tipo personalizado
- ⚠️ **No maneja errores**: Si falla, lanza EXCEPTION (no controlado)
- ⚠️ **Requiere query extra**: JOIN innecesario al final

**Solución Aplicada**:
```sql
-- Parámetros OUT estándar (más simple)
OUT success         BOOLEAN,
OUT msg             VARCHAR,
OUT error_code      VARCHAR,
OUT id_user         INTEGER,
OUT id_card         DECIMAL

-- Retorno simple
success := TRUE;
msg := 'Conductor creado exitosamente: ' || v_name_clean || ' (' || v_email_clean || ')';
error_code := NULL;
id_user := v_new_id;
id_card := wid_card;
RETURN;
```

**Beneficio**: Backend puede hacer:
```javascript
const result = await pool.query('SELECT * FROM fun_create_driver(...)');
if (result.rows[0].success) {
    console.log('Conductor creado con ID:', result.rows[0].id_user);
} else {
    console.error('Error:', result.rows[0].msg, result.rows[0].error_code);
}
```

---

### Error 5: Uso de RAISE EXCEPTION para Validaciones (MEDIO)

**Descripción**: La función usaba `RAISE EXCEPTION` para validaciones, lo que interrumpe la transacción y es difícil de manejar desde el backend.

**Código Problemático**:
```sql
-- LÍNEAS 61-63
IF p_email IS NULL OR TRIM(p_email) = '' THEN
    RAISE EXCEPTION 'El email es obligatorio'
        USING HINT = 'INVALID_EMAIL';
END IF;

-- LÍNEAS 67-69
IF v_email_clean !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
    RAISE EXCEPTION 'El email "%" no tiene un formato válido', v_email_clean
        USING HINT = 'INVALID_EMAIL_FORMAT';
END IF;
```

**Impacto**:
- ⚠️ **Backend complejo**: Debe usar TRY-CATCH para cada llamada
- ⚠️ **Rollback automático**: No se puede continuar la transacción
- ⚠️ **Difícil extraer error_code**: HINT no es estándar

**Solución Aplicada**:
```sql
-- Retorno controlado con OUT parameters
IF wuser_email IS NULL OR TRIM(wuser_email) = '' THEN
    msg := 'El email es obligatorio';
    error_code := 'EMAIL_NULL_EMPTY';
    RETURN;  -- ✅ Retorna sin EXCEPTION
END IF;

IF v_email_clean !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
    msg := 'El email "' || v_email_clean || '" no tiene un formato válido';
    error_code := 'EMAIL_INVALID_FORMAT';
    RETURN;  -- ✅ Retorna sin EXCEPTION
END IF;
```

---

### Error 6: Campos Redundantes en INSERT (BAJO)

**Descripción**: Los INSERT incluían campos que tienen DEFAULT y no necesitan ser especificados.

**Código Problemático**:
```sql
-- LÍNEA 248 (tab_users)
INSERT INTO tab_users (
    ...
    avatar_url,
    created_at,  -- ❌ Tiene DEFAULT NOW()
    user_create,
    is_active
) VALUES (
    ...
    NULLIF(TRIM(p_avatar_url), ''),
    NOW(),  -- ❌ Redundante
    p_user_create,
    TRUE
);

-- LÍNEA 287 (tab_driver_details)
INSERT INTO tab_driver_details (
    ...
    date_entry,  -- ❌ Tiene DEFAULT CURRENT_DATE
    available,
    status_driver,
    created_at,  -- ❌ Tiene DEFAULT NOW()
    user_create
) VALUES (
    ...
    CURRENT_DATE,  -- ❌ Redundante
    TRUE,
    TRUE,
    NOW(),  -- ❌ Redundante
    p_user_create
);
```

**Esquema Real**:
```sql
CREATE TABLE tab_users (
    ...
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- Ya tiene DEFAULT
    ...
);

CREATE TABLE tab_driver_details (
    ...
    date_entry DATE NOT NULL DEFAULT CURRENT_DATE,  -- Ya tiene DEFAULT
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- Ya tiene DEFAULT
    ...
);
```

**Impacto**:
- ⚠️ **Código verboso**: Más líneas innecesarias
- ℹ️ **Funciona correctamente**: Pero no es óptimo

**Solución Aplicada**:
```sql
-- tab_users - eliminado created_at (usa DEFAULT)
INSERT INTO tab_users (
    id_user,
    email,
    password_hash,
    full_name,
    avatar_url,
    user_create,
    is_active
) VALUES (...);  -- created_at se asigna automáticamente

-- tab_driver_details - eliminado date_entry y created_at (usan DEFAULT)
INSERT INTO tab_driver_details (
    id_card,
    id_user,
    cel,
    license_cat,
    license_exp,
    address_driver,
    available,
    status_driver,
    user_create
) VALUES (...);  -- date_entry y created_at se asignan automáticamente
```

---

## 3. MEJORAS IMPLEMENTADAS

### Mejora 1: Normalización de Variables

**Antes**:
```sql
-- Variables sueltas sin patrón
v_email_clean       VARCHAR(320);
v_name_clean        VARCHAR(100);
```

**Después**:
```sql
-- Variables agrupadas con prefijo v_
v_email_clean       VARCHAR(320);
v_name_clean        VARCHAR(100);
v_cel_clean         VARCHAR(15);
v_license_clean     VARCHAR(2);
v_user_exists       BOOLEAN;
v_email_exists      BOOLEAN;
v_card_exists       BOOLEAN;
```

**Beneficio**: 
- ✅ Código más legible
- ✅ Patrón consistente

---

### Mejora 2: Bloques TRY-CATCH para INSERT

**Antes**:
```sql
INSERT INTO tab_users (...) VALUES (...);
-- Si falla, EXCEPTION genérica
```

**Después**:
```sql
BEGIN
    INSERT INTO tab_users (...) VALUES (...);
    RAISE NOTICE 'Usuario creado con ID: %', v_new_id;
    
EXCEPTION
    WHEN unique_violation THEN
        msg := 'Error de unicidad al insertar usuario: ' || SQLERRM;
        error_code := 'USER_INSERT_UNIQUE_VIOLATION';
        RETURN;
    WHEN foreign_key_violation THEN
        msg := 'Error de clave foránea al insertar usuario: ' || SQLERRM;
        error_code := 'USER_INSERT_FK_VIOLATION';
        RETURN;
    WHEN OTHERS THEN
        msg := 'Error inesperado al insertar usuario: ' || SQLERRM;
        error_code := 'USER_INSERT_ERROR';
        RETURN;
END;
```

**Beneficio**: 
- ✅ Mensajes de error específicos por tipo
- ✅ Código de error único por excepción
- ✅ Backend puede manejar errores fácilmente

---

### Mejora 3: Logging con RAISE NOTICE

**Agregado**:
```sql
-- Después de cada INSERT exitoso
RAISE NOTICE 'Usuario creado con ID: %', v_new_id;
RAISE NOTICE 'Rol Conductor asignado al usuario %', v_new_id;
RAISE NOTICE 'Detalles de conductor creados para cédula: %', wid_card;
```

**Beneficio**: 
- ✅ Trazabilidad en logs de PostgreSQL
- ✅ Debugging más fácil en desarrollo
- ℹ️ Solo visible con `client_min_messages = NOTICE`

---

### Mejora 4: Mensajes de Error Descriptivos

**Antes**:
```sql
RAISE EXCEPTION 'El email "%" no tiene un formato válido', v_email_clean
    USING HINT = 'INVALID_EMAIL_FORMAT';
```

**Después**:
```sql
msg := 'El email "' || v_email_clean || '" no tiene un formato válido';
error_code := 'EMAIL_INVALID_FORMAT';
RETURN;
```

**Beneficio**: 
- ✅ Mensaje legible en backend
- ✅ Código de error específico
- ✅ Sin interrumpir transacción

---

### Mejora 5: Uso de %TYPE para Type Safety

**Antes**:
```sql
p_email             VARCHAR(320),
p_password_hash     VARCHAR(60),
```

**Después**:
```sql
wuser_email         tab_users.email%TYPE,
wpassword_hash      tab_users.password_hash%TYPE,
```

**Beneficio**: 
- ✅ Si cambia el esquema, la función se adapta automáticamente
- ✅ Garantiza compatibilidad de tipos
- ✅ No hay riesgo de desincronización

---

## 4. CAMBIOS EN LA FIRMA DE LA FUNCIÓN

### Antes (v1.0)
```sql
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
    p_user_create       VARCHAR(100) DEFAULT 'system'  -- ❌ TIPO INCORRECTO
)
RETURNS driver_created_type  -- ❌ TIPO COMPLEJO
```

### Después (v2.0)
```sql
CREATE OR REPLACE FUNCTION fun_create_driver(
    wuser_email         tab_users.email%TYPE,
    wpassword_hash      tab_users.password_hash%TYPE,
    wfull_name          tab_users.full_name%TYPE,
    wid_card            tab_driver_details.id_card%TYPE,
    wcel                tab_driver_details.cel%TYPE,
    wlicense_cat        tab_driver_details.license_cat%TYPE,
    wlicense_exp        tab_driver_details.license_exp%TYPE,
    wavatar_url         tab_users.avatar_url%TYPE DEFAULT NULL,
    waddress_driver     tab_driver_details.address_driver%TYPE DEFAULT NULL,
    wuser_create        tab_users.user_create%TYPE,  -- ✅ TIPO CORRECTO (INTEGER)
    
    OUT success         BOOLEAN,
    OUT msg             VARCHAR,
    OUT error_code      VARCHAR,
    OUT id_user         INTEGER,
    OUT id_card         DECIMAL
)
```

### ⚠️ CAMBIO INCOMPATIBLE HACIA ATRÁS

**Implicaciones**:
- ❌ **Backend debe actualizarse**: Pasar `req.user.id_user` (INTEGER) en vez de 'system' (VARCHAR)
- ❌ **Llamadas antiguas fallarán**: Si se pasa VARCHAR se producirá error de tipo
- ✅ **Tipo de retorno diferente**: Ya no es `driver_created_type`, ahora es tabla con campos OUT
- ✅ **Migración necesaria**: Ver sección 6

---

## 5. ESTADÍSTICAS DE CÓDIGO

| Métrica | Antes | Después | Cambio |
|---------|-------|---------|--------|
| Líneas totales | 323 | 465 | +44% |
| Parámetros IN | 10 | 10 | = |
| Parámetros OUT | 0 (tipo personalizado) | 5 | +5 |
| Variables declaradas | 8 | 11 | +37% |
| Validaciones | 13 | 16 | +23% |
| Códigos de error | 13 (HINT) | 29 (error_code) | +123% |
| Bloques EXCEPTION | 0 | 3 (uno por INSERT) | +3 |
| Tipos personalizados | 1 (driver_created_type) | 0 | -100% |

---

## 6. IMPACTO EN BACKEND

### Cambios Necesarios en Servicios

**archivo**: `api/services/drivers.service.js`

**Antes**:
```javascript
async function createDriver(driverData) {
  const query = 'SELECT * FROM fun_create_driver($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)';
  const values = [
    driverData.email,
    driverData.password_hash,
    driverData.full_name,
    driverData.id_card,
    driverData.cel,
    driverData.license_cat,
    driverData.license_exp,
    driverData.avatar_url,
    driverData.address_driver,
    'system'  // ❌ VARCHAR
  ];
  
  try {
    const result = await pool.query(query, values);
    // result.rows[0] es de tipo driver_created_type
    return {
      success: true,
      data: result.rows[0]
    };
  } catch (error) {
    // Manejo de EXCEPTION
    return {
      success: false,
      error: error.message
    };
  }
}
```

**Después**:
```javascript
async function createDriver(driverData, userId) {
  const query = 'SELECT * FROM fun_create_driver($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)';
  const values = [
    driverData.email,
    driverData.password_hash,
    driverData.full_name,
    driverData.id_card,
    driverData.cel,
    driverData.license_cat,
    driverData.license_exp,
    driverData.avatar_url || null,
    driverData.address_driver || null,
    userId  // ✅ INTEGER (del JWT)
  ];
  
  const result = await pool.query(query, values);
  
  // La función SIEMPRE retorna (no lanza EXCEPTION)
  if (result.rows[0].success) {
    return {
      success: true,
      id_user: result.rows[0].id_user,
      id_card: result.rows[0].id_card,
      message: result.rows[0].msg
    };
  } else {
    return {
      success: false,
      error: result.rows[0].msg,
      error_code: result.rows[0].error_code
    };
  }
}
```

### Cambios Necesarios en Rutas

**archivo**: `api/routes/drivers.routes.js`

**Antes**:
```javascript
router.post('/create', async (req, res) => {
  try {
    const result = await createDriver(req.body);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

**Después**:
```javascript
router.post('/create', authMiddleware, async (req, res) => {
  const userId = req.user.id_user;  // ✅ INTEGER del JWT
  
  const result = await createDriver(req.body, userId);
  
  if (result.success) {
    res.status(201).json({
      success: true,
      id_user: result.id_user,
      id_card: result.id_card,
      message: result.message
    });
  } else {
    // Determinar código HTTP según error_code
    let statusCode = 400;
    if (result.error_code === 'EMAIL_DUPLICATE' || result.error_code === 'ID_CARD_DUPLICATE') {
      statusCode = 409; // Conflict
    } else if (result.error_code === 'USER_CREATE_NOT_FOUND') {
      statusCode = 403; // Forbidden
    }
    
    res.status(statusCode).json({
      success: false,
      error: result.error,
      error_code: result.error_code
    });
  }
});
```

### ⚠️ Verificar JWT Middleware

Asegurarse de que el middleware de autenticación extraiga `id_user` del token:

```javascript
// middleware/auth.js
function verifyToken(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token provided' });
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = {
      id_user: decoded.id_user,  // ✅ NECESARIO: ID como INTEGER
      email: decoded.email,
      // ... otros campos
    };
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
}
```

---

## 7. CÓDIGOS DE ERROR

### Todos los Códigos (29 en total)

| Código | Descripción | Cuándo se lanza |
|--------|-------------|-----------------|
| `USER_CREATE_NOT_FOUND` | Usuario creador no existe | wuser_create no existe o inactivo |
| `EMAIL_NULL_EMPTY` | Email nulo o vacío | wuser_email IS NULL o '' |
| `EMAIL_INVALID_FORMAT` | Formato de email inválido | No cumple regex RFC 5322 |
| `EMAIL_TOO_LONG` | Email muy largo | > 320 caracteres |
| `EMAIL_DUPLICATE` | Email ya registrado | Existe en tab_users |
| `PASSWORD_INVALID_LENGTH` | Hash de password incorrecto | LENGTH != 60 |
| `PASSWORD_INVALID_FORMAT` | Hash no es bcrypt | No cumple regex bcrypt |
| `NAME_NULL_EMPTY` | Nombre nulo o vacío | wfull_name IS NULL o '' |
| `NAME_TOO_SHORT` | Nombre muy corto | < 3 caracteres |
| `NAME_TOO_LONG` | Nombre muy largo | > 100 caracteres |
| `NAME_INVALID_CHARS` | Nombre con caracteres inválidos | Contiene números o símbolos |
| `AVATAR_INVALID_PROTOCOL` | Avatar sin http/https | No empieza con http:// |
| `AVATAR_TOO_LONG` | URL de avatar muy larga | > 500 caracteres |
| `ID_CARD_INVALID` | Cédula inválida | NULL o <= 0 |
| `ID_CARD_TOO_LARGE` | Cédula muy grande | > 999999999999 (12 dígitos) |
| `ID_CARD_DUPLICATE` | Cédula ya registrada | Existe en tab_driver_details |
| `PHONE_NULL_EMPTY` | Teléfono nulo o vacío | wcel IS NULL o '' |
| `PHONE_INVALID_FORMAT` | Teléfono con formato inválido | No cumple ^[0-9]{7,15}$ |
| `LICENSE_CAT_NULL` | Categoría de licencia nula | wlicense_cat IS NULL |
| `LICENSE_CAT_INVALID` | Categoría inválida | No es C1, C2 ni C3 |
| `LICENSE_EXP_NULL` | Fecha de expiración nula | wlicense_exp IS NULL |
| `LICENSE_EXPIRED` | Licencia vencida | wlicense_exp <= CURRENT_DATE |
| `ID_NOT_MONOTONIC` | Error en generación de ID | ID generado <= último ID |
| `USER_INSERT_UNIQUE_VIOLATION` | Violación de unicidad (usuario) | Email duplicado en INSERT |
| `USER_INSERT_FK_VIOLATION` | Error FK (usuario) | user_create no existe |
| `USER_INSERT_ERROR` | Error inesperado (usuario) | Otros errores en INSERT |
| `ROLE_ASSIGN_FK_VIOLATION` | Error FK (rol) | id_role o assigned_by inválido |
| `ROLE_ASSIGN_ERROR` | Error inesperado (rol) | Otros errores en asignación |
| `DRIVER_INSERT_UNIQUE_VIOLATION` | Violación de unicidad (conductor) | id_card o id_user duplicado |
| `DRIVER_INSERT_FK_VIOLATION` | Error FK (conductor) | id_user o user_create inválido |
| `DRIVER_INSERT_CHECK_VIOLATION` | Violación de CHECK (conductor) | license_cat, cel o fecha inválida |
| `DRIVER_INSERT_ERROR` | Error inesperado (conductor) | Otros errores en INSERT |

---

## 8. PRUEBAS RECOMENDADAS

### Caso 1: Creación Exitosa
```sql
SELECT * FROM fun_create_driver(
    'conductor1@test.com',                                      -- email
    '$2b$10$abcdefghijklmnopqrstuvwxyz123456789012345678901',  -- password hash
    'Juan Pérez Gómez',                                         -- nombre
    1234567890,                                                 -- cédula
    '3001234567',                                              -- teléfono
    'C2',                                                       -- licencia
    '2027-12-31',                                              -- expiración
    'https://example.com/avatar.jpg',                          -- avatar
    'Calle 123 #45-67',                                        -- dirección
    1                                                          -- usuario creador (admin)
);

-- Resultado esperado:
-- success: TRUE
-- msg: "Conductor creado exitosamente: Juan Pérez Gómez (conductor1@test.com)"
-- error_code: NULL
-- id_user: [nuevo ID generado]
-- id_card: 1234567890
```

### Caso 2: Error - Usuario Creador No Existe
```sql
SELECT * FROM fun_create_driver(
    'test@test.com',
    '$2b$10$abcdefghijklmnopqrstuvwxyz123456789012345678901',
    'Test Driver',
    9876543210,
    '3009876543',
    'C1',
    '2027-12-31',
    NULL,
    NULL,
    9999  -- ❌ Usuario que no existe
);

-- Resultado esperado:
-- success: FALSE
-- msg: "El usuario creador no existe o está inactivo (ID: 9999)"
-- error_code: "USER_CREATE_NOT_FOUND"
-- id_user: NULL
-- id_card: NULL
```

### Caso 3: Error - Email Duplicado
```sql
-- Primero crear un conductor
SELECT * FROM fun_create_driver(
    'duplicate@test.com', '...', 'Driver 1', 111, '3001111111', 'C1', '2027-12-31', NULL, NULL, 1
);

-- Intentar crear otro con mismo email
SELECT * FROM fun_create_driver(
    'duplicate@test.com',  -- ❌ Email duplicado
    '...',
    'Driver 2',
    222,
    '3002222222',
    'C2',
    '2027-12-31',
    NULL,
    NULL,
    1
);

-- Resultado esperado:
-- success: FALSE
-- msg: "El email \"duplicate@test.com\" ya está registrado en el sistema"
-- error_code: "EMAIL_DUPLICATE"
-- id_user: NULL
-- id_card: NULL
```

### Caso 4: Error - Cédula Duplicada
```sql
-- Primero crear un conductor
SELECT * FROM fun_create_driver(
    'driver1@test.com', '...', 'Driver 1', 12345, '3001111111', 'C1', '2027-12-31', NULL, NULL, 1
);

-- Intentar crear otro con misma cédula
SELECT * FROM fun_create_driver(
    'driver2@test.com',
    '...',
    'Driver 2',
    12345,  -- ❌ Cédula duplicada
    '3002222222',
    'C2',
    '2027-12-31',
    NULL,
    NULL,
    1
);

-- Resultado esperado:
-- success: FALSE
-- msg: "La cédula 12345 ya está registrada como conductor"
-- error_code: "ID_CARD_DUPLICATE"
-- id_user: NULL
-- id_card: NULL
```

### Caso 5: Error - Licencia Vencida
```sql
SELECT * FROM fun_create_driver(
    'expired@test.com',
    '$2b$10$abcdefghijklmnopqrstuvwxyz123456789012345678901',
    'Expired License',
    55555,
    '3005555555',
    'C3',
    '2024-01-01',  -- ❌ Fecha pasada
    NULL,
    NULL,
    1
);

-- Resultado esperado:
-- success: FALSE
-- msg: "La licencia está vencida o expira hoy. Debe ser una fecha futura (después de [CURRENT_DATE])"
-- error_code: "LICENSE_EXPIRED"
-- id_user: NULL
-- id_card: NULL
```

### Caso 6: Error - Formato de Email Inválido
```sql
SELECT * FROM fun_create_driver(
    'not-an-email',  -- ❌ Sin @
    '$2b$10$abcdefghijklmnopqrstuvwxyz123456789012345678901',
    'Invalid Email',
    66666,
    '3006666666',
    'C1',
    '2027-12-31',
    NULL,
    NULL,
    1
);

-- Resultado esperado:
-- success: FALSE
-- msg: "El email \"not-an-email\" no tiene un formato válido"
-- error_code: "EMAIL_INVALID_FORMAT"
-- id_user: NULL
-- id_card: NULL
```

---

## 9. RECOMENDACIONES

### Inmediatas (Antes de Deploy)
1. ✅ **Actualizar backend**: Cambiar llamadas para pasar INTEGER en user_create
2. ✅ **Verificar JWT**: Asegurar que incluye id_user como INTEGER
3. ✅ **Ejecutar DROP**: `DROP TYPE driver_created_type CASCADE;`
4. ✅ **Ejecutar SQL**: Aplicar la función v2.0
5. ✅ **Probar casos**: Ejecutar los 6 casos de prueba

### Corto Plazo
6. ✅ **Actualizar documentación API**: Nueva firma y códigos de error
7. ✅ **Actualizar Postman/Insomnia**: Cambiar collections
8. ✅ **Notificar frontend**: Cambio en respuesta (ya no es driver_created_type)

### Mediano Plazo
9. ⚠️ **Monitorear logs**: Revisar NOTICE messages en desarrollo
10. ⚠️ **Performance**: Evaluar tiempo de generación de ID

---

## 10. COMPARACIÓN CON OTRAS FUNCIONES

| Característica | fun_create_driver v2.0 | fun_create_bus v2.0 | fun_assign_driver v2.0 |
|----------------|------------------------|---------------------|------------------------|
| Patrón OUT parameters | ✅ success/msg/error_code | ✅ success/msg/error_code | ✅ success/msg/error_code |
| Validación user_create | ✅ Verifica existencia | ✅ Verifica existencia | ✅ Verifica existencia (wuser_assign) |
| Tipo user_create | ✅ INTEGER | ✅ INTEGER | ✅ INTEGER |
| Uso de %TYPE | ✅ Todos los parámetros | ✅ Todos los parámetros | ✅ Todos los parámetros |
| Bloques TRY-CATCH | ✅ 3 bloques | ✅ 1 bloque | ✅ 4 bloques |
| RAISE NOTICE | ✅ Logging | ✅ Logging | ✅ Logging |
| Normalización | ✅ v_*_clean | ✅ v_normalized_* | ✅ v_normalized_plate |
| Códigos de error | 29 códigos | 16 códigos | 11 códigos |

**Conclusión**: Las 3 funciones ahora siguen el mismo patrón v2.0, garantizando consistencia en toda la API.

---

## 11. CONCLUSIÓN

### Errores Críticos Resueltos
- ✅ **Incompatibilidad de tipos**: VARCHAR(100) → INTEGER
- ✅ **Sin validación**: Validación del usuario creador agregada
- ✅ **assigned_by NULL**: Ahora usa wuser_create
- ✅ **Tipo de retorno complejo**: Ahora usa OUT parameters estándar
- ✅ **RAISE EXCEPTION**: Ahora retorna con success/msg/error_code

### Mejoras de Calidad
- ✅ 29 códigos de error específicos
- ✅ Bloques TRY-CATCH para cada INSERT
- ✅ Logging con RAISE NOTICE
- ✅ Normalización de variables
- ✅ Uso de %TYPE para type safety

### Estado de Deployment
- ⚠️ **No compatible hacia atrás**: Backend debe actualizarse
- ⚠️ **Tipo de retorno diferente**: Ya no es driver_created_type
- ✅ **Lista para producción**: Después de actualizar backend
- ✅ **Documentada**: Este reporte + comentarios en código

### Próximos Pasos
1. Actualizar backend según sección 6
2. Ejecutar pruebas según sección 8
3. Deploy a staging
4. Validar integración end-to-end
5. Deploy a producción

---

**Versión del Reporte**: 1.0  
**Autor**: GitHub Copilot  
**Fecha de Revisión**: 2025-01-01  
**Archivo Revisado**: fun_create_driver.sql v2.0 (465 líneas)  
**Estado**: ✅ Revisión completa - Backend pendiente de actualización

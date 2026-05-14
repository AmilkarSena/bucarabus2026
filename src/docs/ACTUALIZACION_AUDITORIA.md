# ACTUALIZACIÓN DE CAMPOS DE AUDITORÍA (user_create, user_update)

**Fecha:** Enero 2025  
**Estado:** Completado ✅  
**Alcance:** Sistema completo de auditoría para rastrear qué usuario del panel de administración crea o modifica registros

---

## 📋 RESUMEN

Se agregaron campos de auditoría `user_create` y `user_update` a `tab_users` y `tab_driver_details` para rastrear qué administrador realiza operaciones CRUD desde el panel de administración.

**Patrón implementado:**
```
Request (frontend) → Route extrae 'user' → Service lo pasa con default → 
Database function lo almacena en user_create/user_update
```

---

## 🗄️ CAMBIOS EN BASE DE DATOS

### Tablas Actualizadas

**tab_users:**
```sql
user_create VARCHAR(100) NOT NULL    -- Quién creó el usuario
user_update VARCHAR(100)              -- Quién actualizó por última vez
```

**tab_driver_details:**
```sql
user_create VARCHAR(100) NOT NULL    -- Quién creó el conductor
user_update VARCHAR(100)              -- Quién actualizó por última vez
```

### Funciones Actualizadas

#### 1. fun_create_user.sql

**Firma anterior:**
```sql
CREATE OR REPLACE FUNCTION fun_create_user(
    p_email VARCHAR(320),
    p_password_hash VARCHAR(60),
    p_full_name VARCHAR(100),
    p_avatar_url VARCHAR(500) DEFAULT NULL
)
```

**Firma actualizada:**
```sql
CREATE OR REPLACE FUNCTION fun_create_user(
    p_email VARCHAR(320),
    p_password_hash VARCHAR(60),
    p_full_name VARCHAR(100),
    p_avatar_url VARCHAR(500) DEFAULT NULL,
    p_user_create VARCHAR(100) DEFAULT 'system'  -- ✅ NUEVO
)
```

**Cambio en INSERT:**
```sql
INSERT INTO tab_users (
    id_user, email, password_hash, full_name,
    avatar_url, created_at, user_create, is_active  -- ✅ user_create agregado
) VALUES (
    v_id, v_email_clean, p_password_hash, v_name_clean,
    p_avatar_url, NOW(), p_user_create, true  -- ✅ p_user_create agregado
);
```

---

#### 2. fun_update_user.sql

**Firma anterior:**
```sql
CREATE OR REPLACE FUNCTION fun_update_user(
    p_id_user INTEGER,
    p_full_name VARCHAR(100) DEFAULT NULL,
    p_avatar_url VARCHAR(500) DEFAULT NULL
)
```

**Firma actualizada:**
```sql
CREATE OR REPLACE FUNCTION fun_update_user(
    p_id_user INTEGER,
    p_full_name VARCHAR(100) DEFAULT NULL,
    p_avatar_url VARCHAR(500) DEFAULT NULL,
    p_user_update VARCHAR(100) DEFAULT 'system'  -- ✅ NUEVO
)
```

**Cambio en UPDATE:**
```sql
UPDATE tab_users
SET 
    full_name = COALESCE(v_name_clean, tab_users.full_name),
    avatar_url = COALESCE(p_avatar_url, tab_users.avatar_url),
    updated_at = NOW(),
    user_update = p_user_update  -- ✅ NUEVO
WHERE tab_users.id_user = p_id_user;
```

---

#### 3. fun_create_driver.sql

**Firma anterior:**
```sql
CREATE OR REPLACE FUNCTION fun_create_driver(
    p_email VARCHAR(320),
    p_password_hash VARCHAR(60),
    p_full_name VARCHAR(100),
    p_id_card DECIMAL(12,0),
    p_cel VARCHAR(15),
    p_license_cat VARCHAR(2),
    p_license_exp DATE,
    p_avatar_url VARCHAR(500) DEFAULT NULL,
    p_address_driver TEXT DEFAULT NULL
)
```

**Firma actualizada:**
```sql
CREATE OR REPLACE FUNCTION fun_create_driver(
    p_email VARCHAR(320),
    p_password_hash VARCHAR(60),
    p_full_name VARCHAR(100),
    p_id_card DECIMAL(12,0),
    p_cel VARCHAR(15),
    p_license_cat VARCHAR(2),
    p_license_exp DATE,
    p_avatar_url VARCHAR(500) DEFAULT NULL,
    p_address_driver TEXT DEFAULT NULL,
    p_user_create VARCHAR(100) DEFAULT 'system'  -- ✅ NUEVO
)
```

**Cambio en INSERT tab_users:**
```sql
INSERT INTO tab_users (
    id_user, email, password_hash, full_name,
    avatar_url, created_at, user_create, is_active  -- ✅ user_create agregado
) VALUES (
    v_id, v_email_clean, p_password_hash, v_name_clean,
    NULLIF(TRIM(p_avatar_url), ''), NOW(), p_user_create, TRUE  -- ✅ p_user_create
);
```

**Cambio en INSERT tab_driver_details:**
```sql
INSERT INTO tab_driver_details (
    id_card, id_user, cel, license_cat, license_exp,
    address_driver, date_entry, available, status_driver,
    created_at, user_create  -- ✅ user_create
) VALUES (
    p_id_card, v_id, TRIM(p_cel), UPPER(p_license_cat), p_license_exp,
    NULLIF(TRIM(p_address_driver), ''), CURRENT_DATE, TRUE, TRUE,
    NOW(), p_user_create  -- ✅ Antes era 'system' hardcoded
);
```

---

#### 4. fun_update_driver.sql

**Firma anterior:**
```sql
CREATE OR REPLACE FUNCTION fun_update_driver(
    p_id_user INTEGER,
    p_full_name VARCHAR(100),
    p_cel VARCHAR(15),
    p_license_cat VARCHAR(2),
    p_license_exp DATE,
    p_address_driver TEXT DEFAULT NULL,
    p_avatar_url VARCHAR(500) DEFAULT NULL,
    p_available BOOLEAN DEFAULT TRUE
)
```

**Firma actualizada:**
```sql
CREATE OR REPLACE FUNCTION fun_update_driver(
    p_id_user INTEGER,
    p_full_name VARCHAR(100),
    p_cel VARCHAR(15),
    p_license_cat VARCHAR(2),
    p_license_exp DATE,
    p_address_driver TEXT DEFAULT NULL,
    p_avatar_url VARCHAR(500) DEFAULT NULL,
    p_available BOOLEAN DEFAULT TRUE,
    p_user_update VARCHAR(100) DEFAULT 'system'  -- ✅ NUEVO
)
```

**Cambio en UPDATE tab_users:**
```sql
UPDATE tab_users 
SET full_name = v_name_clean,
    avatar_url = NULLIF(TRIM(p_avatar_url), ''),
    updated_at = NOW(),
    user_update = p_user_update  -- ✅ NUEVO
WHERE id_user = p_id_user;
```

**Cambio en UPDATE tab_driver_details:**
```sql
UPDATE tab_driver_details 
SET cel = TRIM(p_cel),
    license_cat = UPPER(p_license_cat),
    license_exp = p_license_exp,
    address_driver = NULLIF(TRIM(p_address_driver), ''),
    available = COALESCE(p_available, TRUE),
    updated_at = NOW(),
    user_update = p_user_update  -- ✅ Antes era 'system' hardcoded
WHERE id_user = p_id_user;
```

---

## 💻 CAMBIOS EN BACKEND (Node.js/Express)

### Services

#### users.service.js

**createUser:**
```javascript
// Extrae user_create con default 'system'
const { email, password, full_name, avatar_url, initial_role = 1, user_create = 'system' } = userData

// Pasa 5 parámetros (antes eran 4)
const result = await client.query(query, [
  email,
  password_hash,
  full_name,
  avatar_url || null,
  user_create  // ✅ NUEVO - 5to parámetro
])
```

**updateUser:**
```javascript
// Extrae user_update con default 'system'
const { full_name, avatar_url, user_update = 'system' } = updates

// Pasa 4 parámetros (antes eran 3)
const result = await pool.query(query, [
  userId,
  full_name || null,
  avatar_url !== undefined ? avatar_url : null,
  user_update  // ✅ NUEVO - 4to parámetro
])
```

---

#### drivers.service.js

**createDriver:**
```javascript
// Extrae user_create con default 'system'
const {
  email, password, full_name, id_card, cel,
  license_cat, license_exp, avatar_url = null,
  address_driver = null,
  user_create = 'system'  // ✅ NUEVO
} = driverData;

// Pasa 10 parámetros (antes eran 9)
const result = await pool.query(
  `SELECT * FROM fun_create_driver($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
  [
    email, passwordHash, full_name, id_card, cel,
    license_cat, license_exp, avatar_url, address_driver,
    user_create  // ✅ NUEVO - 10mo parámetro
  ]
);
```

**updateDriver:**
```javascript
// Extrae user_update con default 'system'
const {
  name_driver, cel, license_cat, license_exp,
  address_driver = null, photo_driver = null,
  available = true,
  user_update = 'system'  // ✅ NUEVO
} = driverData;

// Pasa 9 parámetros (antes eran 8)
const result = await pool.query(
  `SELECT * FROM fun_update_driver($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
  [
    idUser, name_driver, cel, license_cat, license_exp,
    address_driver, photo_driver, available,
    user_update  // ✅ NUEVO - 9no parámetro
  ]
);
```

---

### Routes

#### users.routes.js

**POST /api/users:**
```javascript
// Extrae 'user' del body
const { email, password, full_name, avatar_url, initial_role, user } = req.body

// Pasa como user_create con default 'admin'
const result = await usersService.createUser({
  email, password, full_name, avatar_url, initial_role,
  user_create: user || 'admin'  // ✅ NUEVO - default 'admin' para panel
})
```

**PUT /api/users/:id:**
```javascript
// Extrae 'user' del body
const { full_name, avatar_url, user } = req.body

// Pasa como user_update con default 'admin'
const result = await usersService.updateUser(userId, {
  full_name, avatar_url,
  user_update: user || 'admin'  // ✅ NUEVO - default 'admin' para panel
})
```

---

#### drivers.routes.js

**POST /api/drivers:**
```javascript
// Extrae 'user' del body
const {
  email, password, name_driver, id_card, cel,
  license_cat, license_exp, address_driver, photo_driver,
  user  // ✅ NUEVO
} = req.body;

// Pasa como user_create con default 'admin'
const result = await driversService.createDriver({
  email, password,
  full_name: name_driver,
  id_card, cel, license_cat, license_exp,
  avatar_url: photo_driver || null,
  address_driver: address_driver || null,
  user_create: user || 'admin'  // ✅ NUEVO
});
```

**PUT /api/drivers/:id:**
```javascript
// Extrae 'user' del body
const { user } = req.body;

// Spread req.body y agrega user_update con default 'admin'
const result = await driversService.updateDriver(id, {
  ...req.body,
  user_update: user || 'admin'  // ✅ NUEVO
});
```

---

## 📁 ARCHIVOS MODIFICADOS

### Base de Datos (4 archivos)
- ✅ `api/database/fun_create_user.sql`
- ✅ `api/database/fun_update_user.sql`
- ✅ `api/database/fun_create_driver.sql`
- ✅ `api/database/fun_update_driver.sql`

### Backend - Services (2 archivos)
- ✅ `api/services/users.service.js`
- ✅ `api/services/drivers.service.js`

### Backend - Routes (2 archivos)
- ✅ `api/routes/users.routes.js`
- ✅ `api/routes/drivers.routes.js`

**TOTAL: 8 archivos actualizados**

---

## 🚀 CÓMO APLICAR LOS CAMBIOS

### Opción 1: Archivo SQL Consolidado (RECOMENDADO)

Ejecuta el archivo consolidado que contiene todas las funciones:

```bash
psql -h 10.5.213.111 -U dlastre -d db_bucarabus -f api/database/UPDATE_AUDIT_FUNCTIONS.sql
```

O desde pgAdmin:
1. Abre pgAdmin
2. Conecta a la base de datos `db_bucarabus`
3. Abre Query Tool
4. Carga y ejecuta `api/database/UPDATE_AUDIT_FUNCTIONS.sql`

### Opción 2: Ejecutar Funciones Individualmente

```bash
# En orden:
psql -h 10.5.213.111 -U dlastre -d db_bucarabus -f api/database/fun_create_user.sql
psql -h 10.5.213.111 -U dlastre -d db_bucarabus -f api/database/fun_update_user.sql
psql -h 10.5.213.111 -U dlastre -d db_bucarabus -f api/database/fun_create_driver.sql
psql -h 10.5.213.111 -U dlastre -d db_bucarabus -f api/database/fun_update_driver.sql
```

---

## 🧪 PRUEBAS

### Test 1: Crear Usuario
```javascript
// Frontend debe enviar:
{
  email: "test@example.com",
  password: "securepass123",
  full_name: "Usuario Prueba",
  user: "admin_username"  // ✅ Campo de auditoría
}

// Resultado en BD:
// tab_users.user_create = "admin_username"
// tab_users.created_at = NOW()
```

### Test 2: Actualizar Usuario
```javascript
// Frontend debe enviar:
{
  full_name: "Nombre Actualizado",
  user: "admin_username"  // ✅ Campo de auditoría
}

// Resultado en BD:
// tab_users.user_update = "admin_username"
// tab_users.updated_at = NOW()
```

### Test 3: Crear Conductor
```javascript
// Frontend debe enviar:
{
  email: "driver@example.com",
  password: "driverpass123",
  name_driver: "Conductor Prueba",
  id_card: 1234567890,
  cel: "3001234567",
  license_cat: "C2",
  license_exp: "2025-12-31",
  user: "admin_username"  // ✅ Campo de auditoría
}

// Resultado en BD:
// tab_users.user_create = "admin_username"
// tab_driver_details.user_create = "admin_username"
```

### Test 4: Actualizar Conductor
```javascript
// Frontend debe enviar:
{
  name_driver: "Conductor Actualizado",
  cel: "3009876543",
  license_cat: "C3",
  license_exp: "2026-06-30",
  user: "admin_username"  // ✅ Campo de auditoría
}

// Resultado en BD:
// tab_users.user_update = "admin_username"
// tab_driver_details.user_update = "admin_username"
```

---

## 📊 VALORES POR DEFECTO

| Contexto | Campo | Valor Default | Cuándo se usa |
|----------|-------|---------------|---------------|
| Creación manual (panel) | `user_create` | `'admin'` | Usuario crea desde panel de admin |
| Actualización manual (panel) | `user_update` | `'admin'` | Usuario actualiza desde panel de admin |
| Creación automática (sistema) | `user_create` | `'system'` | Proceso automatizado o sin usuario |
| Actualización automática (sistema) | `user_update` | `'system'` | Trigger o proceso automático |

---

## 🔄 COMPATIBILIDAD RETROACTIVA

✅ **Las funciones son retrocompatibles:**
- Parámetros `user_create` y `user_update` tienen valores DEFAULT
- Llamadas sin estos parámetros usan 'system' automáticamente
- No rompe código existente que llame a las funciones

```sql
-- ✅ Llamada antigua (sigue funcionando):
SELECT * FROM fun_create_user('email@test.com', 'hash', 'Name', NULL);
-- user_create se establece automáticamente a 'system'

-- ✅ Llamada nueva (con auditoría):
SELECT * FROM fun_create_user('email@test.com', 'hash', 'Name', NULL, 'admin123');
-- user_create se establece a 'admin123'
```

---

## 📝 NOTAS ADICIONALES

### Consideraciones para Frontend

El frontend debe incluir el campo `user` en las peticiones API. Ejemplo para Vue/Pinia store:

```javascript
// stores/auth.js o similar
import { defineStore } from 'pinia'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    currentUser: null
  }),
  
  getters: {
    username: (state) => state.currentUser?.email || 'admin'
  }
})

// Luego en las peticiones API:
import { useAuthStore } from '@/stores/auth'

async function createUser(userData) {
  const authStore = useAuthStore()
  
  const response = await fetch('/api/users', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      ...userData,
      user: authStore.username  // ✅ Campo de auditoría
    })
  })
  
  return response.json()
}
```

### Consultas de Auditoría

Puedes consultar quién creó o modificó registros:

```sql
-- Ver quién creó cada usuario
SELECT id_user, email, full_name, user_create, created_at
FROM tab_users
ORDER BY created_at DESC;

-- Ver últimas actualizaciones de conductores
SELECT 
  u.id_user,
  u.full_name,
  u.user_update,
  u.updated_at,
  dd.user_update AS driver_details_updated_by
FROM tab_users u
INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
WHERE u.user_update IS NOT NULL
ORDER BY u.updated_at DESC;

-- Auditoría por administrador específico
SELECT 
  'usuario' AS tipo,
  id_user,
  email AS identificador,
  user_create AS admin,
  created_at AS fecha
FROM tab_users
WHERE user_create = 'admin_username'

UNION ALL

SELECT 
  'conductor' AS tipo,
  id_user,
  id_card::TEXT AS identificador,
  user_create AS admin,
  created_at AS fecha
FROM tab_driver_details
WHERE user_create = 'admin_username'

ORDER BY fecha DESC;
```

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN

- [x] Actualizar fun_create_user.sql con parámetro user_create
- [x] Actualizar fun_update_user.sql con parámetro user_update
- [x] Actualizar fun_create_driver.sql con parámetro user_create
- [x] Actualizar fun_update_driver.sql con parámetro user_update
- [x] Modificar users.service.js (createUser, updateUser)
- [x] Modificar drivers.service.js (createDriver, updateDriver)
- [x] Modificar users.routes.js (POST, PUT)
- [x] Modificar drivers.routes.js (POST, PUT)
- [x] Crear archivo consolidado UPDATE_AUDIT_FUNCTIONS.sql
- [ ] **PENDIENTE:** Ejecutar UPDATE_AUDIT_FUNCTIONS.sql en base de datos
- [ ] **PENDIENTE:** Modificar frontend para enviar campo 'user'
- [ ] **PENDIENTE:** Probar creación de usuario desde panel
- [ ] **PENDIENTE:** Probar actualización de usuario desde panel
- [ ] **PENDIENTE:** Probar creación de conductor desde panel
- [ ] **PENDIENTE:** Probar actualización de conductor desde panel

---

## 🎯 PRÓXIMOS PASOS

1. **Ejecutar** el archivo `UPDATE_AUDIT_FUNCTIONS.sql` en la base de datos
2. **Actualizar frontend** para incluir campo `user` en peticiones API
3. **Probar** todas las operaciones CRUD con auditoría
4. **Verificar** que los campos `user_create` y `user_update` se guardan correctamente
5. **Implementar** consultas de auditoría en el panel de administración (opcional)

---

**Documentación creada:** Enero 2025  
**Autor:** GitHub Copilot  
**Estado:** Lista para implementación ✅

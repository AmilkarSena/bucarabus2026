# GUÍA DE MIGRACIÓN BACKEND: VARCHAR → INTEGER (FK) para Auditoría

## 📋 RESUMEN DEL CAMBIO

**Antes:**
- `user_create` y `user_update` eran VARCHAR(100)
- Se pasaban nombres de usuario o emails como strings
- Routes: `user: 'admin'` → Service: `user_create = 'system'` → DB: VARCHAR

**Después:**
- `user_create` y `user_update` son INTEGER con FK a `tab_users(id_user)`
- Se pasan IDs de usuarios como números
- Routes: `userId: 1735689605` → Service: `user_create = 1735689605` → DB: INTEGER

---

## 🔧 CAMBIOS NECESARIOS EN BACKEND

### 1. Services (api/services/*.service.js)

#### users.service.js

**createUser - ANTES:**
```javascript
const { email, password, full_name, avatar_url, initial_role = 1, user_create = 'system' } = userData

const result = await client.query(query, [
  email,
  password_hash,
  full_name,
  avatar_url || null,
  user_create  // VARCHAR
])
```

**createUser - DESPUÉS:**
```javascript
// Constante para ID del sistema
const SYSTEM_USER_ID = 1735689600;

const { email, password, full_name, avatar_url, initial_role = 1, user_create_id = null } = userData

const result = await client.query(query, [
  email,
  password_hash,
  full_name,
  avatar_url || null,
  user_create_id || SYSTEM_USER_ID  // INTEGER (NULL se convierte en sistema)
])
```

**updateUser - ANTES:**
```javascript
const { full_name, avatar_url, user_update = 'system' } = updates

const result = await pool.query(query, [
  userId,
  full_name || null,
  avatar_url !== undefined ? avatar_url : null,
  user_update  // VARCHAR
])
```

**updateUser - DESPUÉS:**
```javascript
const { full_name, avatar_url, user_update_id = null } = updates

const result = await pool.query(query, [
  userId,
  full_name || null,
  avatar_url !== undefined ? avatar_url : null,
  user_update_id  // INTEGER (NULL es válido aquí)
])
```

---

#### drivers.service.js

**createDriver - ANTES:**
```javascript
const {
  email, password, full_name, id_card, cel,
  license_cat, license_exp, avatar_url = null,
  address_driver = null,
  user_create = 'system'  // VARCHAR
} = driverData;

const result = await pool.query(
  `SELECT * FROM fun_create_driver($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
  [
    email, passwordHash, full_name, id_card, cel,
    license_cat, license_exp, avatar_url, address_driver,
    user_create  // VARCHAR
  ]
);
```

**createDriver - DESPUÉS:**
```javascript
const SYSTEM_USER_ID = 1735689600;

const {
  email, password, full_name, id_card, cel,
  license_cat, license_exp, avatar_url = null,
  address_driver = null,
  user_create_id = null  // ✅ INTEGER
} = driverData;

const result = await pool.query(
  `SELECT * FROM fun_create_driver($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
  [
    email, passwordHash, full_name, id_card, cel,
    license_cat, license_exp, avatar_url, address_driver,
    user_create_id || SYSTEM_USER_ID  // ✅ INTEGER
  ]
);
```

**updateDriver - ANTES:**
```javascript
const {
  name_driver, cel, license_cat, license_exp,
  address_driver = null, photo_driver = null,
  available = true,
  user_update = 'system'  // VARCHAR
} = driverData;

const result = await pool.query(
  `SELECT * FROM fun_update_driver($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
  [
    idUser, name_driver, cel, license_cat, license_exp,
    address_driver, photo_driver, available,
    user_update  // VARCHAR
  ]
);
```

**updateDriver - DESPUÉS:**
```javascript
const {
  name_driver, cel, license_cat, license_exp,
  address_driver = null, photo_driver = null,
  available = true,
  user_update_id = null  // ✅ INTEGER
} = driverData;

const result = await pool.query(
  `SELECT * FROM fun_update_driver($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
  [
    idUser, name_driver, cel, license_cat, license_exp,
    address_driver, photo_driver, available,
    user_update_id  // ✅ INTEGER
  ]
);
```

---

### 2. Routes (api/routes/*.routes.js)

#### users.routes.js

**POST /api/users - ANTES:**
```javascript
const { email, password, full_name, avatar_url, initial_role, user } = req.body

const result = await usersService.createUser({
  email, password, full_name, avatar_url, initial_role,
  user_create: user || 'admin'  // STRING
})
```

**POST /api/users - DESPUÉS:**
```javascript
// Obtener ID del usuario autenticado desde middleware de autenticación
const authenticatedUserId = req.user?.id_user;  // Desde JWT o sesión

const { email, password, full_name, avatar_url, initial_role } = req.body

const result = await usersService.createUser({
  email, password, full_name, avatar_url, initial_role,
  user_create_id: authenticatedUserId  // ✅ INTEGER (puede ser null)
})
```

**PUT /api/users/:id - ANTES:**
```javascript
const { full_name, avatar_url, user } = req.body

const result = await usersService.updateUser(userId, {
  full_name, avatar_url,
  user_update: user || 'admin'  // STRING
})
```

**PUT /api/users/:id - DESPUÉS:**
```javascript
const authenticatedUserId = req.user?.id_user;

const { full_name, avatar_url } = req.body

const result = await usersService.updateUser(userId, {
  full_name, avatar_url,
  user_update_id: authenticatedUserId  // ✅ INTEGER
})
```

---

#### drivers.routes.js

**POST /api/drivers - ANTES:**
```javascript
const {
  email, password, name_driver, id_card, cel,
  license_cat, license_exp, address_driver, photo_driver,
  user  // STRING
} = req.body;

const result = await driversService.createDriver({
  email, password,
  full_name: name_driver,
  id_card, cel, license_cat, license_exp,
  avatar_url: photo_driver || null,
  address_driver: address_driver || null,
  user_create: user || 'admin'  // STRING
});
```

**POST /api/drivers - DESPUÉS:**
```javascript
const authenticatedUserId = req.user?.id_user;

const {
  email, password, name_driver, id_card, cel,
  license_cat, license_exp, address_driver, photo_driver
} = req.body;

const result = await driversService.createDriver({
  email, password,
  full_name: name_driver,
  id_card, cel, license_cat, license_exp,
  avatar_url: photo_driver || null,
  address_driver: address_driver || null,
  user_create_id: authenticatedUserId  // ✅ INTEGER
});
```

**PUT /api/drivers/:id - ANTES:**
```javascript
const { user } = req.body;

const result = await driversService.updateDriver(id, {
  ...req.body,
  user_update: user || 'admin'  // STRING
});
```

**PUT /api/drivers/:id - DESPUÉS:**
```javascript
const authenticatedUserId = req.user?.id_user;

const result = await driversService.updateDriver(id, {
  ...req.body,
  user_update_id: authenticatedUserId  // ✅ INTEGER
});
```

---

## 🔐 MIDDLEWARE DE AUTENTICACIÓN

Para obtener el `id_user` del usuario autenticado, necesitas un middleware que decodifique el JWT o valide la sesión:

**api/middleware/auth.js - EJEMPLO:**
```javascript
import jwt from 'jsonwebtoken';

export const authMiddleware = (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (!token) {
      return res.status(401).json({ 
        success: false, 
        message: 'Token no proporcionado' 
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Adjuntar información del usuario al request
    req.user = {
      id_user: decoded.id_user,
      email: decoded.email,
      full_name: decoded.full_name
    };
    
    next();
  } catch (error) {
    return res.status(401).json({ 
      success: false, 
      message: 'Token inválido' 
    });
  }
};

// Middleware opcional - permite continuar sin autenticación
export const optionalAuth = (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');
    
    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = {
        id_user: decoded.id_user,
        email: decoded.email,
        full_name: decoded.full_name
      };
    }
    
    next();
  } catch (error) {
    // Si falla, continuar sin usuario (usará sistema)
    next();
  }
};
```

**Uso en routes:**
```javascript
import { authMiddleware, optionalAuth } from '../middleware/auth.js';

// Requiere autenticación
router.post('/', authMiddleware, async (req, res) => {
  // req.user.id_user estará disponible
});

// Autenticación opcional
router.get('/public', optionalAuth, async (req, res) => {
  // req.user?.id_user puede ser undefined
});
```

---

## 📦 CONSTANTES COMPARTIDAS

Crea un archivo de constantes para el ID del sistema:

**api/config/constants.js:**
```javascript
// ID fijo del usuario del sistema (debe coincidir con user_roles.sql)
export const SYSTEM_USER_ID = 1735689600;  // Epoch 2025-01-01 00:00:00 UTC

// Otros IDs de usuarios especiales si los hay
export const ADMIN_DEFAULT_ID = null;  // Para permitir que se use el ID real del admin
```

**Uso en services:**
```javascript
import { SYSTEM_USER_ID } from '../config/constants.js';

// En createUser, createDriver, etc.
user_create_id: userData.user_create_id || SYSTEM_USER_ID
```

---

## 🧪 EJEMPLOS DE PETICIONES

### Desde Frontend (con autenticación)

**Crear usuario:**
```javascript
// El frontend ya NO envía campo 'user'
// El backend lo obtiene del token JWT automáticamente

const response = await fetch('/api/users', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`  // ✅ JWT con id_user
  },
  body: JSON.stringify({
    email: 'nuevo@example.com',
    password: 'securepass',
    full_name: 'Usuario Nuevo',
    // NO se envía 'user' - el backend lo extrae del token
  })
});
```

**Actualizar usuario:**
```javascript
const response = await fetch(`/api/users/${userId}`, {
  method: 'PUT',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`
  },
  body: JSON.stringify({
    full_name: 'Nombre Actualizado',
    // NO se envía 'user'
  })
});
```

---

## 📊 TABLA DE MIGRACIÓN

| Campo Antiguo | Tipo Antiguo | Campo Nuevo | Tipo Nuevo | FK |
|---------------|--------------|-------------|------------|-----|
| `user_create` | VARCHAR(100) | `user_create` | INTEGER | ✅ tab_users(id_user) |
| `user_update` | VARCHAR(100) | `user_update` | INTEGER | ✅ tab_users(id_user) |

**Archivo** | **Cambios necesarios**
--|--
`users.service.js` | Cambiar `user_create`/`user_update` a `user_create_id`/`user_update_id` (INTEGER)
`drivers.service.js` | Cambiar `user_create`/`user_update` a `user_create_id`/`user_update_id` (INTEGER)
`users.routes.js` | Usar `req.user.id_user` en lugar de extraer del body
`drivers.routes.js` | Usar `req.user.id_user` en lugar de extraer del body
`auth.js` (middleware) | Crear middleware para extraer `id_user` del JWT
`constants.js` | Crear con `SYSTEM_USER_ID = 1735689600`

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN

### Base de Datos
- [ ] Ejecutar `user_roles.sql` (con FKs actualizados)
- [ ] Ejecutar `MIGRATION_AUDIT_TO_FK.sql` (migrar datos existentes)
- [ ] Ejecutar `FUNCTIONS_AUDIT_FK.sql` (funciones con INTEGER)
- [ ] Verificar FKs creados: `SELECT * FROM information_schema.table_constraints WHERE constraint_type = 'FOREIGN KEY';`

### Backend
- [ ] Crear `api/config/constants.js` con `SYSTEM_USER_ID`
- [ ] Crear o actualizar `api/middleware/auth.js` con autenticación JWT
- [ ] Actualizar `api/services/users.service.js`
- [ ] Actualizar `api/services/drivers.service.js`
- [ ] Actualizar `api/routes/users.routes.js`
- [ ] Actualizar `api/routes/drivers.routes.js`
- [ ] Aplicar middleware `authMiddleware` a rutas protegidas

### Frontend
- [ ] **REMOVER** campos `user` de los formularios
- [ ] Asegurar que todas las peticiones incluyan `Authorization: Bearer ${token}`
- [ ] Verificar que el token JWT incluya `id_user` en el payload

### Testing
- [ ] Probar crear usuario autenticado (debe usar id_user del token)
- [ ] Probar crear usuario sin token (debe usar SYSTEM_USER_ID)
- [ ] Probar actualizar usuario (user_update debe ser id_user del token)
- [ ] Probar crear conductor
- [ ] Probar actualizar conductor
- [ ] Verificar en BD que user_create/user_update son INTEGER
- [ ] Verificar consultas de auditoría con JOIN

---

## 🔍 CONSULTAS DE VERIFICACIÓN

```sql
-- Ver quién creó cada usuario (con nombre del creador)
SELECT 
    u.id_user,
    u.email,
    u.full_name,
    creator.full_name AS created_by,
    u.created_at
FROM tab_users u
LEFT JOIN tab_users creator ON u.user_create = creator.id_user
ORDER BY u.created_at DESC;

-- Ver quién actualizó cada usuario
SELECT 
    u.id_user,
    u.email,
    u.full_name,
    updater.full_name AS updated_by,
    u.updated_at
FROM tab_users u
LEFT JOIN tab_users updater ON u.user_update = updater.id_user
WHERE u.user_update IS NOT NULL
ORDER BY u.updated_at DESC;

-- Auditoría completa de conductores
SELECT 
    u.id_user,
    u.full_name AS driver_name,
    dd.id_card,
    creator.full_name AS created_by,
    u.created_at,
    updater.full_name AS last_updated_by,
    u.updated_at
FROM tab_users u
INNER JOIN tab_driver_details dd ON u.id_user = dd.id_user
LEFT JOIN tab_users creator ON u.user_create = creator.id_user
LEFT JOIN tab_users updater ON u.user_update = updater.id_user
ORDER BY u.created_at DESC;
```

---

## ⚠️ IMPORTANTE

1. **Orden de ejecución:**
   - Primero: Crear esquema con FKs (`user_roles.sql`)
   - Segundo: Migrar datos existentes (`MIGRATION_AUDIT_TO_FK.sql`)
   - Tercero: Actualizar funciones (`FUNCTIONS_AUDIT_FK.sql`)
   - Cuarto: Actualizar backend
   - Quinto: Actualizar frontend

2. **Backup:** Hacer backup de la base de datos antes de migrar

3. **Testing:** Probar en ambiente de desarrollo antes de producción

4. **Rollback:** Si algo falla, restaurar el backup y revertir cambios

---

**Beneficios del nuevo diseño:**
- ✅ Integridad referencial garantizada
- ✅ JOINs directos para auditoría
- ✅ Imposible tener IDs de usuarios inexistentes
- ✅ ON DELETE cascades bien definidos
- ✅ Mejor performance (índices en INTEGER vs VARCHAR)
- ✅ Tipo de dato correcto para relaciones

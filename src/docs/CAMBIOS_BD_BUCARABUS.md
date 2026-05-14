# 📋 RESUMEN DE CORRECCIONES EN bd_bucarabus.sql

## ✅ CAMBIOS COMPLETADOS

Se corrigieron **4 tablas** para usar campos de auditoría con **INTEGER + FOREIGN KEY** en lugar de VARCHAR:

### 1. **tab_buses** ✅

**ANTES:**
```sql
user_create VARCHAR
user_update VARCHAR
```

**DESPUÉS:**
```sql
user_create INTEGER NOT NULL DEFAULT 1735689600  -- FK a tab_users(id_user)
user_update INTEGER                              -- FK a tab_users(id_user)

-- Foreign Keys agregados:
CONSTRAINT fk_buses_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
CONSTRAINT fk_buses_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL

-- Índices agregados:
CREATE INDEX idx_buses_created_by ON tab_buses(user_create)
CREATE INDEX idx_buses_updated_by ON tab_buses(user_update) WHERE user_update IS NOT NULL
```

---

### 2. **tab_routes** ✅

**ANTES:**
```sql
user_create VARCHAR(255) NOT NULL
user_update VARCHAR(255)
```

**DESPUÉS:**
```sql
user_create INTEGER NOT NULL DEFAULT 1735689600  -- FK a tab_users(id_user)
user_update INTEGER                              -- FK a tab_users(id_user)

-- Foreign Keys agregados:
CONSTRAINT fk_routes_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
CONSTRAINT fk_routes_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL

-- Índices agregados:
CREATE INDEX idx_routes_created_by ON tab_routes(user_create)
CREATE INDEX idx_routes_updated_by ON tab_routes(user_update) WHERE user_update IS NOT NULL
```

---

### 3. **tab_bus_assignments** ✅

**ANTES:**
```sql
assigned_by   VARCHAR(50) NOT NULL
unassigned_by VARCHAR(50) NULL
-- No tenía user_create/user_update
```

**DESPUÉS:**
```sql
assigned_by   INTEGER NOT NULL DEFAULT 1735689600  -- FK a tab_users(id_user)
unassigned_by INTEGER NULL                         -- FK a tab_users(id_user)
created_at    TIMESTAMP DEFAULT NOW()              -- ✅ NUEVO
user_create   INTEGER NOT NULL DEFAULT 1735689600  -- ✅ NUEVO - FK a tab_users(id_user)
updated_at    TIMESTAMP                            -- ✅ NUEVO
user_update   INTEGER                              -- ✅ NUEVO - FK a tab_users(id_user)

-- Foreign Keys agregados:
CONSTRAINT fk_assignments_assigned_by    FOREIGN KEY (assigned_by)   REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
CONSTRAINT fk_assignments_unassigned_by  FOREIGN KEY (unassigned_by) REFERENCES tab_users(id_user) ON DELETE SET NULL
CONSTRAINT fk_assignments_created_by     FOREIGN KEY (user_create)   REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
CONSTRAINT fk_assignments_updated_by     FOREIGN KEY (user_update)   REFERENCES tab_users(id_user) ON DELETE SET NULL

-- Índices agregados:
CREATE INDEX idx_assignments_assigned_by ON tab_bus_assignments(assigned_by)
CREATE INDEX idx_assignments_created_by ON tab_bus_assignments(user_create)
CREATE INDEX idx_assignments_updated_by ON tab_bus_assignments(user_update) WHERE user_update IS NOT NULL
```

---

### 4. **tab_trips** ✅

**ANTES:**
```sql
user_create VARCHAR(100) NOT NULL
user_update VARCHAR(100)
```

**DESPUÉS:**
```sql
user_create INTEGER NOT NULL DEFAULT 1735689600  -- FK a tab_users(id_user)
user_update INTEGER                              -- FK a tab_users(id_user)

-- Foreign Keys agregados:
CONSTRAINT fk_trips_created_by FOREIGN KEY (user_create) REFERENCES tab_users(id_user) ON DELETE SET DEFAULT
CONSTRAINT fk_trips_updated_by FOREIGN KEY (user_update) REFERENCES tab_users(id_user) ON DELETE SET NULL

-- Índices agregados:
CREATE INDEX idx_trips_created_by ON tab_trips(user_create)
CREATE INDEX idx_trips_updated_by ON tab_trips(user_update) WHERE user_update IS NOT NULL
```

---

## 📊 RESUMEN DE CAMPOS AGREGADOS

| Tabla | Campos Corregidos | FKs Agregados | Índices Agregados |
|-------|-------------------|---------------|-------------------|
| **tab_buses** | user_create, user_update | 2 | 2 |
| **tab_routes** | user_create, user_update | 2 | 2 |
| **tab_bus_assignments** | assigned_by, unassigned_by, created_at, user_create, updated_at, user_update | 4 | 3 |
| **tab_trips** | user_create, user_update | 2 | 2 |
| **TOTAL** | **12 campos** | **10 FKs** | **9 índices** |

---

## 🔧 ARCHIVOS QUE NECESITAN ACTUALIZACIÓN

### Backend Services (api/services/)

#### 1. **buses.service.js** - CRÍTICO ⚠️

**Archivo:** `api/services/buses.service.js`  
**Línea 159:** `user_create = 'system'` → Debe cambiar a `user_create_id = null`

**ANTES:**
```javascript
const {
  plate_number, amb_code, id_company, capacity,
  photo_url = null, soat_exp, techno_exp, rcc_exp, rce_exp,
  id_card_owner, name_owner,
  user_create = 'system'  // ❌ STRING
} = busData;

const result = await pool.query(
  `SELECT * FROM fun_create_bus($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
  [
    plate_number, amb_code, id_company, capacity,
    photo_url, soat_exp, techno_exp, rcc_exp, rce_exp,
    id_card_owner, name_owner,
    user_create  // ❌ Pasa 'system'
  ]
);
```

**DESPUÉS:**
```javascript
const SYSTEM_USER_ID = 1735689600;

const {
  plate_number, amb_code, id_company, capacity,
  photo_url = null, soat_exp, techno_exp, rcc_exp, rce_exp,
  id_card_owner, name_owner,
  user_create_id = null  // ✅ INTEGER o null
} = busData;

const result = await pool.query(
  `SELECT * FROM fun_create_bus($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
  [
    plate_number, amb_code, id_company, capacity,
    photo_url, soat_exp, techno_exp, rcc_exp, rce_exp,
    id_card_owner, name_owner,
    user_create_id || SYSTEM_USER_ID  // ✅ Pasa INTEGER
  ]
);
```

**También actualizar:**
- `updateBus()` - Agregar `user_update_id`
- Otros métodos que usen campos de auditoría

---

#### 2. **routes.service.js** - REVISAR

**Buscar funciones que usen:**
- `fun_create_route()`
- `fun_update_route()`
- Cambiar parámetros VARCHAR a INTEGER

---

#### 3. **trips.service.js** - REVISAR

**Buscar funciones que usen:**
- `fun_create_trip()`
- `fun_update_trip()`
- `fun_create_trips_batch()`
- Cambiar parámetros VARCHAR a INTEGER

---

#### 4. **assignments.service.js** - REVISAR

**Buscar funciones que usen:**
- Campos `assigned_by` y `unassigned_by`
- Ahora deben recibir INTEGER en lugar de VARCHAR

---

### Backend Routes (api/routes/)

Todos los routes que llamen a estos services necesitan:

1. **Obtener `id_user` del usuario autenticado** (desde JWT/sesión)
2. **Pasar `user_create_id` o `user_update_id`** en lugar de strings

**Ejemplo:**
```javascript
// ANTES
router.post('/', async (req, res) => {
  const { ...busData, user } = req.body;
  const result = await busesService.createBus({
    ...busData,
    user_create: user || 'admin'  // ❌ STRING
  });
});

// DESPUÉS
router.post('/', authMiddleware, async (req, res) => {
  const authenticatedUserId = req.user.id_user;  // Desde JWT
  const result = await busesService.createBus({
    ...req.body,
    user_create_id: authenticatedUserId  // ✅ INTEGER
  });
});
```

---

## 🗂️ FUNCIONES SQL QUE USAN %TYPE (AUTO-ADAPTAN)

Estas funciones usan `tab_buses.user_create%TYPE` y se adaptarán automáticamente:

✅ `api/database/fun_create_bus.sql` - Línea 16  
✅ `api/database/fun_update_bus.sql` - Revisar  
✅ `api/database/fun_create_trip.sql` - Revisar  
✅ `api/database/fun_update_trip.sql` - Revisar  
✅ `api/database/fun_create_update_SOFT_DELETE_route.sql` - Revisar  

**Ventaja:** Al usar `%TYPE`, cuando la tabla cambie a INTEGER, las funciones heredarán el tipo automáticamente.

**Pero:** Los services que llaman a estas funciones **SÍ necesitan cambiar** de pasar 'system' a pasar 1735689600.

---

## 📝 COMENTARIOS AGREGADOS

Se agregaron comentarios SQL para documentar todos los campos:

```sql
COMMENT ON COLUMN tab_buses.user_create IS 'ID del usuario administrador que creó el bus (FK a tab_users)';
COMMENT ON COLUMN tab_buses.user_update IS 'ID del usuario administrador que actualizó el bus por última vez (FK a tab_users)';

COMMENT ON COLUMN tab_routes.user_create IS 'ID del usuario administrador que creó la ruta (FK a tab_users)';
COMMENT ON COLUMN tab_routes.user_update IS 'ID del usuario administrador que actualizó la ruta por última vez (FK a tab_users)';

COMMENT ON COLUMN tab_bus_assignments.assigned_by IS 'ID del usuario que realizó la asignación (FK a tab_users)';
COMMENT ON COLUMN tab_bus_assignments.unassigned_by IS 'ID del usuario que realizó la desasignación (FK a tab_users)';
COMMENT ON COLUMN tab_bus_assignments.user_create IS 'ID del usuario que creó el registro (FK a tab_users)';
COMMENT ON COLUMN tab_bus_assignments.user_update IS 'ID del usuario que actualizó el registro (FK a tab_users)';

COMMENT ON COLUMN tab_trips.user_create IS 'ID del usuario administrador que creó el turno/viaje (FK a tab_users)';
COMMENT ON COLUMN tab_trips.user_update IS 'ID del usuario administrador que actualizó el turno/viaje (FK a tab_users)';
```

---

## 🚀 ORDEN DE IMPLEMENTACIÓN

### Fase 1: Base de Datos ✅

- [x] Actualizar `bd_bucarabus.sql` con campos INTEGER + FK
- [x] Agregar comentarios a las tablas
- [ ] **PENDIENTE:** Ejecutar migración en BD de producción

### Fase 2: Backend - Services

- [ ] Actualizar `buses.service.js`
- [ ] Actualizar `routes.service.js`
- [ ] Actualizar `trips.service.js`
- [ ] Actualizar `assignments.service.js`
- [ ] Crear `api/config/constants.js` con `SYSTEM_USER_ID = 1735689600`

### Fase 3: Backend - Routes

- [ ] Actualizar `buses.routes.js` - Usar `req.user.id_user`
- [ ] Actualizar `routes.routes.js` - Usar `req.user.id_user`
- [ ] Actualizar `trips.routes.js` - Usar `req.user.id_user`
- [ ] Actualizar `assignments.routes.js` - Usar `req.user.id_user`

### Fase 4: Middleware

- [ ] Crear/actualizar `auth.js` middleware para extraer `id_user` del JWT

### Fase 5: Frontend

- [ ] Remover campos `user` de formularios
- [ ] Asegurar que peticiones incluyan `Authorization: Bearer <token>`
- [ ] Verificar que JWT incluya `id_user` en payload

### Fase 6: Testing

- [ ] Probar crear bus con auditoría
- [ ] Probar crear ruta con auditoría
- [ ] Probar crear trip con auditoría
- [ ] Probar asignaciones con auditoría
- [ ] Verificar JOINs de auditoría funcionan

---

## ⚠️ IMPORTANTE

### Usuario del Sistema (ID: 1735689600)

Todas las tablas ahora usan `DEFAULT 1735689600` para `user_create`. Este ID debe existir en `tab_users` **ANTES** de insertar cualquier dato.

**Ejecutar PRIMERO:**
```sql
-- Ver user_roles.sql líneas 83-110 para crear usuario del sistema
INSERT INTO tab_users (
  id_user, email, password_hash, full_name,
  created_at, user_create, is_active
) VALUES (
  1735689600,
  'system@bucarabus.local',
  '$2b$10$SYSTEMUSERDUMMYHASH0000000000000000000000000000000',
  'Sistema Bucarabus',
  NOW(),
  1735689600,
  TRUE
) ON CONFLICT (id_user) DO NOTHING;
```

### Foreign Key Cascades

- **ON DELETE SET DEFAULT** para `user_create` → Si se borra el creador, usa sistema
- **ON DELETE SET NULL** para `user_update` → Si se borra el actualizador, deja NULL

---

## 📊 CONSULTAS DE AUDITORÍA ÚTILES

```sql
-- Ver quién creó cada bus
SELECT 
    b.plate_number,
    b.amb_code,
    creator.full_name AS created_by,
    b.created_at
FROM tab_buses b
LEFT JOIN tab_users creator ON b.user_create = creator.id_user
ORDER BY b.created_at DESC;

-- Ver quién actualizó cada ruta
SELECT 
    r.id_route,
    r.name_route,
    updater.full_name AS updated_by,
    r.updated_at
FROM tab_routes r
LEFT JOIN tab_users updater ON r.user_update = updater.id_user
WHERE r.user_update IS NOT NULL
ORDER BY r.updated_at DESC;

-- Auditoría completa de asignaciones
SELECT 
    a.id_assignment,
    b.amb_code AS bus,
    u.full_name AS conductor,
    assigner.full_name AS assigned_by,
    a.assigned_at,
    unassigner.full_name AS unassigned_by,
    a.unassigned_at
FROM tab_bus_assignments a
INNER JOIN tab_buses b ON a.plate_number = b.plate_number
INNER JOIN tab_users u ON a.id_user = u.id_user
LEFT JOIN tab_users assigner ON a.assigned_by = assigner.id_user
LEFT JOIN tab_users unassigner ON a.unassigned_by = unassigner.id_user
ORDER BY a.assigned_at DESC;

-- Ver quién creó cada trip
SELECT 
    t.id_trip,
    r.name_route AS ruta,
    t.trip_date,
    t.start_time,
    creator.full_name AS created_by,
    t.created_at
FROM tab_trips t
INNER JOIN tab_routes r ON t.id_route = r.id_route
LEFT JOIN tab_users creator ON t.user_create = creator.id_user
ORDER BY t.trip_date DESC, t.start_time;
```

---

## ✅ BENEFICIOS DE LOS CAMBIOS

1. ✅ **Integridad Referencial:** Imposible tener IDs de usuarios inexistentes
2. ✅ **JOINs Directos:** Consultas de auditoría más eficientes
3. ✅ **Performance:** Índices en INTEGER son más rápidos que VARCHAR
4. ✅ **Tipo Correcto:** INTEGER para relaciones, no VARCHAR
5. ✅ **Cascadas Seguras:** ON DELETE bien definidos
6. ✅ **Auditoría Completa:** Saber exactamente quién hizo qué y cuándo
7. ✅ **Estandarización:** Todas las tablas siguen el mismo patrón

---

**Estado:** ✅ bd_bucarabus.sql completamente corregido  
**Siguiente paso:** Actualizar services y routes del backend  
**Documentos de referencia:**  
- [user_roles.sql](user_roles.sql) - Esquema de usuarios con FKs  
- [GUIA_MIGRACION_AUDITORIA_FK.md](GUIA_MIGRACION_AUDITORIA_FK.md) - Guía completa backend  
- [MIGRATION_AUDIT_TO_FK.sql](MIGRATION_AUDIT_TO_FK.sql) - Script de migración de datos

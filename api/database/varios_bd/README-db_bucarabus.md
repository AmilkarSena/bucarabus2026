# 🎉 Base de Datos db_bucarabus - Deployment Completado

## ✅ Estado Actual

La base de datos **db_bucarabus** está completamente desplegada y funcional.

### 📊 Recursos Creados

| Recurso | Cantidad | Estado |
|---------|----------|--------|
| **Base de datos** | db_bucarabus | ✅ Activa |
| **Tablas** | 9 principales + PostGIS | ✅ Creadas |
| **Funciones CREATE** | 6 funciones | ✅ Operativas |
| **Funciones UPDATE** | 5 funciones | ✅ Operativas |
| **Funciones DELETE** | 4 funciones | ✅ Operativas |
| **Funciones ESPECIALES** | 4 funciones | ✅ Operativas |
| **Usuario sistema** | ID: 1735689600 | ✅ Creado |
| **Roles** | 4 roles | ✅ Creados |

### 🔐 Credenciales

```
Base de datos: db_bucarabus
Usuario:       bucarabus_user
Contraseña:    bucarabus2024
Host:          localhost
Puerto:        5432
```

### 📋 Tablas Principales

1. `tab_users` - Usuarios del sistema
2. `tab_roles` - Roles de usuario
3. `tab_user_roles` - Relación usuarios-roles
4. `tab_driver_details` - Detalles de conductores
5. `tab_buses` - Catálogo de buses
6. `tab_routes` - Rutas con geometría PostGIS
7. `tab_favorite_routes` - Rutas favoritas
8. `tab_bus_assignments` - Asignaciones bus-conductor
9. `tab_trips` - Turnos/viajes programados

### 🔧 Funciones Disponibles

#### CREATE (6 funciones)
- `fun_create_user(email, hash, name, user_create, avatar?)`
- `fun_create_bus(plate, amb, company, capacity, ...)`
- `fun_create_driver(email, hash, name, id_card, ...)`
- `fun_create_route(name, path, user_create, description?, color?)`
- `fun_create_trip(id_route, date, start, end, user_create, plate?, status?)`
- `fun_create_trips_batch(id_route, dates, user_create)`

#### UPDATE (5 funciones)
- `fun_update_user(id_user, user_update, name?, avatar?)`
- `fun_update_bus(plate, amb, company, ...)`
- `fun_update_driver(id_user, user_update, name?, avatar?, ...)`
- `fun_update_route(id_route, user_update, name?, description?, color?)`
- `fun_update_trip(id_trip, user_update, start?, end?, plate?, status?)`

#### DELETE (4 funciones)
- `fun_delete_driver(id_user, user_delete)`
- `fun_delete_route(id_route, user_delete)`
- `fun_delete_trip(id_trip, user_delete)`
- `fun_delete_trips_by_date(id_route, date, user_delete)`

#### ESPECIALES (4 funciones)
- `fun_assign_driver(plate, id_user?, user_assign)`
- `fun_toggle_bus_status(plate, is_active, user_update)`
- `fun_set_trip_bus(id_trip, plate?, user_update)`
- `fun_cancel_trip(id_trip, user_update)`

## 🚀 Comandos Rápidos

### Conectar a la base de datos

```powershell
# PowerShell
$env:Path += ";C:\Program Files\PostgreSQL\17\bin"
$env:PGPASSWORD = "bucarabus2024"
psql -U bucarabus_user -d db_bucarabus
```

```bash
# Bash/Linux
export PGPASSWORD="bucarabus2024"
psql -U bucarabus_user -d db_bucarabus -h localhost
```

### Consultas Útiles

```sql
-- Listar todas las funciones
SELECT proname, pronargs 
FROM pg_proc 
WHERE proname LIKE 'fun_%' 
ORDER BY proname;

-- Ver usuario del sistema
SELECT * FROM tab_users WHERE id_user = 1735689600;

-- Ver roles disponibles
SELECT * FROM tab_roles ORDER BY id_role;

-- Ver tablas
\dt

-- Ver funciones con detalles
\df fun_*
```

## 📝 Próximos Pasos

### 1. Actualizar Backend

Archivo: `api/config/database.js`

```javascript
const pool = new Pool({
  user: 'bucarabus_user',
  host: 'localhost',
  database: 'db_bucarabus',  // ⚠️ CAMBIAR AQUÍ
  password: 'bucarabus2024',
  port: 5432,
});
```

### 2. Actualizar Servicios

**IMPORTANTE**: Los parámetros `user_create` y `user_update` ahora son **INTEGER** (no VARCHAR).

```javascript
// ❌ ANTES (INCORRECTO)
const result = await pool.query(
  'SELECT * FROM fun_create_user($1, $2, $3, $4, $5)',
  [email, hash, name, avatar, 'system']
);

// ✅ AHORA (CORRECTO)
const SYSTEM_USER_ID = 1735689600;
const result = await pool.query(
  'SELECT * FROM fun_create_user($1, $2, $3, $4, $5)',
  [email, hash, name, SYSTEM_USER_ID, avatar]
);
```

Ver ejemplos completos en: `api/config/database-NEW-CONFIG.js`

### 3. Probar Funciones

```bash
# Ejecutar pruebas automáticas
psql -U bucarabus_user -d db_bucarabus -f test-functions.sql
```

### 4. Variables de Entorno

Crear archivo `.env`:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=db_bucarabus
DB_USER=bucarabus_user
DB_PASSWORD=bucarabus2024
```

## 🔍 Troubleshooting

### Error: "psql no encontrado"

```powershell
# Windows - Agregar al PATH
$env:Path += ";C:\Program Files\PostgreSQL\17\bin"
```

### Error: "password authentication failed"

Verificar que la contraseña es `bucarabus2024` y el usuario es `bucarabus_user`.

### Error: "database does not exist"

La base de datos debe llamarse exactamente `db_bucarabus` (no `bucarabus_db`).

## 📚 Archivos Creados

- `setup-db_bucarabus.sql` - Script de creación de BD
- `deploy-db_bucarabus.sql` - Deployment completo
- `test-functions.sql` - Script de pruebas
- `database-NEW-CONFIG.js` - Configuración backend
- `README-db_bucarabus.md` - Este archivo

## 🎯 Características v2.0

✅ Auditoría consistente con INTEGER (user_create/user_update)  
✅ Todas las funciones usan OUT parameters  
✅ Error codes descriptivos (no SQLSTATE)  
✅ Validación completa de usuarios  
✅ ROW_COUNT verification  
✅ TRY-CATCH con handlers específicos  
✅ 19 funciones modernizadas  
✅ PostGIS para geometrías  
✅ Índices optimizados  
✅ Datos iniciales (sistema + roles)  

---

**Fecha de deployment**: 2026-02-16  
**Versión**: 2.0  
**Estado**: ✅ Producción Ready

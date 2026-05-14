# 🚍 Deployment de Funciones BucaraBUS v2.0

Scripts automatizados para desplegar todas las funciones de la base de datos en el orden correcto de dependencias.

## 📋 Requisitos Previos

- PostgreSQL 14+ instalado con PostGIS
- Cliente `psql` disponible en el PATH
- Base de datos `bucarabus_db` creada
- Usuario `bucarabus_user` con permisos de escritura
- Contraseña del usuario de base de datos

## 🚀 Uso Rápido

### Opción 1: Script SQL Simple (Recomendado para principiantes)

```bash
# Deployment completo (esquema + funciones)
psql -U bucarabus_user -d bucarabus_db -f deploy-all.sql

# Solo funciones (si el esquema ya existe)
psql -U bucarabus_user -d bucarabus_db -f deploy-functions-only.sql
```

### Opción 2: Windows (PowerShell)

```powershell
# Ejecutar con configuración por defecto
.\deploy-functions.ps1

# Especificar parámetros
.\deploy-functions.ps1 -DbName "bucarabus_db" -DbUser "bucarabus_user" -DbHost "localhost" -DbPort 5432

# Omitir el esquema (si ya existe)
.\deploy-functions.ps1 -SkipSchema

# Modo verbose (ver comandos SQL)
.\deploy-functions.ps1 -Verbose
```

### Opción 3: Linux/Mac (Bash)

```bash
# Dar permisos de ejecución
chmod +x deploy-functions.sh

# Ejecutar con configuración por defecto
./deploy-functions.sh

# Especificar parámetros
./deploy-functions.sh bucarabus_db bucarabus_user localhost 5432

# Omitir el esquema (si ya existe)
SKIP_SCHEMA=true ./deploy-functions.sh

# Modo verbose
VERBOSE=true ./deploy-functions.sh
```

## 📦 Archivos Incluidos

### Scripts de Deployment

| Archivo | Descripción | Uso Recomendado |
|---------|-------------|-----------------|
| `deploy-all.sql` | Script SQL completo (esquema + funciones) | Primera instalación |
| `deploy-functions-only.sql` | Solo funciones, omite esquema | Updates subsecuentes |
| `deploy-functions.ps1` | Script PowerShell automatizado | Windows con control avanzado |
| `deploy-functions.sh` | Script Bash automatizado | Linux/Mac con control avanzado |
| `README_DEPLOYMENT.md` | Documentación completa | Referencia |

### Funciones SQL Incluidas

El script ejecuta los siguientes archivos en orden:

### 1. Esquema Base (Opcional)
- ✅ `bd_bucarabus.sql` - Esquema con tablas, índices y datos iniciales

### 2. Funciones CREATE (6 archivos)
- ✅ `fun_create_user.sql` - Crear usuarios en el sistema
- ✅ `fun_create_bus.sql` - Crear buses en el catálogo
- ✅ `fun_create_driver.sql` - Crear conductores con detalles
- ✅ `fun_create_route.sql` - Crear rutas con geometría PostGIS
- ✅ `fun_create_trip.sql` - Crear turnos/viajes (2 funciones)

### 3. Funciones UPDATE (5 archivos)
- ✅ `fun_update_user.sql` - Actualizar usuarios (nombre, avatar)
- ✅ `fun_update_bus.sql` - Actualizar datos de buses
- ✅ `fun_update_driver.sql` - Actualizar datos de conductores
- ✅ `fun_update_route.sql` - Actualizar metadatos de rutas
- ✅ `fun_update_trip.sql` - Actualizar turnos/viajes (2 funciones)

### 4. Funciones DELETE (3 archivos)
- ✅ `fun_delete_driver.sql` - Eliminar/desactivar conductores
- ✅ `fun_delete_route.sql` - Eliminar/desactivar rutas
- ✅ `fun_delete_trip.sql` - Eliminar turnos/viajes (3 funciones)

### 5. Funciones Especiales (2 archivos)
- ✅ `fun_assign_driver.sql` - Asignar/desasignar conductor a bus
- ✅ `fun_toggle_bus_status.sql` - Activar/desactivar buses

**Total: 16 archivos SQL - 19+ funciones PostgreSQL**

## 🎯 Orden de Dependencias

El script ejecuta los archivos en el orden correcto para evitar errores de dependencias:

```
bd_bucarabus.sql (esquema)
    ↓
fun_create_* (crear entidades)
    ↓
fun_update_* (actualizar entidades)
    ↓
fun_delete_* (eliminar entidades)
    ↓
fun_assign_*, fun_toggle_* (funciones especiales)
```

## ⚙️ Parámetros Disponibles

### PowerShell

| Parámetro | Tipo | Por Defecto | Descripción |
|-----------|------|-------------|-------------|
| `-DbName` | String | `bucarabus_db` | Nombre de la base de datos |
| `-DbUser` | String | `bucarabus_user` | Usuario de PostgreSQL |
| `-DbHost` | String | `localhost` | Host del servidor |
| `-DbPort` | Int | `5432` | Puerto de PostgreSQL |
| `-SkipSchema` | Switch | `false` | Omitir bd_bucarabus.sql |
| `-Verbose` | Switch | `false` | Mostrar comandos SQL ejecutados |

### Bash

| Variable | Por Defecto | Descripción |
|----------|-------------|-------------|
| `$1` (arg1) | `bucarabus_db` | Nombre de la base de datos |
| `$2` (arg2) | `bucarabus_user` | Usuario de PostgreSQL |
| `$3` (arg3) | `localhost` | Host del servidor |
| `$4` (arg4) | `5432` | Puerto de PostgreSQL |
| `SKIP_SCHEMA` | `false` | Omitir bd_bucarabus.sql |
| `VERBOSE` | `false` | Mostrar comandos SQL ejecutados |

## 📊 Ejemplo de Salida

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       🚍 BucaraBUS - Deployment de Funciones v2.0       ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

📊 Configuración:
   Base de datos: bucarabus_db
   Usuario:       bucarabus_user
   Host:          localhost
   Puerto:        5432

✅ psql encontrado: /usr/bin/psql

▶ Ejecutando: bd_bucarabus.sql
  Esquema base de datos con tablas, índices y datos iniciales
  ✅ Éxito

▶ Ejecutando: fun_create_user.sql
  Crear usuarios en el sistema
  ✅ Éxito

▶ Ejecutando: fun_create_bus.sql
  Crear buses en el catálogo
  ✅ Éxito

...

╔══════════════════════════════════════════════════════════╗
║                    RESUMEN FINAL                         ║
╚══════════════════════════════════════════════════════════╝

📊 Estadísticas:
   Total archivos: 16
   ✅ Éxitos:      16
   ❌ Fallos:       0
   ⏭ Omitidos:     0

🎉 ¡Deployment completado exitosamente!

📝 Próximos pasos:
   1. Verificar funciones: SELECT proname FROM pg_proc WHERE proname LIKE 'fun_%';
   2. Probar funciones CREATE con usuario del sistema (1735689600)
   3. Actualizar backend para usar INTEGER en user_create/user_update
   4. Ejecutar pruebas end-to-end
```

## 🔍 Verificación Post-Deployment

Después de ejecutar el script, verifica que todas las funciones se crearon correctamente:

```sql
-- Listar todas las funciones fun_*
SELECT 
    proname AS function_name,
    pronargs AS num_args,
    pg_get_function_identity_arguments(oid) AS arguments
FROM pg_proc
WHERE proname LIKE 'fun_%'
ORDER BY proname;

-- Verificar funciones específicas
SELECT proname FROM pg_proc WHERE proname IN (
    'fun_create_user',
    'fun_create_bus',
    'fun_create_driver',
    'fun_create_route',
    'fun_create_trip',
    'fun_create_trip_bulk',
    'fun_update_user',
    'fun_update_bus',
    'fun_update_driver',
    'fun_update_route',
    'fun_update_trip',
    'fun_set_trip_bus',
    'fun_delete_driver',
    'fun_delete_route',
    'fun_delete_trip',
    'fun_delete_trip_bulk',
    'fun_delete_trips_by_route',
    'fun_assign_driver',
    'fun_toggle_bus_status'
);
```

## 🧪 Pruebas Básicas

Después del deployment, ejecuta pruebas básicas:

```sql
-- 1. Crear un usuario de prueba
SELECT * FROM fun_create_user(
    1735689650,
    'test@bucarabus.com',
    '$2b$10$TESTHASH000000000000000000000000000000000000000',
    'Usuario de Prueba',
    NULL,
    1735689600
);

-- 2. Actualizar el usuario
SELECT * FROM fun_update_user(
    1735689650,
    'Usuario Actualizado',
    'https://example.com/avatar.jpg',
    1735689600
);

-- 3. Verificar que el usuario existe
SELECT id_user, email, full_name, avatar_url, is_active
FROM tab_users
WHERE id_user = 1735689650;
```

## ❌ Manejo de Errores

### Error: "psql no está disponible en el PATH"

**Windows:**
```powershell
# Agregar psql al PATH temporal
$env:Path += ";C:\Program Files\PostgreSQL\16\bin"

# O agregar permanentemente en Variables de Entorno del Sistema
```

**Linux/Mac:**
```bash
# Instalar PostgreSQL client
sudo apt-get install postgresql-client  # Ubuntu/Debian
sudo yum install postgresql             # CentOS/RHEL
brew install postgresql                 # macOS
```

### Error: "Archivo no encontrado"

Asegúrate de estar en el directorio correcto:

```bash
cd vue-bucarabus/api/database
./deploy-functions.sh
```

### Error: "FATAL: password authentication failed"

Verifica que:
1. El usuario existe: `psql -U postgres -c "\du"`
2. La contraseña es correcta
3. El archivo `pg_hba.conf` permite la conexión

### Error: "database does not exist"

Crea la base de datos primero:

```sql
psql -U postgres -c "CREATE DATABASE bucarabus_db;"
psql -U postgres -c "CREATE USER bucarabus_user WITH PASSWORD 'tu_contraseña';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE bucarabus_db TO bucarabus_user;"
```

## 🔄 Rollback

Si necesitas revertir los cambios:

```sql
-- Eliminar todas las funciones fun_*
DO $$
DECLARE
    func RECORD;
BEGIN
    FOR func IN 
        SELECT oid::regprocedure AS signature
        FROM pg_proc
        WHERE proname LIKE 'fun_%'
    LOOP
        EXECUTE 'DROP FUNCTION ' || func.signature || ' CASCADE';
    END LOOP;
END $$;

-- Verificar que se eliminaron
SELECT proname FROM pg_proc WHERE proname LIKE 'fun_%';
```

## 📚 Recursos Adicionales

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostGIS Documentation](https://postgis.net/documentation/)
- [psql Command Reference](https://www.postgresql.org/docs/current/app-psql.html)

## 🆘 Soporte

Si encuentras problemas:

1. Revisa los logs de PostgreSQL: `tail -f /var/log/postgresql/postgresql-*.log`
2. Ejecuta con `-Verbose` o `VERBOSE=true` para ver más detalles
3. Verifica que todas las funciones CREATE se ejecutaron antes de UPDATE
4. Asegúrate de que el usuario del sistema (1735689600) existe en tab_users

## 📝 Notas Importantes

- ⚠️ **SIEMPRE** haz un backup antes de ejecutar en producción
- ⚠️ El script pedirá la contraseña de forma interactiva (no se guarda)
- ⚠️ Si un archivo falla, el script pregunta si deseas continuar
- ℹ️ Usa `-SkipSchema` en deploys subsecuentes (evita recrear tablas)
- ℹ️ El orden de ejecución es crítico para evitar errores de dependencias

## 🎯 Changelog

### v2.0 (Febrero 2025)
- ✅ Migración completa a auditoría con INTEGER (user_create/user_update)
- ✅ Todas las funciones usan OUT parameters
- ✅ Error codes descriptivos (no SQLSTATE genéricos)
- ✅ Validación completa de usuarios updater/creator
- ✅ ROW_COUNT verification en todas las operaciones
- ✅ TRY-CATCH con handlers específicos
- ✅ 19+ funciones modernizadas
- ✅ Scripts de deployment automatizados

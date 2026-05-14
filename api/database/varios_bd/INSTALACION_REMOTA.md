# 🚀 Instalación en Servidor Remoto

## 📋 Servidor PostgreSQL

- **Host:** 10.5.213.111
- **Puerto:** 5432
- **Base de datos:** db_bucarabus
- **Usuario:** dlastre
- **Contraseña:** Remoto1050

---

## ⚡ Instalación Rápida (1 comando)

```powershell
cd api\database
.\instalar-rapido.ps1
```

Este script ejecuta la instalación directamente sin pedir confirmación.

---

## 🔍 Instalación con Verificaciones (Recomendado)

```powershell
cd api\database
.\instalar-remoto.ps1
```

Este script:
- ✅ Verifica que PostgreSQL esté instalado
- ✅ Verifica conectividad al servidor
- ✅ Pide confirmación antes de ejecutar
- ✅ Muestra mensajes detallados de progreso
- ✅ Verifica el resultado final

---

## 📝 Método Manual (Si los scripts no funcionan)

### Windows PowerShell

```powershell
# Navegar a la carpeta de scripts
cd api\database

# Configurar contraseña
$env:PGPASSWORD = "Remoto1050"

# Ejecutar instalación
psql -h 10.5.213.111 -p 5432 -U dlastre -d db_bucarabus -f deploy-all.sql

# Limpiar contraseña
$env:PGPASSWORD = $null
```

### Linux/Mac Bash

```bash
# Navegar a la carpeta de scripts
cd api/database

# Configurar contraseña y ejecutar
PGPASSWORD="Remoto1050" psql -h 10.5.213.111 -p 5432 -U dlastre -d db_bucarabus -f deploy-all.sql
```

---

## ✅ Verificar Instalación

### 1. Verificar funciones creadas

```powershell
$env:PGPASSWORD = "Remoto1050"
psql -h 10.5.213.111 -U dlastre -d db_bucarabus -c "\df fun_*"
$env:PGPASSWORD = $null
```

Deberías ver 16+ funciones: `fun_create_user`, `fun_create_bus`, etc.

### 2. Verificar datos iniciales

```powershell
$env:PGPASSWORD = "Remoto1050"
psql -h 10.5.213.111 -U dlastre -d db_bucarabus -c "SELECT * FROM tab_users;"
$env:PGPASSWORD = $null
```

Deberías ver el usuario del sistema con ID 1.

### 3. Verificar tablas

```powershell
$env:PGPASSWORD = "Remoto1050"
psql -h 10.5.213.111 -U dlastre -d db_bucarabus -c "\dt"
$env:PGPASSWORD = $null
```

Deberías ver: `tab_users`, `tab_routes`, `tab_buses`, `tab_trips`, etc.

---

## 🔧 Configurar Backend

El archivo `api/.env` ya está configurado con los datos del servidor remoto:

```env
DB_HOST=10.5.213.111
DB_PORT=5432
DB_NAME=db_bucarabus
DB_USER=dlastre
DB_PASSWORD=Remoto1050
```

### Iniciar el backend

```powershell
cd api
npm install
npm run dev
```

Deberías ver:
```
✅ BucaraBus API Server corriendo en http://localhost:3001
✅ Conexión a PostgreSQL exitosa (10.5.213.111:5432)
```

---

## 🎨 Configurar Frontend

El archivo `.env` en la raíz ya está configurado:

```env
VITE_API_URL=http://localhost:3001/api
VITE_WS_URL=http://localhost:3001
```

### Iniciar el frontend

```powershell
npm install
npm run dev
```

Luego abrir: **http://localhost:3002**

---

## 🔥 Troubleshooting

### Error: "psql: command not found"

**Solución:** PostgreSQL no está en el PATH

```powershell
# Agregar PostgreSQL al PATH temporalmente
$env:Path += ";C:\Program Files\PostgreSQL\14\bin"

# O instalar PostgreSQL desde:
# https://www.postgresql.org/download/windows/
```

### Error: "connection refused"

**Causas posibles:**
1. Firewall bloqueando puerto 5432
2. PostgreSQL no acepta conexiones remotas

**Solución:** Verificar conectividad

```powershell
Test-NetConnection -ComputerName 10.5.213.111 -Port 5432
```

### Error: "password authentication failed"

**Solución:** Verificar que la contraseña sea correcta

```powershell
# Probar conexión manual
psql -h 10.5.213.111 -U dlastre -d db_bucarabus
# Ingresar contraseña: Remoto1050
```

### Error: "database does not exist"

**Solución:** Crear la base de datos primero

```powershell
# Conectar como superusuario
psql -h 10.5.213.111 -U postgres

# Crear base de datos
CREATE DATABASE db_bucarabus;
GRANT ALL PRIVILEGES ON DATABASE db_bucarabus TO dlastre;
```

---

## 📊 Qué Instala el Script

1. **Esquema de base de datos** (`bd_bucarabus.sql`)
   - Tablas: users, roles, routes, buses, trips, drivers
   - Índices para optimización
   - Constraints (FK, CHECK, UNIQUE)
   - Datos iniciales (usuario sistema, roles)

2. **Funciones CREATE** (6 archivos)
   - `fun_create_user` - Crear usuarios
   - `fun_create_bus` - Crear buses
   - `fun_create_driver` - Crear conductores
   - `fun_create_route` - Crear rutas
   - `fun_create_trip` - Crear viajes
   - `fun_create_trips_batch` - Crear múltiples viajes

3. **Funciones UPDATE** (5 archivos)
   - `fun_update_user` - Actualizar usuarios
   - `fun_update_bus` - Actualizar buses
   - `fun_update_driver` - Actualizar conductores
   - `fun_update_route` - Actualizar rutas
   - `fun_update_trip` - Actualizar viajes

4. **Funciones DELETE** (3 archivos)
   - `fun_delete_driver` - Eliminar conductores
   - `fun_delete_route` - Eliminar rutas
   - `fun_delete_trip` - Eliminar viajes

5. **Funciones Especiales** (2 archivos)
   - `fun_assign_driver` - Asignar conductor a bus
   - `fun_toggle_bus_status` - Activar/desactivar buses

---

## 🎉 Próximos Pasos

1. ✅ Instalar base de datos (este documento)
2. ▶️ Configurar backend (ya hecho en `api/.env`)
3. ▶️ Iniciar backend (`cd api && npm run dev`)
4. ▶️ Configurar frontend (ya hecho en `.env`)
5. ▶️ Iniciar frontend (`npm run dev`)
6. ▶️ Abrir http://localhost:3002

---

## 📞 Ayuda

Si encuentras problemas:

1. Verifica que PostgreSQL esté corriendo en el servidor
2. Verifica que el puerto 5432 esté abierto
3. Prueba conexión manual con `psql`
4. Revisa los logs de PostgreSQL en el servidor

**Credential Summary:**
- Host: 10.5.213.111
- User: dlastre
- Password: Remoto1050
- Database: db_bucarabus

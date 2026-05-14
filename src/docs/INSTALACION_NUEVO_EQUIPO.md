# 🚍 Instalación de BucaraBUS en Nuevo Equipo

Guía paso a paso para instalar la base de datos y el sistema completo en un equipo nuevo.

---

## 📋 Requisitos Previos

### 1. Software Requerido
- [x] **PostgreSQL 14+** con PostGIS
- [x] **Node.js 18+** y npm
- [x] **Git** (opcional, para clonar el proyecto)

### 2. Verificar Instalaciones

```powershell
# Verificar PostgreSQL
psql --version

# Verificar Node.js
node --version
npm --version
```

---

## 🗄️ PASO 1: Instalar PostgreSQL

### Windows

1. Descargar PostgreSQL desde: https://www.postgresql.org/download/windows/
2. Durante la instalación:
   - Puerto: `5432` (por defecto)
   - Usuario: `postgres`
   - Contraseña: `[elegir una contraseña]`
   - **IMPORTANTE**: Marcar "Stack Builder" para instalar PostGIS

3. En Stack Builder:
   - Seleccionar tu instalación de PostgreSQL
   - Expandir "Spatial Extensions"
   - Marcar "PostGIS 3.x Bundle"
   - Instalar

### Verificar

```powershell
# Conectar a PostgreSQL
psql -U postgres

# Dentro de psql, verificar PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
\dx
# Deberías ver postgis en la lista
```

---

## 🔧 PASO 2: Crear Base de Datos y Usuario

```powershell
# Conectar como superusuario
psql -U postgres
```

Ejecutar estos comandos dentro de `psql`:

```sql
-- 1. Crear usuario
CREATE USER bucarabus_user WITH PASSWORD 'bucarabus2025';

-- 2. Crear base de datos
CREATE DATABASE bucarabus_db 
    WITH OWNER = bucarabus_user
    ENCODING = 'UTF8'
    LC_COLLATE = 'Spanish_Spain.1252'
    LC_CTYPE = 'Spanish_Spain.1252'
    TEMPLATE = template0;

-- 3. Conectar a la nueva base de datos
\c bucarabus_db

-- 4. Habilitar PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- 5. Dar permisos al usuario
GRANT ALL PRIVILEGES ON DATABASE bucarabus_db TO bucarabus_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO bucarabus_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO bucarabus_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO bucarabus_user;

-- 6. Permisos por defecto para objetos futuros
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO bucarabus_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO bucarabus_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO bucarabus_user;

-- 7. Salir
\q
```

---

## 📦 PASO 3: Copiar Archivos del Proyecto

### Opción A: Copiar carpeta completa

Copia toda la carpeta `vue-bucarabus` al nuevo equipo en:
```
C:\Users\[TuUsuario]\Documents\vue-bucarabus
```

### Opción B: Clonar desde Git

```powershell
cd C:\Users\[TuUsuario]\Documents
git clone [URL_DEL_REPOSITORIO] vue-bucarabus
cd vue-bucarabus
```

---

## 🗃️ PASO 4: Instalar Base de Datos y Funciones

### Método 1: Script SQL Automático (Recomendado)

```powershell
# Navegar a la carpeta de database
cd C:\Users\[TuUsuario]\Documents\vue-bucarabus\api\database

# Ejecutar deployment completo
psql -U bucarabus_user -d bucarabus_db -f deploy-all.sql
```

**Cuando pida contraseña**: Ingresa `bucarabus2025` (o la que hayas configurado)

### Método 2: Script PowerShell (Más control)

```powershell
cd C:\Users\[TuUsuario]\Documents\vue-bucarabus\api\database

# Ejecutar con parámetros por defecto
.\deploy-functions.ps1

# O especificar parámetros
.\deploy-functions.ps1 `
  -DbName "bucarabus_db" `
  -DbUser "bucarabus_user" `
  -DbHost "localhost" `
  -DbPort 5432
```

### Verificar Instalación

```powershell
# Conectar a la base de datos
psql -U bucarabus_user -d bucarabus_db

# Ver las tablas creadas
\dt

# Ver las funciones creadas
\df fun_*

# Ver datos de ejemplo
SELECT * FROM tab_users;
SELECT * FROM tab_routes;
SELECT * FROM tab_buses;

# Salir
\q
```

---

## 🔐 PASO 5: Configurar Backend (API)

### 5.1 Instalar dependencias

```powershell
cd C:\Users\[TuUsuario]\Documents\vue-bucarabus\api
npm install
```

### 5.2 Crear archivo `.env`

```powershell
# En la carpeta api/
Copy-Item .env.example .env
```

Editar `api/.env` con los datos de tu base de datos:

```env
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bucarabus_db
DB_USER=bucarabus_user
DB_PASSWORD=bucarabus2025

# Server Configuration
PORT=3001
NODE_ENV=development

# JWT Secret (generar uno único)
JWT_SECRET=tu_secreto_super_seguro_aqui_cambiar_en_produccion
```

### 5.3 Verificar conexión a base de datos

```powershell
# En la carpeta api/
node test-db.js
```

Deberías ver: `✅ Conexión exitosa a PostgreSQL`

---

## 🎨 PASO 6: Configurar Frontend (Vue)

### 6.1 Instalar dependencias

```powershell
cd C:\Users\[TuUsuario]\Documents\vue-bucarabus
npm install
```

### 6.2 Crear archivo `.env`

```powershell
# En la carpeta raíz vue-bucarabus/
Copy-Item .env.example .env
```

Editar `.env`:

```env
# API Backend URL
VITE_API_URL=http://localhost:3001/api

# WebSocket URL
VITE_WS_URL=http://localhost:3001

# Environment
VITE_ENV=development
```

---

## 🚀 PASO 7: Ejecutar la Aplicación

### Terminal 1: Backend (API)

```powershell
cd C:\Users\[TuUsuario]\Documents\vue-bucarabus\api
npm run dev
```

Deberías ver:
```
✅ BucaraBus API Server corriendo en http://localhost:3001
✅ Conexión a PostgreSQL exitosa
```

### Terminal 2: Frontend (Vue)

```powershell
cd C:\Users\[TuUsuario]\Documents\vue-bucarabus
npm run dev
```

Deberías ver:
```
VITE v5.x.x ready in XXX ms
➜ Local:   http://localhost:3002/
➜ Network: use --host to expose
```

---

## 🌐 PASO 8: Acceder a la Aplicación

Abre tu navegador en: **http://localhost:3002**

### Credenciales por defecto

- **Admin**:
  - Email: `admin@bucarabus.com`
  - Password: `admin123`

- **Conductor de prueba**:
  - Email: `conductor@bucarabus.com`
  - Password: `conductor123`

---

## ✅ Verificación Final

### Checklist de Funcionalidades

- [ ] Login funciona
- [ ] Se cargan las rutas en el mapa
- [ ] Se ven los buses en la flota
- [ ] Se pueden crear viajes/turnos
- [ ] WebSocket conecta (ver consola del navegador)
- [ ] No hay errores en consola

---

## 🔧 Troubleshooting

### Problema: "Error: connect ECONNREFUSED 127.0.0.1:5432"

**Solución**: PostgreSQL no está corriendo

```powershell
# Iniciar servicio de PostgreSQL
net start postgresql-x64-14
```

### Problema: "FATAL: password authentication failed"

**Solución**: Contraseña incorrecta en `.env`

1. Verificar contraseña en `api/.env`
2. O cambiar contraseña en PostgreSQL:

```sql
psql -U postgres
ALTER USER bucarabus_user WITH PASSWORD 'nueva_contraseña';
```

### Problema: "Error: No se pudo conectar al servidor"

**Solución**: Backend no está corriendo o puerto incorrecto

1. Verificar que `npm run dev` en `api/` esté corriendo
2. Verificar que `.env` del frontend tenga `VITE_API_URL=http://localhost:3001/api`
3. Recargar el navegador con Ctrl+F5

### Problema: "Failed to fetch routes"

**Solución**: Caché del navegador o variables de entorno

1. Presionar **Ctrl+Shift+Del** en el navegador
2. Borrar caché
3. Recargar con **Ctrl+F5**
4. O reiniciar servidor frontend después de cambiar `.env`

---

## 📚 Archivos Importantes

| Archivo | Ubicación | Propósito |
|---------|-----------|-----------|
| `database/deploy-all.sql` | `api/database/` | Instalar BD completa |
| `database/bd_bucarabus.sql` | `api/database/` | Esquema de tablas |
| `api/.env` | `api/` | Configuración backend |
| `.env` | raíz | Configuración frontend |
| `api/config/database.js` | `api/config/` | Conexión a PostgreSQL |

---

## 🎯 Próximos Pasos

1. **Cambiar contraseñas**: Usar contraseñas seguras en producción
2. **Crear usuarios**: Agregar conductores, administradores, etc.
3. **Configurar rutas**: Dibujar las rutas de tu ciudad
4. **Agregar buses**: Registrar la flota de buses
5. **Planificar turnos**: Crear horarios y asignar conductores

---

## 📞 Soporte

Si encuentras problemas:

1. Revisa la sección **Troubleshooting**
2. Verifica logs en consola del navegador (F12)
3. Revisa logs del backend en la terminal
4. Consulta la documentación en `api/database/README_DEPLOYMENT.md`

---

**¡Listo! 🎉 Tu sistema BucaraBUS está instalado y funcionando.**

# 🚌 BucaraBus - Integración con PostgreSQL + PostGIS

Sistema completo de gestión de rutas de transporte público con base de datos geoespacial.

---

## 📋 Stack Tecnológico

### **Frontend**
- Vue 3 + Vite
- Pinia (State Management)
- Vue Router
- Leaflet.js (Mapas)
- Axios (HTTP Client)

### **Backend**
- Node.js + Express
- PostgreSQL 12+
- PostGIS (Extensión geoespacial)
- pg (Node PostgreSQL driver)

---

## 🚀 Instalación

### **1. Requisitos Previos**

```bash
# Verificar versiones
node --version  # >= 18
npm --version   # >= 9
psql --version  # >= 12
```

---

### **2. Configurar PostgreSQL + PostGIS**

```bash
# Iniciar sesión en PostgreSQL
psql -U postgres

# Ejecutar los comandos SQL del archivo DATABASE_SETUP.md
# O ejecutar directamente:
psql -U postgres -f setup.sql
```

**Comandos principales:**

```sql
CREATE DATABASE bucarabus_db;
\c bucarabus_db
CREATE EXTENSION postgis;

-- Crear tablas (ver DATABASE_SETUP.md)
```

---

### **3. Configurar Backend API**

```bash
# Ir a la carpeta api
cd api

# Copiar archivo de configuración
copy .env.example .env

# Editar .env con tus credenciales de PostgreSQL
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=bucarabus_db
# DB_USER=bucarabus_user
# DB_PASSWORD=tu_password

# Instalar dependencias
npm install

# Iniciar servidor
npm run dev
```

El servidor API estará corriendo en `http://localhost:3001`

---

### **4. Configurar Frontend Vue**

```bash
# Volver a la carpeta principal
cd ..

# Copiar archivo de configuración
copy .env.example .env

# Verificar que VITE_API_URL apunte al backend
# VITE_API_URL=http://localhost:3001/api

# Instalar dependencias
npm install

# Iniciar aplicación
npm run dev
```

La aplicación estará corriendo en `http://localhost:3000`

---

## 📊 Arquitectura

```
┌─────────────────┐
│   Vue Frontend  │  http://localhost:3000
│   (Leaflet Map) │
└────────┬────────┘
         │ HTTP (Axios)
         ↓
┌─────────────────┐
│  Express API    │  http://localhost:3001
│  (REST Routes)  │
└────────┬────────┘
         │ SQL
         ↓
┌─────────────────┐
│   PostgreSQL    │  localhost:5432
│   + PostGIS     │
└─────────────────┘
```

---

## 🗺️ Endpoints API

### **Rutas**

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/routes` | Obtener todas las rutas |
| GET | `/api/routes/:id` | Obtener ruta específica |
| POST | `/api/routes` | Crear nueva ruta |
| PUT | `/api/routes/:id` | Actualizar ruta |
| DELETE | `/api/routes/:id` | Eliminar ruta |
| GET | `/api/routes/search?q=centro` | Buscar rutas |
| PATCH | `/api/routes/:id/visibility` | Alternar visibilidad |
| GET | `/api/routes/:id/distance` | Obtener distancia en km |
| POST | `/api/routes/:id/stops` | Agregar parada |
| POST | `/api/routes/:id/buses` | Asignar bus |

---

## 📝 Ejemplo de Uso

### **Crear Ruta desde el Frontend**

1. **Dibujar en el mapa:**
   - Ir a "Gestión de Rutas"
   - Click en "Nueva Ruta"
   - Hacer clic en el mapa para agregar puntos
   - Click en "Finalizar"

2. **Completar formulario:**
   ```javascript
   {
     id: "RUTA_04",
     name: "Ruta Oriente",
     color: "#10b981",
     fare: 3000,
     frequency: 20,
     description: "Ruta hacia el oriente de la ciudad",
     path: [
       [-73.122, 7.119],
       [-73.125, 7.122],
       [-73.128, 7.125]
     ]
   }
   ```

3. **Guardar:**
   - Click en "Guardar"
   - La ruta se guarda en PostgreSQL
   - Aparece automáticamente en el listado

---

## 🔍 Consultas SQL Útiles

### **Ver todas las rutas con geometría**

```sql
SELECT 
    id,
    name,
    color,
    ST_AsText(geometry) as path_wkt,
    ST_AsGeoJSON(geometry) as path_geojson
FROM routes;
```

### **Calcular distancia de ruta**

```sql
SELECT 
    id,
    name,
    ST_Length(ST_Transform(geometry, 3857)) / 1000 as distance_km
FROM routes
WHERE id = 'RUTA_01';
```

### **Buscar rutas cercanas a un punto**

```sql
SELECT 
    id,
    name,
    ST_Distance(
        ST_Transform(geometry, 3857),
        ST_Transform(ST_GeomFromText('POINT(-73.125 7.120)', 4326), 3857)
    ) / 1000 as distance_km
FROM routes
WHERE ST_DWithin(
    ST_Transform(geometry, 3857),
    ST_Transform(ST_GeomFromText('POINT(-73.125 7.120)', 4326), 3857),
    1000  -- 1km de radio
)
ORDER BY distance_km;
```

---

## 🧪 Testing de la API

### **Con curl:**

```bash
# Health check
curl http://localhost:3001/health

# Obtener todas las rutas
curl http://localhost:3001/api/routes

# Crear nueva ruta
curl -X POST http://localhost:3001/api/routes \
  -H "Content-Type: application/json" \
  -d '{
    "id": "RUTA_05",
    "name": "Ruta Test",
    "color": "#ff0000",
    "fare": 2500,
    "frequency": 15,
    "description": "Ruta de prueba",
    "path": [[-73.122, 7.119], [-73.125, 7.122]]
  }'

# Buscar rutas
curl http://localhost:3001/api/routes/search?q=centro

# Alternar visibilidad
curl -X PATCH http://localhost:3001/api/routes/RUTA_01/visibility
```

### **Con Postman:**

Importar colección desde `api/postman_collection.json`

---

## 🛠️ Troubleshooting

### **Error: "Cannot connect to database"**

```bash
# Verificar que PostgreSQL esté corriendo
sudo service postgresql status

# Verificar credenciales en .env
DB_USER=bucarabus_user
DB_PASSWORD=tu_password
```

### **Error: "PostGIS extension not found"**

```sql
-- Instalar PostGIS
CREATE EXTENSION postgis;

-- Verificar instalación
SELECT PostGIS_Version();
```

### **Error: "CORS policy"**

Verificar que `FRONTEND_URL` en el `.env` del backend coincida con la URL del frontend:

```env
FRONTEND_URL=http://localhost:3000
```

### **Error: "axios is not defined"**

```bash
# Instalar axios en el frontend
cd vue-bucarabus
npm install axios
```

---

## 📚 Documentación

- **PostgreSQL:** https://www.postgresql.org/docs/
- **PostGIS:** https://postgis.net/docs/
- **Leaflet.js:** https://leafletjs.com/reference.html
- **Vue 3:** https://vuejs.org/guide/
- **Express:** https://expressjs.com/

---

## 🔐 Seguridad

### **Producción:**

1. **Cambiar contraseñas:**
   ```sql
   ALTER USER bucarabus_user WITH PASSWORD 'password_super_seguro';
   ```

2. **Usar HTTPS**
3. **Agregar autenticación JWT**
4. **Validar inputs en backend**
5. **Usar variables de entorno**
6. **Rate limiting**

---

## 📦 Deployment

### **Backend (API):**

```bash
# Build
npm run build

# Start en producción
NODE_ENV=production npm start
```

### **Frontend (Vue):**

```bash
# Build para producción
npm run build

# Los archivos estarán en /dist
```

---

## 🎯 Próximas Mejoras

- [ ] Autenticación con JWT
- [ ] WebSockets para tracking en tiempo real
- [ ] Cache con Redis
- [ ] Pruebas unitarias (Jest)
- [ ] Pruebas E2E (Cypress)
- [ ] Docker Compose para deployment
- [ ] CI/CD con GitHub Actions
- [ ] Monitoring con Prometheus

---

## 📄 Licencia

MIT

---

## 👥 Contribuir

1. Fork el proyecto
2. Crear branch (`git checkout -b feature/nueva-caracteristica`)
3. Commit cambios (`git commit -m 'Agregar nueva característica'`)
4. Push al branch (`git push origin feature/nueva-caracteristica`)
5. Crear Pull Request

---

**¡Sistema completo y funcional! 🎉**

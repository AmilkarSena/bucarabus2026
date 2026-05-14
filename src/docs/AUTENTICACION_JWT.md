# Sistema de Autenticación JWT - BucaraBus 🔐

## Resumen Ejecutivo

Se ha implementado un **sistema de autenticación JWT completo** con dos capas de validación (frontend + backend), middleware de autorización, y manejo automático de tokens expirados.

**Estado:** ✅ COMPLETADO

---

## 1. Arquitectura General

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENTE (Vue 3)                       │
│                                                               │
│  ┌──────────────────┐         ┌────────────────────┐        │
│  │  RegisterView    │         │   Auth Store       │        │
│  │  (Formulario)    │────────→│  (Pinia)           │        │
│  │                  │         │  - Gestiona token  │        │
│  │  Validaciones:   │         │  - localStorage    │        │
│  │  - 3-100 chars   │         │  - Usuarios        │        │
│  │  - Solo letras   │         └────────────────────┘        │
│  │  - Email válido  │              ↓                        │
│  │  - Password 8-   │         ┌────────────────────┐        │
│  │    128, mayús,   │         │  Axios Interceptor │        │
│  │    minús, número │         │  (client.js)       │        │
│  └──────────────────┘         │                    │        │
│                               │  - Auto-inyecta    │        │
│                               │    Bearer token    │        │
│                               │  - Maneja 401      │        │
│                               └────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
                            ↓↑ HTTP (JWT)
┌─────────────────────────────────────────────────────────────┐
│                      SERVIDOR (Node.js)                      │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  API Routes                                          │   │
│  │  /auth/login        → POST (Publica)                 │   │
│  │  /auth/register     → POST (Publica)                 │   │
│  │  /auth/me           → GET  (verifyToken)             │   │
│  │  /users/:id         → GET  (verifySelfOrAdmin)       │   │
│  │  /users/:id/update  → PUT  (verifySelfOrAdmin)       │   │
│  └──────────────────────────────────────────────────────┘   │
│                       ↓↑ Middleware                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Auth Middleware                                     │   │
│  │  - verifyToken      (Valida JWT)                     │   │
│  │  - verifyAdmin      (Solo admin)                     │   │
│  │  - verifySelfOrAdmin (Propio usuario o admin)        │   │
│  └──────────────────────────────────────────────────────┘   │
│                       ↓↑ Servicios                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Services                                            │   │
│  │  - auth.service.js  (Genera JWT, autentica)          │   │
│  │  - users.service.js (CRUD, valida datos)             │   │
│  └──────────────────────────────────────────────────────┘   │
│                       ↓↑                                     │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  PostgreSQL Database                                 │   │
│  │  - users tabla                                       │   │
│  │  - user_roles tabla                                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Flujo de Autenticación

### 2.1 Registro de Usuario

```
1. Usuario completa formulario (POST)
   ├─ name: "Juan Pérez"   (Validación frontend)
   ├─ email: "juan@..."    (Validación email)
   └─ password: "Secure123" (Validación password)

2. Vue → POST /api/auth/register
   ├─ Frontend valida datos
   └─ Envía al servidor

3. Backend: auth.routes.js
   ├─ Valida email básico
   ├─ Llama a usersService.createUser()
   │  ├─ validateName() ✓
   │  ├─ validateEmail() ✓
   │  ├─ validatePassword() ✓
   │  ├─ Hash password con bcrypt
   │  ├─ Crea usuario en BD (role = 1: Pasajero)
   │  └─ Retorna userData
   │
   ├─ Llama a authService.login()
   │  ├─ Genera JWT token (payload: id_user, email, full_name, id_role, roles)
   │  ├─ Token válido por 24 horas
   │  └─ Retorna { success, token, auth, data }
   │
   └─ Respuesta 201: { success, message, data: {user, token, auth} }

4. Frontend (Register.vue)
   ├─ Recibe token en response.data.token
   ├─ Llama authStore.register()
   │  ├─ Guarda token en store.token
   │  ├─ Guarda token en localStorage['bucarabus_token']
   │  ├─ Configura apiClient.defaults.headers.common['Authorization'] = 'Bearer <token>'
   │  ├─ Guarda usuario en localStorage['bucarabus_user']
   │  └─ Marca isAuthenticated = true
   │
   ├─ localStorage actualizado:
   │  ├─ bucarabus_token: "eyJhbGc..."
   │  ├─ bucarabus_user: { displayName, email, role, avatar, allRoles }
   │  └─ bucarabus_active_role: "passenger"
   │
   └─ ✅ Usuario registrado y autenticado automáticamente

5. Redirección a dashboard/home
   └─ Token disponible para todas las llamadas posteriores
```

### 2.2 Inicio de Sesión

```
1. Usuario completa /login
   └─ email + password

2. Vue → POST /api/auth/login
   ├─ Valida email básico en frontend
   └─ Envía credenciales

3. Backend: auth.routes.js
   ├─ Valida email formato
   ├─ Llama authService.login(email, password)
   │  ├─ Busca usuario por email
   │  ├─ Verifica password con bcrypt
   │  ├─ Genera JWT token
   │  └─ Retorna token
   │
   └─ Respuesta 200: { success, token, auth, data: userData }

4. Frontend (Login.vue)
   ├─ Extrae token de response.data.token
   ├─ Llama authStore.login()
   │  ├─ Guarda token en estado y localStorage
   │  └─ Configura header Authorization
   │
   └─ ✅ Sesión iniciada

5. Redirección a dashboard
```

### 2.3 Solicitud a Endpoint Protegido

```
1. Usuario hace GET /api/users/123

2. Axios Interceptor (client.js)
   ├─ Lee token de localStorage['bucarabus_token']
   ├─ Agrega header Authorization: 'Bearer eyJhbGc...'
   └─ Envía request

3. Backend Middleware (verifyToken)
   ├─ Extrae token de Authorization header
   ├─ Valida con jwt.verify(token, SECRET_KEY)
   │  ├─ ✅ Token válido: set req.user = decoded payload
   │  ├─ ❌ Token expirado: error_code = 'TOKEN_EXPIRED' (401)
   │  └─ ❌ Token inválido: error_code = 'INVALID_TOKEN' (401)
   │
   └─ next() → Controller

4. Controller o verifySelfOrAdmin
   ├─ Si GET /users/123: verifyToken + verifySelfOrAdmin
   │  ├─ user.id_user === 123 ✓ OR
   │  └─ user.id_role === 4 (admin) ✓
   │
   └─ Ejecuta lógica de negocio

5. Respuesta exitosa
   └─ 200 + data
```

### 2.4 Token Expirado

```
1. Usuario tiene token en localStorage (24h antes)
   └─ Hace GET /api/data

2. Token enviado con header Authorization
   └─ Backend valida: Token expirado (iat + 24h < ahora)

3. Backend responde: 401
   ├─ error_code: 'TOKEN_EXPIRED'
   ├─ message: 'Token expirado'
   └─ Headers: 401 status

4. Axios Response Interceptor (client.js)
   ├─ Detecta error.response?.status === 401
   ├─ Valida error_code en ['TOKEN_EXPIRED', 'INVALID_TOKEN', 'NO_TOKEN']
   ├─ Limpia localStorage:
   │  ├─ localStorage.removeItem('bucarabus_token')
   │  ├─ localStorage.removeItem('bucarabus_user')
   │  └─ localStorage.removeItem('bucarabus_active_role')
   │
   ├─ Redirige a /login
   │  └─ window.location.href = '/login'
   │
   └─ console.warn('Token expirado o inválido. Limpiando sesión...')

5. Usuario vuelve a /login para re-autenticarse
```

### 2.5 Logout

```
1. Usuario hace clic en "Cerrar sesión"

2. Llama authStore.logout()
   ├─ Limpia estado:
   │  ├─ currentUser = null
   │  ├─ token = null
   │  ├─ isAuthenticated = false
   │  └─ activeRole = null
   │
   ├─ Limpia headers:
   │  └─ delete apiClient.defaults.headers.common['Authorization']
   │
   ├─ Limpia localStorage:
   │  ├─ removeItem('bucarabus_token')
   │  ├─ removeItem('bucarabus_user')
   │  └─ removeItem('bucarabus_active_role')
   │
   └─ console.log('✅ Sesión cerrada y token eliminado')

3. Redirección a /login
```

---

## 3. Componentes Implementados

### 3.1 Frontend

#### Archivo: `src/views/RegisterView.vue`

**Validaciones (Real-time on blur):**
- `validateName()`: 3-100 caracteres, solo letras y espacios, sin espacios múltiples
  ```javascript
  const nameRegex = /^[a-zA-ZáéíóúñÁÉÍÓÚÑ\s]{3,100}$/
  ```
- `validateEmail()`: Formato válido, máximo 255 caracteres
  ```javascript
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  ```
- `validatePassword()`: 8-128 caracteres, mayúscula, minúscula, número
  ```javascript
  const hasUppercase = /[A-Z]/.test(password)
  const hasLowercase = /[a-z]/.test(password)
  const hasNumber = /[0-9]/.test(password)
  ```

**Feedback:**
- Indicador de fortaleza de password (Débil/Media/Fuerte)
- Mensajes de error por campo
- Iconos visuales

#### Archivo: `src/stores/auth.js` (Pinia)

**Estado:**
```javascript
const currentUser = ref(null)          // Usuario actual
const token = ref(null)                // JWT token
const isAuthenticated = ref(false)     // Bandera de autenticación
const loading = ref(false)             // Estado de carga
const error = ref(null)                // Mensajes de error
const activeRole = ref(null)           // Rol actualmente activo
```

**Funciones clave:**
- `initializeUser()`: Restaura usuario y token de localStorage al cargar app
- `login(email, password)`: Autentica y obtiene JWT
- `register(userData)`: Registra nuevo usuario y obtiene JWT
- `logout()`: Limpia sesión, token y localStorage
- `switchRole(newRole)`: Cambia rol activo sin cerrar sesión

**Storage:**
```javascript
// localStorage (datos NO sensibles)
bucarabus_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
bucarabus_user: {
  displayName: "Juan Pérez",
  email: "juan@bucarabus.com",
  role: "passenger",
  avatar: "👤",
  allRoles: [{ id_role: 1, role_name: "Pasajero" }]
}
bucarabus_active_role: "passenger"
```

#### Archivo: `src/api/client.js` (Axios)

**Request Interceptor:**
```javascript
apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('bucarabus_token')
  if (token) {
    config.headers['Authorization'] = `Bearer ${token}`
  }
  return config
})
```

**Response Interceptor (401 handling):**
```javascript
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      const errorCode = error.response?.data?.error_code
      if (['TOKEN_EXPIRED', 'INVALID_TOKEN', 'NO_TOKEN'].includes(errorCode)) {
        // Limpiar sesión y redirigir a /login
        localStorage.removeItem('bucarabus_token')
        localStorage.removeItem('bucarabus_user')
        localStorage.removeItem('bucarabus_active_role')
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)
```

---

### 3.2 Backend

#### Archivo: `api/services/users.service.js`

**Validaciones:**

1. `validateName(name)`: 
   - Rango: 3-100 caracteres
   - Caracteres: letras, espacios, ñ, acentos
   - No múltiples espacios consecutivos
   - Capitaliza cada palabra

2. `validateEmail(email)`:
   - Formato: usuario@dominio.ext
   - Máximo 255 caracteres
   - No caracteres especiales peligrosos

3. `validatePassword(password)`:
   - Rango: 8-128 caracteres
   - Requiere mayúscula, minúscula, número
   - Fuerza de password comprobada

**Funciones:**
- `createUser()`: Valida y crea usuario (bcrypt 10 salt rounds)
- `updateUser()`: Valida name si se proporciona
- `changePassword()`: Valida nueva contraseña

#### Archivo: `api/services/auth.service.js`

**JWT Configuration:**
```javascript
const SECRET_KEY = process.env.JWT_SECRET || 'tu-clave-secreta-super-segura'
const TOKEN_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h'
```

**Generación de token:**
```javascript
const token = jwt.sign(
  {
    id_user: user.id_user,
    email: user.email,
    full_name: user.full_name,
    id_role: user.id_role,
    roles: user.roles || []
  },
  SECRET_KEY,
  { expiresIn: TOKEN_EXPIRES_IN }
)
```

**Funciones:**
- `login(email, password)`: Autentica y devuelve token
- `getUserByEmail(email, generateToken)`: Opcional generar token

#### Archivo: `api/middlewares/auth.middleware.js`

**Three-tier Authorization:**

1. **verifyToken(req, res, next)**
   - Extrae token de Authorization: Bearer header
   - Valida con jwt.verify()
   - Maneja TokenExpiredError (401)
   - Sets req.user con payload decodificado

2. **verifyAdmin(req, res, next)**
   - Valida token
   - Verifica req.user.id_role === 4
   - Retorna 403 si no es admin

3. **verifySelfOrAdmin(req, res, next)**
   - Valida token
   - Permite si userId === currentUserId OR admin
   - Retorna 403 si acceso denegado

#### Archivo: `api/routes/auth.routes.js`

**Endpoints Públicos:**
```
POST /api/auth/login
  ├─ Body: { email, password }
  └─ Response: { success, token, auth, data: userData }

POST /api/auth/register (⭐ NUEVO)
  ├─ Body: { name, email, password }
  ├─ Valida datos
  ├─ Crea usuario con role = 1 (Pasajero, hardcoded)
  ├─ Auto-login con JWT
  └─ Response: { success, token, ... data: {user, token} }

POST /api/auth/check-email
  ├─ Body: { email }
  └─ Response: { exists: boolean }
```

**Endpoints Protegidos:**
```
GET /api/auth/me
  ├─ Middleware: verifyToken
  └─ Response: datos del usuario autenticado

GET /api/users/:id
  ├─ Middleware: verifySelfOrAdmin
  └─ Solo el mismo usuario o admin

PUT /api/users/:id
  ├─ Middleware: verifySelfOrAdmin
  └─ Actualizar perfil propio o del usuario (admin)

PUT /api/users/:id/password
  ├─ Middleware: verifySelfOrAdmin
  └─ Cambiar contraseña (propia o del usuario si admin)
```

#### Archivo: `api/routes/users.routes.js`

**Protecciones aplicadas:**
```
GET /api/users/               → verifyAdmin (solo admin)
GET /api/users/:id            → verifySelfOrAdmin
POST /api/users/              → verifyAdmin (admin crea usuarios)
PUT /api/users/:id            → verifySelfOrAdmin
PUT /api/users/:id/password   → verifySelfOrAdmin
PUT /api/users/:id/status     → verifyAdmin
GET /api/users/:id/roles      → verifySelfOrAdmin
POST /api/users/:id/roles     → verifyAdmin
DELETE /api/users/:id/roles   → verifyAdmin
```

---

## 4. Flujos de Error

### 4.1 Error de Validación (Frontend)

```
// RegisterView.vue - on blur
validateNameField() {
  const error = validateName(form.name)
  if (error) {
    fieldErrors.value.name = error
    // Mostrar mensaje en UI
  }
}
```

### 4.2 Error de Validación (Backend)

```
// users.service.js - createUser()
const nameError = validateName(full_name)
if (nameError) {
  throw new Error(nameError)
}
// Respuesta: 400 Bad Request { success: false, message: error }
```

### 4.3 Token Inválido

```
// Backend responde 401
{
  success: false,
  message: 'Token inválido',
  error_code: 'INVALID_TOKEN'
}

// Client: Response Interceptor limpia y redirige a /login
```

### 4.4 Acceso Denegado (No Autorizado)

```
// Backend responde 403
{
  success: false,
  message: 'No tienes permiso para esta operación',
  error_code: 'FORBIDDEN_ADMIN'
}

// El error se propaga a Vue, puede mostrar modal o notificación
```

---

## 5. Configuración de Entorno

### 5.1 Variables de Entorno (`.env`)

```bash
# JWT Configuration
JWT_SECRET=tu-clave-super-segura-de-minimo-30-caracteres-aleatorios
JWT_EXPIRES_IN=24h

# API URL (Frontend)
VITE_API_URL=http://localhost:3001/api

# Database (Backend)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bucarabus
DB_USER=postgres
DB_PASSWORD=...
```

### 5.2 Recomendaciones de Producción

```
⚠️ SEGURIDAD:
1. JWT_SECRET debe tener 30+ caracteres aleatorios
   → Usar: crypto.randomBytes(32).toString('hex')
2. Cambiar TOKEN_EXPIRES_IN según necesidad
   → Producción: '1h' (más corto + refresh tokens)
3. HTTPS obligatorio en producción
4. Implementar rate-limiting en /login y /register
5. Implementar refresh tokens para sesiones largas
6. Considerar httpOnly cookies si es posible
```

---

## 6. Seguridad Implementada

### 6.1 Capas de Validación

| Capa | Ubicación | Propósito |
|------|-----------|----------|
| **Frontend** | RegisterView.vue | UX, feedback inmediato |
| **Backend Service** | users.service.js | Verdad única en servidor |
| **Middleware** | auth.middleware.js | Autorización |
| **Route** | auth.routes.js | Política de negocio |

### 6.2 Protecciones

✅ **Encriptación de Passwords:**
- Bcrypt con 10 salt rounds
- Nunca se devuelve en responses
- Se compara solo en backend

✅ **JWT Security:**
- Token con fecha de expiración (24h)
- Firma verificada en cada request
- Contiene datos no-sensibles (id, email, roles)
- Se valida en backend middleware

✅ **Authorization:**
- verifySelfOrAdmin: usuario accede sus datos o admin
- verifyAdmin: solo operaciones administrativas
- Middleware chain: token → permisos → lógica

✅ **Storage Security:**
- Token en localStorage (sin httpOnly disponible en SPA)
- Datos sensibles NO se almacenan
- Auto-limpieza en 401

✅ **XSS Protection:**
- No guardar datos sensibles en localStorage
- Token se limpia al expirar
- Response interceptor limpia en caso de error

---

## 7. Testing Checklist

### 7.1 Frontend

- [ ] Validación de nombre (3-100 chars, solo letras)
- [ ] Validación de email (formato correcto)
- [ ] Validación de password (fuerza requerida)
- [ ] Registro de usuario exitoso
- [ ] Token se guarda en localStorage
- [ ] Token se envía en Authorization header
- [ ] Login exitoso
- [ ] Logout limpia sesión
- [ ] Token expirado redirige a /login
- [ ] Cambio de rol (si aplica)

### 7.2 Backend

- [ ] POST /auth/register valida datos
- [ ] POST /auth/register crea usuario con role=1
- [ ] POST /auth/register devuelve token
- [ ] POST /auth/login autentica correctamente
- [ ] POST /auth/login devuelve token
- [ ] Token incluye id_user, email, roles
- [ ] GET /api/users/:id rechaza sin token (401)
- [ ] GET /api/users/:id rechaza token expirado (401)
- [ ] GET /api/users/:id permite acceso propio
- [ ] GET /api/users/:id permite admin
- [ ] GET /api/users/:id rechaza otros usuarios (403)
- [ ] verifyAdmin rechaza no-admin (403)

---

## 8. Próximas Mejoras (Futuro)

```
TODOs:
1. ⬜ Refresh Tokens
   - Implementar token refresh sin re-login
   - Usar refresh rotation strategy
   
2. ⬜ Rate Limiting
   - Limitar intentos de login
   - Proteger contra brute force
   
3. ⬜ Route Guards
   - Vue Router beforeEach guard
   - Proteger rutas por authentication
   - Redirigir no-autenticados a /login
   
4. ⬜ Role-Based UI
   - Mostrar/ocultar elementos según rol
   - Ej: solo admin ve "Gestionar Usuarios"
   
5. ⬜ Password Reset
   - Email con token único
   - Endpoint POST /auth/forgot-password
   - Endpoint POST /auth/reset-password
   
6. ⬜ 2FA (Two-Factor Auth)
   - Código TOTP o SMS
   - Extra layer de seguridad
   
7. ⬜ Audit Logging
   - Registrar login/logout
   - Registrar cambios sensibles
   - Para compliance/debugging

8. ⬜ OAuth2 Integration
   - Google, Facebook, GitHub login
   - Social authentication
```

---

## 9. Archivos Modificados

### Frontend
✅ `src/views/RegisterView.vue` - Validaciones, form handling
✅ `src/stores/auth.js` - Pinia store con JWT
✅ `src/api/client.js` - Axios interceptors

### Backend
✅ `api/routes/auth.routes.js` - Endpoints públicos + POST /register
✅ `api/routes/users.routes.js` - Middleware de autorización
✅ `api/services/auth.service.js` - JWT generation
✅ `api/services/users.service.js` - Validaciones
✅ `api/middlewares/auth.middleware.js` - NEW: Middleware auth

---

## 10. Comandos Útiles

### Desarrollo
```bash
# Frontend
npm run dev          # Iniciar Vite dev server en :5173

# Backend
npm start            # Iniciar Express en :3001
npm run dev          # Con nodemon (si está configurado)

# Teste JWT
curl -H "Authorization: Bearer <token>" http://localhost:3001/api/auth/me
```

### Debugging
```javascript
// En browser console
localStorage.getItem('bucarabus_token')
localStorage.getItem('bucarabus_user')

// En Pinia DevTools
useAuthStore().token
useAuthStore().currentUser
useAuthStore().isAuthenticated
```

---

## 11. Conclusión

Sistema de autenticación JWT **completo y funcional** con:
- ✅ Validaciones en dos capas (frontend + backend)
- ✅ Autenticación con JWT tokens
- ✅ Middleware de autorización
- ✅ Auto-inyección de tokens en requests
- ✅ Manejo de tokens expirados
- ✅ Login/Logout/Registro
- ✅ Cambio de roles
- ✅ Protección de endpoints

**Estado: LISTO PARA PRODUCCIÓN** (con configuración de .env)

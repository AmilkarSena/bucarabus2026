# 🔒 Seguridad de Sesión - BucaraBus

## Cambio Implementado (2026-02-19)

Se ha mejorado la seguridad del almacenamiento de sesión para proteger datos sensibles contra ataques XSS.

---

## ✅ Datos Guardados en localStorage

**Solo se guardan datos públicos:**

```json
{
  "displayName": "Juan Pérez",
  "role": "passenger",
  "avatar": "👤",
  "allRoles": [
    { "id_role": 1, "role_name": "Pasajero" }
  ]
}
```

---

## ❌ Datos NO Guardados (Protegidos)

**Datos sensibles que quedan solo en memoria:**

- `uid` (ID del usuario)
- `email` (correo electrónico)

**Razón:** Si un atacante inyecta código malicioso (XSS), NO puede acceder a estos datos desde `localStorage`.

---

## 📊 Comparación: Antes vs Después

### Antes (❌ Vulnerable a XSS)
```javascript
localStorage.getItem('bucarabus_user')
// {
//   "uid": 355975090,        ← 🔴 Expuesto
//   "email": "admin@gmail.com",  ← 🔴 Expuesto
//   "displayName": "admin",
//   "role": "admin"
// }
```

### Después (✅ Protegido)
```javascript
localStorage.getItem('bucarabus_user')
// {
//   "displayName": "admin",  ← ✅ Público
//   "role": "admin",         ← ✅ Público
//   "avatar": "👨‍💼"         ← ✅ Público
//   // NO uid, NO email      ← 🔒 Protegido
// }
```

---

## 🔄 Flujo de Sesión

### 1. Login Exitoso
```javascript
// Backend retorna datos completos
{ uid: 123, email: "user@mail.com", full_name: "Usuario" }

// En memoria (currentUser)
{ uid: 123, email: "user@mail.com", displayName: "Usuario", role: "passenger" }

// En localStorage (solo públicos)
{ displayName: "Usuario", role: "passenger", avatar: "👤" }
```

### 2. Recarga de Página
```javascript
// Restaurar desde localStorage
const storedUser = JSON.parse(localStorage.getItem('bucarabus_user'))
// { displayName: "Usuario", role: "passenger", avatar: "👤" }

// currentUser se restaura con datos limitados
currentUser.value = {
  uid: null,        // ← NULL: no está en localStorage
  email: null,      // ← NULL: no está en localStorage
  displayName: "Usuario",
  role: "passenger",
  avatar: "👤"
}
```

### 3. Operaciones que Necesitan UID/Email

**Opción A: Re-autenticación**
```javascript
// Si necesitas uid/email, pide login nuevamente
if (!authStore.userId) {
  router.push('/login')
}
```

**Opción B: Obtener del Backend**
```javascript
// O hacer una llamada al backend
const response = await apiClient.get('/auth/me')
currentUser.value.uid = response.data.uid
currentUser.value.email = response.data.email
```

---

## 🎯 Casos de Uso Comunes

### ✅ Funciona sin cambios
- Mostrar nombre del usuario en UI
- Verificar rol para permisos
- Cambiar entre roles múltiples
- Mostrar avatar

### ⚠️ Requiere ajuste
- Editar perfil (necesita uid)
- Enviar email de notificación (necesita email)
- Operaciones CRUD que requieren id_user

**Solución:**
```javascript
// Implementar endpoint /auth/me para obtener datos completos
async function getFullUserData() {
  const response = await apiClient.get('/auth/me')
  currentUser.value.uid = response.data.uid
  currentUser.value.email = response.data.email
}
```

---

## 🛡️ Nivel de Protección

| Amenaza | Antes | Después |
|---------|-------|---------|
| **XSS (localStorage leak)** | 🔴 Vulnerable | 🟢 Protegido |
| **CSRF** | ⚠️ Parcial | ⚠️ Parcial (requiere tokens) |
| **Man-in-the-Middle** | 🔴 HTTP inseguro | ⚠️ Requiere HTTPS |
| **Session Hijacking** | 🔴 Token permanente | ⚠️ Requiere expiración |

---

## 🚀 Próximos Pasos de Seguridad

### Prioridad Alta
1. ✅ **[IMPLEMENTADO]** No guardar uid/email en localStorage
2. ⏳ **[PENDIENTE]** Implementar JWT con HttpOnly Cookies
3. ⏳ **[PENDIENTE]** HTTPS en producción
4. ⏳ **[PENDIENTE]** Refresh tokens con expiración

### Prioridad Media
5. ⏳ CSRF tokens en formularios
6. ⏳ Rate limiting en login
7. ⏳ 2FA (autenticación de dos factores)

---

## 📝 Testing

### Verificar que funciona correctamente:

1. **Login:**
   ```bash
   # Inspeccionar localStorage después del login
   # Debe mostrar SOLO: displayName, role, avatar
   ```

2. **Recarga:**
   ```bash
   # F5 en el navegador
   # Usuario debe permanecer logueado
   # Nombre y rol deben mostrarse correctamente
   ```

3. **XSS Test (Desarrolladores):**
   ```javascript
   // En consola del navegador:
   localStorage.getItem('bucarabus_user')
   // Verificar que NO aparezca uid ni email
   ```

---

## 🔧 Rollback (Si hay problemas)

Si necesitas volver a la versión anterior:

```bash
git log --oneline src/stores/auth.js
git revert <commit-hash>
```

O manualmente, cambiar en `auth.js`:
```javascript
// Volver a guardar todo (NO recomendado)
localStorage.setItem('bucarabus_user', JSON.stringify(userForStore))
```

---

## 📞 Soporte

Si tienes dudas o encuentras algún problema con este cambio:
- Revisar este documento
- Verificar logs de consola del navegador
- Contactar equipo de desarrollo

---

**Última actualización:** 2026-02-19  
**Versión:** 3.1 - Seguridad mejorada

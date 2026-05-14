# fun_create_user v3.0 - IDs Secuenciales

## 📋 Resumen de Cambios

### ¿Qué cambió?

**Versión anterior (v2.0):**
- Generaba IDs usando: `(timestamp - epoch_2025) * 10 + random`
- Producía IDs como: 357727599 (10 dígitos)
- **PROBLEMA:** IDs más pequeños que el usuario del sistema (1735689600)
- Dependía de sincronización de reloj

**Versión actual (v3.0):**
- Genera IDs secuenciales: `MAX(id_user) + 1`
- Produce IDs como: 1, 2, 3, 4... (o continúa desde el último)
- **VENTAJAS:**
  - ✅ Simple y predecible
  - ✅ No depende de reloj del servidor
  - ✅ Siempre monotónicamente creciente
  - ✅ Fácil de entender y debuggear

## 🚀 Cómo Desplegar

### Opción 1: Servidor REMOTO (10.5.213.111)

```powershell
cd api\database
.\deploy-fun_create_user-remoto.ps1
```

### Opción 2: Servidor LOCAL (localhost)

```powershell
cd api\database
.\deploy-fun_create_user-local.ps1
```

### Opción 3: Manual en pgAdmin

1. Abrir pgAdmin
2. Conectar a la base de datos `db_bucarabus`
3. Abrir el archivo `deploy-fun_create_user-v3.sql`
4. Ejecutar (F5)

## 🧪 Cómo Probar

### Paso 1: Generar un hash bcrypt

```powershell
cd api
node -e "const bcrypt = require('bcrypt'); bcrypt.hash('Admin123', 10).then(h => console.log(h));"
```

**Ejemplo de salida:**
```
$2b$10$abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ
```

### Paso 2: Crear un usuario en pgAdmin

```sql
SELECT * FROM fun_create_user(
  'admin@bucarabus.local',
  '$2b$10$abcdefghij...',  -- Hash del paso anterior
  'Administrador',
  1735689600,  -- ID del usuario sistema
  NULL         -- Sin avatar
);
```

**Resultado esperado:**
```
success | msg                                     | error_code | id_user
--------+-----------------------------------------+------------+---------
TRUE    | Usuario creado exitosamente con rol... | NULL       | 1735689601
```

### Paso 3: Verificar el usuario creado

```sql
SELECT 
  u.id_user,
  u.email,
  u.full_name,
  r.role_name,
  u.created_at,
  u.is_active
FROM tab_users u
JOIN tab_user_roles ur ON u.id_user = ur.id_user
JOIN tab_roles r ON ur.id_role = r.id_role
WHERE u.email = 'admin@bucarabus.local';
```

## 📝 Notas Importantes

1. **Orden de parámetros correcto:**
   ```sql
   fun_create_user(
     email,         -- VARCHAR (320)
     password_hash, -- VARCHAR (60) - bcrypt
     full_name,     -- VARCHAR (100)
     user_create,   -- INTEGER - ID del creador
     avatar_url     -- VARCHAR (500) - OPCIONAL
   )
   ```

2. **El password_hash DEBE:**
   - Tener exactamente 60 caracteres
   - Ser generado con bcrypt
   - Comenzar con `$2a$`, `$2b$` o `$2y$`

3. **El email DEBE:**
   - Ser único (no duplicado)
   - Tener formato válido: usuario@dominio.com
   - Entre 5 y 320 caracteres

4. **El nombre DEBE:**
   - Tener al menos 2 caracteres
   - Máximo 100 caracteres
   - Solo letras, espacios, guiones y apóstrofes
   - Permite acentos: José, María, etc.

## 🔧 Solución de Problemas

### Error: "El usuario creador no existe"

El ID del usuario creador no existe en la base de datos. Verifica que exista:

```sql
SELECT id_user, email FROM tab_users WHERE id_user = 1735689600;
```

Si no existe, créalo primero usando el script `crear-usuario-sistema.sql`.

### Error: "El email ya está registrado"

El email ya existe en la base de datos. Usa otro email o elimina el existente:

```sql
SELECT id_user, email FROM tab_users WHERE email = 'tu@email.com';
```

### Error: "Password hash inválido"

El hash no tiene 60 caracteres o no tiene formato bcrypt. Genera uno nuevo:

```powershell
node -e "const bcrypt = require('bcrypt'); bcrypt.hash('TuPassword', 10).then(h => console.log('Hash:', h, 'Longitud:', h.length));"
```

## 📊 Comparación de Versiones

| Aspecto | v2.0 (Timestamp) | v3.0 (Secuencial) |
|---------|------------------|-------------------|
| ID generado | 357727599 | 1735689601 |
| Algoritmo | (epoch-2025)*10+random | MAX(id)+1 |
| Depende de reloj | ✅ Sí | ❌ No |
| Colisiones posibles | ✅ Sí (reloj desincronizado) | ❌ No |
| Complejidad | 🔴 Alta | 🟢 Baja |
| Mantenibilidad | 🔴 Difícil | 🟢 Fácil |

## 🎯 Próximos Pasos

1. ✅ Desplegar función en servidor remoto
2. ✅ Desplegar función en servidor local
3. ⏳ Crear usuario administrador
4. ⏳ Probar login desde la aplicación
5. ⏳ Actualizar backend si es necesario

## 📞 Soporte

Si encuentras algún problema, revisa:

1. Logs de PostgreSQL
2. Logs del backend (consola donde corre `npm run dev`)
3. Network tab del navegador (DevTools)
4. Verifica que el backend esté usando la versión correcta de la función

---

**Versión:** 3.0  
**Fecha:** 2026-02-18  
**Autor:** Sistema Bucarabus

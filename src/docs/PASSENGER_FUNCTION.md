# Sistema de Pasajeros - Función Almacenada

## 📋 Resumen

La creación de pasajeros ahora utiliza una **función almacenada en PostgreSQL** (`fun_create_passenger`) que centraliza toda la lógica de validación y generación de ID.

## ✨ Ventajas

### 1. **Seguridad de ID**
- El ID se genera usando `EXTRACT(EPOCH FROM NOW())` de PostgreSQL
- **Inmune a manipulación del reloj del servidor de aplicación**
- **Validación estricta**: Garantiza que `nuevo_id > MAX(id)` existente
  - Si NO es mayor → **ERROR CRÍTICO** - Reloj no sincronizado
  - Fuerza a resolver problemas de sincronización NTP
  - No oculta problemas graves del sistema
  - Mantiene integridad del diseño (IDs con significado temporal)
- **Protección multicapa**:
  - Usa reloj de PostgreSQL (no Node.js)
  - Falla ruidosamente si el reloj está mal configurado
  - PRIMARY KEY como última barrera contra duplicados
- PostgreSQL es la única fuente de verdad para timestamps
- **En producción con NTP correcto, esto nunca debería fallar**

### 2. **Validaciones Centralizadas**
Todas las validaciones en un solo lugar (orden optimizado):
1. ✅ **Validaciones de formato** (rápidas, sin BD):
   - Nombre: longitud (2-100), caracteres permitidos
   - Email: formato, longitud
   - Password hash: formato bcrypt válido (60 caracteres)
   - Avatar URL: formato y longitud (opcional)
2. ✅ **Validaciones que requieren BD** (lentas, I/O):
   - Email: verificar que no exista (unicidad)
3. ✅ **Generación de ID**: solo si todo pasó
4. ✅ **INSERT**: transacción atómica

**Ventaja:** Evita consultas a la BD si los datos tienen formato inválido

### 3. **Transaccionalidad**
- Todo en una sola transacción atómica
- Si falla cualquier validación, no se inserta nada
- Mensajes de error descriptivos

### 4. **Portabilidad Mantenida**
- La función usa SQL estándar (EXTRACT, RANDOM, etc.)
- Compatible con PostgreSQL 9.6+
- Fácil de migrar a MySQL/MariaDB con ajustes menores

## 🗑️ Campo `phone` Eliminado

### ¿Por qué?
- No esencial para app de transporte público
- Usuarios pueden preferir no compartir su número
- Simplifica registro y mejora privacidad
- El email es suficiente para autenticación

### Si necesitas contactar usuarios
✉️ Usa el campo `email` que es obligatorio

## 🔧 Instalación

### 1. Crear la tabla (si es nueva base de datos)
```bash
psql -U postgres -d bd_bucarabus -f api/database/tab_passengers.sql
```

### 2. Crear la función almacenada
```bash
psql -U postgres -d bd_bucarabus -f api/database/fun_create_passenger.sql
```

### 3. Migrar base de datos existente (si ya tienes passengers)
```bash
psql -U postgres -d bd_bucarabus -f api/database/migrate-remove-phone.sql
```

### 4. Instalar bcrypt
```bash
cd api
npm install bcrypt
```

## 📝 Uso

### Desde Node.js (servicio actualizado)
```javascript
import { createPassenger } from './services/passengers.service.js'

const result = await createPassenger({
  email: 'usuario@email.com',
  password: 'miPassword123',  // Mínimo 8 caracteres
  full_name: 'Juan Pérez',
  avatar_url: 'https://example.com/avatar.jpg'  // Opcional
})

if (result.success) {
  console.log('Usuario creado:', result.data)
  // result.data = { id, email, full_name, created_at }
} else {
  console.error('Error:', result.error)
}
```

### Directamente en PostgreSQL
```sql
-- Crear pasajero básico
SELECT * FROM fun_create_passenger(
  'maria@email.com',
  '$2b$10$abc...',  -- hash bcrypt
  'María García'
);

-- Con avatar
SELECT * FROM fun_create_passenger(
  'juan@email.com',
  '$2b$10$xyz...',
  'Juan Pérez',
  'https://example.com/avatar.jpg'
);
```

## ✅ Validaciones Implementadas

### Email
- ✅ Longitud: 5-255 caracteres
- ✅ Formato: `usuario@dominio.com`
- ✅ Unicidad: no puede existir dos veces
- ✅ Conversión automática a minúsculas

### Nombre
- ✅ Longitud: 2-100 caracteres
- ✅ Caracteres permitidos:
  - Letras (a-z, A-Z)
  - Acentos (á, é, í, ó, ú, ñ, ü)
  - Espacios
  - Guiones (-)
  - Apóstrofes (')
- ✅ Al menos una letra
- ✅ Espacios múltiples normalizados
- ❌ NO permite: números, símbolos (@, #, $, etc.)

**Nombres válidos:**
- ✅ Juan Pérez
- ✅ María José García
- ✅ O'Connor
- ✅ García-Martínez
- ✅ José Ángel

**Nombres inválidos:**
- ❌ User123
- ❌ @Juan
- ❌ Test#User
- ❌ J (muy corto)

### Password Hash
- ✅ Exactamente 60 caracteres
- ✅ Formato bcrypt: `$2a$10$...` o `$2b$10$...`
- ✅ Validación del patrón bcrypt completo

### Avatar URL
- ✅ Máximo 500 caracteres
- ✅ Debe comenzar con `http://` o `https://`
- ✅ Opcional (puede ser NULL)

### ID
- ✅ Generado automáticamente (timestamp + random)
- ✅ Tipo INTEGER (4 bytes)
- ✅ Único con reintentos (hasta 3 intentos si colisión)
- ✅ Inmune a manipulación del reloj del servidor

## 🆔 Formato del ID

```
Timestamp (segundos) * 1000 + Random (0-999)
```

**Ejemplo:**
- NOW() = 2026-02-15 10:30:45 UTC
- Timestamp = 1739617845 segundos
- Random = 234
- ID = 1739617845000 + 234 = **1739617845234**

## 🔒 Seguridad

### Contraseñas
- ✅ Hasheadas con bcrypt (SALT_ROUNDS=10)
- ✅ NUNCA se guarda la contraseña en texto plano
- ✅ NUNCA se devuelve el hash en las respuestas
- ✅ Mínimo 8 caracteres

### Clock Manipulation
- ✅ Usa NOW() de PostgreSQL, no Date.now() de Node.js
- ✅ Inmune a cambios en el reloj del servidor de aplicación
- ✅ PostgreSQL típicamente sincronizado con NTP

### Inyección SQL
- ✅ Todos los parámetros parametrizados ($1, $2, etc.)
- ✅ Validaciones con expresiones regulares seguras
- ✅ Función encapsula toda la lógica

## 📊 Mensajes de Error

La función retorna errores descriptivos:

**Validaciones de datos:**
```
❌ Nombre debe tener al menos 2 caracteres
❌ Nombre no puede exceder 100 caracteres
❌ Nombre contiene caracteres no permitidos
❌ Email debe tener entre 5 y 255 caracteres
❌ Email tiene formato inválido
❌ Email ya está registrado
❌ Password hash inválido (debe ser bcrypt hash de 60 caracteres)
❌ Avatar URL debe comenzar con http:// o https://
```

**Error crítico del sistema:**
```
❌ Error crítico: El reloj del servidor no está sincronizado. 
   ID generado (1739500000000) no es mayor al último ID (1739617845234). 
   Verificar sincronización NTP del servidor PostgreSQL.
```

**Este último error indica un problema grave que requiere atención inmediata:**
- Reloj del servidor PostgreSQL atrasado o mal sincronizado
- Problema con NTP (Network Time Protocol)
- Cambio manual del reloj del sistema
- **Acción requerida:** Configurar/verificar NTP en el servidor de base de datos

## 🎯 Escenarios de Generación de ID

### ✅ Escenario Normal (Reloj Sincronizado)
```
Último ID en BD: 1739617845234
Timestamp NOW(): 1739617850123 (5 segundos después)
Random: 456
ID generado: 1739617850456
Validación: 1739617850456 > 1739617845234 ✅
Resultado: INSERT exitoso
```

### ❌ Escenario de Error (Reloj Atrasado)
```
Último ID en BD: 1739617845234
Timestamp NOW(): 1739617800000 (reloj atrasado 45 segundos)
Random: 123
ID generado: 1739617800123
Validación: 1739617800123 <= 1739617845234 ❌
Resultado: ERROR - "El reloj del servidor no está sincronizado..."
Acción: Administrador debe verificar/configurar NTP
```

### ✅ Escenario Primera Inserción
```
Último ID en BD: 0 (tabla vacía)
Timestamp NOW(): 1739617850123
Random: 789
ID generado: 1739617850789
Validación: 1739617850789 > 0 ✅
Resultado: INSERT exitoso (primer pasajero)
```

**¿Por qué lanzar error en lugar de ajustar?**
- ✅ **Visibilidad**: Los administradores detectan problemas inmediatamente
- ✅ **Root cause**: Fuerza a resolver la causa (NTP mal configurado)
- ✅ **Integridad**: Los IDs mantienen su significado temporal real
- ✅ **Prevención**: Evita ocultar problemas que afectan todo el sistema
- ✅ **En producción**: Con NTP correcto, esto nunca debería pasar

## 🎯 Próximos Pasos

1. ✅ Crear ruta API (`routes/passengers.routes.js`)
2. ✅ Actualizar auth store en Vue
3. ✅ Probar registro desde el frontend
4. ✅ Implementar favoritos, alertas e historial

## 📚 Archivos Relacionados

- `api/database/fun_create_passenger.sql` - Función almacenada
- `api/database/tab_passengers.sql` - Esquema de tabla (sin phone)
- `api/database/migrate-remove-phone.sql` - Migración
- `api/services/passengers.service.js` - Servicio actualizado
- `api/ID_SYSTEM.md` - Documentación del sistema de IDs

## ❓ FAQ

**¿Y si quiero volver a agregar phone?**
1. Agrega columna: `ALTER TABLE passengers ADD COLUMN phone VARCHAR(20)`
2. Actualiza servicio: agrega `phone` en updatePassenger
3. No lo agregues en la función de creación (mantén registro simple)

**¿La función es portable?**
Sí, usa SQL estándar. Para migrar a MySQL:
- Cambia `plpgsql` a SQL estándar
- Usa `UNIX_TIMESTAMP()` en lugar de `EXTRACT(EPOCH FROM NOW())`
- Mantén la misma lógica de validaciones

**¿Por qué no SERIAL para el ID?**
SERIAL crea secuencias específicas de PostgreSQL que dificultan la migración y tienen problemas de concurrencia. Nuestro sistema timestamp+random es portable y distribuido.

**¿Qué pasa si dos usuarios se registran al mismo segundo?**
El componente random (0-999) previene colisiones. Probabilidad de colisión: 1/1000 por segundo. Con reintentos, prácticamente 0%.

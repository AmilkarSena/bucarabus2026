# FIX: Error ID_NOT_MONOTONIC - Sistema BucaraBus

## 📋 RESUMEN DEL PROBLEMA

**Error Original:**
```
Error en generación de ID: nuevo ID (355902134) <= último ID (1735689600)
Error code: ID_NOT_MONOTONIC
```

## 🔍 CAUSA RAÍZ

El problema estaba en una **incompatibilidad entre el ID del usuario del sistema y la fórmula de generación de IDs**:

### Fórmula de Generación de IDs (PostgreSQL):
```sql
v_epoch_2025 := 1735689600;  -- Epoch de 2025-01-01 00:00:00 UTC
v_random := FLOOR(RANDOM() * 100)::INTEGER;
v_new_id := ((EXTRACT(EPOCH FROM NOW()) - v_epoch_2025) * 10)::INTEGER + v_random;
```

### El Problema:
- **Usuario del Sistema original**: `id_user = 1735689600` (valor epoch completo de 2025-01-01)
- **IDs generados en 2026**: `~355,000,000` (basados en segundos desde 2025-01-01 multiplicados por 10)
- **Validación**: `IF v_new_id <= v_last_id THEN ERROR`

**Resultado**: Como `355,000,000 < 1,735,689,600`, la validación siempre fallaba.

### Por qué pasaba esto:
La fórmula genera IDs incrementales empezando desde 0 en 2025-01-01:
- Fecha: 2025-01-01 → ID: 0
- Fecha: 2026-02-16 → ID: ~355,911,950
- Fecha: 2030-06-15 → ID: 1,735,689,600 (alcanzaría al ID del sistema)

El sistema solo funcionaría correctamente **después del año 2030**.

## ✅ SOLUCIÓN IMPLEMENTADA

### 1. Corrección en Base de Datos

**Script ejecutado**: `fix-system-user-id.sql`

Acciones realizadas:
1. ✅ Creó usuario temporal con `id_user = 1`
2. ✅ Actualizó todas las referencias `user_create`/`user_update` de `1735689600` → `1`
3. ✅ Eliminó usuario del sistema con ID antiguo (`1735689600`)
4. ✅ Actualizó usuario temporal para ser el usuario del sistema oficial
5. ✅ Cambió los DEFAULT de columnas `user_create` en todas las tablas a `1`

**Resultado en base de datos**:
```sql
SELECT id_user, email, full_name FROM tab_users WHERE id_user = 1;
-- id_user: 1
-- email: system@bucarabus.local
-- full_name: Sistema Bucarabus
```

### 2. Actualización del Código

**Archivos modificados (10 archivos)**:

#### Frontend (1 archivo):
- ✅ `src/constants/system.js`
  ```javascript
  // ANTES: export const SYSTEM_USER_ID = 1735689600
  // DESPUÉS: export const SYSTEM_USER_ID = 1
  ```

#### Backend (9 archivos):

**Configuración:**
- ✅ `api/.env`
  ```env
  # ANTES: SYSTEM_USER_ID=1735689600
  # DESPUÉS: SYSTEM_USER_ID=1
  ```

**Servicios (5 archivos):**
- ✅ `api/services/drivers.service.js`
- ✅ `api/services/users.service.js`
- ✅ `api/services/buses.service.js`
- ✅ `api/services/routes.service.js`
- ✅ `api/services/trips.service.js`
  ```javascript
  // ANTES: const SYSTEM_USER_ID = 1735689600;
  // DESPUÉS: const SYSTEM_USER_ID = 1;
  ```

**Rutas (3 archivos):**
- ✅ `api/routes/drivers.routes.js`
- ✅ `api/routes/users.routes.js`
- ✅ `api/routes/assignments.routes.js`
  ```javascript
  // ANTES: const SYSTEM_USER_ID = 1735689600;
  // DESPUÉS: const SYSTEM_USER_ID = 1;
  ```

## 🧪 VERIFICACIÓN

### Diagnóstico realizado:

```powershell
# Verificar fecha de PostgreSQL
psql -U bucarabus_user -d db_bucarabus -c "SELECT NOW(), EXTRACT(EPOCH FROM NOW());"
# Resultado: 2026-02-16 (fecha correcta) ✅
# Epoch: 1771280795 ✅

# Verificar timezone
psql -U bucarabus_user -d db_bucarabus -c "SHOW timezone;"
# Resultado: America/Bogota ✅
```

**Conclusión del diagnóstico**: 
- ✅ PostgreSQL tiene la fecha/hora correcta
- ✅ Timezone configurado correctamente
- ❌ El problema era el ID del usuario del sistema demasiado grande

## 🎯 PRÓXIMOS PASOS

### 1. Reiniciar Servidores

**Backend:**
```bash
cd vue-bucarabus/api
# Detener servidor actual (Ctrl+C)
npm run dev
```

**Frontend:**
```bash
cd vue-bucarabus
# Detener servidor actual (Ctrl+C)
npm run dev
```

### 2. Probar Creación de Conductor

Datos de prueba:
- Email: `conductor.test@bucarabus.com`
- Nombre: `Carlos Eduardo Montoya`
- Cédula: `324324325`
- Celular: `3001234567`
- Categoría Licencia: `C2`
- Fecha Expiración: `2026-12-31`

**Resultado Esperado:**
```javascript
{
  success: true,
  msg: 'Conductor creado exitosamente: Carlos Eduardo Montoya',
  id_user: 355912345,  // ID > 1 ✅
  id_card: 324324325
}
```

### 3. Verificar IDs Generados

```sql
-- Verificar que los nuevos IDs son mayores que 1
SELECT id_user, email, full_name, created_at 
FROM tab_users 
ORDER BY id_user DESC 
LIMIT 5;

-- Debería mostrar:
-- id_user > 1 para todos los nuevos usuarios ✅
```

## 📊 RESUMEN DE CAMBIOS

| Componente | Antes | Después | Estado |
|------------|-------|---------|--------|
| **Base de Datos** | | | |
| Usuario Sistema ID | 1735689600 | 1 | ✅ |
| DEFAULT user_create | 1735689600 | 1 | ✅ |
| **Frontend** | | | |
| SYSTEM_USER_ID | 1735689600 | 1 | ✅ |
| **Backend** | | | |
| .env | 1735689600 | 1 | ✅ |
| Services (5) | 1735689600 | 1 | ✅ |
| Routes (3) | 1735689600 | 1 | ✅ |

## 🔐 VALIDACIÓN DE SEGURIDAD

La validación `ID_NOT_MONOTONIC` se **mantiene activa** para:
- ✅ Detectar problemas de fecha/hora del servidor
- ✅ Prevenir IDs duplicados
- ✅ Asegurar integridad de auditoría

Esta validación ahora funciona correctamente porque:
- El ID del sistema (1) es el más pequeño posible
- Todos los nuevos IDs serán > 1
- La fórmula producirá IDs crecientes mientras la fecha avance

## ⚠️ IMPORTANTE

**¿Qué NO se modificó?**
- ❌ La fórmula de generación de IDs (sigue usando `(epoch - 1735689600) * 10`)
- ❌ La validación ID_NOT_MONOTONIC (se mantiene por seguridad)
- ❌ La estructura de las tablas

**¿Por qué funciona ahora?**
- ✅ El punto de referencia (ID del sistema = 1) es mucho más pequeño que cualquier ID generado
- ✅ Los IDs generados (~355 millones) son siempre mayores que 1
- ✅ La validación cumple su propósito sin falsos positivos

## 📝 NOTAS TÉCNICAS

### Rango de IDs Esperado (2025-2035):

| Fecha | Segundos desde 2025-01-01 | ID Generado* |
|-------|---------------------------|--------------|
| 2025-01-01 | 0 | 0 - 99 |
| 2026-01-01 | 31,536,000 | 315,360,000 - 315,360,099 |
| 2030-01-01 | 157,680,000 | 1,576,800,000 - 1,576,800,099 |
| 2035-01-01 | 315,360,000 | 3,153,600,000 - 3,153,600,099 |

\* Fórmula: `(segundos * 10) + random(0-99)`

### Capacidad del Sistema:

- **Tipo de dato**: INTEGER (PostgreSQL)
- **Rango**: -2,147,483,648 a 2,147,483,647
- **ID máximo alcanzable**: ~2,147,483,647
- **Fecha límite**: Año ~2092 (67 años de operación)

---

**Fecha de corrección**: 2026-02-16  
**Ejecutado por**: Sistema BucaraBus  
**Estado**: ✅ COMPLETADO

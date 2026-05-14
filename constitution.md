# Constitución del Proyecto BucaraBus

## 1. Identidad Central
BucaraBus es una plataforma de gestión de flotas y optimización de rutas para el transporte público. Su misión es proporcionar visibilidad en tiempo real y una administración eficiente de las operaciones de tránsito, garantizando escalabilidad y facilidad de mantenimiento.

## 2. Principios Arquitectónicos (BD Delgada / API Gruesa)
BucaraBus adopta el enfoque **Thin Database / Thick Application Layer**. 

### Responsabilidades por Capa:
- **🗄️ Capa de Base de Datos (PostgreSQL)**:
    - **SÍ**: Integridad referencial, validaciones de registro (`CHECK`, `UNIQUE`), Procedimientos Almacenados optimizados para mutaciones, triggers de auditoría básica (`updated_at`).
    - **NO**: Lógica de negocio compleja, validación de estado de otras entidades, formateo de UI, comunicación externa.
- **⚙️ Capa de Negocio / API (Node.js / Express)**:
    - **SÍ**: Centralizar TODA la lógica y validaciones complejas, orquestar llamadas a Procedimientos Almacenados, declarar columnas explícitas en `SELECT`, manejo de auth/authz.
    - **NO**: Ejecutar `INSERT/UPDATE/DELETE` directos (SQL Raw), usar `SELECT *`.
- **🖥️ Capa de Presentación (Vue.js)**:
    - **SÍ**: Retroalimentación inmediata (UI/UX), validaciones tempranas, manejo amigable de errores de la API.

### Flujo de Trabajo (Regla de Oro):
Si la validación requiere leer el estado de *otras* tablas para tomar una decisión lógica, esa validación **debe ir en el Servicio de la API**, no en la Base de Datos.

---

## 3. Stack Tecnológico
- **Frontend**: Vue 3 (Composition API), Vite, Pinia, Leaflet.
- **Backend**: Node.js, Express, `pg` (node-postgres).
- **Base de Datos**: PostgreSQL 15+.
- **Real-time**: Socket.io.
- **Pruebas**: Vitest (Frontend), Jest (Backend).

---

## 4. Estándares de Codificación

### Nomenclatura
- **Código (JS/Vue)**: camelCase para variables/funciones, PascalCase para componentes/clases. Idioma preferido: Inglés.
- **Base de Datos**: snake_case para tablas/columnas/funciones. Idioma: Español permitido para términos de negocio.
- **API Responses**: Siempre retornar:
  ```javascript
  { success: boolean, message: string, data?: any, error_code?: string }
  ```

### Backend (Reglas de Oro)
1. **Mutaciones**: Invocación obligatoria de Procedimientos Almacenados (ej: `SELECT * FROM fun_create_user(...)`).
2. **Consultas**: Prohibido el uso de `SELECT *`. Selección explícita de columnas siempre.
3. **Servicios vs Controladores**: Controladores manejan HTTP; Servicios manejan lógica y BD.
4. **Auditoría**: Toda mutación debe requerir el ID del usuario (`user_create` / `user_update`) obtenido del Token JWT.

### Frontend
- **Estado**: Usar Pinia para estado compartido. Evitar prop drilling.
- **Modularidad**: Componentes de máximo 400 líneas. Refactorizar en sub-componentes si exceden el límite.
- **Estilos**: CSS Vanilla o scoped styles.

---

## 5. Principios de Diseño y Limpieza
- **KISS**: Priorizar simplicidad sobre sobre-ingeniería.
- **DRY**: Eliminar duplicación de código (lógica, componentes o SQL).
- **YAGNI**: Implementar solo lo necesario para el requerimiento actual.
- **Clean Code**: Nombres descriptivos, funciones cortas (una sola cosa), comentarios solo para explicar el "por qué" de decisiones complejas.

---

## 6. Estrategia de Pruebas
- **Unidad/Integración**: Vitest para el frontend y Jest para los servicios del backend.
- **Prioridad**: Cubrir lógica de negocio crítica en Servicios y Procedimientos Almacenados.

---

## 7. Definición de Hecho (Definition of Done)
- [ ] El código cumple con el patrón Thin DB / Thick API.
- [ ] No se utiliza `SELECT *` ni SQL Raw para mutaciones.
- [ ] La respuesta de la API sigue la estructura estándar.
- [ ] El código pasa el Linter y las pruebas automáticas.
- [ ] Las funciones son cortas y siguen SRP (Responsabilidad Única).

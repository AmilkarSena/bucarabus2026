# BucaraBus - Sistema de Gestión de Transporte

## 🎉 Arquitectura Actualizada con Vue Router

El proyecto ha sido refactorizado para utilizar **Vue Router** con una arquitectura híbrida que optimiza el uso del espacio según el tipo de contenido.

---

## 📋 Estructura de Navegación

### 🗺️ **Vistas con Mapa** (MapLayout)
Estas secciones muestran el mapa de fondo con widgets flotantes de control:

- **📍 Monitor Live** (`/monitor`)
  - Widget flotante con estadísticas en tiempo real
  - Acciones rápidas (Nuevo Bus, Nueva Ruta, Ver Todas las Rutas)
  - Visualización de buses activos en el mapa

- **🛣️ Rutas** (`/routes`)
  - Widget de control de rutas
  - Toggle para mostrar/ocultar rutas en el mapa
  - Botones para crear y editar rutas

### 📊 **Vistas Completas** (DashboardLayout)
Estas secciones ocupan toda el área disponible sin el mapa:

- **🚌 Gestión de Flota** (`/fleet`)
  - Grid de tarjetas con todos los buses
  - Búsqueda y filtros avanzados
  - Gestión completa de la flota

- **👤 Gestión de Conductores** (`/drivers`)
  - Grid de tarjetas con todos los conductores
  - Información completa de licencias
  - Alertas de vencimiento de licencias
  - Búsqueda y filtros por disponibilidad y categoría

- **⏰ Gestión de Turnos** (`/shifts`)
  - Sistema de drag & drop para asignación de buses
  - Generador automático de horarios
  - Vista de buses disponibles

- **📊 Analytics** (`/analytics`)
  - Dashboard con métricas y KPIs
  - Gráficos de rendimiento
  - Análisis por rutas

- **🚨 Centro de Alertas** (`/alerts`)
  - Lista de notificaciones
  - Historial de eventos
  - Gestión de alertas

- **⚙️ Configuración** (`/settings`)
  - Ajustes del sistema
  - Preferencias de usuario
  - Configuración general

---

## 🚀 Cómo Ejecutar el Proyecto

### Prerrequisitos
- **Node.js** 16+ (recomendado: Node 18 o 20)
- **npm** (viene con Node.js)

### Instalación y Ejecución

1. **Navegar a la carpeta del proyecto:**
   ```powershell
   cd C:\Users\dlast\Documents\previous_version\vue-bucarabus
   ```

2. **Instalar dependencias** (solo la primera vez o si actualizas dependencias):
   ```powershell
   npm install
   ```

3. **Arrancar en modo desarrollo:**
   ```powershell
   npm run dev
   ```
   
   La aplicación se abrirá en: **http://localhost:5173** (o el puerto que Vite asigne)

4. **Abrir en el navegador:**
   ```powershell
   Start-Process 'http://localhost:5173'
   ```

### Build de Producción

Para generar los archivos optimizados:
```powershell
npm run build
```

Para previsualizar el build:
```powershell
npm run preview
```

---

## 🎨 Cambios Principales Implementados

### ❌ **Eliminado:**
- `AppContextPanel.vue` - Panel contextual lateral derecho
- Sistema de navegación por "sections" en el store
- Funciones `openContextPanel`, `closeContextPanel`, `setCurrentSection`

### ✅ **Agregado:**
- **Vue Router** con rutas independientes
- **2 Layouts:**
  - `MapLayout.vue` - Para Monitor y Rutas (con mapa de fondo)
  - `DashboardLayout.vue` - Para Flota, Turnos, Analytics, etc.
- **Navegación con `router-link`** en el sidebar
- **Widgets flotantes** para vistas con mapa (MonitorView, RoutesView)
- **Contenido full-screen** para vistas de gestión

### 🔄 **Actualizado:**
- `App.vue` - Ahora solo renderiza `<router-view />`
- `AppSidebar.vue` - Usa `router-link` en lugar de clicks con el store
- `router/index.js` - Configurado con todas las rutas y layouts
- `stores/app.js` - Limpiado de funciones del panel contextual
- `MonitorView.vue` - Convertido a widget flotante
- `RoutesView.vue` - Simplificado a widget de control de rutas

---

## 🗺️ Estructura de Archivos

```
vue-bucarabus/
├── src/
│   ├── layouts/              # ✨ NUEVO
│   │   ├── MapLayout.vue        # Layout con mapa
│   │   └── DashboardLayout.vue  # Layout sin mapa
│   ├── views/
│   │   ├── MonitorView.vue      # 🔄 Widget flotante
│   │   ├── RoutesView.vue       # 🔄 Widget flotante
│   │   ├── FleetView.vue        # ✅ Pantalla completa
│   │   ├── ShiftsView.vue       # ✅ Pantalla completa
│   │   ├── AnalyticsView.vue    # ✅ Pantalla completa
│   │   ├── AlertsView.vue       # ✅ Pantalla completa
│   │   └── SettingsView.vue     # ✅ Pantalla completa
│   ├── components/
│   │   ├── AppHeader.vue
│   │   ├── AppSidebar.vue       # 🔄 Actualizado con router-link
│   │   ├── AppStatusBar.vue
│   │   ├── AppModals.vue
│   │   ├── MapComponent.vue
│   │   └── [AppContextPanel.vue eliminado] # ❌
│   ├── router/
│   │   └── index.js             # 🔄 Configurado
│   ├── stores/
│   │   ├── app.js               # 🔄 Limpiado
│   │   ├── buses.js
│   │   ├── drivers.js
│   │   └── routes.js
│   ├── App.vue                  # 🔄 Simplificado
│   └── main.js
├── package.json
└── vite.config.js
```

---

## 🎯 Ventajas de la Nueva Arquitectura

### ✨ **Mejor UX:**
- URLs compartibles y navegación con historial del navegador
- Vistas específicas optimizadas para su contenido
- Más espacio para tablas, formularios y gráficos

### 🚀 **Mejor Performance:**
- Componentes lazy-loading por ruta
- Mapa solo carga cuando es necesario
- Menos re-renders innecesarios

### 🛠️ **Mejor Mantenibilidad:**
- Separación clara de responsabilidades
- Layouts reutilizables
- Código más limpio y organizado

### 📱 **Responsive:**
- Layouts adaptados a mobile
- Widgets se ajustan automáticamente
- Sidebar colapsable en móvil

---

## 🔧 Solución de Problemas

### Puerto en uso
Si el puerto 5173 está ocupado, Vite automáticamente usará el siguiente disponible. Revisa la consola para ver qué puerto se asignó.

### Error de ESM
El proyecto usa `"type": "module"` en `package.json`. Asegúrate de usar Node.js 16+.

### Errores de compilación
Si ves errores de TypeScript o linting, ejecuta:
```powershell
npm run lint
```

### Limpiar instalación
Si hay problemas con dependencias:
```powershell
Remove-Item -Recurse -Force node_modules, package-lock.json
npm install
```

---

## 📝 Notas para Desarrollo

### Agregar una nueva ruta

1. Crear la vista en `src/views/NuevaVista.vue`
2. Agregar la ruta en `src/router/index.js`:
   ```javascript
   {
     path: '/nueva-vista',
     component: DashboardLayout, // o MapLayout
     children: [
       {
         path: '',
         name: 'nuevaVista',
         component: NuevaVista,
         meta: { title: 'Nueva Vista', section: 'nuevaVista' }
       }
     ]
   }
   ```
3. Agregar el item en el sidebar (`src/components/AppSidebar.vue`):
   ```javascript
   { id: 'nuevaVista', route: '/nueva-vista', icon: '🆕', label: 'Nueva Vista' }
   ```

### Estilos globales
Los estilos base están en `src/assets/css/styles.css` y se importan en `main.js`.

---

## 📚 Tecnologías Utilizadas

- **Vue 3** - Framework progresivo
- **Vue Router 4** - Sistema de rutas
- **Pinia** - State management
- **Vite** - Build tool y dev server
- **Leaflet** - Mapas interactivos
- **ESLint** - Linting

---

## 👨‍💻 Comandos Útiles

```powershell
# Desarrollo
npm run dev

# Build
npm run build

# Preview de build
npm run preview

# Linting
npm run lint

# Ver versiones
node -v
npm -v
```

---

## 🎉 ¡Listo!

El proyecto ahora tiene una arquitectura mucho más funcional y escalable. Disfruta desarrollando con BucaraBus! 🚌

---

**Última actualización:** Octubre 5, 2025

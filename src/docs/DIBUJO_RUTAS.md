# 🗺️ Sistema de Dibujo de Rutas en el Mapa

## 📋 Descripción General

El sistema permite **dibujar rutas interactivamente** en el mapa usando Leaflet.js. El usuario puede hacer clic en el mapa para agregar puntos y crear trayectorias de rutas de bus.

---

## 🔧 Cómo Funcionar

### **1. Activar Modo de Dibujo**

Al hacer clic en el botón **"➕ Nueva Ruta"** en `RoutesView.vue`:

```javascript
const openNewRouteModal = () => {
  appStore.startRouteDrawing()
}
```

Esto activa el modo de dibujo en el mapa:
- `isDrawingRoute = true`
- Se muestra el panel de instrucciones flotante
- El mapa espera clics del usuario

---

### **2. Dibujar en el Mapa**

**Cada clic en el mapa:**
1. Agrega un marcador numerado en esa posición
2. Guarda las coordenadas `[lat, lng]`
3. Si hay 2+ puntos, dibuja una línea conectándolos

**Visualización:**
- 🔴 Marcadores rojos con números (1, 2, 3...)
- 📍 Línea roja conectando los puntos
- 📊 Contador de puntos en el panel lateral

---

### **3. Finalizar el Dibujo**

**Opción A: Botón "Finalizar"**
```javascript
const finishRouteDrawing = () => {
  if (currentRoutePoints.value.length < 2) {
    alert('Necesitas al menos 2 puntos para crear una ruta')
    return
  }
  
  // Abre el modal con los puntos dibujados
  appStore.openModal('route', {
    path: [...currentRoutePoints.value]
  })
}
```

Esto abre `RouteModal.vue` pre-cargado con:
- ✅ Los puntos dibujados en el mapa
- 📝 Formulario para completar: ID, Nombre, Color, Tarifa, etc.

**Opción B: Botón "Cancelar"**
```javascript
const cancelRouteDrawing = () => {
  // Limpia todos los marcadores y líneas
  routeMarkers.forEach(marker => leafletMap.removeLayer(marker))
  routeMarkers = []
  
  if (currentPolyline) {
    leafletMap.removeLayer(currentPolyline)
    currentPolyline = null
  }
  
  appStore.stopRouteDrawing()
  appStore.clearRoutePoints()
}
```

---

## 🎨 Interfaz Visual

### **Panel de Instrucciones (Flotante)**

Aparece cuando estás dibujando:

```
┌─────────────────────────────────┐
│ 🗺️ Dibujando Nueva Ruta        │
├─────────────────────────────────┤
│ • Haz clic en el mapa para      │
│   agregar puntos                │
│ • Mínimo 2 puntos requeridos    │
│ • Puntos actuales: 3            │
├─────────────────────────────────┤
│  [Finalizar]     [Cancelar]     │
└─────────────────────────────────┘
```

---

## 📂 Archivos Involucrados

### **1. MapComponent.vue**
- Maneja el mapa Leaflet
- Detecta clics en el mapa
- Dibuja marcadores y líneas
- Gestiona el estado de dibujo

**Funciones clave:**
- `handleMapClick(e)` - Detecta clics cuando está en modo dibujo
- `addRoutePoint(latlng)` - Agrega punto y marcador
- `finishRouteDrawing()` - Completa y abre modal
- `cancelRouteDrawing()` - Limpia todo

---

### **2. app.js (Store)**
- Gestiona el estado global de dibujo

**Estado:**
```javascript
isDrawingRoute: false,
currentRoutePoints: [],
routeMarkers: []
```

**Acciones:**
- `startRouteDrawing()` - Activa modo dibujo
- `stopRouteDrawing()` - Desactiva modo dibujo
- `addRoutePoint(point)` - Agrega punto al array
- `clearRoutePoints()` - Limpia puntos y marcadores

---

### **3. routes.js (Store)**
- Gestiona las rutas creadas

**Estructura de Ruta:**
```javascript
{
  id: 'RUTA_01',
  name: 'Ruta Centro',
  color: '#3b82f6',
  path: [[7.119, -73.122], [7.125, -73.128], ...],
  fare: 2800,
  frequency: 15,
  description: 'Ruta principal',
  visible: true,
  stops: [],
  buses: ['BUS-001']
}
```

**Acciones:**
- `addRoute(routeData)` - Crea nueva ruta
- `toggleRouteVisibility(id)` - Muestra/oculta en mapa

---

### **4. RouteModal.vue**
- Formulario para completar datos de la ruta
- Recibe los puntos dibujados en `props.data.path`
- Guarda la ruta con `routesStore.addRoute()`

**Campos:**
- 🆔 ID de Ruta (auto-generado)
- 📝 Nombre
- 🎨 Color (selector)
- 💰 Tarifa (COP)
- ⏱️ Frecuencia (minutos)
- 📄 Descripción

---

### **5. RoutesView.vue**
- Widget de control de rutas
- Botón "Nueva Ruta" activa el dibujo
- Lista de rutas con acciones:
  - 👁️ Mostrar/ocultar en mapa
  - ✏️ Editar ruta
  - 🗺️ Mostrar todas

---

## 🚀 Flujo Completo (Paso a Paso)

```mermaid
1. Usuario → [Botón "Nueva Ruta"]
   ↓
2. appStore.startRouteDrawing()
   ↓
3. MapComponent detecta clics
   ↓
4. Por cada clic:
   - Agrega marcador numerado
   - Guarda coordenadas
   - Dibuja línea conectando puntos
   ↓
5. Usuario → [Botón "Finalizar"]
   ↓
6. Validación: ¿2+ puntos?
   ✅ Sí → Abre RouteModal con path
   ❌ No → Muestra alerta
   ↓
7. Usuario completa formulario
   ↓
8. routesStore.addRoute(routeData)
   ↓
9. Ruta guardada y mostrada en lista
   ↓
10. Ruta se puede ver en el mapa (toggleRouteVisibility)
```

---

## 🎯 Características Adicionales

### **Mostrar/Ocultar Rutas**
Cada ruta tiene un botón 👁️:
- Click → Alterna `visible: true/false`
- Si `visible = true` → Se dibuja en el mapa
- Color de la ruta según su propiedad `color`

### **Editar Rutas Existentes**
Click en ✏️ → Abre `RouteModal` con datos pre-cargados

### **Mostrar Todas las Rutas**
Botón "🗺️ Mostrar Todas" → Activa visibilidad de todas las rutas

---

## 🔍 Debugging

### **Ver Estado de Dibujo**
```javascript
// En consola del navegador
const appStore = useAppStore()
console.log('Dibujando:', appStore.isDrawingRoute)
console.log('Puntos:', appStore.currentRoutePoints)
```

### **Ver Rutas en el Store**
```javascript
const routesStore = useRoutesStore()
console.log('Rutas:', routesStore.routesList)
console.log('Rutas visibles:', routesStore.activeRoutes)
```

---

## ⚠️ Validaciones

✅ **Mínimo 2 puntos** para crear una ruta  
✅ **ID único** auto-generado (`RUTA_01`, `RUTA_02`, etc.)  
✅ **Nombre obligatorio**  
✅ **Color por defecto:** `#ef4444` (rojo)  
✅ **Tarifa por defecto:** `0` COP  
✅ **Frecuencia por defecto:** `15` minutos  

---

## 🎨 Estilos Visuales

**Marcadores:**
- 🔴 Círculos rojos con números blancos
- Tamaño: 20x20px
- Borde blanco

**Líneas (Polylines):**
- Color: Rojo (`#ef4444`) durante dibujo
- Color personalizado después de guardar
- Grosor: 4px
- Opacidad: 80%

**Panel de Instrucciones:**
- Fondo blanco
- Sombra flotante
- Bordes redondeados
- Posición: Top-right

---

## 📱 Responsive

- **Desktop:** Panel lateral derecho
- **Mobile:** Panel full-width superior
- Botones táctiles más grandes en móvil

---

## 🔄 Próximas Mejoras

- [ ] **Agregar paradas:** Click secundario para marcar paradas
- [ ] **Editar puntos:** Arrastrar marcadores para ajustar ruta
- [ ] **Eliminar puntos:** Click derecho en marcador
- [ ] **Deshacer último punto:** Botón "Undo"
- [ ] **Calcular distancia:** Mostrar km totales de la ruta
- [ ] **Importar rutas:** Cargar desde archivo GeoJSON
- [ ] **Exportar rutas:** Descargar como GPX/KML

---

## 📊 Datos de Ejemplo

El sistema viene con 3 rutas pre-cargadas:

1. **RUTA_01 - Ruta Centro** (Azul 🔵)
2. **RUTA_02 - Ruta Norte** (Rojo 🔴)
3. **RUTA_03 - Ruta Sur** (Verde 🟢)

---

## 🛠️ Tecnologías

- **Vue 3** - Framework
- **Leaflet.js 1.9.4** - Librería de mapas
- **Pinia** - State management
- **CartoDB** - Tiles del mapa

---

**¡Sistema completo y funcional! 🎉**

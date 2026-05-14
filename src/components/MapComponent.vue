<template>
  <div class="map-wrapper" :class="{ 'is-creating-route': appStore.isCreatingRoute }" :style="{ '--draft-color': appStore.draftRouteColor }">
    <div id="map" class="leaflet-map"></div>

    <!-- Banner de Modo Creación -->
    <CreationBanner />

    <!-- Map Controls -->
    <div class="map-controls">
      <button id="fullscreen-map" class="map-control-btn" @click="toggleFullscreen" title="Pantalla completa">
        ⛶
      </button>
      <button id="center-map" class="map-control-btn" @click="centerMap" title="Centrar mapa">
        🎯
      </button>
      <button id="layers-control" class="map-control-btn" @click="toggleLayers" title="Capas">
        🗂️
      </button>
    </div>

    <!-- Active Buses Widget -->
    <ActiveBusesWidget
      :busLocationsArray="busLocationsArray"
      :isConnected="isConnected"
      :activeRoutesLegend="activeRoutesLegend"
      :activeBusesWithRoutes="activeBusesWithRoutes"
    />


    <!-- Overlay: editar punto del catálogo -->
    <CatalogPointPopup />

  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed, watch, nextTick } from 'vue'

import { useAppStore } from '../stores/app'
import { useBusesStore } from '../stores/buses'
import { useRoutesStore } from '../stores/routes'
import { useWebSocket } from '../composables/useWebSocket'
import { useShiftBuses } from '../composables/useShiftBuses'
import { useGpsBuses } from '../composables/useGpsBuses'
import { useCatalogPoints } from '../composables/useCatalogPoints'
import { useBusDisplay } from '../composables/useBusDisplay'
import { useRouteDisplay } from '../composables/useRouteDisplay'
import { useDraftRoute } from '../composables/useDraftRoute'
import CreationBanner from './map/CreationBanner.vue'
import ActiveBusesWidget from './map/ActiveBusesWidget.vue'
import CatalogPointPopup from './map/CatalogPointPopup.vue'
import { snapToRoad } from '../api/geocoding'
import L from 'leaflet'

const appStore = useAppStore()
const busesStore = useBusesStore()
const routesStore = useRoutesStore()

// WebSocket para GPS en tiempo real
const { 
  isConnected, 
  busLocations, 
  busLocationsArray, 
  connect: connectWebSocket, 
  disconnect: disconnectWebSocket 
} = useWebSocket()

// Estado local
let leafletMap = null
let busMarkers = new Map() // Mapa de marcadores de buses { busId: marker }
let shiftBusesInterval = null // Intervalo para actualizar buses de turnos

// Composables de buses (extraídos de este componente)
const getMap = () => leafletMap
const { displayShiftBuses, clearShiftBusMarkers, shiftDataCache } = useShiftBuses({
  getMap, routesStore, busLocations
})
const { displayGpsBuses, clearGpsMarkers } = useGpsBuses({
  getMap, busLocations, busLocationsArray, shiftDataCache
})

// Computed properties
const selectedRoutePoints = computed(() => appStore.selectedRoutePoints)
const catalogPointsVisible = computed(() => appStore.catalogPointsVisible || appStore.isCreatingRoute)
const allCatalogPoints = computed(() => appStore.allCatalogPoints)

// Composable de marcadores del catálogo de paradas
const { cleanup: cleanupCatalogPoints } = useCatalogPoints({
  getMap,
  appStore,
  catalogPointsVisible,
  allCatalogPoints,
  selectedRoutePoints
})

// Composable de display de buses de la flota
const { displayBuses } = useBusDisplay({
  getMap, busMarkers, busesStore, routesStore
})

// Composable de display de rutas y paradas numeradas
const { displayRoutes, clearRoutesFromMap, cleanup: cleanupRouteDisplay } = useRouteDisplay({
  getMap, appStore, routesStore
})

// Composable de trazado del borrador de ruta (modo creación)
const { draftRouteCache, cleanup: cleanupDraftRoute } = useDraftRoute({
  getMap, appStore
})

const activeBusesWithRoutes = computed(() => 
  busesStore.buses.filter(bus => bus.status_bus && bus.ruta_actual)
)

// Leyenda de rutas activas con conteo de buses
const activeRoutesLegend = computed(() => {
  const routesMap = new Map()
  
  activeBusesWithRoutes.value.forEach(bus => {
    if (bus.ruta_actual) {
      const route = routesStore.getRouteById(bus.ruta_actual)
      if (route) {
        if (routesMap.has(route.id)) {
          routesMap.get(route.id).busCount++
        } else {
          routesMap.set(route.id, {
            id: route.id,
            name: route.name,
            color: route.color || '#667eea',
            busCount: 1
          })
        }
      }
    }
  })
  
  return Array.from(routesMap.values()).sort((a, b) => b.busCount - a.busCount)
})


// Métodos del mapa
const initializeMap = () => {
  if (leafletMap) return

  // Wait for the map container to be available
  const mapContainer = document.getElementById('map')
  if (!mapContainer) {
    console.warn('Map container not found, retrying in 100ms...')
    setTimeout(initializeMap, 100)
    return
  }

  console.log('Map container found:', mapContainer)
  console.log('Map container dimensions:', mapContainer.offsetWidth, 'x', mapContainer.offsetHeight)

  try {
    leafletMap = L.map('map').setView([7.1193, -73.1227], 13)

    const CARTO_URL = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
    const LOCAL_TILE_URL = import.meta.env.VITE_TILE_URL || '/tiles'
    const SERVICE_BOUNDS = L.latLngBounds([6.88, -73.38], [7.62, -72.90])
    const tileOptions = {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      subdomains: 'abcd',
      maxZoom: 19,
      updateWhenZooming: false,
      updateWhenIdle: true,
      keepBuffer: 2,
      detectRetina: false
    }

    if (!LOCAL_TILE_URL) {
      L.tileLayer(CARTO_URL, tileOptions).addTo(leafletMap)
    } else {
      // bounds: restringe al área del .mbtiles. Solo cambia a CartoDB tras 5 errores en 10s.
      let switched = false
      let errorCount = 0
      let errorTimer = null
      const localLayer = L.tileLayer(
        `${LOCAL_TILE_URL}/styles/positron/{z}/{x}/{y}.png`,
        { ...tileOptions, bounds: SERVICE_BOUNDS }
      ).addTo(leafletMap)

      localLayer.on('tileerror', (e) => {
        console.warn(`Tile local falló en zoom ${e.coords.z}. Manteniendo servidor local...`);
      })
    }

    // Configurar eventos del mapa
    leafletMap.on('click', handleMapClick)
    leafletMap.on('click', () => { if (!appStore.isCreatingRoutePoint) appStore.catalogPointPopup = null })

    // Guardar referencia en el store
    appStore.setMapInstance(leafletMap)

    console.log('Mapa inicializado correctamente')
  } catch (error) {
    console.error('Error initializing map:', error)
  }
}
// Maneja los clics en el mapa
const handleMapClick = async (e) => {
  if (appStore.isCreatingRoutePoint) {
    // Modo Creación de Punto para el Catálogo
    const rawLat = e.latlng.lat
    const rawLng = e.latlng.lng
    // Intentar hacer snap a la calle más cercana
    const snapResult = await snapToRoad(rawLat, rawLng)
    
    let finalCoords = [rawLat, rawLng]
    if (snapResult && snapResult.snapped) {
      console.log(`🛣️ Snap exitoso: moviendo marcador ${snapResult.distance}m a la calle`)
      finalCoords = [snapResult.lat, snapResult.lng]
    }
    
    // Asignar solo una vez con las coordenadas finales para que el watcher en RoutesView capture el punto correcto
    appStore.newRoutePointCoords = finalCoords
  }
}

// ═══════════════════════════════════════════════════════════════════

// Watchers de rutas activas y buses
watch(
  () => [...routesStore.activeRoutes],
  () => { displayRoutes() },
  { deep: true }
)
// Observar solo cambios estructurales en la lista de buses (añadidos/eliminados) sin deep watch
watch(() => busesStore.buses.length, displayBuses)

// Al entrar/salir del modo creación de ruta: limpiar caché y redibujar
watch(() => appStore.isCreatingRoute, (isCreating) => {
  if (isCreating) {
    routesStore.clearFocusedRoute()
    draftRouteCache.clear()
  }
  displayRoutes()
})

let busUpdateInterval = null

// Lifecycle
onMounted(() => {
  nextTick(() => {
    initializeMap()
    displayRoutes()
    displayBuses()
    
    // ═══════════════════════════════════════════════════════════
    // CONECTAR WEBSOCKET PARA GPS EN TIEMPO REAL
    // ═══════════════════════════════════════════════════════════
    connectWebSocket()
    console.log('🛰️ WebSocket GPS iniciando conexión...')
    
    // ═══════════════════════════════════════════════════════════
    // MOSTRAR BUSES DE TURNOS ACTIVOS
    // ═══════════════════════════════════════════════════════════
    displayShiftBuses()
    // Actualizar buses de turnos cada 3 segundos
    shiftBusesInterval = setInterval(displayShiftBuses, 3000)
    console.log('🚌 Intervalo de buses de turnos iniciado')
    
    // Actualizar visualización de buses cada 2 segundos
    busUpdateInterval = setInterval(() => {
      displayBuses()
    }, 2000)
  })
})

onUnmounted(() => {
  if (busUpdateInterval) {
    clearInterval(busUpdateInterval)
  }
  
  // Limpiar intervalo de buses de turnos
  if (shiftBusesInterval) {
    clearInterval(shiftBusesInterval)
    console.log('🚌 Intervalo de buses de turnos detenido')
  }
  
  // ═══════════════════════════════════════════════════════════
  // DESCONECTAR WEBSOCKET
  // ═══════════════════════════════════════════════════════════
  disconnectWebSocket()
  console.log('🛰️ WebSocket GPS desconectado')
  
  // Limpiar marcadores de buses
  busMarkers.forEach(marker => {
    if (leafletMap) {
      leafletMap.removeLayer(marker)
    }
  })
  busMarkers.clear()
  
  // Limpiar marcadores GPS
  clearGpsMarkers()
  
  // Limpiar marcadores de buses de turnos
  clearShiftBusMarkers()
  
  // Limpiar marcadores del catálogo
  cleanupCatalogPoints()
  
  // Limpiar rutas y marcadores de paradas numeradas
  cleanupRouteDisplay()
  
  // Limpiar borrador de ruta (polílínea + marcadores + OSRM controller)
  cleanupDraftRoute()
  
  if (leafletMap) {
    leafletMap.remove()
    leafletMap = null
  }
})
</script>

<style scoped>
/* Map container */
.map-wrapper {
  height: 100%;
  width: 100%;
  position: relative;
}

#map {
  height: 100%;
  width: 100%;
  z-index: 1;
}

.leaflet-map {
  height: 100% !important;
  width: 100% !important;
}

/* Map controls */
.map-controls {
  position: absolute;
  top: 20px;
  right: 20px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  z-index: 800;
}

.map-control-btn {
  width: 45px;
  height: 45px;
  background: white;
  border: none;
  border-radius: 10px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  cursor: pointer;
  font-size: 16px;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.map-control-btn:hover {
  background: #667eea;
  color: white;
  transform: scale(1.05);
}

/* Route point markers */
.route-point-marker {
  border: 2px solid white !important;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.3) !important;
  cursor: pointer;
}

/* Bus markers */
:deep(.bus-marker) {
  background: transparent !important;
  border: none !important;
}

:deep(.bus-marker-container) {
  cursor: pointer;
  transition: transform 0.3s ease;
  filter: drop-shadow(0 4px 6px rgba(0, 0, 0, 0.3));
}

:deep(.bus-marker-container:hover) {
  transform: scale(1.2);
  filter: drop-shadow(0 6px 10px rgba(0, 0, 0, 0.4));
}

:deep(.bus-marker-icon) {
  animation: busFloat 3s ease-in-out infinite;
}

@keyframes busFloat {
  0%, 100% {
    transform: translateY(0px);
  }
  50% {
    transform: translateY(-4px);
  }
}

:deep(.bus-status-dot) {
  animation: statusPulse 2s ease-in-out infinite;
}

@keyframes statusPulse {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.7;
    transform: scale(0.9);
  }
}

/* ═══════════════════════════════════════════════════════════════
   ESTILOS PARA MARCADORES GPS EN TIEMPO REAL
   ═══════════════════════════════════════════════════════════════ */

:deep(.gps-bus-marker) {
  background: transparent;
  border: none;
}

:deep(.gps-marker-container) {
  position: relative;
}

:deep(.gps-marker-icon) {
  transition: transform 0.3s ease;
}

@keyframes gps-pulse {
  0% {
    transform: translate(-50%, -50%) scale(0.5);
    opacity: 1;
  }
  100% {
    transform: translate(-50%, -50%) scale(1.5);
    opacity: 0;
  }
}

:deep(.gps-pulse) {
  animation: gps-pulse 2s ease-out infinite !important;
}

:deep(.gps-speed-badge) {
  box-shadow: 0 2px 4px rgba(0,0,0,0.3);
}

/* Responsive */
@media (max-width: 768px) {
  .floating-widget {
    position: relative;
    top: 10px;
    left: 10px;
    width: calc(100% - 20px);
    max-width: 300px;
  }

  .map-controls {
    top: 10px;
    right: 10px;
  }

}

/* Animación de pulso para marcadores de buses */
@keyframes pulse-ring {
  0% {
    transform: scale(0.8);
    opacity: 1;
  }
  100% {
    transform: scale(2);
    opacity: 0;
  }
}

/* Estilos para marcadores de buses de turnos */
:deep(.shift-bus-marker) {
  background: transparent !important;
  border: none !important;
}

/* ========================================================
   MODO CREACIÓN DE RUTA (Efectos Visuales)
   ======================================================== */
/* Resplandor o borde animado sobre todo el mapa (Glow Border) */
.is-creating-route::after {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  pointer-events: none;
  z-index: 2000; /* Asegura que esté por encima de los controles de Leaflet */
  border: 4px solid #3b82f6;
  border-radius: inherit;
  animation: map-glow 1.5s ease-in-out infinite alternate;
}

@keyframes map-glow {
  from {
    box-shadow: inset 0 0 10px rgba(59, 130, 246, 0.2);
    border-color: rgba(59, 130, 246, 0.5);
  }
  to {
    box-shadow: inset 0 0 30px rgba(59, 130, 246, 0.9);
    border-color: rgba(59, 130, 246, 1);
  }
}

/* Animación de latido (pulse) azul para las paradas del catálogo durante el modo creación */
.is-creating-route :deep(.catalog-point-marker div) {
  background: var(--draft-color, #3b82f6) !important;
  animation: pulse-blue-marker 1.5s infinite !important;
  transition: background 0.3s ease;
}

@keyframes pulse-blue-marker {
  0% {
    transform: scale(0.95);
  }
  50% {
    transform: scale(1.15);
  }
  100% {
    transform: scale(0.95);
  }
}

/* Banner flotante de Modo Creación */
@keyframes banner-glow {
  from {
    box-shadow: 0 0 5px rgba(59, 130, 246, 0.3), 0 4px 15px rgba(0, 0, 0, 0.3);
    border-color: rgba(59, 130, 246, 0.4);
  }
  to {
    box-shadow: 0 0 20px rgba(59, 130, 246, 0.9), 0 4px 15px rgba(0, 0, 0, 0.3);
    border-color: rgba(59, 130, 246, 1);
  }
}

.pulse-dot {
  width: 10px;
  height: 10px;
  background-color: #ef4444;
  border-radius: 50%;
  display: inline-block;
  animation: pulse-red 1.5s infinite;
}

@keyframes pulse-red {
  0% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
  }
  70% {
    transform: scale(1);
    box-shadow: 0 0 0 6px rgba(239, 68, 68, 0);
  }
  100% {
    transform: scale(0.95);
    box-shadow: 0 0 0 0 rgba(239, 68, 68, 0);
  }
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
  transform: translate(-50%, -10px);
}
</style>

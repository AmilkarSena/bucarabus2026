<!-- App.vue — Punto de entrada de la app BucaraBus Pasajero -->
<template>
  <div class="passenger-app">
    <SideMenu 
      :is-open="isMenuOpen" 
      :current-view="currentView"
      @update:is-open="isMenuOpen = $event"
      @navigate="handleNavigate"
    />

    <PassengerHeader
      :is-connected="isConnected"
      :user-location="userLocation"
      :is-offline="isOffline"
      @locate="handleLocate"
      @open-menu="isMenuOpen = true"
    />

    <div v-show="currentView === 'home'" class="home-view">
      <!-- Barra de búsqueda dual (origen + destino) -->
    <div class="search-bar-wrapper">
      <TripSearchBar
        :origin-query="originQuery"
        :destination-query="searchQuery"
        :origin-results="originResults"
        :destination-results="searchResults"
        :has-origin="!!selectedOrigin"
        :has-destination="!!selectedDestination"
        :user-location-name="userLocationName"
        @search-origin="onSearchOrigin"
        @search-destination="onSearchDestination"
        @select-origin="handleSelectOrigin"
        @select-destination="handleSelectDestination"
        @clear-origin="handleClearOrigin"
        @clear-destination="handleClearDestination"
        @swap="handleSwap"
      />
    </div>

    <!-- Toast fuera de área de servicio -->
    <Transition name="toast-fade">
      <div v-if="toastMsg" class="toast-out-of-area">
        <span class="toast-icon">🚧</span>
        <span>{{ toastMsg }}</span>
      </div>
    </Transition>

    <!-- Vista de lista: visible cuando el mapa no está activo -->
    <div v-show="!mapVisible" class="content-area">
      <RouteSuggestionList
        v-if="selectedDestination && suggestedRoutes.length > 0"
        :suggestions="suggestedRoutes"
        :selected-suggestion="selectedSuggestedRoute"
        @select-route="handleSelectRoute"
      >
        <template #active-buses>
          <ActiveBusesList
            v-if="selectedSuggestedRoute && activeBusesOnSelectedRoute.length > 0"
            :buses="activeBusesOnSelectedRoute"
            @select-bus="handleSelectBusFromRoute"
          />
        </template>
      </RouteSuggestionList>

      <div v-else-if="selectedDestination && suggestedRoutes.length === 0" class="no-routes-msg">
        <span>😔</span>
        <p>No encontramos rutas directas a ese destino.</p>
      </div>

      <NearbyBusesList
        v-else
        :buses="nearbyBuses"
        :user-location="userLocation"
        @select-bus="handleSelectBusNearby"
        @request-location="requestLocation"
      />
    </div>

    <!-- Mapa: siempre en DOM, oculto con CSS para no romper Leaflet -->
    <div class="map-container" :class="{ 'map-hidden': !mapVisible }">
      <div ref="mapRef" class="map"></div>
      <button v-if="mapVisible" class="btn-back-list" @click="handleBackToList">
        ← Volver
      </button>
      <div v-if="isLoading" class="loading-overlay">
        <div class="spinner"></div>
        <p>Cargando buses...</p>
      </div>
    </div>

    <!-- Panel inferior: solo cuando el mapa está visible -->
    <BottomPanel
      v-show="mapVisible"
      :panel-hidden="panelHidden"
      :panel-expanded="panelExpanded"
      :selected-bus="selectedBus"
      :suggested-routes="suggestedRoutes"
      :selected-destination="selectedDestination"
      :selected-suggested-route="selectedSuggestedRoute"
      :active-buses-on-route="activeBusesOnSelectedRoute"
      :nearby-buses="nearbyBuses"
      :user-location="userLocation"
      @toggle="togglePanel"
      @select-route="handleSelectRoute"
      @select-bus-from-route="handleSelectBusFromRoute"
      @clear-bus="selectedBus = null"
      @request-location="requestLocation"
      @select-bus-nearby="handleSelectBusNearby"
    />
    </div> <!-- fin home-view -->

    <!-- Vista de Catálogo de Rutas -->
    <div v-show="currentView === 'catalog'" class="catalog-view">
      <RouteCatalog 
        :routes="cachedRoutes" 
        @view-on-map="handleViewRouteOnMap"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue'

// Componentes (todos locales a esta app)
import PassengerHeader      from './components/PassengerHeader.vue'
import SideMenu             from './components/SideMenu.vue'
import RouteCatalog         from './components/RouteCatalog.vue'
import TripSearchBar        from './components/TripSearchBar.vue'
import BottomPanel          from './components/BottomPanel.vue'
import RouteSuggestionList  from './components/RouteSuggestionList.vue'
import ActiveBusesList      from './components/ActiveBusesList.vue'
import NearbyBusesList      from './components/NearbyBusesList.vue'

// Composables compartidos
import { usePassengerGeolocation } from '@/composables/usePassengerGeolocation'
import { calculateDistance, formatDistance, calculateETA } from '@shared/utils/geo'

// Composables propios de la app Pasajero
import { usePassengerMap }    from './composables/usePassengerMap'
import { useRouteSearch }     from './composables/useRouteSearch'
import { useNominatim }       from './composables/useNominatim'
import { usePassengerSocket } from './composables/usePassengerSocket'
import { useRoutesCache }     from './composables/useRoutesCache'

// ============================================
// CONFIG
// ============================================
const getApiUrl = () => {
  // Hardcoded para test del APK en el celular
  return (import.meta.env.VITE_API_URL || 'http://localhost:3001').replace(/\/api$/, '')
}
const API_URL = getApiUrl()

// ============================================
// ÁREA DE SERVICIO — Bucaramanga y área metropolitana
// ============================================
const SERVICE_AREA = { south: 6.88, north: 7.62, west: -73.38, east: -72.90 }
const isInsideServiceArea = (lat, lng) =>
  lat >= SERVICE_AREA.south && lat <= SERVICE_AREA.north &&
  lng >= SERVICE_AREA.west  && lng <= SERVICE_AREA.east

// ============================================
// TOAST
// ============================================
const toastMsg = ref('')
let toastTimer = null
const showOutOfAreaToast = () => {
  clearTimeout(toastTimer)
  toastMsg.value = 'Este lugar está fuera del área de servicio. BucaraBus opera en Bucaramanga y su área metropolitana.'
  toastTimer = setTimeout(() => { toastMsg.value = '' }, 4000)
}

// ============================================
// STATE DE NAVEGACIÓN
// ============================================
const currentView = ref('home') // 'home' | 'catalog'
const isMenuOpen  = ref(false)

const handleNavigate = (view) => {
  currentView.value = view
  if (view === 'home') {
    // Si regresamos al mapa, asegurar que el tamaño se recalcule
    if (mapVisible.value) {
      nextTick(() => { setTimeout(() => getMap()?.invalidateSize(), 300) })
    }
  }
}

const handleViewRouteOnMap = async (route) => {
  currentView.value = 'home'
  mapVisible.value = true
  
  // Limpiamos los marcadores de la sugerencia anterior si existen
  clearRouteMarkers()
  
  // Limpiamos cualquier otra ruta dibujada previamente para que no se superpongan
  clearAllRoutePaths()
  
  // Ocultamos el panel inferior para que se vea mejor el mapa completo
  panelHidden.value = true
  
  await nextTick()
  
  // Esperar a que la transición CSS de la vista termine (300ms)
  setTimeout(() => {
    const map = getMap()
    if (map) {
      map.invalidateSize() // Forzar a Leaflet a recalcular su tamaño real
      
      drawRoutePath(route) // Dibujar la línea de la ruta
      
      // Enfocamos el mapa en los puntos de la ruta usando las dimensiones correctas
      if (route.path && route.path.length > 0) {
        const coords = route.path.map(p => Math.abs(p[0]) < 20 ? [p[0], p[1]] : [p[1], p[0]])
        map.fitBounds(coords, { padding: [50, 50] })
      }
    }
  }, 350)
}

const activeBuses = ref({})
const isLoading   = ref(true)
const mapVisible  = ref(false)

// ============================================
// ORIGIN STATE (punto de partida manual)
// ============================================
const originQuery      = ref('')
const originResults    = ref([])
const selectedOrigin   = ref(null)
const userLocationName = ref('')
let originSearchTimer  = null
let reverseGeoTimer    = null

const reverseGeocodeUserLocation = async (loc) => {
  clearTimeout(reverseGeoTimer)
  reverseGeoTimer = setTimeout(async () => {
    try {
      const baseUrl = API_URL.endsWith('/') ? API_URL.slice(0, -1) : API_URL
      const res  = await fetch(`${baseUrl || ''}/api/geocoding/reverse?lat=${loc.lat}&lng=${loc.lng}`)
      const data = await res.json()
      if (data.success && data.name) userLocationName.value = data.name
    } catch (e) { console.warn('No se pudo obtener la dirección del GPS:', e) }
  }, 800)
}

// ============================================
// COMPOSABLES
// ============================================
const {
  mapRef, selectedBus, selectedSuggestedRoute,
  panelExpanded, panelHidden,
  getMap, initMap, destroyMap,
  updateBusMarker, removeBusMarker,
  updateUserMarker, centerOnUser,
  drawRoutePath, selectBus, showRouteOnMap,
  selectBusFromRoute, togglePanel, clearRouteMarkers,
  clearAllRoutePaths,
  distanceAlongRoute,
  addIncidentMarker
} = usePassengerMap()

const { userLocation, requestLocation, stopWatchingLocation } = usePassengerGeolocation(
  (loc) => {
    if (!selectedOrigin.value) updateUserMarker(loc)
    reverseGeocodeUserLocation(loc)
  },
  (loc) => { if (!selectedOrigin.value) centerOnUser(loc) }
)

const { cachedRoutes, isOffline, loadRoutesWithCache } = useRoutesCache(API_URL)

const { suggestedRoutes, findBestRoutes, normalizeRouteId, clearRoutes } = useRouteSearch()

const {
  searchQuery, searchResults, showSearchResults, selectedDestination,
  searchDestination, selectDestination, clearDestination
} = useNominatim(API_URL, getMap)

const originLocation = computed(() => selectedOrigin.value ?? userLocation.value)

// ============================================
// VELOCIDAD PROMEDIO RODANTE (anti-semáforos)
// ============================================
const busPositionHistory = {}
const HISTORY_SIZE       = 5
const FLOOR_SPEED_KMH    = 18

const getRollingSpeed = (busId) => {
  const hist = busPositionHistory[busId]
  if (!hist || hist.length < 2) return FLOOR_SPEED_KMH
  let totalDist = 0, totalTime = 0
  for (let i = 1; i < hist.length; i++) {
    const prev = hist[i - 1], curr = hist[i]
    const dt = (curr.ts - prev.ts) / 1000
    if (dt <= 0) continue
    totalDist += calculateDistance(prev.lat, prev.lng, curr.lat, curr.lng)
    totalTime += dt
  }
  if (totalTime === 0) return FLOOR_SPEED_KMH
  return Math.max((totalDist / totalTime) * 3.6, FLOOR_SPEED_KMH)
}

const { isConnected, connect, disconnect } = usePassengerSocket(API_URL, {
  onBusUpdate: (data) => {
    const route  = cachedRoutes.value.find(r => r.id === data.routeId)
    const busData = {
      busId: data.busId, plate: data.plate || activeBuses.value[data.busId]?.plate || 'Bus',
      driverId: data.driverId, routeId: data.routeId,
      routeName: route?.name || data.routeName || 'Ruta',
      routeColor: route?.color || data.routeColor || '#667eea',
      lat: data.latitude, lng: data.longitude, speed: data.speed || 0,
      lastUpdate: new Date(), routePath: route?.path || null
    }
    if (!busPositionHistory[data.busId]) busPositionHistory[data.busId] = []
    busPositionHistory[data.busId].push({ lat: data.latitude, lng: data.longitude, ts: Date.now() })
    if (busPositionHistory[data.busId].length > HISTORY_SIZE) busPositionHistory[data.busId].shift()
    activeBuses.value[data.busId] = busData
    updateBusMarker(busData)
    if (selectedBus.value?.busId === data.busId) selectBus(busData, userLocation.value)
  },
  onShiftEnded: (data) => {
    delete activeBuses.value[data.busId]
    removeBusMarker(data.busId)
    if (selectedBus.value?.busId === data.busId) selectedBus.value = null
  },
  onIncidentReported: (incident) => {
    addIncidentMarker(incident)
  }
})

// ============================================
// COMPUTED
// ============================================
const nearbyBuses = computed(() => {
  if (!userLocation.value) return []
  return Object.values(activeBuses.value)
    .map(bus => ({ ...bus, distanceMeters: calculateDistance(userLocation.value.lat, userLocation.value.lng, bus.lat, bus.lng) }))
    .filter(bus => bus.distanceMeters < 5000)
    .sort((a, b) => a.distanceMeters - b.distanceMeters)
    .slice(0, 10)
    .map(bus => ({ ...bus, distance: formatDistance(bus.distanceMeters), eta: calculateETA(bus.distanceMeters, bus.speed || 20) }))
})

const activeBusesOnSelectedRoute = computed(() => {
  if (!selectedSuggestedRoute.value || !userLocation.value) return []
  const routeId     = selectedSuggestedRoute.value.route.id
  const pickupPoint = selectedSuggestedRoute.value.pickupPoint
  const routePath   = selectedSuggestedRoute.value.route.path || null

  return Object.values(activeBuses.value)
    .filter(bus => normalizeRouteId(bus.routeId) === normalizeRouteId(routeId))
    .map(bus => {
      const distToPickup  = distanceAlongRoute(bus.lat, bus.lng, pickupPoint.lat, pickupPoint.lng, routePath)
      const rollingSpeed  = getRollingSpeed(bus.busId)
      const etaMinutes    = Math.round(distToPickup / (rollingSpeed / 3.6) / 60)
      const etaLabel      = etaMinutes <= 1 ? '< 1 min' : etaMinutes <= 60 ? `~${etaMinutes} min` : `~${Math.round(etaMinutes / 60)} h`
      const etaArrivalTime = new Date(Date.now() + etaMinutes * 60 * 1000)
        .toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', hour12: true })
      return { ...bus, distanceToPickup: formatDistance(distToPickup), etaToPickup: etaLabel, etaArrivalTime, etaMinutes, rollingSpeedKmh: Math.round(rollingSpeed) }
    })
    .sort((a, b) => a.etaMinutes - b.etaMinutes)
})

// ============================================
// EVENT HANDLERS
// ============================================
const handleLocate = () => { if (userLocation.value) centerOnUser(userLocation.value); else requestLocation() }

const onSearchOrigin = (value) => {
  originQuery.value = value
  if (!value || value.length < 2) { originResults.value = []; return }
  clearTimeout(originSearchTimer)
  originSearchTimer = setTimeout(async () => {
    try {
      const res  = await fetch(`${API_URL}/api/geocoding/search?q=${encodeURIComponent(value)}`)
      const data = await res.json()
      if (data.success) originResults.value = data.data
    } catch (e) { console.error('Error buscando origen:', e) }
  }, 500)
}

const handleSelectOrigin = (place) => {
  if (!isInsideServiceArea(place.lat, place.lng)) { showOutOfAreaToast(); return }
  selectedOrigin.value = place
  originQuery.value    = place.name
  originResults.value  = []
  const loc = { lat: place.lat, lng: place.lng }
  updateUserMarker(loc)
  centerOnUser(loc)
  if (selectedDestination.value) findBestRoutes(place, selectedDestination.value, cachedRoutes.value, activeBuses.value)
}

const handleClearOrigin = () => {
  selectedOrigin.value = null
  originQuery.value    = ''
  originResults.value  = []
  if (userLocation.value) { updateUserMarker(userLocation.value); centerOnUser(userLocation.value) }
  if (selectedDestination.value && userLocation.value) findBestRoutes(userLocation.value, selectedDestination.value, cachedRoutes.value, activeBuses.value)
}

const handleSwap = () => {
  const prevOrigin = selectedOrigin.value, prevOriginQ = originQuery.value
  const prevDest   = selectedDestination.value, prevDestQ = searchQuery.value

  if (prevDest) {
    selectedOrigin.value = prevDest; originQuery.value = prevDestQ
    updateUserMarker({ lat: prevDest.lat, lng: prevDest.lng })
    centerOnUser({ lat: prevDest.lat, lng: prevDest.lng })
  } else { selectedOrigin.value = null; originQuery.value = '' }

  if (prevOrigin) {
    selectDestination(prevOrigin, () => { findBestRoutes(originLocation.value, prevOrigin, cachedRoutes.value, activeBuses.value) })
  } else if (userLocation.value) {
    const gpsDestino = { name: 'Mi ubicación', lat: userLocation.value.lat, lng: userLocation.value.lng }
    selectDestination(gpsDestino, () => { findBestRoutes(originLocation.value, gpsDestino, cachedRoutes.value, activeBuses.value) })
  } else {
    clearDestination(() => { clearRoutes(); clearRouteMarkers() })
    mapVisible.value = false
  }
}

const onSearchDestination    = (value) => { searchQuery.value = value; searchDestination() }

const handleSelectDestination = (destination) => {
  if (!isInsideServiceArea(destination.lat, destination.lng)) { showOutOfAreaToast(); return }
  selectDestination(destination, () => { findBestRoutes(originLocation.value, destination, cachedRoutes.value, activeBuses.value) })
}

const handleClearDestination = () => {
  clearDestination(() => { clearRoutes(); clearRouteMarkers() })
  mapVisible.value = false
}

const showMap = () => {
  mapVisible.value = true
  return new Promise(resolve => {
    nextTick(() => {
      // 350ms es mayor que la transición CSS (0.3s) para garantizar que el contenedor tenga tamaño real
      setTimeout(() => {
        getMap()?.invalidateSize()
        resolve()
      }, 350)
    })
  })
}

const handleSelectRoute = async (suggestion) => {
  await showMap()
  // Limpiar marcadores de abordaje/bajada y todas las polilíneas previas
  clearRouteMarkers()
  clearAllRoutePaths()
  drawRoutePath(suggestion.route)
  showRouteOnMap(suggestion, userLocation.value, selectedDestination.value)
}
const handleSelectBusFromRoute = (bus) => { selectBusFromRoute(bus, userLocation.value) }
const handleSelectBusNearby  = async (bus) => {
  await showMap()
  selectBus(bus, userLocation.value)
}
const handleBackToList       = () => { clearRouteMarkers(); selectedBus.value = null; mapVisible.value = false }

// ============================================
// DATA LOADING
// ============================================
const loadRoutes = async () => {
  await loadRoutesWithCache()
}

const loadActiveShifts = async () => {
  try {
    const response = await fetch(`${API_URL}/api/shifts`)
    const data     = await response.json()
    if (data.success && data.data) {
      data.data.forEach(shift => {
        let lat = shift.current_lat, lng = shift.current_lng
        if (!lat || !lng) {
          try {
            if (shift.path_geojson) {
              const geojson = JSON.parse(shift.path_geojson)
              if (geojson.coordinates?.length > 0) {
                const p = geojson.coordinates[0]
                lat = Math.abs(p[0]) > 20 ? p[1] : p[0]
                lng = Math.abs(p[0]) > 20 ? p[0] : p[1]
              }
            }
          } catch (e) { console.error('Error parsing path_geojson:', e) }
        }
        if (lat && lng) {
          const busId = shift.id_bus || shift.plate_number
          activeBuses.value[busId] = {
            busId, plate: shift.plate_number, driverId: shift.id_user,
            driverName: shift.name_driver, routeId: shift.id_route,
            routeName: shift.name_route || 'Ruta', routeColor: shift.color_route || '#667eea',
            lat, lng, speed: shift.current_speed || 0, lastUpdate: new Date()
          }
        }
      })
      Object.values(activeBuses.value).forEach(updateBusMarker)
    }
  } catch (error) { console.error('Error loading shifts:', error) }
  finally { isLoading.value = false }
}

const loadActiveIncidents = async () => {
  try {
    const response = await fetch(`${API_URL}/api/incidents?status=active`)
    const data     = await response.json()
    if (data.success && data.data) {
      // Necesita timeout breve para asegurar que leafletMap está listo
      setTimeout(() => {
        data.data.forEach(incident => addIncidentMarker(incident))
      }, 500)
    }
  } catch (error) { console.error('Error loading incidents:', error) }
}

// ============================================
// WATCHERS
// ============================================
watch([userLocation, activeBuses, cachedRoutes], () => {
  if (selectedDestination.value) findBestRoutes(originLocation.value, selectedDestination.value, cachedRoutes.value, activeBuses.value)
}, { deep: true })

// ============================================
// LIFECYCLE
// ============================================
onMounted(async () => { initMap(); await loadRoutes(); await loadActiveShifts(); await loadActiveIncidents(); connect(); requestLocation() })
onUnmounted(() => { disconnect(); stopWatchingLocation(); destroyMap() })
</script>

<style scoped>
.passenger-app {
  height: 100vh;
  height: 100dvh;
  display: flex;
  flex-direction: column;
  background: #f5f7fa;
  position: relative;
  overflow: hidden;
}
.home-view {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow: hidden;
}
.catalog-view {
  flex: 1;
  overflow: hidden;
}
.search-bar-wrapper {
  background: white;
  padding: 10px 14px 6px;
  box-shadow: 0 2px 6px rgba(0,0,0,0.08);
  position: relative;
  z-index: 800;
  flex-shrink: 0;
}
.search-bar-wrapper :deep(.destination-search) { position: static; top: auto; left: auto; right: auto; }
.content-area { flex: 1; overflow-y: auto; background: #f5f7fa; }
.no-routes-msg { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 56px 24px; gap: 12px; color: #6b7280; font-size: 0.95rem; text-align: center; }
.no-routes-msg span { font-size: 2.5rem; }
.map-container { flex: 1; position: relative; transition: flex 0.3s ease, height 0.3s ease; }
.btn-back-list { position: absolute; top: 12px; left: 12px; z-index: 500; background: white; border: none; border-radius: 20px; padding: 8px 16px; font-size: 0.88rem; font-weight: 600; color: #374151; box-shadow: 0 2px 8px rgba(0,0,0,0.18); cursor: pointer; transition: background 0.2s; }
.btn-back-list:hover { background: #f3f4f6; }
.map-hidden { flex: 0 !important; height: 0 !important; overflow: hidden; }
.map { width: 100%; height: 100%; }
.loading-overlay { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: rgba(255,255,255,0.9); display: flex; flex-direction: column; align-items: center; justify-content: center; z-index: 500; }
.spinner { width: 40px; height: 40px; border: 3px solid #e0e0e0; border-top-color: #667eea; border-radius: 50%; animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
:deep(.bus-marker) { background: transparent !important; border: none !important; }
:deep(.bus-marker-inner) { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; box-shadow: 0 2px 8px rgba(0,0,0,0.3); border: 2px solid white; }
:deep(.user-marker) { background: transparent !important; border: none !important; }
:deep(.user-marker-inner) { font-size: 2rem; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3)); }
@media (min-width: 768px) { .passenger-app { max-width: 500px; margin: 0 auto; box-shadow: 0 0 30px rgba(0,0,0,0.1); } }
.toast-out-of-area { position: absolute; bottom: 80px; left: 16px; right: 16px; z-index: 1000; background: #1e293b; color: white; border-radius: 12px; padding: 12px 16px; display: flex; align-items: flex-start; gap: 10px; font-size: 0.875rem; line-height: 1.4; box-shadow: 0 4px 16px rgba(0,0,0,0.3); }
.toast-icon { font-size: 1.1rem; flex-shrink: 0; margin-top: 1px; }
.toast-fade-enter-active { transition: opacity 0.25s ease, transform 0.25s ease; }
.toast-fade-leave-active { transition: opacity 0.2s ease, transform 0.2s ease; }
.toast-fade-enter-from   { opacity: 0; transform: translateY(12px); }
.toast-fade-leave-to     { opacity: 0; transform: translateY(8px); }
</style>

<!-- Estilos globales para tooltips de Leaflet (no scoped) -->
<style>
.stop-tooltip { background: white !important; border: none !important; border-radius: 8px !important; box-shadow: 0 3px 10px rgba(0,0,0,0.18) !important; font-size: 12px !important; font-weight: 600 !important; padding: 5px 10px !important; white-space: nowrap !important; }
.stop-tooltip::before { display: none !important; }
.pickup-tooltip  { color: #10b981 !important; }
.dropoff-tooltip { color: #ef4444 !important; }
.dest-tooltip { background: white !important; border: none !important; border-radius: 8px !important; box-shadow: 0 3px 10px rgba(0,0,0,0.18) !important; font-size: 12px !important; font-weight: 600 !important; padding: 5px 10px !important; white-space: nowrap !important; color: #f97316 !important; }
.dest-tooltip::before { display: none !important; }
</style>

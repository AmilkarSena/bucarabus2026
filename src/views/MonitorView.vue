<template>
  <div class="monitor-widget" :class="{ collapsed: isCollapsed }">
    <div class="widget-card">
      <!-- Header compacto (siempre visible) -->
      <div class="widget-header" @click="toggleCollapse">
        <div class="header-left">
          <h3>📍 Monitor</h3>
          <!-- Stats mini cuando está colapsado -->
          <div v-if="isCollapsed" class="mini-stats">
            <span class="mini-stat">🚌 {{ activeRoutesData.reduce((sum, r) => sum + r.busesActivos, 0) }}</span>
            <span class="mini-stat">🚦 {{ activeRoutesData.length }}</span>
            <span class="mini-stat">✅ {{ getTotalTripsCompleted() }}</span>
          </div>
          <!-- Botón ver todas las rutas -->
          <button 
            v-if="!isCollapsed && activeRoutesData.length > 0"
            class="show-all-btn"
            @click.stop="toggleAllRoutes"
            :title="allRoutesVisible ? 'Ocultar todas las rutas' : 'Mostrar todas las rutas'"
          >
            {{ allRoutesVisible ? '👁️ Ocultar' : '👁️ Ver todas' }}
          </button>
        </div>
        <div class="header-indicators">
          <span 
            class="ws-indicator" 
            :class="{ connected: isConnected, disconnected: !isConnected }"
            :title="isConnected ? 'WebSocket conectado' : 'WebSocket desconectado'"
          >
            {{ isConnected ? '🟢' : '🔴' }}
          </span>
          <span v-if="!isCollapsed" class="live-indicator">🔴 EN VIVO</span>
          <button class="collapse-btn" :title="isCollapsed ? 'Expandir' : 'Minimizar'">
            {{ isCollapsed ? '▼' : '▲' }}
          </button>
        </div>
      </div>

      <!-- Contenido expandible -->
      <div v-show="!isCollapsed" class="widget-body">
        <div class="monitor-stats-grid">
          <div class="monitor-stat-card">
            <div class="stat-label">Buses Activos</div>
            <div class="stat-number">
              {{ activeRoutesData.reduce((sum, r) => sum + r.busesActivos, 0) }}
            </div>
          </div>
          <div class="monitor-stat-card">
            <div class="stat-label">Rutas Activas</div>
            <div class="stat-number">{{ activeRoutesData.length }}</div>
          </div>
          <div class="monitor-stat-card">
            <div class="stat-label">Viajes Completados</div>
            <div class="stat-number">
              {{ getTotalTripsCompleted() }}
            </div>
          </div>
        </div>

        <!-- Pestañas -->
        <div class="monitor-tabs">
          <button 
            class="monitor-tab" 
            :class="{ active: activeTab === 'routes' }" 
            @click.stop="activeTab = 'routes'"
          >
            🚦 Rutas
          </button>
          <button 
            class="monitor-tab" 
            :class="{ active: activeTab === 'incidents' }" 
            @click.stop="activeTab = 'incidents'"
          >
            🚨 Incidentes
            <span v-if="incidentsStore.activeIncidents.length > 0" class="tab-badge">
              {{ incidentsStore.activeIncidents.length }}
            </span>
          </button>
        </div>

        <!-- Tab: Rutas -->
        <div v-show="activeTab === 'routes'" class="active-routes-cards">
          <div class="section-title">
            <h4>🚦 Rutas en Línea</h4>
            <span class="refresh-btn" @click.stop="loadActiveRoutes">🔄</span>
          </div>

          <!-- Chips de filtro por estado -->
          <div class="filter-chips" @click.stop>
            <button
              v-for="chip in STATUS_CHIPS"
              :key="chip.key"
              class="chip"
              :class="{ 'chip-active': statusFilter === chip.key }"
              @click="statusFilter = chip.key"
            >
              {{ chip.icon }} {{ chip.label }}
            </button>
          </div>

          <!-- Barra de búsqueda -->
          <div class="search-container" @click.stop>
            <div class="search-input-wrapper">
              <span class="search-icon">🔍</span>
              <input 
                type="text"
                v-model="searchQuery"
                placeholder="Buscar por ruta, placa o conductor..."
                class="search-input"
                @input="handleSearch"
              >
              <button 
                v-if="searchQuery"
                class="clear-search"
                @click="clearSearch"
                title="Limpiar búsqueda"
              >
                ✕
              </button>
            </div>
            <div v-if="searchQuery" class="search-results-info">
              {{ filteredRoutes.length }} {{ filteredRoutes.length === 1 ? 'resultado' : 'resultados' }}
            </div>
          </div>
          <div class="cards-grid" @click.stop>
            <MonitorRouteCard 
              v-for="route in filteredRoutes" 
              :key="route.id"
              :route="route"
              :filteredBuses="getFilteredBuses(route)"
              :isExpanded="expandedRoutes.has(route.id)"
              :isVisibleOnMap="isRouteVisible(route.id)"
              :activeGpsCount="getActiveGPSCount(route)"
              :tripsCompleted="getRouteTripsCompleted(route)"
              :searchQuery="searchQuery"
              @toggle-visibility="toggleRouteVisibility"
              @toggle-expand="toggleExpand"
              @focus-route="focusRoute($event.id, $event.path, $event.color, $event.name)"
              @view-details="viewRouteDetails"
            />

            <div v-if="filteredRoutes.length === 0 && searchQuery" class="empty-state-card">
              <div class="empty-icon">🔍</div>
              <p>No se encontraron resultados</p>
              <small>Intenta con otro término de búsqueda</small>
              <button class="clear-search-btn" @click="clearSearch">Limpiar búsqueda</button>
            </div>

            <div v-else-if="activeRoutesData.length === 0" class="empty-state-card">
              <div class="empty-icon">🚫</div>
              <p>No hay rutas activas</p>
              <small>Inicia un viaje para ver rutas en línea</small>
            </div>
          </div>
        </div>

        <!-- Tab: Incidentes -->
        <div v-show="activeTab === 'incidents'" class="incidents-panel">
          <div class="section-title">
            <h4>🚨 Incidentes Activos</h4>
            <span class="refresh-btn" @click.stop="incidentsStore.fetchActiveIncidents()">🔄</span>
          </div>

          <div v-if="incidentsStore.loading" class="empty-state-card">
            <p>Cargando incidentes...</p>
          </div>

          <div v-else-if="incidentsStore.activeIncidents.length === 0" class="empty-state-card">
            <div class="empty-icon">✅</div>
            <p>Sin incidentes activos</p>
            <small>No hay incidentes reportados en este momento</small>
          </div>

          <div v-else class="incidents-list">
            <div 
              v-for="incident in incidentsStore.activeIncidents" 
              :key="incident.id" 
              class="incident-card"
            >
              <div class="incident-header">
                <span class="incident-name">{{ incident.tag || '🚧' }} {{ incident.name || 'Incidente' }}</span>
                <span class="incident-time">{{ formatIncidentTime(incident.created_at) }}</span>
              </div>
              <div v-if="incident.descrip" class="incident-descrip">{{ incident.descrip }}</div>
              <div class="incident-meta">
                <span class="incident-location" :title="`${incident.lat}, ${incident.lng}`">
                  📍 {{ incident.address || `${Number(incident.lat).toFixed(4)}, ${Number(incident.lng).toFixed(4)}` }}
                </span>
                <span class="incident-status active">● Activo</span>
              </div>
              <div class="incident-actions">
                <button 
                  class="resolve-btn" 
                  @click.stop="handleResolve(incident.id)"
                  :disabled="resolvingId === incident.id"
                >
                  {{ resolvingId === incident.id ? '⏳ Resolviendo...' : '✅ Resolver' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useAppStore } from '../stores/app'
import { useBusesStore } from '../stores/buses'
import { useRoutesStore } from '../stores/routes'
import { useIncidentsStore } from '../stores/incidents'
import { useWebSocket } from '../composables/useWebSocket'
import { getActiveShifts } from '../api/shifts'
import MonitorRouteCard from '../components/monitor/MonitorRouteCard.vue'

const appStore = useAppStore()
const busesStore = useBusesStore()
const routesStore = useRoutesStore()
const incidentsStore = useIncidentsStore()

// 🆕 Datos y WebSockets (Extraído a Composable)
import { useMonitorData } from '../composables/useMonitorData'
const { 
  activeRoutesData, 
  isConnected, 
  wsLocations 
} = useMonitorData()

// 🆕 Filtros y Búsqueda (Extraído a Composable)
import { useMonitorFilters } from '../composables/useMonitorFilters'
const {
  searchQuery,
  statusFilter,
  filteredRoutes,
  getFilteredBuses,
  handleSearch,
  clearSearch
} = useMonitorFilters(activeRoutesData)
const isCollapsed = ref(false) // Estado colapsado
const allRoutesVisible = ref(false) // Todas las rutas visibles
const expandedRoutes = ref(new Set()) // Rutas con lista de buses expandida
const activeTab = ref('routes') // Pestaña activa
const resolvingId = ref(null) // ID del incidente en proceso de resolución
let refreshInterval = null

const STATUS_CHIPS = [
  { key: 'activos',      label: 'Activos',     icon: '🟢' },
  { key: 'programados',  label: 'Programados', icon: '📅' },
  { key: 'finalizados',  label: 'Finalizados', icon: '✅' },
  { key: 'todos',        label: 'Todos',       icon: '🚦' },
]

// Toggle colapsar/expandir
const toggleCollapse = () => {
  isCollapsed.value = !isCollapsed.value
}

// Mostrar/ocultar todas las rutas activas
const toggleAllRoutes = () => {
  if (allRoutesVisible.value) {
    // Ocultar todas
    activeRoutesData.value.forEach(route => {
      routesStore.deactivateRoute(route.id)
    })
    allRoutesVisible.value = false
    console.log('👁️ Todas las rutas ocultas')
  } else {
    // Mostrar todas
    showAllActiveRoutes()
  }
}

// Mostrar todas las rutas activas en el mapa
const showAllActiveRoutes = () => {
  activeRoutesData.value.forEach(route => {
    // Activar ruta en el store usando el ID numérico
    routesStore.activateRoute(route.id)
    
    // Si la ruta no existe en el store, agregarla temporalmente con su path
    if (!routesStore.routes[route.id] && route.path) {
      routesStore.routes[route.id] = {
        id: route.id,
        name: route.name,
        color: route.color,
        path: route.path,
        visible: true,
        description: '',
        stops: [],
        buses: []
      }
    }
  })
  allRoutesVisible.value = true
  console.log('👁️ Mostrando todas las rutas activas:', activeRoutesData.value.length)
}

// Computed properties para la UI
const activeBusesCount = computed(() => busesStore.activeBuses.length)
const totalRoutesCount = computed(() => routesStore.routesCount)

// Expandir / colapsar lista de buses de una ruta
const toggleExpand = (routeId) => {
  const next = new Set(expandedRoutes.value)
  if (next.has(routeId)) {
    next.delete(routeId)
  } else {
    next.add(routeId)
  }
  expandedRoutes.value = next
}

// Obtener total de viajes completados de una ruta
const getRouteTripsCompleted = (route) => {
  if (!route.buses || route.buses.length === 0) return 0
  return route.buses.reduce((sum, bus) => sum + (bus.viajes_completados || 0), 0)
}

// Obtener cantidad de buses con GPS activo en una ruta
const getActiveGPSCount = (route) => {
  if (!route.buses || route.buses.length === 0) return 0
  return route.buses.filter(bus => bus.gps_active).length
}

// Obtener total de viajes completados de todas las rutas
const getTotalTripsCompleted = () => {
  return activeRoutesData.value.reduce((sum, route) => 
    sum + getRouteTripsCompleted(route), 0
  )
}


// Métodos existentes
const openBusModal = () => {
  appStore.openModal('bus')
}

const openRouteModal = () => {
  appStore.openModal('route')
}

const viewAllRoutes = () => {
  routesStore.clearActiveRoutes()
  Object.keys(routesStore.routes).forEach(routeId => {
    routesStore.activateRoute(routeId)
  })
}

const focusRoute = (routeId, path, color, name) => {
  console.log('📍 Enfocando ruta:', routeId)
  
  // Agregar ruta al store si no existe
  if (!routesStore.routes[routeId] && path) {
    routesStore.routes[routeId] = {
      id: routeId,
      name: name,
      color: color,
      path: path,
      visible: true,
      description: '',
      stops: [],
      buses: []
    }
  }
  
  routesStore.activateRoute(routeId)
}

const viewRouteDetails = (routeId) => {
  console.log('📊 Ver detalles de ruta:', routeId)
  appStore.openModal('route', { id: routeId })
}

// Verificar si una ruta está visible en el mapa
const isRouteVisible = (routeId) => {
  // Verificar si está en activeRoutes del store
  return routesStore.activeRoutes.has(routeId)
}

// Toggle visibilidad de ruta en el mapa
const toggleRouteVisibility = (route) => {
  const routeId = route.id
  
  // Agregar al store si no existe
  if (!routesStore.routes[routeId] && route.path) {
    routesStore.routes[routeId] = {
      id: routeId,
      name: route.name,
      color: route.color,
      path: route.path,
      visible: true,
      description: '',
      stops: [],
      buses: []
    }
  }
  
  if (routesStore.activeRoutes.has(routeId)) {
    routesStore.deactivateRoute(routeId)
    console.log(`👁️ Ruta ${routeId} oculta en el mapa`)
  } else {
    routesStore.activateRoute(routeId)
    console.log(`👁️ Ruta ${routeId} visible en el mapa`)
  }
}

// 🆕 Auto-mostrar rutas en el mapa la primera vez que se cargan
watch(() => activeRoutesData.value.length, (newLength, oldLength) => {
  if (newLength > 0 && oldLength === 0 && !allRoutesVisible.value) {
    showAllActiveRoutes()
  }
})

// 🆕 Watch para actualizaciones de ubicación en tiempo real
watch(wsLocations, (newLocations) => {
  if (newLocations.length > 0) {
    console.log('📍 Actualización de ubicaciones:', newLocations.length)
    // Aquí podrías actualizar los marcadores en el mapa
  }
}, { deep: true })

// Incidentes
const formatIncidentTime = (dateStr) => {
  if (!dateStr) return ''
  const d = new Date(dateStr)
  return d.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' })
}

const handleResolve = async (id) => {
  resolvingId.value = id
  await incidentsStore.markAsResolved(id)
  resolvingId.value = null
}

onMounted(() => {
  incidentsStore.fetchActiveIncidents()
})
</script>

<style scoped>
.monitor-widget {
  max-width: 400px;
  /* Limitar la altura al espacio disponible del overlay (100% del contenedor padre) */
  max-height: 100%;
  display: flex;
  flex-direction: column;
  transition: all 0.3s ease;
}

.monitor-widget.collapsed {
  max-width: 320px;
}

.widget-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  border-radius: 16px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
  /* flex column para que el body ocupe el espacio restante */
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.3);
  /* Crecer hasta llenar el monitor-widget pero sin salirse */
  max-height: 100%;
}

.widget-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 12px 16px;
  color: white;
  display: flex;
  justify-content: space-between;
  align-items: center;
  cursor: pointer;
  user-select: none;
  transition: padding 0.3s ease;
}

.monitor-widget.collapsed .widget-header {
  padding: 10px 14px;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
}

.widget-header h3 {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  white-space: nowrap;
}

/* Mini stats cuando está colapsado */
.mini-stats {
  display: flex;
  gap: 10px;
  animation: fadeIn 0.3s ease;
}

.mini-stat {
  font-size: 12px;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.2);
  padding: 3px 8px;
  border-radius: 10px;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateX(-10px); }
  to { opacity: 1; transform: translateX(0); }
}

/* Botón mostrar todas las rutas */
.show-all-btn {
  background: rgba(255, 255, 255, 0.25);
  border: 1px solid rgba(255, 255, 255, 0.4);
  color: white;
  padding: 4px 10px;
  border-radius: 8px;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.show-all-btn:hover {
  background: rgba(255, 255, 255, 0.4);
  transform: scale(1.05);
}

.show-all-btn:active {
  transform: scale(0.95);
}

.header-indicators {
  display: flex;
  align-items: center;
  gap: 8px;
}

.collapse-btn {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.collapse-btn:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: scale(1.1);
}

/* Indicador de WebSocket */
.ws-indicator {
  padding: 4px 8px;
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
}

.ws-indicator.connected {
  background: rgba(16, 185, 129, 0.3);
}

.ws-indicator.disconnected {
  background: rgba(239, 68, 68, 0.3);
}

.live-indicator {
  padding: 4px 10px;
  background: rgba(239, 68, 68, 0.2);
  color: white;
  border-radius: 12px;
  font-size: 10px;
  font-weight: 600;
  animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

/* Transición de deslizamiento */
.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease;
  max-height: 600px;
  overflow: hidden;
}

.slide-enter-from,
.slide-leave-to {
  max-height: 0;
  opacity: 0;
}

/* Widget body - ocupa el espacio restante y hace scroll */
.widget-body {
  flex: 1;
  overflow-y: auto;
  /* Scrollbar fina para no ocupar espacio */
  scrollbar-width: thin;
  scrollbar-color: #cbd5e1 transparent;
}

.widget-body::-webkit-scrollbar {
  width: 6px;
}
.widget-body::-webkit-scrollbar-track {
  background: transparent;
}
.widget-body::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 10px;
}

.monitor-stats-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0;
  border-bottom: 1px solid #e2e8f0;
}

.monitor-stat-card {
  padding: 20px 16px;
  text-align: center;
  border-right: 1px solid #e2e8f0;
  transition: all 0.2s ease;
}

.monitor-stat-card:last-child {
  border-right: none;
}

.monitor-stat-card:hover {
  background: #f8fafc;
}

.stat-label {
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 8px;
  font-weight: 500;
}

.stat-number {
  font-size: 28px;
  font-weight: 700;
  color: #667eea;
  line-height: 1;
}

.active-routes-cards {
  padding: 20px;
  background: #f8fafc;
}

.section-title {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.section-title h4 {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  color: #334155;
}

.refresh-btn {
  cursor: pointer;
  font-size: 18px;
  transition: transform 0.3s;
}

.refresh-btn:hover {
  transform: rotate(180deg);
}

/* 🆕 Estilos de búsqueda */
.search-container {
  margin-bottom: 16px;
}

.search-input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.search-icon {
  position: absolute;
  left: 12px;
  font-size: 16px;
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 10px 40px 10px 40px;
  border: 2px solid #e2e8f0;
  border-radius: 10px;
  font-size: 13px;
  transition: all 0.3s;
  background: white;
}

.search-input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.clear-search {
  position: absolute;
  right: 8px;
  width: 24px;
  height: 24px;
  border: none;
  background: #e2e8f0;
  color: #64748b;
  border-radius: 50%;
  cursor: pointer;
  font-size: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.clear-search:hover {
  background: #cbd5e1;
  color: #334155;
}

.search-results-info {
  margin-top: 8px;
  font-size: 12px;
  color: #64748b;
  text-align: center;
}

/* Resaltado de texto */
:deep(.highlight) {
  background: #fef08a;
  color: #854d0e;
  padding: 2px 4px;
  border-radius: 3px;
  font-weight: 600;
}

.clear-search-btn {
  margin-top: 16px;
  padding: 8px 16px;
  border: none;
  background: #667eea;
  color: white;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.clear-search-btn:hover {
  background: #5a67d8;
  transform: translateY(-1px);
}

.cards-grid {
  display: grid;
  gap: 16px;
  max-height: 500px;
  overflow-y: auto;
}

.route-card {
  background: white;
  border-radius: 12px;
  border-left: 4px solid #667eea;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 0.3s;
  animation: slideIn 0.5s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.route-card:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
  transform: translateY(-2px);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  gap: 12px;
}

.card-header-left {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
  min-width: 0;
}

.card-header h5 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.status-badges {
  display: flex;
  gap: 6px;
  flex-shrink: 0;
}

.toggle-route-visibility {
  background: #f1f5f9;
  border: none;
  border-radius: 8px;
  padding: 6px 10px;
  font-size: 16px;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  justify-content: center;
  min-width: 36px;
  height: 36px;
}

.toggle-route-visibility:hover {
  background: #667eea;
  transform: scale(1.1);
}

.toggle-route-visibility:active {
  transform: scale(0.95);
}

.toggle-route-visibility.route-visible {
  background: #d1fae5;
  color: #065f46;
}

.toggle-route-visibility.route-visible:hover {
  background: #10b981;
}

.status-badge {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  white-space: nowrap;
}

.status-badge.online {
  background: #d1fae5;
  color: #065f46;
}

.status-badge.scheduled {
  background: #fef3c7;
  color: #92400e;
}

.card-stats {
  display: flex;
  gap: 12px;
  margin-bottom: 16px;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 1;
}

.stat-icon {
  font-size: 18px;
}

.stat-detail {
  display: flex;
  flex-direction: column;
}

.stat-value {
  font-size: 16px;
  font-weight: 700;
  color: #667eea;
  line-height: 1;
}

.stat-label {
  font-size: 9px;
  color: #64748b;
  text-transform: uppercase;
}

/* Lista de buses */
















/* Progreso individual del bus */







.more-buses {
  width: 100%;
  text-align: center;
  font-size: 11px;
  color: #3b82f6;
  padding: 8px;
  background: #eff6ff;
  border-radius: 6px;
  border: 1px dashed #93c5fd;
  cursor: pointer;
  font-weight: 600;
  transition: background 0.15s, color 0.15s;
}
.more-buses:hover {
  background: #dbeafe;
  color: #1d4ed8;
}

.card-actions {
  display: flex;
  gap: 8px;
  padding-top: 12px;
  border-top: 1px solid #e2e8f0;
}

.card-action-btn {
  flex: 1;
  padding: 8px;
  border: none;
  background: #f1f5f9;
  color: #475569;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.card-action-btn:hover {
  background: #667eea;
  color: white;
}

.empty-state-card {
  text-align: center;
  padding: 60px 20px;
  background: white;
  border-radius: 12px;
  border: 2px dashed #e2e8f0;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 12px;
}

.empty-state-card p {
  margin: 0 0 8px 0;
  font-size: 16px;
  font-weight: 600;
  color: #334155;
}

.empty-state-card small {
  color: #64748b;
  display: block;
  margin-bottom: 16px;
}

.cards-grid::-webkit-scrollbar {
  width: 8px;
}

.cards-grid::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 10px;
  margin: 8px 0;
}

.cards-grid::-webkit-scrollbar-thumb {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 10px;
}

.cards-grid::-webkit-scrollbar-thumb:hover {
  background: linear-gradient(135deg, #5a67d8 0%, #6b46a1 100%);
}

/* Chips de filtro */
.filter-chips {
  display: flex;
  gap: 6px;
  margin-bottom: 12px;
  flex-wrap: wrap;
}

.chip {
  padding: 5px 12px;
  border: 1.5px solid #e2e8f0;
  border-radius: 20px;
  background: white;
  color: #64748b;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.chip:hover {
  border-color: #667eea;
  color: #667eea;
}

.chip-active {
  background: #667eea;
  border-color: #667eea;
  color: white;
}

/* Pestañas del Monitor */
.monitor-tabs {
  display: flex;
  border-bottom: 2px solid #e2e8f0;
  background: white;
}

.monitor-tab {
  flex: 1;
  padding: 10px 16px;
  border: none;
  background: none;
  font-size: 13px;
  font-weight: 600;
  color: #64748b;
  cursor: pointer;
  transition: all 0.2s;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}

.monitor-tab.active {
  color: #667eea;
}

.monitor-tab.active::after {
  content: '';
  position: absolute;
  bottom: -2px;
  left: 0;
  right: 0;
  height: 2px;
  background: #667eea;
  border-radius: 2px 2px 0 0;
}

.monitor-tab:hover {
  color: #667eea;
  background: #f8fafc;
}

.tab-badge {
  background: #ef4444;
  color: white;
  font-size: 10px;
  font-weight: 700;
  min-width: 18px;
  height: 18px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 5px;
  animation: pulse 2s ease-in-out infinite;
}

/* Panel de Incidentes */
.incidents-panel {
  padding: 20px;
  background: #f8fafc;
}

.incidents-list {
  display: grid;
  gap: 12px;
  max-height: 500px;
  overflow-y: auto;
}

.incident-card {
  background: white;
  border-radius: 10px;
  border-left: 4px solid #ef4444;
  padding: 14px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  transition: all 0.2s;
}

.incident-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  transform: translateY(-1px);
}

.incident-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
}

.incident-name {
  font-size: 14px;
  font-weight: 600;
  color: #1e293b;
}

.incident-time {
  font-size: 11px;
  color: #94a3b8;
  font-weight: 500;
}

.incident-descrip {
  font-size: 12px;
  color: #64748b;
  margin-bottom: 8px;
  font-style: italic;
}

.incident-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}

.incident-location {
  font-size: 11px;
  color: #64748b;
}

.incident-status.active {
  font-size: 11px;
  font-weight: 600;
  color: #ef4444;
}

.incident-actions {
  display: flex;
  justify-content: flex-end;
}

.resolve-btn {
  padding: 6px 14px;
  border: none;
  background: #10b981;
  color: white;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.resolve-btn:hover {
  background: #059669;
  transform: translateY(-1px);
}

.resolve-btn:disabled {
  background: #94a3b8;
  cursor: not-allowed;
  transform: none;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

/* ═══════════════ RESPONSIVE ═══════════════ */
@media (max-width: 1024px) {
  .monitor-widget {
    max-width: 350px;
  }
}

@media (max-width: 768px) {
  .monitor-widget {
    max-width: 95%;
    margin: 0 auto;
    position: fixed;
    bottom: 20px;
    left: 10px;
    right: 10px;
    z-index: 1100;
  }

  .monitor-widget.collapsed {
    max-width: 95%;
  }

  .widget-card {
    max-height: 50vh; /* Ocupa la mitad de la pantalla para dejar ver el mapa */
    box-shadow: 0 -5px 25px rgba(0,0,0,0.2);
  }

  .monitor-stats-grid {
    grid-template-columns: repeat(3, 1fr);
  }

  .monitor-stat-card {
    padding: 12px 8px;
  }

  .stat-number {
    font-size: 20px;
  }

  .stat-label {
    font-size: 9px;
  }

  .monitor-tab {
    padding: 10px;
    font-size: 13px;
  }

  .active-routes-cards {
    padding: 12px;
  }

  .cards-grid {
    max-height: 35vh;
  }
  
  .search-input {
    padding: 8px 35px;
    font-size: 12px;
  }
}

@media (max-width: 480px) {
  .monitor-widget {
    bottom: 15px;
    left: 8px;
    right: 8px;
  }
  
  .widget-header h3 {
    font-size: 13px;
  }
}
</style>
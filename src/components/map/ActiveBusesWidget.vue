<template>
  <div id="active-buses-widget" class="floating-widget">
    <div class="widget-header">
      <span class="widget-title">🚌 Buses en Vivo</span>
      <div class="widget-header-right">
        <!-- Indicador de conexión WebSocket -->
        <span 
          class="ws-indicator" 
          :class="{ connected: isConnected }"
          :title="isConnected ? 'GPS Conectado' : 'GPS Desconectado'"
        >
          {{ isConnected ? '🛰️' : '📡' }}
        </span>
        <button class="widget-toggle" @click="toggleWidget">−</button>
      </div>
    </div>
    <div class="widget-content" :class="{ collapsed: widgetCollapsed }">
      <!-- GPS en tiempo real -->
      <div v-if="busLocationsArray && busLocationsArray.length > 0" class="gps-buses-section">
        <div class="section-label">
          <span class="pulse-dot"></span>
          GPS en tiempo real ({{ busLocationsArray.length }})
        </div>
        <div class="gps-bus-list">
          <div 
            v-for="bus in busLocationsArray" 
            :key="bus.busId" 
            class="gps-bus-item"
          >
            <div class="gps-bus-info">
              <span class="gps-bus-id">🚌 Bus #{{ bus.busId }}</span>
              <span class="gps-speed">{{ Math.round(bus.speed) }} km/h</span>
            </div>
            <div class="gps-coords">
              📍 {{ bus.lat.toFixed(4) }}, {{ bus.lng.toFixed(4) }}
            </div>
          </div>
        </div>
      </div>
      
      <!-- Leyenda de rutas -->
      <div v-if="activeRoutesLegend.length > 0" class="routes-legend">
        <div 
          v-for="route in activeRoutesLegend" 
          :key="route.id"
          class="legend-item"
        >
          <div 
            class="legend-color" 
            :style="{ background: route.color }"
          ></div>
          <span class="legend-name">{{ route.name }}</span>
          <span class="legend-count">{{ route.busCount }}</span>
        </div>
      </div>

      <div id="live-buses-list">
        <div v-for="bus in activeBusesWithRoutes" :key="bus.id_bus" class="live-bus-item">
          <div class="bus-info">
            <div class="bus-plate-with-color">
              <div 
                class="bus-color-indicator" 
                :style="{ background: getRouteColor(bus.ruta_actual) }"
              ></div>
              <span class="bus-plate">{{ bus.placa }}</span>
            </div>
            <span class="bus-status" :class="bus.status_bus ? 'active' : 'inactive'">
              {{ bus.status_bus ? '🟢' : '🔴' }}
            </span>
          </div>
          <div class="bus-route-info">
            <small v-if="bus.ruta_actual">
              📍 {{ getRouteName(bus.ruta_actual) }}
            </small>
            <small v-else>Sin ruta asignada</small>
          </div>
          <div v-if="bus.ruta_actual" class="bus-progress-mini">
            <div class="progress-bar-mini">
              <div 
                class="progress-fill-mini" 
                :style="{ 
                  width: (bus.progreso_ruta || 0) + '%',
                  background: getRouteColor(bus.ruta_actual)
                }"
              ></div>
            </div>
            <span class="progress-text-mini">{{ bus.progreso_ruta || 0 }}%</span>
          </div>
        </div>
        <div v-if="activeBusesWithRoutes.length === 0" class="no-buses">
          No hay buses en rutas activas
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRoutesStore } from '../../stores/routes'

const props = defineProps({
  busLocationsArray: { type: Array, default: () => [] },
  isConnected: { type: Boolean, default: false },
  activeRoutesLegend: { type: Array, default: () => [] },
  activeBusesWithRoutes: { type: Array, default: () => [] }
})

const routesStore = useRoutesStore()
const widgetCollapsed = ref(false)

const toggleWidget = () => {
  widgetCollapsed.value = !widgetCollapsed.value
}

const getRouteName = (routeId) => {
  const route = routesStore.getRouteById(routeId)
  return route ? route.name : 'Ruta desconocida'
}

const getRouteColor = (routeId) => {
  const route = routesStore.getRouteById(routeId)
  return route ? route.color : '#667eea'
}
</script>

<style scoped>
/* Widget flotante */
.floating-widget {
  position: absolute;
  top: 20px;
  left: 20px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
  z-index: 800;
  min-width: 220px;
  max-width: 280px;
  overflow: hidden;
}

.widget-header {
  padding: 12px 15px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  display: flex;
  justify-content: space-between;
  align-items: center;
  cursor: pointer;
}

.widget-title {
  font-size: 13px;
  font-weight: 600;
}

.widget-header-right {
  display: flex;
  align-items: center;
  gap: 8px;
}

.ws-indicator {
  font-size: 14px;
  opacity: 0.7;
  transition: opacity 0.3s;
}

.ws-indicator.connected {
  opacity: 1;
  animation: pulse-ws 2s infinite;
}

@keyframes pulse-ws {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

.widget-toggle {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  cursor: pointer;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
  transition: background 0.2s;
}

.widget-toggle:hover {
  background: rgba(255, 255, 255, 0.35);
}

.widget-content {
  max-height: 350px;
  overflow-y: auto;
  transition: max-height 0.3s ease;
}

.widget-content.collapsed {
  max-height: 0;
  overflow: hidden;
}

/* GPS section */
.gps-buses-section {
  padding: 10px 12px;
  border-bottom: 1px solid #f1f5f9;
}

.section-label {
  font-size: 11px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 6px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.pulse-dot {
  width: 8px;
  height: 8px;
  background-color: #10b981;
  border-radius: 50%;
  display: inline-block;
  animation: pulse-green 1.5s infinite;
  flex-shrink: 0;
}

@keyframes pulse-green {
  0% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.4); opacity: 0.6; }
  100% { transform: scale(1); opacity: 1; }
}

.gps-bus-item {
  padding: 5px 0;
  border-bottom: 1px solid #f8fafc;
}

.gps-bus-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.gps-bus-id {
  font-size: 12px;
  font-weight: 600;
  color: #1e293b;
}

.gps-speed {
  font-size: 11px;
  background: #dbeafe;
  color: #1d4ed8;
  padding: 1px 6px;
  border-radius: 8px;
  font-weight: 600;
}

.gps-coords {
  font-size: 10px;
  color: #94a3b8;
  margin-top: 2px;
}

/* Routes legend */
.routes-legend {
  padding: 8px 12px;
  border-bottom: 1px solid #f1f5f9;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 3px 0;
}

.legend-color {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.legend-name {
  font-size: 11px;
  color: #475569;
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.legend-count {
  font-size: 11px;
  font-weight: 700;
  color: #1e293b;
  background: #f1f5f9;
  padding: 1px 5px;
  border-radius: 8px;
}

/* Live buses list */
#live-buses-list {
  padding: 6px 0;
}

.live-bus-item {
  padding: 8px 12px;
  border-bottom: 1px solid #f8fafc;
  transition: background 0.2s;
}

.live-bus-item:hover {
  background: #f8fafc;
}

.bus-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 3px;
}

.bus-plate-with-color {
  display: flex;
  align-items: center;
  gap: 6px;
}

.bus-color-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.bus-plate {
  font-size: 13px;
  font-weight: 600;
  color: #1e293b;
}

.bus-status {
  font-size: 10px;
}

.bus-route-info small {
  font-size: 11px;
  color: #64748b;
}

.bus-progress-mini {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 4px;
}

.progress-bar-mini {
  flex: 1;
  height: 4px;
  background: #e2e8f0;
  border-radius: 2px;
  overflow: hidden;
}

.progress-fill-mini {
  height: 100%;
  border-radius: 2px;
  transition: width 0.5s ease;
}

.progress-text-mini {
  font-size: 10px;
  color: #94a3b8;
  font-weight: 600;
  min-width: 28px;
  text-align: right;
}

.no-buses {
  padding: 12px;
  text-align: center;
  color: #94a3b8;
  font-size: 12px;
}
</style>

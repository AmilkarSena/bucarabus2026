<template>
  <div
    class="bottom-panel-container"
    :class="{ 'panel-is-hidden': panelHidden, expanded: panelExpanded }"
  >
    <!-- Handle — always visible -->
    <div class="panel-handle" @click="$emit('toggle')">
      <div class="handle-arrow" :class="{ hidden: panelHidden }">
        {{ panelHidden ? '▲' : '▼' }}
      </div>
      <div class="handle-bar"></div>
    </div>

    <!-- Panel content -->
    <div v-show="!panelHidden" class="bottom-panel-content">

      <!-- Selected bus info -->
      <div v-if="selectedBus" class="selected-bus-info">
        <div class="bus-header">
          <div class="bus-icon-large" :style="{ background: selectedBus.routeColor }">🚌</div>
          <div class="bus-details">
            <h3>{{ selectedBus.plate }}</h3>
            <p class="route-name" :style="{ color: selectedBus.routeColor }">{{ selectedBus.routeName }}</p>
          </div>
          <button @click="$emit('clear-bus')" class="btn-close">✕</button>
        </div>
        <div class="bus-stats">
          <div class="stat">
            <span class="stat-icon">🚗</span>
            <span class="stat-value">{{ Math.round(selectedBus.speed || 0) }} km/h</span>
            <span class="stat-label">Velocidad</span>
          </div>
          <div class="stat">
            <span class="stat-icon">📍</span>
            <span class="stat-value">{{ selectedBus.distance || '---' }}</span>
            <span class="stat-label">Distancia</span>
          </div>
          <div class="stat">
            <span class="stat-icon">⏱️</span>
            <span class="stat-value">{{ selectedBus.eta || '---' }}</span>
            <span v-if="selectedBus.etaArrivalTime" class="stat-arrival">{{ selectedBus.etaArrivalTime }}</span>
            <span class="stat-label">Llegada</span>
          </div>
        </div>
      </div>

      <!-- Suggested routes -->
      <template v-else-if="selectedDestination && suggestedRoutes.length > 0">
        <RouteSuggestionList
          :suggestions="suggestedRoutes"
          :selected-suggestion="selectedSuggestedRoute"
          @select-route="$emit('select-route', $event)"
        >
          <template #active-buses>
            <ActiveBusesList
              v-if="selectedSuggestedRoute && activeBusesOnRoute.length > 0"
              :buses="activeBusesOnRoute"
              @select-bus="$emit('select-bus-from-route', $event)"
            />
            <div
              v-else-if="selectedSuggestedRoute && activeBusesOnRoute.length === 0"
              class="no-active-buses"
            >
              <p>⏸️ No hay buses activos en esta ruta en este momento</p>
            </div>
          </template>
        </RouteSuggestionList>
      </template>

      <!-- No routes found -->
      <div v-else-if="selectedDestination && suggestedRoutes.length === 0" class="no-routes-found">
        <h3><span>😔</span> No encontramos rutas</h3>
        <p>No hay rutas disponibles que conecten tu ubicación con este destino.</p>
        <p class="hint">Intenta buscar otro destino más cercano.</p>
      </div>

      <!-- Nearby buses (default state) -->
      <NearbyBusesList
        v-else
        :buses="nearbyBuses"
        :user-location="userLocation"
        @select-bus="$emit('select-bus-nearby', $event)"
        @request-location="$emit('request-location')"
      />
    </div>
  </div>
</template>

<script setup>
import RouteSuggestionList from './RouteSuggestionList.vue'
import ActiveBusesList from './ActiveBusesList.vue'
import NearbyBusesList from './NearbyBusesList.vue'

defineProps({
  panelHidden: { type: Boolean, default: false },
  panelExpanded: { type: Boolean, default: false },
  selectedBus: { type: Object, default: null },
  suggestedRoutes: { type: Array, default: () => [] },
  selectedDestination: { type: Object, default: null },
  selectedSuggestedRoute: { type: Object, default: null },
  activeBusesOnRoute: { type: Array, default: () => [] },
  nearbyBuses: { type: Array, default: () => [] },
  userLocation: { type: Object, default: null }
})
defineEmits([
  'toggle',
  'select-route',
  'select-bus-from-route',
  'clear-bus',
  'request-location',
  'select-bus-nearby'
])
</script>

<style scoped>
.bottom-panel-container {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 1000;
  display: flex;
  flex-direction: column;
  align-items: center;
  max-height: 45%;
  transition: all 0.3s ease;
  pointer-events: none;
}

.bottom-panel-container.expanded { max-height: 65%; }

.bottom-panel-container.panel-is-hidden {
  max-height: none;
  justify-content: flex-end;
  padding-bottom: 16px;
}

/* Handle */
.panel-handle {
  pointer-events: auto;
  padding: 8px 24px;
  background: white;
  border-radius: 20px 20px 0 0;
  box-shadow: 0 -4px 12px rgba(0,0,0,0.1);
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  transition: all 0.3s ease;
  flex-shrink: 0;
  gap: 4px;
}

.panel-is-hidden .panel-handle {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 16px;
  box-shadow: 0 4px 16px rgba(102, 126, 234, 0.5);
  padding: 10px 28px;
}

.panel-handle:hover { transform: scale(1.05); }

.handle-bar {
  width: 36px;
  height: 4px;
  border-radius: 2px;
  background: #ccc;
}

.panel-is-hidden .handle-bar { background: rgba(255, 255, 255, 0.4); }

.handle-arrow {
  font-size: 0.75rem;
  color: #667eea;
  font-weight: bold;
  line-height: 1;
  transition: all 0.3s ease;
  user-select: none;
}

.handle-arrow.hidden {
  font-size: 0.85rem;
  color: white;
  text-shadow: 0 1px 3px rgba(0,0,0,0.2);
}

.panel-handle:hover .handle-arrow { transform: scale(1.2); }

/* Panel content */
.bottom-panel-content {
  pointer-events: auto;
  background: white;
  width: 100%;
  overflow-y: auto;
  box-shadow: 0 -4px 20px rgba(0,0,0,0.1);
  flex: 1;
  min-height: 0;
}

/* Selected bus */
.selected-bus-info { padding: 0 16px 16px; }

.bus-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.bus-icon-large {
  width: 50px;
  height: 50px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
}

.bus-details { flex: 1; }
.bus-details h3 { margin: 0; font-size: 1.1rem; }
.route-name { margin: 4px 0 0; font-weight: 500; }

.btn-close {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: #f0f0f0;
  cursor: pointer;
  font-size: 1rem;
}

.bus-stats { display: flex; gap: 12px; }

.stat {
  flex: 1;
  background: #f8f9fa;
  padding: 12px;
  border-radius: 12px;
  text-align: center;
}

.stat-icon { font-size: 1.2rem; display: block; margin-bottom: 4px; }
.stat-value { font-size: 1.1rem; font-weight: 600; display: block; }
.stat-arrival { font-size: 0.72rem; color: #667eea; font-weight: 600; display: block; margin-top: 1px; }
.stat-label { font-size: 0.75rem; color: #666; }

/* No routes found */
.no-routes-found { padding: 20px 16px; text-align: center; }

.no-routes-found h3 {
  margin: 0 0 12px;
  font-size: 1rem;
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: center;
}

.no-routes-found p { color: #666; margin: 8px 0; font-size: 0.9rem; }
.no-routes-found .hint { font-size: 0.85rem; color: #999; font-style: italic; }

/* No active buses */
.no-active-buses {
  margin-top: 12px;
  padding: 12px;
  background: #f8f9fa;
  border-radius: 8px;
  text-align: center;
}

.no-active-buses p { margin: 0; font-size: 0.85rem; color: #666; }
</style>

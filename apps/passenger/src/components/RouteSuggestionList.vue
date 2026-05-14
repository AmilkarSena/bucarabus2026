<template>
  <div class="route-suggestions">
    <div class="suggestions-header">
      <span class="header-title">Rutas disponibles</span>
      <span class="header-count">{{ suggestions.length }} encontrada{{ suggestions.length !== 1 ? 's' : '' }}</span>
    </div>

    <div class="suggestions-list">
      <div
        v-for="suggestion in suggestions"
        :key="suggestion.route.id + '-' + (suggestion.pickupStopName || 'geo')"
        class="route-card"
        :class="{ selected: selectedSuggestion?.route.id === suggestion.route.id }"
        @click="$emit('select-route', suggestion)"
      >
        <!-- Franja de color lateral -->
        <div class="route-color-bar" :style="{ background: suggestion.route.color }"></div>

        <div class="route-card-body">
          <!-- Fila superior: badge de ruta + estado buses -->
          <div class="card-top">
            <div class="route-badge" :style="{ background: suggestion.route.color }">
              {{ suggestion.route.name }}
            </div>
            <span v-if="suggestion.route.fare" class="fare-tag">
              ${{ suggestion.route.fare.toLocaleString('es-CO') }}
            </span>
            <div class="bus-status" :class="suggestion.busesOnRoute > 0 ? 'has-buses' : 'no-buses'">
              <span class="bus-dot"></span>
              <span>{{ suggestion.busesOnRoute > 0
                ? `${suggestion.busesOnRoute} bus${suggestion.busesOnRoute > 1 ? 'es' : ''} activo${suggestion.busesOnRoute > 1 ? 's' : ''}`
                : 'Sin buses activos'
              }}</span>
            </div>
          </div>

          <!-- Indicador de paradas de recorrido -->
          <div v-if="suggestion.stopsCount" class="stops-indicator">
            <span class="stops-icon">🚏</span>
            <span>{{ suggestion.stopsCount }} parada{{ suggestion.stopsCount !== 1 ? 's' : '' }}</span>
          </div>

          <!-- Paradas: origen → destino -->
          <div class="card-stops">
            <div class="stop-row">
              <span class="stop-dot origin-dot"></span>
              <span class="stop-name">{{ suggestion.pickupStopName || 'Paradero más cercano' }}</span>
              <span class="walk-tag">🚶 {{ formatDistance(suggestion.walkToPickup) }}</span>
            </div>
            <div class="stop-connector"></div>
            <div class="stop-row">
              <span class="stop-dot dest-dot"></span>
              <span class="stop-name dest-name">{{ suggestion.dropoffStopName || 'Tu destino' }}</span>
            </div>
          </div>
        </div>

        <span class="card-arrow">›</span>
      </div>
    </div>

    <!-- Buses activos en ruta seleccionada -->
    <slot name="active-buses" />
  </div>
</template>

<script setup>
import { formatDistance } from '@shared/utils/geo'

defineProps({
  suggestions: { type: Array, default: () => [] },
  selectedSuggestion: { type: Object, default: null }
})
defineEmits(['select-route'])
</script>

<style scoped>
.route-suggestions { padding: 0 16px 16px; }

.suggestions-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 0 10px;
}
.header-title { font-size: 0.85rem; font-weight: 600; color: #374151; text-transform: uppercase; letter-spacing: 0.05em; }
.header-count { font-size: 0.8rem; color: #9ca3af; }

.suggestions-list { display: flex; flex-direction: column; gap: 10px; }

/* Tarjeta */
.route-card {
  display: flex;
  align-items: stretch;
  background: white;
  border-radius: 14px;
  border: 1.5px solid #e5e7eb;
  box-shadow: 0 1px 4px rgba(0,0,0,0.06);
  overflow: hidden;
  cursor: pointer;
  transition: box-shadow 0.2s, border-color 0.2s, transform 0.15s;
}
.route-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.1); transform: translateY(-1px); }
.route-card.selected { border-color: #667eea; box-shadow: 0 0 0 3px rgba(102,126,234,0.15); }

.route-color-bar { width: 5px; flex-shrink: 0; }

.route-card-body { flex: 1; padding: 12px 10px 12px 12px; display: flex; flex-direction: column; gap: 10px; min-width: 0; }

/* Fila superior */
.card-top { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }

.route-badge {
  color: white;
  font-size: 0.78rem;
  font-weight: 700;
  padding: 3px 10px;
  border-radius: 6px;
  letter-spacing: 0.02em;
  white-space: nowrap;
}

.bus-status {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 0.75rem;
  font-weight: 500;
  margin-left: auto;
}
.bus-dot {
  width: 7px; height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
}
.has-buses { color: #059669; }
.has-buses .bus-dot { background: #10b981; box-shadow: 0 0 0 2px rgba(16,185,129,0.2); }
.no-buses { color: #9ca3af; }
.no-buses .bus-dot { background: #d1d5db; }

.fare-tag {
  font-size: 0.72rem;
  font-weight: 700;
  color: #059669;
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  padding: 2px 7px;
  border-radius: 4px;
  white-space: nowrap;
  letter-spacing: 0.01em;
}

/* Paradas de recorrido */
.stops-indicator {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 0.73rem;
  color: #6b7280;
  background: #f9fafb;
  padding: 3px 10px;
  border-radius: 6px;
  width: fit-content;
}
.stops-icon { font-size: 0.85rem; }

/* Paradas */
.card-stops { display: flex; flex-direction: column; gap: 0; padding-left: 2px; }

.stop-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 2px 0;
}

.stop-dot {
  width: 10px; height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
  border: 2px solid;
}
.origin-dot { border-color: #667eea; background: white; }
.dest-dot { border-color: #ef4444; background: #ef4444; }

.stop-connector {
  width: 2px; height: 14px;
  background: #d1d5db;
  margin-left: 4px;
}

.stop-name {
  flex: 1;
  font-size: 0.82rem;
  color: #374151;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 170px;
}
.dest-name { color: #6b7280; }

.walk-tag {
  font-size: 0.72rem;
  color: #6b7280;
  white-space: nowrap;
  flex-shrink: 0;
}

/* Flecha */
.card-arrow {
  display: flex;
  align-items: center;
  padding: 0 12px;
  font-size: 1.4rem;
  color: #d1d5db;
  flex-shrink: 0;
  transition: color 0.2s;
}
.route-card:hover .card-arrow { color: #667eea; }
.route-card.selected .card-arrow { color: #667eea; }
</style>

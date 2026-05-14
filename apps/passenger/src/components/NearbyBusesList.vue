<template>
  <div class="nearby-stops">
    <h3>
      <span>📍</span>
      {{ userLocation ? 'Buses cercanos' : 'Activa tu ubicación' }}
    </h3>

    <div v-if="!userLocation" class="enable-location">
      <p>Para ver buses cercanos, activa tu ubicación</p>
      <button @click="$emit('request-location')" class="btn-enable-location">
        Activar ubicación
      </button>
    </div>

    <div v-else-if="buses.length === 0" class="no-buses">
      <p>No hay buses cercanos en este momento</p>
    </div>

    <div v-else class="buses-list">
      <div
        v-for="bus in buses"
        :key="bus.busId"
        class="bus-item"
        @click="$emit('select-bus', bus)"
      >
        <div class="bus-color-indicator" :style="{ background: bus.routeColor }"></div>
        <div class="bus-item-info">
          <span class="bus-plate">{{ bus.plate }}</span>
          <span class="bus-route">{{ bus.routeName }}</span>
        </div>
        <div class="bus-item-eta">
          <span class="eta-value">{{ bus.eta }}</span>
          <span class="eta-label">{{ bus.distance }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  buses: { type: Array, default: () => [] },
  userLocation: { type: Object, default: null }
})
defineEmits(['select-bus', 'request-location'])
</script>

<style scoped>
.nearby-stops { padding: 0 16px 16px; }

.nearby-stops h3 {
  margin: 0 0 12px;
  font-size: 1rem;
  display: flex;
  align-items: center;
  gap: 8px;
}

.enable-location { text-align: center; padding: 20px; }
.enable-location p { color: #666; margin-bottom: 12px; }

.btn-enable-location {
  padding: 12px 24px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 25px;
  font-size: 1rem;
  cursor: pointer;
}

.no-buses { text-align: center; padding: 20px; color: #666; }

.buses-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 200px;
  overflow-y: auto;
}

.bus-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: #f8f9fa;
  border-radius: 12px;
  cursor: pointer;
  transition: background 0.2s;
}

.bus-item:hover { background: #f0f0f0; }

.bus-color-indicator {
  width: 4px;
  height: 40px;
  border-radius: 2px;
}

.bus-item-info { flex: 1; }

.bus-plate { font-weight: 600; display: block; }
.bus-route { font-size: 0.85rem; color: #666; }

.bus-item-eta { text-align: right; }
.eta-value { font-weight: 600; color: #667eea; display: block; }
.eta-label { font-size: 0.75rem; color: #999; }
</style>

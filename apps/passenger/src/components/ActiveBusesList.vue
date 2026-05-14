<template>
  <div class="active-buses-section">
    <h4 class="active-buses-title">
      <span>🚌</span> Buses activos en esta ruta
    </h4>
    <div class="active-buses-list">
      <div
        v-for="bus in buses"
        :key="bus.busId"
        class="active-bus-card"
        @click="$emit('select-bus', bus)"
      >
        <div class="bus-card-icon" :style="{ background: bus.routeColor }">🚌</div>
        <div class="bus-card-info">
          <div class="bus-card-plate">{{ bus.plate }}</div>
          <div class="bus-card-stats">
            <span class="bus-stat">{{ bus.rollingSpeedKmh ?? Math.round(bus.speed || 0) }} km/h</span>
            <span class="bus-stat-separator">•</span>
            <span class="bus-stat">{{ bus.distanceToPickup }}</span>
          </div>
        </div>
        <div class="bus-card-eta">
          <div
            class="eta-badge"
            :class="{
              'eta-close':  bus.etaMinutes <= 5,
              'eta-medium': bus.etaMinutes > 5 && bus.etaMinutes <= 15,
              'eta-far':    bus.etaMinutes > 15
            }"
          >{{ bus.etaToPickup }}</div>
          <div v-if="bus.etaArrivalTime" class="eta-clock">{{ bus.etaArrivalTime }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  buses: { type: Array, default: () => [] }
})
defineEmits(['select-bus'])
</script>

<style scoped>
.active-buses-section {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid #e0e0e0;
}

.active-buses-title {
  margin: 0 0 12px;
  font-size: 0.9rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 6px;
  color: #333;
}

.active-buses-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.active-bus-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px;
  background: white;
  border: 1px solid #e0e0e0;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.active-bus-card:hover {
  background: #f8f9fa;
  border-color: #667eea;
  transform: translateX(2px);
}

.bus-card-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.2rem;
  flex-shrink: 0;
}

.bus-card-info { flex: 1; }
.bus-card-plate { font-weight: 600; font-size: 0.9rem; color: #333; }

.bus-card-stats {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 2px;
}

.bus-stat { font-size: 0.75rem; color: #666; }
.bus-stat-separator { font-size: 0.7rem; color: #ccc; }
.bus-card-eta { flex-shrink: 0; }

.eta-badge {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 700;
  transition: background 0.4s ease;
}
/* Verde: bus está cerca (< 5 min) */
.eta-close  { background: #10b981; color: white; }
/* Naranja: bus viene en camino (5-15 min) */
.eta-medium { background: #f97316; color: white; }
/* Gris: bus está lejos (> 15 min) */
.eta-far    { background: #94a3b8; color: white; }

.eta-clock {
  font-size: 0.68rem;
  color: #6b7280;
  text-align: center;
  margin-top: 4px;
  font-weight: 500;
  white-space: nowrap;
}
</style>

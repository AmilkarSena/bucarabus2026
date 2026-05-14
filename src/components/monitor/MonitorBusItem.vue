<template>
  <div class="bus-item" :class="{ 'bus-inactive': !bus.gps_active }">
    <div class="bus-header">
      <span class="bus-icon">🚌</span>
      <div class="bus-info">
        <div class="bus-plate-row">
          <span class="bus-plate" v-html="highlightedPlaca"></span>
          <span 
            v-if="!bus.gps_active" 
            class="gps-badge inactive"
            title="GPS inactivo - Viaje programado"
          >
            📡❌
          </span>
          <span 
            v-else
            class="gps-badge active"
            title="GPS activo - En vivo"
          >
            📡✅
          </span>
        </div>
        <span class="bus-driver" v-if="bus.conductor" v-html="highlightedConductor"></span>
        <span v-if="!bus.gps_active" class="scheduled-badge">📅 Programado</span>
      </div>
      <div class="bus-stats">
        <span class="trip-count" :title="`${bus.viajes_completados || 0} viajes completados hoy`">
          🎯 {{ bus.viajes_completados || 0 }}
        </span>
      </div>
    </div>
    
    <div class="bus-progress" v-if="bus.gps_active">
      <div class="bus-progress-bar">
        <div 
          class="bus-progress-fill" 
          :style="{ 
            width: (bus.progreso_ruta || 0) + '%',
            backgroundColor: getProgressColor(bus.progreso_ruta || 0)
          }"
        ></div>
      </div>
      <span class="bus-progress-text">{{ bus.progreso_ruta || 0 }}%</span>
    </div>
    <div class="bus-time-info" v-else>
      <span class="time-label">⏰ Horario:</span>
      <span class="time-range">{{ formatTime(bus.start_time) }} - {{ formatTime(bus.end_time) }}</span>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  bus: {
    type: Object,
    required: true
  },
  searchQuery: {
    type: String,
    default: ''
  }
})

// Highlight text based on search query
const highlightText = (text) => {
  if (!props.searchQuery.trim() || !text) {
    return text
  }
  const query = props.searchQuery.trim()
  const regex = new RegExp(`(${query})`, 'gi')
  return text.replace(regex, '<mark class="highlight">$1</mark>')
}

const highlightedPlaca = computed(() => highlightText(props.bus.placa))
const highlightedConductor = computed(() => {
  if (!props.bus.conductor) return ''
  return highlightText('👨‍✈️ ' + props.bus.conductor)
})

// Color according to progress (green start, yellow middle, blue end)
const getProgressColor = (percentage) => {
  if (percentage < 33) return '#10b981'   // Verde - Inicio
  if (percentage < 66) return '#f59e0b'   // Amarillo - Medio
  return '#3b82f6'                        // Azul - Final/Completando
}

// Format time (TIME to HH:MM)
const formatTime = (timeString) => {
  if (!timeString) return '--:--'
  if (timeString instanceof Date) {
    return timeString.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' })
  }
  if (typeof timeString === 'string') {
    const parts = timeString.split(':')
    return `${parts[0]}:${parts[1]}`
  }
  return '--:--'
}
</script>

<style scoped>
.bus-item {
  background: #f8fafc;
  border-radius: 8px;
  padding: 10px;
  transition: all 0.3s;
}
.bus-item.bus-inactive {
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
  border: 1px dashed #f59e0b;
}
.bus-item.bus-inactive .bus-icon {
  opacity: 0.6;
}
.bus-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.bus-icon {
  font-size: 16px;
}
.bus-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.bus-plate-row {
  display: flex;
  align-items: center;
  gap: 6px;
}
.bus-plate {
  font-size: 13px;
  font-weight: 600;
  color: #334155;
}
.bus-driver {
  font-size: 11px;
  color: #64748b;
}
.gps-badge {
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 8px;
  font-weight: 600;
  display: inline-flex;
  align-items: center;
  gap: 2px;
}
.gps-badge.active {
  background: #d1fae5;
  color: #065f46;
}
.gps-badge.inactive {
  background: #fee2e2;
  color: #991b1b;
}
.scheduled-badge {
  font-size: 10px;
  color: #f59e0b;
  font-weight: 600;
  background: rgba(245, 158, 11, 0.1);
  padding: 2px 6px;
  border-radius: 6px;
  display: inline-block;
  margin-top: 2px;
}
.bus-stats {
  display: flex;
  gap: 8px;
}
.trip-count {
  font-size: 12px;
  font-weight: 600;
  color: #667eea;
  background: #e0e7ff;
  padding: 3px 8px;
  border-radius: 10px;
}
.bus-progress {
  display: flex;
  align-items: center;
  gap: 8px;
}
.bus-progress-bar {
  flex: 1;
  height: 6px;
  background: #e2e8f0;
  border-radius: 3px;
  overflow: hidden;
}
.bus-progress-fill {
  height: 100%;
  transition: width 0.5s ease-in-out, background-color 0.3s;
}
.bus-progress-text {
  font-size: 11px;
  font-weight: 600;
  color: #64748b;
  min-width: 35px;
  text-align: right;
}
.bus-time-info {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 4px;
  padding: 6px 8px;
  background: rgba(245, 158, 11, 0.1);
  border-radius: 6px;
}
.time-label {
  font-size: 11px;
  color: #92400e;
  font-weight: 600;
}
.time-range {
  font-size: 11px;
  color: #b45309;
  font-weight: 700;
}
:deep(.highlight) {
  background-color: #fef08a;
  color: #b45309;
  padding: 0 2px;
  border-radius: 2px;
  font-weight: bold;
}
</style>

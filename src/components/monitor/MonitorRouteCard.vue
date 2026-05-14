<template>
  <div class="route-card" :style="{ borderLeftColor: route.color }">
    <div class="card-header">
      <div class="card-header-left">
        <h5 v-html="highlightedName"></h5>
        <button 
          class="toggle-route-visibility"
          :class="{ 'route-visible': isVisibleOnMap }"
          @click="$emit('toggle-visibility', route)"
          :title="isVisibleOnMap ? 'Ocultar ruta en el mapa' : 'Mostrar ruta en el mapa'"
        >
          {{ isVisibleOnMap ? '👁️' : '👁️‍🗨️' }}
        </button>
      </div>
      <div class="status-badges">
        <span 
          v-if="activeGpsCount > 0"
          class="status-badge online"
          :title="`${activeGpsCount} de ${route.busesActivos} buses con GPS activo`"
        >
          📡 {{ activeGpsCount }}/{{ route.busesActivos }}
        </span>
        <span 
          v-else
          class="status-badge scheduled"
          title="Viajes programados sin GPS activo"
        >
          📅 PROGRAMADO
        </span>
      </div>
    </div>

    <div class="card-stats">
      <div class="stat-item">
        <span class="stat-icon">🚌</span>
        <div class="stat-detail">
          <span class="stat-value">{{ route.busesActivos }}</span>
          <span class="stat-label">Buses</span>
        </div>
      </div>
      <div class="stat-item">
        <span class="stat-icon"></span>
        <div class="stat-detail">
          <span class="stat-value">{{ activeGpsCount }}</span>
          <span class="stat-label">GPS</span>
        </div>
      </div>
      <div class="stat-item">
        <span class="stat-icon">✅</span>
        <div class="stat-detail">
          <span class="stat-value">{{ tripsCompleted }}</span>
          <span class="stat-label">OK</span>
        </div>
      </div>
    </div>

    <div class="buses-list">
      <MonitorBusItem 
        v-for="bus in visibleBuses" 
        :key="bus.id_bus"
        :bus="bus"
        :searchQuery="searchQuery"
      />
      
      <button 
        v-if="filteredBuses.length > 3"
        class="more-buses"
        @click="$emit('toggle-expand', route.id)"
      >
        <template v-if="isExpanded">
          ▲ Ver menos
        </template>
        <template v-else>
          ▼ +{{ filteredBuses.length - 3 }} buses más
        </template>
      </button>
    </div>

    <div class="card-actions">
      <button class="card-action-btn" @click="$emit('focus-route', route)">
        📍 Ver en Mapa
      </button>
      <button class="card-action-btn" @click="$emit('view-details', route.id)">
        📊 Detalles
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import MonitorBusItem from './MonitorBusItem.vue'

const props = defineProps({
  route: {
    type: Object,
    required: true
  },
  filteredBuses: {
    type: Array,
    default: () => []
  },
  isExpanded: {
    type: Boolean,
    default: false
  },
  isVisibleOnMap: {
    type: Boolean,
    default: false
  },
  activeGpsCount: {
    type: Number,
    default: 0
  },
  tripsCompleted: {
    type: Number,
    default: 0
  },
  searchQuery: {
    type: String,
    default: ''
  }
})

defineEmits(['toggle-visibility', 'toggle-expand', 'focus-route', 'view-details'])

const visibleBuses = computed(() => {
  return props.isExpanded ? props.filteredBuses : props.filteredBuses.slice(0, 3)
})

const highlightedName = computed(() => {
  const text = props.route.name
  if (!props.searchQuery.trim() || !text) {
    return text
  }
  const query = props.searchQuery.trim()
  const regex = new RegExp(`(${query})`, 'gi')
  return text.replace(regex, '<mark class="highlight">$1</mark>')
})
</script>

<style scoped>
.route-card {
  background: white;
  border-radius: 12px;
  border-left: 4px solid #667eea;
  padding: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 0.3s;
  animation: slideIn 0.5s ease-out;
  margin-bottom: 12px;
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
.buses-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 12px;
}
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
:deep(.highlight) {
  background-color: #fef08a;
  color: #b45309;
  padding: 0 2px;
  border-radius: 2px;
  font-weight: bold;
}
@keyframes slideIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>

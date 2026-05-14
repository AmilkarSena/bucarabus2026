<template>
  <footer id="status-bar">
    <div class="status-left">
      <span class="status-item">
        <span class="status-icon" :class="{ 'status-active': systemStatus }">🟢</span>
        <span>Sistema Operativo</span>
      </span>
      <span class="status-item">
        <span class="status-icon">⏱️</span>
        <span id="current-time">{{ currentTime }}</span>
      </span>
    </div>

    <div class="status-center">
      <div class="quick-stats">
        <span class="quick-stat">
          <span class="quick-stat-value" id="active-shifts">{{ activeShifts }}</span>
          <span class="quick-stat-label">Turnos Activos</span>
        </span>
        <span class="quick-stat">
          <span class="quick-stat-value" id="total-distance">{{ totalDistance }}km</span>
          <span class="quick-stat-label">Distancia Total</span>
        </span>
        <span class="quick-stat">
          <span class="quick-stat-value" id="avg-speed">{{ averageSpeed }}km/h</span>
          <span class="quick-stat-label">Velocidad Promedio</span>
        </span>
      </div>
    </div>

    <div class="status-right">
      <button id="emergency-btn" class="emergency-btn" @click="handleEmergency">🚨 Emergencia</button>
      <div class="connection-status">
        <span class="connection-dot" :class="{ 'connected': isConnected }"></span>
        <span>{{ connectionStatus }}</span>
      </div>
    </div>
  </footer>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useRoutesStore } from '../stores/routes'

// Estado local
const currentTime = ref('')
const systemStatus = ref(true)
const isConnected = ref(true)
const connectionStatus = ref('Conectado')
const activeShifts = ref(12)
const totalDistance = ref(0)
const averageSpeed = ref(0)

const routesStore = useRoutesStore()

// Computed properties
const totalDistanceComputed = computed(() => routesStore.totalDistance)

// Métodos
const updateTime = () => {
  const now = new Date()
  currentTime.value = now.toLocaleTimeString('es-ES', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })
}

const handleEmergency = () => {
  if (confirm('¿Está seguro de que desea activar el protocolo de emergencia?')) {
    alert('Protocolo de emergencia activado. Se ha notificado al equipo de respuesta.')
  }
}

// Lifecycle
let timeInterval

onMounted(() => {
  updateTime()
  timeInterval = setInterval(updateTime, 1000)

  // Update distance from routes store
  totalDistance.value = routesStore.totalDistance
})

onUnmounted(() => {
  if (timeInterval) {
    clearInterval(timeInterval)
  }
})
</script>

<style scoped>
/* Status bar styles - migrated from original CSS */
#status-bar {
  background: #ffffff;
  border-top: 1px solid #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  color: #64748b;
  font-size: 12px;
  z-index: 1000;
  height: 50px;
  box-shadow: 0 -4px 6px -1px rgba(0, 0, 0, 0.1), 0 -2px 4px -1px rgba(0, 0, 0, 0.06);
}

.status-left,
.status-right {
  display: flex;
  align-items: center;
  gap: 20px;
}

.status-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.status-icon {
  font-size: 14px;
  transition: all 0.3s ease;
}

.status-icon.status-active {
  color: #10b981;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

.status-center {
  flex: 1;
  display: flex;
  justify-content: center;
}

.quick-stats {
  display: flex;
  gap: 30px;
}

.quick-stat {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.quick-stat-value {
  font-size: 16px;
  font-weight: bold;
  color: #1e293b;
  line-height: 1;
}

.quick-stat-label {
  font-size: 10px;
  color: #64748b;
}

.emergency-btn {
  background: #ef4444;
  color: white;
  border: none;
  padding: 8px 15px;
  border-radius: 20px;
  font-size: 11px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.2s ease;
  animation: pulse 2s infinite;
}

.emergency-btn:hover {
  background: #dc2626;
  transform: scale(1.05);
}

.connection-status {
  display: flex;
  align-items: center;
  gap: 8px;
}

.connection-dot {
  width: 8px;
  height: 8px;
  background: #10b981;
  border-radius: 50%;
  animation: blink 2s infinite;
  transition: background-color 0.3s ease;
}

.connection-dot.connected {
  background: #10b981;
}

.connection-dot:not(.connected) {
  background: #ef4444;
}

@keyframes blink {
  0%, 50% { opacity: 1; }
  51%, 100% { opacity: 0.3; }
}

/* Responsive */
@media (max-width: 1024px) {
  .quick-stats {
    gap: 20px;
  }

  .quick-stat-value {
    font-size: 14px;
  }
}

@media (max-width: 768px) {
  #status-bar {
    height: 45px;
    padding: 0 15px;
  }

  .status-left,
  .status-right {
    gap: 10px;
  }

  .quick-stats {
    gap: 15px;
  }

  .quick-stat-value {
    font-size: 14px;
  }

  .emergency-btn {
    padding: 6px 10px;
    font-size: 10px;
  }
}

@media (max-width: 480px) {
  #status-bar {
    height: 40px;
    padding: 0 10px;
  }

  .status-left,
  .status-right {
    gap: 8px;
  }

  .quick-stats {
    gap: 10px;
  }

  .quick-stat-value {
    font-size: 12px;
  }

  .emergency-btn {
    padding: 5px 8px;
    font-size: 9px;
  }

  .status-item span:not(.status-icon) {
    display: none;
  }

  .connection-status span {
    display: none;
  }
}

/* Hover effects */
.status-item:hover {
  color: #1e293b;
}

.quick-stat:hover .quick-stat-value {
  color: #667eea;
  transform: scale(1.05);
  transition: all 0.2s ease;
}
</style>
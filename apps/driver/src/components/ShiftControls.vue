<template>
  <div class="shift-controls">
    <div v-if="!shiftActive" class="shift-start">
      <button @click="$emit('start-shift')" class="btn-start-shift" :disabled="!isConnected">
        <span class="btn-icon">▶️</span>
        <span class="btn-text">Iniciar Turno</span>
      </button>
      <p class="shift-hint">Activa el GPS para iniciar tu turno</p>
    </div>

    <div v-else class="shift-running">
      <div class="shift-stats">
        <div class="stat">
          <span class="stat-value">{{ formatTime(shiftDuration) }}</span>
          <span class="stat-label">Tiempo</span>
        </div>
        <div class="stat">
          <span class="stat-value">{{ tripsCompleted }}</span>
          <span class="stat-label">Viajes</span>
        </div>
        <div class="stat">
          <span class="stat-value">{{ Math.round(currentSpeed) }}</span>
          <span class="stat-label">km/h</span>
        </div>
      </div>

      <div class="progress-section">
        <div class="progress-label">
          <span>Progreso de ruta</span>
          <span>{{ routeProgress }}%</span>
        </div>
        <div class="progress-bar">
          <div 
            class="progress-fill" 
            :style="{ width: routeProgress + '%', background: tripColor || '#667eea' }"
          ></div>
        </div>
      </div>

      <button @click="$emit('end-shift')" class="btn-end-shift">
        <span class="btn-icon">⏹️</span>
        <span class="btn-text">Terminar Turno</span>
      </button>
    </div>
  </div>
</template>

<script setup>
defineProps({
  shiftActive: { type: Boolean, default: false },
  shiftDuration: { type: Number, default: 0 },
  tripsCompleted: { type: Number, default: 0 },
  currentSpeed: { type: Number, default: 0 },
  routeProgress: { type: Number, default: 0 },
  isConnected: { type: Boolean, default: false },
  tripColor: { type: String, default: '#667eea' }
})

defineEmits(['start-shift', 'end-shift'])

const formatTime = (seconds) => {
  const hrs = Math.floor(seconds / 3600)
  const mins = Math.floor((seconds % 3600) / 60)
  const secs = seconds % 60
  
  if (hrs > 0) {
    return `${hrs}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }
  return `${mins}:${secs.toString().padStart(2, '0')}`
}
</script>

<style scoped>
.shift-controls {
  padding: 16px;
  background: #1e293b;
  border-top: 1px solid #334155;
}

.shift-start {
  text-align: center;
}

.btn-start-shift {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  width: 100%;
  padding: 20px;
  font-size: 18px;
  font-weight: 600;
  color: white;
  background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
  border: none;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-start-shift:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(34, 197, 94, 0.4);
}

.btn-start-shift:disabled {
  background: #334155;
  cursor: not-allowed;
}

.shift-hint {
  margin-top: 12px;
  font-size: 12px;
  color: #64748b;
}

/* Shift Running */
.shift-stats {
  display: flex;
  justify-content: space-around;
  margin-bottom: 16px;
}

.stat {
  text-align: center;
}

.stat-value {
  display: block;
  font-size: 24px;
  font-weight: 700;
  color: #22c55e;
}

.stat-label {
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
}

.progress-section {
  margin-bottom: 16px;
}

.progress-label {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #94a3b8;
  margin-bottom: 8px;
}

.progress-bar {
  height: 8px;
  background: #334155;
  border-radius: 4px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  border-radius: 4px;
  transition: width 0.5s ease;
}

.btn-end-shift {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  width: 100%;
  padding: 16px;
  font-size: 16px;
  font-weight: 600;
  color: white;
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  border: none;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-end-shift:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(239, 68, 68, 0.4);
}
</style>

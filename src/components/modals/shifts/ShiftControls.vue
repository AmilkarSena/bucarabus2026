<template>
  <div class="route-controls">
    <div class="controls-row">
      <!-- Ruta Info -->
      <div class="control-group">
        <label>Ruta</label>
        <div class="info-badge route-badge">
          <span class="badge-icon">🛣️</span>
          <span class="badge-text">{{ selectedRouteName }}</span>
        </div>
      </div>

      <!-- Fecha Info -->
      <div class="control-group">
        <label>Fecha</label>
        <div class="info-badge date-badge">
          <span class="badge-icon">📅</span>
          <span class="badge-text">{{ formattedSelectedDate }}</span>
        </div>
      </div>

      <!-- Botones de acción -->
      <div class="control-group actions-group">
        <label>&nbsp;</label>
        <div class="action-buttons">
          <button
            @click="emit('generate')"
            class="generate-btn"
            :disabled="isPastDate"
            :title="isPastDate ? 'No se pueden generar viajes en fechas pasadas' : 'Generar horario'"
          >
            ✨ Generar
          </button>
          <button
            @click="emit('add-single')"
            class="add-single-btn"
            :disabled="isPastDate"
            :title="isPastDate ? 'No se pueden agregar viajes en fechas pasadas' : 'Agregar un viaje individual'"
          >
            + Viaje
          </button>
          <button
            @click="emit('clear')"
            class="clear-btn"
            :disabled="isPastDate"
            title="Limpiar Horario"
          >
            🗑️
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  selectedRouteName: {
    type: String,
    required: true
  },
  formattedSelectedDate: {
    type: String,
    required: true
  },
  isPastDate: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['generate', 'add-single', 'clear'])
</script>

<style scoped>
/* Controles de Ruta */
.route-controls {
  background: white;
  border-bottom: 1px solid #e2e8f0;
  padding: 16px 20px;
  flex-shrink: 0;
}

.controls-row {
  display: flex;
  gap: 20px;
  align-items: flex-end;
  flex-wrap: wrap;
}

.control-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.control-group label {
  font-weight: 600;
  color: #374151;
  font-size: 13px;
}

.info-badge {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  background: #f1f5f9;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  font-size: 14px;
  color: #1e293b;
  min-width: 200px;
  font-weight: 500;
}

.info-badge .badge-icon {
  font-size: 16px;
}

.info-badge .badge-text {
  flex: 1;
}

.route-badge {
  border-color: #dbeafe;
  background: rgba(219, 234, 254, 0.5);
}

.date-badge {
  border-color: #fce7f3;
  background: rgba(252, 231, 243, 0.5);
}

.action-buttons {
  display: flex;
  gap: 8px;
}

.generate-btn,
.add-single-btn,
.clear-btn {
  padding: 10px 16px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: 6px;
}

.generate-btn {
  background: #667eea;
  color: white;
}

.generate-btn:hover:not(:disabled) {
  background: #5a67d8;
  transform: translateY(-1px);
}

.generate-btn:disabled {
  background: #d1d5db;
  cursor: not-allowed;
}

.add-single-btn {
  background: #10b981;
  color: white;
}

.add-single-btn:hover:not(:disabled) {
  background: #059669;
  transform: translateY(-1px);
}

.add-single-btn:disabled {
  background: #d1d5db;
  cursor: not-allowed;
}

.clear-btn {
  background: #ef4444;
  color: white;
}

.clear-btn:hover:not(:disabled) {
  background: #dc2626;
}

.clear-btn:disabled {
  background: #d1d5db;
  cursor: not-allowed;
}

/* Responsive */
@media (max-width: 900px) {
  .controls-row {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
  }

  .action-buttons {
    justify-content: stretch;
  }

  .generate-btn,
  .clear-btn {
    flex: 1;
    justify-content: center;
  }
}
</style>

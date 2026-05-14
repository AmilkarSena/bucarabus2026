<template>
  <div
    class="trip-row"
    :class="{ 'assigned': trip.busId, 'drag-over': trip.isDragOver }"
    :style="{ backgroundColor: trip.batchColor }"
    @dragover="$emit('dragover', $event, trip)"
    @dragleave="$emit('dragleave', $event, trip)"
    @drop="$emit('drop', $event, trip)"
  >
    <div class="trip-cell id-cell">
      <div class="id-container">
        <span class="trip-id">{{ trip.tripNumber }}</span>
        <span v-if="trip.fromDatabase" class="db-id">#{{ trip.id }}</span>
        <span v-else class="new-badge">NUEVO</span>
      </div>
    </div>
    
    <div class="trip-cell vehicle-cell">
      <template v-if="trip.busId">
        <button
          v-if="trip.status_trip !== 3 && trip.status_trip !== 4"
          @click="$emit('unassign', trip)"
          class="unassign-btn"
          title="Quitar asignación"
        >
          ✕
        </button>
        <div class="assigned-bus">
          <div class="bus-main-row">
            <span class="bus-amb-text">{{ getBusAmbCode(trip.busId) }}</span>
            <span class="bus-plate-inline">{{ trip.busId }}</span>
          </div>
          <span class="driver-name">{{ getDriverNameForBus(trip.busId) }}</span>
        </div>
      </template>
      <template v-else>
        <span class="drop-placeholder">Arrastra un bus aquí...</span>
      </template>
    </div>
    
    <div class="trip-cell" @dblclick="startEditing('start')">
      <template v-if="editingField === 'start'">
        <input
          v-model="editValue"
          type="time"
          class="time-input"
          ref="timeInputRef"
          @blur="onBlur"
          @keyup.enter="saveEdit"
          @keyup.escape="cancelEdit"
        />
      </template>
      <template v-else>
        {{ trip.startTime }}
      </template>
    </div>
    
    <div class="trip-cell frequency-cell">
      <span class="frequency-badge">{{ frequencyFromPrevious }}</span>
    </div>
    
    <div class="trip-cell" @dblclick="startEditing('end')">
      <template v-if="editingField === 'end'">
        <input
          v-model="editValue"
          type="time"
          class="time-input"
          ref="timeInputRef"
          @blur="onBlur"
          @keyup.enter="saveEdit"
          @keyup.escape="cancelEdit"
        />
      </template>
      <template v-else>
        {{ trip.endTime }}
      </template>
    </div>
    
    <div class="trip-cell duration-cell">
      <span class="duration-badge">{{ trip.duration }} min</span>
    </div>
    
    <div class="trip-cell status-cell">
      <span class="status-badge" :class="{
        'active':    trip.status_trip === 3,
        'completed': trip.status_trip === 4,
        'cancelled': trip.status_trip === 5,
        'assigned':  trip.status_trip === 2,
        'unassigned':trip.status_trip === 1
      }">
        {{ trip.status_trip === 3 ? 'Activo' : trip.status_trip === 4 ? 'Completado' : trip.status_trip === 5 ? 'Cancelado' : (trip.busId ? 'Asignado' : 'No Asignado') }}
      </span>
    </div>
    
    <!-- Botones flotantes para insertar y borrar viaje -->
    <button
      @click="$emit('insert-after', trip)"
      class="insert-trip-btn"
      :disabled="isPastDate || trip.status_trip === 3 || trip.status_trip === 4"
      :title="isPastDate ? 'No se puede modificar en fechas pasadas' : (trip.status_trip === 3 ? 'No se puede insertar después de un viaje activo' : trip.status_trip === 4 ? 'No se puede insertar después de un viaje completado' : 'Insertar viaje después')"
    >
      +
    </button>
    <button
      @click="$emit('delete', trip)"
      class="delete-trip-btn"
      :disabled="isPastDate || trip.status_trip === 3 || trip.status_trip === 4"
      :title="isPastDate ? 'No se puede eliminar en fechas pasadas' : (trip.status_trip === 3 ? 'No se puede eliminar un viaje activo' : trip.status_trip === 4 ? 'No se puede eliminar un viaje completado' : 'Eliminar viaje')"
    >
      🗑️
    </button>
  </div>
</template>

<script setup>
import { ref, nextTick } from 'vue'

const props = defineProps({
  trip: {
    type: Object,
    required: true
  },
  isPastDate: {
    type: Boolean,
    default: false
  },
  frequencyFromPrevious: {
    type: [String, Number],
    default: '-'
  },
  getBusAmbCode: {
    type: Function,
    required: true
  },
  getDriverNameForBus: {
    type: Function,
    required: true
  }
})

const emit = defineEmits([
  'dragover',
  'dragleave',
  'drop',
  'unassign',
  'insert-after',
  'delete',
  'save-time'
])

const editingField = ref(null)
const editValue = ref('')
const timeInputRef = ref(null)

const startEditing = async (field) => {
  editingField.value = field
  editValue.value = field === 'start' ? props.trip.startTime : props.trip.endTime

  await nextTick()
  
  if (timeInputRef.value) {
    // Si hay multiples refs por el v-if/v-else, tomamos el activo
    const input = Array.isArray(timeInputRef.value) ? timeInputRef.value[0] : timeInputRef.value
    if (input) {
      input.focus()
      input.select()
    }
  }
}

const cancelEdit = () => {
  editingField.value = null
  editValue.value = ''
}

const saveEdit = () => {
  if (editingField.value && editValue.value) {
    emit('save-time', props.trip.id, editingField.value, editValue.value)
  }
  editingField.value = null
  editValue.value = ''
}

const onBlur = () => {
  setTimeout(() => {
    if (editingField.value !== null) {
      saveEdit()
    }
  }, 150)
}
</script>

<style>
/* Copiado desde ShiftsModal.vue: las reglas específicas de la fila */
.trip-row {
  display: grid;
  grid-template-columns: var(--trips-grid);
  gap: 16px;
  padding: 14px 20px;
  border-bottom: 1px solid #f1f5f9;
  transition: all 0.2s ease;
  align-items: center;
  position: relative;
}

.trip-row.assigned {
  background: rgba(16, 185, 129, 0.03);
}

.trip-row.drag-over {
  border-color: #3b82f6;
  background: #eff6ff !important;
  transform: scale(1.01);
}

.trip-row:hover {
  filter: brightness(0.97);
}

.trip-cell {
  font-size: 14px;
  color: #374151;
}

.id-cell {
  display: flex;
  align-items: center;
  justify-content: center;
}

.id-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.trip-id {
  font-weight: 700;
  color: #667eea;
  font-size: 13px;
  padding: 4px 8px;
  background: rgba(102, 126, 234, 0.1);
  border-radius: 4px;
}

.db-id {
  font-size: 9px;
  color: #9ca3af;
  font-weight: 400;
}

.new-badge {
  font-size: 8px;
  color: #10b981;
  background: rgba(16, 185, 129, 0.1);
  padding: 1px 4px;
  border-radius: 3px;
  font-weight: 600;
}

.vehicle-cell {
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 8px;
}

.duration-cell {
  display: flex;
  align-items: center;
  justify-content: center;
}

.duration-badge {
  padding: 5px 10px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  background: rgba(59, 130, 246, 0.1);
  color: #3b82f6;
}

.frequency-cell {
  display: flex;
  align-items: center;
  justify-content: center;
}

.frequency-badge {
  padding: 5px 10px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  background: rgba(168, 85, 247, 0.1);
  color: #a855f7;
}

.assigned-bus {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.bus-main-row {
  display: flex;
  align-items: baseline;
  gap: 6px;
}

.bus-amb-text {
  font-weight: 700;
  color: #1e293b;
  font-size: 14px;
}

.bus-plate-inline {
  font-size: 12px;
  color: #6b7280;
}

.driver-name {
  font-size: 12px;
  color: #6b7280;
}

.drop-placeholder {
  color: #9ca3af;
  font-style: italic;
  font-size: 13px;
}

.status-cell {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 8px;
}

.status-badge {
  padding: 5px 10px;
  border-radius: 16px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.status-badge.assigned {
  background: rgba(16, 185, 129, 0.1);
  color: #10b981;
}

.status-badge.unassigned {
  background: rgba(156, 163, 175, 0.1);
  color: #6b7280;
}

.status-badge.active {
  background: rgba(76, 175, 80, 0.15);
  color: #4CAF50;
}

.status-badge.completed {
  background: rgba(239, 68, 68, 0.1);
  color: #c08080;
}

.status-badge.cancelled {
  background: rgba(244, 67, 54, 0.1);
  color: #F44336;
}

.unassign-btn {
  background: #ef4444;
  color: white;
  border: none;
  border-radius: 50%;
  width: 22px;
  height: 22px;
  cursor: pointer;
  font-size: 11px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  opacity: 1;
  pointer-events: auto;
}

.trip-row:hover .unassign-btn {
  opacity: 1;
  pointer-events: auto;
}

.unassign-btn:hover {
  background: #dc2626;
  transform: scale(1.1);
}

.no-trips {
  text-align: center;
  padding: 50px 20px;
  color: #9ca3af;
}

.no-trips p {
  margin: 0 0 6px 0;
  font-size: 14px;
}

/* Botón Flotante para Insertar Viaje */
.insert-trip-btn {
  position: absolute;
  right: 60px;
  top: 50%;
  transform: translateY(-50%) scale(0);
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border: none;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  z-index: 20;
}

.trip-row:hover .insert-trip-btn {
  opacity: 1;
  transform: translateY(-50%) scale(1);
}

.insert-trip-btn:hover:not(:disabled) {
  transform: translateY(-50%) scale(1.15);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.insert-trip-btn:disabled {
  background: #d1d5db;
  cursor: not-allowed;
}

/* Botón Flotante para Eliminar Viaje */
.delete-trip-btn {
  position: absolute;
  right: 25px;
  top: 50%;
  transform: translateY(-50%) scale(0);
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #ef4444, #dc2626);
  color: white;
  border: none;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  z-index: 20;
}

.trip-row:hover .delete-trip-btn {
  opacity: 1;
  transform: translateY(-50%) scale(1);
}

.delete-trip-btn:hover:not(:disabled) {
  transform: translateY(-50%) scale(1.15);
  box-shadow: 0 4px 12px rgba(239, 68, 68, 0.4);
}

.delete-trip-btn:disabled {
  background: #d1d5db;
  cursor: not-allowed;
}



/* Time Input Styling */
.time-input {
  width: 100%;
  padding: 6px 8px;
  border: 2px solid #667eea;
  border-radius: 6px;
  font-size: 14px;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  color: #1e293b;
  background: white;
  transition: all 0.2s ease;
  text-align: center;
}

.time-input:focus {
  outline: none;
  border-color: #764ba2;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}
</style>

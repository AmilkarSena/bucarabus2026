<template>
  <div class="trips-container">
    <!-- Cabecera de la tabla -->
    <div class="trips-header">
      <div class="header-cell">ID</div>
      <div class="header-cell">VEHÍCULO</div>
      <div class="header-cell">HORA INICIO</div>
      <div class="header-cell">FRECUENCIA</div>
      <div class="header-cell">HORA FIN</div>
      <div class="header-cell">DURACIÓN</div>
      <div class="header-cell">ESTADO</div>
    </div>

    <!-- Lista de viajes -->
    <div class="trips-list">
      <TripRow
        v-for="trip in filteredTrips"
        :key="trip.id"
        :trip="trip"
        :is-past-date="isPastDate"
        :frequency-from-previous="getFrequencyFromPrevious(trip)"
        :get-bus-amb-code="getBusAmbCode"
        :get-driver-name-for-bus="getDriverNameForBus"
        @unassign="$emit('unassign', $event)"
        @dragover="onDragOver"
        @dragleave="onDragLeave"
        @drop="onDrop"
        @save-time="onSaveTime"
        @insert-after="$emit('insert-after', $event)"
        @delete="$emit('delete', $event)"
      />

      <!-- Empty state -->
      <div v-if="filteredTrips.length === 0" class="no-trips">
        <p>No hay viajes generados para esta ruta.</p>
        <p>Selecciona una ruta y haz clic en "Generar" para crear el horario.</p>
      </div>

      <!-- Espaciador al final -->
      <div v-if="filteredTrips.length > 0" class="trips-list-spacer"></div>
    </div>
  </div>
</template>

<script setup>
import TripRow from './TripRow.vue'

const props = defineProps({
  filteredTrips: {
    type: Array,
    required: true
  },
  isPastDate: {
    type: Boolean,
    default: false
  },
  getFrequencyFromPrevious: {
    type: Function,
    required: true
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
  'unassign',
  'dragover',
  'dragleave',
  'drop',
  'save-time',
  'insert-after',
  'delete'
])

// Re-emite los 3 argumentos separados que TripRow envía en save-time
const onSaveTime = (tripId, field, newTime) => {
  emit('save-time', tripId, field, newTime)
}

// Re-emite (event, trip) que TripRow envía para drag-and-drop
const onDragOver = (event, trip) => emit('dragover', event, trip)
const onDragLeave = (event, trip) => emit('dragleave', event, trip)
const onDrop = (event, trip) => emit('drop', event, trip)
</script>

<style>
/* Lista de Viajes */
.trips-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  --trips-grid: 0.8fr 2fr 1fr 0.8fr 1fr 0.8fr 1.5fr;
}

.trips-header {
  display: grid;
  grid-template-columns: var(--trips-grid);
  gap: 16px;
  padding: 12px 20px;
  background: #f1f5f9;
  border-bottom: 2px solid #e2e8f0;
  font-weight: 600;
  font-size: 11px;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  flex-shrink: 0;
}

.trips-list {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
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

.trips-list-spacer {
  height: 100px;
}

/* Scrollbar */
.trips-list::-webkit-scrollbar {
  width: 8px;
}

.trips-list::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 4px;
}

.trips-list::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 4px;
}

.trips-list::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}
</style>

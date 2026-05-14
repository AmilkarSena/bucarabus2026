<template>
  <div v-if="isOpen" class="modal-overlay" @click="closeModal">
    <div class="modal-container shifts-modal" @click.stop>
      <!-- Header del Modal -->
      <div class="modal-header">
        <div class="header-content">
          <h3>📅 Generador de Horarios</h3>
          <p class="header-subtitle">Asigna buses a los viajes arrastrándolos</p>
        </div>
        <button class="close-btn" @click="closeModal">✕</button>
      </div>

      <!-- Contenido Principal -->
      <div class="modal-body">
        <div class="shifts-layout">
          <!-- Panel Lateral: Buses Disponibles (Componente Extraido) -->
          <AvailableBusesPanel
            :buses="availableBuses"
            :is-past-date="isPastDate"
            :get-driver-name="getDriverName"
            :get-bus-trip-count="getBusTripCount"
            @dragstart="handleDragStart"
          />

          <!-- Área Principal -->
          <main class="main-content">
            <!-- Controles (Componente Extraído) -->
            <ShiftControls
              :selected-route-name="selectedRouteName"
              :formatted-selected-date="formattedSelectedDate"
              :is-past-date="isPastDate"
              @generate="generateSchedule"
              @add-single="addSingleTrip"
              @clear="clearSchedule"
            />

            <!-- Lista de Viajes -->
            <TripsGrid
              :filtered-trips="filteredTrips"
              :is-past-date="isPastDate"
              :get-frequency-from-previous="getFrequencyFromPrevious"
              :get-bus-amb-code="getBusAmbCode"
              :get-driver-name-for-bus="getDriverNameForBus"
              @unassign="unassignBus"
              @dragover="handleDragOver"
              @dragleave="handleDragLeave"
              @drop="handleDrop"
              @save-time="handleSaveTime"
              @insert-after="insertTripAfter"
              @delete="deleteTrip"
            />
          </main>
        </div>
      </div>

      <!-- Footer del Modal -->
      <div class="modal-footer">
        <div class="footer-stats">
          <span class="stat-item">
            <strong>{{ filteredTrips.length }}</strong> viajes
          </span>
          <span class="stat-item">
            <strong>{{ assignedTripsCount }}</strong> asignados
          </span>
        </div>
        <div class="footer-actions">
          <button class="btn btn-secondary" @click="closeModal" :disabled="isSaving">Cerrar</button>
          <button 
            class="btn btn-primary" 
            @click="saveSchedule"
            :disabled="filteredTrips.length === 0 || isSaving"
          >
            <span v-if="isSaving">⏳ Guardando...</span>
            <span v-else>💾 Guardar Horario</span>
          </button>
        </div>
      </div>
    </div>
  </div>

  <!-- Mini-modal: Agregar viaje individual -->
  <AddTripModal
    v-model="showAddTripModal"
    :is-today="selectedDate.toLocaleDateString('en-CA') === new Date().toLocaleDateString('en-CA')"
    :existing-start-times="trips.filter(t => t.routeId === selectedRouteId).map(t => t.startTime)"
    @confirm="handleAddTripConfirm"
  />

  <!-- Mini-modal: Generar horario -->
  <MultiTripGenerator
    v-model="showGenerateModal"
    :is-today="selectedDate.toLocaleDateString('en-CA') === new Date().toLocaleDateString('en-CA')"
    :last-trip-start-time="trips.filter(t => t.routeId === selectedRouteId).length > 0 ? trips.filter(t => t.routeId === selectedRouteId).reduce((latest, t) => timeToMinutes(t.startTime) > timeToMinutes(latest.startTime) ? t : latest).startTime : null"
    @generate="handleGenerateSchedule"
  />
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useDriversStore } from '../../stores/drivers'
import { useBusesStore } from '../../stores/buses'
import { useRoutesStore } from '../../stores/routes'
import { useTripsStore } from '../../stores/trips'
import AddTripModal from './shifts/AddTripModal.vue'
import MultiTripGenerator from './shifts/MultiTripGenerator.vue'
import AvailableBusesPanel from './shifts/AvailableBusesPanel.vue'
import TripsGrid from './shifts/TripsGrid.vue'
import ShiftControls from './shifts/ShiftControls.vue'
import { useShiftBatchGenerator } from '../../composables/useShiftBatchGenerator'
import { useShiftTimeValidation } from '../../composables/useShiftTimeValidation'
import { useShiftState } from '../../composables/useShiftState'
import { useShiftDragDrop } from '../../composables/useShiftDragDrop'
import { useShiftTripFactory } from '../../composables/useShiftTripFactory'
import { useShiftPersistence } from '../../composables/useShiftPersistence'
import { useShiftsDataLoader } from '../../composables/useShiftsDataLoader'
import { useShiftsManager } from '../../composables/useShiftsManager'

const props = defineProps({
  isOpen: { type: Boolean, default: false },
  initialRouteId: { type: [String, Number], default: '' },
  initialDate: { type: [Date, String], default: null }
})

const emit = defineEmits(['close', 'save'])

const driversStore = useDriversStore()
const busesStore = useBusesStore()
const routesStore = useRoutesStore()
const tripsStore = useTripsStore()

// Composables
const { generateTripsBatch, batchColors, getNextBatchNumber } = useShiftBatchGenerator()
const { tripFromDatabase, createNewTrip: buildNewTrip } = useShiftTripFactory()

// Estado reactivo
const trips = ref([])
const deletedTripIds = ref([])
const allDayTrips = ref([])

// Inicialización de validadores de tiempo
const { timeToMinutes, minutesToTime, hasBusOverlap, calculateDuration } = useShiftTimeValidation(trips, allDayTrips)

// Computed properties
const routesList = computed(() => routesStore.routesList)
const availableBuses = computed(() => busesStore.buses.filter(bus => bus.is_active))

const selectedDate = computed(() => {
  if (props.initialDate) {
    if (props.initialDate instanceof Date) return props.initialDate
    if (typeof props.initialDate === 'string') {
      const parsed = new Date(props.initialDate + 'T00:00:00')
      return isNaN(parsed.getTime()) ? new Date() : parsed
    }
  }
  return new Date()
})

const selectedRouteId = computed(() => props.initialRouteId)

const selectedRouteName = computed(() => {
  const route = routesList.value.find(r => r.id === selectedRouteId.value)
  return route ? route.name : 'Sin seleccionar'
})

const formattedSelectedDate = computed(() => {
  const days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
  const d = selectedDate.value
  if (!(d instanceof Date) || isNaN(d.getTime())) return 'Fecha no válida'
  return `${days[d.getDay()]}, ${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`
})

const isPastDate = computed(() => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const d = new Date(selectedDate.value)
  d.setHours(0, 0, 0, 0)
  return d < today
})

const filteredTrips = computed(() => {
  if (!selectedRouteId.value) return []
  return trips.value
    .filter(trip => trip.routeId === selectedRouteId.value)
    .sort((a, b) => timeToMinutes(a.startTime) - timeToMinutes(b.startTime))
})

const assignedTripsCount = computed(() => {
  return filteredTrips.value.filter(trip => trip.busId).length
})

// UI State and Helpers
const {
  getBusTripCount,
  getBusAmbCode,
  getDriverName,
  getDriverNameForBus,
  setBusAvailability
} = useShiftState({ trips, allDayTrips, busesStore, driversStore })

// Drag and Drop
const {
  handleDragStart,
  handleDragOver,
  handleDragLeave,
  handleDrop
} = useShiftDragDrop({ trips, allDayTrips, selectedRouteId, isPastDate, hasBusOverlap, timeToMinutes })

// Persistencia en BD
const { isSaving, saveError, saveSchedule: persistSchedule, cancelTripImmediate } = useShiftPersistence(tripsStore)

// Cargador de datos
const { loadData, loadExistingTrips } = useShiftsDataLoader({
  trips, allDayTrips, busesStore, driversStore, routesStore, tripsStore, tripFromDatabase, batchColors, calculateDuration
})

// Lógica de manipulación
const {
  unassignBus,
  handleSaveTime,
  getFrequencyFromPrevious,
  handleAddTripConfirm,
  insertTripAfter,
  clearSchedule,
  deleteTrip
} = useShiftsManager({
  trips, filteredTrips, selectedRouteId, selectedDate, isPastDate, batchColors, getNextBatchNumber,
  buildNewTrip, timeToMinutes, minutesToTime, calculateDuration, setBusAvailability, cancelTripImmediate, tripsStore
})

const showAddTripModal = ref(false)
const showGenerateModal = ref(false)

watch(() => props.isOpen, async (newVal) => {
  if (newVal) {
    trips.value = []
    allDayTrips.value = []
    deletedTripIds.value = []
    loadData(props.initialRouteId, props.initialDate).catch(error => console.error('Error en loadData:', error))
  }
}, { immediate: true })

watch([() => props.initialRouteId, () => props.initialDate], async ([newRouteId, newDate], [oldRouteId, oldDate]) => {
  if (props.isOpen && (newRouteId !== oldRouteId || String(newDate) !== String(oldDate))) {
    trips.value = []
    allDayTrips.value = []
    if (newRouteId && newDate) await loadExistingTrips(newRouteId, newDate)
  }
})

const closeModal = () => emit('close')

const generateSchedule = () => {
  if (isPastDate.value) return
  if (!selectedRouteId.value) {
    alert('Por favor, selecciona una ruta primero.')
    return
  }
  showGenerateModal.value = true
}

const handleGenerateSchedule = ({ startTime, endTime, frequency, duration }) => {
  const result = generateTripsBatch({
    routeId: selectedRouteId.value,
    startTimeStr: startTime,
    endTimeStr: endTime,
    frequency,
    duration,
    existingTrips: trips.value
  })

  if (result.success) {
    trips.value = [...trips.value, ...result.data]
    alert(result.msg)
  } else {
    alert(result.msg)
  }
}

const addSingleTrip = () => {
  if (isPastDate.value) return
  showAddTripModal.value = true
}

const saveSchedule = async () => {
  if (filteredTrips.value.length === 0) {
    alert('No hay viajes para guardar.')
    return
  }
  const routeId = selectedRouteId.value || props.initialRouteId
  if (!routeId) {
    alert('❌ Error: No hay ruta seleccionada.')
    return
  }
  let tripDate
  if (typeof props.initialDate === 'string' && props.initialDate) {
    tripDate = props.initialDate.split('T')[0]
  } else if (props.initialDate instanceof Date && !isNaN(props.initialDate.getTime())) {
    tripDate = props.initialDate.toISOString().split('T')[0]
  } else {
    tripDate = new Date().toISOString().split('T')[0]
  }
  const result = await persistSchedule({
    filteredTrips: filteredTrips.value,
    deletedTripIds: deletedTripIds.value,
    routeId,
    tripDate,
    busesStore
  })
  deletedTripIds.value = []
  if (result.success) {
    let msg = '✅ Horario guardado exitosamente\n'
    if (result.updatedCount > 0) msg += `• ${result.updatedCount} viajes actualizados\n`
    if (result.deletedCount > 0) msg += `• ${result.deletedCount} viajes cancelados\n`
    if (result.createdCount > 0) msg += `• ${result.createdCount} viajes creados`
    alert(msg)
    emit('save', { date: tripDate, routeId: selectedRouteId.value })
    closeModal()
  } else if (result.errors && result.errors.length > 0) {
    const { updatedCount, deletedCount, createdCount, errors } = result
    alert(`⚠️ Guardado parcial:\n• ${updatedCount} actualizados\n• ${deletedCount} cancelados\n• ${createdCount} creados\n\nErrores:\n${errors.join('\n')}`)
  } else {
    alert(`❌ Error al guardar: ${saveError.value || 'Error desconocido'}`)
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 20px;
  backdrop-filter: blur(4px);
}
.modal-container.shifts-modal {
  background: white;
  border-radius: 16px;
  width: 95vw;
  max-width: 1400px;
  height: 90vh;
  max-height: 900px;
  display: flex;
  flex-direction: column;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  overflow: hidden;
}
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}
.header-content h3 { margin: 0; font-size: 22px; font-weight: 700; }
.header-subtitle { margin: 4px 0 0; font-size: 14px; opacity: 0.9; }
.close-btn {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  font-size: 18px;
  cursor: pointer;
  transition: all 0.2s ease;
}
.close-btn:hover { background: rgba(255, 255, 255, 0.3); transform: scale(1.1); }
.modal-body { flex: 1; overflow: hidden; display: flex; }
.shifts-layout { display: flex; width: 100%; height: 100%; }
.main-content { flex: 1; display: flex; flex-direction: column; overflow: hidden; min-width: 0; }
.modal-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  background: #f8fafc;
  border-top: 1px solid #e2e8f0;
}
.footer-stats { display: flex; gap: 20px; }
.stat-item { font-size: 14px; color: #64748b; }
.stat-item strong { color: #1e293b; }
.footer-actions { display: flex; gap: 12px; }
.btn {
  padding: 10px 20px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}
.btn-secondary { background: #e2e8f0; color: #475569; }
.btn-secondary:hover { background: #cbd5e1; }
.btn-primary { background: #667eea; color: white; }
.btn-primary:hover:not(:disabled) { background: #5a67d8; }
.btn-primary:disabled { background: #d1d5db; cursor: not-allowed; }
@media (max-width: 900px) {
  .modal-container.shifts-modal { width: 100%; height: 100%; max-height: none; border-radius: 0; }
  .shifts-layout { flex-direction: column; }
}
</style>

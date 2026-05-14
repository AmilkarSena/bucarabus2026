<template>
  <div class="assign-driver-section">
    <div class="section-header">
      <h2>Asignar Conductor</h2>
      <p class="section-description">Asigna conductores disponibles a los buses de la flota</p>
    </div>

    <div class="assignment-container">
      <!-- Panel de Buses Disponibles -->
      <div class="panel buses-panel">
        <div class="panel-header">
          <h3>🚌 Buses Disponibles</h3>
          <span class="count-badge">{{ availableBuses.length }}</span>
        </div>
        <div class="search-box">
          <input
            type="text"
            v-model="busSearchQuery"
            placeholder="Buscar por placa o código AMB..."
            class="search-input"
          />
        </div>
        <div class="items-list">
          <div
            v-for="bus in filteredBuses"
            :key="bus.id_bus"
            class="item-card bus-card"
            :class="{ selected: selectedBus?.id_bus === bus.id_bus }"
            @click="selectBus(bus)"
          >
            <div class="item-avatar">
              <div class="bus-avatar-small">🚌</div>
            </div>
            <div class="item-info">
              <div class="item-title">{{ bus.plate_number }}</div>
              <div class="item-subtitle">{{ bus.amb_code }}</div>
              <div class="item-meta" v-if="bus.assigned_driver">
                <span class="current-driver">👨‍✈️ {{ getDriverName(bus.assigned_driver) }}</span>
              </div>
            </div>
            <div class="item-status">
              <span class="status-dot" :class="getBusStatusClass(bus)"></span>
            </div>
          </div>
          <div v-if="filteredBuses.length === 0" class="empty-state">
            <p>No hay buses disponibles</p>
          </div>
        </div>
      </div>

      <!-- Panel Central de Asignación -->
      <div class="assignment-panel">
        <div class="assignment-preview">
          <div v-if="selectedBus && selectedDriver" class="preview-content">
            <div class="preview-item">
              <div class="preview-icon bus-icon">🚌</div>
              <div class="preview-details">
                <div class="preview-label">Bus</div>
                <div class="preview-value">{{ selectedBus.plate_number }}</div>
                <div class="preview-sublabel">{{ selectedBus.amb_code }}</div>
              </div>
            </div>

            <div class="assignment-arrow">→</div>

            <div class="preview-item">
              <div class="preview-icon driver-icon">👨‍✈️</div>
              <div class="preview-details">
                <div class="preview-label">Conductor</div>
                <div class="preview-value">{{ selectedDriver.name_driver }}</div>
                <div class="preview-sublabel">CC: {{ selectedDriver.id_driver }}</div>
              </div>
            </div>
          </div>
          <div v-else class="preview-placeholder">
            <p>Selecciona un bus y un conductor para realizar la asignación</p>
          </div>
        </div>

        <div class="assignment-actions">
          <button
            class="btn btn-assign"
            :disabled="!canAssign"
            @click="assignDriver"
          >
            ✓ Asignar Conductor
          </button>
          <button
            class="btn btn-clear"
            @click="clearSelection"
            :disabled="!selectedBus && !selectedDriver"
          >
            ✕ Limpiar Selección
          </button>
        </div>
      </div>

      <!-- Panel de Conductores Disponibles -->
      <div class="panel drivers-panel">
        <div class="panel-header">
          <h3>👨‍✈️ Conductores Disponibles</h3>
          <span class="count-badge">{{ availableDrivers.length }}</span>
        </div>
        <div class="search-box">
          <input
            type="text"
            v-model="driverSearchQuery"
            placeholder="Buscar por nombre o cédula..."
            class="search-input"
          />
        </div>
        <div class="items-list">
          <div
            v-for="driver in filteredDrivers"
            :key="driver.id_driver"
            class="item-card driver-card"
            :class="{ selected: selectedDriver?.id_driver === driver.id_driver }"
            @click="selectDriver(driver)"
          >
            <div class="item-avatar">
              <img
                v-if="driver.photo_driver"
                :src="driver.photo_driver"
                :alt="driver.name_driver"
                class="driver-photo"
              />
              <div v-else class="driver-avatar-placeholder">
                {{ driver.name_driver.charAt(0) }}
              </div>
            </div>
            <div class="item-info">
              <div class="item-title">{{ driver.name_driver }}</div>
              <div class="item-subtitle">CC: {{ driver.id_driver }}</div>
              <div class="item-meta">
                <span class="license-badge">{{ driver.license_cat }}</span>
              </div>
            </div>
            <div class="item-status">
              <span class="status-dot available"></span>
            </div>
          </div>
          <div v-if="filteredDrivers.length === 0" class="empty-state">
            <p>No hay conductores disponibles</p>
          </div>
        </div>
      </div>

      <!-- Panel de Buses Activos -->
      <div class="panel active-buses-panel">
        <div class="panel-header">
          <h3>✓ Buses Activos</h3>
          <span class="count-badge">{{ assignedBuses.length }}</span>
        </div>
        <div class="table-container">
          <table class="active-buses-table">
            <thead>
              <tr>
                <th>Bus</th>
                <th>Conductor</th>
                <th>Fecha de Asignación</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="bus in assignedBuses" :key="bus.id_bus">
                <td>
                  <div class="bus-info">
                    <div class="bus-icon-tiny">🚌</div>
                    <div>
                      <div class="bus-plate">{{ bus.plate_number }}</div>
                      <div class="bus-amb">{{ bus.amb_code }}</div>
                    </div>
                  </div>
                </td>
                <td>
                  <div class="driver-info">
                    {{ getDriverName(bus.assigned_driver) }}
                  </div>
                </td>
                <td>
                  <div class="assignment-date">
                    {{ formatAssignmentDate(bus.assignment_date) }}
                  </div>
                </td>
                <td>
                  <div class="table-actions">
                    <button class="action-btn history-btn" @click="openHistory(bus)" title="Historial">
                      📋
                    </button>
                    <button class="action-btn reassign-btn" @click="reassignBus(bus)" title="Reasignar">
                      ↻
                    </button>
                    <button class="action-btn unassign-btn" @click="unassignDriver(bus)" title="Desasignar">
                      ✕
                    </button>
                  </div>
                </td>
              </tr>
              <tr v-if="assignedBuses.length === 0">
                <td colspan="4" class="empty-state">
                  <p>No hay buses con conductor asignado</p>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- Modal de Historial -->
    <AssignmentHistoryModal 
      v-if="historyBus"
      :is-open="showHistoryModal" 
      :bus="historyBus" 
      @close="closeHistory" 
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useBusesStore } from '../stores/buses'
import { useDriversStore } from '../stores/drivers'
import * as assignmentsApi from '../api/assignments.js'
import AssignmentHistoryModal from '../components/modals/AssignmentHistoryModal.vue'

const busesStore = useBusesStore()
const driversStore = useDriversStore()

// Estado local
const selectedBus = ref(null)
const selectedDriver = ref(null)
const busSearchQuery = ref('')
const driverSearchQuery = ref('')
const showHistoryModal = ref(false)
const historyBus = ref(null)

// Cargar datos al montar el componente
onMounted(async () => {
  await busesStore.fetchBuses()
  await driversStore.fetchDrivers()
})

// Computed properties
const availableBuses = computed(() => {
  // Solo buses activos SIN conductor asignado
  return busesStore.buses.filter(bus => bus.is_active && !bus.assigned_driver)
})

const availableDrivers = computed(() => {
  const assignedIds = new Set(
    busesStore.buses
      .filter(bus => bus.assigned_driver != null)
      .map(bus => String(bus.assigned_driver))
  )
  return driversStore.availableDrivers.filter(d => !assignedIds.has(String(d.id_driver)))
})

const filteredBuses = computed(() => {
  if (!busSearchQuery.value) return availableBuses.value
  
  const query = busSearchQuery.value.toLowerCase()
  return availableBuses.value.filter(bus =>
    bus.plate_number?.toLowerCase().includes(query) ||
    bus.amb_code?.toLowerCase().includes(query) ||
    String(bus.id_bus).includes(query)
  )
})

const filteredDrivers = computed(() => {
  if (!driverSearchQuery.value) return availableDrivers.value
  
  const query = driverSearchQuery.value.toLowerCase()
  return availableDrivers.value.filter(driver =>
    driver.name_driver?.toLowerCase().includes(query) ||
    driver.id_driver?.toString().includes(query)
  )
})

const canAssign = computed(() => {
  return selectedBus.value && selectedDriver.value
})

const assignedBuses = computed(() => {
  // Buses activos con conductor asignado
  return busesStore.buses.filter(bus => bus.is_active && bus.assigned_driver)
})

// Métodos
const selectBus = (bus) => {
  selectedBus.value = selectedBus.value?.id_bus === bus.id_bus ? null : bus
}

const selectDriver = (driver) => {
  selectedDriver.value = selectedDriver.value?.id_driver === driver.id_driver ? null : driver
}

const clearSelection = () => {
  selectedBus.value = null
  selectedDriver.value = null
}

const assignDriver = async () => {
  if (!canAssign.value) return

  const confirmed = confirm(
    `¿Desea asignar a ${selectedDriver.value.name_driver} al bus ${selectedBus.value.plate_number}?`
  )

  if (!confirmed) return

  try {
    const result = await assignmentsApi.assignDriver(
      selectedBus.value.id_bus,
      selectedDriver.value.id_driver
    )

    if (result.success) {
      await busesStore.fetchBuses()
      await driversStore.fetchDrivers()
      alert(`✓ ${result.message}`)
      clearSelection()
    } else {
      alert(`✗ Error: ${result.message}`)
    }
  } catch (error) {
    console.error('Error al asignar conductor:', error)
    alert('✗ Error al asignar conductor')
  }
}

const getBusStatusClass = (bus) => {
  if (bus.assigned_driver) return 'with-driver'
  return 'available'
}

const getDriverName = (driverId) => {
  if (!driverId) return 'Sin conductor'
  const driver = driversStore.drivers.find(d => d.id_driver === driverId)
  return driver ? driver.name_driver : 'Desconocido'
}

const formatAssignmentDate = (dateString) => {
  if (!dateString) return 'Sin asignar'
  
  const date = new Date(dateString)
  const day = String(date.getDate()).padStart(2, '0')
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const year = date.getFullYear()
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')
  
  return `${day}/${month}/${year} ${hours}:${minutes}`
}

const reassignBus = (bus) => {
  // Limpiar selección actual y seleccionar este bus para reasignar
  selectedBus.value = bus
  selectedDriver.value = null
  
  // Scroll a panel de conductores
  const driversPanel = document.querySelector('.drivers-panel')
  if (driversPanel) {
    driversPanel.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }
}

const unassignDriver = async (bus) => {
  const confirmed = confirm(
    `¿Desea desasignar al conductor del bus ${bus.plate_number} (id: ${bus.plate_number})?`
  )

  if (!confirmed) return

  try {
    const result = await assignmentsApi.unassignDriver(bus.assigned_driver)

    if (result.success) {
      await busesStore.fetchBuses()
      await driversStore.fetchDrivers()
      alert(`✓ ${result.message}`)
      clearSelection()
    } else {
      alert(`✗ Error: ${result.message}`)
    }
  } catch (error) {
    console.error('Error al desasignar conductor:', error)
    alert('✗ Error al desasignar conductor')
  }
}

const openHistory = (bus) => {
  historyBus.value = bus
  showHistoryModal.value = true
}

const closeHistory = () => {
  showHistoryModal.value = false
  historyBus.value = null
}
</script>

<style scoped>
.assign-driver-section {
  padding: 0;
}

.section-header {
  margin-bottom: 24px;
  padding: 20px;
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.section-header h2 {
  margin: 0 0 8px 0;
  font-size: 24px;
  font-weight: 700;
  color: #1e293b;
}

.section-description {
  margin: 0;
  color: #64748b;
  font-size: 14px;
}

.assignment-container {
  display: grid;
  grid-template-columns: 1fr 1.2fr 1fr 1.8fr;
  gap: 20px;
  height: calc(100vh - 250px);
}

.panel {
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px;
  border-bottom: 1px solid #e2e8f0;
}

.panel-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #1e293b;
}

.count-badge {
  background: #667eea;
  color: white;
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}

.search-box {
  padding: 16px 20px;
  border-bottom: 1px solid #f1f5f9;
}

.search-input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  transition: border-color 0.3s ease;
}

.search-input:focus {
  outline: none;
  border-color: #667eea;
}

.items-list {
  flex: 1;
  overflow-y: auto;
  padding: 12px;
}

.item-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 2px solid #e2e8f0;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s ease;
  margin-bottom: 8px;
}

.item-card:hover {
  border-color: #cbd5e1;
  background: #f8fafc;
  transform: translateX(4px);
}

.item-card.selected {
  border-color: #667eea;
  background: linear-gradient(135deg, #f0f4ff 0%, #e8edff 100%);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
}

.item-avatar {
  flex-shrink: 0;
}

.bus-avatar-small {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
}

.driver-photo {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  object-fit: cover;
}

.driver-avatar-placeholder {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 20px;
  font-weight: 700;
}

.item-info {
  flex: 1;
  min-width: 0;
}

.item-title {
  font-weight: 600;
  color: #1e293b;
  font-size: 14px;
  margin-bottom: 4px;
}

.item-subtitle {
  font-size: 12px;
  color: #64748b;
  margin-bottom: 4px;
}

.item-meta {
  display: flex;
  gap: 8px;
  align-items: center;
}

.current-driver {
  font-size: 11px;
  color: #64748b;
}

.license-badge {
  background: #dbeafe;
  color: #1e40af;
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
}

.item-status {
  flex-shrink: 0;
}

.status-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  display: inline-block;
}

.status-dot.available {
  background: #10b981;
  box-shadow: 0 0 8px rgba(16, 185, 129, 0.5);
}

.status-dot.with-driver {
  background: #3b82f6;
  box-shadow: 0 0 8px rgba(59, 130, 246, 0.5);
}

.empty-state {
  text-align: center;
  padding: 40px 20px;
  color: #64748b;
  font-style: italic;
}

.assignment-panel {
  background: white;
  border-radius: 12px;
  border: 2px solid #667eea;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.assignment-preview {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 32px;
}

.preview-content {
  display: flex;
  align-items: center;
  gap: 32px;
}

.preview-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.preview-icon {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 40px;
}

.bus-icon {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  box-shadow: 0 8px 24px rgba(102, 126, 234, 0.3);
}

.driver-icon {
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  box-shadow: 0 8px 24px rgba(16, 185, 129, 0.3);
}

.preview-details {
  text-align: center;
}

.preview-label {
  font-size: 12px;
  color: #64748b;
  text-transform: uppercase;
  font-weight: 600;
  letter-spacing: 0.5px;
  margin-bottom: 4px;
}

.preview-value {
  font-size: 18px;
  font-weight: 700;
  color: #1e293b;
  margin-bottom: 4px;
}

.preview-sublabel {
  font-size: 12px;
  color: #94a3b8;
}

.assignment-arrow {
  font-size: 32px;
  color: #667eea;
  font-weight: bold;
}

.preview-placeholder {
  text-align: center;
  color: #94a3b8;
  font-style: italic;
  max-width: 300px;
}

.assignment-actions {
  padding: 24px;
  border-top: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.btn {
  padding: 14px 24px;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.btn-assign {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.btn-assign:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(102, 126, 234, 0.4);
}

.btn-assign:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-clear {
  background: #f1f5f9;
  color: #64748b;
}

.btn-clear:hover:not(:disabled) {
  background: #e2e8f0;
}

.btn-clear:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.table-container {
  flex: 1;
  overflow-y: auto;
  padding: 0;
}

.active-buses-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.active-buses-table thead {
  position: sticky;
  top: 0;
  background: #f8fafc;
  z-index: 10;
}

.active-buses-table th {
  padding: 12px 16px;
  text-align: left;
  font-weight: 600;
  color: #475569;
  border-bottom: 2px solid #e2e8f0;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.active-buses-table td {
  padding: 12px 16px;
  border-bottom: 1px solid #f1f5f9;
  vertical-align: middle;
}

.active-buses-table tbody tr:hover {
  background: #f8fafc;
}

.bus-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.bus-icon-tiny {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  flex-shrink: 0;
}

.bus-plate {
  font-weight: 600;
  color: #1e293b;
  font-size: 13px;
}

.bus-amb {
  font-size: 11px;
  color: #64748b;
}

.driver-info {
  color: #1e293b;
  font-weight: 500;
}

.assignment-date {
  color: #64748b;
  font-size: 12px;
}

.table-actions {
  display: flex;
  gap: 6px;
}

.action-btn {
  width: 28px;
  height: 28px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
}

.history-btn {
  background: #fef3c7;
  color: #92400e;
}

.history-btn:hover {
  background: #f59e0b;
  color: white;
  transform: scale(1.1);
}

.reassign-btn {
  background: #dbeafe;
  color: #1e40af;
}

.reassign-btn:hover {
  background: #3b82f6;
  color: white;
  transform: rotate(180deg);
}

.unassign-btn {
  background: #fee2e2;
  color: #991b1b;
}

.unassign-btn:hover {
  background: #ef4444;
  color: white;
  transform: scale(1.1);
}

/* Responsive */
@media (max-width: 1200px) {
  .assignment-container {
    grid-template-columns: 1fr;
    height: auto;
  }

  .panel {
    max-height: 400px;
  }

  .assignment-panel {
    order: -1;
  }
}
</style>

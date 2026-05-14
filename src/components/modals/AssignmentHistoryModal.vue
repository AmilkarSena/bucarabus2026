<template>
  <div v-if="isOpen" class="modal-overlay" @click="closeModal">
    <div class="modal-container" @click.stop>
      <div class="modal-header">
        <div class="header-content">
          <h3>📋 Historial de Asignaciones</h3>
          <div class="bus-info-header">
            <span class="bus-plate-badge">{{ bus.plate_number }}</span>
            <span class="bus-amb-text">{{ bus.amb_code }}</span>
          </div>
        </div>
        <button class="close-btn" @click="closeModal">✕</button>
      </div>

      <!-- Filtros -->
      <div class="filters-section">
        <div class="filter-group">
          <label class="filter-label">Buscar Conductor</label>
          <input
            type="text"
            v-model="filters.searchDriver"
            placeholder="Nombre del conductor..."
            class="filter-input"
          />
        </div>

        <div class="filter-group">
          <label class="filter-label">Desde</label>
          <input
            type="date"
            v-model="filters.dateFrom"
            class="filter-input"
          />
        </div>

        <div class="filter-group">
          <label class="filter-label">Hasta</label>
          <input
            type="date"
            v-model="filters.dateTo"
            class="filter-input"
          />
        </div>

        <div class="filter-group">
          <label class="filter-label">Ordenar por</label>
          <select v-model="filters.sortBy" class="filter-select">
            <option value="recent">Más reciente</option>
            <option value="oldest">Más antiguo</option>
          </select>
        </div>

        <button class="clear-filters-btn" @click="clearFilters" title="Limpiar filtros">
          ✕ Limpiar
        </button>
      </div>

      <div class="modal-body">
        <div v-if="loading" class="loading-state">
          <p>Cargando historial...</p>
        </div>

        <div v-else-if="filteredHistory.length === 0" class="empty-state">
          <p>{{ history.length === 0 ? 'No hay historial de asignaciones para este bus' : 'No se encontraron registros con los filtros aplicados' }}</p>
        </div>

        <div v-else class="history-table-container">
          <div class="results-count">
            Mostrando {{ filteredHistory.length }} de {{ history.length }} registros
          </div>
          <table class="history-table">
            <thead>
              <tr>
                <th>Fecha Asignación</th>
                <th>Fecha Desasignación</th>
                <th>Conductor</th>
                <th>Duración</th>
                <th>Estado</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="record in filteredHistory" :key="record.id">
                <td>
                  <div class="date-cell">
                    {{ formatDate(record.assignment_date) }}
                  </div>
                </td>
                <td>
                  <div class="date-cell">
                    {{ record.unassignment_date ? formatDate(record.unassignment_date) : '-' }}
                  </div>
                </td>
                <td>
                  <div class="driver-cell">
                    <span class="driver-icon">👨‍✈️</span>
                    {{ record.driver_name }}
                  </div>
                </td>
                <td>
                  <div class="duration-cell">
                    {{ calculateDuration(record) }}
                  </div>
                </td>
                <td>
                  <span class="status-badge" :class="getStatusClass(record)">
                    {{ getStatusText(record) }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="modal-footer">
        <button class="btn btn-secondary" @click="closeModal">Cerrar</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import * as assignmentsApi from '../../api/assignments.js'

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  },
  bus: {
    type: Object,
    required: true
  }
})

const emit = defineEmits(['close'])

const loading = ref(false)
const history = ref([])
const filters = ref({
  searchDriver: '',
  dateFrom: '',
  dateTo: '',
  sortBy: 'recent'
})

// Definir clearFilters antes de usarla en el watch
const clearFilters = () => {
  filters.value = {
    searchDriver: '',
    dateFrom: '',
    dateTo: '',
    sortBy: 'recent'
  }
}

// Cargar historial desde la API
const loadHistory = async () => {
  if (!props.bus?.plate_number) {
    console.warn('⚠️ No hay placa de bus')
    return
  }
  
  loading.value = true
  
  try {
    console.log('🔄 Cargando historial para:', props.bus.plate_number)
    const result = await assignmentsApi.getBusHistory(props.bus.plate_number)
    console.log('📥 Resultado API:', result)
    
    if (result.success) {
      history.value = result.data.map(record => ({
        id: record.id_assignment,
        assignment_date: record.assigned_at,
        unassignment_date: record.unassigned_at,
        driver_name: record.name_driver,
        id_user: record.id_user
      }))
      console.log('✅ Historial cargado:', history.value.length, 'registros')
    } else {
      console.warn('⚠️ API retornó success: false', result)
      history.value = []
    }
  } catch (error) {
    console.error('❌ Error al cargar historial:', error)
    history.value = []
  } finally {
    loading.value = false
  }
}

// Cargar al montar si está abierto
onMounted(() => {
  console.log('🚀 Modal montado, isOpen:', props.isOpen, 'bus:', props.bus?.plate_number)
  if (props.isOpen && props.bus) {
    loadHistory()
  }
})

// Watch con immediate para capturar cambios
watch(() => props.isOpen, (newValue) => {
  console.log('👁️ Watch isOpen:', newValue)
  if (newValue && props.bus) {
    loadHistory()
    clearFilters()
  }
}, { immediate: true })

// Computed para filtrar y ordenar
const filteredHistory = computed(() => {
  let filtered = [...history.value]

  // Filtro por nombre de conductor
  if (filters.value.searchDriver) {
    const search = filters.value.searchDriver.toLowerCase()
    filtered = filtered.filter(record => 
      record.driver_name.toLowerCase().includes(search)
    )
  }

  // Filtro por fecha desde
  if (filters.value.dateFrom) {
    const fromDate = new Date(filters.value.dateFrom)
    filtered = filtered.filter(record => {
      const assignDate = new Date(record.assignment_date)
      return assignDate >= fromDate
    })
  }

  // Filtro por fecha hasta
  if (filters.value.dateTo) {
    const toDate = new Date(filters.value.dateTo)
    toDate.setHours(23, 59, 59, 999) // Incluir todo el día
    filtered = filtered.filter(record => {
      const assignDate = new Date(record.assignment_date)
      return assignDate <= toDate
    })
  }

  // Ordenar
  filtered.sort((a, b) => {
    const dateA = new Date(a.assignment_date)
    const dateB = new Date(b.assignment_date)
    
    if (filters.value.sortBy === 'recent') {
      return dateB - dateA // Más reciente primero
    } else {
      return dateA - dateB // Más antiguo primero
    }
  })

  return filtered
})

const closeModal = () => {
  emit('close')
}

const formatDate = (dateString) => {
  const date = new Date(dateString)
  const day = String(date.getDate()).padStart(2, '0')
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const year = date.getFullYear()
  const hours = String(date.getHours()).padStart(2, '0')
  const minutes = String(date.getMinutes()).padStart(2, '0')
  
  return `${day}/${month}/${year} ${hours}:${minutes}`
}

const calculateDuration = (record) => {
  const start = new Date(record.assignment_date)
  const end = record.unassignment_date ? new Date(record.unassignment_date) : new Date()
  
  const diffTime = end - start
  const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24))
  
  if (diffDays === 0) return 'Menos de 1 día'
  if (diffDays === 1) return '1 día'
  if (diffDays < 30) return `${diffDays} días`
  
  const months = Math.floor(diffDays / 30)
  const remainingDays = diffDays % 30
  
  if (months === 1 && remainingDays === 0) return '1 mes'
  if (months === 1) return `1 mes ${remainingDays} días`
  if (remainingDays === 0) return `${months} meses`
  return `${months} meses ${remainingDays} días`
}

const getStatusClass = (record) => {
  return record.unassignment_date ? 'status-completed' : 'status-active'
}

const getStatusText = (record) => {
  return record.unassignment_date ? 'Finalizado' : 'Activo'
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(4px);
}

.modal-container {
  background: white;
  border-radius: 16px;
  width: 90%;
  max-width: 1000px;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  animation: modalSlideIn 0.3s ease-out;
}

@keyframes modalSlideIn {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.modal-header {
  padding: 24px;
  border-bottom: 1px solid #e2e8f0;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.header-content h3 {
  margin: 0 0 12px 0;
  font-size: 20px;
  font-weight: 700;
  color: #1e293b;
}

.bus-info-header {
  display: flex;
  align-items: center;
  gap: 12px;
}

.bus-plate-badge {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 6px 16px;
  border-radius: 8px;
  font-weight: 700;
  font-size: 16px;
  letter-spacing: 1px;
}

.bus-amb-text {
  color: #64748b;
  font-size: 14px;
  font-weight: 500;
}

.close-btn {
  background: #f1f5f9;
  border: none;
  width: 36px;
  height: 36px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 20px;
  color: #64748b;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.close-btn:hover {
  background: #e2e8f0;
  color: #1e293b;
}

.filters-section {
  padding: 20px 24px;
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
  display: grid;
  grid-template-columns: 2fr 1fr 1fr 1.2fr auto;
  gap: 12px;
  align-items: end;
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.filter-label {
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.filter-input,
.filter-select {
  padding: 8px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  font-size: 13px;
  transition: border-color 0.2s ease;
  background: white;
}

.filter-input:focus,
.filter-select:focus {
  outline: none;
  border-color: #667eea;
}

.filter-select {
  cursor: pointer;
}

.clear-filters-btn {
  padding: 8px 16px;
  background: #fee2e2;
  color: #991b1b;
  border: none;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  white-space: nowrap;
}

.clear-filters-btn:hover {
  background: #ef4444;
  color: white;
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
}

.results-count {
  margin-bottom: 12px;
  font-size: 12px;
  color: #64748b;
  font-weight: 500;
}

.loading-state,
.empty-state {
  text-align: center;
  padding: 60px 20px;
  color: #64748b;
  font-style: italic;
}

.history-table-container {
  overflow-x: auto;
}

.history-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.history-table thead {
  background: #f8fafc;
}

.history-table th {
  padding: 12px 16px;
  text-align: left;
  font-weight: 600;
  color: #475569;
  border-bottom: 2px solid #e2e8f0;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.history-table td {
  padding: 16px;
  border-bottom: 1px solid #f1f5f9;
  vertical-align: middle;
}

.history-table tbody tr:hover {
  background: #f8fafc;
}

.date-cell {
  color: #1e293b;
  font-size: 13px;
}

.driver-cell {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #1e293b;
  font-weight: 500;
}

.driver-icon {
  font-size: 16px;
}

.duration-cell {
  color: #64748b;
  font-weight: 500;
}

.status-badge {
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.status-active {
  background: #d1fae5;
  color: #065f46;
}

.status-completed {
  background: #e0e7ff;
  color: #3730a3;
}

.modal-footer {
  padding: 20px 24px;
  border-top: 1px solid #e2e8f0;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.btn {
  padding: 10px 24px;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-secondary {
  background: #f1f5f9;
  color: #64748b;
}

.btn-secondary:hover {
  background: #e2e8f0;
  color: #1e293b;
}

/* Responsive */
@media (max-width: 900px) {
  .filters-section {
    grid-template-columns: 1fr;
  }

  .filter-group {
    width: 100%;
  }
}
</style>

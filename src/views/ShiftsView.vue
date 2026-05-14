<template>
  <div class="shifts-dashboard">
    <!-- Header -->
    <header class="dashboard-header">
      <div class="header-content">
        <h1>📊 Gestión de Turnos</h1>
        <p class="header-subtitle">Administra los horarios de las rutas</p>
      </div>
    </header>

    <!-- Estadísticas Rápidas -->
    <section class="stats-section">
      <div class="stat-card">
        <div class="stat-icon blue">🚌</div>
        <div class="stat-info">
          <span class="stat-value">{{ totalShifts }}</span>
          <span class="stat-label">Turnos Totales</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon green">✓</div>
        <div class="stat-info">
          <span class="stat-value">{{ assignedShifts }}</span>
          <span class="stat-label">Asignados</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon orange">⏳</div>
        <div class="stat-info">
          <span class="stat-value">{{ pendingShifts }}</span>
          <span class="stat-label">Pendientes</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon purple">🛣️</div>
        <div class="stat-info">
          <span class="stat-value">{{ activeRoutes }}</span>
          <span class="stat-label">Rutas Activas</span>
        </div>
      </div>
    </section>

    <!-- Filtros -->
    <section class="filters-section">
      <div class="filter-group">
        <label>Semana:</label>
        <div class="week-navigator">
          <button class="nav-btn" @click="previousWeek">◀</button>
          <span class="week-label">{{ weekRangeLabel }}</span>
          <button class="nav-btn" @click="nextWeek">▶</button>
          <input 
            type="date" 
            :value="weekPickerDate"
            @change="goToSelectedWeek"
            class="week-picker"
            title="Selecciona una fecha para ir a esa semana"
          />
        </div>
      </div>
      <button class="btn-today" @click="goToCurrentWeek">
        📅 Hoy
      </button>
    </section>

    <!-- Tabla de Turnos por Ruta y Fecha -->
    <section class="shifts-table-section">
      <!-- Indicador de carga -->
      <div v-if="tripsStore.loading" class="loading-overlay">
        <div class="loading-spinner">
          <div class="spinner"></div>
          <p>Cargando turnos...</p>
        </div>
      </div>
      
      <div class="table-container">
        <table class="shifts-table">
          <thead>
            <tr>
              <th class="route-column">Ruta</th>
              <th 
                v-for="day in weekDays" 
                :key="day.dateStr" 
                class="day-column"
                :class="{ 'today': day.isToday }"
              >
                <span class="day-name">{{ day.dayName }}</span>
                <span class="day-number">{{ day.dayNumber }}</span>
              </th>
              <th class="actions-column">Acciones</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="route in routesList" :key="route.id">
              <td class="route-cell">
                <div class="route-info">
                  <span class="route-color" :style="{ backgroundColor: route.color || '#667eea' }"></span>
                  <span class="route-name">{{ route.name }}</span>
                </div>
              </td>
              <td 
                v-for="day in weekDays" 
                :key="`${route.id}-${day.dateStr}`"
                class="shift-cell"
                :class="{ 'today': day.isToday }"
                @click="openShiftsModal(route.id, day.dateStr)"
              >
                <div v-if="getShiftsForDay(route.id, day.dateStr)" class="shift-badge" :class="getShiftStatus(route.id, day.dateStr)">
                  <span class="shift-count">{{ getShiftsForDay(route.id, day.dateStr).total }}</span>
                  <span class="shift-status-icon">
                    {{ getShiftsForDay(route.id, day.dateStr).allAssigned ? '✓' : '⏳' }}
                  </span>
                </div>
                <div v-else class="no-shifts">
                  <span class="add-icon">+</span>
                </div>
              </td>
              <td class="actions-cell">
                <button class="action-btn view" @click="viewRouteDetails(route)" title="Ver detalles">
                  👁️
                </button>
                <button v-if="authStore.can('CREATE_TRIPS')" class="action-btn generate" @click="openShiftsModal(route.id)" title="Generar horario">
                  ➕
                </button>
              </td>
            </tr>
            <tr v-if="routesList.length === 0">
              <td colspan="9" class="empty-state">
                <p>No hay rutas registradas.</p>
                <p>Crea una ruta primero para generar horarios.</p>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Turnos Recientes -->
    <section class="recent-shifts-section">
      <h3 class="section-title">📋 Turnos Recientes</h3>
      <div class="recent-shifts-list">
        <div v-for="shift in recentShifts" :key="shift.id" class="recent-shift-card">
          <div class="shift-route">
            <span class="route-dot" :style="{ backgroundColor: shift.routeColor || '#667eea' }"></span>
            {{ shift.routeName }}
          </div>
          <div class="shift-date">{{ formatDate(shift.date) }}</div>
          <div class="shift-stats">
            <span class="stat assigned">{{ shift.assigned }}/{{ shift.total }}</span>
            asignados
          </div>
          <button class="btn-view-shift" @click="openShiftsModal(shift.routeId, shift.date)">
            Ver
          </button>
        </div>
        <div v-if="recentShifts.length === 0" class="no-recent">
          <p>No hay turnos generados aún.</p>
          <p>Haz clic en "Generar Horario" para comenzar.</p>
        </div>
      </div>
    </section>

    <!-- Modal de Turnos -->
    <ShiftsModal
      :is-open="showShiftsModal"
      :initial-route-id="selectedRouteId"
      :initial-date="selectedDate"
      @close="closeShiftsModal"
      @save="handleSaveSchedule"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoutesStore } from '../stores/routes'
import { useTripsStore } from '../stores/trips'
import { useAuthStore } from '../stores/auth'
import ShiftsModal from '../components/modals/ShiftsModal.vue'

const routesStore = useRoutesStore()
const tripsStore = useTripsStore()
const authStore = useAuthStore()

console.log('🎯 ShiftsView component initialized')

// Estado del modal
const showShiftsModal = ref(false)
const selectedRouteId = ref('')
const selectedDate = ref(null)

// Estado de la semana actual
const currentWeekStart = ref(getMonday(new Date()))

// Computed
const routesList = computed(() => routesStore.routesList.filter(r => r.isActive !== false))

const weekPickerDate = computed(() => {
  const year = currentWeekStart.value.getFullYear()
  const month = String(currentWeekStart.value.getMonth() + 1).padStart(2, '0')
  const day = String(currentWeekStart.value.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
})

const weekDays = computed(() => {
  const days = []
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  
  for (let i = 0; i < 7; i++) {
    const date = new Date(currentWeekStart.value)
    date.setDate(date.getDate() + i)
    
    const dayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
    
    days.push({
      date: date,
      dateStr: formatDateStr(date),
      dayName: dayNames[date.getDay()],
      dayNumber: date.getDate(),
      isToday: date.getTime() === today.getTime()
    })
  }
  return days
})

const weekRangeLabel = computed(() => {
  const start = currentWeekStart.value
  const end = new Date(start)
  end.setDate(end.getDate() + 6)
  
  const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']
  
  if (start.getMonth() === end.getMonth()) {
    return `${start.getDate()} - ${end.getDate()} ${months[start.getMonth()]} ${start.getFullYear()}`
  } else {
    return `${start.getDate()} ${months[start.getMonth()]} - ${end.getDate()} ${months[end.getMonth()]} ${end.getFullYear()}`
  }
})

// Computed para estadísticas usando el store de trips
const weekStats = computed(() => {
  if (!routesList.value.length || !weekDays.value.length) {
    return { total: 0, assigned: 0, pending: 0, byRoute: {} }
  }
  
  const dates = weekDays.value.map(d => d.dateStr)
  const stats = tripsStore.getStatsForWeek(routesList.value, dates)
  return stats
})

const totalShifts = computed(() => weekStats.value.total)
const assignedShifts = computed(() => weekStats.value.assigned)
const pendingShifts = computed(() => weekStats.value.pending)
const activeRoutes = computed(() => {
  return Object.keys(weekStats.value.byRoute || {}).filter(routeId => {
    return weekStats.value.byRoute[routeId].active > 0
  }).length
})

const recentShifts = computed(() => {
  const shifts = []
  const stats = weekStats.value.byRoute || {}
  
  Object.entries(stats).forEach(([routeId, routeStats]) => {
    Object.entries(routeStats.byDate || {}).forEach(([date, dateStats]) => {
      if (dateStats.total > 0) {
        // routeId ahora es numérico (ej: 1, 2, 3)
        const route = routesList.value.find(r => r.id == routeId)
        shifts.push({
          id: `${routeId}-${date}`,
          routeId: routeId, // ID numérico de la ruta
          routeName: route?.name || 'Ruta desconocida',
          routeColor: route?.color,
          date: date,
          total: dateStats.total,
          assigned: dateStats.assigned
        })
      }
    })
  })
  
  // Ordenar por fecha descendente y tomar los primeros 5
  return shifts
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .slice(0, 5)
})

// Métodos
function getMonday(date) {
  const d = new Date(date)
  const day = d.getDay()
  const diff = d.getDate() - day + (day === 0 ? -6 : 1)
  d.setDate(diff)
  d.setHours(0, 0, 0, 0)
  return d
}

function formatDateStr(date) {
  // Si ya es un string en formato YYYY-MM-DD, devolverlo
  if (typeof date === 'string') {
    return date.split('T')[0]
  }
  // Si es un objeto Date
  if (date instanceof Date && !isNaN(date.getTime())) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
  // Fallback
  return new Date().toISOString().split('T')[0]
}

function formatDate(dateStr) {
  const date = new Date(dateStr + 'T00:00:00')
  const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
  const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']
  return `${days[date.getDay()]} ${date.getDate()} ${months[date.getMonth()]}`
}

function previousWeek() {
  const newStart = new Date(currentWeekStart.value)
  newStart.setDate(newStart.getDate() - 7)
  currentWeekStart.value = newStart
}

function nextWeek() {
  const newStart = new Date(currentWeekStart.value)
  newStart.setDate(newStart.getDate() + 7)
  currentWeekStart.value = newStart
}

function goToCurrentWeek() {
  currentWeekStart.value = getMonday(new Date())
}

function goToSelectedWeek(event) {
  const selectedDateStr = event.target.value
  const selectedDate = new Date(selectedDateStr + 'T00:00:00')
  currentWeekStart.value = getMonday(selectedDate)
}

function getShiftsForDay(routeId, dateStr) {
  const stats = weekStats.value.byRoute?.[routeId]?.byDate?.[dateStr]
  if (!stats || stats.total === 0) return null
  
  return {
    total: stats.total,
    assigned: stats.assigned,
    allAssigned: stats.assigned === stats.total
  }
}

function getShiftStatus(routeId, dateStr) {
  const shift = getShiftsForDay(routeId, dateStr)
  if (!shift) return ''
  return shift.allAssigned ? 'complete' : 'pending'
}

function openShiftsModal(routeId = '', date = null) {
  selectedRouteId.value = routeId
  selectedDate.value = date
  showShiftsModal.value = true
}

function closeShiftsModal() {
  showShiftsModal.value = false
  selectedRouteId.value = ''
  selectedDate.value = null
}

function handleSaveSchedule(scheduleData) {
  console.log('📅 Guardando horario:', scheduleData)
  
  // El modal ya guardó los datos en la BD usando tripsStore.createTripsBatch
  // Solo necesitamos recargar los datos de esa ruta/fecha
  closeShiftsModal()
  
  // Recargar datos de la semana actual para reflejar los cambios
  loadTripsForCurrentWeek()
}

function viewRouteDetails(route) {
  console.log('Ver detalles de ruta:', route)
  // TODO: Implementar vista de detalles o abrir modal
}

// Función principal para cargar trips de la semana actual
async function loadTripsForCurrentWeek() {
  if (!routesList.value.length || !weekDays.value.length) {
    console.log('⏳ Esperando rutas y días de la semana...')
    return
  }

  try {
    console.log('🔄 Cargando trips para la semana actual...')
    
    const dates = weekDays.value.map(d => d.dateStr)
    await tripsStore.fetchTripsForWeek(routesList.value, dates)
    
    console.log('✅ Trips de la semana cargados')
  } catch (error) {
    console.error('❌ Error cargando trips de la semana:', error)
  }
}

// Watch para recargar cuando cambia la semana
watch(currentWeekStart, () => {
  console.log('📅 Cambió la semana, recargando turnos...')
  loadTripsForCurrentWeek()
})


// Inicialización
onMounted(async () => {
  console.log('🎯 Inicializando ShiftsView...')
  
  // 1. Cargar rutas primero
  const timeoutId = setTimeout(() => {
    console.warn('⚠️ Timeout cargando rutas')
  }, 5000)

  try {
    await routesStore.loadRoutes()
    clearTimeout(timeoutId)
    console.log('📊 Rutas cargadas')
    
    // 2. Cargar trips de la semana actual
    await loadTripsForCurrentWeek()
  } catch (error) {
    clearTimeout(timeoutId)
    console.error('❌ Error en inicialización:', error)
  }
})
</script>

<style scoped>
.shifts-dashboard {
  padding: 24px;
  max-width: 1400px;
  margin: 0 auto;
  font-family: 'Inter', sans-serif;
}

/* Header */
.dashboard-header {
  margin-bottom: 16px;
}

.header-content h1 {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: #1e293b;
}

.header-subtitle {
  margin: 2px 0 0;
  color: #64748b;
  font-size: 13px;
}

/* Estadísticas */
.stats-section {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 10px;
  margin-bottom: 16px;
}

.stat-card {
  background: white;
  border-radius: 10px;
  padding: 10px 14px;
  display: flex;
  align-items: center;
  gap: 10px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
  transition: all 0.3s ease;
}

.stat-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 3px 8px rgba(0, 0, 0, 0.1);
}

.stat-icon {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  flex-shrink: 0;
}

.stat-icon.blue { background: #dbeafe; }
.stat-icon.green { background: #d1fae5; }
.stat-icon.orange { background: #fed7aa; }
.stat-icon.purple { background: #e9d5ff; }

.stat-info {
  display: flex;
  flex-direction: column;
}

.stat-value {
  font-size: 20px;
  font-weight: 700;
  color: #1e293b;
  line-height: 1;
}

.stat-label {
  font-size: 11px;
  color: #64748b;
  margin-top: 2px;
}

/* Filtros */
.filters-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  background: white;
  padding: 10px 16px;
  border-radius: 10px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 12px;
}

.filter-group label {
  font-weight: 600;
  color: #374151;
  font-size: 14px;
}

.week-navigator {
  display: flex;
  align-items: center;
  gap: 12px;
}

.nav-btn {
  background: #f1f5f9;
  border: none;
  width: 36px;
  height: 36px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 14px;
  color: #64748b;
  transition: all 0.2s ease;
}

.nav-btn:hover {
  background: #667eea;
  color: white;
}

.week-label {
  font-weight: 600;
  color: #1e293b;
  min-width: 180px;
  text-align: center;
}

.week-picker {
  padding: 8px 12px;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  font-size: 14px;
  color: #1e293b;
  background: white;
  cursor: pointer;
  transition: all 0.2s ease;
}

.week-picker:hover {
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.week-picker:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.btn-today {
  background: #f1f5f9;
  border: none;
  padding: 10px 16px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  color: #667eea;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-today:hover {
  background: #667eea;
  color: white;
}

/* Tabla de Turnos */
.shifts-table-section {
  background: white;
  border-radius: 16px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
  overflow: hidden;
  margin-bottom: 32px;
  position: relative;
  height: calc(100vh - 360px);
  min-height: 360px;
}

/* Loading overlay */
.loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 255, 255, 0.9);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10;
}

.loading-spinner {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #e2e8f0;
  border-top-color: #667eea;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading-spinner p {
  color: #64748b;
  font-size: 14px;
  font-weight: 500;
  margin: 0;
}


.table-container {
  overflow-x: auto;
  overflow-y: auto;
  max-height: 100%;
}

.shifts-table {
  width: 100%;
  border-collapse: collapse;
}

.shifts-table th {
  background: #f8fafc;
  padding: 16px 12px;
  text-align: center;
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 2px solid #e2e8f0;
  position: sticky;
  top: 0;
  z-index: 1;
}

.shifts-table th.route-column {
  text-align: left;
  padding-left: 20px;
  min-width: 180px;
}

.shifts-table th.day-column {
  min-width: 80px;
}

.shifts-table th.day-column.today {
  background: #dbeafe;
}

.day-name {
  display: block;
  font-size: 11px;
  color: #94a3b8;
}

.day-number {
  display: block;
  font-size: 16px;
  font-weight: 700;
  color: #1e293b;
  margin-top: 2px;
}

.shifts-table th.today .day-number {
  color: #667eea;
}

.shifts-table th.actions-column {
  min-width: 100px;
}

.shifts-table td {
  padding: 12px;
  border-bottom: 1px solid #f1f5f9;
  text-align: center;
  vertical-align: middle;
}

.route-cell {
  text-align: left;
  padding-left: 20px !important;
}

.route-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.route-color {
  width: 8px;
  height: 32px;
  border-radius: 4px;
}

.route-name {
  font-weight: 600;
  color: #1e293b;
  font-size: 14px;
}

.shift-cell {
  cursor: pointer;
  transition: all 0.2s ease;
}

.shift-cell:hover {
  background: #f1f5f9;
}

.shift-cell.today {
  background: #f0f9ff;
}

.shift-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 600;
}

.shift-badge.complete {
  background: #d1fae5;
  color: #059669;
}

.shift-badge.pending {
  background: #fef3c7;
  color: #d97706;
}

.shift-count {
  font-size: 14px;
}

.shift-status-icon {
  font-size: 12px;
}

.no-shifts {
  color: #cbd5e1;
  transition: all 0.2s ease;
}

.no-shifts:hover {
  color: #667eea;
}

.add-icon {
  font-size: 20px;
  font-weight: 300;
}

.actions-cell {
  display: flex;
  justify-content: center;
  gap: 8px;
}

.action-btn {
  background: #f1f5f9;
  border: none;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.2s ease;
}

.action-btn:hover {
  transform: scale(1.1);
}

.action-btn.view:hover {
  background: #dbeafe;
}

.action-btn.generate:hover {
  background: #d1fae5;
}

.empty-state {
  text-align: center;
  padding: 60px 20px !important;
  color: #94a3b8;
}

.empty-state p {
  margin: 0 0 8px 0;
}

/* Turnos Recientes */
.recent-shifts-section {
  background: white;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.06);
}

.section-title {
  margin: 0 0 20px 0;
  font-size: 18px;
  font-weight: 700;
  color: #1e293b;
}

.recent-shifts-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.recent-shift-card {
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 16px;
  background: #f8fafc;
  border-radius: 12px;
  transition: all 0.2s ease;
}

.recent-shift-card:hover {
  background: #f1f5f9;
}

.shift-route {
  display: flex;
  align-items: center;
  gap: 10px;
  font-weight: 600;
  color: #1e293b;
  min-width: 150px;
}

.route-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.shift-date {
  color: #64748b;
  font-size: 14px;
  min-width: 100px;
}

.shift-stats {
  flex: 1;
  font-size: 14px;
  color: #64748b;
}

.shift-stats .stat {
  font-weight: 600;
}

.shift-stats .stat.assigned {
  color: #059669;
}

.btn-view-shift {
  background: #667eea;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-view-shift:hover {
  background: #5a67d8;
}

.no-recent {
  text-align: center;
  padding: 40px 20px;
  color: #94a3b8;
}

.no-recent p {
  margin: 0 0 8px 0;
}

/* Responsive */
@media (max-width: 1024px) {
  .shifts-dashboard {
    padding: 16px;
  }

  .shifts-table-section {
    height: calc(100vh - 420px);
  }
  
  .dashboard-header {
    flex-direction: column;
    gap: 16px;
    text-align: center;
  }
  
  .stats-section {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .filters-section {
    flex-direction: column;
    gap: 16px;
  }
}

@media (max-width: 768px) {
  .stats-section {
    grid-template-columns: 1fr;
  }

  .shifts-table-section {
    height: calc(100vh - 460px);
  }
  
  .recent-shift-card {
    flex-wrap: wrap;
  }
  
  .shift-route {
    width: 100%;
  }
}
</style>

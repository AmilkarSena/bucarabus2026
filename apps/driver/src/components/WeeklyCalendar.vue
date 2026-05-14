<template>
  <div class="weekly-calendar">
    <!-- Header Semanal -->
    <div class="calendar-header">
      <div class="week-controls">
        <button class="btn-nav" @click="previousWeek">◀</button>
        <span class="month-label">{{ currentMonthLabel }}</span>
        <button class="btn-nav" @click="nextWeek">▶</button>
      </div>
      <button class="btn-today" @click="goToToday" v-if="!isCurrentWeek">Hoy</button>
    </div>

    <!-- Slider de Días -->
    <div class="days-slider" ref="sliderRef">
      <div 
        v-for="day in weekDays" 
        :key="day.dateStr"
        class="day-card"
        :class="{ 
          'active': day.dateStr === selectedDateStr,
          'today': day.isToday 
        }"
        @click="selectDate(day.dateStr)"
      >
        <div v-if="weeklyCounts[day.dateStr] > 0" class="trip-badge">{{ weeklyCounts[day.dateStr] }}</div>
        
        <span class="day-name">{{ day.dayName }}</span>
        <span class="day-number">{{ day.dayNumber }}</span>
        <div v-if="day.isToday" class="today-dot"></div>
      </div>
    </div>

    <!-- Lista de Viajes -->
    <div class="trips-container">
      <div class="date-header">
        <h3>Viajes para el {{ formattedSelectedDate }}</h3>
      </div>

      <div v-if="loading" class="loading-state">
        <div class="spinner"></div>
        <p>Cargando viajes...</p>
      </div>

      <div v-else-if="trips.length === 0" class="empty-state">
        <span class="empty-icon">🏖️</span>
        <p>No tienes viajes asignados para este día.</p>
      </div>

      <div v-else class="trips-list">
        <div 
          v-for="trip in trips" 
          :key="trip.id_trip"
          class="trip-card"
          :class="getTripStatusClass(trip.status_trip)"
        >
          <div class="trip-time">
            <span class="time">{{ formatTime(trip.start_time) }}</span>
            <span class="time-separator">-</span>
            <span class="time">{{ formatTime(trip.end_time) }}</span>
          </div>
          
          <div class="trip-details">
            <div class="route-info">
              <span class="route-color" :style="{ backgroundColor: trip.color }"></span>
              <span class="route-name">{{ trip.name }}</span>
            </div>
            <span class="trip-status">{{ getTripStatusLabel(trip.status_trip) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'

const props = defineProps({
  trips: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  weeklyCounts: { type: Object, default: () => ({}) }
})

const emit = defineEmits(['date-changed', 'week-changed'])

// Estado de fechas
const selectedDate = ref(new Date())
const currentWeekStart = ref(getMonday(new Date()))

// Métodos de utilidades de fecha
function getMonday(d) {
  const date = new Date(d)
  const day = date.getDay()
  const diff = date.getDate() - day + (day === 0 ? -6 : 1)
  date.setDate(diff)
  date.setHours(0, 0, 0, 0)
  return date
}

function formatDateStr(date) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

const selectedDateStr = computed(() => formatDateStr(selectedDate.value))

const isCurrentWeek = computed(() => {
  const todayMonday = getMonday(new Date())
  return currentWeekStart.value.getTime() === todayMonday.getTime()
})

const currentMonthLabel = computed(() => {
  const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre']
  return `${months[currentWeekStart.value.getMonth()]} ${currentWeekStart.value.getFullYear()}`
})

const formattedSelectedDate = computed(() => {
  const days = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
  const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']
  const d = selectedDate.value
  return `${days[d.getDay()]} ${d.getDate()} de ${months[d.getMonth()]}`
})

const weekDays = computed(() => {
  const days = []
  const todayStr = formatDateStr(new Date())
  
  for (let i = 0; i < 7; i++) {
    const d = new Date(currentWeekStart.value)
    d.setDate(d.getDate() + i)
    
    const dayNames = ['D', 'L', 'M', 'X', 'J', 'V', 'S']
    
    days.push({
      date: d,
      dateStr: formatDateStr(d),
      dayName: dayNames[d.getDay()],
      dayNumber: d.getDate(),
      isToday: formatDateStr(d) === todayStr
    })
  }
  return days
})

// Acciones
const selectDate = (dateStr) => {
  const parts = dateStr.split('-')
  selectedDate.value = new Date(parts[0], parts[1] - 1, parts[2])
  emit('date-changed', dateStr)
}

const previousWeek = () => {
  const newStart = new Date(currentWeekStart.value)
  newStart.setDate(newStart.getDate() - 7)
  currentWeekStart.value = newStart
  
  // Si retrocedemos, seleccionamos el lunes de esa semana
  selectDate(formatDateStr(newStart))
}

const nextWeek = () => {
  const newStart = new Date(currentWeekStart.value)
  newStart.setDate(newStart.getDate() + 7)
  currentWeekStart.value = newStart
  
  selectDate(formatDateStr(newStart))
}

const goToToday = () => {
  const today = new Date()
  currentWeekStart.value = getMonday(today)
  selectDate(formatDateStr(today))
}

// Formateo de Viajes
const formatTime = (timeStr) => {
  if (!timeStr) return ''
  const [hours, minutes] = timeStr.split(':')
  const h = parseInt(hours)
  const ampm = h >= 12 ? 'PM' : 'AM'
  const h12 = h % 12 || 12
  return `${h12}:${minutes} ${ampm}`
}

const getTripStatusLabel = (statusId) => {
  const statuses = { 1: 'Pendiente', 2: 'Asignado', 3: 'En Progreso', 4: 'Completado' }
  return statuses[statusId] || 'Desconocido'
}

const getTripStatusClass = (statusId) => {
  if (statusId === 4) return 'completed'
  if (statusId === 3) return 'in-progress'
  return 'pending'
}

// Iniciar cargando el día de hoy y la semana actual
onMounted(() => {
  emit('week-changed', formatDateStr(currentWeekStart.value))
  emit('date-changed', selectedDateStr.value)
})

watch(currentWeekStart, (newStart) => {
  emit('week-changed', formatDateStr(newStart))
})
</script>

<style scoped>
.weekly-calendar {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #0f172a;
  color: white;
}

/* Header */
.calendar-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px 8px;
}

.week-controls {
  display: flex;
  align-items: center;
  gap: 16px;
}

.btn-nav {
  background: rgba(255, 255, 255, 0.1);
  border: none;
  color: white;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  cursor: pointer;
}

.month-label {
  font-weight: 600;
  font-size: 1.1rem;
  min-width: 120px;
  text-align: center;
}

.btn-today {
  background: rgba(34, 197, 94, 0.2);
  color: #4ade80;
  border: 1px solid rgba(34, 197, 94, 0.3);
  padding: 6px 12px;
  border-radius: 16px;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
}

/* Slider de días */
.days-slider {
  display: flex;
  justify-content: space-between;
  padding: 12px 16px 20px;
  border-bottom: 1px solid #1e293b;
}

.day-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 60px;
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
  position: relative;
}

.day-name {
  font-size: 0.75rem;
  color: #94a3b8;
  margin-bottom: 4px;
}

.day-number {
  font-size: 1.1rem;
  font-weight: 600;
}

.day-card.today .day-number {
  color: #4ade80;
}

.today-dot {
  width: 4px;
  height: 4px;
  background: #4ade80;
  border-radius: 50%;
  position: absolute;
  bottom: 6px;
}

.day-card.active {
  background: #667eea;
  color: white;
}

.day-card.active .day-name,
.day-card.active .day-number {
  color: white;
}

.day-card.active .today-dot {
  background: white;
}

.trip-badge {
  position: absolute;
  top: -6px;
  right: -6px;
  background: #ef4444; /* Rojo de alerta */
  color: white;
  font-size: 0.65rem;
  font-weight: 700;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px solid #0f172a;
}

.day-card.active .trip-badge {
  border-color: #667eea;
}

/* Lista de Viajes */
.trips-container {
  flex: 1;
  padding: 20px 16px;
  overflow-y: auto;
}

.date-header h3 {
  margin: 0 0 16px 0;
  font-size: 1rem;
  color: #cbd5e1;
  font-weight: 500;
}

.trips-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.trip-card {
  background: #1e293b;
  border-radius: 12px;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  border-left: 4px solid #667eea;
}

.trip-card.completed {
  border-left-color: #10b981;
  opacity: 0.8;
}

.trip-card.in-progress {
  border-left-color: #f59e0b;
}

.trip-time {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 1.1rem;
  font-weight: 600;
}

.time-separator {
  color: #64748b;
}

.trip-details {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.route-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.route-color {
  width: 12px;
  height: 12px;
  border-radius: 3px;
}

.route-name {
  font-size: 0.95rem;
  color: #e2e8f0;
}

.trip-status {
  font-size: 0.8rem;
  padding: 4px 8px;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.1);
  color: #94a3b8;
}

.completed .trip-status {
  background: rgba(16, 185, 129, 0.1);
  color: #34d399;
}

.in-progress .trip-status {
  background: rgba(245, 158, 11, 0.1);
  color: #fbbf24;
}

/* Estados Vacíos / Carga */
.loading-state, .empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 0;
  color: #94a3b8;
  text-align: center;
}

.empty-icon {
  font-size: 3rem;
  margin-bottom: 16px;
  opacity: 0.8;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid rgba(255, 255, 255, 0.1);
  border-top-color: #667eea;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 16px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>

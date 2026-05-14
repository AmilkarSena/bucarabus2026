<template>
  <div class="driver-app" :class="{ 'shift-active': shiftActive }">
    <div class="main-screen">
      <!-- Header -->
      <DriverHeader
        :driver-name="driver.name"
        :bus-plate="driver.busPlate"
        :is-authenticated="authStore.isAuthenticated"
        :user-avatar="authStore.userAvatar"
        :user-name="authStore.userName"
        :role-name="authStore.getRoleName ? authStore.getRoleName(authStore.userRole) : 'Conductor'"
        @logout="handleLogout"
        @open-menu="isMenuOpen = true"
      />

      <!-- Side Menu -->
      <SideMenu
        v-model:isOpen="isMenuOpen"
        :current-view="currentView"
        @navigate="view => currentView = view"
      />

      <!-- VISTA HOME: Mi Turno -->
      <div v-show="currentView === 'home'" class="view-container">
        <!-- Connection Status -->
      <ConnectionStatus :is-connected="isConnected" />

      <!-- Route Info -->
      <TripTimeline
        :current-trip="currentTrip"
        :assigned-trips="assignedTrips"
        :is-expanded="isRoutesExpanded"
        @toggle-expansion="toggleRoutesExpansion"
        @select-trip="selectTrip"
      />

      <!-- Map Container -->
      <div class="map-container">
        <div id="driver-map" class="driver-map"></div>
        
        <!-- GPS Accuracy Indicator -->
        <div v-if="shiftActive && currentLocation" class="gps-accuracy">
          <span class="accuracy-icon">📡</span>
          <span>Precisión: {{ Math.round(currentLocation.accuracy || 0) }}m</span>
        </div>

        <!-- Draggable FAB para Incidentes -->
        <DraggableSpeedDial 
          v-if="shiftActive"
          @report="handleIncidentReport"
        />
      </div>

      <ShiftControls
          :shift-active="shiftActive"
          :shift-duration="shiftDuration"
          :trips-completed="tripsCompleted"
          :current-speed="currentSpeed"
          :route-progress="routeProgress"
          :is-connected="isConnected"
          :trip-color="currentTrip?.color"
          @start-shift="startShift"
          @end-shift="endShift"
        />
      </div>

      <!-- VISTA CALENDAR: Calendario de Viajes -->
      <div v-if="currentView === 'calendar'" class="view-container calendar-view-container">
        <WeeklyCalendar 
          :trips="calendarTrips" 
          :loading="calendarLoading"
          :weekly-counts="weeklyTripsCount"
          @date-changed="loadCalendarTrips"
          @week-changed="loadCalendarWeek"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@shared/api/auth'

// Components
import DriverHeader from '../components/DriverHeader.vue'
import ConnectionStatus from '../components/ConnectionStatus.vue'
import TripTimeline from '../components/TripTimeline.vue'
import ShiftControls from '../components/ShiftControls.vue'
import SideMenu from '../components/SideMenu.vue'
import WeeklyCalendar from '../components/WeeklyCalendar.vue'
import DraggableSpeedDial from '../components/DraggableSpeedDial.vue'

// Composables
import { useDriverTrips } from '../composables/useDriverTrips'
import { useDriverSocket } from '../composables/useDriverSocket'
import { useDriverGPS } from '../composables/useDriverGPS'
import { useDriverMap } from '../composables/useDriverMap'

const router = useRouter()
console.log('📦 Inicializando DriverAppView...')
const authStore = useAuthStore()
console.log('👤 Auth Store cargada:', authStore.isAuthenticated)

// Navigation State
const isMenuOpen = ref(false)
const currentView = ref('home')

// Shift State
const shiftActive = ref(false)
const shiftStartTime = ref(null)
const shiftDuration = ref(0)
const tripsCompleted = ref(0)
const routeProgress = ref(0) // TODO: calculate based on distance to waypoints
let shiftTimer = null
let autoUpdateTimer = null

// Initialize Composables
const {
  driver,
  assignedTrips,
  currentTrip,
  isRoutesExpanded,
  calendarTrips,
  calendarLoading,
  weeklyTripsCount,
  loadDriverData,
  loadCalendarTrips,
  loadCalendarWeek,
  updateCurrentTrip,
  selectTrip,
  toggleRoutesExpansion,
  updateTripStatus
} = useDriverTrips()

const {
  isConnected,
  connectWebSocket,
  disconnectWebSocket,
  sendLocation,
  emitShiftStart,
  emitShiftEnd,
  emitIncident
} = useDriverSocket()

const {
  currentLocation,
  currentSpeed,
  startTracking,
  stopTracking
} = useDriverGPS()

const {
  initMap,
  drawRoute,
  updateDriverMarker,
  destroyMap
} = useDriverMap()

// Handlers
const handleLogout = async () => {
  if (shiftActive.value) {
    if (!confirm('¿Terminar turno y cerrar sesión?')) return
    await endShift()
  }
  
  disconnectWebSocket()
  authStore.logout()
  router.push('/login')
}

const onGPSPositionUpdate = (location) => {
  // 1. Actualizar mapa
  updateDriverMarker(location.lat, location.lng, driver.value.busPlate)
  // 2. Enviar por socket si hay turno activo
  sendLocation(driver.value, location, shiftActive.value)
}

const startShift = async () => {
  if (!currentTrip.value) {
    alert('No tienes viajes asignados. Contacta al supervisor.')
    return
  }
  
  const gpsStarted = startTracking(onGPSPositionUpdate)
  if (!gpsStarted) return
  
  shiftActive.value = true
  shiftStartTime.value = Date.now()
  
  // Status = 3 (En progreso)
  await updateTripStatus(3)
  
  shiftTimer = setInterval(() => {
    shiftDuration.value = Math.floor((Date.now() - shiftStartTime.value) / 1000)
  }, 1000)
  
  emitShiftStart(driver.value, currentTrip.value)
}

const endShift = async () => {
  stopTracking()
  
  if (shiftTimer) {
    clearInterval(shiftTimer)
    shiftTimer = null
  }
  
  // Status = 4 (Completado)
  await updateTripStatus(4)
  tripsCompleted.value++
  
  emitShiftEnd(driver.value, currentTrip.value, shiftDuration.value, tripsCompleted.value)
  
  shiftActive.value = false
  shiftDuration.value = 0
  
  updateCurrentTrip()
}

const handleIncidentReport = (data) => {
  if (!currentLocation.value) {
    alert('Buscando señal GPS. Intenta de nuevo en unos segundos.')
    return
  }
  
  emitIncident(driver.value, currentLocation.value, currentTrip.value, data.incidentId, data.tag, data.name, data.description)
  
  // Pequeña retroalimentación visual nativa (si está disponible)
  if (navigator.vibrate) navigator.vibrate(50)
}

// Watchers
watch(() => currentTrip.value?.id_trip, (newTripId) => {
  if (newTripId && currentTrip.value?.path?.length > 0) {
    drawRoute(currentTrip.value.path, currentTrip.value.color)
  }
}, { flush: 'post' })

watch(currentView, async (newView) => {
  if (newView === 'home') {
    await nextTick()
    setTimeout(() => {
      if (document.getElementById('driver-map')) {
        // Forzar recalcular tamaño al volver al mapa
        window.dispatchEvent(new Event('resize'))
      }
    }, 300)
  }
})

// Lifecycle
onMounted(async () => {
  if (!authStore.isAuthenticated) {
    router.push('/login')
    return
  }

  if (!authStore.userId && !authStore.currentUser?.email) {
    authStore.logout()
    router.push('/login')
    return
  }

  if (!authStore.userId) {
    await authStore.refreshUserData()
  }

  const dataLoaded = await loadDriverData(authStore.userId, authStore)
  
  if (dataLoaded) {
    nextTick(() => {
      initMap('driver-map', currentTrip.value)
      connectWebSocket()
    })
    autoUpdateTimer = setInterval(updateCurrentTrip, 60000)
  }

  if ('wakeLock' in navigator) {
    navigator.wakeLock.request('screen').catch(console.error)
  }
})

onUnmounted(() => {
  stopTracking()
  disconnectWebSocket()
  if (shiftTimer) clearInterval(shiftTimer)
  if (autoUpdateTimer) clearInterval(autoUpdateTimer)
  destroyMap()
})
</script>

<style scoped>
.driver-app {
  min-height: 100vh;
  min-height: 100dvh;
  background: #0f172a;
  color: white;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.main-screen {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  min-height: 100dvh;
}

.view-container {
  display: flex;
  flex-direction: column;
  flex: 1;
}

.calendar-view-container {
  height: calc(100vh - 60px); /* Ajuste basado en el alto del header */
  overflow: hidden;
}

.map-container {
  flex: 1;
  position: relative;
  min-height: 250px;
}

.driver-map {
  width: 100%;
  height: 100%;
  min-height: 250px;
}

.gps-accuracy {
  position: absolute;
  top: 12px;
  left: 12px;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  background: rgba(15, 23, 42, 0.9);
  border-radius: 20px;
  font-size: 12px;
  color: #94a3b8;
  z-index: 1000;
}

.animate-bounce-slow {
  animation: bounce 3s infinite;
}

/* Shift Active State Override */
.shift-active :deep(.app-header) {
  background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
}

.shift-active :deep(.connection-status.connected) {
  background: rgba(255, 255, 255, 0.1);
  color: white;
}
</style>

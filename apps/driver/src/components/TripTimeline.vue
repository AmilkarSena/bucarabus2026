<template>
  <div v-if="!currentTrip && assignedTrips.length === 0" class="no-trips-message">
    <div class="no-trips-icon">📋</div>
    <h3>Sin viajes asignados</h3>
    <p>No tienes viajes programados para hoy. Contacta al supervisor.</p>
  </div>

  <div v-if="currentTrip" class="route-info-card" :class="{ expanded: isExpanded }">
    <!-- Current Trip Header (Always Visible) -->
    <div class="route-header" @click="$emit('toggle-expansion')">
      <div class="route-color-bar" :style="{ background: currentTrip.color }"></div>
      <div class="route-details">
        <div class="route-main-info">
          <h3>{{ currentTrip.name }} <span class="route-id">#{{ currentTrip.id_route }}</span></h3>
          <p class="route-time">
            {{ formatTripTime(currentTrip.start_time) }} - {{ formatTripTime(currentTrip.end_time) }}
          </p>
        </div>
        <div class="route-status-badge" :class="getTripStatusClass(currentTrip)">
          {{ getTripStatusLabel(currentTrip) }}
        </div>
      </div>
      <div class="expand-icon" :class="{ rotated: isExpanded }">▼</div>
    </div>

    <!-- All Trips Timeline (Expandable) -->
    <transition name="slide-down">
      <div v-if="isExpanded" class="trips-timeline">
        <div class="timeline-header">
          <span>Viajes del día</span>
          <span class="trip-count">{{ assignedTrips.length }} viajes</span>
        </div>
        
        <div class="timeline-items">
          <div 
            v-for="trip in assignedTrips" 
            :key="trip.id_trip"
            class="timeline-item"
            :class="{ 
              'is-current': trip.id_trip === currentTrip?.id_trip,
              'is-completed': trip.status_trip === 4,
              'is-active': trip.status_trip === 3
            }"
            @click="$emit('select-trip', trip)"
          >
            <div class="timeline-dot" :style="{ background: trip.color }"></div>
            <div class="timeline-content">
              <div class="timeline-main">
                <span class="timeline-route-name">{{ trip.name }} <span class="route-id-small">#{{ trip.id_route }}</span></span>
                <span class="timeline-time">{{ formatTripTime(trip.start_time) }}</span>
              </div>
              <div class="timeline-status">
                <span class="status-indicator" :class="getTripStatusClass(trip)">
                  {{ getTripStatusLabel(trip) }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
defineProps({
  currentTrip: {
    type: Object,
    default: null
  },
  assignedTrips: {
    type: Array,
    default: () => []
  },
  isExpanded: {
    type: Boolean,
    default: false
  }
})

defineEmits(['toggle-expansion', 'select-trip'])

const formatTripTime = (timeString) => {
  if (!timeString) return ''
  return timeString.slice(0, 5)
}

const getTripStatusClass = (trip) => {
  if (!trip) return ''
  const now = new Date().toTimeString().slice(0, 8)
  
  if (trip.status_trip === 4) return 'status-completed'
  if (trip.status_trip === 3) return 'status-active'
  if (trip.start_time > now) return 'status-upcoming'
  if (trip.end_time < now) return 'status-past'
  
  return 'status-pending'
}

const getTripStatusLabel = (trip) => {
  if (!trip) return ''
  const now = new Date().toTimeString().slice(0, 8)
  
  if (trip.status_trip === 4) return 'Completado'
  if (trip.status_trip === 3) return 'En progreso'
  if (trip.start_time > now) return 'Próximo'
  if (trip.end_time < now) return 'Retrasado'
  
  return 'Pendiente'
}
</script>

<style scoped>
/* No Trips Message */
.no-trips-message {
  margin: 20px;
  padding: 40px 20px;
  text-align: center;
  background: #1e293b;
  border-radius: 12px;
  border: 2px dashed #334155;
}

.no-trips-icon {
  font-size: 64px;
  margin-bottom: 16px;
  opacity: 0.5;
}

.no-trips-message h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  color: #f1f5f9;
}

.no-trips-message p {
  margin: 0;
  font-size: 14px;
  color: #64748b;
}

/* Route Info Card */
.route-info-card {
  margin: 12px;
  background: #1e293b;
  border-radius: 12px;
  overflow: hidden;
  transition: all 0.3s ease;
}

.route-info-card.expanded {
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
}

.route-header {
  display: flex;
  align-items: center;
  cursor: pointer;
  transition: background 0.2s;
}

.route-header:hover {
  background: rgba(255, 255, 255, 0.02);
}

.route-color-bar {
  width: 6px;
  min-height: 60px;
}

.route-details {
  flex: 1;
  padding: 12px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.route-main-info {
  flex: 1;
}

.route-details h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.route-id {
  font-size: 13px;
  font-weight: 500;
  color: #94a3b8;
  opacity: 0.8;
}

.route-id-small {
  font-size: 11px;
  font-weight: 500;
  color: #64748b;
  opacity: 0.7;
}

.route-time {
  margin: 4px 0 0;
  font-size: 13px;
  color: #94a3b8;
  font-weight: 500;
}

.route-status-badge {
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.status-active {
  background: rgba(34, 197, 94, 0.15);
  color: #22c55e;
}

.status-upcoming {
  background: rgba(59, 130, 246, 0.15);
  color: #3b82f6;
}

.status-pending {
  background: rgba(251, 191, 36, 0.15);
  color: #fbbf24;
}

.status-completed {
  background: rgba(100, 116, 139, 0.15);
  color: #64748b;
}

.status-past {
  background: rgba(239, 68, 68, 0.15);
  color: #ef4444;
}

.expand-icon {
  padding: 0 16px;
  font-size: 12px;
  color: #64748b;
  transition: transform 0.3s;
}

.expand-icon.rotated {
  transform: rotate(180deg);
}

/* Trips Timeline */
.trips-timeline {
  border-top: 1px solid #334155;
  padding: 16px;
  background: rgba(15, 23, 42, 0.5);
}

.timeline-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  font-size: 13px;
  color: #94a3b8;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.trip-count {
  font-size: 11px;
  padding: 4px 10px;
  background: rgba(102, 126, 234, 0.15);
  color: #667eea;
  border-radius: 12px;
}

.timeline-items {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.timeline-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: #1e293b;
  border: 2px solid transparent;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s;
}

.timeline-item:hover:not(.is-completed) {
  background: #334155;
  border-color: rgba(102, 126, 234, 0.3);
}

.timeline-item.is-current {
  border-color: #667eea;
  background: rgba(102, 126, 234, 0.1);
}

.timeline-item.is-active {
  border-color: #22c55e;
  background: rgba(34, 197, 94, 0.1);
}

.timeline-item.is-completed {
  opacity: 0.5;
  cursor: default;
}

.timeline-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  flex-shrink: 0;
}

.timeline-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.timeline-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.timeline-route-name {
  font-weight: 600;
  font-size: 14px;
}

.timeline-time {
  font-size: 13px;
  color: #94a3b8;
  font-weight: 500;
}

.timeline-status {
  display: flex;
  align-items: center;
}

.status-indicator {
  font-size: 10px;
  padding: 2px 8px;
  border-radius: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* Slide Down Animation */
.slide-down-enter-active,
.slide-down-leave-active {
  transition: all 0.3s ease;
  max-height: 500px;
}

.slide-down-enter-from,
.slide-down-leave-to {
  max-height: 0;
  opacity: 0;
  padding-top: 0;
  padding-bottom: 0;
}
</style>

<template>
  <aside class="available-buses-panel">
    <h4 class="panel-title">🚌 Buses Disponibles</h4>
    <div class="buses-list">
      <div
        v-for="bus in buses"
        :key="bus.plate_number"
        class="bus-card"
        :draggable="!isPastDate"
        @dragstart="!isPastDate && emit('dragstart', $event, bus)"
      >
        <div class="bus-info">
          <p class="bus-id">{{ bus.amb_code }}</p>
          <p class="bus-plate">Placa: {{ bus.plate_number }}</p>
          <p class="bus-driver">Conductor: {{ getDriverName(bus.assigned_driver) }}</p>
          <span class="bus-status" :class="getBusTripCount(bus.plate_number) > 0 ? 'multi-assigned' : 'active'">
            {{ getBusTripCount(bus.plate_number) > 0 ? `${getBusTripCount(bus.plate_number)} viaje${getBusTripCount(bus.plate_number) > 1 ? 's' : ''}` : 'Disponible' }}
          </span>
        </div>
      </div>
      <div v-if="buses.length === 0" class="no-buses">
        No hay buses disponibles
      </div>
    </div>
  </aside>
</template>

<script setup>
const props = defineProps({
  buses: {
    type: Array,
    required: true
  },
  isPastDate: {
    type: Boolean,
    default: false
  },
  getDriverName: {
    type: Function,
    required: true
  },
  getBusTripCount: {
    type: Function,
    required: true
  }
})

const emit = defineEmits(['dragstart'])
</script>

<style scoped>
/* Panel Lateral: Buses Disponibles */
.available-buses-panel {
  width: 280px;
  background: #f8fafc;
  padding: 20px;
  border-right: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
}

.panel-title {
  font-size: 16px;
  font-weight: 700;
  color: #1e293b;
  margin: 0 0 16px 0;
}

.buses-list {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-right: 8px;
}

.bus-card {
  background: white;
  padding: 14px;
  border-radius: 10px;
  cursor: grab;
  border: 2px solid transparent;
  transition: all 0.2s ease;
  user-select: none;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.bus-card:hover {
  border-color: #667eea;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.bus-card.dragging {
  opacity: 0.5;
  transform: rotate(3deg) scale(1.05);
  background: #dbeafe;
}

.bus-info p {
  margin: 0 0 4px 0;
  font-size: 13px;
  color: #374151;
}

.bus-id {
  font-weight: 700;
  color: #1e293b;
  font-size: 14px;
}

.bus-plate {
  font-size: 12px;
  color: #64748b;
}

.bus-driver {
  font-size: 12px;
  color: #6b7280;
}

.bus-status {
  display: inline-block;
  font-size: 11px;
  font-weight: 600;
  padding: 3px 8px;
  border-radius: 10px;
  text-transform: uppercase;
  margin-top: 6px;
}

.bus-status.active {
  background: rgba(16, 185, 129, 0.1);
  color: #10b981;
}

.bus-status.inactive {
  background: rgba(239, 68, 68, 0.1);
  color: #ef4444;
}

.bus-status.multi-assigned {
  background: rgba(102, 126, 234, 0.12);
  color: #667eea;
}

.no-buses {
  text-align: center;
  color: #9ca3af;
  font-style: italic;
  padding: 30px 10px;
  font-size: 13px;
}

/* Scrollbar */
.buses-list::-webkit-scrollbar {
  width: 8px;
}

.buses-list::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 4px;
}

.buses-list::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 4px;
}

.buses-list::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

/* Responsive */
@media (max-width: 900px) {
  .available-buses-panel {
    width: 100%;
    max-height: 200px;
    border-right: none;
    border-bottom: 1px solid #e2e8f0;
  }
}
</style>

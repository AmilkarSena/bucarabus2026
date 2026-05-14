<template>
  <div class="shift-modal-content">
    <div class="form-group">
      <label for="shift-route">Ruta</label>
      <select id="shift-route" v-model="form.routeId" class="form-control">
        <option value="">-- Seleccionar Ruta --</option>
        <option v-for="route in routes" :key="route.id" :value="route.id">
          {{ route.name }}
        </option>
      </select>
    </div>

    <div class="form-group">
      <label for="shift-bus">Bus</label>
      <select id="shift-bus" v-model="form.busId" class="form-control">
        <option value="">-- Seleccionar Bus --</option>
        <option v-for="bus in buses" :key="bus.plate_number" :value="bus.plate_number">
          {{ bus.amb_code }} - {{ bus.plate_number }}
        </option>
      </select>
    </div>

    <div class="form-row">
      <div class="form-group half">
        <label for="shift-date">Fecha</label>
        <input type="date" id="shift-date" v-model="form.date" class="form-control" />
      </div>
      <div class="form-group half">
        <label for="shift-start">Hora Inicio</label>
        <input type="time" id="shift-start" v-model="form.startTime" class="form-control" />
      </div>
    </div>

    <div class="form-row">
      <div class="form-group half">
        <label for="shift-end">Hora Fin</label>
        <input type="time" id="shift-end" v-model="form.endTime" class="form-control" />
      </div>
      <div class="form-group half">
        <label for="shift-status">Estado</label>
        <select id="shift-status" v-model="form.status" class="form-control">
          <option value="pending">Pendiente</option>
          <option value="assigned">Asignado</option>
          <option value="completed">Completado</option>
          <option value="cancelled">Cancelado</option>
        </select>
      </div>
    </div>

    <div class="form-group">
      <label for="shift-notes">Notas</label>
      <textarea id="shift-notes" v-model="form.notes" class="form-control" rows="3" placeholder="Notas adicionales..."></textarea>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRoutesStore } from '../../stores/routes'
import { useBusesStore } from '../../stores/buses'
import { useAppStore } from '../../stores/app'

const routesStore = useRoutesStore()
const busesStore = useBusesStore()
const appStore = useAppStore()

const form = ref({
  id: null,
  routeId: '',
  busId: '',
  date: '',
  startTime: '',
  endTime: '',
  status: 1,  // 1 = pending
  notes: ''
})

const routes = computed(() => routesStore.routesList)
const buses = computed(() => busesStore.buses)

// Cargar datos del turno si estamos editando
watch(() => appStore.modalData, (data) => {
  if (data && data.shift) {
    form.value = { ...data.shift }
  } else {
    // Valores por defecto para nuevo turno
    const today = new Date().toISOString().split('T')[0]
    form.value = {
      id: null,
      routeId: '',
      busId: '',
      date: today,
      startTime: '06:00',
      endTime: '07:00',
      status: 1,  // 1 = pending
      notes: ''
    }
  }
}, { immediate: true })

// Método para obtener datos del formulario (llamado desde AppModals)
const getFormData = () => {
  return { ...form.value }
}

// Exponer método para el padre
defineExpose({
  getFormData
})

onMounted(async () => {
  await routesStore.fetchRoutes()
  await busesStore.fetchBuses()
})
</script>

<style scoped>
.shift-modal-content {
  padding: 8px 0;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  margin-bottom: 6px;
  font-weight: 600;
  color: #374151;
  font-size: 14px;
}

.form-control {
  width: 100%;
  padding: 10px 12px;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  font-size: 14px;
  transition: all 0.2s ease;
}

.form-control:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-row {
  display: flex;
  gap: 16px;
}

.form-group.half {
  flex: 1;
}

textarea.form-control {
  resize: vertical;
  min-height: 80px;
}

select.form-control {
  cursor: pointer;
  background-color: white;
}
</style>

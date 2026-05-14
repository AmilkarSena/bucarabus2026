<template>
  <div v-show="modelValue" class="mini-modal-overlay" @click.self="close">
    <div class="mini-modal generate-modal">
      <div class="mini-modal-header">
        <h4>✨ Generar horario</h4>
        <button class="close-btn" @click="close">✕</button>
      </div>
      <div class="mini-modal-body">
        <div class="mini-modal-row">
          <div class="mini-modal-field">
            <label>Hora de inicio</label>
            <input
              v-model="startTime"
              type="time"
              class="mini-modal-input"
              :class="{ 'input-error': error && error.field === 'start' }"
              @change="validateStart"
            />
            <span v-if="error && error.field === 'start'" class="field-error">{{ error.msg }}</span>
          </div>
          <div class="mini-modal-field">
            <label>Hora de fin</label>
            <input
              v-model="endTime"
              type="time"
              class="mini-modal-input"
              :class="{ 'input-error': error && error.field === 'end' }"
              @change="validateEnd"
            />
            <span v-if="error && error.field === 'end'" class="field-error">{{ error.msg }}</span>
          </div>
        </div>
        <div class="mini-modal-row">
          <div class="mini-modal-field">
            <label>Frecuencia (min)</label>
            <input
              v-model.number="frequency"
              type="number"
              min="1"
              class="mini-modal-input"
              :class="{ 'input-error': error && error.field === 'frequency' }"
              @change="validateFrequency"
            />
            <span v-if="error && error.field === 'frequency'" class="field-error">{{ error.msg }}</span>
          </div>
          <div class="mini-modal-field">
            <label>Duración (min)</label>
            <input
              v-model.number="duration"
              type="number"
              min="1"
              class="mini-modal-input"
              :class="{ 'input-error': error && error.field === 'duration' }"
              @change="validateDuration"
            />
            <span v-if="error && error.field === 'duration'" class="field-error">{{ error.msg }}</span>
          </div>
        </div>
      </div>
      <div class="mini-modal-footer">
        <button class="btn btn-secondary" @click="close">Cancelar</button>
        <button class="btn btn-primary" @click="confirm">Generar</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  isToday: { type: Boolean, default: false },
  lastTripStartTime: { type: String, default: null } // Para validar que inicie después del último viaje
})

const emit = defineEmits(['update:modelValue', 'generate'])

const startTime = ref('06:00')
const endTime = ref('08:00')
const frequency = ref(15)
const duration = ref(60)
const error = ref(null)

// Función utilitaria temporal (se moverá en Fase 2)
const timeToMinutes = (timeStr) => {
  if (!timeStr) return 0
  const [hours, minutes] = timeStr.split(':').map(Number)
  return hours * 60 + minutes
}

watch(() => props.modelValue, (newVal) => {
  if (newVal) {
    startTime.value = '06:00'
    endTime.value = '08:00'
    frequency.value = 15
    duration.value = 60
    error.value = null
  }
})

const validateStart = () => {
  if (!startTime.value) return
  
  if (props.isToday) {
    const now = new Date()
    const currentMinutes = now.getHours() * 60 + now.getMinutes()
    if (timeToMinutes(startTime.value) <= currentMinutes) {
      const currentTimeStr = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false })
      error.value = { field: 'start', msg: `Debe ser mayor a la hora actual (${currentTimeStr})` }
      return
    }
  }
  
  if (props.lastTripStartTime && timeToMinutes(startTime.value) <= timeToMinutes(props.lastTripStartTime)) {
    error.value = { field: 'start', msg: `Debe ser posterior al último viaje (${props.lastTripStartTime})` }
    return
  }
  
  if (error.value && error.value.field === 'start') error.value = null
}

const validateEnd = () => {
  if (!endTime.value) return
  if (startTime.value && timeToMinutes(endTime.value) <= timeToMinutes(startTime.value)) {
    error.value = { field: 'end', msg: `Debe ser posterior a la hora de inicio (${startTime.value})` }
    return
  }
  if (error.value && error.value.field === 'end') error.value = null
}

const validateFrequency = () => {
  if (!frequency.value || frequency.value <= 0) {
    error.value = { field: 'frequency', msg: 'Debe ser un número positivo' }
    return
  }
  if (error.value && error.value.field === 'frequency') error.value = null
}

const validateDuration = () => {
  if (!duration.value || duration.value <= 0) {
    error.value = { field: 'duration', msg: 'Debe ser un número positivo' }
    return
  }
  if (error.value && error.value.field === 'duration') error.value = null
}

const close = () => {
  emit('update:modelValue', false)
}

const confirm = () => {
  error.value = null
  
  if (!startTime.value) {
    error.value = { field: 'start', msg: 'La hora de inicio es obligatoria' }
    return
  }
  validateStart()
  if (error.value) return
  
  if (!endTime.value) {
    error.value = { field: 'end', msg: 'La hora de fin es obligatoria' }
    return
  }
  validateEnd()
  if (error.value) return
  
  validateFrequency()
  if (error.value) return
  
  validateDuration()
  if (error.value) return
  
  emit('generate', { 
    startTime: startTime.value, 
    endTime: endTime.value, 
    frequency: frequency.value, 
    duration: duration.value 
  })
  close()
}
</script>

<style scoped>
/* Estilos base reutilizados, idealmente se moverían a un CSS global o mixin */
.mini-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1010;
  /* backdrop-filter eliminado para mejorar rendimiento */
}

.mini-modal {
  background: white;
  width: 90%;
  max-width: 400px;
  border-radius: 12px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
  display: flex;
  flex-direction: column;
  animation: modalSlideIn 0.3s ease-out;
}

.generate-modal {
  max-width: 500px;
}

.mini-modal-header {
  padding: 16px 20px;
  border-bottom: 1px solid #e2e8f0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.mini-modal-header h4 {
  margin: 0;
  font-size: 1.1rem;
  color: #1e293b;
  font-weight: 700;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.25rem;
  color: #94a3b8;
  cursor: pointer;
  padding: 4px;
}

.close-btn:hover {
  color: #ef4444;
}

.mini-modal-body {
  padding: 20px;
}

.mini-modal-row {
  display: flex;
  gap: 16px;
  margin-bottom: 16px;
}

.mini-modal-field {
  flex: 1;
}

.mini-modal-field label {
  display: block;
  font-size: 0.85rem;
  font-weight: 600;
  color: #475569;
  margin-bottom: 6px;
}

.mini-modal-input {
  width: 100%;
  padding: 10px;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  font-size: 0.95rem;
  color: #1e293b;
  transition: all 0.2s;
  box-sizing: border-box;
}

.mini-modal-input:focus {
  outline: none;
  border-color: #6366f1;
  box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
}

.mini-modal-input.input-error {
  border-color: #ef4444;
}

.field-error {
  display: block;
  font-size: 0.75rem;
  color: #ef4444;
  margin-top: 4px;
}

.mini-modal-footer {
  padding: 16px 20px;
  border-top: 1px solid #e2e8f0;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.btn {
  padding: 8px 16px;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition: all 0.2s;
}

.btn-secondary {
  background: #f1f5f9;
  color: #475569;
}

.btn-secondary:hover {
  background: #e2e8f0;
}

.btn-primary {
  background: #6366f1;
  color: white;
}

.btn-primary:hover {
  background: #4f46e5;
}

@keyframes modalSlideIn {
  from { opacity: 0; transform: translateY(-20px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>

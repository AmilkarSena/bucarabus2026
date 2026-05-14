<template>
  <div v-show="modelValue" class="mini-modal-overlay" @click.self="close">
    <div class="mini-modal">
      <div class="mini-modal-header">
        <h4>Agregar viaje</h4>
        <button class="close-btn" @click="close">✕</button>
      </div>
      <div class="mini-modal-body">
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
      <div class="mini-modal-footer">
        <button class="btn btn-secondary" @click="close">Cancelar</button>
        <button class="btn btn-primary" @click="confirm">Agregar</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  isToday: { type: Boolean, default: false },
  existingStartTimes: { type: Array, default: () => [] }
})

const emit = defineEmits(['update:modelValue', 'confirm'])

const startTime = ref('')
const endTime = ref('')
const error = ref(null)

// Función utilitaria temporal (se moverá en Fase 2)
const timeToMinutes = (timeStr) => {
  if (!timeStr) return 0
  const [hours, minutes] = timeStr.split(':').map(Number)
  return hours * 60 + minutes
}

watch(() => props.modelValue, (newVal) => {
  if (newVal) {
    startTime.value = ''
    endTime.value = ''
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
  
  const duplicate = props.existingStartTimes.includes(startTime.value)
  if (duplicate) {
    error.value = { field: 'start', msg: `Ya existe un viaje con esta hora de inicio` }
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
  
  emit('confirm', { startTime: startTime.value, endTime: endTime.value })
  close()
}
</script>

<style scoped>
/* Estilos extraídos de ShiftsModal.vue para el mini-modal */
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

.mini-modal-field {
  margin-bottom: 16px;
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

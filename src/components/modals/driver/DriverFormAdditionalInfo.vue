<template>
  <div class="form-section">
    <h3 class="section-title">📅 Información Adicional</h3>
    
    <div class="form-row">
      <div class="form-group">
        <label for="date_entry">Fecha de Ingreso</label>
        <input
          type="date"
          id="date_entry"
          v-model="formData.date_entry"
          :max="today"
        />
      </div>

      <div class="form-group" v-if="isEditMode">
        <label>Última Actualización</label>
        <input
          type="text"
          :value="formatDateTime(formData.updated_at)"
          disabled
          class="readonly-field"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { inject } from 'vue'

const {
  formData,
  today,
  isEditMode
} = inject('driverFormContext')

const formatDateTime = (dateTime) => {
  if (!dateTime) return 'N/A'
  const date = new Date(dateTime)
  return date.toLocaleString('es-CO', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}
</script>

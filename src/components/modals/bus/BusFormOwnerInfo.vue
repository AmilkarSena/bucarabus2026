<template>
  <div class="form-section">
    <h3 class="section-title">👤 Propietario</h3>

    <div class="form-row">
      <div class="form-group">
        <label for="id_owner" class="required">Propietario</label>
        <select
          id="id_owner"
          v-model.number="formData.id_owner"
          required
          :class="{ 'error': errors.id_owner }"
          @blur="validateIdOwnerField"
          @change="validateIdOwnerField"
        >
          <option value="">Seleccione un propietario</option>
          <option v-for="o in busOwners" :key="o.id_owner" :value="o.id_owner">
            {{ o.full_name }}
          </option>
        </select>
        <span v-if="errors.id_owner" class="error-message">{{ errors.id_owner }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { inject } from 'vue'

const {
  formData,
  errors,
  busOwners,
  validateIdOwnerField
} = inject('busFormContext')
</script>

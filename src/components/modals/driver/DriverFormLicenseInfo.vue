<template>
  <div class="form-section">
    <h3 class="section-title">🪪 Licencia de Conducción</h3>

    <div class="form-row">
      <div class="form-group">
        <label for="license_cat" class="required">Categoría</label>
        <select
          id="license_cat"
          v-model="formData.license_cat"
          required
          :class="{ 'error': errors.license_cat }"
        >
          <option value="">Seleccione una categoría</option>
          <option value="C1">C1 - Vehículos particulares</option>
          <option value="C2">C2 - Vehículos de servicio público</option>
          <option value="C3">C3 - Vehículos de carga</option>
        </select>
        <span v-if="errors.license_cat" class="error-message">{{ errors.license_cat }}</span>
      </div>

      <div class="form-group">
        <label for="license_exp" class="required">Fecha de Vencimiento</label>
        <input
          type="date"
          id="license_exp"
          v-model="formData.license_exp"
          :min="minLicenseDate"
          :max="calculateMaxLicenseExpDate(formData.birth_date)"
          required
          @blur="validateLicenseExpField"
          :class="{ 'error': errors.license_exp }"
        />
        <span v-if="errors.license_exp" class="error-message">{{ errors.license_exp }}</span>
        <span v-if="!errors.license_exp && formData.license_exp && formData.birth_date" class="field-help">
          ✅ Vence: {{ new Date(formData.license_exp).toLocaleDateString('es-CO') }}
          <br/>
          <span style="font-size: 11px; color: #667eea;">máximo permitido: {{ new Date(calculateMaxLicenseExpDate(formData.birth_date)).toLocaleDateString('es-CO') }}</span>
        </span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { inject } from 'vue'

const {
  formData,
  errors,
  minLicenseDate,
  calculateMaxLicenseExpDate,
  validateLicenseExpField
} = inject('driverFormContext')
</script>

<template>
  <div class="form-section">
    <h3 class="section-title">📋 Información Básica</h3>

    <div class="form-row">
      <div class="form-group">
        <label for="plate_number" class="required">Placa</label>
        <input
          type="text"
          id="plate_number"
          v-model="formData.plate_number"
          placeholder="ABC123"
          maxlength="6"
          required
          :disabled="isEditMode"
          :class="{ 'error': errors.plate_number }"
          @input="formatPlateNumber"
          @blur="validatePlateField"
        />
        <span v-if="errors.plate_number" class="error-message">{{ errors.plate_number }}</span>
      </div>

      <div class="form-group">
        <label for="amb_code" class="required">Código AMB</label>
        <input
          type="text"
          id="amb_code"
          v-model="formData.amb_code"
          placeholder="AMB-0001"
          maxlength="8"
          required
          :class="{ 'error': errors.amb_code }"
          @blur="validateAmbCodeField"
        />
        <span v-if="errors.amb_code" class="error-message">{{ errors.amb_code }}</span>
      </div>
    </div>

    <div class="form-row">
      <div class="form-group">
        <label for="code_internal" class="required">Código Interno</label>
        <input
          type="text"
          id="code_internal"
          v-model="formData.code_internal"
          placeholder="BUS-001"
          maxlength="20"
          required
          :class="{ 'error': errors.code_internal }"
          @blur="validateCodeInternalField"
        />
        <span v-if="errors.code_internal" class="error-message">{{ errors.code_internal }}</span>
      </div>

      <div class="form-group">
        <label for="id_company" class="required">Compañía</label>
        <select
          id="id_company"
          v-model.number="formData.id_company"
          required
          :class="{ 'error': errors.id_company }"
          @blur="validateIdCompanyField"
          @change="validateIdCompanyField"
        >
          <option value="">Seleccione una compañía</option>
          <option v-for="c in companies" :key="c.id_company" :value="c.id_company">
            {{ c.company_name }}
          </option>
        </select>
        <span v-if="errors.id_company" class="error-message">{{ errors.id_company }}</span>
      </div>
    </div>

    <div class="form-row">
      <div class="form-group">
        <label for="model_year" class="required">Año del Modelo</label>
        <input
          type="number"
          id="model_year"
          v-model.number="formData.model_year"
          :min="1990"
          :max="currentYear + 1"
          placeholder="2020"
          required
          :class="{ 'error': errors.model_year }"
          @blur="validateModelYearField"
        />
        <span v-if="errors.model_year" class="error-message">{{ errors.model_year }}</span>
      </div>

      <div class="form-group">
        <label for="capacity_bus" class="required">Capacidad</label>
        <input
          type="number"
          id="capacity_bus"
          v-model.number="formData.capacity_bus"
          min="10"
          max="200"
          placeholder="40"
          required
          :class="{ 'error': errors.capacity_bus }"
          @blur="validateCapacityField"
        />
        <span v-if="errors.capacity_bus" class="error-message">{{ errors.capacity_bus }}</span>
      </div>
    </div>

    <div class="form-row">
      <div class="form-group">
        <label for="color_bus" class="required">Color</label>
        <input
          type="text"
          id="color_bus"
          v-model="formData.color_bus"
          placeholder="Ej: Amarillo"
          maxlength="30"
          required
          :class="{ 'error': errors.color_bus }"
          @blur="validateColorBusField"
        />
        <span v-if="errors.color_bus" class="error-message">{{ errors.color_bus }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { inject } from 'vue'

const {
  formData,
  errors,
  isEditMode,
  companies,
  currentYear,
  validatePlateField,
  validateAmbCodeField,
  validateCodeInternalField,
  validateIdCompanyField,
  validateModelYearField,
  validateCapacityField,
  validateColorBusField
} = inject('busFormContext')

const formatPlateNumber = (event) => {
  const value = event.target.value.replace(/[^A-Z0-9]/gi, '').toUpperCase()
  formData.value.plate_number = value.slice(0, 6)
}
</script>

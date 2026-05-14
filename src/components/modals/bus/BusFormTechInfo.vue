<template>
  <div class="form-section">
    <h3 class="section-title">🔧 Datos Técnicos <span class="optional-tag">(opcionales)</span></h3>

    <div class="form-row">
      <div class="form-group">
        <label for="id_brand">Marca</label>
        <select
          id="id_brand"
          v-model="formData.id_brand"
        >
          <option :value="null">-- Sin especificar --</option>
          <option
            v-for="brand in brands"
            :key="brand.id_brand"
            :value="brand.id_brand"
          >{{ brand.brand_name }}</option>
        </select>
      </div>

      <div class="form-group">
        <label for="model_name">Modelo</label>
        <input
          type="text"
          id="model_name"
          v-model="formData.model_name"
          placeholder="Ej: Citaro"
          maxlength="50"
          :class="{ 'error': errors.model_name }"
          @blur="validateModelNameField"
        />
        <span v-if="errors.model_name" class="error-message">{{ errors.model_name }}</span>
      </div>
    </div>

    <div class="form-row">
      <div class="form-group">
        <label for="chassis_number">Número de Chasis</label>
        <input
          type="text"
          id="chassis_number"
          v-model="formData.chassis_number"
          placeholder="Ej: 9BM384075LB000000"
          maxlength="30"
          :class="{ 'error': errors.chassis_number }"
        />
        <span v-if="errors.chassis_number" class="error-message">{{ errors.chassis_number }}</span>
      </div>

      <div class="form-group">
        <label for="gps_device_id">ID Dispositivo GPS</label>
        <input
          type="text"
          id="gps_device_id"
          v-model="formData.gps_device_id"
          placeholder="Ej: GPS-BUS-001"
          maxlength="50"
        />
      </div>
    </div>

    <div class="form-row">
      <div class="form-group">
        <label for="color_app">Color en App</label>
        <div class="color-app-field">
          <input
            type="color"
            id="color_app"
            v-model="formData.color_app"
            class="color-picker"
          />
          <input
            type="text"
            v-model="formData.color_app"
            placeholder="#CCCCCC"
            maxlength="7"
            class="color-text"
            :class="{ 'error': errors.color_app }"
            @blur="validateColorAppField"
          />
        </div>
        <span v-if="errors.color_app" class="error-message">{{ errors.color_app }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { inject } from 'vue'

const {
  formData,
  errors,
  brands,
  validateModelNameField,
  validateColorAppField
} = inject('busFormContext')
</script>

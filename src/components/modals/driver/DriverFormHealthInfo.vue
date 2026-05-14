<template>
  <div class="form-section">
    <h3 class="section-title">🏥 Salud y Emergencia</h3>

    <!-- Fila 1: Tipo de Sangre + EPS + ARL -->
    <div class="form-row-3">
      <div class="form-group">
        <label for="blood_type">Tipo de Sangre</label>
        <select
          id="blood_type"
          v-model="formData.blood_type"
        >
          <option value="SA">-- Sin especificar --</option>
          <option value="O+">O+</option>
          <option value="O-">O-</option>
          <option value="A+">A+</option>
          <option value="A-">A-</option>
          <option value="B+">B+</option>
          <option value="B-">B-</option>
          <option value="AB+">AB+</option>
          <option value="AB-">AB-</option>
        </select>
      </div>
      <div class="form-group">
        <label for="id_eps">EPS</label>
        <select
          id="id_eps"
          v-model.number="formData.id_eps"
        >
          <option value="">Seleccionar EPS</option>
          <option v-for="eps in epsList" :key="eps.id_eps" :value="eps.id_eps">
            {{ eps.name_eps }}
          </option>
        </select>
      </div>
      <div class="form-group">
        <label for="id_arl">ARL</label>
        <select
          id="id_arl"
          v-model.number="formData.id_arl"
        >
          <option value="">Seleccionar ARL</option>
          <option v-for="arl in arlList" :key="arl.id_arl" :value="arl.id_arl">
            {{ arl.name_arl }}
          </option>
        </select>
      </div>
    </div>

    <!-- Fila 2: Contacto de Emergencia + Teléfono -->
    <div class="form-row-emergency">
      <div class="form-group">
        <label for="emergency_contact">Contacto de Emergencia</label>
        <input
          type="text"
          id="emergency_contact"
          v-model="formData.emergency_contact"
          placeholder="Nombre del contacto"
          maxlength="100"
        />
      </div>
      <div class="form-group">
        <label for="emergency_phone">Tel. Emergencia</label>
        <input
          type="tel"
          id="emergency_phone"
          v-model="formData.emergency_phone"
          placeholder="Ej: 3201234567"
          maxlength="15"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { inject } from 'vue'

const {
  formData,
  epsList,
  arlList
} = inject('driverFormContext')
</script>

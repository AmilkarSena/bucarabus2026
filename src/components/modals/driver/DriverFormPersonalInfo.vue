<template>
  <div class="form-section">
    <h3 class="section-title">👤 Información Personal</h3>
    
    <!-- Fila 1: Cédula + Nombre -->
    <div class="form-row">
      <div class="form-group" style="max-width: 150px;">
        <label for="id_driver" class="required">Cédula</label>
        <input
          type="number"
          id="id_driver"
          v-model.number="formData.id_driver"
          placeholder="Ej: 1098765432"
          min="1"
          max="9999999999999"
          required
          @blur="validateCedulaField"
          :disabled="isEditMode"
          :class="{ 'error': errors.id_driver }"
        />
        <span v-if="errors.id_driver" class="error-message">{{ errors.id_driver }}</span>
      </div>
      <div class="form-group">
        <label for="name_driver" class="required">Nombre Completo</label>
        <input
          type="text"
          id="name_driver"
          v-model="formData.name_driver"
          placeholder="Ej: Juan Pérez González"
          maxlength="100"
          required
          @blur="validateNameField"
          :class="{ 'error': errors.name_driver }"
        />
        <span v-if="errors.name_driver" class="error-message">{{ errors.name_driver }}</span>
      </div>
    </div>

    <!-- Fila 2: Teléfono + Email -->
    <div class="form-row">
      <div class="form-group" style="max-width: 150px;">
        <label for="phone_driver">Teléfono</label>
        <input
          type="tel"
          id="phone_driver"
          v-model="formData.phone_driver"
          placeholder="Ej: 3201234567"
          maxlength="15"
          @blur="validatePhoneField"
          :class="{ 'error': errors.phone_driver }"
        />
        <span v-if="errors.phone_driver" class="error-message">{{ errors.phone_driver }}</span>
      </div>
      <div class="form-group">
        <label for="email_driver">Email</label>
        <input
          type="email"
          id="email_driver"
          v-model="formData.email_driver"
          placeholder="ejemplo@email.com"
          maxlength="320"
          @blur="validateEmailField"
          :class="{ 'error': errors.email_driver }"
        />
        <span v-if="errors.email_driver" class="error-message">{{ errors.email_driver }}</span>
      </div>
    </div>

    <!-- Fila 3: Fecha de Nacimiento + Género -->
    <div class="form-row">
      <div class="form-group">
        <label for="birth_date">Fecha de Nacimiento</label>
        <input
          type="date"
          id="birth_date"
          v-model="formData.birth_date"
          :max="today"
          @blur="validateBirthdateField"
          :class="{ 'error': errors.birth_date }"
        />
        <span v-if="errors.birth_date" class="error-message">{{ errors.birth_date }}</span>
        <span v-if="!errors.birth_date && formData.birth_date" class="field-help">
          Edad: {{ calculateAge(formData.birth_date) }} años - {{ getLicenseValidityMessage(formData.birth_date) }}
        </span>
      </div>
      <div class="form-group" style="max-width: 150px;">
        <label for="gender">Género</label>
        <select
          id="gender"
          v-model="formData.gender"
          :class="{ 'error': errors.gender }"
        >
          <option value="SA">Sin asignar</option>
          <option value="M">Masculino</option>
          <option value="F">Femenino</option>
          <option value="O">Otro</option>
        </select>
        <span v-if="errors.gender" class="error-message">{{ errors.gender }}</span>
      </div>
    </div>

    <div class="form-group">
      <label for="address_driver">Dirección</label>
      <textarea
        id="address_driver"
        v-model="formData.address_driver"
        placeholder="Ej: Calle 123 #45-67, Bucaramanga"
        rows="2"
        :class="{ 'error': errors.address_driver }"
      ></textarea>
      <span v-if="errors.address_driver" class="error-message">{{ errors.address_driver }}</span>
    </div>
  </div>
</template>

<script setup>
import { inject } from 'vue'

const {
  formData,
  errors,
  isEditMode,
  today,
  calculateAge,
  getLicenseValidityMessage,
  validateCedulaField,
  validateNameField,
  validatePhoneField,
  validateEmailField,
  validateBirthdateField
} = inject('driverFormContext')
</script>

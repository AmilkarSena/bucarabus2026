<template>
  <div class="driver-modal-content">
    <form @submit.prevent="handleSubmit" class="modal-form">
        <!-- Header con Foto y Switch -->
        <DriverFormHeader />

        <!-- Información Personal -->
        <DriverFormPersonalInfo />

        <!-- Salud y Emergencia -->
        <DriverFormHealthInfo />

        <!-- Información de Licencia -->
        <DriverFormLicenseInfo />

        <!-- Información Adicional -->
        <DriverFormAdditionalInfo />

        <!-- Mensaje de Error Global -->
        <div v-if="globalError" class="global-error">
          ⚠️ {{ globalError }}
        </div>

        <!-- Botones de Acción -->
        <div class="modal-actions">
          <button type="button" class="btn secondary" @click="handleClose" :disabled="isSubmitting">
            Cancelar
          </button>
          <button type="submit" class="btn primary" :disabled="isSubmitting">
            <span v-if="isSubmitting" class="spinner"></span>
            {{ isSubmitting ? 'Guardando...' : (isEditMode ? 'Actualizar Conductor' : 'Crear Conductor') }}
          </button>
        </div>
      </form>
  </div>
</template>

<script setup>
import { ref, computed, watch, provide } from 'vue'
import { useAppStore } from '../../stores/app'         
import { useDriverForm } from '../../composables/useDriverForm'
import { useDriverPersistence } from '../../composables/useDriverPersistence'
import DriverFormPersonalInfo from './driver/DriverFormPersonalInfo.vue'
import DriverFormHealthInfo from './driver/DriverFormHealthInfo.vue'
import DriverFormLicenseInfo from './driver/DriverFormLicenseInfo.vue'
import DriverFormHeader from './driver/DriverFormHeader.vue'
import DriverFormAdditionalInfo from './driver/DriverFormAdditionalInfo.vue'

const appStore = useAppStore()

// Referencias

// Props
const props = defineProps({
  data: {
    type: Object,
    default: null
  },
  isEdit: {
    type: Boolean,
    default: false
  }
})

// Estado del modal
const isEditMode = computed(() => props.isEdit)
const isSubmitting = ref(false)

// 🆕 Estado del formulario y cálculos de fecha (Extraído a Composable)
const {
  formData,
  today,
  minLicenseDate,
  calculateAge,
  calculateMaxLicenseExpDate,
  getLicenseValidityMessage,
  loadDriverData,
  resetFormData
} = useDriverForm()

// 🆕 Persistencia y Catálogos (Extraído a Composable)
const {
  epsList,
  arlList,
  saveDriver,
  handleStatusChange: originalHandleStatusChange
} = useDriverPersistence()

// Validaciones (Extraídas a Composable)
import { useDriverValidation } from '../../composables/useDriverValidation'
const {
  errors,
  resetErrors: clearValidationErrors,
  validateNameField,
  validateCedulaField,
  validatePhoneField,
  validateEmailField,
  validateLicenseExpField,
  validateBirthdateField,
  validateForm
} = useDriverValidation(formData, { calculateAge, calculateMaxLicenseExpDate })

// Proveer contexto a los subcomponentes
provide('driverFormContext', {
  formData,
  errors,
  isEditMode,
  today,
  minLicenseDate,
  epsList,
  arlList,
  calculateAge,
  getLicenseValidityMessage,
  calculateMaxLicenseExpDate,
  validateNameField,
  validateCedulaField,
  validatePhoneField,
  validateEmailField,
  validateLicenseExpField,
  validateBirthdateField,
  handleStatusChange: () => originalHandleStatusChange(formData.value)
})

const globalError = ref('')

const resetForm = () => {
  resetFormData()
  clearValidationErrors()
  globalError.value = ''
}

// =============================================
// MÉTODOS (DECLARAR ANTES DE LOS WATCHERS)
// =============================================

const handleStatusChange = () => {
  originalHandleStatusChange(formData.value)
}

const handleSubmit = async () => {
  if (!validateForm()) {
    globalError.value = 'Por favor corrija los errores antes de continuar'
    return
  }

  isSubmitting.value = true
  globalError.value = ''

  try {
    const driverData = { ...formData.value }
    await saveDriver(driverData, isEditMode.value, props.data?.id_driver)
    
    // Éxito: limpiar y cerrar
    resetForm()
    appStore.closeModal()
  } catch (error) {
    console.error('Error al guardar conductor:', error)
    globalError.value = error.message || 'Error al guardar el conductor'
  } finally {
    isSubmitting.value = false
  }
}

const handleClose = () => {
  if (!isSubmitting.value) {
    resetForm()
    appStore.closeModal()
  }
}

const handleImageError = (event) => {
  event.target.src = 'https://via.placeholder.com/150?text=Sin+Foto'
}

const triggerFileInput = () => {
  fileInput.value?.click()
}

const handleFileUpload = async (event) => {
  const file = event.target.files?.[0]
  if (!file) return

  // Validar tipo
  if (!file.type.startsWith('image/')) {
    alert('Solo se permiten archivos de imagen')
    return
  }

  // Validar tamaño (max 5MB)
  if (file.size > 5 * 1024 * 1024) {
    alert('La imagen es muy grande. Máximo 5MB')
    return
  }

  try {
    // TODO: Implementar subida a servidor/storage (AWS S3, Cloudinary, etc.)
    // Por ahora, usamos una URL temporal local para preview
    const temporaryUrl = URL.createObjectURL(file)
    formData.value.photo_driver = temporaryUrl
    
    // Aquí deberías subir la imagen a tu servidor y obtener la URL real
    // Ejemplo con FormData para enviar al backend:
    /*
    const formDataUpload = new FormData()
    formDataUpload.append('photo', file)
    
    const response = await apiClient.post('/upload/driver-photo', formDataUpload, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    
    formData.value.photo_driver = response.data.url
    */
    
    console.warn('⚠️ Imagen cargada temporalmente. Debes implementar la subida al servidor.')
    console.log('📁 Archivo seleccionado:', file.name, 'Tamaño:', (file.size / 1024).toFixed(2), 'KB')
  } catch (error) {
    console.error('Error al procesar imagen:', error)
    alert('Error al procesar la imagen')
  }
}

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

// =============================================
// WATCHERS (DESPUÉS DE DECLARAR LOS MÉTODOS)
// =============================================

watch(() => props.data, (newDriver) => {
  if (newDriver) {
    loadDriverData(newDriver)
  } else {
    resetForm()
  }
}, { immediate: true, deep: true })

// Exponer método para que AppModals pueda invocarlo
defineExpose({
  handleSave: handleSubmit
})
</script>

<style scoped>
.driver-modal-content {
  max-width: 550px;
  width: 100%;
}

/* Ocultar flechas de incremento en inputs numéricos */
input[type="number"]::-webkit-outer-spin-button,
input[type="number"]::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}

input[type="number"] {
  -moz-appearance: textfield;
  appearance: textfield;
}

</style>
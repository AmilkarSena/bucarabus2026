<template>
  <div class="bus-modal-content">
    <form @submit.prevent="handleSubmit" class="modal-form">
      <!-- Header con Foto y Switches -->
      <BusFormHeader />

      <!-- Sub-componentes visuales inyectados con el form context -->
      <BusFormBasicInfo />
      <BusFormOwnerInfo />
      <BusFormTechInfo />

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
          {{ isSubmitting ? 'Guardando...' : (isEditMode ? 'Actualizar Bus' : 'Crear Bus') }}
        </button>
      </div>
    </form>
  </div>
</template>

<script setup>
import { ref, computed, watch, provide } from 'vue'
import BusFormBasicInfo from './bus/BusFormBasicInfo.vue'
import BusFormOwnerInfo from './bus/BusFormOwnerInfo.vue'
import BusFormTechInfo from './bus/BusFormTechInfo.vue'
import BusFormHeader from './bus/BusFormHeader.vue'
import { useAppStore } from '../../stores/app'
import { useBusForm } from '../../composables/useBusForm'
import { useBusPersistence } from '../../composables/useBusPersistence'

const appStore = useAppStore()

const currentYear = new Date().getFullYear()

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

const isEditMode = computed(() => props.isEdit && props.data)
const isSubmitting = ref(false)

// 🆕 Estado del formulario
const {
  formData,
  loadBusData,
  resetFormData
} = useBusForm()

// 🆕 Validaciones
import { useBusValidation } from '../../composables/useBusValidation'
const {
  errors,
  resetErrors: clearValidationErrors,
  validatePlateField,
  validateAmbCodeField,
  validateCodeInternalField,
  validateIdCompanyField,
  validateModelYearField,
  validateCapacityField,
  validateColorBusField,
  validateIdOwnerField,
  validateModelNameField,
  validateColorAppField,
  validateForm
} = useBusValidation(formData, { currentYear })
const globalError = ref('')

// 🆕 Persistencia y Catálogos
const {
  busOwners,
  companies,
  brands,
  handleStatusChange: originalHandleStatusChange,
  saveBus
} = useBusPersistence()

// Proveer el contexto a los sub-componentes
provide('busFormContext', {
  formData,
  errors,
  isEditMode,
  companies,
  busOwners,
  brands,
  currentYear,
  validatePlateField,
  validateAmbCodeField,
  validateCodeInternalField,
  validateIdCompanyField,
  validateModelYearField,
  validateCapacityField,
  validateColorBusField,
  validateIdOwnerField,
  validateModelNameField,
  validateColorAppField,
  handleStatusChange: () => originalHandleStatusChange(formData.value, props.data)
})

// =============================================
// MÉTODOS
// =============================================



const resetForm = () => {
  resetFormData()
  clearValidationErrors()
  globalError.value = ''
}

const handleSubmit = async () => {
  if (!validateForm()) {
    globalError.value = 'Por favor corrija los errores antes de continuar'
    return
  }

  isSubmitting.value = true
  globalError.value = ''

  try {
    await saveBus(formData.value, isEditMode.value, props.data)

    handleClose()
    resetForm()
  } catch (error) {
    console.error('Error al guardar bus:', error)
    globalError.value = error.message || 'Error al guardar el bus'
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

// =============================================
// WATCHERS
// =============================================

watch(() => props.data, (newBus) => {
  if (newBus) {
    loadBusData(newBus)
  } else {
    resetForm()
  }
}, { immediate: true, deep: true })

defineExpose({
  handleSave: handleSubmit
})
</script>
<style scoped>
/* 
  Los estilos compartidos están en src/assets/modal-forms.css
*/
</style>

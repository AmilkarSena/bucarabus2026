<template>
  <div class="form-grid">
    <!-- ID solo visible en modo edición (no editable) -->
    <div v-if="isEdit" class="form-group">
      <label for="route-id">ID de Ruta</label>
      <input
        type="text"
        id="route-id"
        :value="formData.id"
        class="form-input"
        disabled
      >
      <span class="hint-text">El ID no se puede modificar</span>
    </div>

    <!-- Nombre -->
    <div class="form-group" :class="{ 'full-width': !isEdit }">
      <label for="route-name">Nombre de Ruta *</label>
      <input
        type="text"
        id="route-name"
        v-model="formData.name"
        placeholder="Ej: Ruta Centro - Norte"
        required
        class="form-input"
        :class="{ error: errors.name }"
      >
      <span v-if="errors.name" class="error-message">{{ errors.name }}</span>
    </div>

    <!-- Empresa (ID) -->
    <div class="form-group">
      <label for="route-company">Empresa *</label>
      <select
        id="route-company"
        v-model.number="formData.idCompany"
        required
        class="form-input"
        :class="{ error: errors.idCompany }"
      >
        <option value="" disabled selected>Seleccione una empresa</option>
        <option v-for="company in companies" :key="company.id_company" :value="company.id_company">
          {{ company.company_name }}
        </option>
      </select>
      <span v-if="errors.idCompany" class="error-message">{{ errors.idCompany }}</span>
    </div>

    <!-- Color -->
    <div class="form-group">
      <label for="route-color">Color de Ruta</label>
      <input
        type="color"
        id="route-color"
        v-model="formData.color"
        class="form-input color-input"
      >
    </div>

    <!-- Descripción -->
    <div class="form-group full-width">
      <label for="route-description">Descripción</label>
      <textarea
        id="route-description"
        v-model="formData.description"
        rows="2"
        placeholder="Descripción de la ruta..."
        class="form-textarea"
      ></textarea>
    </div>

    <!-- Carteles de cartel -->
    <div class="form-group">
      <label for="route-departure-sign">Cartel salida</label>
      <input
        type="text"
        id="route-departure-sign"
        v-model="formData.departureRouteSign"
        placeholder="Ej: CABECERA → CENTRO"
        class="form-input"
        maxlength="100"
      >
    </div>
    <div class="form-group">
      <label for="route-return-sign">Cartel retorno</label>
      <input
        type="text"
        id="route-return-sign"
        v-model="formData.returnRouteSign"
        placeholder="Ej: CENTRO → CABECERA"
        class="form-input"
        maxlength="100"
      >
    </div>

    <!-- Horarios primer/último viaje -->
    <div class="form-group">
      <label for="route-first-trip">Primer viaje</label>
      <input
        type="time"
        id="route-first-trip"
        v-model="formData.firstTrip"
        class="form-input"
      >
    </div>
    <div class="form-group">
      <label for="route-last-trip">Último viaje</label>
      <input
        type="time"
        id="route-last-trip"
        v-model="formData.lastTrip"
        class="form-input"
        :class="{ error: errors.lastTrip }"
      >
      <span v-if="errors.lastTrip" class="error-message">{{ errors.lastTrip }}</span>
    </div>

    <!-- Tarifa y Ruta circular -->
    <div class="form-group">
      <label for="route-fare">Tarifa (COP)</label>
      <div class="input-with-icon">
        <span class="currency-symbol">$</span>
        <input
          type="number"
          id="route-fare"
          v-model.number="formData.routeFare"
          class="form-input"
          min="0"
          step="50"
        >
      </div>
    </div>
    <div class="form-group checkbox-container">
      <label class="checkbox-label">
        <input
          type="checkbox"
          v-model="formData.isCircular"
          class="form-checkbox"
        >
        <span class="label-text">¿Ruta circular?</span>
      </label>
      <span class="hint-text">Marcar si la ruta es un circuito cerrado (el bus vuelve al punto de inicio)</span>
    </div>

    <!-- Estado (Solo edición) -->
    <div v-if="isEdit" class="form-group checkbox-container full-width status-switch-container">
      <label class="switch-label">
        <div class="switch">
          <input type="checkbox" v-model="formData.isActive" @change="handleStatusChange">
          <span class="slider round"></span>
        </div>
        <span class="label-text" :class="formData.isActive ? 'text-active' : 'text-inactive'">
          {{ formData.isActive ? 'Ruta Activa' : 'Ruta Inactiva' }}
        </span>
      </label>
      <span class="hint-text">Activa o desactiva la disponibilidad de esta ruta en el sistema.</span>
    </div>

    <!-- Info ruta dibujada -->
    <div v-if="formData.path && formData.path.length > 0" class="info-panel route-info-panel">
      <div class="route-info-content">
        <strong>📍 Ruta dibujada:</strong> {{ formData.path.length }} puntos
        <span v-if="isEdit" class="distance-info">
          | Distancia: {{ calculateDistance() }} km
        </span>
      </div>
    </div>

    <!-- Paradas detectadas o asignadas (Componente Extraído) -->
    <RouteStopsTable
      v-if="(!isEdit && !data?.fromDraft && formData.path && formData.path.length > 1) || ((data?.fromDraft || isEdit) && formData.stops?.length)"
      :is-edit="isEdit"
      :from-draft="data?.fromDraft"
      :detected-stops="detectedStops"
      :stops="formData.stops"
      :loading-detection="loadingDetection"
      v-model:threshold="threshold"
    />

    <!-- Notas informativas -->
    <div v-if="isEdit" class="info-panel info-note">
      <strong>ℹ️ Información:</strong> Los puntos de la ruta no se pueden modificar. Si necesitas cambiar el recorrido, crea una nueva ruta.
    </div>
    <div v-if="!isEdit" class="info-panel info-note">
      <strong>💡 Nota:</strong> El ID de la ruta se generará automáticamente al guardar.
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoutesStore } from '../../stores/routes'
import { useAppStore } from '../../stores/app'
import { getCompanies } from '../../api/catalogs'
import { calculatePathDistance } from '../../utils/routeUtils'
import { useRouteStopDetection } from '../../composables/useRouteStopDetection'
import { useRouteValidation } from '../../composables/useRouteValidation'
import { useRouteForm } from '../../composables/useRouteForm'
import RouteStopsTable from './RouteStopsTable.vue'

const props = defineProps({
  data: {
    type: Object,
    default: () => ({})
  },
  isEdit: {
    type: Boolean,
    default: false
  }
})

const routesStore = useRoutesStore()
const appStore    = useAppStore()

const { errors, validateForm, validateStatusChange } = useRouteValidation()

// ─── Catálogos ────────────────────────────────────────────────────────────────
const companies = ref([])

onMounted(async () => {
  try {
    const response = await getCompanies()
    if (response && response.success) {
      companies.value = response.data
    }
  } catch (error) {
    console.error('Error cargando empresas:', error)
  }
})

// ─── Estado del formulario y Guardado ──────────────────────────────────────────
const { formData, handleStatusChange, handleSave, handleCancel } = useRouteForm({
  props,
  appStore,
  routesStore,
  validateForm,
  validateStatusChange,
  getDetectedStops: () => detectedStops.value
})

// ─── Detección de paradas por proximidad ──────────────────────────────────────
const { detectedStops, threshold, loadingDetection } = useRouteStopDetection({
  formData,
  props,
  appStore
})



// ─── Distancia aproximada ──────────────────────────────────────────────────────
const calculateDistance = () => calculatePathDistance(formData.value.path)

defineExpose({ handleSave, handleCancel })
</script>

<style scoped>
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-group.full-width {
  grid-column: 1 / -1;
}

.form-group label {
  font-weight: 500;
  color: #374151;
  font-size: 14px;
}

.form-input,
.form-textarea {
  padding: 12px 16px;
  border: 2px solid #e5e7eb;
  border-radius: 8px;
  font-size: 14px;
  transition: all 0.3s ease;
  background: white;
}

.form-input:focus,
.form-textarea:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-textarea {
  resize: vertical;
  min-height: 80px;
  font-family: inherit;
}

.form-input:disabled {
  background: #f9fafb;
  color: #6b7280;
  cursor: not-allowed;
}

.form-input.error {
  border-color: #ef4444;
}

.error-message {
  color: #ef4444;
  font-size: 12px;
  font-weight: 500;
}

.info-panel {
  background: rgba(59, 130, 246, 0.05);
  border: 1px solid rgba(59, 130, 246, 0.2);
  border-radius: 8px;
  padding: 16px;
  color: #1e40af;
  font-size: 14px;
  line-height: 1.5;
  grid-column: 1 / -1;
}

.info-panel strong {
  color: #1d4ed8;
}

.info-panel.info-note {
  background: rgba(156, 163, 175, 0.1);
  border-color: rgba(156, 163, 175, 0.3);
  color: #4b5563;
}

.info-panel.info-note strong {
  color: #374151;
}

.route-info-content {
  display: block;
}

.distance-info {
  color: #6366f1;
  font-size: 13px;
  margin-left: 8px;
}

.hint-text {
  font-size: 12px;
  color: #9ca3af;
  font-style: italic;
}

/* Tarifa y Checkboxes */
.input-with-icon {
  position: relative;
  display: flex;
  align-items: center;
}
.currency-symbol {
  position: absolute;
  left: 12px;
  color: #64748b;
  font-weight: 500;
}
.input-with-icon input {
  padding-left: 28px;
  width: 100%;
}
.checkbox-container {
  justify-content: flex-end;
}
.checkbox-label {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}
.form-checkbox {
  width: 16px;
  height: 16px;
  accent-color: #667eea;
}

/* Switch de Estado */
.status-switch-container {
  margin-top: 10px;
  padding-top: 15px;
  border-top: 1px dashed #e2e8f0;
}
.switch-label {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  font-weight: 600;
  font-size: 15px;
}
.switch {
  position: relative;
  display: inline-block;
  width: 46px;
  height: 24px;
}
.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}
.slider {
  position: absolute;
  cursor: pointer;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: #ef4444;
  transition: .3s;
}
.slider:before {
  position: absolute;
  content: "";
  height: 18px;
  width: 18px;
  left: 3px;
  bottom: 3px;
  background-color: white;
  transition: .3s;
}
input:checked + .slider {
  background-color: #10b981;
}
input:focus + .slider {
  box-shadow: 0 0 1px #10b981;
}
input:checked + .slider:before {
  transform: translateX(22px);
}
.slider.round {
  border-radius: 24px;
}
.slider.round:before {
  border-radius: 50%;
}
.text-active {
  color: #10b981;
}
.text-inactive {
  color: #ef4444;
}

/* Responsive */
@media (max-width: 768px) {
  .form-grid {
    grid-template-columns: 1fr;
    gap: 16px;
  }
}
</style>
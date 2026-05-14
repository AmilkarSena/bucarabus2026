<template>
  <Teleport to="body">
    <div v-if="modelValue" class="modal-overlay" @click.self="$emit('update:modelValue', false)">
      <div class="modal-box" role="dialog" :aria-label="`${isEditMode ? 'Editar' : 'Nuevo'} ${singular}`">

        <div class="modal-header">
          <h3>{{ isEditMode ? 'Editar' : 'Nuevo' }} {{ singular }}</h3>
          <button class="modal-close" @click="$emit('update:modelValue', false)">✕</button>
        </div>

        <form @submit.prevent="handleSubmit" class="modal-form">
          <!-- Campo Código (para seguros/documentos) -->
          <div v-if="showCode" class="form-group">
            <label :class="{ required: !isEditMode }">{{ codeLabel }}</label>
            <input
              v-model="localCode"
              type="text"
              placeholder="Ej: SOAT, LTC"
              :required="!isEditMode"
              :readonly="isEditMode"
              :maxlength="codeMaxLength"
              class="form-input"
              :class="{ error: formError, readonly: isEditMode, 'uppercase-text': forceUppercase }"
              @input="formError = ''"
            />
            <small v-if="isEditMode" class="form-hint">El código no puede modificarse.</small>
          </div>

          <div class="form-group">
            <label class="required">Nombre</label>
            <input
              v-model="localName"
              type="text"
              :placeholder="`Nombre de la ${singular}`"
              required
              maxlength="100"
              class="form-input"
              :class="{ error: formError }"
              @input="formError = ''"
            />
          </div>

          <!-- Campo Descripción -->
          <div v-if="showDescription" class="form-group">
            <label>Descripción</label>
            <textarea
              v-model="localDescription"
              placeholder="Descripción opcional"
              class="form-input"
              rows="3"
              @input="formError = ''"
            ></textarea>
          </div>

          <!-- Campo NIT: solo para Compañías -->
          <div v-if="showNit" class="form-group">
            <label :class="{ required: !isEditMode }">NIT</label>
            <input
              v-model="localNit"
              type="text"
              placeholder="Ej: 900123456-1"
              :required="!isEditMode"
              :readonly="isEditMode"
              maxlength="20"
              class="form-input"
              :class="{ error: formError, readonly: isEditMode }"
              @input="formError = ''"
            />
            <small v-if="isEditMode" class="form-hint">El NIT no puede modificarse.</small>
          </div>

          <!-- Switches (Obligatorio / Vencimiento) -->
          <div v-if="showMandatory || showExpiration" class="switches-row">
            <label v-if="showMandatory" class="switch-label">
              <input type="checkbox" v-model="localMandatory" />
              <span>Es obligatorio para operar</span>
            </label>
            
            <label v-if="showExpiration" class="switch-label">
              <input type="checkbox" v-model="localExpiration" />
              <span>Tiene fecha de vencimiento</span>
            </label>
          </div>

          <p v-if="formError" class="form-error">{{ formError }}</p>

          <div class="modal-actions">
            <button type="button" class="btn secondary" @click="$emit('update:modelValue', false)">
              Cancelar
            </button>
            <button type="submit" class="btn primary" :disabled="submitting">
              {{ submitting ? 'Guardando...' : (isEditMode ? 'Guardar cambios' : 'Crear') }}
            </button>
          </div>
        </form>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, watch } from 'vue'

const props = defineProps({
  modelValue: { type: Boolean, required: true },
  singular:   { type: String, required: true },
  isEditMode: { type: Boolean, default: false },
  submitting: { type: Boolean, default: false },
  
  // Opciones de campos
  showNit:         { type: Boolean, default: false },
  showCode:        { type: Boolean, default: false },
  codeLabel:       { type: String, default: 'Código' },
  codeMaxLength:   { type: Number, default: 5 },
  forceUppercase:  { type: Boolean, default: true },
  showDescription: { type: Boolean, default: false },
  showMandatory:   { type: Boolean, default: false },
  showExpiration:  { type: Boolean, default: false },
  
  // Valores iniciales
  initialName:        { type: String, default: '' },
  initialNit:         { type: String, default: '' },
  initialCode:        { type: String, default: '' },
  initialDescription: { type: String, default: '' },
  initialMandatory:   { type: Boolean, default: true },
  initialExpiration:  { type: Boolean, default: true }
})

const emit = defineEmits(['update:modelValue', 'submit'])

const localName        = ref('')
const localNit         = ref('')
const localCode        = ref('')
const localDescription = ref('')
const localMandatory   = ref(true)
const localExpiration  = ref(true)

const formError = ref('')

watch(() => props.modelValue, (isOpen) => {
  if (isOpen) {
    localName.value        = props.initialName
    localNit.value         = props.initialNit
    localCode.value        = props.initialCode
    localDescription.value = props.initialDescription
    localMandatory.value   = props.initialMandatory
    localExpiration.value  = props.initialExpiration
    formError.value        = ''
  }
})

defineExpose({ setError: (msg) => { formError.value = msg } })

function handleSubmit() {
  const finalCode = props.forceUppercase 
    ? localCode.value?.toUpperCase() 
    : localCode.value;
    
  emit('submit', { 
    name:        localName.value, 
    nit:         localNit.value,
    code:        finalCode,
    description: localDescription.value,
    mandatory:   localMandatory.value,
    expiration:  localExpiration.value
  })
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-box {
  background: white;
  border-radius: 12px;
  width: 420px;
  max-width: 95vw;
  box-shadow: 0 20px 60px rgba(0,0,0,0.15);
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 18px 22px 14px;
  border-bottom: 1px solid #f1f5f9;
}

.modal-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #1e293b;
}

.modal-close {
  background: none;
  border: none;
  cursor: pointer;
  color: #94a3b8;
  font-size: 18px;
  padding: 2px 6px;
  border-radius: 4px;
  transition: all 0.15s;
}

.modal-close:hover { background: #f1f5f9; color: #475569; }

.modal-form {
  padding: 18px 22px 22px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.form-group { display: flex; flex-direction: column; gap: 5px; }

.form-group label {
  font-size: 13px;
  font-weight: 500;
  color: #475569;
}

.form-group label.required::after { content: ' *'; color: #ef4444; }

.form-input {
  padding: 8px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  color: #1e293b;
  outline: none;
  font-family: inherit;
  transition: border-color 0.2s;
}

textarea.form-input {
  resize: vertical;
}

.form-input:focus  { border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37,99,235,0.1); }
.form-input.error  { border-color: #ef4444; }
.form-input.readonly { background: #f3f4f6; color: #6b7280; cursor: not-allowed; }
.uppercase-text { text-transform: uppercase; }

.form-hint  { display: block; margin-top: 4px; font-size: 12px; color: #6b7280; }
.form-error { margin: 0; font-size: 13px; color: #ef4444; }

.switches-row {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 4px;
}

.switch-label {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: #334155;
  cursor: pointer;
}

.modal-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 4px; }

.btn {
  padding: 7px 14px;
  border-radius: 8px;
  border: none;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  transition: all 0.2s;
}

.btn.primary   { background: #2563eb; color: white; }
.btn.primary:hover:not(:disabled) { background: #1d4ed8; }
.btn.primary:disabled { background: #93c5fd; cursor: not-allowed; }
.btn.secondary { background: #f1f5f9; color: #475569; }
.btn.secondary:hover { background: #e2e8f0; }
</style>

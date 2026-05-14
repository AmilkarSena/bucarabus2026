<template>
  <form class="compliance-form" @submit.prevent="handleSubmit">
    <h3>Registrar / Reemplazar Documento</h3>
    
    <p v-if="hasExistingRecord" class="replace-warning">
      ⚠️ Ya existe un documento para este tipo. Al guardar será <strong>reemplazado</strong>.
    </p>

    <div class="form-row">
      <label>
        Tipo *
        <select v-model="form.id_doc" required :disabled="isEditMode">
          <option value="">-- Seleccionar --</option>
          <option
            v-for="t in activeTypes"
            :key="t.id_doc"
            :value="t.id_doc"
          >{{ t.name_doc }}</option>
        </select>
      </label>
      <label>
        N° Documento *
        <input
          v-model.trim="form.doc_number"
          required
          placeholder="Ej: CTM-2026-001234"
          maxlength="50"
        />
      </label>
    </div>

    <!-- Fechas: solo se muestran si el documento tiene vencimiento -->
    <div v-if="requiresExpiration" class="form-row">
      <label>
        Fecha emisión *
        <input type="date" v-model="form.init_date" required />
      </label>
      <label>
        Fecha vencimiento *
        <input type="date" v-model="form.end_date" required />
      </label>
    </div>
    <div v-else class="info-row">
      <p class="no-expiration-info">ℹ️ Este documento no tiene fecha de vencimiento.</p>
    </div>

    <div class="form-row">
      <label>
        URL Documento
        <input
          v-model.trim="form.doc_url"
          type="url"
          placeholder="https://..."
        />
      </label>
    </div>

    <div v-if="localError" class="form-error">{{ localError }}</div>

    <div class="form-actions">
      <button type="button" class="btn btn-sec" @click="$emit('cancel')">Cancelar</button>
      <button type="submit" class="btn btn-pri" :disabled="submitting">
        {{ submitting ? 'Guardando...' : 'Guardar' }}
      </button>
    </div>
  </form>
</template>

<script setup>
import { ref, watch, computed } from 'vue'

const props = defineProps({
  activeTypes: { type: Array, required: true },
  initialData: { type: Object, default: () => ({}) },
  submitting:  { type: Boolean, default: false },
  error:       { type: String, default: null },
  records:     { type: Array, required: true } // Para checkear si ya existe un registro del tipo seleccionado
})

const emit = defineEmits(['submit', 'cancel'])

const form = ref({
  id_doc: '',
  doc_number: '',
  init_date: '',
  end_date: '',
  doc_url: ''
})

const localError = ref(null)

// Sincronizar prop error externo con localError
watch(() => props.error, (newVal) => {
  localError.value = newVal
})

const isEditMode = computed(() => !!props.initialData.doc_number)

const hasExistingRecord = computed(() => {
  if (isEditMode.value) return true // En edición siempre se va a reemplazar
  if (!form.value.id_doc) return false
  return props.records.some(r => r.id_doc === form.value.id_doc)
})

// Computar si el documento seleccionado tiene vencimiento
const requiresExpiration = computed(() => {
  if (!form.value.id_doc) return true // por defecto mostramos fechas
  const typeDef = props.activeTypes.find(t => t.id_doc === form.value.id_doc)
  return typeDef ? typeDef.has_expiration !== false : true
})

watch(() => props.initialData, (newVal) => {
  if (Object.keys(newVal).length > 0) {
    form.value = { ...newVal }
  } else {
    form.value = {
      id_doc: '',
      doc_number: '',
      init_date: '',
      end_date: '',
      doc_url: ''
    }
  }
  localError.value = null
}, { immediate: true, deep: true })

function handleSubmit() {
  localError.value = null
  
  if (requiresExpiration.value) {
    if (!form.value.init_date || !form.value.end_date) {
      localError.value = 'Las fechas de emisión y vencimiento son obligatorias.'
      return
    }
    if (form.value.end_date <= form.value.init_date) {
      localError.value = 'La fecha de vencimiento debe ser posterior a la de emisión.'
      return
    }
  } else {
    // Si no requiere vencimiento, nos aseguramos que las fechas vayan vacías para que el backend ponga null
    form.value.init_date = ''
    form.value.end_date = ''
  }

  emit('submit', { ...form.value })
}
</script>

<style scoped>
.compliance-form {
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  padding: 16px;
  background: #f8fafc;
}

.compliance-form h3 {
  margin: 0 0 14px;
  font-size: 14px;
  color: #334155;
  font-weight: 600;
}

.replace-warning {
  margin: 0 0 12px;
  padding: 8px 12px;
  background: #fffbeb;
  border-left: 3px solid #f59e0b;
  border-radius: 4px;
  font-size: 13px;
  color: #92400e;
}

.info-row {
  margin-bottom: 10px;
}

.no-expiration-info {
  margin: 0;
  padding: 8px 12px;
  background: #eff6ff;
  border-radius: 6px;
  font-size: 12px;
  color: #1e40af;
  border: 1px solid #bfdbfe;
}

.form-row {
  display: flex;
  gap: 12px;
  margin-bottom: 10px;
}

.form-row label {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
  font-size: 12px;
  color: #475569;
  font-weight: 500;
}

.form-row input,
.form-row select {
  padding: 7px 10px;
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  font-size: 13px;
  background: #fff;
  outline: none;
  transition: all 0.2s;
}

.form-row input:focus,
.form-row select:focus {
  border-color: #0ea5e9;
  box-shadow: 0 0 0 2px rgba(14, 165, 233, 0.2);
}

.form-row select:disabled {
  background: #f1f5f9;
  color: #94a3b8;
  cursor: not-allowed;
}

.form-error {
  color: #dc2626;
  font-size: 12px;
  margin-bottom: 8px;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 12px;
}

.btn {
  padding: 8px 18px;
  border-radius: 8px;
  border: none;
  cursor: pointer;
  font-size: 13px;
  font-weight: 600;
  transition: all 0.2s;
}

.btn-pri {
  background: #0ea5e9;
  color: #fff;
}

.btn-pri:hover:not(:disabled) {
  background: #0284c7;
}

.btn-pri:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-sec {
  background: #f1f5f9;
  color: #334155;
  border: 1px solid #e2e8f0;
}

.btn-sec:hover {
  background: #e2e8f0;
}

@media (max-width: 600px) {
  .form-row {
    flex-direction: column;
    gap: 10px;
  }
}
</style>

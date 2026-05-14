<template>
  <div class="compliance-section">
    <div v-if="loading" class="state-msg">Cargando pólizas...</div>
    <div v-else-if="error" class="state-msg error">{{ error }}</div>

    <template v-else>
      <div class="section-content">
        <!-- Bloques de tipos de seguro -->
        <InsuranceTypeBlock
          v-for="type in activeTypes"
          :key="type.id_insurance_type"
          :type="type"
          :records="getRecords(type.id_insurance_type)"
          @edit="onEdit"
        />

        <!-- Sección de formulario -->
        <div class="add-section">
          <button v-if="!showForm" class="btn-add" @click="showForm = true">
            ➕ Registrar Póliza
          </button>

          <InsuranceForm
            v-else
            :active-types="activeTypes"
            :insurers="insurers"
            :initial-data="formData"
            :records="records"
            :submitting="submitting"
            :error="formError"
            @submit="onSubmit"
            @cancel="cancelForm"
          />
        </div>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getBusInsurance, addBusInsurance, getActiveInsuranceTypes, getActiveInsurers } from '../../../../api/buses.js'
import InsuranceTypeBlock from './InsuranceTypeBlock.vue'
import InsuranceForm from './InsuranceForm.vue'

const props = defineProps({
  plate: { type: String, required: true }
})
const emit = defineEmits(['updated'])

const loading     = ref(true)
const error       = ref(null)
const records     = ref([])
const activeTypes = ref([])
const insurers    = ref([])

const showForm    = ref(false)
const formData    = ref({})
const submitting  = ref(false)
const formError   = ref(null)

onMounted(loadData)

async function loadData() {
  loading.value = true
  error.value   = null
  try {
    const [recRes, typesRes, insRes] = await Promise.all([
      getBusInsurance(props.plate),
      getActiveInsuranceTypes(),
      getActiveInsurers()
    ])
    records.value     = recRes.data    || []
    activeTypes.value = typesRes.data  || []
    insurers.value    = insRes.data    || []
  } catch (e) {
    error.value = 'Error al cargar datos: ' + (e.response?.data?.message || e.message)
  } finally {
    loading.value = false
  }
}

function getRecords(typeId) {
  return records.value.filter(r => r.id_insurance_type === typeId)
}

function onEdit(rec) {
  formData.value = {
    id_insurance_type: rec.id_insurance_type,
    id_insurance: rec.id_insurance,
    id_insurer: String(rec.id_insurer),
    start_date_insu: rec.start_date_insu?.slice(0, 10) || '',
    end_date_insu: rec.end_date_insu?.slice(0, 10) || '',
    doc_url: rec.doc_url || ''
  }
  showForm.value  = true
  formError.value = null
}

function cancelForm() {
  showForm.value  = false
  formError.value = null
  formData.value  = {}
}

async function onSubmit(data) {
  submitting.value = true
  formError.value  = null
  try {
    const res = await addBusInsurance(props.plate, data)
    if (!res.success) {
      formError.value = res.message
      return
    }
    await loadData()
    cancelForm()
    emit('updated')
  } catch (e) {
    formError.value = e.response?.data?.message || 'Error al guardar la póliza.'
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.compliance-section {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.state-msg {
  text-align: center;
  padding: 32px;
  color: #64748b;
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.state-msg.error {
  color: #dc2626;
}

.section-content {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
}

.add-section {
  margin-top: 4px;
}

.btn-add {
  display: block;
  width: 100%;
  padding: 10px;
  border: 2px dashed #c7d2fe;
  border-radius: 8px;
  background: transparent;
  color: #4f46e5;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
  text-align: center;
  transition: all 0.2s;
}

.btn-add:hover {
  background: #eef2ff;
}
</style>

<template>
  <div class="compliance-section">
    <div v-if="loading" class="state-msg">Cargando documentos...</div>
    <div v-else-if="error" class="state-msg error">{{ error }}</div>

    <template v-else>
      <div class="section-content">
        <!-- Bloques de tipos de documento -->
        <DocTypeBlock
          v-for="type in activeTypes"
          :key="type.id_doc"
          :type="type"
          :records="getRecords(type.id_doc)"
          @edit="onEdit"
        />

        <!-- Sección de formulario -->
        <div class="add-section">
          <button v-if="!showForm" class="btn-add" @click="showForm = true">
            ➕ Registrar Documento
          </button>

          <TransitDocForm
            v-else
            :active-types="activeTypes"
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
import { getBusTransitDocs, addBusTransitDoc, getActiveTransitDocTypes } from '../../../../api/buses.js'
import DocTypeBlock from './DocTypeBlock.vue'
import TransitDocForm from './TransitDocForm.vue'

const props = defineProps({
  plate: { type: String, required: true }
})
const emit = defineEmits(['updated'])

const loading     = ref(true)
const error       = ref(null)
const records     = ref([])
const activeTypes = ref([])

const showForm    = ref(false)
const formData    = ref({})
const submitting  = ref(false)
const formError   = ref(null)

onMounted(loadData)

async function loadData() {
  loading.value = true
  error.value   = null
  try {
    const [recRes, typesRes] = await Promise.all([
      getBusTransitDocs(props.plate),
      getActiveTransitDocTypes()
    ])
    records.value     = recRes.data   || []
    activeTypes.value = typesRes.data || []
  } catch (e) {
    error.value = 'Error al cargar datos: ' + (e.response?.data?.message || e.message)
  } finally {
    loading.value = false
  }
}

function getRecords(docId) {
  return records.value.filter(r => r.id_doc === docId)
}

function onEdit(rec) {
  formData.value = {
    id_doc: rec.id_doc,
    doc_number: rec.doc_number,
    init_date: rec.init_date?.slice(0, 10) || '',
    end_date: rec.end_date?.slice(0, 10) || '',
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
    const res = await addBusTransitDoc(props.plate, data)
    if (!res.success) {
      formError.value = res.message
      return
    }
    await loadData()
    cancelForm()
    emit('updated')
  } catch (e) {
    formError.value = e.response?.data?.message || 'Error al guardar el documento.'
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
  border: 2px dashed #bae6fd;
  border-radius: 8px;
  background: transparent;
  color: #0284c7;
  cursor: pointer;
  font-size: 14px;
  font-weight: 600;
  text-align: center;
  transition: all 0.2s;
}

.btn-add:hover {
  background: #e0f2fe;
}
</style>

<template>
  <div class="catalogs-section">
    <div class="page-header">
      <h1>Catálogos del Sistema</h1>
    </div>

    <div class="catalogs-layout">
      <!-- Sidebar: navegación entre catálogos -->
      <CatalogSidebar
        v-model="activeCatalogKey"
        :catalogs="sidebarItems"
      />

      <!-- Panel: tabla del catálogo activo -->
      <CatalogPanel
        :active-catalog="activeCatalogMeta"
        :loading="store.loading"
        :card-error="toggleError"
        :can-create="authStore.can('CREATE_CATALOGS')"
        :can-edit="authStore.can('EDIT_CATALOGS')"
        :can-toggle="authStore.can('TOGGLE_CATALOGS')"
        @create="openModal"
        @edit="openEditModal"
        @toggle="handleToggle"
      />
    </div>

    <!-- Modal de formulario (Create / Edit) -->
    <CatalogFormModal
      v-model="showModal"
      :singular="activeCatalogMeta?.singular ?? ''"
      :show-nit="activeCatalogKey === 'companies'"
      :show-code="activeCatalogMeta?.hasCode"
      :code-label="activeCatalogMeta?.codeLabel || 'Código'"
      :code-max-length="activeCatalogMeta?.codeMaxLength || 5"
      :force-uppercase="activeCatalogMeta?.forceUppercase ?? true"
      :show-description="activeCatalogMeta?.hasDescription"
      :show-mandatory="activeCatalogMeta?.hasMandatory"
      :show-expiration="activeCatalogMeta?.hasExpiration"
      :is-edit-mode="isEditMode"
      :initial-name="formInitialName"
      :initial-nit="formInitialNit"
      :initial-code="formInitialCode"
      :initial-description="formInitialDescription"
      :initial-mandatory="formInitialMandatory"
      :initial-expiration="formInitialExpiration"
      :submitting="submitting"
      ref="modalRef"
      @submit="handleSubmit"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useCatalogsAdminStore } from '../stores/catalogsAdmin.js'
import { useAuthStore } from '../stores/auth'
import CatalogSidebar   from '../components/CatalogSidebar.vue'
import CatalogPanel     from '../components/CatalogPanel.vue'
import CatalogFormModal from '../components/CatalogFormModal.vue'

const store     = useCatalogsAdminStore()
const authStore = useAuthStore()

// ─── Definición de catálogos ────────────────────────────────────────────────
// Para agregar un nuevo catálogo basta con añadir una entrada aquí.
const CATALOGS = [
  {
    key:      'eps',
    title:    'EPS',
    icon:     '🏥',
    singular: 'EPS',
    idKey:    'id_eps',
    nameKey:  'name_eps',
    items:    computed(() => store.eps),
  },
  {
    key:      'arl',
    title:    'ARL',
    icon:     '🛡️',
    singular: 'ARL',
    idKey:    'id_arl',
    nameKey:  'name_arl',
    items:    computed(() => store.arl),
  },
  {
    key:      'brands',
    title:    'Marcas',
    icon:     '🏷️',
    singular: 'Marca',
    idKey:    'id_brand',
    nameKey:  'brand_name',
    items:    computed(() => store.brands),
  },
  {
    key:       'companies',
    title:     'Compañías',
    icon:      '🏢',
    singular:  'Compañía',
    idKey:     'id_company',
    nameKey:   'company_name',
    extraKey:  'nit_company',
    extraLabel:'NIT',
    items:     computed(() => store.companies),
  },
  {
    key:      'insurers',
    title:    'Aseguradoras',
    icon:     '📋',
    singular: 'Aseguradora',
    idKey:    'id_insurer',
    nameKey:  'insurer_name',
    items:    computed(() => store.insurers),
  },
  {
    key:      'insuranceTypes',
    title:    'Tipos de Seguros',
    icon:     '🛡️',
    singular: 'Tipo de Seguro',
    idKey:    'id_insurance_type',
    nameKey:  'name_insurance',
    hasCode: true,
    codeLabel: 'Abreviatura (Tag)',
    hasDescription: true,
    hasMandatory: true,
    hasExpiration: false,
    items:    computed(() => store.insuranceTypes),
  },
  {
    key:      'transitDocs',
    title:    'Tipos de Documentos',
    icon:     '📄',
    singular: 'Tipo de Documento',
    idKey:    'id_doc',
    nameKey:  'name_doc',
    hasCode: true,
    codeLabel: 'Abreviatura (Tag)',
    hasDescription: true,
    hasMandatory: true,
    hasExpiration: true,
    items:    computed(() => store.transitDocs),
  },
  {
    key:      'incidentTypes',
    title:    'Tipos de Incidentes',
    icon:     '🚨',
    singular: 'Tipo de Incidente',
    idKey:    'id_incident',
    nameKey:  'name_incident',
    hasCode:  true,
    codeLabel:'Tag (ej. accident)',
    codeMaxLength: 20,
    forceUppercase: false,
    hasDescription: false,
    hasMandatory: false,
    hasExpiration: false,
    items:    computed(() => store.incidentTypes),
  }
]

// ─── Navegación ─────────────────────────────────────────────────────────────
const activeCatalogKey = ref(CATALOGS[0].key)

const sidebarItems = computed(() =>
  CATALOGS.map(c => ({
    key:   c.key,
    title: c.title,
    icon:  c.icon,
    count: c.items.value?.length ?? 0,
  }))
)

const activeCatalogMeta = computed(() => {
  const cat = CATALOGS.find(c => c.key === activeCatalogKey.value)
  if (!cat) return null
  return { ...cat, items: cat.items.value }
})

// ─── Estado del Modal ────────────────────────────────────────────────────────
const showModal      = ref(false)
const isEditMode     = ref(false)
const submitting     = ref(false)
const editingId      = ref(null)
const formInitialName = ref('')
const formInitialNit  = ref('')
const formInitialCode = ref('')
const formInitialDescription = ref('')
const formInitialMandatory = ref(true)
const formInitialExpiration = ref(true)
const modalRef       = ref(null)

// ─── Estado de errores de toggle ─────────────────────────────────────────────
const toggleError = ref('')

// ─── Carga inicial ───────────────────────────────────────────────────────────
onMounted(async () => {
  await Promise.all([
    store.fetchEps(),
    store.fetchArl(),
    store.fetchBrands(),
    store.fetchCompanies(),
    store.fetchInsurers(),
    store.fetchInsuranceTypes(),
    store.fetchTransitDocs(),
    store.fetchIncidentTypes()
  ])
})

// ─── Acciones del Modal ───────────────────────────────────────────────────────
function openModal() {
  isEditMode.value    = false
  editingId.value     = null
  formInitialName.value = ''
  formInitialNit.value  = ''
  formInitialCode.value = ''
  formInitialDescription.value = ''
  formInitialMandatory.value = true
  formInitialExpiration.value = true
  showModal.value     = true
}

function openEditModal(item) {
  const cat = CATALOGS.find(c => c.key === activeCatalogKey.value)
  if (!cat) return

  isEditMode.value    = true
  editingId.value     = item[cat.idKey]
  formInitialName.value = item[cat.nameKey] ?? ''
  formInitialNit.value  = item.nit_company ?? ''
  formInitialCode.value = cat.hasCode ? (item.code ?? '') : ''
  formInitialDescription.value = item.descrip_insurance || item.descrip_doc || ''
  formInitialMandatory.value = item.is_mandatory ?? true
  formInitialExpiration.value = item.has_expiration ?? true
  showModal.value     = true
}

async function handleSubmit(payload) {
  submitting.value = true
  try {
    const type   = activeCatalogKey.value
    const result = isEditMode.value
      ? await callUpdate(type, editingId.value, payload)
      : await callCreate(type, payload)

    if (result.success) {
      showModal.value = false
    } else {
      modalRef.value?.setError(result.message || 'Error al guardar')
    }
  } catch (e) {
    modalRef.value?.setError(e.response?.data?.message || 'Error al guardar')
  } finally {
    submitting.value = false
  }
}

async function callCreate(type, payload) {
  const { name, nit, code, description, mandatory, expiration } = payload;
  switch (type) {
    case 'eps':       return store.createEps({ name_eps: name })
    case 'arl':       return store.createArl({ name_arl: name })
    case 'brands':    return store.createBrand({ brand_name: name })
    case 'companies': return store.createCompany({ company_name: name, nit_company: nit })
    case 'insurers':  return store.createInsurer({ insurer_name: name })
    case 'insuranceTypes': return store.createInsuranceType({ name, code, description, mandatory })
    case 'transitDocs':    return store.createTransitDoc({ name, code, description, mandatory, expiration })
    case 'incidentTypes':  return store.createIncidentType({ name, code })
  }
}

async function callUpdate(type, id, payload) {
  const { name, code, description, mandatory, expiration } = payload;
  switch (type) {
    case 'eps':       return store.updateEps(id, { name_eps: name })
    case 'arl':       return store.updateArl(id, { name_arl: name })
    case 'brands':    return store.updateBrand(id, { brand_name: name })
    case 'companies': return store.updateCompany(id, { company_name: name })
    case 'insurers':  return store.updateInsurer(id, { insurer_name: name })
    case 'insuranceTypes': return store.updateInsuranceType(id, { name, code, description, mandatory })
    case 'transitDocs':    return store.updateTransitDoc(id, { name, code, description, mandatory, expiration })
    case 'incidentTypes':  return store.updateIncidentType(id, { name, code })
  }
}

async function handleToggle(item) {
  toggleError.value = ''
  const type = activeCatalogKey.value
  const cat  = CATALOGS.find(c => c.key === type)
  const id   = item[cat.idKey]
  try {
    switch (type) {
      case 'eps':       await store.toggleEps(id); break
      case 'arl':       await store.toggleArl(id); break
      case 'brands':    await store.toggleBrand(id); break
      case 'companies': await store.toggleCompany(id); break
      case 'insurers':  await store.toggleInsurer(id); break
      case 'insuranceTypes': await store.toggleInsuranceType(id); break
      case 'transitDocs':    await store.toggleTransitDoc(id); break
      case 'incidentTypes':  await store.toggleIncidentType(id); break
    }
  } catch (e) {
    toggleError.value = e.response?.data?.message || 'No se pudo cambiar el estado'
    setTimeout(() => { toggleError.value = '' }, 5000)
  }
}
</script>

<style scoped>
.catalogs-section { display: flex; flex-direction: column; gap: 16px; }

.page-header h1 {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: #1e293b;
}

.catalogs-layout {
  display: flex;
  gap: 16px;
  align-items: flex-start;
}

/* Sidebar fijo de 200px, panel ocupa el resto */
:deep(.catalog-sidebar) { width: 200px; flex-shrink: 0; }

/* Responsive */
@media (max-width: 768px) {
  .catalogs-section {
    gap: 0;
  }

  .page-header {
    padding: 15px;
    background: white;
    margin-bottom: 0;
  }

  .catalogs-layout {
    flex-direction: column;
    gap: 0;
  }

  :deep(.catalog-sidebar) {
    width: 100% !important;
  }
}
</style>

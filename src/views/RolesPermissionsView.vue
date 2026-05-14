<template>
  <div class="roles-permissions-view fade-in">
    <div class="header">
      <div>
        <h1 class="title">Gestión de Permisos</h1>
        <p class="subtitle">Asigna accesos granulares a los roles del sistema</p>
      </div>
      <button 
        class="btn primary" 
        :disabled="!selectedRole || isSaving" 
        @click="savePermissions"
      >
        <span class="icon">{{ isSaving ? '⏳' : '💾' }}</span>
        {{ isSaving ? 'Guardando...' : 'Guardar Cambios' }}
      </button>
    </div>

    <div class="split-layout">
      <!-- PANEL IZQUIERDO: ROLES (Componente) -->
      <RolesList 
        :roles="roles" 
        :loading="loadingRoles" 
        :selectedRoleId="selectedRole?.id_role"
        @select-role="selectRole"
      />

      <!-- PANEL DERECHO: PERMISOS (Componente) -->
      <PermissionsAccordion 
        :groupedPermissions="groupedPermissions"
        :selectedRole="selectedRole"
        v-model:checkedPermissions="checkedPermissions"
        :loading="loadingPermissions"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '../api/client.js'
import RolesList from '../components/RolesList.vue'
import PermissionsAccordion from '../components/PermissionsAccordion.vue'

// Estado
const roles = ref([])
const permissionsMap = ref([]) // Catálogo plano
const selectedRole = ref(null)
const checkedPermissions = ref([]) // Array de 'code_permission' marcados

// Estado UI
const loadingRoles = ref(false)
const loadingPermissions = ref(false)
const isSaving = ref(false)

// Computados
const groupedPermissions = computed(() => {
  // 1. Filtrar los padres (id_parent = null)
  const parents = permissionsMap.value.filter(p => !p.id_parent)
  
  // 2. Anidar los hijos
  return parents.map(parent => {
    return {
      ...parent,
      children: permissionsMap.value.filter(p => p.id_parent === parent.id_permission)
    }
  })
})

// Carga Inicial
onMounted(async () => {
  await fetchRoles()
  await fetchMasterPermissions()
})

const fetchRoles = async () => {
  loadingRoles.value = true
  try {
    const { data } = await api.get('/catalogs/roles')
    // Filtrar el rol Administrador (id_role === 1) porque tiene acceso total
    roles.value = data.data.filter(role => role.id_role !== 1)
  } catch (error) {
    alert('Error al cargar roles')
  } finally {
    loadingRoles.value = false
  }
}

const fetchMasterPermissions = async () => {
  try {
    const { data } = await api.get('/roles/permissions')
    permissionsMap.value = data.data
  } catch (error) {
    alert('Error al cargar catálogo de permisos')
  }
}

// Interacción
const selectRole = async (role) => {
  selectedRole.value = role
  loadingPermissions.value = true
  checkedPermissions.value = []
  
  try {
    const { data } = await api.get(`/roles/${role.id_role}/permissions`)
    checkedPermissions.value = data.data || []
  } catch (error) {
    alert('Error al cargar permisos del rol')
  } finally {
    loadingPermissions.value = false
  }
}

// Guardar
const savePermissions = async () => {
  if (!selectedRole.value) return
  
  isSaving.value = true
  try {
    await api.put(`/roles/${selectedRole.value.id_role}/permissions`, {
      permissions: checkedPermissions.value
    })
    alert('Permisos actualizados correctamente')
  } catch (error) {
    alert('Error al guardar permisos')
  } finally {
    isSaving.value = false
  }
}
</script>

<style scoped>
.roles-permissions-view {
  padding: 0;
  max-width: 1400px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
}

.title {
  font-size: 24px;
  font-weight: 700;
  color: #1e293b;
  margin: 0 0 4px 0;
}

.subtitle {
  color: #64748b;
  margin: 0;
  font-size: 14px;
}

.split-layout {
  display: flex;
  gap: 24px;
  flex: 1;
  min-height: 0; /* Crucial para que los hijos puedan hacer scroll */
}

/* Forzar que los componentes ocupen el espacio flex */
.split-layout > * {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.btn {
  padding: 12px 24px;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 8px;
  transition: all 0.2s;
}

.btn.primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.btn.primary:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  background: #cbd5e1;
}

@media (max-width: 1024px) {
  .split-layout {
    flex-direction: column;
  }
}
</style>

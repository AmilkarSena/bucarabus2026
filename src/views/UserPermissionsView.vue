<template>
  <div class="user-permissions-view fade-in">
    <div class="header">
      <div>
        <h1 class="title">Permisos por Usuario</h1>
        <p class="subtitle">Asigna overrides individuales sobre los permisos del rol</p>
      </div>
      <button
        class="btn primary"
        :disabled="!selectedUser || isSaving"
        @click="saveOverrides"
      >
        <span class="icon">{{ isSaving ? '⏳' : '💾' }}</span>
        {{ isSaving ? 'Guardando...' : 'Guardar Cambios' }}
      </button>
    </div>

    <div class="split-layout">
      <!-- PANEL IZQUIERDO: USUARIOS -->
      <UsersList
        :users="users"
        :loading="loadingUsers"
        :selectedUserId="selectedUser?.id_user"
        @select-user="selectUser"
      />

      <!-- PANEL DERECHO: PERMISOS EN MODO USUARIO -->
      <PermissionsAccordion
        mode="user"
        :groupedPermissions="groupedPermissions"
        :selectedUser="selectedUser"
        :rolePermissions="rolePermissions"
        v-model:userOverrides="userOverrides"
        :loading="loadingPermissions"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '../api/client.js'
import UsersList from '../components/UsersList.vue'
import PermissionsAccordion from '../components/PermissionsAccordion.vue'

// Estado
const users          = ref([])
const permissionsMap = ref([])   // Catálogo maestro plano
const selectedUser   = ref(null)
const rolePermissions = ref([])  // Códigos heredados del rol del usuario seleccionado
const userOverrides  = ref([])   // [{code, is_granted}] — overrides individuales

// Estado UI
const loadingUsers       = ref(false)
const loadingPermissions = ref(false)
const isSaving           = ref(false)

// Agrupa el catálogo maestro en árbol (igual que RolesPermissionsView)
const groupedPermissions = computed(() => {
  const parents = permissionsMap.value.filter(p => !p.id_parent)
  return parents.map(parent => ({
    ...parent,
    children: permissionsMap.value.filter(p => p.id_parent === parent.id_permission)
  }))
})

// Carga Inicial
onMounted(async () => {
  await fetchUsers()
  await fetchMasterPermissions()
})

/** Obtiene todos los usuarios activos con su rol principal */
const fetchUsers = async () => {
  loadingUsers.value = true
  try {
    const { data } = await api.get('/users?active=true')
    // El API devuelve roles como array JSON: [{id_role, role_name}]
    // Aplanamos a role_name para que UsersList lo muestre directamente
    users.value = (data.data || []).map(u => ({
      ...u,
      role_name: u.roles?.[0]?.role_name || null
    }))
  } catch {
    alert('Error al cargar usuarios')
  } finally {
    loadingUsers.value = false
  }
}

/** Catálogo maestro de permisos (estructura de árbol) */
const fetchMasterPermissions = async () => {
  try {
    const { data } = await api.get('/roles/permissions')
    permissionsMap.value = data.data
  } catch {
    alert('Error al cargar catálogo de permisos')
  }
}

/** Al seleccionar un usuario: carga sus permisos de rol y sus overrides */
const selectUser = async (user) => {
  selectedUser.value = user
  loadingPermissions.value = true
  rolePermissions.value = []
  userOverrides.value = []

  try {
    // 1. Permisos heredados del rol (todos los roles del usuario)
    const rolesRes = await api.get(`/users/${user.id_user}/roles`)
    const userRoles = rolesRes.data.data || []

    // Obtener permisos de cada rol y unificar
    const allRolePerms = new Set()
    for (const role of userRoles) {
      const permRes = await api.get(`/roles/${role.id_role}/permissions`)
      ;(permRes.data.data || []).forEach(code => allRolePerms.add(code))
    }
    rolePermissions.value = [...allRolePerms]

    // 2. Overrides individuales del usuario
    const overridesRes = await api.get(`/users/${user.id_user}/permissions/overrides`)
    userOverrides.value = overridesRes.data.data || []

    // Enriquecer el selectedUser con el nombre del rol para el badge
    selectedUser.value = {
      ...user,
      role_name: userRoles[0]?.role_name || 'Sin rol'
    }
  } catch {
    alert('Error al cargar permisos del usuario')
  } finally {
    loadingPermissions.value = false
  }
}

/** Guarda solo los overrides individuales */
const saveOverrides = async () => {
  if (!selectedUser.value) return
  isSaving.value = true
  try {
    await api.put(`/users/${selectedUser.value.id_user}/permissions/overrides`, {
      overrides: userOverrides.value
    })
    alert('Permisos individuales actualizados correctamente')
  } catch {
    alert('Error al guardar los overrides')
  } finally {
    isSaving.value = false
  }
}
</script>

<style scoped>
.user-permissions-view {
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
  min-height: 0;
}

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

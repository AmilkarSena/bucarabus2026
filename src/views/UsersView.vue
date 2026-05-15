<template>
  <div class="users-section">
    <div class="section-header">
      <div class="header-stats">
        <div class="stat-card">
          <h3>Total Usuarios</h3>
          <span>{{ totalUsers }}</span>
        </div>
        <div class="stat-card">
          <h3>Administradores</h3>
          <span class="role-admins">{{ usersByRole.admins }}</span>
        </div>
        <div class="stat-card">
          <h3>Turnadores</h3>
          <span class="role-drivers">{{ usersByRole.turners }}</span>
        </div>
        <div class="stat-card">
          <h3>Conductores</h3>
          <span class="role-drivers">{{ usersByRole.drivers }}</span>
        </div>
      </div>
      <div class="header-actions">
        <button class="btn primary" @click="openUserModal">
          <span>➕</span> Nuevo Usuario
        </button>
      </div>
    </div>

    <div class="users-controls">
      <div class="search-filters">
        <input
          type="text"
          v-model="searchQuery"
          placeholder="Buscar por nombre o email..."
          class="search-input"
          @input="filterUsers"
        />
        <select v-model="roleFilter" class="filter-select" @change="filterUsers">
          <option value="">Todos los roles</option>
          <option value="1">Administrador</option>
          <option value="2">Turnador</option>
          <option value="3">Conductor</option>
        </select>
        <select v-model="statusFilter" class="filter-select" @change="filterUsers">
          <option value="">Todos los estados</option>
          <option value="true">Activos</option>
          <option value="false">Inactivos</option>
        </select>
      </div>
    </div>

    <div class="users-table-container">
      <table class="users-table">
        <thead class="mobile-hidden">
          <tr>
            <th>ID</th>
            <th>Usuario</th>
            <th>Email</th>
            <th>Roles</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in filteredUsers" :key="user.id_user" class="user-row">
            <td class="user-id-cell mobile-hidden">{{ user.id_user }}</td>
            <td class="user-cell">
              <div class="user-info-compact">
                <div class="user-avatar-small">
                  <span>{{ getInitials(user.full_name) }}</span>
                </div>
                <div class="user-name-col">
                  <span class="name">{{ user.full_name }}</span>
                  <div class="user-meta-mobile mobile-only">
                    <span class="email-sub">{{ user.email_user }}</span>
                    <div class="roles-inline">
                      <span 
                        v-for="role in user.roles" 
                        :key="role.id_role" 
                        class="role-tag-mini" 
                        :class="getRoleClass(role.id_role)"
                      >
                        {{ role.role_name }}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </td>
            <td class="mobile-hidden">{{ user.email_user }}</td>
            <td class="roles-cell-wrapper mobile-hidden">
              <div class="roles-cell">
                <span 
                  v-for="role in user.roles" 
                  :key="role.id_role" 
                  class="role-badge-small" 
                  :class="getRoleClass(role.id_role)"
                >
                  {{ role.role_name }}
                </span>
              </div>
            </td>
            <td class="status-cell-wrapper">
              <span class="status-dot-user" :class="user.is_active ? 'active' : 'inactive'" :title="user.is_active ? 'Activo' : 'Inactivo'"></span>
            </td>
            <td class="actions-cell-wrapper">
              <div class="actions-cell">
                <button class="btn-icon" title="Editar" @click="editUser(user)">✏️</button>
                <button class="btn-icon" title="Gestionar Roles" @click="manageRoles(user)">🎭</button>
                <button class="btn-icon mobile-hidden" title="Cambiar Contraseña" @click="changePassword(user)">🔑</button>
                <button 
                  v-if="!user.roles?.some(r => r.id_role === 1)"
                  class="btn-icon" 
                  :title="user.is_active ? 'Desactivar' : 'Activar'"
                  @click="toggleStatus(user)"
                >
                  {{ user.is_active ? '🔒' : '🔓' }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <div v-if="filteredUsers.length === 0" class="empty-state">
        <p>No se encontraron usuarios</p>
      </div>
    </div>

    <!-- Modal: Crear/Editar Usuario -->
    <div v-if="showUserModal" class="modal-overlay" @click.self="closeUserModal">
      <div class="modal-content">
        <div class="modal-header">
          <h2>{{ isEditing ? 'Editar Usuario' : 'Nuevo Usuario' }}</h2>
          <button class="btn-close" @click="closeUserModal">✕</button>
        </div>
        <div class="modal-body">
          <form @submit.prevent="saveUser">
            <div class="form-row">
              <div class="form-group full-width">
                <label>Nombre Completo *</label>
                <input
                  type="text"
                  v-model="userForm.full_name"
                  required
                  minlength="2"
                  maxlength="100"
                  placeholder="Juan Pérez García"
                />
              </div>
            </div>

            <div class="form-row">
              <div class="form-group full-width">
                <label>Email *</label>
                <input
                  type="email"
                  v-model="userForm.email_user"
                  required
                  maxlength="320"
                  placeholder="usuario@example.com"
                />
              </div>
            </div>

            <div class="form-row" v-if="!isEditing">
              <div class="form-group full-width">
                <label>Contraseña *</label>
                <input
                  type="password"
                  v-model="userForm.password"
                  :required="!isEditing"
                  minlength="8"
                  placeholder="Ej: MiClave123"
                />
                <small class="form-hint">Mínimo 8 caracteres, debe incluir mayúscula, minúscula y número</small>
              </div>
            </div>


            <div class="form-row" v-if="!isEditing">
              <div class="form-group full-width">
                <label>Rol Inicial</label>
                <select v-model="userForm.initial_role">
                  <option v-for="role in creatableRoles" :key="role.id_role" :value="role.id_role">
                    {{ role.role_name }}
                  </option>
                </select>
                <small class="form-hint">Si el rol es Conductor, vincúlalo a un registro de conductor desde el módulo de Conductores</small>
              </div>
            </div>

            <div class="form-actions">
              <button type="button" class="btn secondary" @click="closeUserModal">
                Cancelar
              </button>
              <button type="submit" class="btn primary" :disabled="isSubmitting">
                {{ isSubmitting ? 'Guardando...' : (isEditing ? 'Actualizar' : 'Crear Usuario') }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- Modal: Gestionar Roles -->
    <div v-if="showRolesModal" class="modal-overlay" @click.self="closeRolesModal">
      <div class="modal-content modal-medium">
        <div class="modal-header">
          <h2>Gestionar Roles - {{ selectedUser?.full_name }}</h2>
          <button class="btn-close" @click="closeRolesModal">✕</button>
        </div>
        <div class="modal-body">
          <div class="roles-management">
            <div class="current-roles">
              <h3>Roles Actuales</h3>
              <div class="roles-list">
                <div 
                  v-for="role in selectedUser?.roles" 
                  :key="role.id_role"
                  class="role-item"
                >
                  <span class="role-badge" :class="getRoleClass(role.id_role)">
                    {{ role.role_name }}
                  </span>
                  <button 
                    class="btn-icon-small"
                    title="Quitar rol"
                    @click="removeRole(role.id_role)"
                    :disabled="(selectedUser.roles?.length ?? 0) === 1"
                  >
                    ✕
                  </button>
                </div>
                <p v-if="(selectedUser?.roles?.length ?? 0) === 0" class="empty-roles">
                  Sin roles asignados
                </p>
              </div>
            </div>

            <div class="available-roles">
              <h3>Agregar Rol</h3>
              <p v-if="isAdmin" class="info-hint">
                El rol Administrador es exclusivo y no puede combinarse con otros roles.
              </p>
              <div v-else class="add-role-form">
                <select v-model="roleToAdd" class="role-select">
                  <option value="">Seleccionar rol...</option>
                  <option 
                    v-for="role in availableRoles" 
                    :key="role.id_role"
                    :value="role.id_role"
                  >
                    {{ role.role_name }}
                  </option>
                </select>
                <button 
                  class="btn primary-small"
                  @click="addRole"
                  :disabled="!roleToAdd"
                >
                  Agregar
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal: Cambiar Contraseña -->
    <div v-if="showPasswordModal" class="modal-overlay" @click.self="closePasswordModal">
      <div class="modal-content modal-small">
        <div class="modal-header">
          <h2>Cambiar Contraseña - {{ selectedUser?.full_name }}</h2>
          <button class="btn-close" @click="closePasswordModal">✕</button>
        </div>
        <div class="modal-body">
          <form @submit.prevent="updatePassword">
            <div class="form-group">
              <label>Nueva Contraseña *</label>
              <input
                type="password"
                v-model="newPassword"
                required
                minlength="8"
                placeholder="Mínimo 8 caracteres"
              />
            </div>
            <div class="form-group">
              <label>Confirmar Contraseña *</label>
              <input
                type="password"
                v-model="confirmPassword"
                required
                minlength="8"
                placeholder="Repetir contraseña"
              />
            </div>
            <div class="form-actions">
              <button type="button" class="btn secondary" @click="closePasswordModal">
                Cancelar
              </button>
              <button type="submit" class="btn primary" :disabled="isSubmitting">
                {{ isSubmitting ? 'Actualizando...' : 'Cambiar Contraseña' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useUsersStore } from '../stores/users'
import { getRoles } from '../api/catalogs'

// Store
const usersStore = useUsersStore()

// Estado local
const users = computed(() => usersStore.users)
const searchQuery = ref('')
const roleFilter = ref('')
const statusFilter = ref('')
const showUserModal = ref(false)
const showRolesModal = ref(false)
const showPasswordModal = ref(false)
const isEditing = ref(false)
const isSubmitting = ref(false)
const selectedUser = ref(null)
const roleToAdd = ref('')
const newPassword = ref('')
const confirmPassword = ref('')

// Roles cargados desde la BD
const allRoles = ref([])

// Roles disponibles al CREAR usuario (todos excepto Administrador)
const creatableRoles = computed(() => allRoles.value.filter(r => r.id_role !== ADMIN_ROLE_ID))

// Roles disponibles en el modal de gestión (solo Turnador y Conductor; Admin es exclusivo)
const managableRoles = computed(() => allRoles.value.filter(r => r.id_role !== ADMIN_ROLE_ID))

const userForm = ref({
  full_name: '',
  email_user: '',
  password: '',
  initial_role: ''
})

// Computados
const totalUsers = computed(() => users.value.length)

const usersByRole = computed(() => {
  return {
    admins: users.value.filter(u => u.roles?.some(r => r.id_role === 1)).length,
    turners: users.value.filter(u => u.roles?.some(r => r.id_role === 2)).length,
    drivers: users.value.filter(u => u.roles?.some(r => r.id_role === 3)).length
  }
})

const filteredUsers = computed(() => {
  let filtered = users.value

  // Filtrar por búsqueda
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase()
    filtered = filtered.filter(u =>
      u.full_name?.toLowerCase().includes(query) ||
      u.email_user?.toLowerCase().includes(query)
    )
  }

  // Filtrar por rol
  if (roleFilter.value) {
    const roleId = parseInt(roleFilter.value)
    filtered = filtered.filter(u => u.roles?.some(r => r.id_role === roleId))
  }

  // Filtrar por estado
  if (statusFilter.value !== '') {
    const isActive = statusFilter.value === 'true'
    filtered = filtered.filter(u => u.is_active === isActive)
  }

  return filtered
})

const ADMIN_ROLE_ID = 1

const isAdmin = computed(() =>
  selectedUser.value?.roles?.some(r => r.id_role === ADMIN_ROLE_ID) ?? false
)

const availableRoles = computed(() => {
  if (!selectedUser.value) return managableRoles.value
  const userRoleIds = selectedUser.value.roles?.map(r => r.id_role) || []
  if (isAdmin.value) return []
  return managableRoles.value.filter(r => !userRoleIds.includes(r.id_role))
})

// Métodos
const loadUsers = async () => {
  try {
    await usersStore.fetchUsers()
  } catch (error) {
    console.error('Error cargando usuarios:', error)
    alert('Error al cargar usuarios')
  }
}

const loadRoles = async () => {
  try {
    const response = await getRoles()
    allRoles.value = response.data
  } catch (error) {
    console.error('Error cargando roles:', error)
  }
}

const filterUsers = () => {
  // Los computed ya manejan el filtrado
}

const openUserModal = () => {
  isEditing.value = false
  userForm.value = {
    full_name: '',
    email_user: '',
    password: '',
    initial_role: creatableRoles.value[0]?.id_role ?? ''
  }
  showUserModal.value = true
}

const editUser = (user) => {
  isEditing.value = true
  selectedUser.value = user
  userForm.value = {
    id_user: user.id_user,
    full_name: user.full_name,
    email_user: user.email_user,
    password: ''
  }
  showUserModal.value = true
}

const closeUserModal = () => {
  showUserModal.value = false
  isEditing.value = false
  selectedUser.value = null
}

const saveUser = async () => {
  // Validación de contraseña en el frontend antes de enviar
  if (!isEditing.value) {
    const pwd = userForm.value.password
    if (!pwd || pwd.length < 8) {
      alert('❌ La contraseña debe tener al menos 8 caracteres'); return
    }
    if (!/[A-Z]/.test(pwd)) {
      alert('❌ La contraseña debe contener al menos una LETRA MAYÚSCULA'); return
    }
    if (!/[a-z]/.test(pwd)) {
      alert('❌ La contraseña debe contener al menos una letra minúscula'); return
    }
    if (!/[0-9]/.test(pwd)) {
      alert('❌ La contraseña debe contener al menos un NÚMERO (0-9)'); return
    }
  }

  isSubmitting.value = true
  try {
    if (isEditing.value) {
      // Actualizar usuario
      await usersStore.updateUser(userForm.value.id_user, {
        full_name: userForm.value.full_name,
        email_user: userForm.value.email_user
      })
      await loadUsers()
      alert('Usuario actualizado exitosamente')
    } else {
      // Crear nuevo usuario
      await usersStore.createUser({
        email: userForm.value.email_user,
        password: userForm.value.password,
        full_name: userForm.value.full_name,
        id_role: parseInt(userForm.value.initial_role)
      })
      await loadUsers()
      alert('Usuario creado exitosamente')
    }
    closeUserModal()
  } catch (error) {
    console.error('❌ Error guardando usuario:', error)
    console.error('📋 Response data:', error.response?.data)
    console.error('📋 Response status:', error.response?.status)
    console.error('📋 Response headers:', error.response?.headers)
    
    const backendMessage = error.response?.data?.message
    const errorCode = error.response?.data?.error_code
    const genericMessage = error.message || 'Error desconocido al guardar usuario'
    
    let errorMessage = '❌ Error al crear usuario\n\n'
    if (backendMessage) {
      errorMessage += backendMessage
      if (errorCode) {
        errorMessage += `\n\nCódigo: ${errorCode}`
      }
    } else {
      errorMessage += genericMessage
    }
    
    alert(errorMessage)
  } finally {
    isSubmitting.value = false
  }
}

const manageRoles = (user) => {
  selectedUser.value = { ...user, roles: user.roles ?? [] }
  roleToAdd.value = ''
  showRolesModal.value = true
}

const closeRolesModal = () => {
  showRolesModal.value = false
  selectedUser.value = null
  roleToAdd.value = ''
}

const addRole = async () => {
  if (!roleToAdd.value) return

  const newRoleId = parseInt(roleToAdd.value)
  if (isAdmin.value || newRoleId === ADMIN_ROLE_ID) {
    alert('El rol Administrador es exclusivo y no puede combinarse con otros roles.')
    return
  }
  
  try {
    await usersStore.assignRole(selectedUser.value.id_user, newRoleId)
    await loadUsers()
    const found = usersStore.users.find(u => u.id_user === selectedUser.value.id_user)
    selectedUser.value = found ? { ...found, roles: found.roles ?? [] } : null
    roleToAdd.value = ''
    alert('Rol asignado exitosamente')
  } catch (error) {
    console.error('Error agregando rol:', error)
    alert(error.response?.data?.message || 'Error al agregar rol')
  }
}

const removeRole = async (roleId) => {
  if (selectedUser.value.roles.length === 1) {
    alert('No puedes eliminar el único rol del usuario')
    return
  }

  if (!confirm('¿Estás seguro de quitar este rol?')) return

  try {
    await usersStore.removeRole(selectedUser.value.id_user, roleId)
    await loadUsers()
    const found = usersStore.users.find(u => u.id_user === selectedUser.value.id_user)
    selectedUser.value = found ? { ...found, roles: found.roles ?? [] } : null
    alert('Rol eliminado exitosamente')
  } catch (error) {
    console.error('Error quitando rol:', error)
    alert(error.response?.data?.message || 'Error al quitar rol')
  }
}

const changePassword = (user) => {
  selectedUser.value = user
  newPassword.value = ''
  confirmPassword.value = ''
  showPasswordModal.value = true
}

const closePasswordModal = () => {
  showPasswordModal.value = false
  selectedUser.value = null
  newPassword.value = ''
  confirmPassword.value = ''
}

const updatePassword = async () => {
  if (newPassword.value !== confirmPassword.value) {
    alert('Las contraseñas no coinciden')
    return
  }

  if (newPassword.value.length < 8) {
    alert('La contraseña debe tener al menos 8 caracteres')
    return
  }

  isSubmitting.value = true
  try {
    await usersStore.changePassword(selectedUser.value.id_user, newPassword.value)
    await loadUsers() // Recargar lista para reflejar cambios
    closePasswordModal()
    alert('Contraseña actualizada exitosamente')
  } catch (error) {
    console.error('Error cambiando contraseña:', error)
    alert(error.response?.data?.message || 'Error al cambiar contraseña')
  } finally {
    isSubmitting.value = false
  }
}

const toggleStatus = async (user) => {
  const action = user.is_active ? 'desactivar' : 'activar'
  if (!confirm(`¿Estás seguro de ${action} este usuario?`)) return

  try {
    await usersStore.toggleUserStatus(user.id_user, !user.is_active)
    await loadUsers() // Recargar lista para reflejar cambios
    alert(`Usuario ${action}do exitosamente`)
  } catch (error) {
    console.error('Error cambiando estado:', error)
    alert(error.response?.data?.message || 'Error al cambiar estado del usuario')
  }
}

const getRoleClass = (roleId) => {
  const classes = {
    1: 'role-admin',
    2: 'role-driver',
    3: 'role-supervisor'
  }
  return classes[roleId] || ''
}

const getInitials = (name) => {
  if (!name) return '?'
  const parts = name.split(' ')
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase()
  }
  return name.substring(0, 2).toUpperCase()
}

const formatDate = (dateString) => {
  if (!dateString) return '-'
  const date = new Date(dateString)
  return date.toLocaleDateString('es-ES', { 
    year: 'numeric', 
    month: 'short', 
    day: 'numeric' 
  })
}

// Lifecycle
onMounted(() => {
  loadUsers()
  loadRoles()
})
</script>

<style scoped>
.users-section {
  padding: 20px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  gap: 20px;
  flex-wrap: wrap;
}

.header-stats {
  display: flex;
  gap: 15px;
  flex-wrap: wrap;
}

.stat-card {
  background: white;
  padding: 20px;
  border-radius: 12px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  min-width: 150px;
}

.stat-card h3 {
  font-size: 12px;
  color: #64748b;
  margin: 0 0 8px 0;
  font-weight: 500;
  text-transform: uppercase;
}

.stat-card span {
  font-size: 28px;
  font-weight: 700;
  color: #1e293b;
}

.role-passengers { color: #3b82f6; }
.role-drivers { color: #8b5cf6; }
.role-admins { color: #ef4444; }

.header-actions {
  display: flex;
  gap: 10px;
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

.btn.primary:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.btn.secondary {
  background: #f1f5f9;
  color: #475569;
}

.btn.secondary:hover {
  background: #e2e8f0;
}

.users-controls {
  background: white;
  padding: 20px;
  border-radius: 12px;
  margin-bottom: 20px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.search-filters {
  display: flex;
  gap: 15px;
  flex-wrap: wrap;
}

.search-input {
  flex: 1;
  min-width: 250px;
  padding: 12px 16px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
}

.filter-select {
  padding: 12px 16px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  cursor: pointer;
  background: white;
}

.users-table-container {
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.users-table {
  width: 100%;
  border-collapse: collapse;
}

.users-table thead {
  background: #f8fafc;
  border-bottom: 2px solid #e2e8f0;
}

.users-table th {
  padding: 16px;
  text-align: left;
  font-weight: 600;
  color: #475569;
  font-size: 13px;
  text-transform: uppercase;
}

.users-table tbody tr {
  border-bottom: 1px solid #f1f5f9;
  transition: background 0.2s;
}

.users-table tbody tr:hover {
  background: #f8fafc;
}

.users-table td {
  padding: 16px;
  color: #334155;
}

.user-id-cell {
  text-align: center;
  font-weight: 600;
  color: #94a3b8;
  font-size: 13px;
  min-width: 50px;
}

.user-cell {
  min-width: 200px;
}

.user-info-compact {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-avatar-small {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 600;
  font-size: 14px;
  flex-shrink: 0;
  overflow: hidden;
}

.user-avatar-small img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.user-name-col {
  display: flex;
  flex-direction: column;
}

.user-name-col .name {
  font-weight: 600;
  color: #1e293b;
}

.roles-cell {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.role-badge-small {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
}

.role-passenger {
  background: #dbeafe;
  color: #1e40af;
}

.role-driver {
  background: #ede9fe;
  color: #6b21a8;
}

.role-supervisor {
  background: #fef3c7;
  color: #92400e;
}

.role-admin {
  background: #fee2e2;
  color: #991b1b;
}

.status-badge-small {
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}

.status-badge-small.active {
  background: #d1fae5;
  color: #065f46;
}

.status-badge-small.inactive {
  background: #fee2e2;
  color: #991b1b;
}

.actions-cell {
  display: flex;
  gap: 8px;
}

.btn-icon {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 18px;
  padding: 8px;
  border-radius: 6px;
  transition: all 0.2s;
}

.btn-icon:hover {
  background: #f1f5f9;
  transform: scale(1.1);
}

.empty-state {
  padding: 60px 20px;
  text-align: center;
  color: #94a3b8;
}

/* Modales */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 20px;
}

.modal-content {
  background: white;
  border-radius: 16px;
  max-width: 600px;
  width: 100%;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
}

.modal-content.modal-medium {
  max-width: 500px;
}

.modal-content.modal-small {
  max-width: 400px;
}

.modal-header {
  padding: 24px;
  border-bottom: 1px solid #e2e8f0;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-header h2 {
  margin: 0;
  font-size: 20px;
  color: #1e293b;
}

.btn-close {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: #94a3b8;
  padding: 0;
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}

.btn-close:hover {
  background: #f1f5f9;
  color: #475569;
}

.modal-body {
  padding: 24px;
}

.form-row {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
  margin-bottom: 16px;
}

.form-group {
  display: flex;
  flex-direction: column;
}

.form-group.full-width {
  grid-column: 1 / -1;
}

.form-group label {
  margin-bottom: 8px;
  font-weight: 600;
  color: #475569;
  font-size: 14px;
}

.form-group input,
.form-group select {
  padding: 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
}

.form-group input:focus,
.form-group select:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-hint {
  margin-top: 4px;
  font-size: 12px;
  color: #64748b;
}

.form-actions {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
  margin-top: 24px;
  padding-top: 24px;
  border-top: 1px solid #e2e8f0;
}

.roles-management {
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.roles-management h3 {
  font-size: 14px;
  color: #475569;
  margin: 0 0 12px 0;
  text-transform: uppercase;
  font-weight: 600;
}

.roles-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.role-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px;
  background: #f8fafc;
  border-radius: 8px;
}

.role-badge {
  padding: 6px 14px;
  border-radius: 14px;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
}

.btn-icon-small {
  background: none;
  border: none;
  cursor: pointer;
  color: #94a3b8;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 14px;
}

.btn-icon-small:hover:not(:disabled) {
  background: #e2e8f0;
  color: #ef4444;
}

.btn-icon-small:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}

.empty-roles {
  color: #94a3b8;
  font-style: italic;
  padding: 20px;
  text-align: center;
}

.add-role-form {
  display: flex;
  gap: 12px;
}

.role-select {
  flex: 1;
  padding: 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
}

.primary-small {
  padding: 12px 20px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
}

.primary-small:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.primary-small:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

@media (max-width: 768px) {
  .section-header {
    flex-direction: column;
    align-items: stretch;
  }

  .header-stats {
    flex-direction: column;
  }

  .stat-card {
    min-width: auto;
  }

  .users-table-container {
    overflow-x: auto;
  }

  .form-row {
    grid-template-columns: 1fr;
  }
}
.role-tag-mini {
  font-size: 9px;
  padding: 1px 4px;
  border-radius: 4px;
  font-weight: 600;
  text-transform: uppercase;
}

.user-meta-mobile {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.roles-inline {
  display: flex;
  gap: 4px;
  flex-wrap: wrap;
}

/* Responsive */
@media (max-width: 768px) {
  .users-section { padding: 10px; }
  
  .section-header {
    margin-bottom: 12px;
    gap: 8px;
  }

  .header-stats {
    display: grid;
    grid-template-columns: repeat(4, 1fr); /* 4 columnas para que sean muy pequeñas */
    gap: 6px;
    width: 100%;
  }

  .stat-card {
    min-width: 0;
    padding: 8px 4px;
    text-align: center;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    box-shadow: none;
  }

  .stat-card h3 { font-size: 8px; margin-bottom: 2px; color: #94a3b8; }
  .stat-card span { font-size: 14px; font-weight: 800; }

  .header-actions { width: 100%; }
  .header-actions .btn { 
    width: 100%; 
    justify-content: center; 
    padding: 8px; 
    font-size: 13px; 
    border-radius: 6px;
  }

  .users-controls { padding: 0; margin-bottom: 12px; background: transparent; box-shadow: none; }
  .search-filters {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .search-input { width: 100%; padding: 8px 12px; font-size: 14px; border-radius: 6px; }
  
  .filter-select-group {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 6px;
  }

  .filter-select { padding: 8px; font-size: 12px; border-radius: 6px; }

  .mobile-hidden { display: none !important; }
  .mobile-only { display: flex; }

  .users-table-container { background: transparent; box-shadow: none; overflow: visible; }
  .users-table, .users-table tbody, .users-table tr { display: block; width: 100%; }
  
  .user-row {
    display: flex !important;
    align-items: center;
    padding: 10px 0;
    background: white;
    border-bottom: 1px solid #f1f5f9;
    gap: 10px;
  }

  .users-table td { padding: 0 !important; border: none !important; }

  .user-cell { flex: 1; min-width: 0; }
  .user-info-compact { gap: 8px; }
  .user-avatar-small { width: 36px; height: 36px; font-size: 14px; background: #667eea; color: white; border-radius: 10px; }
  .user-name-col .name { font-size: 14px; color: #1e293b; }
  .email-sub { font-size: 11px; color: #94a3b8; }

  .status-cell-wrapper { width: 16px; display: flex; justify-content: center; margin-right: 4px; }
  .status-dot-user { width: 8px; height: 8px; }

  .actions-cell-wrapper { width: auto; }
  .actions-cell { gap: 4px; }
  .btn-icon { width: 34px; height: 34px; font-size: 14px; background: #f8fafc; border: 1px solid #f1f5f9; border-radius: 8px; }
}
</style>

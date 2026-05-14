<template>
  <header id="main-header">
    <div class="header-left">
      <button id="sidebar-toggle" class="sidebar-toggle" @click="toggleSidebar">
        <span class="hamburger"></span>
      </button>
      <div class="logo" @click="router.push('/')" style="cursor:pointer">
        <h1>🚌 BucaraBus</h1>
      </div>
    </div>

    <div class="header-right">
      <div class="header-stats">
        <div class="stat-pill active">
          <span class="stat-icon">🚌</span>
          <span class="stat-value" id="buses-active">{{ activeBusesCount }}</span>
          <span class="stat-label">Activos</span>
        </div>
        <div class="stat-pill routes">
          <span class="stat-icon">🛣️</span>
          <span class="stat-value" id="routes-total">{{ totalRoutesCount }}</span>
          <span class="stat-label">Rutas</span>
        </div>
        <div class="stat-pill alerts">
          <span class="stat-icon">🚨</span>
          <span class="stat-value" id="alerts-count">3</span>
          <span class="stat-label">Alertas</span>
        </div>
      </div>

      <div class="user-menu">
        <button id="notifications-btn" class="icon-btn">
          <span class="notification-icon">🔔</span>
          <span class="notification-badge">3</span>
        </button>
        <div class="user-info">
          <div class="user-avatar">{{ userAvatar }}</div>
          <div class="user-details">
            <span id="current-user">{{ userName }}</span>
            
            <!-- Dropdown de roles si tiene múltiples roles -->
            <div v-if="hasMultipleRoles" class="role-selector">
              <button class="current-role-btn" @click="toggleRoleDropdown">
                <span class="role-text">{{ currentRoleName }}</span>
                <span class="dropdown-arrow">▼</span>
              </button>
              
              <!-- Dropdown de roles -->
              <div v-if="showRoleDropdown" class="role-dropdown">
                <div class="role-dropdown-header">🔄 Cambiar Vista</div>
                <button
                  v-for="role in availableRoles"
                  :key="role.id_role"
                  @click="handleRoleSwitch(role)"
                  class="role-option"
                  :class="{ active: isActiveRole(role) }"
                >
                  <span class="role-icon">{{ getRoleIcon(role.id_role) }}</span>
                  <span class="role-name">{{ role.role_name || getRoleNameById(role.id_role) }}</span>
                  <span v-if="isActiveRole(role)" class="active-badge">✔</span>
                </button>
              </div>
            </div>
            
            <!-- Rol simple si solo tiene uno -->
            <span v-else class="user-role">{{ userRole }}</span>
          </div>
          <button id="logout-btn" class="logout-btn" @click="handleLogout">
            🚪 Salir
          </button>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAppStore } from '../stores/app'
import { useAuthStore } from '../stores/auth'
import { useBusesStore } from '../stores/buses'
import { useRoutesStore } from '../stores/routes'

const router = useRouter()
const appStore = useAppStore()
const authStore = useAuthStore()
const busesStore = useBusesStore()
const routesStore = useRoutesStore()

// Estado local
const showRoleDropdown = ref(false)

// Getters computados - Usuario
const userName = computed(() => authStore.userName)
const userRole = computed(() => {
  const role = authStore.userRole
  const roleNames = {
    'admin': 'Administrador',
    'driver': 'Conductor',
    'passenger': 'Pasajero',
    'guest': 'Invitado'
  }
  return roleNames[role] || role
})
const userAvatar = computed(() => authStore.userAvatar)
const hasMultipleRoles = computed(() => authStore.hasMultipleRoles)
const availableRoles = computed(() => authStore.availableRoles)
const currentRoleName = computed(() => {
  const role = authStore.userRole
  return authStore.getRoleName(role)
})

// Getters computados - Stats
const activeBusesCount = computed(() => {
  try {
    return busesStore.activeBuses?.length || 0
  } catch (e) {
    return 0
  }
})
const totalRoutesCount = computed(() => {
  try {
    return routesStore.routesCount || 0
  } catch (e) {
    return 0
  }
})

// Métodos
const toggleSidebar = () => {
  appStore.toggleSidebar()
}

const handleLogout = async () => {
  if (confirm('¿Estás seguro de que deseas cerrar sesión?')) {
    await authStore.logout()
    router.push('/login')
  }
}

const toggleRoleDropdown = () => {
  showRoleDropdown.value = !showRoleDropdown.value
}

const isActiveRole = (role) => {
  const roleKey = authStore.roleIdToKey(role.id_role)
  return roleKey === authStore.userRole
}

const handleRoleSwitch = async (role) => {
  const roleKey = authStore.roleIdToKey(role.id_role)
  
  // Cambiar rol en el store
  const result = authStore.switchRole(roleKey)
  
  if (result.success) {
    showRoleDropdown.value = false
    
    // Redirigir según el nuevo rol
    let redirectPath = '/monitor' // Default
    if (roleKey === 'driver') {
      redirectPath = '/conductor'
    } else if (roleKey === 'passenger') {
      redirectPath = '/pasajero'
    } else if (roleKey === 'supervisor' || roleKey === 'admin') {
      redirectPath = '/monitor'
    }
    
    console.log(`🔄 Cambiando a rol ${roleKey}, redirigiendo a ${redirectPath}`)
    router.push(redirectPath)
  }
}

const getRoleIcon = (id_role) => {
  const icons = {
    4: '👨‍💼', // Admin
    3: '👨‍🏫', // Supervisor
    2: '👨‍✈️', // Conductor
    1: '👤'  // Pasajero
  }
  return icons[id_role] || '👤'
}

const getRoleNameById = (id_role) => {
  const names = {
    4: 'Administrador',
    3: 'Supervisor',
    2: 'Conductor',
    1: 'Pasajero'
  }
  return names[id_role] || 'Usuario'
}

// Cerrar dropdown al hacer click fuera
const handleClickOutside = (event) => {
  const roleSelector = document.querySelector('.role-selector')
  if (roleSelector && !roleSelector.contains(event.target)) {
    showRoleDropdown.value = false
  }
}

// Agregar listener para cerrar dropdown
onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped>
/* Header styles - migrated from original CSS */
#main-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  color: white;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  z-index: 1000;
  position: relative;
  height: 70px;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 15px;
  flex: 0 0 auto;
}

.sidebar-toggle {
  background: rgba(255, 255, 255, 0.15);
  border: none;
  width: 40px;
  height: 40px;
  border-radius: 8px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
}

.sidebar-toggle:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: scale(1.05);
}

.hamburger {
  width: 18px;
  height: 2px;
  background: white;
  position: relative;
  transition: all 0.3s ease;
}

.hamburger::before,
.hamburger::after {
  content: '';
  position: absolute;
  width: 18px;
  height: 2px;
  background: white;
  transition: all 0.3s ease;
}

.hamburger::before { top: -6px; }
.hamburger::after { bottom: -6px; }

.logo h1 {
  font-size: 24px;
  font-weight: 700;
  margin: 0;
  background: linear-gradient(45deg, #fff, #f0f8ff);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 20px;
  flex: 0 0 auto;
}

.header-stats {
  display: flex;
  gap: 15px;
}

.stat-pill {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px 12px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 10px;
  min-width: 70px;
  backdrop-filter: blur(10px);
  transition: all 0.2s ease;
}

.stat-pill:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: translateY(-2px);
}

.stat-pill.active { border: 2px solid #10b981; }
.stat-pill.routes { border: 2px solid #3b82f6; }
.stat-pill.alerts { border: 2px solid #f59e0b; }

.stat-icon { font-size: 16px; margin-bottom: 2px; }
.stat-value { font-size: 18px; font-weight: bold; line-height: 1; }
.stat-label { font-size: 10px; opacity: 0.8; }

.user-menu {
  display: flex;
  align-items: center;
  gap: 15px;
}

.icon-btn {
  position: relative;
  background: rgba(255, 255, 255, 0.15);
  border: none;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  color: white;
  cursor: pointer;
  transition: all 0.2s ease;
}

.icon-btn:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: scale(1.05);
}

.notification-badge {
  position: absolute;
  top: -5px;
  right: -5px;
  background: #ef4444;
  color: white;
  font-size: 10px;
  font-weight: bold;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 16px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 30px;
  backdrop-filter: blur(10px);
}

.user-avatar {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.3rem;
  flex-shrink: 0;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

.user-details {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.user-details span {
  font-size: 13px;
  font-weight: 500;
  line-height: 1.2;
}

.user-role {
  font-size: 11px !important;
  opacity: 0.8;
  font-weight: 400 !important;
}

/* Role Selector Dropdown */
.role-selector {
  position: relative;
}

.current-role-btn {
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: white;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 11px;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
  transition: all 0.2s ease;
  font-weight: 500;
}

.current-role-btn:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: scale(1.02);
}

.role-text {
  opacity: 0.9;
}

.dropdown-arrow {
  font-size: 8px;
  opacity: 0.7;
  transition: transform 0.2s;
}

.role-dropdown {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  background: white;
  border-radius: 12px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.2);
  min-width: 200px;
  z-index: 1000;
  overflow: hidden;
  animation: slideDown 0.2s ease;
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.role-dropdown-header {
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  padding: 10px 15px;
  font-size: 12px;
  font-weight: 600;
  text-align: center;
}

.role-option {
  width: 100%;
  background: white;
  border: none;
  padding: 12px 15px;
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  transition: all 0.2s ease;
  border-bottom: 1px solid #f0f0f0;
  color: #1e293b;
  font-size: 13px;
}

.role-option:last-child {
  border-bottom: none;
}

.role-option:hover {
  background: #f8fafc;
}

.role-option.active {
  background: linear-gradient(135deg, rgba(102, 126, 234, 0.1), rgba(118, 75, 162, 0.1));
  border-left: 3px solid #667eea;
}

.role-icon {
  font-size: 16px;
  flex-shrink: 0;
}

.role-name {
  flex: 1;
  text-align: left;
  font-weight: 500;
}

.active-badge {
  color: #10b981;
  font-size: 12px;
  font-weight: bold;
}

.logout-btn {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  padding: 6px 12px;
  border-radius: 15px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.2s ease;
  font-weight: 500;
}

.logout-btn:hover {
  background: rgba(255, 255, 255, 0.4);
  transform: scale(1.05);
}

/* Responsive */
@media (max-width: 768px) {
  .header-stats {
    display: none;
  }

  .logo h1 {
    font-size: 18px;
  }

  .user-details {
    display: none;
  }

  .user-info {
    padding: 6px;
  }
}
</style>
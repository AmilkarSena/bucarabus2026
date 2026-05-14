<template>
  <nav id="sidebar" class="sidebar" :class="{ open: isOpen, 'initial-load': showAnimations }">
    <div class="sidebar-content">
      <ul class="nav-menu">
        <li
          v-for="item in navItems"
          :key="item.id"
          class="nav-item"
          :class="{ 'has-submenu': item.submenu }"
        >
          <!-- Item sin submenú -->
          <router-link
            v-if="!item.submenu"
            :to="item.route"
            class="nav-link"
            :class="{ active: isActiveRoute(item.id) }"
            @click="handleNavClick"
          >
            <span class="nav-icon">{{ item.icon }}</span>
            <span class="nav-label">{{ item.label }}</span>
          </router-link>

          <!-- Item con submenú -->
          <template v-else>
            <div
              class="nav-link"
              :class="{ active: isActiveSection(item.id), expanded: expandedMenus.includes(item.id) }"
              @click="toggleSubmenu(item.id)"
            >
              <span class="nav-icon">{{ item.icon }}</span>
              <span class="nav-label">{{ item.label }}</span>
              <span class="submenu-arrow">{{ expandedMenus.includes(item.id) ? '▼' : '▶' }}</span>
            </div>
            <ul class="submenu" v-show="expandedMenus.includes(item.id)">
              <li
                v-for="subitem in item.submenu"
                :key="subitem.id"
                class="submenu-item"
              >
                <router-link
                  :to="subitem.route"
                  class="submenu-link"
                  :class="{ active: isActiveRoute(subitem.id) }"
                  @click="handleNavClick"
                >
                  <span class="submenu-icon">{{ subitem.icon }}</span>
                  <span class="submenu-label">{{ subitem.label }}</span>
                </router-link>
              </li>
            </ul>
          </template>
        </li>
      </ul>
    </div>
  </nav>
</template>

<script setup>
import { computed, ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useAppStore } from '../stores/app'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const appStore = useAppStore()
const authStore = useAuthStore()

// Estado local
const expandedMenus = ref(['fleet']) // 'fleet' expandido por defecto
const showAnimations = ref(false)

// Estado computado
const isOpen = computed(() => appStore.sidebarOpen)

// Activar animaciones solo en montaje inicial
onMounted(() => {
  // Pequeño delay para que las animaciones se vean suaves
  setTimeout(() => {
    showAnimations.value = true
  }, 50)
})

// Definición de ítems con sus permisos requeridos
// permissions: null = siempre visible | Array = visible si tiene al menos uno
const ALL_NAV_ITEMS = [
  { id: 'monitor', route: '/monitor', icon: '📍', label: 'Monitor Live', permissions: null },
  { 
    id: 'fleet', 
    icon: '🚌', 
    label: 'Gestión de Flota',
    permissions: ['VIEW_BUSES', 'CREATE_BUSES', 'EDIT_BUSES', 'DELETE_BUSES'],
    submenu: [
      { id: 'buses', route: '/fleet', icon: '🚌', label: 'Buses' },
      { id: 'assign-driver', route: '/fleet/assign-driver', icon: '👨‍✈️', label: 'Asignar Conductor' }
    ]
  },
  { 
    id: 'drivers', route: '/drivers', icon: '👤', label: 'Conductores',
    permissions: ['VIEW_DRIVERS', 'CREATE_DRIVERS', 'EDIT_DRIVERS', 'DELETE_DRIVERS']
  },
  { 
    id: 'routes', route: '/routes', icon: '🛣️', label: 'Rutas',
    permissions: ['VIEW_ROUTES', 'CREATE_ROUTES', 'EDIT_ROUTES', 'DELETE_ROUTES', 'VIEW_STOPS', 'CREATE_STOPS', 'EDIT_STOPS']
  },
  { 
    id: 'shifts', route: '/shifts', icon: '⏰', label: 'Turnos',
    permissions: ['VIEW_TRIPS', 'CREATE_TRIPS', 'ASSIGN_TRIPS', 'CANCEL_TRIPS']
  },
  { 
    id: 'users', 
    icon: '👥', 
    label: 'Usuarios',
    permissions: ['MANAGE_USERS', 'CREATE_USERS', 'EDIT_USERS'],
    submenu: [
      { id: 'user-list',         route: '/users',                  icon: '👥', label: 'Lista de Usuarios' },
      { id: 'permissions',       route: '/users/permissions',       icon: '🔐', label: 'Permisos por Rol' },
      { id: 'user-permissions',  route: '/users/user-permissions',  icon: '🧩', label: 'Permisos por Usuario' }
    ]
  },
  { 
    id: 'catalogs', route: '/catalogs', icon: '🗂️', label: 'Catálogos',
    permissions: ['CREATE_CATALOGS', 'EDIT_CATALOGS', 'TOGGLE_CATALOGS']
  },
  { id: 'alerts', route: '/alerts', icon: '🚨', label: 'Alertas', permissions: null },
  { id: 'settings', route: '/settings', icon: '⚙️', label: 'Configuración', permissions: null }
]

// Items filtrados por permisos del usuario actual
const navItems = computed(() => {
  return ALL_NAV_ITEMS.filter(item => {
    if (!item.permissions) return true // siempre visible
    return authStore.canAny(item.permissions)
  })
})

// Métodos
const isActiveRoute = (itemId) => {
  return route.meta.section === itemId
}

const isActiveSection = (sectionId) => {
  // Buscar en ALL_NAV_ITEMS (no en el computed filtrado) para evitar errores de ref
  const item = ALL_NAV_ITEMS.find(i => i.id === sectionId)
  if (item && item.submenu) {
    return item.submenu.some(sub => route.meta.section === sub.id)
  }
  return false
}

const toggleSubmenu = (menuId) => {
  const index = expandedMenus.value.indexOf(menuId)
  if (index > -1) {
    expandedMenus.value.splice(index, 1)
  } else {
    expandedMenus.value.push(menuId)
  }
}

const handleNavClick = () => {
  // Cerrar sidebar en móvil
  if (window.innerWidth <= 768) {
    appStore.toggleSidebar()
  }
}

defineEmits(['toggle'])
</script>

<style scoped>
/* Sidebar styles - migrated from original CSS */
.sidebar {
  background: #ffffff;
  border-right: 1px solid #e2e8f0;
  overflow: hidden;
  transition: all 0.3s ease;
  z-index: 900;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  width: 260px;
  position: relative;
}

.sidebar-content {
  height: 100%;
  padding: 20px 0;
}

.nav-menu {
  list-style: none;
  margin: 0;
  padding: 0;
}

.nav-item {
  margin: 2px 10px;
}

.nav-link {
  display: flex;
  align-items: center;
  padding: 15px 20px;
  cursor: pointer;
  transition: all 0.2s ease;
  position: relative;
  border-radius: 10px;
  user-select: none;
  text-decoration: none;
  color: inherit;
}

.nav-link:hover {
  background: #f1f5f9;
  transform: translateX(5px);
}

.nav-link.active {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.nav-link.active::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 4px;
  background: white;
  border-radius: 0 2px 2px 0;
}

.nav-link.expanded {
  background: #f8fafc;
}

.submenu-arrow {
  margin-left: auto;
  font-size: 10px;
  transition: transform 0.3s ease;
  color: #64748b;
}

.submenu {
  list-style: none;
  margin: 4px 0 8px 0;
  padding: 0;
  animation: slideDown 0.3s ease-out;
}

.submenu-item {
  margin: 2px 10px 2px 20px;
}

.submenu-link {
  display: flex;
  align-items: center;
  padding: 12px 20px;
  cursor: pointer;
  transition: all 0.2s ease;
  border-radius: 8px;
  user-select: none;
  text-decoration: none;
  color: #64748b;
  font-size: 13px;
}

.submenu-link:hover {
  background: #f1f5f9;
  color: #1e293b;
  transform: translateX(3px);
}

.submenu-link.active {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  box-shadow: 0 2px 4px rgba(102, 126, 234, 0.3);
}

.submenu-icon {
  font-size: 14px;
  margin-right: 12px;
  width: 20px;
  text-align: center;
}

.submenu-label {
  font-weight: 500;
}

.nav-icon {
  font-size: 18px;
  margin-right: 15px;
  width: 24px;
  text-align: center;
  transition: all 0.3s ease;
}

.nav-label {
  font-weight: 500;
  font-size: 14px;
  transition: all 0.3s ease;
  white-space: nowrap;
  opacity: 1;
  flex: 1;
}

/* Mobile styles */
@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    left: -100%;
    top: 70px;
    bottom: 50px;
    width: 280px;
    transition: left 0.3s ease;
  }

  .sidebar.open {
    left: 0;
  }
}

/* Collapsed sidebar styles */
.sidebar.collapsed {
  width: 60px;
}

.sidebar.collapsed .nav-label {
  opacity: 0;
  width: 0;
  overflow: hidden;
}

.sidebar.collapsed .nav-link {
  justify-content: center;
  padding: 15px;
}

.sidebar.collapsed .nav-icon {
  margin-right: 0;
}

/* Animations - solo durante carga inicial */
.sidebar.initial-load .nav-link {
  animation: slideInLeft 0.3s ease-out;
}

.sidebar.initial-load .nav-item:nth-child(1) .nav-link { animation-delay: 0.05s; }
.sidebar.initial-load .nav-item:nth-child(2) .nav-link { animation-delay: 0.1s; }
.sidebar.initial-load .nav-item:nth-child(3) .nav-link { animation-delay: 0.15s; }
.sidebar.initial-load .nav-item:nth-child(4) .nav-link { animation-delay: 0.2s; }
.sidebar.initial-load .nav-item:nth-child(5) .nav-link { animation-delay: 0.25s; }
.sidebar.initial-load .nav-item:nth-child(6) .nav-link { animation-delay: 0.3s; }
.sidebar.initial-load .nav-item:nth-child(7) .nav-link { animation-delay: 0.35s; }
.sidebar.initial-load .nav-item:nth-child(8) .nav-link { animation-delay: 0.4s; }
.sidebar.initial-load .nav-item:nth-child(9) .nav-link { animation-delay: 0.45s; }

@keyframes slideInLeft {
  from {
    opacity: 0;
    transform: translateX(-20px);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

@keyframes slideDown {
  from {
    opacity: 0;
    max-height: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    max-height: 500px;
    transform: translateY(0);
  }
}
</style>
<template>
  <header class="app-header">
    <div class="header-left">
      <button class="btn-menu" @click="$emit('open-menu')">☰</button>
      <div class="driver-info">
        <span class="driver-avatar">👨‍✈️</span>
        <div class="driver-details">
          <span class="driver-name">{{ driverName }}</span>
          <span class="driver-bus">🚌 {{ busPlate }}</span>
        </div>
      </div>
    </div>
    
    <!-- User Menu -->
    <div class="user-menu-container" v-if="isAuthenticated">
      <button class="user-menu-btn" @click="showUserMenu = !showUserMenu">
        <span class="user-avatar">{{ userAvatar }}</span>
        <span class="menu-arrow">▼</span>
      </button>
      
      <!-- Dropdown Menu -->
      <div v-if="showUserMenu" class="user-dropdown">
        <!-- User Info -->
        <div class="dropdown-header">
          <div class="dropdown-avatar">{{ userAvatar }}</div>
          <div class="dropdown-info">
            <div class="dropdown-name">{{ userName }}</div>
            <div class="dropdown-role">{{ roleName }}</div>
          </div>
        </div>
        
        <!-- Logout -->
        <div class="dropdown-section">
          <button @click="$emit('logout')" class="btn-logout-menu">
            <span>🚪</span> Cerrar sesión
          </button>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const props = defineProps({
  driverName: { type: String, default: '' },
  busPlate: { type: String, default: '' },
  isAuthenticated: { type: Boolean, default: false },
  userAvatar: { type: String, default: '👤' },
  userName: { type: String, default: '' },
  roleName: { type: String, default: 'Conductor' }
})

defineEmits(['logout', 'open-menu'])

const showUserMenu = ref(false)

// Close user menu when clicking outside
const handleClickOutside = (event) => {
  const userMenu = event.target.closest('.user-menu-container')
  if (!userMenu) {
    showUserMenu.value = false
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<style scoped>
.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  background: #1e293b;
  border-bottom: 1px solid #334155;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}

.btn-menu {
  background: none;
  border: none;
  color: white;
  font-size: 1.5rem;
  cursor: pointer;
  padding: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.driver-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.driver-avatar {
  font-size: 32px;
}

.driver-details {
  display: flex;
  flex-direction: column;
}

.driver-name {
  font-weight: 600;
  font-size: 14px;
}

.driver-bus {
  font-size: 12px;
  color: #94a3b8;
}

/* User Menu */
.user-menu-container {
  position: relative;
}

.user-menu-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 12px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 20px;
  color: white;
  cursor: pointer;
  transition: all 0.2s;
}

.user-menu-btn:hover {
  background: rgba(255, 255, 255, 0.15);
}

.user-avatar {
  font-size: 1.2rem;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.menu-arrow {
  font-size: 0.7rem;
  margin-left: 2px;
}

/* Dropdown */
.user-dropdown {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  background: white;
  border-radius: 12px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
  min-width: 240px;
  overflow: hidden;
  z-index: 2000;
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

.dropdown-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.dropdown-avatar {
  font-size: 2rem;
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 50%;
}

.dropdown-info {
  flex: 1;
}

.dropdown-name {
  font-weight: 600;
  font-size: 1rem;
  margin-bottom: 2px;
  color: white;
}

.dropdown-role {
  font-size: 0.85rem;
  opacity: 0.9;
}

.dropdown-section {
  padding: 8px 0;
  border-top: 1px solid #eee;
}

.dropdown-section:first-child {
  border-top: none;
}

.btn-logout-menu {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 16px;
  background: white;
  border: none;
  color: #f44336;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s;
}

.btn-logout-menu:hover {
  background: #ffebee;
}
</style>

<template>
  <div>
    <!-- Overlay -->
    <Transition name="fade">
      <div v-if="isOpen" class="menu-overlay" @click="closeMenu"></div>
    </Transition>

    <!-- Menú Lateral -->
    <Transition name="slide">
      <div v-if="isOpen" class="side-menu">
        <div class="menu-header">
          <div class="logo">
            <span class="logo-icon">👨‍✈️</span>
            <h2>Conductor</h2>
          </div>
          <button class="btn-close" @click="closeMenu">✕</button>
        </div>

        <nav class="menu-nav">
          <a 
            href="#" 
            class="nav-item" 
            :class="{ active: currentView === 'home' }"
            @click.prevent="navigate('home')"
          >
            <span class="icon">🗺️</span>
            Mi Turno (Mapa)
          </a>
          <a 
            href="#" 
            class="nav-item" 
            :class="{ active: currentView === 'calendar' }"
            @click.prevent="navigate('calendar')"
          >
            <span class="icon">📅</span>
            Calendario de Viajes
          </a>
        </nav>

        <div class="menu-footer">
          <p class="app-version">BucaraBus Driver v1.0.0</p>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup>
defineProps({
  isOpen: { type: Boolean, default: false },
  currentView: { type: String, default: 'home' }
})

const emit = defineEmits(['update:isOpen', 'navigate'])

const closeMenu = () => emit('update:isOpen', false)

const navigate = (view) => {
  emit('navigate', view)
  closeMenu()
}
</script>

<style scoped>
.menu-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.6);
  z-index: 3000;
  backdrop-filter: blur(2px);
}

.side-menu {
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  width: 280px;
  background: #1e293b;
  color: white;
  z-index: 3001;
  display: flex;
  flex-direction: column;
  box-shadow: 4px 0 20px rgba(0, 0, 0, 0.3);
}

.menu-header {
  padding: 24px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #334155;
}

.logo {
  display: flex;
  align-items: center;
  gap: 12px;
}

.logo-icon {
  font-size: 1.8rem;
}

.logo h2 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 700;
  color: #f8fafc;
}

.btn-close {
  background: rgba(255, 255, 255, 0.1);
  border: none;
  font-size: 1.1rem;
  color: #cbd5e1;
  cursor: pointer;
  padding: 8px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.btn-close:hover {
  background: rgba(255, 255, 255, 0.2);
  color: white;
}

.menu-nav {
  flex: 1;
  padding: 20px 12px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 14px 16px;
  text-decoration: none;
  color: #cbd5e1;
  font-weight: 600;
  font-size: 1.05rem;
  border-radius: 12px;
  transition: all 0.2s ease;
}

.nav-item .icon {
  font-size: 1.25rem;
  opacity: 0.8;
}

.nav-item:hover {
  background: rgba(255, 255, 255, 0.05);
  color: white;
}

.nav-item.active {
  background: rgba(34, 197, 94, 0.15); /* Verde BucaraBus */
  color: #4ade80;
}

.nav-item.active .icon {
  opacity: 1;
}

.menu-footer {
  padding: 20px;
  border-top: 1px solid #334155;
  text-align: center;
}

.app-version {
  margin: 0;
  font-size: 0.85rem;
  color: #64748b;
}

/* Animaciones */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.slide-enter-active,
.slide-leave-active {
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

.slide-enter-from,
.slide-leave-to {
  transform: translateX(-100%);
}
</style>

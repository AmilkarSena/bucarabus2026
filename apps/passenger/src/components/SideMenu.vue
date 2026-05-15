<template>
  <div>
    <!-- Overlay (fondo oscuro) -->
    <Transition name="fade">
      <div v-if="isOpen" class="menu-overlay" @click="closeMenu"></div>
    </Transition>

    <!-- Menú Lateral -->
    <Transition name="slide">
      <div v-if="isOpen" class="side-menu">
        <div class="menu-header">
          <div class="logo">
            <span class="logo-icon">🚌</span>
            <h2>BucaraBus</h2>
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
            Viajar (Mapa)
          </a>
          <a 
            href="#" 
            class="nav-item" 
            :class="{ active: currentView === 'catalog' }"
            @click.prevent="navigate('catalog')"
          >
            <span class="icon">📖</span>
            Catálogo de Rutas
          </a>

          <!-- Botón PWA Condicional -->
          <a 
            v-if="isInstallable"
            href="#" 
            class="nav-item pwa-btn" 
            @click.prevent="installPWA"
          >
            <span class="icon">⬇️</span>
            Instalar App
          </a>
        </nav>

        <div class="menu-footer">
          <p class="app-version">Pasajero v1.0.0</p>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { usePWAInstall } from '../composables/usePWAInstall.js'

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

// Lógica de PWA
const { isInstallable, installPWA } = usePWAInstall()
</script>

<style scoped>
.menu-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 2000;
  backdrop-filter: blur(2px);
}

.side-menu {
  position: fixed;
  top: 0;
  left: 0;
  bottom: 0;
  width: 280px;
  background: white;
  z-index: 2001;
  display: flex;
  flex-direction: column;
  box-shadow: 4px 0 20px rgba(0, 0, 0, 0.15);
}

.menu-header {
  padding: 24px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #f3f4f6;
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
  color: #1f2937;
}

.btn-close {
  background: none;
  border: none;
  font-size: 1.25rem;
  color: #6b7280;
  cursor: pointer;
  padding: 8px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s;
}

.btn-close:hover {
  background: #f3f4f6;
  color: #1f2937;
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
  color: #4b5563;
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
  background: #f3f4f6;
  color: #1f2937;
}

.nav-item.active {
  background: #eef2ff;
  color: #4f46e5;
}

.nav-item.active .icon {
  opacity: 1;
}

/* Estilo sutil para el botón PWA */
.pwa-btn {
  margin-top: 12px;
  background-color: #f0fdf4;
  color: #166534;
  border: 1px dashed #bbf7d0;
}

.pwa-btn:hover {
  background-color: #dcfce7;
  color: #15803d;
}

.menu-footer {
  padding: 20px;
  border-top: 1px solid #f3f4f6;
  text-align: center;
}

.app-version {
  margin: 0;
  font-size: 0.85rem;
  color: #9ca3af;
}

/* Transiciones */
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

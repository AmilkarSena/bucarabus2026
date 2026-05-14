<template>
  <div class="map-layout">
    <!-- HEADER PRINCIPAL -->
    <AppHeader />

    <!-- LAYOUT CON MAPA -->
    <div class="main-layout" :class="{ 'sidebar-collapsed': sidebarCollapsed }">
      <!-- SIDEBAR NAVEGACIÓN -->
      <AppSidebar @toggle="toggleSidebar" />

      <!-- ÁREA PRINCIPAL CON MAPA -->
      <main class="main-content">
        <!-- MAPA DE FONDO -->
        <div class="map-container">
          <MapComponent />
        </div>

        <!-- PANEL FLOTANTE PARA EL CONTENIDO DE LA VISTA -->
        <div class="content-overlay">
          <router-view :key="$route.path" />
        </div>
      </main>
    </div>

    <!-- STATUS BAR -->
    <AppStatusBar />

    <!-- MODALES -->
    <AppModals />
  </div>
</template>

<script setup>
import { ref } from 'vue'
import AppHeader from '../components/AppHeader.vue'
import AppSidebar from '../components/AppSidebar.vue'
import AppStatusBar from '../components/AppStatusBar.vue'
import AppModals from '../components/AppModals.vue'
import MapComponent from '../components/MapComponent.vue'

const sidebarCollapsed = ref(false)

const toggleSidebar = () => {
  sidebarCollapsed.value = !sidebarCollapsed.value
}
</script>

<style scoped>
.map-layout {
  height: 100vh;
  width: 100vw;
  display: grid;
  grid-template-rows: 70px 1fr 50px;
  overflow: hidden;
}

.main-layout {
  display: grid;
  grid-template-columns: 260px 1fr;
  height: 100%;
  transition: grid-template-columns 0.3s ease;
  position: relative;
}

.main-layout.sidebar-collapsed {
  grid-template-columns: 60px 1fr;
}

.main-content {
  position: relative;
  overflow: hidden;
}

.map-container {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 1;
}

.content-overlay {
  position: absolute;
  top: 20px;
  left: 20px;
  right: 20px;
  bottom: 20px;
  z-index: 10;
  pointer-events: none;
  display: flex;
  align-items: flex-start;
  justify-content: flex-start;
  overflow: hidden;
}

.content-overlay > :deep(*) {
  pointer-events: auto;
}

/* Responsive */
@media (max-width: 768px) {
  .main-layout {
    grid-template-columns: 100%;
  }

  .main-layout.sidebar-collapsed {
    grid-template-columns: 100%;
  }

  .content-overlay {
    top: 10px;
    left: 10px;
    right: 10px;
    bottom: 10px;
  }
}
</style>

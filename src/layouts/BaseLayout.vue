<template>
  <div class="base-layout">
    <!-- HEADER PRINCIPAL - Compartido -->
    <AppHeader />

    <!-- LAYOUT PRINCIPAL -->
    <div class="main-layout" :class="{ 'sidebar-collapsed': sidebarCollapsed }">
      <!-- SIDEBAR NAVEGACIÓN - Compartido -->
      <AppSidebar @toggle="toggleSidebar" />

      <!-- ÁREA PRINCIPAL - Variable según la vista -->
      <main class="main-content">
        <!-- Si la ruta tiene mapa -->
        <template v-if="hasMap">
          <div class="map-container">
            <MapComponent />
          </div>
          <div class="content-overlay">
            <router-view :key="$route.path" />
          </div>
        </template>

        <!-- Si la ruta NO tiene mapa -->
        <template v-else>
          <div class="content-wrapper">
            <router-view :key="$route.path" />
          </div>
        </template>
      </main>
    </div>

    <!-- STATUS BAR - Compartido -->
    <AppStatusBar />

    <!-- MODALES - Compartidos -->
    <AppModals />
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRoute } from 'vue-router'
import AppHeader from '../components/AppHeader.vue'
import AppSidebar from '../components/AppSidebar.vue'
import AppStatusBar from '../components/AppStatusBar.vue'
import AppModals from '../components/AppModals.vue'
import MapComponent from '../components/MapComponent.vue'

const route = useRoute()
const sidebarCollapsed = ref(false)

// Determinar si la vista actual necesita mapa basándose en la meta de la ruta
const hasMap = computed(() => route.meta.hasMap === true)

const toggleSidebar = () => {
  sidebarCollapsed.value = !sidebarCollapsed.value
}
</script>

<style scoped>
.base-layout {
  min-height: 100vh;
  width: 100%;
  display: flex;
  flex-direction: column;
}

.main-layout {
  display: flex;
  flex: 1;
  width: 100%;
  background: #f8fafc;
  position: relative;
}

.main-content {
  position: relative;
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
}

/* Estilos para vista con mapa */
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
}

.content-overlay > :deep(*) {
  pointer-events: auto;
}

/* Estilos para vista sin mapa */
.content-wrapper {
  padding: 24px;
  width: 100%;
}

/* Responsive */
@media (max-width: 768px) {
  .main-layout {
    flex-direction: column;
  }

  .content-wrapper {
    padding: 16px;
  }

  .content-overlay {
    top: 10px;
    left: 10px;
    right: 10px;
    bottom: 10px;
  }
}
</style>

<template>
  <div class="dashboard-layout">
    <!-- HEADER PRINCIPAL -->
    <AppHeader />

    <!-- LAYOUT PRINCIPAL -->
    <div class="main-layout" :class="{ 'sidebar-collapsed': sidebarCollapsed }">
      <!-- SIDEBAR NAVEGACIÓN -->
      <AppSidebar @toggle="toggleSidebar" />

      <!-- Backdrop para móvil (oscurece el fondo cuando el menú está abierto) -->
      <div
        v-if="appStore.sidebarOpen"
        class="sidebar-backdrop"
        @click="appStore.toggleSidebar"
      ></div>

      <!-- ÁREA PRINCIPAL - CONTENIDO COMPLETO -->
      <main class="main-content">
        <div class="content-wrapper">
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
import { useAppStore } from '../stores/app'

const appStore = useAppStore()
const sidebarCollapsed = ref(false)

const toggleSidebar = () => {
  sidebarCollapsed.value = !sidebarCollapsed.value
}
</script>

<style scoped>
.dashboard-layout {
  min-height: 100vh;
  width: 100%;
  display: flex;
  flex-direction: column;
  background: #f8fafc;
}

.main-layout {
  display: flex;
  flex: 1;
  width: 100%;
}

.main-content {
  flex: 1;
  width: 100%;
  min-width: 0;
}

.content-wrapper {
  padding: 24px;
  width: 100%;
}

.sidebar-backdrop {
  display: none;
}

/* Responsive */
@media (max-width: 768px) {
  .dashboard-layout {
    display: block;
  }

  .main-layout {
    flex-direction: column;
  }

  .content-wrapper {
    padding: 16px;
  }

  .sidebar-backdrop {
    display: block;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(15, 23, 42, 0.5);
    backdrop-filter: blur(4px);
    z-index: 850; /* Por debajo del sidebar (900) */
  }
}
</style>

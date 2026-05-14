<template>
  <div class="dashboard-layout">
    <!-- HEADER PRINCIPAL -->
    <AppHeader />

    <!-- LAYOUT SIN MAPA -->
    <div class="main-layout" :class="{ 'sidebar-collapsed': sidebarCollapsed }">
      <!-- SIDEBAR NAVEGACIÓN -->
      <AppSidebar @toggle="toggleSidebar" />

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

const sidebarCollapsed = ref(false)

const toggleSidebar = () => {
  sidebarCollapsed.value = !sidebarCollapsed.value
}
</script>

<style scoped>
.dashboard-layout {
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
  background: #f8fafc;
}

.main-layout.sidebar-collapsed {
  grid-template-columns: 60px 1fr;
}

.main-content {
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.content-wrapper {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
}

/* Scrollbar styling */
.content-wrapper::-webkit-scrollbar {
  width: 8px;
}

.content-wrapper::-webkit-scrollbar-track {
  background: #f1f5f9;
}

.content-wrapper::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 4px;
}

.content-wrapper::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}

/* Responsive */
@media (max-width: 768px) {
  .main-layout {
    grid-template-columns: 100%;
  }

  .main-layout.sidebar-collapsed {
    grid-template-columns: 100%;
  }

  .content-wrapper {
    padding: 16px;
  }
}
</style>

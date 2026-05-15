<script setup>
import { ref } from 'vue'
import { useAppStore } from '../stores/app'

// Importar los nuevos sub-componentes
import RouteListPanel from '../components/routes/RouteListPanel.vue'
import RouteCreationPanel from '../components/routes/RouteCreationPanel.vue'
import StopsAdminPanel from '../components/routes/StopsAdminPanel.vue'
import BulkStopCreator from '../components/routes/BulkStopCreator.vue'

const appStore = useAppStore()

// Estado de las pestañas
const activeTab = ref('routes')

// Estado para controlar cuándo mostrar el creador masivo de paradas
const isCreatingPoint = ref(false)

// Control de colapso en móvil
const isCollapsed = ref(window.innerWidth < 768)

const toggleCollapse = () => {
  isCollapsed.value = !isCollapsed.value
}

const handleStartCreatePoint = () => {
  isCreatingPoint.value = true
  appStore.isCreatingRoutePoint = true
  appStore.newRoutePointCoords = null
}

const handleCloseCreatePoint = () => {
  isCreatingPoint.value = false
  appStore.isCreatingRoutePoint = false
  appStore.newRoutePointCoords = null
}
</script>

<template>
  <div class="routes-widget" :class="{ 'collapsed': isCollapsed }">
    <div class="widget-card">
      <div class="widget-header">
        <div class="header-main">
          <h3>🛣️ Control de Rutas</h3>
          <button class="collapse-btn" @click="toggleCollapse">
            {{ isCollapsed ? '🔼' : '🔽' }}
          </button>
        </div>
        <!-- ─── Pestañas ──────────────────────────────────────── -->
        <div class="widget-tabs" v-show="!isCollapsed">
          <button
            class="tab-btn"
            :class="{ active: activeTab === 'routes' }"
            @click="activeTab = 'routes'"
          >🛣️ Rutas</button>
          <button
            class="tab-btn"
            :class="{ active: activeTab === 'stops' }"
            @click="activeTab = 'stops'"
          >📍 Paradas</button>
        </div>
      </div>

      <div class="widget-content" v-show="!isCollapsed">
        <!-- ══════════════════════════════════════════════════════
             TAB: RUTAS
        ══════════════════════════════════════════════════════ -->
        <template v-if="activeTab === 'routes'">
          <RouteCreationPanel v-if="appStore.isCreatingRoute" />
          <RouteListPanel v-else />
        </template>

        <!-- ══════════════════════════════════════════════════════
             TAB: PARADAS
        ══════════════════════════════════════════════════════ -->
        <template v-else-if="activeTab === 'stops'">
          <BulkStopCreator 
            v-if="isCreatingPoint" 
            @close="handleCloseCreatePoint" 
          />
          <KeepAlive>
            <StopsAdminPanel 
              v-if="!isCreatingPoint"
              @startCreate="handleStartCreatePoint" 
            />
          </KeepAlive>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Estilos globales del widget (Layout principal) */
.routes-widget {
  max-width: 380px;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.widget-card {
  background: rgba(255, 255, 255, 0.92);
  border-radius: 16px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
  backdrop-filter: blur(12px);
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.3);
}

.widget-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 16px 20px 0;
  color: white;
}

.header-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.widget-header h3 {
  margin: 0;
  font-size: 1.1rem;
  font-weight: 700;
  letter-spacing: -0.5px;
}

.collapse-btn {
  background: rgba(255, 255, 255, 0.2);
  border: none;
  color: white;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  transition: background 0.2s;
}

.collapse-btn:hover {
  background: rgba(255, 255, 255, 0.3);
}

.widget-tabs {
  display: flex;
  gap: 4px;
}

.tab-btn {
  flex: 1;
  padding: 10px 12px;
  border: none;
  border-radius: 10px 10px 0 0;
  background: rgba(255,255,255,0.1);
  color: rgba(255,255,255,0.7);
  font-size: 0.85rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
}

.tab-btn.active {
  background: white;
  color: #667eea;
}

.widget-content {
  padding: 16px;
  max-height: 70vh;
  overflow-y: auto;
}

/* RESPONSIVE MÓVIL */
@media (max-width: 768px) {
  .routes-widget {
    position: fixed;
    bottom: 20px;
    left: 10px;
    right: 10px;
    max-width: none;
    z-index: 1000;
  }

  .routes-widget.collapsed {
    bottom: 10px;
  }

  .widget-header {
    padding-bottom: 12px;
  }

  .widget-header.collapsed {
    padding-bottom: 0;
  }

  .widget-content {
    max-height: 50vh;
    padding: 12px;
  }

  .tab-btn {
    padding: 12px;
    font-size: 0.8rem;
  }
}
</style>


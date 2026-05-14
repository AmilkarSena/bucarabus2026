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
  <div class="routes-widget">
    <div class="widget-card">
      <div class="widget-header">
        <h3>🛣️ Control de Rutas</h3>
        <!-- ─── Pestañas ──────────────────────────────────────── -->
        <div class="widget-tabs">
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

      <div class="widget-content">
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
}
.widget-card {
  background: rgba(255, 255, 255, 0.95);
  border-radius: 16px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.15);
  backdrop-filter: blur(10px);
  /* Permitir que crezca con el contenido y ocultar bordes internos sobrantes */
  overflow: hidden;
}
.widget-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 16px 20px 0;
  color: white;
  /* Ya no necesita border-radius superior si .widget-card tiene overflow:hidden, pero lo dejamos por seguridad */
  border-radius: 16px 16px 0 0;
}
.widget-header h3 {
  margin: 0 0 12px;
  font-size: 1.2rem;
  font-weight: 600;
}
.widget-tabs {
  display: flex;
  gap: 2px;
}
.tab-btn {
  flex: 1;
  padding: 8px 12px;
  border: none;
  border-radius: 8px 8px 0 0;
  background: rgba(255,255,255,0.15);
  color: rgba(255,255,255,0.8);
  font-size: 0.88rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s, color 0.2s;
}
.tab-btn:hover {
  background: rgba(255,255,255,0.25);
  color: white;
}
.tab-btn.active {
  background: white;
  color: #667eea;
}
.widget-content {
  padding: 20px;
}
</style>


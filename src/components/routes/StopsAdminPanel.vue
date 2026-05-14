<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useAppStore } from '../../stores/app'
import { useAuthStore } from '../../stores/auth'
import { getAllRoutePointsAdmin, getRoutePoints as fetchCatalogPoints } from '../../api/catalogs'

const appStore = useAppStore()
const authStore = useAuthStore()

const adminPoints = ref([])
const adminPointsLoaded = ref(false)
const adminPointsLoading = ref(false)
const adminPointsError = ref('')
const stopSearch = ref('')
const showInactiveStops = ref(false)
const loadingCatalog = ref(false)
const catalogLoadError = ref('')

const catalogPointsVisible = computed(() => appStore.catalogPointsVisible)

const filteredAdminPoints = computed(() => {
  const q = stopSearch.value.trim().toLowerCase()
  return adminPoints.value.filter(p => {
    const isActive = p.is_active !== false
    if (!showInactiveStops.value && !isActive) return false
    if (q && !p.name_point.toLowerCase().includes(q)) return false
    return true
  })
})

const loadAdminPoints = async () => {
  if (adminPointsLoaded.value) return
  adminPointsLoading.value = true
  adminPointsError.value = ''
  try {
    const res = await getAllRoutePointsAdmin()
    if (res.success) {
      adminPoints.value = res.data
      adminPointsLoaded.value = true
    } else {
      adminPointsError.value = res.message || 'Error al cargar paradas'
    }
  } catch (e) {
    adminPointsError.value = 'Error de conexión'
  } finally {
    adminPointsLoading.value = false
  }
}

onMounted(() => {
  loadAdminPoints()
})

// Sincronizar is_active desde cambios hechos en el popup del mapa
// Usamos un Map para evitar el cuello de botella O(N*M)
watch(() => appStore.allCatalogPoints, (catalog) => {
  if (!adminPointsLoaded.value) return
  
  // Crear un mapa para búsqueda rápida O(1)
  const adminMap = new Map()
  adminPoints.value.forEach((p, index) => adminMap.set(p.id_point, index))

  catalog.forEach(cp => {
    if (adminMap.has(cp.id_point)) {
      const idx = adminMap.get(cp.id_point)
      if (adminPoints.value[idx].is_active !== cp.is_active) {
        adminPoints.value[idx].is_active = cp.is_active
      }
    }
  })
}, { deep: true })

const locateStop = async (point) => {
  const map = appStore.mapInstance
  if (!map) return

  if (!appStore.catalogPointsVisible) {
    if (appStore.allCatalogPoints.length === 0) {
      loadingCatalog.value = true
      try {
        const res = await fetchCatalogPoints()
        if (res.success) appStore.allCatalogPoints = res.data
      } catch (e) {} finally {
        loadingCatalog.value = false
      }
    }
    appStore.catalogPointsVisible = true
  }

  const lat = parseFloat(point.lat)
  const lng = parseFloat(point.lng)
  map.once('moveend', () => {
    const containerPoint = map.latLngToContainerPoint([lat, lng])
    appStore.catalogPointPopup = { point: { ...point }, x: containerPoint.x, y: containerPoint.y }
  })
  map.flyTo([lat, lng], 17, { animate: true, duration: 0.6 })
}

const toggleCatalogPoints = async () => {
  catalogLoadError.value = ''
  if (appStore.catalogPointsVisible) {
    appStore.catalogPointsVisible = false
    return
  }
  
  if (appStore.allCatalogPoints.length === 0) {
    loadingCatalog.value = true
    try {
      const res = await fetchCatalogPoints()
      if (res.success) {
        appStore.allCatalogPoints = res.data
      } else {
        catalogLoadError.value = res.message || 'Error al cargar paradas'
        return
      }
    } catch (e) {
      catalogLoadError.value = 'Error de conexión'
      return
    } finally {
      loadingCatalog.value = false
    }
  }
  appStore.catalogPointsVisible = true
}
</script>

<template>
  <div class="tab-actions">
    <button
      class="action-btn"
      :class="catalogPointsVisible ? 'catalog-active' : 'secondary'"
      @click="toggleCatalogPoints"
      :disabled="loadingCatalog"
      title="Mostrar/ocultar paradas en el mapa"
    >
      <span class="btn-icon">{{ loadingCatalog ? '⏳' : '📍' }}</span>
      {{ loadingCatalog ? '...' : (catalogPointsVisible ? `Ocultar (${appStore.allCatalogPoints.length})` : 'Ver en mapa') }}
    </button>
    <button class="action-btn ghost" v-if="authStore.can('CREATE_STOPS')" @click="$emit('startCreate')">
      <span>➕</span> Nueva parada
    </button>
  </div>
  <div v-if="catalogLoadError" class="catalog-error">⚠️ {{ catalogLoadError }}</div>

  <!-- Buscador -->
  <div class="stops-search-bar">
    <input v-model="stopSearch" type="text" class="picker-input" placeholder="Buscar parada..." />
    <label class="checkbox-label small">
      <input v-model="showInactiveStops" type="checkbox" /> Inactivas
    </label>
  </div>

  <!-- Tabla compacta -->
  <div class="stops-list-scroll">
    <div v-if="adminPointsLoading" class="no-routes">Cargando paradas...</div>
    <div v-else-if="adminPointsError" class="catalog-error">⚠️ {{ adminPointsError }}</div>
    <div v-else-if="filteredAdminPoints.length === 0" class="no-routes">
      No hay paradas{{ stopSearch ? ' que coincidan' : ' registradas' }}.
    </div>
    <template v-else>
      <div class="stops-grid-header">
        <span>Nombre</span>
        <span>Tipo</span>
        <span></span>
      </div>
      <div
        v-for="point in filteredAdminPoints"
        :key="point.id_point"
        class="stops-grid-row"
        :class="{ 'stop-row-inactive': !point.is_active }"
        @click="locateStop(point)"
        title="Ver en mapa"
      >
        <span class="stop-col-name">
          <span class="stop-type-dot" :style="{ background: point.point_type === 1 ? '#10b981' : '#6366f1' }"></span>
          {{ point.name_point }}
          <span v-if="point.is_checkpoint" class="checkpoint-pill">★</span>
        </span>
        <span class="stop-col-type">{{ point.point_type === 1 ? 'Parada' : 'Ref.' }}</span>
        <span class="stop-col-status">
          <span class="stop-status-dot" :class="point.is_active ? 'active' : 'inactive'"></span>
        </span>
      </div>
    </template>
  </div>
</template>

<style scoped>
.tab-actions {
  display: flex;
  gap: 10px;
  margin-bottom: 16px;
}
.action-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 16px;
  border: none;
  border-radius: 10px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.action-btn.secondary {
  background: white;
  color: #667eea;
  border: 2px solid #667eea;
}
.action-btn.secondary:hover:not(:disabled) {
  background: #667eea;
  color: white;
}
.action-btn.catalog-active {
  background: #10b981;
  color: white;
  border: none;
}
.action-btn.catalog-active:hover {
  background: #059669;
  transform: translateY(-1px);
}
.action-btn.ghost {
  flex: 1;
  background: transparent;
  color: #667eea;
  border: 1.5px dashed #667eea;
  font-size: 0.82rem;
  padding: 8px 12px;
}
.action-btn.ghost:hover:not(:disabled) {
  background: #eef2ff;
}
.action-btn:disabled, .action-btn.ghost:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.catalog-error {
  background: #fef2f2;
  border: 1px solid #fca5a5;
  border-radius: 8px;
  padding: 6px 12px;
  font-size: 0.8rem;
  color: #dc2626;
  margin-bottom: 10px;
}
.stops-search-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.picker-input {
  flex: 1;
  padding: 8px 10px;
  border: 1.5px solid #d1d5db;
  border-radius: 8px;
  font-size: 0.85rem;
  background: white;
  color: #1e293b;
}
.picker-input:focus {
  outline: none;
  border-color: #667eea;
}
.checkbox-label.small {
  font-size: 0.78rem;
  white-space: nowrap;
  display: flex;
  align-items: center;
  gap: 6px;
  color: #374151;
  cursor: pointer;
}
.no-routes {
  text-align: center;
  padding: 40px 20px;
  color: #94a3b8;
  font-size: 0.95rem;
}
.stops-list-scroll {
  overflow-y: auto;
  max-height: 320px;
  border: 1px solid #e2e8f0;
  border-radius: 10px;
  font-size: 0.8rem;
}
.stops-list-scroll::-webkit-scrollbar { width: 4px; }
.stops-list-scroll::-webkit-scrollbar-track { background: transparent; }
.stops-list-scroll::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 4px; }
.stops-grid-header,
.stops-grid-row {
  display: grid;
  grid-template-columns: 1fr 52px 20px;
  align-items: center;
}
.stops-grid-header {
  position: sticky;
  top: 0;
  background: #f8fafc;
  color: #64748b;
  font-weight: 600;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  padding: 5px 8px;
  border-bottom: 1px solid #e2e8f0;
}
.stops-grid-row {
  padding: 4px 8px;
  border-bottom: 1px solid #f1f5f9;
  transition: background 0.1s;
  cursor: pointer;
}
.stops-grid-row:last-child { border-bottom: none; }
.stops-grid-row:hover { background: #f8fafc; }
.stop-row-inactive { opacity: 0.45; }
.stop-col-name {
  display: flex;
  align-items: center;
  gap: 5px;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  min-width: 0;
}
.stop-col-type {
  color: #64748b;
  font-size: 0.78rem;
  white-space: nowrap;
}
.stop-col-status {
  display: flex;
  justify-content: center;
  align-items: center;
}
.stop-status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.stop-status-dot.active  { background: #10b981; }
.stop-status-dot.inactive { background: #cbd5e1; }
.stop-type-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
}
.checkpoint-pill {
  background: #fef3c7;
  color: #d97706;
  font-size: 0.68rem;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: 8px;
  margin-left: 2px;
}
</style>

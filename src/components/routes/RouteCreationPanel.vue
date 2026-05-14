<!--este es el componente para crear rutas a partir del catalogo
    las paradas no son las del catalogo, no se pueden agregar a la ruta
    SI SON LAS DEL CATALOGO, SE PUEDEN AGREGAR A LA RUTA
    
    Acciones:
    - Seleccionar paradas del catalogo
    - Agregar paradas del catalogo a la ruta  
    - Eliminar paradas del catalogo a la ruta
    - Ordenar paradas del catalogo
    - Guardar ruta
    - Cancelar creacion
    
-->
<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../../stores/app'
import { getRoutePoints as fetchCatalogPoints } from '../../api/catalogs'

const appStore = useAppStore()

const creationStopSearch = ref('')
const newRouteError = ref('')
const loadingCatalog = ref(false)

//Si las paradas no son las del catalogo, no se pueden agregar a la ruta
//Si las paradas son las del catalogo, se pueden agregar a la ruta

onMounted(async () => {
  if (appStore.allCatalogPoints.length === 0) {
    loadingCatalog.value = true
    try {
      const res = await fetchCatalogPoints()
      if (res.success) {
        appStore.allCatalogPoints = res.data
      }
    } catch (e) {
      console.error('Error cargando catálogo:', e)
    } finally {
      loadingCatalog.value = false
    }
  }
})
// creationCatalogFiltered: crea una lista filtrada de paradas del catalogo
//
const creationCatalogFiltered = computed(() => {
  const q = creationStopSearch.value.trim().toLowerCase()
  const draftIds = new Set(appStore.draftStops.map(s => s.id_point))
  return (appStore.allCatalogPoints || []).filter(p => {
    if (draftIds.has(p.id_point)) return false
    if (!q) return true
    return p.name_point.toLowerCase().includes(q)
  })
})

// saveNewRoute: guarda la ruta en la store
const saveNewRoute = async () => {
  if (appStore.draftStops.length < 2) return
  const path  = appStore.draftPath || appStore.draftStops.map(s => [s.lat, s.lng])
  const stops = appStore.draftStops.map((s, idx) => ({
    id_point:        s.id_point,
    name_point:      s.name_point,
    dist_from_start: null,
    eta_seconds:     null
  }))
  appStore.openModal('newRoute', { fromDraft: true, path, stops })
}
</script>

<template>
  <!-- Cabecera del panel -->
  <div class="creation-header">
    <span class="creation-title">🗺️ Nueva Ruta — Selecciona paradas en orden</span>
    <button class="icon-btn small danger" @click="appStore.cancelRouteCreation()" title="Cancelar creación">✕</button>
  </div>

  <!-- Buscador en el catálogo -->
  <div class="creation-search-box">
    <input
      v-model="creationStopSearch"
      class="stop-search-input"
      placeholder="🔍 Buscar parada..."
    />
  </div>

  <!-- Lista del catálogo (clicables para añadir al borrador) -->
  <div class="catalog-picker-list">
    <div v-if="creationCatalogFiltered.length === 0" class="no-stops-msg">
      {{ loadingCatalog
          ? 'Cargando paradas…'
          : 'Sin resultados. Crea paradas en la pestaña Paradas.' }}
    </div>
    <button
      v-for="stop in creationCatalogFiltered"
      :key="stop.id_point"
      class="catalog-stop-btn"
      @click="appStore.addDraftStop({ id_point: stop.id_point, name_point: stop.name_point, lat: parseFloat(stop.lat), lng: parseFloat(stop.lng) })"
      :title="`Agregar ${stop.name_point}`"
    >
      <span class="stop-dot">📍</span>
      <span class="stop-name">{{ stop.name_point }}</span>
      <span class="stop-add-icon">＋</span>
    </button>
  </div>

  <!-- Secuencia borrador -->
  <div class="draft-sequence-header">
    <span>Secuencia ({{ appStore.draftStops.length }} paradas)</span>
  </div>
  <div class="draft-sequence-list">
    <div v-if="appStore.draftStops.length === 0" class="no-stops-msg draft-empty">
      Haz clic en una parada del catálogo para empezar.
    </div>
    <div
      v-for="(stop, idx) in appStore.draftStops"
      :key="stop.id_point"
      class="draft-stop-item"
    >
      <span class="draft-order-badge">{{ idx + 1 }}</span>
      <span class="draft-stop-name">{{ stop.name_point }}</span>
      <button class="icon-btn small" @click="appStore.removeDraftStop(idx)" title="Quitar">✕</button>
    </div>
  </div>

  <!-- Acciones del panel de creación -->
  <div class="creation-actions">
    <button
      class="action-btn secondary small"
      :disabled="appStore.draftStops.length === 0"
      @click="appStore.undoLastDraftStop()"
      title="Quitar última parada"
    >↩️ Deshacer</button>
    <button
      class="action-btn primary small"
      :disabled="appStore.draftStops.length < 2"
      @click="saveNewRoute()"
      :title="appStore.draftStops.length < 2 ? 'Necesitas al menos 2 paradas' : 'Guardar ruta'"
    >💾 Guardar Ruta</button>
  </div>
  <div v-if="newRouteError" class="creation-error">⚠️ {{ newRouteError }}</div>
</template>

<style scoped>
.creation-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 8px;
  margin-bottom: 8px;
}
.creation-title {
  font-size: 0.78rem;
  font-weight: 700;
  color: #fff;
  line-height: 1.3;
}
.creation-search-box {
  margin-bottom: 6px;
}
.stop-search-input {
  width: 100%;
  padding: 7px 10px;
  border: 1.5px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.82rem;
  background: #f8fafc;
  outline: none;
  transition: border-color 0.2s;
  box-sizing: border-box;
}
.stop-search-input:focus {
  border-color: #667eea;
  background: #fff;
}
.catalog-picker-list {
  max-height: 180px;
  overflow-y: auto;
  border: 1.5px solid #e2e8f0;
  border-radius: 8px;
  background: #f8fafc;
  margin-bottom: 8px;
}
.catalog-stop-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  width: 100%;
  padding: 7px 10px;
  background: none;
  border: none;
  border-bottom: 1px solid #f1f5f9;
  cursor: pointer;
  text-align: left;
  font-size: 0.8rem;
  color: #374151;
  transition: background 0.15s;
}
.catalog-stop-btn:last-child { border-bottom: none; }
.catalog-stop-btn:hover { background: #eef2ff; color: #4338ca; }
.stop-name { flex: 1; }
.stop-add-icon { color: #667eea; font-weight: 700; font-size: 1rem; }
.draft-sequence-header {
  font-size: 0.75rem;
  font-weight: 700;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  padding: 4px 2px;
  margin-bottom: 4px;
}
.draft-sequence-list {
  min-height: 60px;
  max-height: 160px;
  overflow-y: auto;
  border: 1.5px dashed #cbd5e1;
  border-radius: 8px;
  padding: 4px;
  margin-bottom: 8px;
  background: #f8fafc;
}
.draft-stop-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 5px 6px;
  border-radius: 6px;
  background: #fff;
  margin-bottom: 3px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.06);
  font-size: 0.8rem;
}
.draft-order-badge {
  min-width: 22px;
  height: 22px;
  border-radius: 50%;
  background: #667eea;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.7rem;
  font-weight: 700;
  flex-shrink: 0;
}
.draft-stop-name {
  flex: 1;
  color: #1e293b;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.no-stops-msg {
  font-size: 0.78rem;
  color: #94a3b8;
  text-align: center;
  padding: 12px 8px;
}
.draft-empty { font-style: italic; }
.creation-actions {
  display: flex;
  gap: 6px;
  margin-top: 4px;
}
.action-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border: none;
  border-radius: 10px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.action-btn.primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}
.action-btn.primary:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
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
.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.action-btn.small {
  font-size: 0.78rem;
  padding: 6px 10px;
  flex: 1;
}
.icon-btn {
  width: 26px;
  height: 26px;
  border: none;
  background: transparent;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.85rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
}
.icon-btn.danger {
  background: #fee2e2;
  color: #dc2626;
}
.icon-btn.danger:hover {
  background: #dc2626;
  color: white;
}
.icon-btn.small {
  width: 26px;
  height: 26px;
  font-size: 0.75rem;
}
.creation-error {
  font-size: 0.78rem;
  color: #ef4444;
  margin-top: 4px;
  padding: 6px 8px;
  background: #fef2f2;
  border-radius: 6px;
}
</style>

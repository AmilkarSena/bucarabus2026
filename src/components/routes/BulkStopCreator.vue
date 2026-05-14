<script setup>
import { ref, computed, watch, onUnmounted } from 'vue'
import { useAppStore } from '../../stores/app'
import { createRoutePoint } from '../../api/catalogs'
import { reverseGeocode } from '../../api/geocoding'
import L from 'leaflet'

const appStore = useAppStore()
const emit = defineEmits(['close'])

const pendingPoints = ref([])
const savingPoint = ref(false)
const pointError = ref('')
const pendingMarkers = ref(new Map())

const clearPendingMarkers = () => {
  if (appStore.mapInstance) {
    pendingMarkers.value.forEach(marker => {
      appStore.mapInstance.removeLayer(marker)
    })
  }
  pendingMarkers.value.clear()
}

const cancelCreatePoint = () => {
  pointError.value = ''
  appStore.isCreatingRoutePoint = false
  appStore.newRoutePointCoords = null
  pendingPoints.value = []
  clearPendingMarkers()
  emit('close')
}

// Limpiar al desmontar para evitar marcadores huérfanos
onUnmounted(() => {
  cancelCreatePoint()
})

const capturedCoords = computed(() => appStore.newRoutePointCoords)

watch(capturedCoords, async (coords) => {
  if (coords) { // Este componente solo existe cuando isCreatingPoint es true
    const newId = Date.now()
    const point = {
      id: newId,
      lat: coords[0],
      lng: coords[1],
      name: '',
      isGeocoding: true
    }
    pendingPoints.value.push(point)
    
    // Dibujar marcador en el mapa
    if (appStore.mapInstance) {
      const marker = L.marker([coords[0], coords[1]], {
        icon: L.divIcon({
          className: 'temp-creation-marker',
          html: `<div style="
            background: #6366f1; 
            color: white; 
            width: 30px; 
            height: 30px; 
            border-radius: 50%; 
            display: flex; 
            align-items: center; 
            justify-content: center; 
            font-size: 18px;
            box-shadow: 0 0 15px rgba(99, 102, 241, 0.8);
            border: 3px solid white;
          ">📍</div>`,
          iconSize: [30, 30],
          iconAnchor: [15, 15]
        }),
        zIndexOffset: 2000
      }).addTo(appStore.mapInstance)
      pendingMarkers.value.set(newId, marker)
    }
    
    appStore.newRoutePointCoords = null

    try {
      const suggested = await reverseGeocode(point.lat, point.lng)
      const targetPoint = pendingPoints.value.find(p => p.id === newId)
      if (targetPoint && suggested) {
        targetPoint.name = suggested
      }
    } finally {
      const targetPoint = pendingPoints.value.find(p => p.id === newId)
      if (targetPoint) targetPoint.isGeocoding = false
    }
  }
})

const removePendingPoint = (id) => {
  pendingPoints.value = pendingPoints.value.filter(p => p.id !== id)
  if (appStore.mapInstance && pendingMarkers.value.has(id)) {
    appStore.mapInstance.removeLayer(pendingMarkers.value.get(id))
    pendingMarkers.value.delete(id)
  }
}

const saveCreatedPoints = async () => {
  pointError.value = ''
  if (pendingPoints.value.length === 0) {
    pointError.value = 'No hay paradas para guardar.'
    return
  }

  if (pendingPoints.value.some(p => !p.name.trim())) {
    pointError.value = 'Todas las paradas deben tener un nombre.'
    return
  }

  savingPoint.value = true
  let successCount = 0
  
  try {
    // OPTIMIZACIÓN: Ejecutar en paralelo con Promise.all en lugar de secuencial
    const promises = pendingPoints.value.map(point => {
      return createRoutePoint({
        name_point:    point.name.trim(),
        descrip_point: null,
        lat:           point.lat,
        lng:           point.lng,
        point_type:    1,
        is_checkpoint: false
      })
    })

    const results = await Promise.allSettled(promises)
    
    results.forEach(res => {
      if (res.status === 'fulfilled' && res.value.success) {
        successCount++
        if (appStore.allCatalogPoints.length > 0) {
          appStore.allCatalogPoints.unshift(res.value.data)
        }
        // Nota: adminPoints se actualizará solo si cerramos este panel o a través de eventos, 
        // pero como comparten el store, al abrir StopsAdminPanel de nuevo debería refrescar o ver el store.
      }
    })

    if (successCount > 0) {
      alert(`✅ Se guardaron ${successCount} paradas correctamente.`)
      // Si hubo fallos, podríamos mantenerlos, pero para simplificar cancelamos
      cancelCreatePoint()
    } else {
      pointError.value = 'Error al crear las paradas.'
    }
  } catch (e) {
    pointError.value = e?.response?.data?.message || e.message || String(e) || 'Error de conexión.'
  } finally {
    savingPoint.value = false
  }
}
</script>

<template>
  <div class="create-point-form">
    <div class="picker-header">
      <h4>📍 Crear Paradas</h4>
      <button class="icon-btn small" @click="cancelCreatePoint" title="Cancelar">✕</button>
    </div>
    <div class="coords-capture">
      <span class="coords-pending">🖱️ Haz múltiples clics en el mapa para agregar paradas</span>
    </div>
    
    <div class="pending-points-container" v-if="pendingPoints.length > 0">
      <div class="pending-points-list">
        <div v-for="point in pendingPoints" :key="point.id" class="pending-point-item">
          <div class="pending-point-header">
            <input
              v-model="point.name"
              type="text"
              class="picker-input pending-name"
              :placeholder="point.isGeocoding ? '🔍 Buscando...' : 'Nombre de la parada *'"
            />
            <button class="icon-btn small danger" @click="removePendingPoint(point.id)" title="Eliminar parada">✕</button>
          </div>
        </div>
      </div>
    </div>

    <div v-if="pointError" class="point-error">{{ pointError }}</div>
    <div class="picker-actions">
      <button class="action-btn secondary small" @click="cancelCreatePoint">Cancelar</button>
      <button 
        class="action-btn primary small" 
        :disabled="savingPoint || pendingPoints.length === 0" 
        @click="saveCreatedPoints"
      >
        {{ savingPoint ? 'Guardando...' : (pendingPoints.length > 0 ? `Guardar ${pendingPoints.length} Parada(s)` : 'Guardar Paradas') }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.create-point-form {
  display: flex;
  flex-direction: column;
  gap: 10px;
  background: #f0fdf4;
  border: 1.5px solid #86efac;
  border-radius: 12px;
  padding: 14px;
  margin-bottom: 14px;
}
.picker-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.picker-header h4 {
  margin: 0;
  color: #1e293b;
  font-size: 1rem;
}
.coords-capture {
  background: #fef9c3;
  border: 1px dashed #fbbf24;
  border-radius: 8px;
  padding: 8px 12px;
  font-size: 0.82rem;
  color: #92400e;
  text-align: center;
}
.coords-pending {
  font-style: italic;
}
.pending-points-container {
  max-height: 250px;
  overflow-y: auto;
}
.pending-points-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pending-point-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.pending-point-header {
  display: flex;
  gap: 8px;
  align-items: center;
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
.point-error {
  color: #dc2626;
  font-size: 0.8rem;
  text-align: center;
}
.picker-actions {
  display: flex;
  gap: 10px;
  margin-top: 4px;
}
.action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border: none;
  border-radius: 10px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}
.action-btn.small {
  padding: 6px 10px;
  font-size: 0.78rem;
  flex: 1;
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
.icon-btn {
  width: 26px;
  height: 26px;
  border: none;
  background: transparent;
  border-radius: 6px;
  cursor: pointer;
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
  font-size: 0.75rem;
}
</style>

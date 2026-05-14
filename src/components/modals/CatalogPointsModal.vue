<template>
  <div class="catalog-points-modal">
    <!-- Barra de búsqueda -->
    <div class="modal-toolbar">
      <input
        v-model="searchQuery"
        type="text"
        class="search-input"
        placeholder="Buscar por nombre..."
      />
      <label class="toggle-inactive">
        <input v-model="showInactive" type="checkbox" />
        Mostrar inactivos
      </label>
    </div>

    <!-- Error general -->
    <div v-if="loadError" class="modal-error">⚠️ {{ loadError }}</div>

    <!-- Formulario de edición inline -->
    <div v-if="editingPoint" class="edit-form">
      <div class="edit-form-header">
        <span>✏️ Editando: <strong>{{ editingPoint.name_point }}</strong></span>
        <button class="icon-btn small" @click="cancelEdit" title="Cancelar">✕</button>
      </div>
      <div class="edit-form-fields">
        <input v-model="editForm.name_point" type="text" class="picker-input" placeholder="Nombre *" />
        <input v-model="editForm.descrip_point" type="text" class="picker-input" placeholder="Descripción (opcional)" />
        <div class="edit-form-row">
          <div class="coords-capture" :class="{ captured: newCoords }">
            <span v-if="newCoords">✅ {{ newCoords[0].toFixed(5) }}, {{ newCoords[1].toFixed(5) }}</span>
            <span v-else class="coords-pending">
              📍 {{ editForm.lat.toFixed(5) }}, {{ editForm.lng.toFixed(5) }}
              <button class="action-btn ghost small" @click="startRelocate" title="Cambiar ubicación en el mapa">🖱️ Reubicar</button>
            </span>
          </div>
          <select v-model="editForm.point_type" class="picker-select narrow">
            <option :value="1">Parada</option>
            <option :value="2">Referencia</option>
          </select>
          <label class="checkbox-label">
            <input v-model="editForm.is_checkpoint" type="checkbox" />
            Checkpoint
          </label>
        </div>
        <div v-if="editError" class="point-error">{{ editError }}</div>
        <div class="edit-form-actions">
          <button class="action-btn secondary small" @click="cancelEdit">Cancelar</button>
          <button class="action-btn primary small" :disabled="savingEdit" @click="saveEdit">
            {{ savingEdit ? 'Guardando...' : 'Guardar cambios' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Tabla de puntos -->
    <div class="points-table-wrapper">
      <div v-if="isLoading" class="loading-state">Cargando puntos...</div>
      <div v-else-if="filteredPoints.length === 0" class="empty-state">
        No hay puntos que coincidan con la búsqueda.
      </div>
      <table v-else class="points-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Nombre</th>
            <th>Tipo</th>
            <th>Coords</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="point in filteredPoints"
            :key="point.id_point"
            :class="{ inactive: !point.is_active, editing: editingPoint?.id_point === point.id_point }"
          >
            <td class="col-id">{{ point.id_point }}</td>
            <td class="col-name">
              <span class="point-type-badge" :class="point.point_type === 1 ? 'type-stop' : 'type-ref'">
                {{ point.point_type === 1 ? '🚌' : '📍' }}
              </span>
              {{ point.name_point }}
              <span v-if="point.is_checkpoint" class="checkpoint-badge" title="Checkpoint">✓</span>
            </td>
            <td class="col-type">{{ point.point_type === 1 ? 'Parada' : 'Referencia' }}</td>
            <td class="col-coords">{{ Number(point.lat).toFixed(4) }}, {{ Number(point.lng).toFixed(4) }}</td>
            <td class="col-status">
              <span class="status-badge" :class="point.is_active ? 'active' : 'inactive'">
                {{ point.is_active ? 'Activo' : 'Inactivo' }}
              </span>
            </td>
            <td class="col-actions">
              <button
                class="icon-btn"
                :disabled="!!editingPoint"
                @click="startEdit(point)"
                title="Editar"
              >✏️</button>
              <button
                class="icon-btn"
                :class="{ 'danger': point.is_active }"
                :disabled="togglingId === point.id_point"
                @click="togglePoint(point)"
                :title="point.is_active ? 'Desactivar' : 'Activar'"
              >{{ point.is_active ? '🔴' : '🟢' }}</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useAppStore } from '../../stores/app'
import { getAllRoutePointsAdmin, updateRoutePoint, toggleRoutePoint } from '../../api/catalogs'

const appStore = useAppStore()

const points = ref([])
const isLoading = ref(false)
const loadError = ref('')
const searchQuery = ref('')
const showInactive = ref(false)

// Edición
const editingPoint = ref(null)
const editForm = ref({})
const editError = ref('')
const savingEdit = ref(false)
const newCoords = ref(null)

// Toggle
const togglingId = ref(null)

// ─── Carga inicial ────────────────────────────────────────────────────────────
const loadPoints = async () => {
  isLoading.value = true
  loadError.value = ''
  try {
    const res = await getAllRoutePointsAdmin()
    if (res.success) {
      points.value = res.data
    } else {
      loadError.value = res.message || 'Error al cargar puntos'
    }
  } catch (e) {
    loadError.value = 'Error de conexión al cargar puntos'
  } finally {
    isLoading.value = false
  }
}

onMounted(loadPoints)

// ─── Filtrado ────────────────────────────────────────────────────────────────
const filteredPoints = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  return points.value.filter(p => {
    if (!showInactive.value && !p.is_active) return false
    if (q && !p.name_point.toLowerCase().includes(q)) return false
    return true
  })
})

// ─── Edición ─────────────────────────────────────────────────────────────────
const startEdit = (point) => {
  editingPoint.value = point
  editForm.value = {
    name_point:    point.name_point,
    descrip_point: point.descrip_point || '',
    lat:           parseFloat(point.lat),
    lng:           parseFloat(point.lng),
    point_type:    point.point_type,
    is_checkpoint: point.is_checkpoint
  }
  editError.value = ''
  newCoords.value = null
}

const cancelEdit = () => {
  editingPoint.value = null
  editForm.value = {}
  editError.value = ''
  newCoords.value = null
  appStore.isCreatingRoutePoint = false
  appStore.newRoutePointCoords = null
}

const startRelocate = () => {
  appStore.isCreatingRoutePoint = true
  appStore.newRoutePointCoords = null
}

// Observar coordenadas capturadas en el mapa
watch(() => appStore.newRoutePointCoords, (coords) => {
  if (coords && editingPoint.value) {
    newCoords.value = coords
    editForm.value.lat = coords[0]
    editForm.value.lng = coords[1]
    appStore.isCreatingRoutePoint = false
  }
})

const saveEdit = async () => {
  editError.value = ''
  if (!editForm.value.name_point?.trim()) {
    editError.value = 'El nombre es obligatorio.'
    return
  }
  savingEdit.value = true
  try {
    const res = await updateRoutePoint(editingPoint.value.id_point, {
      name_point:    editForm.value.name_point.trim(),
      descrip_point: editForm.value.descrip_point.trim() || null,
      lat:           editForm.value.lat,
      lng:           editForm.value.lng,
      point_type:    editForm.value.point_type,
      is_checkpoint: editForm.value.is_checkpoint
    })
    if (res.success) {
      // Actualizar en la lista local
      const idx = points.value.findIndex(p => p.id_point === editingPoint.value.id_point)
      if (idx !== -1) {
        points.value[idx] = {
          ...points.value[idx],
          name_point:    editForm.value.name_point.trim(),
          descrip_point: editForm.value.descrip_point.trim() || null,
          lat:           editForm.value.lat,
          lng:           editForm.value.lng,
          point_type:    editForm.value.point_type,
          is_checkpoint: editForm.value.is_checkpoint
        }
      }
      // Sincronizar allCatalogPoints del store si está cargado
      if (appStore.allCatalogPoints?.length > 0) {
        const ci = appStore.allCatalogPoints.findIndex(p => p.id_point === editingPoint.value.id_point)
        if (ci !== -1) {
          appStore.allCatalogPoints[ci] = { ...appStore.allCatalogPoints[ci], ...points.value[idx] }
        }
      }
      cancelEdit()
    } else {
      editError.value = res.message || 'Error al guardar los cambios.'
    }
  } catch (e) {
    editError.value = e?.response?.data?.message || 'Error de conexión.'
  } finally {
    savingEdit.value = false
  }
}

// ─── Toggle activo/inactivo ───────────────────────────────────────────────────
const togglePoint = async (point) => {
  const newState = !point.is_active
  const action = newState ? 'activar' : 'desactivar'
  if (!confirm(`¿${newState ? 'Activar' : 'Desactivar'} el punto "${point.name_point}"?`)) return

  togglingId.value = point.id_point
  try {
    const res = await toggleRoutePoint(point.id_point, newState)
    if (res.success) {
      point.is_active = res.data.is_active
      // Sincronizar store
      if (appStore.allCatalogPoints?.length > 0) {
        const ci = appStore.allCatalogPoints.findIndex(p => p.id_point === point.id_point)
        if (ci !== -1) appStore.allCatalogPoints[ci].is_active = res.data.is_active
      }
    } else {
      alert(`Error al ${action} punto: ${res.message}`)
    }
  } catch (e) {
    alert(`Error de conexión al ${action} punto.`)
  } finally {
    togglingId.value = null
  }
}

// Limpiar estado de captura de coordenadas al desmontar
onUnmounted(() => {
  appStore.isCreatingRoutePoint = false
  appStore.newRoutePointCoords = null
})
</script>

<style scoped>
.catalog-points-modal {
  display: flex;
  flex-direction: column;
  gap: 12px;
  min-height: 300px;
}

.modal-toolbar {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.search-input {
  flex: 1;
  min-width: 160px;
  padding: 6px 10px;
  border: 1px solid var(--border-color, #ddd);
  border-radius: 6px;
  font-size: 0.85rem;
  background: var(--input-bg, #fff);
  color: var(--text-primary, #1e293b);
}

.toggle-inactive {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.82rem;
  color: var(--text-muted, #64748b);
  cursor: pointer;
  white-space: nowrap;
}

.modal-error {
  padding: 8px 12px;
  background: #fef2f2;
  border: 1px solid #fca5a5;
  border-radius: 6px;
  color: #dc2626;
  font-size: 0.85rem;
}

/* ─── Edit form ─────────────────────────────────────── */
.edit-form {
  border: 1px solid #3b82f6;
  border-radius: 8px;
  padding: 12px;
  background: #eff6ff;
}

.edit-form-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
  font-size: 0.88rem;
  color: #1e40af;
}

.edit-form-fields {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.edit-form-row {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}

.coords-capture {
  flex: 1;
  min-width: 160px;
  padding: 6px 10px;
  border-radius: 6px;
  font-size: 0.8rem;
  border: 1px solid #93c5fd;
  background: #dbeafe;
  color: #1e40af;
  display: flex;
  align-items: center;
  gap: 8px;
}

.coords-capture.captured {
  background: #dcfce7;
  border-color: #86efac;
  color: #166534;
}

.coords-pending {
  display: flex;
  align-items: center;
  gap: 8px;
}

.edit-form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

/* ─── Table ──────────────────────────────────────────── */
.points-table-wrapper {
  overflow-x: auto;
  overflow-y: auto;
  max-height: 420px;
  border: 1px solid var(--border-color, #e2e8f0);
  border-radius: 8px;
}

.points-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.83rem;
}

.points-table thead th {
  position: sticky;
  top: 0;
  background: var(--bg-secondary, #f8fafc);
  padding: 8px 10px;
  text-align: left;
  font-weight: 600;
  color: var(--text-muted, #64748b);
  border-bottom: 1px solid var(--border-color, #e2e8f0);
  white-space: nowrap;
}

.points-table tbody tr {
  border-bottom: 1px solid var(--border-color, #f1f5f9);
  transition: background 0.15s;
}

.points-table tbody tr:hover {
  background: var(--bg-hover, #f8fafc);
}

.points-table tbody tr.inactive {
  opacity: 0.5;
}

.points-table tbody tr.editing {
  background: #eff6ff;
}

.points-table td {
  padding: 7px 10px;
  color: var(--text-primary, #1e293b);
  vertical-align: middle;
}

.col-id { width: 44px; color: var(--text-muted, #94a3b8); font-size: 0.78rem; }
.col-name { max-width: 200px; }
.col-type { width: 80px; white-space: nowrap; }
.col-coords { width: 150px; font-size: 0.78rem; color: var(--text-muted, #64748b); white-space: nowrap; }
.col-status { width: 80px; }
.col-actions { width: 70px; white-space: nowrap; }

.status-badge {
  display: inline-block;
  padding: 2px 8px;
  border-radius: 10px;
  font-size: 0.75rem;
  font-weight: 600;
}
.status-badge.active { background: #dcfce7; color: #166534; }
.status-badge.inactive { background: #f1f5f9; color: #64748b; }

.checkpoint-badge {
  display: inline-block;
  margin-left: 4px;
  font-size: 0.7rem;
  color: #f59e0b;
  font-weight: 700;
}

.loading-state,
.empty-state {
  padding: 32px;
  text-align: center;
  color: var(--text-muted, #94a3b8);
  font-size: 0.88rem;
}

/* shared utility classes (mirror other modals) */
.picker-input {
  width: 100%;
  padding: 7px 10px;
  border: 1px solid var(--border-color, #ddd);
  border-radius: 6px;
  font-size: 0.85rem;
  background: var(--input-bg, #fff);
  color: var(--text-primary, #1e293b);
  box-sizing: border-box;
}

.picker-select {
  padding: 6px 8px;
  border: 1px solid var(--border-color, #ddd);
  border-radius: 6px;
  font-size: 0.85rem;
  background: var(--input-bg, #fff);
  color: var(--text-primary, #1e293b);
}

.picker-select.narrow { width: 120px; }

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.85rem;
  color: var(--text-primary, #1e293b);
  cursor: pointer;
}

.point-error {
  color: #dc2626;
  font-size: 0.82rem;
  padding: 4px 0;
}

.icon-btn {
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 4px 6px;
  border-radius: 4px;
  font-size: 0.9rem;
  transition: background 0.15s;
}
.icon-btn:hover { background: var(--bg-hover, #f1f5f9); }
.icon-btn:disabled { opacity: 0.4; cursor: not-allowed; }
.icon-btn.small { font-size: 0.75rem; padding: 2px 5px; }

.action-btn {
  padding: 5px 12px;
  border: none;
  border-radius: 6px;
  font-size: 0.82rem;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  transition: background 0.15s, opacity 0.15s;
}
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.action-btn.primary { background: #3b82f6; color: #fff; }
.action-btn.primary:hover:not(:disabled) { background: #2563eb; }
.action-btn.secondary { background: var(--bg-secondary, #f8fafc); color: var(--text-primary, #1e293b); border: 1px solid var(--border-color, #e2e8f0); }
.action-btn.secondary:hover:not(:disabled) { background: var(--bg-hover, #f1f5f9); }
.action-btn.ghost { background: transparent; color: #3b82f6; border: 1px solid #93c5fd; }
.action-btn.ghost:hover:not(:disabled) { background: #eff6ff; }
.action-btn.small { padding: 3px 9px; font-size: 0.78rem; }
</style>

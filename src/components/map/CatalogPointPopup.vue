<template>
  <Transition name="popup-fade">
    <div
      v-if="catalogPointPopup"
      class="catalog-point-popup"
      :style="popupStyle"
      @click.stop
      @keydown.esc="closePopup"
    >
      <!-- Flecha decorativa -->
      <div class="popup-arrow"></div>

      <!-- Modo vista (barra de acciones) -->
      <template v-if="!popupEditing">
        <div class="popup-header">
          <span class="popup-title">{{ catalogPointPopup.point.name_point }}</span>
          <button class="popup-close" @click="closePopup" title="Cerrar">✕</button>
        </div>
        <div class="popup-meta">
          <span class="popup-type-badge" :class="catalogPointPopup.point.point_type === 1 ? 'type-stop' : 'type-ref'">
            {{ catalogPointPopup.point.point_type === 1 ? '🚌 Parada' : '📍 Referencia' }}
          </span>
          <span v-if="catalogPointPopup.point.is_checkpoint" class="popup-checkpoint">★ Checkpoint</span>
        </div>
        <div class="popup-actions" style="flex-wrap: wrap;">
          <button
            v-if="appStore.isCreatingRoute"
            class="popup-btn"
            style="background: #3b82f6; color: white; flex-basis: 100%; margin-bottom: 6px;"
            @click="appStore.addDraftStop(catalogPointPopup.point); closePopup()"
          >
            ➕ Añadir a ruta
          </button>
          <button class="popup-btn edit" @click="startPopupEdit">✏️ Editar</button>
          <button
            class="popup-btn"
            :class="catalogPointPopup.point.is_active !== false ? 'deactivate' : 'activate'"
            :disabled="popupToggling"
            @click="togglePopupPoint"
          >
            {{ popupToggling ? '⏳' : (catalogPointPopup.point.is_active !== false ? '🔴 Desactivar' : '🟢 Activar') }}
          </button>
        </div>
      </template>

      <!-- Modo edición -->
      <template v-else>
        <div class="popup-header">
          <span class="popup-title">Editando parada</span>
          <button class="popup-close" @click="cancelPopupEdit" title="Cancelar">✕</button>
        </div>
        <div class="popup-form">
          <input
            v-model="popupForm.name_point"
            type="text"
            class="popup-input"
            placeholder="Nombre *"
            @keydown.enter="savePopupEdit"
          />
          <input
            v-model="popupForm.descrip_point"
            type="text"
            class="popup-input"
            placeholder="Descripción"
          />
          <div class="popup-form-row">
            <select v-model="popupForm.point_type" class="popup-select">
              <option :value="1">Parada</option>
              <option :value="2">Referencia</option>
            </select>
            <label class="popup-checkbox">
              <input v-model="popupForm.is_checkpoint" type="checkbox" /> Checkpoint
            </label>
          </div>
          <div class="popup-relocate" :class="{ relocating: popupRelocating }">
            <span v-if="popupRelocating" class="relocating-hint">🖱️ Haz clic en el mapa para nueva posición...</span>
            <template v-else>
              <span class="popup-coords">📍 {{ popupForm.lat?.toFixed(5) }}, {{ popupForm.lng?.toFixed(5) }}</span>
              <button type="button" class="popup-btn-small" @click="startRelocate">Reubicar</button>
            </template>
          </div>
          <div v-if="popupEditError" class="popup-error">{{ popupEditError }}</div>
          <div class="popup-form-actions">
            <button class="popup-btn secondary" @click="cancelPopupEdit">Cancelar</button>
            <button class="popup-btn edit" :disabled="popupSaving" @click="savePopupEdit">
              {{ popupSaving ? '⏳' : '💾 Guardar' }}
            </button>
          </div>
        </div>
      </template>
    </div>
  </Transition>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useAppStore } from '../../stores/app'
import { updateRoutePoint, toggleRoutePoint } from '../../api/catalogs'

const appStore = useAppStore()

// ── Posicionamiento sobre el mapa ────────────────────────────
const POPUP_W     = 260
const POPUP_H_VIEW = 110
const POPUP_H_EDIT = 210
const ARROW_H     = 10

const catalogPointPopup = computed(() => appStore.catalogPointPopup)

const popupStyle = computed(() => {
  if (!catalogPointPopup.value) return {}
  const { x, y } = catalogPointPopup.value
  const popupH = popupEditing.value ? POPUP_H_EDIT : POPUP_H_VIEW
  let left = x - POPUP_W / 2
  let top  = y - popupH - ARROW_H - 11
  left = Math.max(8, left)
  return { left: left + 'px', top: top + 'px', width: POPUP_W + 'px' }
})

const closePopup = () => {
  appStore.catalogPointPopup = null
  popupEditing.value = false
  popupEditError.value = ''
}

// ── Modo edición ─────────────────────────────────────────────
const popupEditing   = ref(false)
const popupSaving    = ref(false)
const popupEditError = ref('')
const popupForm      = ref({})
const popupRelocating = ref(false)

const startPopupEdit = () => {
  const p = catalogPointPopup.value.point
  popupForm.value = {
    name_point:    p.name_point,
    descrip_point: p.descrip_point || '',
    point_type:    p.point_type,
    is_checkpoint: p.is_checkpoint || false,
    lat:           parseFloat(p.lat),
    lng:           parseFloat(p.lng)
  }
  popupEditError.value = ''
  popupRelocating.value = false
  popupEditing.value = true
}

const startRelocate = () => {
  popupRelocating.value = true
  appStore.isCreatingRoutePoint = true
  appStore.newRoutePointCoords = null
}

// Captura las nuevas coordenadas cuando el usuario hace clic en el mapa
watch(() => appStore.newRoutePointCoords, (coords) => {
  if (coords && popupRelocating.value) {
    popupForm.value.lat = coords[0]
    popupForm.value.lng = coords[1]
    appStore.isCreatingRoutePoint = false
    appStore.newRoutePointCoords = null
    popupRelocating.value = false
  }
})

const cancelPopupEdit = () => {
  if (popupRelocating.value) {
    appStore.isCreatingRoutePoint = false
    appStore.newRoutePointCoords = null
    popupRelocating.value = false
  }
  popupEditing.value = false
  popupEditError.value = ''
}

const savePopupEdit = async () => {
  popupEditError.value = ''
  if (!popupForm.value.name_point?.trim()) {
    popupEditError.value = 'El nombre es obligatorio.'
    return
  }
  popupSaving.value = true
  try {
    const p = catalogPointPopup.value.point
    const res = await updateRoutePoint(p.id_point, {
      name_point:    popupForm.value.name_point.trim(),
      descrip_point: popupForm.value.descrip_point.trim() || null,
      lat:           popupForm.value.lat,
      lng:           popupForm.value.lng,
      point_type:    popupForm.value.point_type,
      is_checkpoint: popupForm.value.is_checkpoint
    })
    if (res.success) {
      const idx = appStore.allCatalogPoints.findIndex(cp => cp.id_point === p.id_point)
      if (idx !== -1) {
        appStore.allCatalogPoints[idx] = {
          ...appStore.allCatalogPoints[idx],
          name_point:    popupForm.value.name_point.trim(),
          descrip_point: popupForm.value.descrip_point.trim() || null,
          lat:           popupForm.value.lat,
          lng:           popupForm.value.lng,
          point_type:    popupForm.value.point_type,
          is_checkpoint: popupForm.value.is_checkpoint
        }
      }
      appStore.catalogPointPopup = {
        ...appStore.catalogPointPopup,
        point: { ...p, ...appStore.allCatalogPoints[idx] }
      }
      popupEditing.value = false
    } else {
      popupEditError.value = res.message || 'Error al guardar.'
    }
  } catch (e) {
    popupEditError.value = e?.response?.data?.message || 'Error de conexión.'
  } finally {
    popupSaving.value = false
  }
}

// ── Toggle activo / inactivo ──────────────────────────────────
const popupToggling = ref(false)

const togglePopupPoint = async () => {
  const p = catalogPointPopup.value.point
  const newState = p.is_active === false ? true : false
  if (!confirm(`¿${newState ? 'Activar' : 'Desactivar'} "${p.name_point}"?`)) return
  popupToggling.value = true
  try {
    const res = await toggleRoutePoint(p.id_point, newState)
    if (res.success) {
      const idx = appStore.allCatalogPoints.findIndex(cp => cp.id_point === p.id_point)
      if (idx !== -1) appStore.allCatalogPoints[idx].is_active = newState
      closePopup()
    } else {
      alert(res.message || 'Error al cambiar estado.')
    }
  } catch (e) {
    alert('Error de conexión.')
  } finally {
    popupToggling.value = false
  }
}
</script>

<style scoped>
/* ═══════════════════════════════════════════════════════════
   CATALOG POINT POPUP OVERLAY
═══════════════════════════════════════════════════════════ */
.catalog-point-popup {
  position: absolute;
  z-index: 1200;
  background: white;
  border-radius: 10px;
  box-shadow: 0 6px 24px rgba(0,0,0,0.18), 0 2px 8px rgba(0,0,0,0.12);
  padding: 12px 14px 10px;
  pointer-events: all;
  min-width: 220px;
}

/* Flecha apuntando hacia abajo (hacia el marcador) */
.popup-arrow {
  position: absolute;
  bottom: -8px;
  left: 50%;
  transform: translateX(-50%);
  width: 0;
  height: 0;
  border-left: 8px solid transparent;
  border-right: 8px solid transparent;
  border-top: 8px solid white;
  filter: drop-shadow(0 2px 2px rgba(0,0,0,0.12));
}

.popup-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 8px;
  margin-bottom: 6px;
}

.popup-title {
  font-size: 0.92rem;
  font-weight: 700;
  color: #1e293b;
  line-height: 1.3;
  flex: 1;
  word-break: break-word;
}

.popup-close {
  background: none;
  border: none;
  cursor: pointer;
  color: #94a3b8;
  font-size: 0.8rem;
  padding: 0 2px;
  line-height: 1;
  flex-shrink: 0;
}
.popup-close:hover { color: #475569; }

.popup-meta {
  display: flex;
  gap: 6px;
  align-items: center;
  margin-bottom: 10px;
  flex-wrap: wrap;
}

.popup-type-badge {
  font-size: 0.72rem;
  padding: 2px 7px;
  border-radius: 8px;
  font-weight: 600;
}
.popup-type-badge.type-stop { background: #dcfce7; color: #166534; }
.popup-type-badge.type-ref  { background: #e0f2fe; color: #0369a1; }

.popup-checkpoint {
  font-size: 0.72rem;
  color: #d97706;
  font-weight: 600;
}

.popup-actions {
  display: flex;
  gap: 6px;
}

.popup-btn {
  flex: 1;
  padding: 5px 10px;
  border: none;
  border-radius: 7px;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s, opacity 0.15s;
  white-space: nowrap;
}
.popup-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.popup-btn.edit       { background: #3b82f6; color: white; }
.popup-btn.edit:hover:not(:disabled) { background: #2563eb; }
.popup-btn.deactivate { background: #fee2e2; color: #dc2626; }
.popup-btn.deactivate:hover:not(:disabled) { background: #fecaca; }
.popup-btn.activate   { background: #dcfce7; color: #16a34a; }
.popup-btn.activate:hover:not(:disabled) { background: #bbf7d0; }
.popup-btn.secondary  { background: #f1f5f9; color: #475569; }
.popup-btn.secondary:hover:not(:disabled) { background: #e2e8f0; }

/* Formulario edición */
.popup-form {
  display: flex;
  flex-direction: column;
  gap: 7px;
}

.popup-input {
  width: 100%;
  padding: 6px 9px;
  border: 1.5px solid #e2e8f0;
  border-radius: 7px;
  font-size: 0.82rem;
  color: #1e293b;
  background: #f8fafc;
  box-sizing: border-box;
}
.popup-input:focus { outline: none; border-color: #3b82f6; background: white; }

.popup-form-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.popup-select {
  flex: 1;
  padding: 5px 7px;
  border: 1.5px solid #e2e8f0;
  border-radius: 7px;
  font-size: 0.82rem;
  color: #1e293b;
  background: #f8fafc;
}

.popup-checkbox {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 0.8rem;
  color: #475569;
  cursor: pointer;
  white-space: nowrap;
}

.popup-error {
  font-size: 0.78rem;
  color: #dc2626;
}

.popup-relocate {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  padding: 4px 0;
}
.popup-relocate.relocating {
  background: #fef3c7;
  border-radius: 6px;
  padding: 5px 8px;
}
.popup-coords {
  font-size: 0.74rem;
  color: #64748b;
  font-family: monospace;
  flex: 1;
}
.relocating-hint {
  font-size: 0.78rem;
  color: #92400e;
  font-weight: 600;
}
.popup-btn-small {
  padding: 3px 9px;
  border: 1.5px solid #6366f1;
  border-radius: 6px;
  font-size: 0.76rem;
  font-weight: 600;
  color: #6366f1;
  background: white;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s;
}
.popup-btn-small:hover { background: #ede9fe; }

.popup-form-actions {
  display: flex;
  gap: 6px;
  margin-top: 2px;
}

/* Transición */
.popup-fade-enter-active,
.popup-fade-leave-active {
  transition: opacity 0.15s ease, transform 0.15s ease;
}
.popup-fade-enter-from,
.popup-fade-leave-to {
  opacity: 0;
  transform: translateY(6px);
}
</style>

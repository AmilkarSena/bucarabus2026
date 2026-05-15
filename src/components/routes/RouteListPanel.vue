<script setup>
import { computed, ref } from 'vue'
import { useAppStore } from '../../stores/app'
import { useRoutesStore } from '../../stores/routes'
import { useAuthStore } from '../../stores/auth'

const appStore = useAppStore()
const routesStore = useRoutesStore()
const authStore = useAuthStore()

const searchQuery = ref('')
const filterStatus = ref('active')

const routes = computed(() => {
  let list = routesStore.routesList

  if (filterStatus.value === 'active') {
    list = list.filter(r => r.isActive !== false)
  } else if (filterStatus.value === 'inactive') {
    list = list.filter(r => r.isActive === false)
  }

  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    list = list.filter(r => 
      (r.name && r.name.toLowerCase().includes(q)) || 
      (r.id && r.id.toString().includes(q)) ||
      (r.code && r.code.toLowerCase().includes(q))
    )
  }

  return list
})

const openNewRouteModal = () => {
  appStore.startRouteCreation()
}

const allRoutesVisible = computed(() => {
  if (routes.value.length === 0) return false
  return routes.value.every(route => route.visible)
})

const toggleAllRoutesAction = () => {
  if (allRoutesVisible.value) {
    routesStore.hideAllRoutes()
  } else {
    routesStore.showAllRoutes()
  }
}

const toggleAllRoutesText = computed(() => {
  if (routes.value.length === 0) return 'Mostrar Todas'
  return allRoutesVisible.value ? 'Ocultar Todas' : 'Mostrar Todas'
})

const editRoute = (route) => {
  appStore.openModal('editRoute', route)
}

const openPointsModal = (route) => {
  appStore.openModal('routePoints', route)
}

const deleteRoute = async (route) => {
  const confirmed = confirm(
    `¿Desactivar la ruta "${route.name}"?\n\nLa ruta quedará inactiva y ya no aparecerá en el mapa.\nPuedes reactivarla más adelante.`
  )

  if (confirmed) {
    try {
      await routesStore.deleteRoute(route.id)
      alert(`Ruta "${route.name}" desactivada exitosamente`)
    } catch (error) {
      console.error('Error desactivando ruta:', error)
      let errorMessage = 'Error al desactivar la ruta'
      if (error.code === 'ROUTE_NOT_FOUND') {
        errorMessage = '❌ La ruta no existe o ya fue desactivada.'
      } else {
        errorMessage += ':\n' + (error.message || 'Error desconocido')
      }
      alert(errorMessage)
    }
  }
}
</script>

<template>
  <div class="tab-actions">
    <button v-if="authStore.can('CREATE_ROUTES')" class="action-btn primary" @click="openNewRouteModal">
      <span class="btn-icon">➕</span>
      Nueva Ruta
    </button>
    <button class="action-btn secondary" @click="toggleAllRoutesAction" :disabled="routes.length === 0">
      <span class="btn-icon">🗺️</span>
      {{ toggleAllRoutesText }}
    </button>
  </div>

  <div class="filters-container">
    <div class="search-box">
      <span class="search-icon">🔍</span>
      <input 
        type="text" 
        v-model="searchQuery" 
        placeholder="Buscar ruta..." 
        class="search-input"
      />
    </div>
    <div class="filter-select-wrapper">
      <select v-model="filterStatus" class="status-filter">
        <option value="active">Rutas Activas</option>
        <option value="inactive">Rutas Inactivas</option>
        <option value="all">Todas las Rutas</option>
      </select>
    </div>
  </div>

  <div class="routes-list-scroll">
    <div class="routes-list">
      <div v-if="routes.length === 0" class="no-routes">
        No hay rutas registradas
      </div>
      <div v-else class="route-items">
        <div
          v-for="route in routes"
          :key="route.id"
          class="route-item"
          :class="{ 'route-active': route.visible, 'route-inactive': route.isActive === false }"
        >
          <div class="route-color-strip" :style="{ backgroundColor: route.color || '#667eea' }"></div>
          <div class="route-main">
            <div class="route-name-row">
              <span class="route-id">{{ route.id }}</span>
              <span class="route-name">{{ route.name }}</span>
            </div>
            <span class="route-meta">
              <span title="Puntos">📍{{ route.points?.length || 0 }}</span>
              <span title="Buses">🚌{{ route.buses?.length || 0 }}</span>
              <span v-if="route.firstTrip" title="Primer viaje">🕐{{ route.firstTrip.substring(0, 5) }}</span>
            </span>
          </div>
          <div class="route-actions">
            <button
              class="icon-btn"
              :class="{ 'icon-btn-focused': routesStore.focusedRouteId === route.id }"
              @click="routesStore.focusRoute(route.id)"
              :title="routesStore.focusedRouteId === route.id ? 'Quitar foco del mapa' : 'Ver en mapa con paradas numeradas'"
            >{{ routesStore.focusedRouteId === route.id ? '🎯' : '👁️' }}</button>
            <button
              v-if="authStore.can('EDIT_ROUTES')"
              class="icon-btn"
              @click="openPointsModal(route)"
              title="Gestionar puntos"
            >📍</button>
            <button
              v-if="authStore.can('EDIT_ROUTES')"
              class="icon-btn"
              @click="editRoute(route)"
              title="Editar ruta"
            >✏️</button>
          </div>
        </div>
      </div>
    </div>
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
.action-btn.primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}
.action-btn.primary:hover {
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
.btn-icon {
  font-size: 1.1rem;
}
.filters-container {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 12px;
}
.search-box {
  position: relative;
  display: flex;
  align-items: center;
}
.search-icon {
  position: absolute;
  left: 10px;
  font-size: 0.9rem;
  color: #94a3b8;
}
.search-input {
  width: 100%;
  padding: 8px 10px 8px 30px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.9rem;
  outline: none;
  transition: border-color 0.2s;
}
.search-input:focus {
  border-color: #667eea;
}
.filter-select-wrapper {
  position: relative;
  width: 100%;
}
.status-filter {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.85rem;
  color: #475569;
  background-color: #f8fafc;
  outline: none;
  cursor: pointer;
  transition: all 0.2s;
  appearance: none;
}
.status-filter:focus {
  border-color: #667eea;
  box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.1);
}
.filter-select-wrapper::after {
  content: '▼';
  font-size: 0.6rem;
  color: #94a3b8;
  position: absolute;
  right: 12px;
  top: 50%;
  transform: translateY(-50%);
  pointer-events: none;
}
.routes-list-scroll {
  max-height: calc(100vh - 420px);
  overflow-y: auto;
  margin: 0 -20px;
  padding: 0 20px 20px 20px;
}
.routes-list-scroll::-webkit-scrollbar {
  width: 6px;
}
.routes-list-scroll::-webkit-scrollbar-track {
  background: #f1f5f9;
  border-radius: 10px;
}
.routes-list-scroll::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 10px;
}
.routes-list-scroll::-webkit-scrollbar-thumb:hover {
  background: #94a3b8;
}
.no-routes {
  text-align: center;
  padding: 40px 20px;
  color: #94a3b8;
  font-size: 0.95rem;
}
.route-items {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.route-item {
  background: white;
  border: 1.5px solid #e2e8f0;
  border-radius: 10px;
  display: flex;
  align-items: center;
  gap: 0;
  overflow: hidden;
  transition: all 0.2s ease;
}
.route-item:hover {
  border-color: #667eea;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.12);
}
.route-item.route-active {
  border-color: #10b981;
  background: #f0fdf4;
}
.route-item.route-inactive {
  opacity: 0.6;
  background: #f8fafc;
}
.route-item.route-inactive .route-name {
  text-decoration: line-through;
  color: #94a3b8;
}
.route-color-strip {
  width: 5px;
  align-self: stretch;
  flex-shrink: 0;
}
.route-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 8px 10px;
  min-width: 0;
}
.route-name {
  font-size: 0.9rem;
  font-weight: 600;
  color: #1e293b;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.route-meta {
  display: flex;
  gap: 10px;
  font-size: 0.75rem;
  color: #94a3b8;
}
.route-meta span {
  display: flex;
  align-items: center;
  gap: 2px;
}
.route-name-row {
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}
.route-id {
  font-family: monospace;
  font-size: 0.7rem;
  color: #cbd5e1;
  flex-shrink: 0;
}
.route-actions {
  display: flex;
  gap: 2px;
  padding: 0 6px;
  flex-shrink: 0;
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
.icon-btn:hover {
  background: #f1f5f9;
}
.icon-btn-focused {
  background: #eef2ff !important;
  border-color: #667eea !important;
  color: #667eea !important;
  box-shadow: 0 0 0 2px rgba(102, 126, 234, 0.25);
}

/* Responsive */
@media (max-width: 768px) {
  .tab-actions {
    gap: 8px;
    margin-bottom: 12px;
  }

  .action-btn {
    padding: 10px;
    font-size: 0.8rem;
    border-radius: 8px;
  }

  .filters-container {
    display: grid;
    grid-template-columns: 1.5fr 1fr;
    gap: 8px;
    margin-bottom: 10px;
  }

  .search-input {
    font-size: 0.85rem;
    padding: 8px 10px 8px 28px;
  }

  .status-filter {
    font-size: 0.8rem;
    padding: 8px;
  }

  .routes-list-scroll {
    max-height: 40vh;
    margin: 0 -12px;
    padding: 0 12px 12px;
  }

  .route-item {
    border-radius: 8px;
  }

  .route-main {
    padding: 10px 8px;
  }

  .route-name {
    font-size: 0.85rem;
  }

  .icon-btn {
    width: 38px;
    height: 38px;
    font-size: 1.1rem;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
  }
}
</style>

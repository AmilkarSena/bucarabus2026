<template>
  <div class="route-catalog">
    <div class="catalog-header">
      <h2>Catálogo de Rutas</h2>
      <p class="subtitle">Explora todas las rutas disponibles</p>
      
      <div class="search-container">
        <span class="search-icon">🔍</span>
        <input 
          type="text" 
          v-model="searchQuery" 
          placeholder="Buscar por nombre de ruta o parada..." 
          class="search-input"
        >
        <button v-if="searchQuery" @click="searchQuery = ''" class="btn-clear">✕</button>
      </div>
    </div>

    <div class="catalog-content">
      <div v-if="filteredRoutes.length === 0" class="no-results">
        <span>🚌</span>
        <p>No se encontraron rutas que coincidan con "{{ searchQuery }}"</p>
      </div>

      <div class="routes-list" v-else>
        <div 
          v-for="route in filteredRoutes" 
          :key="route.id" 
          class="route-card"
          :class="{ expanded: expandedRouteId === route.id }"
        >
          <!-- Cabecera de la Tarjeta (Clickable) -->
          <div class="route-header" @click="toggleRoute(route.id)">
            <div class="route-color-indicator" :style="{ backgroundColor: route.color }"></div>
            <div class="route-info">
              <h3 class="route-name">{{ route.name }}</h3>
              <div class="route-meta">
                <span>{{ route.stops?.length || 0 }} paradas</span>
                <span v-if="route.fare > 0">· ${{ route.fare }}</span>
              </div>
              <div v-if="route.matchedStop" class="match-info">
                Pasa por: <strong>{{ route.matchedStop }}</strong>
              </div>
            </div>
            <div class="expand-icon">{{ expandedRouteId === route.id ? '▲' : '▼' }}</div>
          </div>

          <!-- Contenido Expandido (Paradas) -->
          <div v-if="expandedRouteId === route.id" class="route-details">
            <div class="route-actions">
              <button class="btn-view-map" @click="$emit('view-on-map', route)">
                🗺️ Ver ruta en el mapa
              </button>
            </div>
            
            <div class="stops-timeline" v-if="route.stops && route.stops.length > 0">
              <div v-for="(stop, index) in route.stops" :key="index" class="stop-item">
                <div class="stop-node" :style="{ borderColor: route.color }"></div>
                <div class="stop-line" v-if="index < route.stops.length - 1" :style="{ backgroundColor: route.color }"></div>
                <div class="stop-info">
                  <span class="stop-name" v-html="highlightMatch(stop.name_point, searchQuery)"></span>
                </div>
              </div>
            </div>
            <div v-else class="no-stops">
              <p>Esta ruta no tiene paradas registradas.</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'

const props = defineProps({
  routes: {
    type: Array,
    required: true,
    default: () => []
  }
})

defineEmits(['view-on-map'])

const searchQuery = ref('')
const expandedRouteId = ref(null)

// Filtrar rutas por nombre de ruta o nombre de parada
const filteredRoutes = computed(() => {
  const query = searchQuery.value.toLowerCase().trim()
  if (!query) {
    return props.routes.map(r => ({ ...r, matchedStop: null }))
  }

  return props.routes.filter(route => {
    // 1. Buscar en el nombre de la ruta
    if (route.name.toLowerCase().includes(query)) {
      route.matchedStop = null
      return true
    }

    // 2. Buscar en las paradas
    if (route.stops && route.stops.length > 0) {
      const matchedStop = route.stops.find(stop => 
        stop.name_point && stop.name_point.toLowerCase().includes(query)
      )
      
      if (matchedStop) {
        route.matchedStop = matchedStop.name_point
        return true
      }
    }

    return false
  }).map(r => {
    // Si la búsqueda coincide con una ruta por nombre, no mostramos el matchedStop
    if (r.name.toLowerCase().includes(query)) {
      return { ...r, matchedStop: null }
    }
    return r
  })
})

const toggleRoute = (id) => {
  expandedRouteId.value = expandedRouteId.value === id ? null : id
}

// Resalta el texto buscado en el nombre de la parada
const highlightMatch = (text, query) => {
  if (!text || !query) return text || 'Parada sin nombre'
  const escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const regex = new RegExp(`(${escapedQuery})`, 'gi')
  return text.replace(regex, '<mark>$1</mark>')
}
</script>

<style scoped>
.route-catalog {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #f5f7fa;
  overflow: hidden;
}

.catalog-header {
  background: white;
  padding: 20px 16px 16px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
  z-index: 10;
}

.catalog-header h2 {
  margin: 0;
  font-size: 1.5rem;
  color: #1f2937;
}

.subtitle {
  margin: 4px 0 16px;
  color: #6b7280;
  font-size: 0.9rem;
}

.search-container {
  position: relative;
  display: flex;
  align-items: center;
}

.search-icon {
  position: absolute;
  left: 12px;
  color: #9ca3af;
}

.search-input {
  width: 100%;
  padding: 12px 36px 12px 36px;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  font-size: 1rem;
  background: #f9fafb;
  transition: all 0.2s;
  box-sizing: border-box;
}

.search-input:focus {
  outline: none;
  border-color: #667eea;
  background: white;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.btn-clear {
  position: absolute;
  right: 12px;
  background: none;
  border: none;
  color: #9ca3af;
  font-size: 1rem;
  cursor: pointer;
  padding: 4px;
}

.catalog-content {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
}

.no-results {
  text-align: center;
  padding: 40px 20px;
  color: #6b7280;
}

.no-results span {
  font-size: 3rem;
  display: block;
  margin-bottom: 12px;
  opacity: 0.5;
}

.routes-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-bottom: 40px; /* Espacio extra al final */
}

.route-card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 6px rgba(0,0,0,0.04);
  overflow: hidden;
  transition: all 0.2s ease;
}

.route-card:active {
  transform: scale(0.98);
}

.route-header {
  display: flex;
  align-items: center;
  padding: 16px;
  cursor: pointer;
}

.route-color-indicator {
  width: 6px;
  height: 48px;
  border-radius: 3px;
  margin-right: 16px;
}

.route-info {
  flex: 1;
}

.route-name {
  margin: 0 0 4px 0;
  font-size: 1.1rem;
  color: #1f2937;
}

.route-meta {
  font-size: 0.85rem;
  color: #6b7280;
}

.match-info {
  margin-top: 6px;
  font-size: 0.85rem;
  color: #4f46e5;
  background: #eef2ff;
  padding: 4px 8px;
  border-radius: 6px;
  display: inline-block;
}

.expand-icon {
  color: #9ca3af;
  font-size: 0.8rem;
  margin-left: 12px;
}

.route-details {
  border-top: 1px solid #f3f4f6;
  padding: 16px;
  background: #fafafa;
}

.route-actions {
  margin-bottom: 20px;
}

.btn-view-map {
  width: 100%;
  padding: 12px;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  font-weight: 600;
  color: #4f46e5;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  transition: all 0.2s;
}

.btn-view-map:hover {
  background: #f9fafb;
  border-color: #d1d5db;
}

.stops-timeline {
  position: relative;
  padding-left: 10px;
}

.stop-item {
  position: relative;
  padding-bottom: 16px;
  padding-left: 24px;
}

.stop-item:last-child {
  padding-bottom: 0;
}

.stop-node {
  position: absolute;
  left: 0;
  top: 4px;
  width: 12px;
  height: 12px;
  background: white;
  border: 3px solid;
  border-radius: 50%;
  z-index: 2;
  box-sizing: border-box;
}

.stop-line {
  position: absolute;
  left: 5px;
  top: 16px;
  bottom: 0;
  width: 2px;
  opacity: 0.3;
  z-index: 1;
}

.stop-name {
  font-size: 0.95rem;
  color: #374151;
  line-height: 1.4;
}

:deep(mark) {
  background: #fef08a;
  color: #854d0e;
  padding: 0 2px;
  border-radius: 2px;
}

.no-stops {
  text-align: center;
  color: #9ca3af;
  font-size: 0.9rem;
  padding: 10px;
}
</style>

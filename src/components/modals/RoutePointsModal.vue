<template>
  <div class="route-points-container">
    <div class="header-actions">
      <h3>
        📍 Ruta: {{ data?.name || '...' }} 
        <span class="badge">{{ points.length }} puntos</span>
      </h3>
      <button class="btn secondary" @click="closeModal">Cerrar</button>
    </div>

    <!-- Mensajes de estado -->
    <div v-if="error" class="error-msg">❌ {{ error }}</div>
    
    <!-- Lista de Puntos Asignados -->
    <div class="points-list-container">
      <div v-if="isLoading" class="loading-state">Cargando puntos...</div>
      
      <div v-else-if="points.length === 0" class="empty-state">
        <p>Esta ruta no tiene puntos asignados aún.</p>
      </div>
      
      <ul v-else class="points-list">
        <li v-for="(point, index) in points" :key="point.idPoint" class="point-item">
          <div class="point-order">{{ point.pointOrder }}</div>
          <div class="point-info">
            <strong>{{ point.namePoint }}</strong>
            <span class="point-coords">Lat: {{ point.coordinates[0]?.toFixed(4) }}, Lng: {{ point.coordinates[1]?.toFixed(4) }}</span>
          </div>
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useAppStore } from '../../stores/app'
import { useRoutesStore } from '../../stores/routes'

const props = defineProps({
  data: {
    type: Object,
    required: true
  }
})

const appStore = useAppStore()
const routesStore = useRoutesStore()

const points = ref([])
const isLoading = ref(false)
const error = ref('')

const loadPoints = async () => {
  if (!props.data?.id) return
  isLoading.value = true
  error.value = ''
  
  try {
    const routeId = props.data.id
    if (routesStore.routes[routeId] && routesStore.routes[routeId].stops) {
      points.value = routesStore.routes[routeId].stops.map(s => ({
        idPoint: s.id_point,
        namePoint: s.name_point,
        coordinates: [s.lat, s.lng],
        pointOrder: s.point_order
      }))
    } else {
      points.value = []
    }
  } catch (err) {
    console.error('Error cargando puntos:', err)
    error.value = 'No se pudieron cargar los puntos de la ruta.'
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  loadPoints()
})

const closeModal = () => {
  appStore.closeModal()
}
</script>

<style scoped>
.route-points-container {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.header-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 10px;
}

.header-actions h3 {
  margin: 0;
  display: flex;
  align-items: center;
  gap: 10px;
}

.badge {
  background: #4f46e5;
  color: white;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 0.8rem;
}

.points-list-container {
  background: #fff;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  max-height: 400px;
  overflow-y: auto;
}

.points-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.point-item {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid #f1f5f9;
  gap: 16px;
  transition: background 0.2s;
}

.point-item:last-child {
  border-bottom: none;
}

.point-item:hover {
  background: #f8fafc;
}

.point-order {
  width: 28px;
  height: 28px;
  background: #e2e8f0;
  color: #334155;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  font-size: 0.9rem;
}

.point-info {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.point-coords {
  font-size: 0.8rem;
  color: #64748b;
  margin-top: 2px;
}

.btn {
  padding: 8px 16px;
  border-radius: 6px;
  border: none;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn.primary {
  background: #667eea;
  color: white;
}

.btn.secondary {
  background: #f1f5f9;
  color: #475569;
}

.btn:hover:not(:disabled) {
  opacity: 0.9;
}

.error-msg {
  color: #ef4444;
  background: #fef2f2;
  padding: 10px;
  border-radius: 6px;
  font-size: 0.9rem;
}

.empty-state, .loading-state {
  padding: 30px;
  text-align: center;
  color: #64748b;
}
</style>


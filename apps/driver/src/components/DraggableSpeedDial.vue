<template>
  <div 
    class="draggable-fab-container"
    :style="{ transform: `translate(${x}px, ${y}px)` }"
    ref="container"
  >
    <!-- Opciones (Burbujas) -->
    <transition name="fade-scale">
      <div v-if="isOpen" class="speed-dial-menu">
        <button
          v-for="(type, index) in incidentTypes"
          :key="type.value"
          class="dial-item"
          :style="getDialItemStyle(index)"
          @click.stop="selectIncident(type)"
          :title="type.label"
        >
          <span class="dial-icon">{{ type.icon }}</span>
          <span class="dial-label">{{ type.label }}</span>
        </button>
      </div>
    </transition>

    <!-- Botón Principal -->
    <button 
      class="fab-main shadow-2xl"
      :class="{ 'is-open': isOpen, 'is-dragging': isDragging }"
      @mousedown="onPress"
      @touchstart.passive="onPress"
      @click="onClick"
    >
      <span v-if="!isOpen" class="main-icon text-3xl">🚨</span>
      <span v-else class="main-icon text-2xl">✕</span>
    </button>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const emit = defineEmits(['report'])

const container = ref(null)
const isOpen = ref(false)

// Estado del arrastre
const isTracking = ref(false)
const isDragging = ref(false)
let hasDragged = false
const startPos = ref({ x: 0, y: 0 })
const initialTransform = ref({ x: 0, y: 0 })

// Posición actual (empezamos abajo a la derecha de forma predeterminada, 
// pero usaremos window bounds para calcular la inicial después de montar)
const x = ref(0)
const y = ref(0)
const BUTTON_SIZE = 64
const MARGIN = 20

// Datos de incidentes
const incidentTypes = ref([])

const getIconForTag = (tag) => {
  const icons = {
    road_closed: '🚧',
    accident: '🚗',
    protest: '✊',
    detour: '🔀',
    flood: '🌊',
    danger: '⚠️'
  }
  return icons[tag] || '📍'
}

const loadIncidentTypes = async () => {
  try {
    const baseURL = import.meta.env.VITE_API_URL || 'http://localhost:3001/api'
    const response = await fetch(`${baseURL.replace(/\/api$/, '')}/api/catalogs/incident-types`)
    const data = await response.json()
    if (data.success) {
      incidentTypes.value = data.data.map(t => ({
        value: t.id_incident,
        label: t.name_incident,
        icon: getIconForTag(t.tag_incident),
        tag: t.tag_incident
      }))
    }
  } catch (error) {
    console.error('Error cargando tipos de incidentes:', error)
  }
}

// Inicializar posición inferior derecha
onMounted(async () => {
  await loadIncidentTypes()
  
  // Esperar a que renderice para obtener tamaño ventana
  x.value = window.innerWidth - BUTTON_SIZE - MARGIN
  y.value = window.innerHeight - BUTTON_SIZE - MARGIN - 80 // 80px extra para evitar controles de abajo

  window.addEventListener('mousemove', onDrag)
  window.addEventListener('mouseup', stopDrag)
  window.addEventListener('touchmove', onDrag, { passive: false })
  window.addEventListener('touchend', stopDrag)
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('mousemove', onDrag)
  window.removeEventListener('mouseup', stopDrag)
  window.removeEventListener('touchmove', onDrag)
  window.removeEventListener('touchend', stopDrag)
  window.removeEventListener('resize', handleResize)
})

const handleResize = () => {
  // Ajustar si la ventana cambia de tamaño
  if (x.value > window.innerWidth - BUTTON_SIZE) x.value = window.innerWidth - BUTTON_SIZE - MARGIN
  if (y.value > window.innerHeight - BUTTON_SIZE) y.value = window.innerHeight - BUTTON_SIZE - MARGIN
}

const getEventPos = (e) => {
  if (e.touches && e.touches.length > 0) {
    return { clientX: e.touches[0].clientX, clientY: e.touches[0].clientY }
  } else if (e.changedTouches && e.changedTouches.length > 0) {
    return { clientX: e.changedTouches[0].clientX, clientY: e.changedTouches[0].clientY }
  }
  return { clientX: e.clientX, clientY: e.clientY }
}

const onPress = (e) => {
  const pos = getEventPos(e)
  startPos.value = { x: pos.clientX, y: pos.clientY }
  initialTransform.value = { x: x.value, y: y.value }
  isTracking.value = true
  isDragging.value = false
  hasDragged = false
}

const onDrag = (e) => {
  if (!isTracking.value) return

  const pos = getEventPos(e)
  const dx = pos.clientX - startPos.value.x
  const dy = pos.clientY - startPos.value.y

  // Tolerancia de 10px para diferenciar un "Tap" de un "Drag"
  if (!isDragging.value) {
    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
      isDragging.value = true
      hasDragged = true
    } else {
      return // Aún no cruzamos el umbral
    }
  }
  
  if (isOpen.value) isOpen.value = false // cerrar si se está arrastrando
  if (e.cancelable) e.preventDefault() // Prevenir scroll al arrastrar
  
  let newX = initialTransform.value.x + dx
  let newY = initialTransform.value.y + dy

  // Limites de pantalla
  const maxX = window.innerWidth - BUTTON_SIZE
  const maxY = window.innerHeight - BUTTON_SIZE
  
  newX = Math.max(0, Math.min(newX, maxX))
  newY = Math.max(0, Math.min(newY, maxY))

  x.value = newX
  y.value = newY
}

const stopDrag = (e) => {
  isTracking.value = false
  isDragging.value = false
}

const onClick = (e) => {
  if (!hasDragged) {
    toggleMenu()
  }
}

const toggleMenu = () => {
  isOpen.value = !isOpen.value
}

// Calcular posiciones del menú radial
const getDialItemStyle = (index) => {
  const total = incidentTypes.value.length
  // Si está cerca del borde derecho, las burbujas salen hacia la izquierda
  const isRightSide = x.value > window.innerWidth / 2
  // Si está cerca del borde superior, las burbujas salen hacia abajo
  const isTopSide = y.value < window.innerHeight / 2

  // Configuración de un semicírculo/arco
  const radius = 90
  
  // Calcular ángulos basados en la esquina donde está el botón
  let startAngle, endAngle
  
  if (isRightSide && !isTopSide) { // Bottom Right
    startAngle = 180
    endAngle = 270
  } else if (!isRightSide && !isTopSide) { // Bottom Left
    startAngle = 270
    endAngle = 360
  } else if (isRightSide && isTopSide) { // Top Right
    startAngle = 90
    endAngle = 180
  } else { // Top Left
    startAngle = 0
    endAngle = 90
  }

  // Distribución de ángulos
  const angleStep = (endAngle - startAngle) / Math.max(1, total - 1)
  const angle = startAngle + (angleStep * index)
  
  const rad = angle * (Math.PI / 180)
  const itemX = Math.round(radius * Math.cos(rad))
  const itemY = Math.round(radius * Math.sin(rad))

  return {
    transform: `translate(${itemX}px, ${itemY}px)`,
    transitionDelay: `${index * 0.05}s`
  }
}

const selectIncident = (type) => {
  isOpen.value = false
  emit('report', {
    incidentId: type.value,
    tag: type.tag,
    name: type.label,
    description: '' // Omitimos descripción para máxima velocidad
  })
}
</script>

<style scoped>
.draggable-fab-container {
  position: fixed;
  top: 0;
  left: 0;
  width: 64px;
  height: 64px;
  z-index: 9999;
  will-change: transform;
  touch-action: none;
}

.fab-main {
  width: 64px;
  height: 64px;
  border-radius: 50%;
  background: linear-gradient(135deg, #ef4444, #b91c1c);
  border: 4px solid rgba(255, 255, 255, 0.2);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: grab;
  position: absolute;
  top: 0;
  left: 0;
  z-index: 10;
  transition: background 0.3s, border-color 0.3s;
}

.fab-main:active {
  cursor: grabbing;
}

.fab-main.is-open {
  background: #1e293b;
  border-color: rgba(255, 255, 255, 0.1);
}

.fab-main.is-dragging {
  transform: scale(1.05);
  box-shadow: 0 15px 35px rgba(239, 68, 68, 0.6);
}



.main-icon {
  line-height: 1;
  pointer-events: none;
}

/* Speed Dial Menu */
.speed-dial-menu {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 5;
}

.dial-item {
  position: absolute;
  width: 56px;
  height: 56px;
  top: 4px;
  left: 4px;
  background: rgba(15, 23, 42, 0.95);
  border: 2px solid rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(8px);
  border-radius: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: white;
  box-shadow: 0 10px 25px rgba(0,0,0,0.3);
  transition: transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
}

.dial-item:hover, .dial-item:active {
  background: rgba(30, 41, 59, 1);
  border-color: rgba(239, 68, 68, 0.5);
}

.dial-icon {
  font-size: 20px;
  margin-bottom: -2px;
}

.dial-label {
  font-size: 8px;
  font-weight: 700;
  text-transform: uppercase;
  text-align: center;
  line-height: 1;
  opacity: 0.9;
}

/* Transitions */
.fade-scale-enter-active,
.fade-scale-leave-active {
  transition: opacity 0.3s, transform 0.3s;
}

.fade-scale-enter-from,
.fade-scale-leave-to {
  opacity: 0;
}

.fade-scale-enter-from .dial-item,
.fade-scale-leave-to .dial-item {
  transform: translate(0, 0) scale(0) !important;
  opacity: 0;
}
</style>

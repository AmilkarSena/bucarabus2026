import { ref, watch } from 'vue'
import { detectNearbyStops } from '../utils/routeUtils'
import { getRoutePoints } from '../api/catalogs'

/**
 * Composable para detectar paradas cercanas a una ruta dibujada.
 * Encapsula el estado del umbral de distancia y la lógica de búsqueda.
 * 
 * @param {Object} options
 * @param {Ref} options.formData - Referencia reactiva al formulario de la ruta (debe contener .path)
 * @param {Object} options.props - Props del componente (para evaluar isEdit)
 * @param {Object} options.appStore - Store principal de la aplicación (para caché de catálogos)
 */
export function useRouteStopDetection({ formData, props, appStore }) {
  const detectedStops = ref([])
  const threshold = ref(80)
  const loadingDetection = ref(false)

  const runDetection = async () => {
    const path = formData.value.path
    
    // Si estamos editando, o no hay trazado suficiente, limpiamos las paradas detectadas
    if (props.isEdit || !path || path.length < 2) {
      detectedStops.value = []
      return
    }
    
    loadingDetection.value = true
    
    try {
      // Cargar puntos del catálogo si no están en memoria
      if (!appStore.allCatalogPoints.length) {
        const res = await getRoutePoints()
        if (res?.success) {
          appStore.allCatalogPoints = res.data
        }
      }
      // Calcular las paradas que caen dentro del umbral
      detectedStops.value = detectNearbyStops(path, appStore.allCatalogPoints, threshold.value)
    } catch (error) {
      console.error('Error durante la detección de paradas:', error)
    } finally {
      loadingDetection.value = false
    }
  }

  let debounceTimeout = null
  const debouncedRunDetection = () => {
    if (debounceTimeout) clearTimeout(debounceTimeout)
    debounceTimeout = setTimeout(() => {
      runDetection()
    }, 300)
  }

  // Reactividad: volver a detectar si cambia el dibujo o el umbral
  watch(() => formData.value.path, debouncedRunDetection, { immediate: true })
  watch(threshold, debouncedRunDetection)

  return {
    detectedStops,
    threshold,
    loadingDetection,
    runDetection
  }
}

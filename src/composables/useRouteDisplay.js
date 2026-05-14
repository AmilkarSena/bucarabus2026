import { watch } from 'vue'
import L from 'leaflet'

/**
 * Composable que orquesta la representación visual de las rutas geométricas en el mapa Leaflet.
 * 
 * Responsabilidades:
 * 1. Dibujo de Polilíneas: Renderiza los trazos de las rutas activas o enfocadas usando los colores 
 *    corporativos definidos en el sistema.
 * 2. Visualización de Paradas: Cuando una ruta se "enfoca", dibuja marcadores circulares numerados 
 *    para identificar visualmente la secuencia de abordaje y los nombres de las paradas.
 * 3. Enfoque Dinámico (Focus): Ajusta automáticamente el zoom (fitBounds) para centrar la vista 
 *    en la ruta seleccionada, optimizando la navegación del usuario.
 * 4. Gestión de Capas: Asegura que las polilíneas y marcadores se limpien correctamente al 
 *    cambiar de contexto o desmontar el componente.
 *
 * @param {Object} options - Dependencias del mapa y stores de Pinia.
 */



export function useRouteDisplay({ getMap, appStore, routesStore }) {
  let focusedMarkers = []

  // ── Limpiar todas las polilíneas del mapa ───────────────────────────
  const clearRoutesFromMap = () => {
    const leafletMap = getMap()
    if (!leafletMap) return
    leafletMap.eachLayer((layer) => {
      if (layer instanceof L.Polyline) {
        leafletMap.removeLayer(layer)
      }
    })
  }

  // ── Dibujar rutas activas (o la ruta enfocada) ──────────────────────
  const displayRoutes = () => {
    const leafletMap = getMap()
    if (!leafletMap) {
      console.log('⚠️ displayRoutes: Mapa no inicializado')
      return
    }

    clearRoutesFromMap()

    // Si estamos creando una ruta, ocultar todas las polilíneas.
    // Si hay ruta enfocada, mostrar solo esa; si no, todas las activas.
    const routesToDraw = appStore.isCreatingRoute
      ? []
      : (routesStore.focusedRouteId
          ? [routesStore.focusedRouteId]
          : [...routesStore.activeRoutes])

    routesToDraw.forEach(routeId => {
      const route = routesStore.getRouteById(routeId)
      if (route && route.path && route.path.length > 1) {
        const polyline = L.polyline(route.path, {
          color:   route.color || '#666',
          weight:  routesStore.focusedRouteId === routeId ? 6 : 4,
          opacity: routesStore.focusedRouteId === routeId ? 1 : 0.8
        }).addTo(leafletMap)

        polyline.bindPopup(`
          <div style="font-family: sans-serif;">
            <h4 style="margin: 0 0 8px 0; color: ${route.color || '#666'}">${route.name}</h4>
            <p style="margin: 4px 0; font-size: 12px;"><strong>ID:</strong> ${route.id}</p>
            ${route.fare ? `<p style="margin: 4px 0; font-size: 12px;"><strong>Tarifa:</strong> $${route.fare} COP</p>` : ''}
            <p style="margin: 4px 0; font-size: 12px;"><strong>Puntos:</strong> ${route.path.length}</p>
          </div>
        `)

        routesStore.setRoutePolyline(routeId, polyline)

        // Centrar el mapa en la primera ruta dibujada
        if (routesToDraw[0] === routeId) {
          leafletMap.fitBounds(polyline.getBounds(), { padding: [50, 50] })
        }
      }
    })
  }

  // ── Watcher: ruta enfocada → marcadores numerados de paradas ────────
  watch(
    () => routesStore.focusedRouteId,
    (newId) => {
      const leafletMap = getMap()
      if (!leafletMap) return

      // Limpiar paradas numeradas anteriores
      focusedMarkers.forEach(m => leafletMap.removeLayer(m))
      focusedMarkers = []

      // Redibujar polilíneas (solo la enfocada o todas)
      displayRoutes()

      if (newId) {
        const route = routesStore.getRouteById(newId)
        if (route && route.stops && route.stops.length > 0) {
          route.stops.forEach((stop, index) => {
            const marker = L.marker([parseFloat(stop.lat), parseFloat(stop.lng)], {
              icon: L.divIcon({
                className: 'focused-point-marker',
                html: `<div style="background: ${route.color || '#3b82f6'}; color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-weight: bold; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3); font-size: 12px;">${index + 1}</div>`,
                iconSize: [24, 24],
                iconAnchor: [12, 12]
              }),
              zIndexOffset: 1500
            }).addTo(leafletMap)

            marker.bindTooltip(`<b>${stop.name_point}</b><br>Parada ${index + 1}`, { direction: 'top' })
            focusedMarkers.push(marker)
          })
        }
      }
    }
  )

  // ── Limpieza al desmontar ────────────────────────────────────────────
  const cleanup = () => {
    const leafletMap = getMap()
    if (!leafletMap) return
    focusedMarkers.forEach(m => leafletMap.removeLayer(m))
    focusedMarkers = []
    clearRoutesFromMap()
  }

  return { displayRoutes, clearRoutesFromMap, cleanup }
}

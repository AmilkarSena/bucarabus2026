import { watch } from 'vue'
import L from 'leaflet'

/**
 * Composable especializado en la gestión de puntos de infraestructura (paraderos y referencias).
 * 
 * Este módulo centraliza la visualización del "Catálogo de Puntos" en el mapa:
 * 1. Categorización Visual: Diferencia entre Paradas (verdes), Checkpoints (amarillos) 
 *    y Puntos de Referencia (azules) mediante iconografía dinámica.
 * 2. Modo Creación: Permite capturar coordenadas temporales mediante clics en el mapa 
 *    y gestionar los marcadores de la ruta que se está diseñando en ese momento.
 * 3. Interacción Granular: Implementa eventos de clic para añadir paradas a una ruta 
 *    o abrir el panel de edición de detalles del punto.
 * 4. Reactividad Sincronizada: Mantiene los marcadores actualizados automáticamente 
 *    cuando cambia el catálogo en el store de Pinia.
 *
 * @param {Object} options - Dependencias y estados reactivos necesarios para la gestión de puntos.
 */
export function useCatalogPoints({
  getMap,
  appStore,
  catalogPointsVisible,
  allCatalogPoints,
  selectedRoutePoints
}) {
  let catalogMarkers = []
  let referenceMarkers = []
  let tempCreationMarker = null

  // ── Marcador temporal al capturar coordenadas con clic en mapa ──
  watch(
    () => appStore.newRoutePointCoords,
    (newCoords) => {
      const leafletMap = getMap()
      console.log('👀 MapComponent: Watcher detectó cambio en coordenadas:', newCoords)
      if (!leafletMap) {
        console.error('❌ MapComponent: LeafletMap no está inicializado en el watcher')
        return
      }

      // Limpiar marcador anterior
      if (tempCreationMarker) {
        console.log('🧹 MapComponent: Limpiando marcador temporal anterior')
        leafletMap.removeLayer(tempCreationMarker)
        tempCreationMarker = null
      }

      // Agregar nuevo marcador si hay coordenadas capturadas
      if (newCoords) {
        console.log('🎨 MapComponent: Dibujando nuevo marcador en', newCoords)
        tempCreationMarker = L.marker(newCoords, {
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
              cursor: pointer;
              z-index: 9999;
            ">📍</div>`,
            iconSize: [30, 30],
            iconAnchor: [15, 15]
          }),
          zIndexOffset: 2000
        }).addTo(leafletMap)

        // Centrar suavemente hacia el nuevo punto capturado
        leafletMap.panTo(newCoords)
      }
    },
    { immediate: true }
  )

  // ── Marcadores azules de referencia (puntos seleccionados en Opción B) ──
  watch(
    selectedRoutePoints,
    (points) => {
      const leafletMap = getMap()
      if (!leafletMap) return
      // Limpiar marcadores anteriores
      referenceMarkers.forEach(m => leafletMap.removeLayer(m))
      referenceMarkers = []
      // Dibujar nuevos marcadores azules para cada parada seleccionada
      points.forEach((point, i) => {
        const marker = L.marker([point.lat, point.lng], {
          icon: L.divIcon({
            className: 'ref-point-marker',
            html: `<div style="
              background: #3b82f6;
              color: white;
              border-radius: 50%;
              width: 28px;
              height: 28px;
              display: flex;
              align-items: center;
              justify-content: center;
              font-size: 11px;
              font-weight: 700;
              border: 3px solid white;
              box-shadow: 0 2px 8px rgba(59,130,246,0.6);
            ">${i + 1}</div>`,
            iconSize: [28, 28],
            iconAnchor: [14, 14]
          }),
          zIndexOffset: 1500
        }).addTo(leafletMap)
        marker.bindTooltip(point.namePoint, { permanent: false, direction: 'top' })
        referenceMarkers.push(marker)
      })
    },
    { deep: true }
  )

  // ── Marcadores del catálogo completo (puntos verdes/amarillos) ──
  watch(
    [catalogPointsVisible, allCatalogPoints],
    ([visible, points]) => {
      const leafletMap = getMap()
      if (!leafletMap) return
      console.log('📍 Watcher catálogo - visible:', visible, '| puntos:', points?.length)
      // Limpiar marcadores anteriores
      catalogMarkers.forEach(m => leafletMap.removeLayer(m))
      catalogMarkers = []
      if (!visible || !points?.length) return

      points.filter(point => point.is_active !== false).forEach(point => {
        const isCheckpoint = point.is_checkpoint
        const color = isCheckpoint ? '#f59e0b' : '#10b981'
        const marker = L.marker([parseFloat(point.lat), parseFloat(point.lng)], {
          icon: L.divIcon({
            className: 'catalog-point-marker',
            html: `<div style="
              background: ${color};
              color: white;
              border-radius: 50%;
              width: 14px;
              height: 14px;
              display: flex;
              align-items: center;
              justify-content: center;
              font-size: 10px;
              border: 2px solid white;
              box-shadow: 0 2px 4px rgba(0,0,0,0.3);
            ">${isCheckpoint ? '★' : ''}</div>`,
            iconSize: [14, 14],
            iconAnchor: [7, 7]
          }),
          zIndexOffset: 500
        }).addTo(leafletMap)

        const typeLabel = point.point_type === 1 ? 'Parada' : 'Referencia'
        const cpLabel = isCheckpoint ? ' · Checkpoint' : ''
        marker.bindTooltip(`<b>${point.name_point}</b><br>${typeLabel}${cpLabel}`, {
          permanent: false,
          direction: 'top'
        })

        // Clic → añadir a ruta si está en modo creación, o abrir popup de edición
        marker.on('click', (e) => {
          L.DomEvent.stopPropagation(e)

          if (appStore.isCreatingRoute) {
            appStore.addDraftStop(point)
            return
          }

          const containerPoint = leafletMap.latLngToContainerPoint(marker.getLatLng())
          const mapEl = leafletMap.getContainer()
          const mapRect = mapEl.getBoundingClientRect()
          appStore.catalogPointPopup = {
            point: { ...point },
            x: containerPoint.x,
            y: containerPoint.y,
            mapRect
          }
        })

        catalogMarkers.push(marker)
      })
    },
    { deep: true }
  )

  // ── Limpieza al desmontar ──
  const cleanup = () => {
    const leafletMap = getMap()
    if (!leafletMap) return
    catalogMarkers.forEach(m => leafletMap.removeLayer(m))
    referenceMarkers.forEach(m => leafletMap.removeLayer(m))
    if (tempCreationMarker) leafletMap.removeLayer(tempCreationMarker)
    catalogMarkers = []
    referenceMarkers = []
    tempCreationMarker = null
  }

  return { cleanup }
}

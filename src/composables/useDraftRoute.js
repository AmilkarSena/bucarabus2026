import { watch } from 'vue'
import L from 'leaflet'
import { detectNearbyStops } from '../utils/routeUtils'

/**
 * Composable que encapsula el "Motor de Diseño" para la creación de nuevas rutas.
 * 
 * Este módulo gestiona el comportamiento inteligente del trazado:
 * 1. Smart Routing (OSRM): Se conecta a los servidores de OSRM para calcular trayectos 
 *    que sigan el sentido de las vías y las calles reales, en lugar de líneas rectas.
 * 2. Auto-Detección de Paradas: Mediante algoritmos de proximidad geográfica, detecta 
 *    si el trazo de la ruta pasa cerca (≤5m) de paradas existentes y las integra 
 *    automáticamente al itinerario.
 * 3. Cache de Segmentos: Mantiene un historial de trayectos calculados para optimizar 
 *    el rendimiento al reordenar o añadir paradas.
 * 4. Representación Dual: Soporta tanto trazado inteligente (calles) como trazado manual 
 *    (líneas rectas) para tramos especiales.
 *
 * @param {Object} options - Dependencias del mapa y estado del borrador.
 */
export function useDraftRoute({ getMap, appStore }) {

  // ── Estado interno ────────────────────────────────────────────────
  let draftPolyline       = null
  let draftMarkers        = []
  let draftOsrmController = null
  let isAutoUpdatingStops = false
  let previousStopsLength = 0
  const draftRouteCache   = new Map()   // expuesto para que MapComponent pueda hacer .clear()

  // ── Utilidades OSRM ──────────────────────────────────────────────

  /** Distancia en metros entre dos puntos [lat, lng] (fórmula Haversine) */
  const haversineMeters = ([lat1, lng1], [lat2, lng2]) => {
    const R = 6371000
    const dLat = (lat2 - lat1) * Math.PI / 180
    const dLng = (lng2 - lng1) * Math.PI / 180
    const a = Math.sin(dLat / 2) ** 2
            + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  }

  /** Elimina waypoints demasiado cercanos (<minMeters). Conserva siempre el primero y el último. */
  const simplifyWaypoints = (points, minMeters = 60) => {
    if (points.length <= 2) return points
    const result = [points[0]]
    for (let i = 1; i < points.length - 1; i++) {
      if (haversineMeters(result[result.length - 1], points[i]) >= minMeters) {
        result.push(points[i])
      }
    }
    result.push(points[points.length - 1])
    return result
  }

  /**
   * Llama al endpoint OSRM (perfil driving) y retorna { path, distance } o null.
   * @param {Array} points   - Lista de [lat, lng]
   * @param {AbortSignal} signal - Para cancelar peticiones obsoletas
   */
  // OSRM espera waypoints que son los que forman el trazado, no las paradas. El trazado puede ser más detallado que las paradas si OSRM inserta puntos intermedios para seguir las calles.
  const fetchOsrmSnap = async (points, signal) => {        // OSRM espera waypoints como "lng,lat;lng,lat;..."
    const simplified = simplifyWaypoints(points)
    const waypoints  = simplified.map(([lat, lng]) => `${lng},${lat}`).join(';')
    try {
      const res = await fetch(
        `${import.meta.env.VITE_API_URL || 'http://localhost:3001/api'}/geocoding/route?waypoints=${encodeURIComponent(waypoints)}`,
        { signal }
      )
      if (!res.ok) return null
      const data = await res.json()
      if (data.code === 'Ok' && data.routes?.[0]?.geometry?.coordinates?.length > 1) {
        return {
          path:     data.routes[0].geometry.coordinates.map(([lng, lat]) => [lat, lng]),
          distance: data.routes[0].distance
        }
      }
    } catch (e) {
      if (e.name !== 'AbortError') console.warn('[OSRM] Error:', e.message)
    }
    return null
  }

  // ── Watcher 1: calcular el path OSRM cuando cambian las paradas ──
  watch(
    [() => appStore.draftStops, () => appStore.useSmartRouting],
    async ([stops, useSmartRouting]) => {
      const currentLength = stops ? stops.length : 0

      if (!stops || currentLength < 2) {
        appStore.draftPath = null
        previousStopsLength = currentLength
        return
      }

      // ¿El usuario agregó manualmente un punto?
      const isNewStopAddedManually = currentLength > previousStopsLength && !isAutoUpdatingStops
      previousStopsLength = currentLength

      // Cancelar petición OSRM anterior
      if (draftOsrmController) draftOsrmController.abort()
      draftOsrmController = new AbortController()

      let fullPath = []

      // Agrupar paradas en chunks por modo (smart / recto)
      let chunks = []
      if (stops.length > 1) {
        let currentMode  = stops[1].useSmartRouting !== undefined ? stops[1].useSmartRouting : useSmartRouting
        let currentChunk = { mode: currentMode, stops: [stops[0], stops[1]] }

        for (let i = 2; i < stops.length; i++) {
          const mode = stops[i].useSmartRouting !== undefined ? stops[i].useSmartRouting : useSmartRouting
          if (mode === currentChunk.mode) {
            currentChunk.stops.push(stops[i])
          } else {
            chunks.push(currentChunk)
            currentChunk = { mode, stops: [stops[i - 1], stops[i]] }
          }
        }
        chunks.push(currentChunk)
      }

      // Calcular cada chunk (con caché para evitar peticiones repetidas)
      for (const chunk of chunks) {
        const chunkId  = chunk.stops.map(s => s.id_point).join(',')
        const cacheKey = chunkId + '_' + chunk.mode

        if (draftRouteCache.has(cacheKey)) {
          fullPath.push(...draftRouteCache.get(cacheKey))
          continue
        }

        const points = chunk.stops.map(s => [parseFloat(s.lat), parseFloat(s.lng)])

        if (chunk.mode) {
          // Trazado inteligente por OSRM
          const res = await fetchOsrmSnap(points, draftOsrmController.signal)
          if (draftOsrmController.signal.aborted) return  // nueva actualización llegó

          if (res && res.path) {
            draftRouteCache.set(cacheKey, res.path)
            fullPath.push(...res.path)
          } else {
            // Fallback: líneas rectas si OSRM falla
            const straight = []
            for (let i = 1; i < points.length; i++) straight.push(points[i - 1], points[i])
            draftRouteCache.set(cacheKey, straight)
            fullPath.push(...straight)
          }
        } else {
          // Líneas rectas (trazado manual)
          const straight = []
          for (let i = 1; i < points.length; i++) straight.push(points[i - 1], points[i])
          draftRouteCache.set(cacheKey, straight)
          fullPath.push(...straight)
        }
      }

      appStore.draftPath = fullPath

      // Auto-insertar paradas intermedias del catálogo que caigan sobre el path
      if (fullPath.length > 0) {
        if (isAutoUpdatingStops) {
          isAutoUpdatingStops = false
          return
        }
        if (!isNewStopAddedManually) return

        // Detecta paradas del catálogo a ≤5 m del path
        const detected   = detectNearbyStops(fullPath, appStore.allCatalogPoints, 5, Infinity)
        const currentIds = stops.map(s => s.id_point).join(',')
        const detectedIds = detected.map(d => d.idPoint).join(',')

        if (currentIds !== detectedIds) {
          const allOriginalPreserved = stops.every(s => detected.some(d => d.idPoint === s.id_point))
          if (allOriginalPreserved && detected.length > stops.length) {
            const newDraftStops = detected.map(d => {
              const cp           = appStore.allCatalogPoints.find(p => p.id_point === d.idPoint)
              const originalStop = stops.find(s => s.id_point === d.idPoint)
              return {
                id_point:        cp.id_point,
                name_point:      cp.name_point,
                lat:             cp.lat,
                lng:             cp.lng,
                useSmartRouting: originalStop ? originalStop.useSmartRouting : useSmartRouting,
                cachedSegment:   originalStop ? originalStop.cachedSegment   : undefined
              }
            })
            isAutoUpdatingStops = true
            appStore.draftStops = newDraftStops
          }
        }
      }
    },
    { deep: true }
  )

  // ── Watcher 2: dibujar polilínea y marcadores del borrador ──────
  watch(
    [() => appStore.draftStops, () => appStore.draftPath],
    ([stops, path]) => {
      const leafletMap = getMap()
      if (!leafletMap) return

      // Limpiar dibujo anterior
      if (draftPolyline) {
        leafletMap.removeLayer(draftPolyline)
        draftPolyline = null
      }
      draftMarkers.forEach(m => leafletMap.removeLayer(m))
      draftMarkers = []

      if (!stops || stops.length === 0) return

      // Marcadores numerados de cada parada del borrador
      stops.forEach((stop, index) => {
        const marker = L.marker([stop.lat, stop.lng], {
          icon: L.divIcon({
            className: 'draft-point-marker',
            html: `<div style="background: var(--draft-color, #3b82f6); color: white; border-radius: 50%; width: 24px; height: 24px; display: flex; align-items: center; justify-content: center; font-weight: bold; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3); font-size: 12px;">${index + 1}</div>`,
            iconSize:   [24, 24],
            iconAnchor: [12, 12]
          }),
          zIndexOffset: 2000
        }).addTo(leafletMap)
        draftMarkers.push(marker)
      })

      // Polilínea del borrador (OSRM o líneas rectas)
      const pathCoords = path || stops.map(s => [parseFloat(s.lat), parseFloat(s.lng)])
      if (pathCoords.length > 1) {
        draftPolyline = L.polyline(pathCoords, {
          color:   appStore.draftRouteColor,
          weight:  3,
          opacity: 0.9
        }).addTo(leafletMap)
      }
    },
    { deep: true }
  )

  // ── Watcher 3: actualizar color de la polilínea en tiempo real ──
  watch(() => appStore.draftRouteColor, (newColor) => {
    if (draftPolyline) draftPolyline.setStyle({ color: newColor })
  })

  // ── Limpieza al desmontar ────────────────────────────────────────
  const cleanup = () => {
    const leafletMap = getMap()
    if (draftOsrmController) draftOsrmController.abort()
    if (leafletMap) {
      if (draftPolyline) leafletMap.removeLayer(draftPolyline)
      draftMarkers.forEach(m => leafletMap.removeLayer(m))
    }
    draftPolyline = null
    draftMarkers  = []
    draftRouteCache.clear()
  }

  return {
    draftRouteCache,  // expuesto para que el watcher de isCreatingRoute pueda hacer .clear()
    cleanup
  }
}

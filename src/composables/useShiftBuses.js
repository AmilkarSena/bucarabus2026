import { getActiveShifts } from '../api/shifts'
import { getBusColor } from '@shared/utils/busColors'
import L from 'leaflet'

/**
 * Composable especializado en la monitorización visual de buses que están actualmente en viaje.
 * 
 * A diferencia del seguimiento por GPS puro, este módulo gestiona buses en "modo despacho":
 * 1. Tracking por Progreso: Si un bus no tiene telemetría GPS activa, proyecta su posición 
 *    matemáticamente sobre el path de la ruta basándose en el porcentaje de progreso reportado.
 * 2. Iconografía de Turnos: Utiliza un diseño de marcador con pulsación rítmica (pulse-ring) 
 *    para indicar que el bus está cumpliendo un viaje programado.
 * 3. Animación de Transición: Implementa interpolación cúbica para mover los marcadores 
 *    suavemente entre actualizaciones, simulando un movimiento natural en el mapa.
 * 4. Cache Inteligente: Mantiene datos de conductores y rutas para enriquecer los popups sin 
 *    realizar peticiones API redundantes.
 *
 * @param {Object} options - Dependencias del mapa y estados reactivos.
 * @returns {Object} { displayShiftBuses, clearShiftBusMarkers, shiftDataCache }
 */
export function useShiftBuses({ getMap, routesStore, busLocations }) {
  const shiftBusMarkers = new Map()
  const shiftDataCache = new Map()

  // ─── Animar suavemente un marcador de una posición a otra ───
  const animateMarker = (marker, targetPosition, duration = 1000) => {
    if (marker._animationId) {
      cancelAnimationFrame(marker._animationId)
    }

    const start = marker.getLatLng()
    const startLat = start.lat
    const startLng = start.lng
    const targetLat = targetPosition[0]
    const targetLng = targetPosition[1]

    const distance = Math.sqrt(
      Math.pow(targetLat - startLat, 2) + Math.pow(targetLng - startLng, 2)
    )
    if (distance < 0.00001) return

    const startTime = performance.now()

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      const easeProgress = progress

      const currentLat = startLat + (targetLat - startLat) * easeProgress
      const currentLng = startLng + (targetLng - startLng) * easeProgress

      marker.setLatLng([currentLat, currentLng])

      if (progress < 1) {
        marker._animationId = requestAnimationFrame(animate)
      } else {
        marker._animationId = null
      }
    }

    marker._animationId = requestAnimationFrame(animate)
  }

  // ─── Calcular posición del bus en una ruta según el porcentaje de progreso ───
  const getPositionOnRoute = (path, progressPercent) => {
    if (!path || path.length < 2) return null

    let totalLength = 0
    const segments = []

    for (let i = 0; i < path.length - 1; i++) {
      const [lat1, lng1] = path[i]
      const [lat2, lng2] = path[i + 1]
      const length = Math.sqrt(Math.pow(lat2 - lat1, 2) + Math.pow(lng2 - lng1, 2))
      segments.push({ start: path[i], end: path[i + 1], length })
      totalLength += length
    }

    const targetDistance = (progressPercent / 100) * totalLength

    let accumulatedLength = 0
    for (const segment of segments) {
      if (accumulatedLength + segment.length >= targetDistance) {
        const segmentProgress = (targetDistance - accumulatedLength) / segment.length
        const lat = segment.start[0] + (segment.end[0] - segment.start[0]) * segmentProgress
        const lng = segment.start[1] + (segment.end[1] - segment.start[1]) * segmentProgress
        return [lat, lng]
      }
      accumulatedLength += segment.length
    }

    return path[path.length - 1]
  }

  // ─── Crear icono de bus para turnos activos ───
  const createShiftBusIcon = (bus, routeColor) => {
    const color = getBusColor(bus.id)
    const ring = routeColor || '#667eea'

    return L.divIcon({
      className: 'shift-bus-marker',
      html: `
        <div style="
          position: relative;
          width: 40px;
          height: 40px;
          display: flex;
          align-items: center;
          justify-content: center;
        ">
          <div style="
            position: absolute;
            width: 40px;
            height: 40px;
            background: ${ring}30;
            border-radius: 50%;
            animation: pulse-ring 2s ease-out infinite;
          "></div>
          <div style="
            width: 32px;
            height: 32px;
            background: linear-gradient(135deg, ${color} 0%, ${color}dd 100%);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            box-shadow: 0 4px 12px ${color}50;
            border: 3px solid white;
            z-index: 10;
          ">🚌</div>
        </div>
      `,
      iconSize: [40, 40],
      iconAnchor: [20, 20],
      popupAnchor: [0, -20]
    })
  }

  // ─── Generar popup para bus de turno activo ───
  const getShiftBusPopup = (bus, routeName, routeColor) => {
    return `
      <div style="font-family: sans-serif; min-width: 200px;">
        <h4 style="margin: 0 0 8px 0; color: ${routeColor}; display: flex; align-items: center; gap: 6px;">
          🚌 ${bus.placa}
          <span style="font-size: 10px; background: #d1fae5; color: #065f46; padding: 2px 6px; border-radius: 8px;">EN RUTA</span>
        </h4>
        
        <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>
        
        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          👨‍✈️ <strong>Conductor:</strong> ${bus.conductor || 'Sin asignar'}
        </p>
        
        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          📍 <strong>Ruta:</strong> <span style="color: ${routeColor}; font-weight: 600;">${routeName}</span>
        </p>
        
        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          📊 <strong>Progreso:</strong> ${bus.progreso_ruta}%
        </p>
        <div style="width: 100%; height: 8px; background: #e2e8f0; border-radius: 4px; margin: 6px 0; overflow: hidden;">
          <div style="width: ${bus.progreso_ruta}%; height: 100%; background: ${routeColor}; transition: width 0.5s;"></div>
        </div>
        
        <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>
        
        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          ✅ <strong>Viajes completados:</strong> ${bus.viajes_completados || 0}
        </p>
      </div>
    `
  }

  // ─── Mostrar buses de turnos activos en el mapa ───
  const displayShiftBuses = async () => {
    const leafletMap = getMap()
    if (!leafletMap) {
      console.log('⚠️ displayShiftBuses: Mapa no inicializado')
      return
    }

    try {
      console.log('🚌 Cargando buses de turnos activos...')
      const shifts = await getActiveShifts()

      const currentBusIds = new Set()

      shifts.forEach(shift => {
        // Ignorar viajes que no estén en progreso (ej. finalizados o pendientes)
        if (shift.status_trip !== 3) return

        const busId = shift.plate_number

        // Poblar cache para enriquecer popups GPS
        shiftDataCache.set(busId, {
          ambCode: shift.amb_code || null,
          conductor: shift.name_driver || null,
          driverId: shift.id_driver || null,
          routeName: shift.name_route || 'Ruta',
          routeColor: shift.color_route || '#667eea'
        })

        // Si tiene GPS activo, no mostrar marcador de turno
        if (busLocations.value.has(busId)) {
          console.log(`⏭️ Bus ${busId} tiene GPS activo - saltando marcador de turno`)
          if (shiftBusMarkers.has(busId)) {
            leafletMap.removeLayer(shiftBusMarkers.get(busId))
            shiftBusMarkers.delete(busId)
            console.log(`🗑️ Marcador de turno eliminado para ${busId} (ahora usando GPS)`)
          }
          return
        }

        currentBusIds.add(busId)

        let routePath = null
        const storeRoute = routesStore.routes[shift.id_route]

        if (storeRoute && storeRoute.path) {
          routePath = storeRoute.path
        } else if (shift.path_route && shift.path_route.coordinates) {
          routePath = shift.path_route.coordinates.map(coord => [coord[1], coord[0]])
        }

        if (!routePath || routePath.length < 2) {
          console.log(`⚠️ Bus ${busId}: Sin path de ruta`)
          return
        }

        const position = getPositionOnRoute(routePath, shift.progress_percentage || 0)
        if (!position) {
          console.log(`⚠️ Bus ${busId}: No se pudo calcular posición`)
          return
        }

        const busData = {
          id: busId,
          placa: shift.amb_code || shift.plate_number,
          conductor: shift.name_driver || 'Sin asignar',
          progreso_ruta: shift.progress_percentage || 0,
          viajes_completados: shift.trips_completed || 0
        }

        const routeColor = shift.color_route || '#667eea'
        const routeName = shift.name_route || 'Ruta'

        if (shiftBusMarkers.has(busId)) {
          const marker = shiftBusMarkers.get(busId)
          animateMarker(marker, position, 1800)
          marker.setPopupContent(getShiftBusPopup(busData, routeName, routeColor))
        } else {
          const icon = createShiftBusIcon(busData, routeColor)
          const marker = L.marker(position, { icon })
            .bindPopup(getShiftBusPopup(busData, routeName, routeColor))
            .addTo(leafletMap)

          shiftBusMarkers.set(busId, marker)
          console.log(`✅ Marcador creado: ${busData.placa} en ruta ${routeName}`)
        }
      })

      // Eliminar marcadores de buses que ya no están activos
      shiftBusMarkers.forEach((marker, busId) => {
        if (!currentBusIds.has(busId)) {
          leafletMap.removeLayer(marker)
          shiftBusMarkers.delete(busId)
          console.log(`🗑️ Marcador eliminado: ${busId}`)
        }
      })

      console.log(`🚌 Total buses en mapa (sin GPS): ${shiftBusMarkers.size}`)

    } catch (error) {
      console.error('❌ Error mostrando buses de turnos:', error)
    }
  }

  // ─── Limpiar marcadores de buses de turnos ───
  const clearShiftBusMarkers = () => {
    const leafletMap = getMap()
    shiftBusMarkers.forEach((marker) => {
      if (leafletMap) leafletMap.removeLayer(marker)
    })
    shiftBusMarkers.clear()
  }

  return {
    displayShiftBuses,
    clearShiftBusMarkers,
    shiftDataCache
  }
}

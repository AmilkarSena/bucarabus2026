import L from 'leaflet'
import { getBusColor } from '@shared/utils/busColors'

/**
 * Composable especializado en la representación visual y seguimiento de la flota en tiempo real.
 * 
 * Este módulo actúa como el puente entre los datos del Store (Pinia) y la capa visual (Leaflet).
 * Sus responsabilidades principales son:
 * 1. Cálculo de Ubicación: Implementa una lógica de fallback para determinar dónde está el bus.
 *    - Prioridad 1: Coordenadas GPS reales recibidas del dispositivo.
 *    - Prioridad 2: Estimación matemática basada en el progreso de la ruta (proyectada sobre el path).
 *    - Prioridad 3: Posición por defecto en el centro de la ciudad (Bucaramanga).
 * 2. Iconografía Dinámica: Genera iconos SVG/DivIcon personalizados que cambian de color según la placa
 *    y muestran un punto de estado (Activo/Inactivo).
 * 3. Popups Informativos: Crea interfaces ricas dentro del mapa con barras de progreso y datos del conductor.
 * 4. Sincronización de Marcadores: Mantiene el mapa actualizado, animando el movimiento de los buses
 *    para evitar saltos bruscos entre actualizaciones de GPS.
 *
 * @param {Object} options - Dependencias inyectadas desde el componente de mapa.
 * @param {Function} options.getMap - Retorna la instancia de Leaflet activa.
 * @param {Map} options.busMarkers - Almacén reactivo de marcadores para evitar duplicados.
 * @param {Object} options.busesStore - Store de buses para acceder a la telemetría.
 * @param {Object} options.routesStore - Store de rutas para colorear y proyectar caminos.
 * @returns {Object} Métodos para orquestar la visualización de buses.
 */
export function useBusDisplay({ getMap, busMarkers, busesStore, routesStore }) {

  // ── Calcular posición del bus ────────────────────────────────────────
  const getBusLocation = (bus) => {
    // Coordenadas GPS directas
    if (bus.latitud !== null && bus.longitud !== null) {
      const route = bus.ruta_actual ? routesStore.getRouteById(bus.ruta_actual) : null
      return { lat: bus.latitud, lng: bus.longitud, route }
    }

    // Posición estimada por progreso en la ruta
    if (bus.ruta_actual) {
      const location = busesStore.calculateBusLocation(bus)
      if (location.lat !== null && location.lng !== null) {
        const route = routesStore.getRouteById(bus.ruta_actual)
        return { lat: location.lat, lng: location.lng, route }
      }
    }

    // Posición por defecto: centro de Bucaramanga
    return { lat: 7.1193, lng: -73.1227, route: null }
  }

  // ── HTML del popup del bus ───────────────────────────────────────────
  const getBusPopupContent = (bus, route) => {
    const lastUpdate = bus.ultima_actualizacion
      ? new Date(bus.ultima_actualizacion).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
      : 'Sin actualizar'

    return `
      <div style="font-family: sans-serif; min-width: 220px;">
        <h4 style="margin: 0 0 8px 0; color: ${route ? route.color : '#666'}; display: flex; align-items: center; gap: 6px;">
          🚌 ${bus.placa}
          ${bus.status_bus ? '<span style="font-size: 10px; background: #d1fae5; color: #065f46; padding: 2px 6px; border-radius: 8px;">ACTIVO</span>' : ''}
        </h4>

        <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>

        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          👨‍✈️ <strong>Conductor:</strong> ${bus.conductor_nombre || 'Sin asignar'}
        </p>

        ${route ? `
          <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
            📍 <strong>Ruta:</strong> <span style="color: ${route.color}; font-weight: 600;">${route.name}</span>
          </p>
          <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
            📊 <strong>Progreso:</strong> ${bus.progreso_ruta || 0}%
          </p>
          <div style="width: 100%; height: 6px; background: #e2e8f0; border-radius: 3px; margin: 6px 0; overflow: hidden;">
            <div style="width: ${bus.progreso_ruta || 0}%; height: 100%; background: ${route.color}; transition: width 0.3s;"></div>
          </div>
        ` : ''}

        ${bus.latitud && bus.longitud ? `
          <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>
          <p style="margin: 4px 0; font-size: 11px; color: #94a3b8; font-family: monospace;">
            🌍 GPS: ${bus.latitud.toFixed(6)}, ${bus.longitud.toFixed(6)}
          </p>
          <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
            🚗 <strong>Velocidad:</strong> ${bus.velocidad || 0} km/h
          </p>
          <p style="margin: 4px 0; font-size: 11px; color: #94a3b8;">
            🕐 Actualizado: ${lastUpdate}
          </p>
        ` : ''}

        <div style="border-bottom: 1px solid #e2e8f0; margin: 8px 0;"></div>

        <p style="margin: 4px 0; font-size: 12px; color: #64748b;">
          ✅ <strong>Viajes hoy:</strong> ${bus.viajes_completados || 0}
        </p>
      </div>
    `
  }

  // ── Icono personalizado por placa ────────────────────────────────────
  const createBusIcon = (bus) => {
    const color = getBusColor(bus.placa || String(bus.id_bus))
    const statusColor = bus.status_bus ? '#10b981' : '#ef4444'
    const busLabel = bus.placa ? bus.placa.slice(-3) : bus.id_bus.toString()

    return L.divIcon({
      className: 'bus-marker',
      html: `
        <div class="bus-marker-container" style="position: relative;">
          <div class="bus-marker-icon" style="
            background: ${color};
            width: 36px;
            height: 36px;
            border-radius: 50%;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            border: 2px solid white;
            box-shadow: 0 2px 8px rgba(0,0,0,0.3);
            position: relative;
            z-index: 2;
          ">
            <div style="font-size: 16px; line-height: 1;">🚌</div>
            <div style="
              font-size: 8px;
              font-weight: bold;
              color: white;
              margin-top: -1px;
              text-shadow: 0 1px 2px rgba(0,0,0,0.5);
              letter-spacing: 0.3px;
            ">${busLabel}</div>
          </div>
          <div class="bus-status-dot" style="
            position: absolute;
            top: -1px;
            right: -1px;
            width: 12px;
            height: 12px;
            background: ${statusColor};
            border: 2px solid white;
            border-radius: 50%;
            z-index: 3;
            box-shadow: 0 1px 3px rgba(0,0,0,0.3);
          "></div>
        </div>
      `,
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -18]
    })
  }

  // ── Sincronizar marcadores de buses con el store ─────────────────────
  const displayBuses = () => {
    const leafletMap = getMap()
    if (!leafletMap) return

    const activeBusesWithRoutes = busesStore.buses.filter(
      bus => bus.status_bus && bus.ruta_actual
    )

    // Eliminar marcadores de buses que ya no están activos
    busMarkers.forEach((marker, busId) => {
      const busExists = activeBusesWithRoutes.find(b => b.id_bus === busId)
      if (!busExists) {
        leafletMap.removeLayer(marker)
        busMarkers.delete(busId)
      }
    })

    // Crear o actualizar marcadores
    activeBusesWithRoutes.forEach(bus => {
      const location = getBusLocation(bus)
      const route = location.route

      if (busMarkers.has(bus.id_bus)) {
        // Actualizar posición con animación suave
        const marker = busMarkers.get(bus.id_bus)
        const currentLatLng = marker.getLatLng()
        const newLatLng = L.latLng(location.lat, location.lng)
        const duration = 1500
        const startTime = Date.now()

        // Cancelar animación anterior si existe para evitar solapamientos
        if (marker.animationFrameId) {
          cancelAnimationFrame(marker.animationFrameId)
        }

        const animate = () => {
          const elapsed = Date.now() - startTime
          const progress = Math.min(elapsed / duration, 1)
          const lat = currentLatLng.lat + (newLatLng.lat - currentLatLng.lat) * progress
          const lng = currentLatLng.lng + (newLatLng.lng - currentLatLng.lng) * progress
          marker.setLatLng([lat, lng])
          if (progress < 1) {
            marker.animationFrameId = requestAnimationFrame(animate)
          } else {
            marker.animationFrameId = null
          }
        }
        marker.animationFrameId = requestAnimationFrame(animate)

        marker.setPopupContent(getBusPopupContent(bus, route))
      } else {
        // Crear nuevo marcador
        const icon = createBusIcon(bus)
        const marker = L.marker([location.lat, location.lng], { icon })
          .addTo(leafletMap)
          .bindPopup(getBusPopupContent(bus, route))
        busMarkers.set(bus.id_bus, marker)
      }
    })
  }

  return { displayBuses, getBusPopupContent, createBusIcon, getBusLocation }
}

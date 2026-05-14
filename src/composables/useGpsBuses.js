import { watch } from 'vue'
import { getBusColor } from '@shared/utils/busColors'
import L from 'leaflet'

/**
 * Composable especializado en la representación visual de la telemetría GPS en tiempo real.
 * 
 * Gestiona marcadores de alta prioridad en el mapa con las siguientes características:
 * 1. Visualización de Orientación (Heading): Rota el icono del bus dinámicamente para indicar 
 *    la dirección en la que se está moviendo el vehículo.
 * 2. Diseño de "Streaming": Utiliza animaciones de pulso y transiciones fluidas para 
 *    reflejar el flujo constante de datos desde el WebSocket.
 * 3. Popups Enriquecidos: Combina las coordenadas GPS crudas con datos de negocio 
 *    (conductor, ruta, placa AMB) extraídos del caché de turnos.
 * 4. Gestión de Capas: Los marcadores GPS tienen un `zIndex` superior para asegurar 
 *    que siempre sean visibles por encima de otros elementos del mapa.
 */
export function useGpsBuses({ getMap, busLocations, busLocationsArray, shiftDataCache }) {
  const gpsMarkers = new Map()

  // ─── Crear icono para bus con GPS en tiempo real ───
  const createGpsIcon = (busData) => {
    const color = getBusColor(busData.busId)
    const heading = busData.heading || 0

    const cached = shiftDataCache.get(busData.busId) || {}
    const ambCode = busData.ambCode || cached.ambCode || busData.busId || '---'
    const ambStripped = ambCode.includes('-') ? ambCode.split('-').pop() : ambCode
    const ambLabel = ambStripped.length > 8 ? ambStripped.slice(0, 8) : ambStripped

    return L.divIcon({
      className: 'gps-bus-marker',
      html: `
        <div style="position:relative;display:flex;flex-direction:column;align-items:center;width:34px;">
          <!-- Pulso de fondo -->
          <div style="
            position:absolute;top:0;left:50%;transform:translateX(-50%);
            width:46px;height:46px;border-radius:50%;
            background:${color}35;
            animation:gps-pulse 2s ease-out infinite;
            z-index:0;
          "></div>
          <!-- Círculo principal -->
          <div style="
            background:linear-gradient(135deg,${color} 0%,${color}cc 100%);
            width:32px;height:32px;border-radius:50%;
            display:flex;align-items:center;justify-content:center;
            border:2.5px solid white;
            box-shadow:0 3px 8px rgba(0,0,0,0.35);
            position:relative;z-index:1;
            transform:rotate(${heading}deg);
          ">
            <span style="font-size:16px;line-height:1;transform:rotate(-${heading}deg);">🚌</span>
          </div>
          <!-- Etiqueta AMB -->
          <div style="
            margin-top:2px;
            background:#1f2937;color:white;
            font-size:9px;font-weight:700;
            padding:1px 5px;border-radius:6px;
            white-space:nowrap;z-index:1;
            letter-spacing:0.3px;
            box-shadow:0 1px 4px rgba(0,0,0,0.3);
          ">${ambLabel}</div>
        </div>
      `,
      iconSize: [34, 52],
      iconAnchor: [17, 26],
      popupAnchor: [0, -30]
    })
  }

  // ─── Popup para bus GPS ───
  const getGpsPopupContent = (busData) => {
    const lastUpdate = busData.timestamp
      ? new Date(busData.timestamp).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
      : 'Ahora'

    const cached = shiftDataCache.get(busData.busId) || {}
    const ambCode   = busData.ambCode   || cached.ambCode   || null
    const conductor = busData.driverName || cached.conductor || null
    const driverId  = busData.driverId  || cached.driverId  || null
    const plate     = busData.busId || '---'
    const rColor    = busData.routeColor || cached.routeColor || '#3b82f6'

    const conductorLine  = conductor
      ? `<div style="display:flex;align-items:center;gap:6px;margin-bottom:4px;">
          <span style="font-size:13px;">👨‍✈️</span>
          <span style="font-size:12px;color:#334155;font-weight:600;">${conductor}</span>
          ${driverId ? `<span style="font-size:11px;color:#94a3b8;">#${driverId}</span>` : ''}
         </div>`
      : `<div style="font-size:11px;color:#94a3b8;margin-bottom:4px;">👨‍✈️ Sin conductor asignado</div>`
    const plateLine = `<div style="display:flex;align-items:center;gap:6px;">
          <span style="font-size:13px;">🪪</span>
          <span style="font-size:11px;color:#64748b;">Placa:</span>
          <span style="font-family:monospace;font-size:12px;font-weight:700;color:#1f2937;letter-spacing:1px;">${plate}</span>
         </div>`

    return `
      <div style="font-family:'Segoe UI',sans-serif;min-width:240px;padding:4px;">

        <!-- Encabezado -->
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px;">
          <div style="
            background:${rColor};color:white;font-size:22px;
            width:44px;height:44px;border-radius:10px;
            display:flex;align-items:center;justify-content:center;
            box-shadow:0 2px 8px rgba(0,0,0,0.2);flex-shrink:0;
          ">🚌</div>
          <div style="flex:1;min-width:0;">
            <div style="font-size:17px;font-weight:700;color:#1f2937;line-height:1.15;">
              ${ambCode || plate}
            </div>
            <span style="font-size:11px;background:#10b981;color:white;padding:2px 8px;border-radius:10px;font-weight:500;">📡 GPS ACTIVO</span>
          </div>
        </div>

        <!-- Conductor + placa -->
        <div style="background:#f1f5f9;border-radius:8px;padding:8px 10px;margin-bottom:8px;">
          ${conductorLine}
          ${plateLine}
        </div>

        <!-- Indicadores GPS -->
        <div style="background:#f8fafc;border-radius:8px;padding:10px;margin-bottom:8px;">
          <div style="display:flex;justify-content:space-between;margin-bottom:6px;">
            <span style="color:#64748b;font-size:12px;">🚗 Velocidad</span>
            <span style="font-weight:600;color:#1f2937;font-size:14px;">${Math.round(busData.speed || 0)} km/h</span>
          </div>
          <div style="display:flex;justify-content:space-between;margin-bottom:6px;">
            <span style="color:#64748b;font-size:12px;">🧭 Dirección</span>
            <span style="font-weight:600;color:#1f2937;font-size:14px;">${Math.round(busData.heading || 0)}°</span>
          </div>
          <div style="display:flex;justify-content:space-between;">
            <span style="color:#64748b;font-size:12px;">📍 Coordenadas</span>
            <span style="font-family:monospace;font-size:11px;color:#6366f1;">
              ${busData.lat.toFixed(5)}, ${busData.lng.toFixed(5)}
            </span>
          </div>
        </div>

        <div style="text-align:center;color:#94a3b8;font-size:11px;">🕐 Actualizado: ${lastUpdate}</div>
      </div>
    `
  }

  // ─── Mostrar/actualizar marcadores GPS en tiempo real ───
  const displayGpsBuses = () => {
    const leafletMap = getMap()
    if (!leafletMap) return

    const currentGpsBuses = busLocations.value

    // Eliminar marcadores de buses que ya no envían GPS
    gpsMarkers.forEach((marker, busId) => {
      if (!currentGpsBuses.has(busId)) {
        leafletMap.removeLayer(marker)
        gpsMarkers.delete(busId)
      }
    })

    // Actualizar o crear marcadores
    currentGpsBuses.forEach((busData, busId) => {
      if (gpsMarkers.has(busId)) {
        const marker = gpsMarkers.get(busId)
        const currentLatLng = marker.getLatLng()
        const newLatLng = L.latLng(busData.lat, busData.lng)

        // Animación suave
        const duration = 1000
        const startTime = Date.now()

        if (marker._animationId) {
          cancelAnimationFrame(marker._animationId)
        }

        const animateGps = () => {
          const elapsed = Date.now() - startTime
          const progress = Math.min(elapsed / duration, 1)
          const easeProgress = progress

          const lat = currentLatLng.lat + (newLatLng.lat - currentLatLng.lat) * easeProgress
          const lng = currentLatLng.lng + (newLatLng.lng - currentLatLng.lng) * easeProgress

          marker.setLatLng([lat, lng])

          if (progress < 1) {
            marker._animationId = requestAnimationFrame(animateGps)
          } else {
            marker._animationId = null
          }
        }

        marker._animationId = requestAnimationFrame(animateGps)

        marker.setIcon(createGpsIcon(busData))
        marker.setPopupContent(getGpsPopupContent(busData))

      } else {
        const icon = createGpsIcon(busData)
        const marker = L.marker([busData.lat, busData.lng], {
          icon,
          zIndexOffset: 1000
        })
          .addTo(leafletMap)
          .bindPopup(getGpsPopupContent(busData))

        gpsMarkers.set(busId, marker)

        console.log(`🚌 Nuevo bus GPS detectado: ${busId}`)
      }
    })
  }

  // ─── Limpiar marcadores GPS ───
  const clearGpsMarkers = () => {
    const leafletMap = getMap()
    gpsMarkers.forEach(marker => {
      if (leafletMap) leafletMap.removeLayer(marker)
    })
    gpsMarkers.clear()
  }

  // ─── Watcher para actualizar marcadores cuando llegan datos GPS ───
  watch(
    () => busLocationsArray.value,
    () => {
      displayGpsBuses()
    },
    { deep: true }
  )

  return {
    displayGpsBuses,
    clearGpsMarkers
  }
}

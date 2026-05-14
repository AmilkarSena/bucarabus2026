import { ref } from 'vue'
import L from 'leaflet'
import { getBusColor } from '@shared/utils/busColors'
import { calculateDistance, formatDistance, calculateETA } from '@shared/utils/geo'

/**
 * Composable que gestiona la experiencia de usuario (UX) del mapa para pasajeros.
 *
 * Responsabilidades:
 * 1. Tracking de Buses: Actualiza marcadores de buses en tiempo real y gestiona su selección.
 * 2. Cálculo de Arribo (ETA): Implementa un algoritmo de distancia sobre la ruta (distanceAlongRoute)
 *    que mide el trayecto real que debe recorrer el bus por las calles, no en línea recta.
 * 3. Interacción con Sugerencias: Dibuja el trayecto recomendado (abordaje → ruta → bajada).
 * 4. Control de UI: Gestiona la visibilidad y expansión de los paneles laterales de información.
 */
export function usePassengerMap() {
  const mapRef                 = ref(null)
  const selectedBus            = ref(null)
  const selectedSuggestedRoute = ref(null)
  const panelExpanded          = ref(false)
  const panelHidden            = ref(false)
  const pickupMarker           = ref(null)
  const dropoffMarker          = ref(null)

  let leafletMap     = null
  let busMarkers     = {}
  let userMarker     = null
  let routePolylines = {}
  let incidentMarkers = {}

  const getMap = () => leafletMap

  // Calcula la distancia en metros que debe recorrer el bus siguiendo la polyline
  // desde su posición actual hasta el punto objetivo (parada de abordaje).
  const distanceAlongRoute = (busLat, busLng, targetLat, targetLng, routePath) => {
    if (!routePath || routePath.length < 2) {
      return calculateDistance(busLat, busLng, targetLat, targetLng)
    }
    const normalize = (p) => Math.abs(p[0]) < 20 ? [p[0], p[1]] : [p[1], p[0]]
    let minBusDist = Infinity, minTargetDist = Infinity
    let busSegIdx = 0, targetSegIdx = 0

    for (let i = 0; i < routePath.length - 1; i++) {
      const [lat1, lng1] = normalize(routePath[i])
      const [lat2, lng2] = normalize(routePath[i + 1])
      const midLat = (lat1 + lat2) / 2
      const midLng = (lng1 + lng2) / 2
      const dBus    = calculateDistance(busLat,    busLng,    midLat, midLng)
      const dTarget = calculateDistance(targetLat, targetLng, midLat, midLng)
      if (dBus    < minBusDist)    { minBusDist    = dBus;    busSegIdx    = i }
      if (dTarget < minTargetDist) { minTargetDist = dTarget; targetSegIdx = i }
    }

    if (busSegIdx > targetSegIdx) {
      return calculateDistance(busLat, busLng, targetLat, targetLng)
    }

    let dist = 0
    for (let i = busSegIdx; i < targetSegIdx; i++) {
      const [lat1, lng1] = normalize(routePath[i])
      const [lat2, lng2] = normalize(routePath[i + 1])
      dist += calculateDistance(lat1, lng1, lat2, lng2)
    }
    return Math.max(dist, 0)
  }

  const SERVICE_BOUNDS = L.latLngBounds([6.88, -73.38], [7.62, -72.90])

  const initMap = () => {
    if (!mapRef.value || leafletMap) return
    leafletMap = L.map(mapRef.value, {
      zoomControl: false, maxBounds: SERVICE_BOUNDS, maxBoundsViscosity: 1.0, minZoom: 10
    }).setView([7.1254, -73.1198], 13)
    const CARTO_URL = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
    const LOCAL_TILE_URL = import.meta.env.VITE_TILE_URL || ''
    const tileOptions = {
      attribution: '\u00a9 <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      subdomains: 'abcd',
      maxZoom: 18,
      maxNativeZoom: 16,
      updateWhenZooming: false,
      updateWhenIdle: true,
      keepBuffer: 2,
      detectRetina: false
    }

    if (!LOCAL_TILE_URL) {
      // Sin servidor local configurado, usar CartoDB directamente
      L.tileLayer(CARTO_URL, tileOptions).addTo(leafletMap)
    } else {
      // Intentar servidor local con fallback automático a CartoDB.
      // bounds: restringe las peticiones al área del .mbtiles (evita 404 fuera del bbox).
      // Solo cambia a CartoDB si hay 5+ errores en 10 s, descartando fallos puntuales de GL.
      let switched = false
      let errorCount = 0
      let errorTimer = null
      const localLayer = L.tileLayer(
        `${LOCAL_TILE_URL}/styles/positron/{z}/{x}/{y}.png`,
        { ...tileOptions, bounds: SERVICE_BOUNDS }
      ).addTo(leafletMap)

      localLayer.on('tileerror', (e) => {
        // Logueamos el error pero ya no "switcheamos" la capa entera.
        // Esto evita que el mapa se quede gris si CartoDB no es alcanzable.
        console.warn(`Tile local falló en zoom ${e.coords.z}. Manteniendo servidor local...`);
      })
    }
    L.control.zoom({ position: 'topright' }).addTo(leafletMap)
  }

  const destroyMap = () => {
    if (leafletMap) { leafletMap.remove(); leafletMap = null; busMarkers = {}; userMarker = null; routePolylines = {}; incidentMarkers = {} }
  }

  // Anima suavemente el marcador de una posición a otra (evita saltos bruscos)
  const animateMarker = (marker, targetLat, targetLng, duration = 1000) => {
    // Cancelar cualquier animación previa en este marcador para evitar vibraciones
    if (marker._animationId) {
      cancelAnimationFrame(marker._animationId)
    }

    const start = marker.getLatLng()
    const startLat = start.lat
    const startLng = start.lng
    const startTime = performance.now()

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      // Interpolación lineal: velocidad constante
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

  const updateBusMarker = (bus) => {
    const { busId, lat, lng, plate, routeColor, routeName, speed } = bus
    if (!lat || !lng || !leafletMap) return
    const popupContent = `<div style="text-align:center"><strong>${plate}</strong><br><span style="color:${routeColor}">${routeName}</span><br><small>${speed ? Math.round(speed) + ' km/h' : 'En movimiento'}</small></div>`
    
    if (busMarkers[busId]) {
      const marker = busMarkers[busId]
      // En lugar de saltar con setLatLng, animamos la transición
      animateMarker(marker, lat, lng, 1000)
      marker.setPopupContent(popupContent)
    } else {
      const busIcon = L.divIcon({
        className: 'bus-marker',
        html: `<div class="bus-marker-inner" style="background:${getBusColor(plate)}"><span>🚌</span></div>`,
        iconSize: [36, 36], iconAnchor: [18, 18]
      })
      busMarkers[busId] = L.marker([lat, lng], { icon: busIcon })
        .addTo(leafletMap).bindPopup(popupContent)
        .on('click', () => selectBus(bus, null))
    }
  }

  const removeBusMarker = (busId) => {
    if (busMarkers[busId] && leafletMap) { leafletMap.removeLayer(busMarkers[busId]); delete busMarkers[busId] }
  }

  const updateUserMarker = (userLocation) => {
    if (!userLocation || !leafletMap) return
    const userIcon = L.divIcon({ className: 'user-marker', html: `<div class="user-marker-inner">📍</div>`, iconSize: [32, 32], iconAnchor: [16, 32] })
    if (userMarker) {
      userMarker.setLatLng([userLocation.lat, userLocation.lng])
    } else {
      userMarker = L.marker([userLocation.lat, userLocation.lng], { icon: userIcon }).addTo(leafletMap).bindPopup('Tu ubicación')
    }
  }

  const centerOnUser = (userLocation) => {
    if (userLocation && leafletMap) leafletMap.setView([userLocation.lat, userLocation.lng], 15)
  }

  const drawRoutePath = (route) => {
    if (!route.path || !leafletMap) return
    if (routePolylines[route.id]) leafletMap.removeLayer(routePolylines[route.id])
    const coords = route.path.map(p => Math.abs(p[0]) < 20 ? [p[0], p[1]] : [p[1], p[0]])
    routePolylines[route.id] = L.polyline(coords, { color: route.color || '#667eea', weight: 4, opacity: 0.7 }).addTo(leafletMap)
  }

  const getIncidentIcon = (tag) => {
    const icons = {
      'road_closed': '🚧',
      'accident': '🚗',
      'protest': '✊',
      'detour': '🔀',
      'flood': '🌊',
      'danger': '⚠️'
    }
    return icons[tag] || '🚨'
  }

  const addIncidentMarker = (incident) => {
    if (!leafletMap) return
    
    // Si es un evento de resolución, eliminamos el marcador
    if (incident.resolved) {
      if (incidentMarkers[incident.id]) {
        leafletMap.removeLayer(incidentMarkers[incident.id])
        delete incidentMarkers[incident.id]
      }
      return
    }

    // No duplicar si ya existe
    if (incidentMarkers[incident.id]) return

    const emoji = getIncidentIcon(incident.tag)
    const icon = L.divIcon({ 
      html: `<div style="font-size: 24px; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));">${emoji}</div>`, 
      className: 'incident-marker bg-transparent border-0', 
      iconSize: [32, 32],
      iconAnchor: [16, 16]
    })
    
    const popupContent = `
      <div style="text-align:center">
        <b>${emoji} ${incident.name || 'Incidente'}</b><br>
        ${incident.descrip || ''}<br>
        <small style="color:#666">${new Date(incident.timestamp).toLocaleTimeString()}</small><br>
        <small style="color:#999">Bus: ${incident.plateNumber || 'Desconocido'}</small>
      </div>
    `
    
    const marker = L.marker([incident.lat, incident.lng], { icon })
      .addTo(leafletMap)
      .bindPopup(popupContent)
      
    incidentMarkers[incident.id] = marker

    // Auto-expirar localmente en 90 minutos (90 * 60 * 1000)
    setTimeout(() => {
      if (incidentMarkers[incident.id]) {
        leafletMap.removeLayer(incidentMarkers[incident.id])
        delete incidentMarkers[incident.id]
      }
    }, 90 * 60 * 1000)
  }

  const selectBus = (bus, userLocation) => {
    const isAlreadySelected = selectedBus.value?.busId === bus.busId

    const distanceMeters = userLocation ? calculateDistance(userLocation.lat, userLocation.lng, bus.lat, bus.lng) : null
    const etaStr         = distanceMeters ? calculateETA(distanceMeters, bus.speed) : '---'
    const etaMinutes     = distanceMeters && bus.speed > 0 ? Math.round(distanceMeters / (bus.speed / 3.6) / 60) : null
    const etaArrivalTime = etaMinutes != null
      ? new Date(Date.now() + etaMinutes * 60000).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', hour12: true })
      : null
    selectedBus.value   = { ...bus, distance: distanceMeters ? formatDistance(distanceMeters) : '---', eta: etaStr, etaArrivalTime }
    panelExpanded.value = true
    panelHidden.value   = false
    
    // Solo centrar la cámara violentamente si es la primera vez que se selecciona
    if (!isAlreadySelected && leafletMap && bus.lat && bus.lng) {
      leafletMap.setView([bus.lat, bus.lng], 16)
    }
  }

  const showRouteOnMap = (suggestion, userLocation, selectedDestination) => {
    if (!leafletMap) return
    if (selectedSuggestedRoute.value?.route.id === suggestion.route.id) {
      selectedSuggestedRoute.value = null
      if (pickupMarker.value)  { leafletMap.removeLayer(pickupMarker.value);  pickupMarker.value  = null }
      if (dropoffMarker.value) { leafletMap.removeLayer(dropoffMarker.value); dropoffMarker.value = null }
      Object.values(routePolylines).forEach(p => p.setStyle({ weight: 4, opacity: 0.7 }))
      return
    }
    selectedSuggestedRoute.value = suggestion
    panelExpanded.value = false
    panelHidden.value   = true

    if (pickupMarker.value)  leafletMap.removeLayer(pickupMarker.value)
    if (dropoffMarker.value) leafletMap.removeLayer(dropoffMarker.value)

    const walkToPickupMin    = Math.round(suggestion.walkToPickup / 80)
    const walkFromDropoffMin = Math.round(suggestion.walkFromDropoff / 80)

    pickupMarker.value = L.circleMarker([suggestion.pickupPoint.lat, suggestion.pickupPoint.lng],
      { radius: 10, color: 'white', weight: 3, fillColor: '#10b981', fillOpacity: 1 })
      .addTo(leafletMap)
      .bindTooltip(`🧍 Aquí subes · ${formatDistance(suggestion.walkToPickup)} (~${walkToPickupMin} min)`,
        { permanent: false, direction: 'top', offset: [0, -8], className: 'stop-tooltip pickup-tooltip' })
      .bindPopup(`<div style="text-align:center;padding:4px 0;"><strong style="color:#10b981">🧍 Parada de abordaje</strong><br><span style="font-size:13px">Camina ${formatDistance(suggestion.walkToPickup)}</span><br><span style="font-size:12px;color:#6b7280">~${walkToPickupMin} min a pie</span></div>`)

    dropoffMarker.value = L.circleMarker([suggestion.dropoffPoint.lat, suggestion.dropoffPoint.lng],
      { radius: 10, color: 'white', weight: 3, fillColor: '#ef4444', fillOpacity: 1 })
      .addTo(leafletMap)
      .bindTooltip(`🏁 Aquí bajas · ${formatDistance(suggestion.walkFromDropoff)} (~${walkFromDropoffMin} min)`,
        { permanent: false, direction: 'top', offset: [0, -8], className: 'stop-tooltip dropoff-tooltip' })
      .bindPopup(`<div style="text-align:center;padding:4px 0;"><strong style="color:#ef4444">🏁 Parada de bajada</strong><br><span style="font-size:13px">Camina ${formatDistance(suggestion.walkFromDropoff)}</span><br><span style="font-size:12px;color:#6b7280">~${walkFromDropoffMin} min a pie</span></div>`)

    Object.keys(routePolylines).forEach(routeId => {
      const polyline = routePolylines[routeId]
      if (Number(routeId) === Number(suggestion.route.id)) { polyline.setStyle({ weight: 6, opacity: 1 }); polyline.bringToFront() }
      else polyline.setStyle({ weight: 4, opacity: 0.3 })
    })
    if (pickupMarker.value)  pickupMarker.value.bringToFront()
    if (dropoffMarker.value) dropoffMarker.value.bringToFront()

    const bounds = L.latLngBounds([
      [userLocation.lat, userLocation.lng],
      [suggestion.pickupPoint.lat, suggestion.pickupPoint.lng],
      [suggestion.dropoffPoint.lat, suggestion.dropoffPoint.lng],
      [selectedDestination.lat, selectedDestination.lng]
    ])
    leafletMap.fitBounds(bounds, { padding: [50, 50] })
  }

  const selectBusFromRoute = (bus, userLocation) => {
    const isAlreadySelected = selectedBus.value?.busId === bus.busId

    const distanceMeters = userLocation ? calculateDistance(userLocation.lat, userLocation.lng, bus.lat, bus.lng) : null
    const etaStr         = distanceMeters ? calculateETA(distanceMeters, bus.speed) : '---'
    const etaMinutes     = distanceMeters && bus.speed > 0 ? Math.round(distanceMeters / (bus.speed / 3.6) / 60) : null
    const etaArrivalTime = etaMinutes != null
      ? new Date(Date.now() + etaMinutes * 60000).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', hour12: true })
      : null
    selectedBus.value = { ...bus, distance: distanceMeters ? formatDistance(distanceMeters) : '---', eta: etaStr, etaArrivalTime }
    
    if (!isAlreadySelected && leafletMap && bus.lat && bus.lng) {
      leafletMap.setView([bus.lat, bus.lng], 16)
    }
  }

  const togglePanel     = () => { panelHidden.value = !panelHidden.value }

  const clearRouteMarkers = () => {
    selectedSuggestedRoute.value = null
    panelHidden.value = false
    if (!leafletMap) return
    if (pickupMarker.value)  { leafletMap.removeLayer(pickupMarker.value);  pickupMarker.value  = null }
    if (dropoffMarker.value) { leafletMap.removeLayer(dropoffMarker.value); dropoffMarker.value = null }
    Object.values(routePolylines).forEach(p => p.setStyle({ weight: 4, opacity: 0.7 }))
  }

  const clearAllRoutePaths = () => {
    if (!leafletMap) return
    Object.values(routePolylines).forEach(p => leafletMap.removeLayer(p))
    routePolylines = {}
  }

  return {
    mapRef, selectedBus, selectedSuggestedRoute, panelExpanded, panelHidden,
    getMap, distanceAlongRoute, initMap, destroyMap,
    updateBusMarker, removeBusMarker, updateUserMarker, centerOnUser,
    drawRoutePath, selectBus, showRouteOnMap, selectBusFromRoute, togglePanel, clearRouteMarkers, clearAllRoutePaths,
    addIncidentMarker
  }
}

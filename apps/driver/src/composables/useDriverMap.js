import L from 'leaflet'
import { getBusColor } from '@shared/utils/busColors'

export function useDriverMap() {
  let leafletMap = null
  let routePolyline = null
  let driverMarker = null

  const initMap = (elementId, currentTrip) => {
    if (leafletMap) return
    
    const center = [7.1193, -73.1227]
    
    leafletMap = L.map(elementId, {
      center,
      zoom: 14,
      zoomControl: false
    })
    
    const CARTO_URL = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
    const LOCAL_TILE_URL = import.meta.env.VITE_TILE_URL || ''
    const SERVICE_BOUNDS = L.latLngBounds([6.88, -73.38], [7.62, -72.90])
    const tileOptions = {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      subdomains: 'abcd',
      maxZoom: 18,
      maxNativeZoom: 16,
      updateWhenZooming: false,
      updateWhenIdle: true,
      keepBuffer: 2,
      detectRetina: false
    }

    if (!LOCAL_TILE_URL) {
      L.tileLayer(CARTO_URL, tileOptions).addTo(leafletMap)
    } else {
      // bounds: restringe al área del .mbtiles. Solo cambia a CartoDB tras 5 errores en 10s.
      let switched = false
      let errorCount = 0
      let errorTimer = null
      const localLayer = L.tileLayer(
        `${LOCAL_TILE_URL}/styles/klokantech-basic/{z}/{x}/{y}.png?v=1`,
        { ...tileOptions, bounds: SERVICE_BOUNDS }
      ).addTo(leafletMap)

      localLayer.on('tileerror', (e) => {
        console.warn(`Tile local falló en zoom ${e.coords.z}. Manteniendo servidor local...`);
      })
    }
    
    // Dibujar ruta asignada si existe
    if (currentTrip?.path?.length > 0) {
      drawRoute(currentTrip.path, currentTrip.color)
    }
  }

  const drawRoute = (path, color) => {
    if (!leafletMap) return
    
    if (!path || path.length < 2) return
    
    if (routePolyline) {
      leafletMap.removeLayer(routePolyline)
    }
    
    routePolyline = L.polyline(path, {
      color: color || '#667eea',
      weight: 6,
      opacity: 0.8
    }).addTo(leafletMap)
    
    leafletMap.fitBounds(routePolyline.getBounds(), { padding: [50, 50] })
  }

  const updateDriverMarker = (lat, lng, busPlate) => {
    if (!leafletMap) return
    
    if (driverMarker) {
      driverMarker.setLatLng([lat, lng])
    } else {
      const busColor = getBusColor(busPlate)
      const icon = L.divIcon({
        className: 'driver-marker',
        html: `
          <div class="driver-marker-inner" style="
            background: ${busColor};
            width: 50px;
            height: 50px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            border: 3px solid white;
            box-shadow: 0 4px 14px ${busColor}80;
            position: relative;
          ">
            <div class="driver-marker-pulse" style="
              position: absolute;
              inset: -8px;
              border-radius: 50%;
              background: ${busColor}30;
              animation: markerPulse 2s infinite;
            "></div>
            <div class="driver-marker-icon" style="
              position: absolute;
              top: 50%;
              left: 50%;
              transform: translate(-50%, -50%);
              width: 36px;
              height: 36px;
              background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
              border-radius: 50%;
              display: flex;
              align-items: center;
              justify-content: center;
              font-size: 20px;
              box-shadow: 0 4px 12px rgba(0,0,0,0.3);
              border: 3px solid white;
            ">🚌</div>
          </div>
        `,
        iconSize: [50, 50],
        iconAnchor: [25, 25]
      })
      
      driverMarker = L.marker([lat, lng], { icon }).addTo(leafletMap)
    }
    
    leafletMap.setView([lat, lng], leafletMap.getZoom())
  }

  const destroyMap = () => {
    if (leafletMap) {
      leafletMap.remove()
      leafletMap = null
      routePolyline = null
      driverMarker = null
    }
  }

  return {
    initMap,
    drawRoute,
    updateDriverMarker,
    destroyMap
  }
}

import express from 'express'
const router = express.Router()

/**
 * Buscar lugares usando Mapbox
 * Proxy endpoint para evitar problemas de CORS
 */
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query;                                                     // Extrae la palabra que el usuario está buscando en la URL

    if (!q || q.length < 2) {                                                     // Si no hay una palabra con al menos 2 letras, no busca
      return res.json({                                                          // Devuelve un array vacío
        success: true,                                                          // Indica que la operación fue exitosa
        data: []                                                                // Array vacío de resultados
      });
    }

    let validResults = [];

    try {
      // 1. Intentar con Photon Local
      // La base de datos ya está acotada al Área Metropolitana de Bucaramanga
      // en el momento de la importación (ver photon/filter_bbox.py), por lo que
      // no se necesita ningún filtro adicional aquí.
      const photonUrl = `http://localhost:8080/api?q=${encodeURIComponent(q)}&lat=7.119&lon=-73.122&limit=5`;
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 2000);
      const photonResponse = await fetch(photonUrl, { signal: controller.signal });
      clearTimeout(timer);

      if (photonResponse.ok) {
        const photonData = await photonResponse.json();
        validResults = (photonData.features || []).map(f => {
          const props = f.properties;
          return {
            lat: f.geometry.coordinates[1],
            lng: f.geometry.coordinates[0],
            name: props.name || props.street || props.city,
            address: [props.street, props.housenumber, props.district, props.city].filter(Boolean).join(', '),
            type: props.osm_value || 'point_of_interest',
            osmId: `osm_${props.osm_id}`,
            hasHouseNumber: !!props.housenumber
          };
        }).filter(r => r.lat && r.lng && r.name);
      }
    } catch (photonError) {
      console.warn('Advertencia: Photon local falló. Usando Fallback de Google API.', photonError.message);
    }

    // Heurística de Fallback:
    // Photon cubre POIs y calles de la AMB. Para direcciones exactas con número
    // de casa (ej: "Calle 12 # 29-25"), OSM Bucaramanga no tiene ese nivel de
    // detalle, por lo que usamos Google como complemento preciso.
    const isSpecificAddress = /#|-|\d+\s*[a-zA-Z]?\s*[-#]\s*\d+/.test(q);
    const photonFoundHouse = validResults.some(r => r.hasHouseNumber);
    const needsGoogleFallback = validResults.length === 0 || (isSpecificAddress && !photonFoundHouse);

    // 2. Fallback a Google API
    if (needsGoogleFallback) {
      const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

      if (GOOGLE_API_KEY) {
        try {
          const response = await fetch('https://places.googleapis.com/v1/places:searchText', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': GOOGLE_API_KEY,
              'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.primaryType'
            },
            body: JSON.stringify({
              textQuery: q,
              languageCode: 'es'
            })
          });

          if (response.ok) {
            const data = await response.json();
            const googleResults = (data.places || []).map(r => ({
              lat: r.location?.latitude,
              lng: r.location?.longitude,
              name: r.displayName?.text,
              address: r.formattedAddress,
              type: r.primaryType || 'point_of_interest',
              osmId: `google_${r.id}`
            })).filter(r => r.lat && r.lng);

            // Si Google encontró resultados, los usamos. 
            // Si Google falló y no devolvió nada, mantenemos los resultados de Photon (aunque sean genéricos)
            if (googleResults.length > 0) {
              validResults = googleResults;
            }
          }
        } catch (googleError) {
          console.error('Error en fallback de Google API:', googleError);
        }
      }
    }

    res.json({
      success: true,
      data: validResults
    });
  } catch (error) {
    console.error('Error en geocoding search:', error);
    res.status(500).json({
      success: false,
      error: 'Error al buscar ubicación',
      message: error.message
    });
  }
})

/**
 * Geocodificación inversa: coordenadas → nombre de calle
 * Proxy para Google Geocoding API
 * GET /api/geocoding/reverse?lat=7.119&lng=-73.123
 */
router.get('/reverse', async (req, res) => {
  try {
    const { lat, lng } = req.query

    if (!lat || !lng || isNaN(parseFloat(lat)) || isNaN(parseFloat(lng))) {
      return res.status(400).json({ success: false, error: 'Parámetros lat y lng requeridos' })
    }

    let name = '';
    let formatted = '';

    try {
      // 1. Intentar con Photon Local
      const photonUrl = `http://localhost:8080/reverse?lon=${lng}&lat=${lat}`;
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 2000);
      const photonResponse = await fetch(photonUrl, { signal: controller.signal });
      clearTimeout(timer);

      if (photonResponse.ok) {
        const photonData = await photonResponse.json();
        if (photonData.features && photonData.features.length > 0) {
          const props = photonData.features[0].properties;
          
          if (props.street) {
            name = props.street;
            if (props.housenumber) name += ` #${props.housenumber}`;
            if (props.district) name += `, ${props.district}`;
          } else {
            name = props.name || '';
          }
          formatted = [props.street, props.housenumber, props.district, props.city].filter(Boolean).join(', ');
        }
      }
    } catch (photonError) {
      console.warn('Advertencia: Photon local falló en reverse. Cayendo a Fallback (Google).', photonError.message);
    }

    // 2. Fallback a Google API
    // Photon identifica calles y barrios de la AMB; Google entra cuando Photon
    // no devuelve nombre (p.ej. el usuario hace clic en un punto sin calle tagueada).
    if (!name) {
      const GOOGLE_API_KEY = process.env.GOOGLE_MAPS_API_KEY
      if (!GOOGLE_API_KEY) {
        throw new Error('No se encontró GOOGLE_MAPS_API_KEY y Photon no devolvió resultados')
      }

      const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${GOOGLE_API_KEY}&language=es&result_type=street_address|route`

      const response = await fetch(url)
      if (!response.ok) {
        throw new Error(`Google Geocoding API error: ${response.status}`)
      }

      const data = await response.json()

      if (data.status === 'OK' && data.results?.length > 0) {
        const result = data.results[0]
        const components = result.address_components || []

        const getComp = (type) => components.find(c => c.types.includes(type))

        const route       = getComp('route')?.long_name        // "Carrera 27"
        const streetNum   = getComp('street_number')?.long_name // "45"
        const neighborhood= getComp('sublocality_level_1')?.long_name || getComp('neighborhood')?.long_name || ''

        if (route) {
          name = route
          if (streetNum) name += ` #${streetNum}`
          if (neighborhood) name += `, ${neighborhood}`
        } else {
          name = result.formatted_address?.split(',').slice(0, 2).join(',').trim() || ''
        }
        formatted = result.formatted_address;
      }
    }

    res.json({ success: true, name: name || null, formatted })

  } catch (error) {
    console.error('Error en reverse geocoding:', error)
    res.status(500).json({ success: false, error: 'Error al geocodificar', message: error.message })
  }
})

/**
 * Snap to road: ajusta coordenadas al punto más cercano en una calle real
 * Usa OSRM /nearest como motor primario, fallback sin snap si falla
 * GET /api/geocoding/snap?lat=7.119&lng=-73.123
 */
router.get('/snap', async (req, res) => {
  const { lat, lng } = req.query

  if (!lat || !lng || isNaN(parseFloat(lat)) || isNaN(parseFloat(lng))) {
    return res.status(400).json({ success: false, error: 'Parámetros lat y lng requeridos' })
  }

  const latF = parseFloat(lat)
  const lngF = parseFloat(lng)

  // 1º Local (Docker) — rápido y acotado a Bucaramanga
  // 2º/3º Públicos — si Docker no está corriendo
  const osrmServers = [
    `http://localhost:5000/nearest/v1/driving/${lngF},${latF}?number=1`,
    `https://router.project-osrm.org/nearest/v1/driving/${lngF},${latF}?number=1`,
    `https://routing.openstreetmap.de/routed-car/nearest/v1/driving/${lngF},${latF}?number=1`
  ]

  for (const url of osrmServers) {
    try {
      const controller = new AbortController()
      // 3s para local, 5s para públicos (snap es más ligero que route)
      const isLocal = url.includes('localhost')
      const timer = setTimeout(() => controller.abort(), isLocal ? 3000 : 5000)

      const response = await fetch(url, { signal: controller.signal })
      clearTimeout(timer)

      if (!response.ok) continue

      const data = await response.json()

      if (data.code === 'Ok' && data.waypoints?.length > 0) {
        const [snappedLng, snappedLat] = data.waypoints[0].location
        const name = data.waypoints[0].name || null
        const distance = data.waypoints[0].distance || 0

        console.log(`[SNAP] ${latF},${lngF} → ${snappedLat},${snappedLng} (${Math.round(distance)}m a calle: ${name || 'sin nombre'})`)

        return res.json({
          success: true,
          snapped: true,
          lat: snappedLat,
          lng: snappedLng,
          distance: Math.round(distance), // distancia en metros desde el punto original a la calle
          streetName: name,
          original: { lat: latF, lng: lngF }
        })
      }
    } catch (e) {
      console.warn(`[SNAP] Error con ${url.split('/nearest')[0]}: ${e.message}`)
    }
  }

  // Fallback: devolver las coordenadas originales sin snap
  console.warn(`[SNAP] Todos los servidores OSRM fallaron, devolviendo coordenadas originales`)
  res.json({
    success: true,
    snapped: false,
    lat: latF,
    lng: lngF,
    distance: 0,
    streetName: null,
    original: { lat: latF, lng: lngF }
  })
})

/**
 * Route: obtiene la polilínea vial entre múltiples puntos
 * GET /api/geocoding/route?waypoints=-73.1,7.1;-73.2,7.2
 */
router.get('/route', async (req, res) => {
  const { waypoints } = req.query
  if (!waypoints) return res.status(400).json({ error: 'Waypoints requeridos' })

  // 1º Local (Docker) — rápido y optimizado para Bucaramanga
  // 2º/3º Públicos — si Docker no está corriendo
  const osrmServers = [
    `http://localhost:5000/route/v1/driving/${waypoints}?overview=full&geometries=geojson`,
    `https://router.project-osrm.org/route/v1/driving/${waypoints}?overview=full&geometries=geojson`,
    `https://routing.openstreetmap.de/routed-car/route/v1/driving/${waypoints}?overview=full&geometries=geojson`
  ]

  for (const url of osrmServers) {
    try {
      const controller = new AbortController()
      // 3s para el servidor local (si Docker está vivo responde en <100ms)
      // 10s para los públicos (red externa puede ser más lenta)
      const isLocal = url.includes('localhost')
      const timer = setTimeout(() => controller.abort(), isLocal ? 3000 : 10000)
      const response = await fetch(url, { signal: controller.signal })
      clearTimeout(timer)

      if (!response.ok) continue

      const data = await response.json()
      if (data.code === 'Ok') {
        return res.json(data)
      }
    } catch (e) {
      console.warn(`[ROUTE] Error con OSRM: ${e.message}`)
    }
  }

  res.status(502).json({ error: 'No se pudo generar la ruta con OSRM' })
})

export default router


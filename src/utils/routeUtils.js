/**
 * Haversine distance in meters between two [lat, lng] points.
 */
export function haversineMeters(a, b) {
  const R = 6_371_000
  const toRad = d => d * Math.PI / 180
  const dLat = toRad(b[0] - a[0])
  const dLng = toRad(b[1] - a[1])
  const s = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a[0])) * Math.cos(toRad(b[0])) * Math.sin(dLng / 2) ** 2
  return R * 2 * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s))
}

/**
 * Calculates the total distance of a path in kilometers.
 * @param {Array<[number, number]>} path - Array of [lat, lng]
 * @returns {string} Total distance formatted to 2 decimal places.
 */
export function calculatePathDistance(path) {
  if (!path || path.length < 2) return '0.00'
  let total = 0
  for (let i = 0; i < path.length - 1; i++) {
    total += haversineMeters(path[i], path[i + 1])
  }
  return (total / 1000).toFixed(2)
}

/**
 * Minimum distance from point P to segment A-B (in meters, lat/lng coords).
 * Returns { dist, t } where t is 0..1 within the segment.
 */
function pointToSegmentDist(P, A, B) {
  const dx = B[0] - A[0]
  const dy = B[1] - A[1]
  const len2 = dx * dx + dy * dy
  let t = 0
  if (len2 > 0) {
    t = Math.max(0, Math.min(1, ((P[0] - A[0]) * dx + (P[1] - A[1]) * dy) / len2))
  }
  const proj = [A[0] + t * dx, A[1] + t * dy]
  return { dist: haversineMeters(P, proj), t }
}

/**
 * Detects which catalog points are within `thresholdMeters` of the polyline.
 * A stop is returned once per "pass" — if the route goes near the same stop
 * twice (e.g. bidirectional route), it appears twice in the result sorted by
 * position along the route. Two detections of the same stop are considered
 * separate passes when they are more than `minSeparationMeters` apart along
 * the route (default 300 m).
 *
 * @param {Array}  polylinePoints       - Array of [lat, lng] pairs (the drawn route)
 * @param {Array}  catalogPoints        - Array of { id_point, name_point, lat, lng }
 * @param {number} thresholdMeters      - Max distance from the route (default 80 m)
 * @param {number} minSeparationMeters  - Min route-distance between two passes (default 300 m)
 * @returns {Array} Matched stops sorted by position along the route:
 *   [{ idPoint, namePoint, lat, lng, dist, t }, ...]
 */
export function detectNearbyStops(polylinePoints, catalogPoints, thresholdMeters = 80, minSeparationMeters = 300) {
  if (!polylinePoints || polylinePoints.length < 2 || !catalogPoints?.length) return []

  // Pre-compute segment lengths and cumulative start distances
  const segments = []
  let cumLen = 0
  for (let i = 0; i < polylinePoints.length - 1; i++) {
    const len = haversineMeters(polylinePoints[i], polylinePoints[i + 1])
    segments.push({ len, cumStart: cumLen })
    cumLen += len
  }

  const result = []

  for (const cp of catalogPoints) {
    const P = [cp.lat, cp.lng]

    // Collect all segments within threshold
    const candidates = []
    for (let i = 0; i < segments.length; i++) {
      const { dist, t } = pointToSegmentDist(P, polylinePoints[i], polylinePoints[i + 1])
      if (dist <= thresholdMeters) {
        candidates.push({ dist, globalT: segments[i].cumStart + t * segments[i].len })
      }
    }

    if (candidates.length === 0) continue

    // Cluster consecutive candidates; each cluster = one pass of the route
    const clusters = [[candidates[0]]]
    for (let i = 1; i < candidates.length; i++) {
      const gap = candidates[i].globalT - candidates[i - 1].globalT
      if (gap > minSeparationMeters) {
        clusters.push([candidates[i]])
      } else {
        clusters[clusters.length - 1].push(candidates[i])
      }
    }

    // One result entry per cluster, at the closest segment within the cluster
    for (const cluster of clusters) {
      const best = cluster.reduce((a, b) => a.dist < b.dist ? a : b)
      result.push({
        idPoint:   cp.id_point,
        namePoint: cp.name_point,
        lat:       cp.lat,
        lng:       cp.lng,
        dist:      Math.round(best.dist),
        t:         best.globalT
      })
    }
  }

  result.sort((a, b) => a.t - b.t)
  return result
}

/**
 * Calcula la posición de una nueva parada en el recorrido de una ruta
 * proyectando sus coordenadas sobre el path (polyline) de la ruta.
 *
 * Estrategia en dos pasos para evitar violación de UNIQUE(id_route, point_order):
 *   1. Asignar la nueva parada en `tempOrder` (= stops actuales + 1, siempre seguro)
 *   2. Luego llamar a reorderPoints con `allStopsReorder` para posicionar todo correctamente
 *
 * @param {number} newStopId     - id_point de la nueva parada (ya guardada en BD)
 * @param {[number,number]} newStopCoords - [lat, lng] de la nueva parada
 * @param {Array<[number,number]>} routePath - Array de [lat, lng] del path de la ruta
 * @param {Array<{idPoint?:number, id_point?:number, lat:number|string, lng:number|string, pointOrder?:number, point_order?:number}>} existingStops
 * @returns {{ tempOrder: number, allStopsReorder: Array<{idPoint:number, order:number}>|null }}
 */
export function getInsertOrderOnPath(newStopId, newStopCoords, routePath, existingStops) {
  const n = existingStops?.length ?? 0

  // Posición temporal: MAX(point_order) + 1 — siempre libre en la BD
  // NO usar length + 1 porque los orders pueden tener huecos (ej: 1, 3, 5)
  const maxOrder = (existingStops || []).reduce((max, s) => {
    const order = s.pointOrder ?? s.point_order ?? 0
    return Math.max(max, order)
  }, 0)
  const tempOrder = maxOrder + 1

  if (!routePath || routePath.length < 2 || n === 0) {
    // Sin path o sin stops existentes: no hace falta reordenar
    return { tempOrder, allStopsReorder: null }
  }

  // Pre-calcular longitudes acumuladas de segmentos
  const segments = []
  let cumLen = 0
  for (let i = 0; i < routePath.length - 1; i++) {
    const len = haversineMeters(routePath[i], routePath[i + 1])
    segments.push({ len, cumStart: cumLen })
    cumLen += len
  }

  /**
   * Proyecta un punto [lat, lng] sobre el path y devuelve su
   * distancia acumulada desde el inicio (metros).
   */
  const projectOnPath = ([lat, lng]) => {
    let bestT = 0
    let bestDist = Infinity
    for (let i = 0; i < segments.length; i++) {
      const { dist, t } = pointToSegmentDist([lat, lng], routePath[i], routePath[i + 1])
      const globalT = segments[i].cumStart + t * segments[i].len
      if (dist < bestDist) {
        bestDist = dist
        bestT = globalT
      }
    }
    return bestT
  }

  // Combinar stops existentes + nuevo stop y ordenar por posición en el path
  const combined = [
    ...(existingStops || []).map(s => ({
      idPoint: s.idPoint ?? s.id_point,
      t: projectOnPath([parseFloat(s.lat), parseFloat(s.lng)])
    })),
    { idPoint: newStopId, t: projectOnPath(newStopCoords) }
  ].sort((a, b) => a.t - b.t)

  // Generar el reorder final con todos los stops (existentes + nuevo)
  const allStopsReorder = combined.map((s, idx) => ({ idPoint: s.idPoint, order: idx + 1 }))

  return { tempOrder, allStopsReorder }
}


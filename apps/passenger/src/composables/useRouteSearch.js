import { ref } from 'vue'
import { calculateDistance, calculateETA } from '@shared/utils/geo'

/**
 * Motor de búsqueda y recomendación de rutas para el pasajero.
 * Algoritmo basado en proximidad de paradas, validación de sentido y análisis costo-beneficio.
 */
export function useRouteSearch() {
  const suggestedRoutes = ref([])

  const normalizeRouteId = (id) => Number(String(id).replace(/^RUTA_/i, ''))

  const projectPointOnSegment = (point, segmentStart, segmentEnd) => {
    const [lat1, lng1] = segmentStart, [lat2, lng2] = segmentEnd
    const A = point.lat - lat1, B = point.lng - lng1, C = lat2 - lat1, D = lng2 - lng1
    const dot = A * C + B * D, lenSq = C * C + D * D
    let param = lenSq !== 0 ? dot / lenSq : -1
    let projLat, projLng
    if      (param < 0) { projLat = lat1; projLng = lng1 }
    else if (param > 1) { projLat = lat2; projLng = lng2 }
    else                { projLat = lat1 + param * C; projLng = lng1 + param * D }
    return { lat: projLat, lng: projLng }
  }

  const findClosestPointOnRoute = (point, routePath) => {
    let minDistance = Infinity, closestPoint = null, fraction = 0
    let totalLength = 0
    for (let j = 0; j < routePath.length - 1; j++) {
      totalLength += calculateDistance(routePath[j][0], routePath[j][1], routePath[j+1][0], routePath[j+1][1])
    }
    for (let i = 0; i < routePath.length - 1; i++) {
      const projection = projectPointOnSegment(point, routePath[i], routePath[i+1])
      const distance   = calculateDistance(point.lat, point.lng, projection.lat, projection.lng)
      if (distance < minDistance) {
        minDistance   = distance
        closestPoint  = projection
        let lengthToPoint = 0
        for (let j = 0; j < i; j++) {
          lengthToPoint += calculateDistance(routePath[j][0], routePath[j][1], routePath[j+1][0], routePath[j+1][1])
        }
        lengthToPoint += calculateDistance(routePath[i][0], routePath[i][1], projection.lat, projection.lng)
        fraction = totalLength > 0 ? lengthToPoint / totalLength : 0
      }
    }
    return { point: closestPoint, distance: minDistance, fraction }
  }

  const findStopsNear = (point, stops, maxDistance) => {
    const results = []
    for (let i = 0; i < stops.length; i++) {
      const stopLat = parseFloat(stops[i].lat), stopLng = parseFloat(stops[i].lng)
      if (isNaN(stopLat) || isNaN(stopLng)) continue
      const dist = calculateDistance(point.lat, point.lng, stopLat, stopLng)
      if (dist <= maxDistance) results.push({ stop: stops[i], index: i, distance: dist })
    }
    return results.sort((a, b) => a.distance - b.distance)
  }

  const findNearestStop = (point, stops) => {
    if (!stops || stops.length === 0) return null
    let minDist = Infinity, nearest = null
    for (const stop of stops) {
      const dist = calculateDistance(point.lat, point.lng, parseFloat(stop.lat), parseFloat(stop.lng))
      if (dist < minDist) { minDist = dist; nearest = stop }
    }
    return nearest
  }

  const calculateRideDistance = (pickupIdx, dropoffIdx, stops) => {
    let dist = 0, n = stops.length, i = pickupIdx
    while (i !== dropoffIdx) {
      const next = (i + 1) % n
      dist += calculateDistance(parseFloat(stops[i].lat), parseFloat(stops[i].lng), parseFloat(stops[next].lat), parseFloat(stops[next].lng))
      i = next
    }
    return dist
  }

  const MAX_WALK_DISTANCE      = 1500
  const MIN_BUS_DISTANCE       = 300
  const MAX_CIRCULAR_HOPS_FRAC = 0.75

  const findBestRoutes = (userLocation, selectedDestination, routes, activeBuses) => {
    if (!userLocation || !selectedDestination || routes.length === 0) { suggestedRoutes.value = []; return }
    const candidates = []
    const directDistance = calculateDistance(userLocation.lat, userLocation.lng, selectedDestination.lat, selectedDestination.lng)

    routes.forEach(route => {
      if (!route.path || route.path.length < 2) return
      const stops = route.stops || [], isCircular = route.isCircular ?? true
      const routeLabel = `[${route.name || route.id}]`
      const busesOnRoute = Object.values(activeBuses).filter(b => normalizeRouteId(b.routeId) === normalizeRouteId(route.id)).length

      if (stops.length >= 2) {
        const dropoffCandidates = findStopsNear(selectedDestination, stops, MAX_WALK_DISTANCE)
        const pickupCandidates  = findStopsNear(userLocation, stops, MAX_WALK_DISTANCE)
        if (!dropoffCandidates.length || !pickupCandidates.length) return
        const n = stops.length

        for (const pickup of pickupCandidates) {
          for (const dropoff of dropoffCandidates) {
            if (pickup.index === dropoff.index) continue
            let hops
            if (isCircular) { hops = (dropoff.index - pickup.index + n) % n }
            else { if (pickup.index >= dropoff.index) continue; hops = dropoff.index - pickup.index }
            if (hops === 0) continue

            const rideDistance = calculateRideDistance(pickup.index, dropoff.index, stops)
            const walkToPickup = pickup.distance, walkFromDropoff = dropoff.distance
            const totalWalkDistance = walkToPickup + walkFromDropoff

            const dropoffToUser = calculateDistance(parseFloat(dropoff.stop.lat), parseFloat(dropoff.stop.lng), userLocation.lat, userLocation.lng)
            const dropoffToDest = calculateDistance(parseFloat(dropoff.stop.lat), parseFloat(dropoff.stop.lng), selectedDestination.lat, selectedDestination.lng)
            if (dropoffToUser < dropoffToDest) continue
            if (rideDistance < MIN_BUS_DISTANCE) continue
            const totalBusTime = walkToPickup / 80 + rideDistance / 417 + walkFromDropoff / 80
            if (totalBusTime > (directDistance / 80) * 1.3) continue
            if (isCircular && hops > n * MAX_CIRCULAR_HOPS_FRAC) continue
            const pickupToDest = calculateDistance(parseFloat(pickup.stop.lat), parseFloat(pickup.stop.lng), selectedDestination.lat, selectedDestination.lng)
            if (pickupToDest > directDistance) continue

            candidates.push({
              route,
              pickupPoint:     { lat: parseFloat(pickup.stop.lat),  lng: parseFloat(pickup.stop.lng)  },
              dropoffPoint:    { lat: parseFloat(dropoff.stop.lat), lng: parseFloat(dropoff.stop.lng) },
              pickupStopName:  pickup.stop.name_point  || null,
              dropoffStopName: dropoff.stop.name_point || null,
              walkToPickup, walkFromDropoff, totalWalkDistance,
              busDistance: rideDistance, stopsCount: hops, busesOnRoute,
              score: totalWalkDistance * 2.0 + rideDistance * 0.3 - (busesOnRoute * 1000),
              totalTime: calculateETA(totalWalkDistance + rideDistance, 20)
            })
          }
        }
        return
      }

      // Fallback geométrico (rutas sin paradas)
      const pickupInfo  = findClosestPointOnRoute(userLocation,        route.path)
      const dropoffInfo = findClosestPointOnRoute(selectedDestination, route.path)
      if (pickupInfo.fraction >= dropoffInfo.fraction) return
      if (pickupInfo.distance  > MAX_WALK_DISTANCE)   return
      if (dropoffInfo.distance > MAX_WALK_DISTANCE)   return

      const totalRouteLength = route.path.reduce((sum, p, i) =>
        i === 0 ? 0 : sum + calculateDistance(route.path[i-1][0], route.path[i-1][1], p[0], p[1]), 0)
      const busDistance     = Math.abs(dropoffInfo.fraction - pickupInfo.fraction) * totalRouteLength
      const walkToPickup    = pickupInfo.distance, walkFromDropoff = dropoffInfo.distance
      const totalWalkDistance = walkToPickup + walkFromDropoff

      if (busDistance < MIN_BUS_DISTANCE) return
      if ((walkToPickup / 80 + busDistance / 417 + walkFromDropoff / 80) > (directDistance / 80) * 1.3) return

      candidates.push({
        route,
        pickupPoint:     pickupInfo.point,
        dropoffPoint:    dropoffInfo.point,
        pickupStopName:  findNearestStop(pickupInfo.point,  stops)?.name_point || null,
        dropoffStopName: findNearestStop(dropoffInfo.point, stops)?.name_point || null,
        walkToPickup, walkFromDropoff, totalWalkDistance, busDistance,
        stopsCount: null, busesOnRoute,
        score: totalWalkDistance * 2.0 + busDistance * 0.3 - (busesOnRoute * 1000),
        totalTime: calculateETA(totalWalkDistance + busDistance, 20)
      })
    })

    const bestByRoute = new Map()
    for (const c of candidates) {
      const key = normalizeRouteId(c.route.id)
      if (!bestByRoute.has(key) || c.score < bestByRoute.get(key).score) bestByRoute.set(key, c)
    }
    suggestedRoutes.value = Array.from(bestByRoute.values())
      .sort((a, b) => a.score - b.score).slice(0, 5)
      .map((c, i) => ({ ...c, rank: i + 1 }))
  }

  const clearRoutes = () => { suggestedRoutes.value = [] }

  return { suggestedRoutes, findBestRoutes, normalizeRouteId, clearRoutes }
}

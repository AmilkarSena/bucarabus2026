import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { routesApi } from '../api/routes.js'
import { createRoutePoint } from '../api/catalogs.js'
import { getInsertOrderOnPath } from '../utils/routeUtils.js'

export const useRoutesStore = defineStore('routes', () => {
  // Estado - Inicia vacío, se carga desde la base de datos
  const routes = ref({})

  // Estado de rutas activas en el mapa (visibilidad)
  const activeRoutes    = ref(new Set())
  const routePolylines  = ref(new Map())

  // ID de la ruta enfocada (mostrar solo esa con paradas numeradas)
  const focusedRouteId  = ref(null)

  // ─── Getters ─────────────────────────────────────────────────────────────

  const routesList  = computed(() => Object.values(routes.value))
  const routesCount = computed(() => Object.keys(routes.value).length)

  /** Distancia total aproximada (solo para display rápido) */
  const totalDistance = computed(() =>
    routesList.value.reduce((total, route) => {
      if (route.path && route.path.length > 1) {
        return total + route.path.length * 0.5
      }
      return total
    }, 0)
  )

  // ─── Acciones de datos (BD) ───────────────────────────────────────────────

  /**
   * Cargar rutas desde la base de datos
   */
  const loadRoutes = async () => {
    try {
      const response = await routesApi.getAll()

      if (response.success) {
        routes.value = {}
        response.data.forEach(route => {
          routes.value[route.id] = {
            ...route,
            points: route.points || [],  // tab_route_points_assoc
            buses:  route.buses  || []
          }
        })
        console.log(`✅ ${response.count} rutas cargadas desde PostgreSQL`)
        return true
      }
    } catch (error) {
      console.error('❌ Error cargando rutas:', error)
      return false
    }
  }

  /**
   * Crear ruta y agregarla al store.
   * La respuesta solo trae { id, code, message } — los datos completos
   * se obtienen con getById para mantener el store consistente.
   */
  const addRoute = async (routeData) => {
    try {
      const response = await routesApi.create(routeData)

      if (response.success) {
        const { id, code, message } = response.data

        // Obtener datos completos de la ruta recién creada
        const detailRes = await routesApi.getById(id)
        const full = detailRes.success ? detailRes.data : { id, code }

        routes.value[id] = {
          ...full,
          points: [],
          buses:  []
        }

        console.log(`✅ Ruta creada en PostgreSQL — ${message}`)
        return routes.value[id]
      } else {
        throw new Error(response.error || 'Error creando ruta')
      }
    } catch (error) {
      console.error('❌ Error agregando ruta:', error)
      throw error
    }
  }

  /**
   * Actualizar metadatos de ruta en BD y en el store local.
   * La respuesta solo trae { id, code, message } — aplica merge con los datos actuales.
   */
  const updateRoute = async (id, routeData) => {
    try {
      const response = await routesApi.update(id, routeData)

      if (response.success) {
        // Merge: mantener datos actuales + sobreescribir con los que se enviaron
        if (routes.value[id]) {
          routes.value[id] = {
            ...routes.value[id],
            ...routeData,                                          // campos enviados por el modal
            fare: routeData.routeFare ?? routes.value[id]?.fare ?? 0, // normalizar la clave
            isCircular: routeData.isCircular ?? routes.value[id]?.isCircular ?? true,
            id                                                     // asegurar que el id no cambia
          }
        }

        console.log(`✅ Ruta ${id} actualizada en PostgreSQL`)
        return routes.value[id]
      } else {
        throw new Error(response.error || 'Error actualizando ruta')
      }
    } catch (error) {
      console.error('❌ Error actualizando ruta:', error)
      throw error
    }
  }

  /**
   * Soft-delete: desactiva la ruta en BD (is_active = FALSE) y
   * la elimina del store local para que deje de mostrarse.
   */
  const deleteRoute = async (id, userUpdate) => {
    try {
      const response = await routesApi.delete(id, userUpdate)

      // Quitar del store (ya no visible en la app)
      if (routes.value[id]) {
        deactivateRoute(id)
        delete routes.value[id]
      }

      console.log(`✅ Ruta ${id} desactivada`)
      return response
    } catch (error) {
      console.error('❌ Error desactivando ruta:', error)
      throw error
    }
  }

  /**
   * Cambiar is_active en la BD (toggle real) sin quitar del store.
   * Útil para reactivar una ruta previamente desactivada.
   */
  const toggleRouteStatus = async (id, isActive, userUpdate) => {
    try {
      const response = await routesApi.toggle(id, isActive, userUpdate)

      if (response.success && routes.value[id]) {
        routes.value[id].isActive = isActive
      }

      console.log(`✅ Ruta ${id} → isActive: ${isActive}`)
      return response
    } catch (error) {
      console.error('❌ Error cambiando estado de ruta:', error)
      throw error
    }
  }

  /**
   * Obtener los puntos asignados a una ruta
   */
  const getRoutePoints = async (routeId) => {
    try {
      const response = await routesApi.getPoints(routeId)
      if (response.success && routes.value[routeId]) {
        routes.value[routeId].points = response.data
      }
      return response.data || []
    } catch (error) {
      console.error('❌ Error obteniendo puntos de ruta desde store:', error)
      throw error
    }
  }

  /**
   * Asignar un punto de ruta existente a esta ruta
   */
  const assignRoutePoint = async (routeId, pointData) => {
    try {
      const response = await routesApi.assignPoint(routeId, pointData)
      return response
    } catch (error) {
      console.error('❌ Error asignando punto a ruta en store:', error)
      throw error
    }
  }

  /**
   * Desasignar un punto de una ruta
   */
  const unassignRoutePoint = async (routeId, pointId) => {
    try {
      const response = await routesApi.unassignPoint(routeId, pointId)
      return response
    } catch (error) {
      console.error('❌ Error desasignando punto en store:', error)
      throw error
    }
  }

  /**
   * Reordenar los puntos de una ruta
   * @param {number} routeId
   * @param {Array<{idPoint: number, order: number}>} orderArray
   */
  const reorderRoutePoints = async (routeId, orderArray) => {
    try {
      const response = await routesApi.reorderPoints(routeId, orderArray)
      return response
    } catch (error) {
      console.error('❌ Error reordenando puntos en store:', error)
      throw error
    }
  }

  /**
   * Crear un nuevo punto de ruta global y asignarlo a una ruta actual
   */
  const createAndAssignRoutePoint = async (routeId, pointData) => {
    try {
      // 1. Crear el punto en la BD global
      const createResponse = await createRoutePoint(pointData)
      
      if (createResponse.success) {
        const newPoint   = createResponse.data
        const routePath  = routes.value[routeId]?.path || []

        // 2. ⚡ Consultar la BD en este momento para obtener el estado REAL de los stops.
        //    Evita conflictos de constraint por datos obsoletos en el store.
        const freshPoints = await getRoutePoints(routeId)

        // Normalizar formato: getRoutePoints devuelve { idPoint, coordinates:[lat,lng], pointOrder }
        //                     getAllRoutes devuelve  { id_point, lat, lng, point_order }
        const existingStops = freshPoints.map(p => ({
          id_point:   p.idPoint    ?? p.id_point,
          lat:        p.lat        ?? p.coordinates?.[0],
          lng:        p.lng        ?? p.coordinates?.[1],
          pointOrder: p.pointOrder ?? p.point_order ?? 0,
        }))

        // 3. tempOrder = lastOrder + 1 — siempre libre en la BD (recién consultada)
        const { tempOrder, allStopsReorder } = getInsertOrderOnPath(
          newPoint.id_point,
          [parseFloat(newPoint.lat), parseFloat(newPoint.lng)],
          routePath,
          existingStops
        )

        // 4. Asignar en posición temporal (sin conflicto, BD acaba de confirmarlo)
        await assignRoutePoint(routeId, { idPoint: newPoint.id_point, pointOrder: tempOrder })

        // 5. Re-ordenar todos los stops por posición geométrica en el path
        if (allStopsReorder && allStopsReorder.length > 0) {
          await reorderRoutePoints(routeId, allStopsReorder)
        }

        return createResponse
      }
    } catch (error) {
      console.error('❌ Error creando y asignando punto:', error)
      throw error
    }
  }

  // ─── Búsqueda local ───────────────────────────────────────────────────────

  const getRouteById = (id) => routes.value[id]

  const searchRoutes = (query) => {
    if (!query) return routesList.value

    const lowerQuery = query.toLowerCase()
    return routesList.value.filter(route =>
      // id es SMALLINT (número) — convertir a string para buscar
      String(route.id).includes(query) ||
      (route.name        && route.name.toLowerCase().includes(lowerQuery)) ||
      (route.description && route.description.toLowerCase().includes(lowerQuery))
    )
  }

  // ─── Visibilidad en el mapa (estado local, no BD) ─────────────────────────

  const activateRoute = (id) => activeRoutes.value.add(id)

  const deactivateRoute = (id) => activeRoutes.value.delete(id)

  /**
   * Enfoca una ruta: la muestra sola en el mapa con sus paradas numeradas.
   * Si la ruta ya está enfocada, quita el foco (limpia).
   * Carga los stops frescos desde la BD si aún no están en el store.
   */
  const focusRoute = async (id) => {
    if (focusedRouteId.value === id) {
      // Toggle off — quitar foco
      focusedRouteId.value = null
      return
    }

    // Cargar stops frescos si la ruta no los tiene o están vacíos
    if (!routes.value[id]?.stops?.length && !routes.value[id]?.points?.length) {
      try {
        const freshPoints = await getRoutePoints(id)
        if (routes.value[id] && freshPoints?.length) {
          routes.value[id].stops = freshPoints.map(p => ({
            id_point:    p.idPoint    ?? p.id_point,
            name_point:  p.namePoint  ?? p.name_point  ?? `Parada ${p.idPoint ?? p.id_point}`,
            lat:         parseFloat(p.lat ?? p.coordinates?.[0]),
            lng:         parseFloat(p.lng ?? p.coordinates?.[1]),
            point_order: p.pointOrder ?? p.point_order ?? 0,
          }))
        }
      } catch (e) {
        console.warn(`⚠️ No se pudieron cargar stops para ruta ${id}:`, e)
      }
    }

    focusedRouteId.value = id
  }

  /** Limpia el foco de ruta (llamado externamente o por clearActiveRoutes) */
  const clearFocusedRoute = () => { focusedRouteId.value = null }

  /** Alterna la visibilidad visual de la ruta en el mapa (solo UI) */
  const toggleMapRoute = (id) => {
    if (activeRoutes.value.has(id)) {
      deactivateRoute(id)
    } else {
      activateRoute(id)
    }
  }

  const clearActiveRoutes = () => activeRoutes.value.clear()

  const setRoutePolyline = (id, polyline) => routePolylines.value.set(id, polyline)

  const getRoutePolyline = (id) => routePolylines.value.get(id)

  const removeRoutePolyline = (id) => {
    const polyline = routePolylines.value.get(id)
    if (polyline) {
      routePolylines.value.delete(id)
      return polyline
    }
    return null
  }

  /** Alterna el campo `visible` local y sincroniza con activeRoutes */
  const toggleRouteVisibility = (id) => {
    if (routes.value[id]) {
      routes.value[id].visible = !routes.value[id].visible

      if (routes.value[id].visible) {
        activateRoute(id)
      } else {
        deactivateRoute(id)
      }

      console.log(`👁️ Visibilidad de ruta ${id}: ${routes.value[id].visible}`)
    }
  }

  const showAllRoutes = () => {
    routesList.value.forEach(route => {
      if (route.id && routes.value[route.id]) {
        routes.value[route.id].visible = true
        activateRoute(route.id)
      }
    })
    console.log('👁️ Mostrando todas las rutas en el mapa')
  }

  const hideAllRoutes = () => {
    routesList.value.forEach(route => {
      if (route.id && routes.value[route.id]) {
        routes.value[route.id].visible = false
        deactivateRoute(route.id)
      }
    })
    console.log('👁️‍🗨️ Ocultando todas las rutas del mapa')
  }

  const getBusesForRoute = (routeId) => {
    const route = routes.value[routeId]
    return route?.buses || []
  }

  // ─── Return ───────────────────────────────────────────────────────────────

  return {
    // Estado
    routes,
    activeRoutes,
    routePolylines,
    focusedRouteId,

    // Getters
    routesList,
    routesCount,
    totalDistance,

    // Acciones BD
    loadRoutes,
    addRoute,
    updateRoute,
    deleteRoute,
    toggleRouteStatus,
    getRoutePoints,
    assignRoutePoint,
    unassignRoutePoint,
    reorderRoutePoints,
    createAndAssignRoutePoint,

    // Búsqueda
    getRouteById,
    searchRoutes,

    // Visibilidad mapa (UI)
    activateRoute,
    deactivateRoute,
    toggleMapRoute,
    clearActiveRoutes,
    setRoutePolyline,
    getRoutePolyline,
    removeRoutePolyline,
    toggleRouteVisibility,
    showAllRoutes,
    hideAllRoutes,
    getBusesForRoute,

    // Foco de ruta (paradas numeradas)
    focusRoute,
    clearFocusedRoute
  }
})
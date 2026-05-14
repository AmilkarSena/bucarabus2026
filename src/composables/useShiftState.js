import { ref } from 'vue'

/**
 * Composable que provee utilidades de estado y visualización para la gestión de turnos.
 * 
 * Funciona como una capa de conveniencia para mapear datos crudos a etiquetas legibles:
 * 1. Mapeo de Identidades: Obtiene nombres de conductores y códigos AMB a partir de IDs o placas.
 * 2. Métricas de Flota: Calcula en tiempo real cuántos viajes tiene asignado un bus en el día 
 *    (útil para controlar la carga de trabajo del vehículo).
 * 3. Gestión de Disponibilidad: Permite marcar buses como activos/inactivos directamente 
 *    desde la interfaz de despacho.
 */
export function useShiftState({
  trips,
  allDayTrips,
  busesStore,
  driversStore
}) {

  // -- Formatters & UI Helpers --

  const getBusTripCount = (plateNumber) => {
    const currentRouteCount = trips.value.filter(
      t => t.busId === plateNumber && t.status_trip !== 4 && t.status_trip !== 5
    ).length
    const otherRoutesCount = allDayTrips.value.filter(
      t => t.busId === plateNumber && t.status_trip !== 4 && t.status_trip !== 5
    ).length
    return currentRouteCount + otherRoutesCount
  }

  const getBusPlate = (plateNumber) => {
    return plateNumber || 'N/A'
  }

  const getBusAmbCode = (plateNumber) => {
    const bus = busesStore.buses.find(b => b.plate_number === plateNumber)
    return bus?.amb_code || plateNumber || 'N/A'
  }

  const getDriverName = (driverId) => {
    if (!driverId) return 'Sin asignar'
    const driver = driversStore.drivers.find(d => d.id_driver === driverId)
    return driver ? driver.name_driver : 'Desconocido'
  }

  const getDriverNameForBus = (plateNumber) => {
    const bus = busesStore.buses.find(b => b.plate_number === plateNumber)
    return bus ? getDriverName(bus.assigned_driver) : 'N/A'
  }

  const setBusAvailability = (plateNumber, isAvailable) => {
    const bus = busesStore.buses.find(b => b.plate_number === plateNumber)
    if (bus) {
      bus.is_active = isAvailable
    }
  }

  return {
    getBusTripCount,
    getBusPlate,
    getBusAmbCode,
    getDriverName,
    getDriverNameForBus,
    setBusAvailability
  }
}

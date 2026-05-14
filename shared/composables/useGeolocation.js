import { ref } from 'vue'

/**
 * Composable compartido que encapsula la API de Geolocalización nativa del navegador.
 * Usado por: App Pasajero, App Conductor.
 *
 * @param {Function} onLocationUpdate - Callback ejecutado en cada cambio de posición.
 * @param {Function} onFirstPosition  - Callback ejecutado solo al obtener la primera posición exitosa.
 */
export function useGeolocation(onLocationUpdate, onFirstPosition) {
  const userLocation = ref(null)
  const watchId      = ref(null)

  const startWatchingLocation = () => {
    if (watchId.value) return
    watchId.value = navigator.geolocation.watchPosition(
      (position) => {
        userLocation.value = {
          lat: position.coords.latitude,
          lng: position.coords.longitude
        }
        if (onLocationUpdate) onLocationUpdate(userLocation.value)
      },
      (error) => console.error('Error watching location:', error),
      { enableHighAccuracy: true, maximumAge: 5000 }
    )
  }

  const requestLocation = () => {
    if (!navigator.geolocation) {
      alert('Tu navegador no soporta geolocalización')
      return
    }
    navigator.geolocation.getCurrentPosition(
      (position) => {
        userLocation.value = {
          lat: position.coords.latitude,
          lng: position.coords.longitude
        }
        if (onLocationUpdate) onLocationUpdate(userLocation.value)
        if (onFirstPosition)  onFirstPosition(userLocation.value)
        startWatchingLocation()
      },
      (error) => {
        console.error('Error GPS:', error)
        alert('No pudimos obtener tu ubicación. Verifica los permisos.')
      },
      { enableHighAccuracy: true }
    )
  }

  const stopWatchingLocation = () => {
    if (watchId.value) {
      navigator.geolocation.clearWatch(watchId.value)
      watchId.value = null
    }
  }

  return { userLocation, requestLocation, stopWatchingLocation }
}

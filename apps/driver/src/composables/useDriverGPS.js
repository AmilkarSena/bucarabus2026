import { ref } from 'vue'

// Detecta si estamos en Capacitor nativo (Android/iOS)
// SIN importar @capacitor/core a nivel de módulo para evitar crashes en web
const isNativePlatform = () => {
  try {
    return (typeof window !== 'undefined' && window.Capacitor?.isNativePlatform?.()) ?? false
  } catch {
    return false
  }
}

export function useDriverGPS() {
  const currentLocation = ref(null)
  const currentSpeed = ref(0)
  const watcherId = ref(null) // Para Capacitor nativo
  const watchId = ref(null)   // Para Web Fallback

  const startTracking = async (onPositionCallback) => {
    if (isNativePlatform()) {
      // En Android/iOS: usar BackgroundGeolocation de Capacitor
      try {
        const { registerPlugin } = await import('@capacitor/core')
        const BackgroundGeolocation = registerPlugin('BackgroundGeolocation')

        const id = await BackgroundGeolocation.addWatcher(
          {
            backgroundMessage: 'Cancel to prevent battery drain.',
            backgroundTitle: 'BucaraBus: Turno Activo.',
            requestPermissions: true,
            stale: false,
            distanceFilter: 10
          },
          (location, error) => {
            if (error) {
              if (error.code === 'NOT_AUTHORIZED') {
                if (window.confirm('App needs location tracking permission. Open settings?')) {
                  BackgroundGeolocation.openSettings()
                }
              }
              return console.error('GPS Capacitor error:', error)
            }

            currentLocation.value = {
              lat: location.latitude,
              lng: location.longitude,
              accuracy: location.accuracy,
              speed: location.speed ? location.speed * 3.6 : 0,
              heading: location.bearing
            }
            currentSpeed.value = currentLocation.value.speed

            if (onPositionCallback) onPositionCallback(currentLocation.value)
          }
        )
        watcherId.value = id
        return true
      } catch (err) {
        console.error('Error iniciando BackgroundGeolocation, usando fallback web:', err)
        return startWebGeolocation(onPositionCallback)
      }
    } else {
      // En navegador web: usar la API estándar de geolocalización
      return startWebGeolocation(onPositionCallback)
    }
  }

  const startWebGeolocation = (onPositionCallback) => {
    if (!navigator.geolocation) {
      console.warn('Este navegador no soporta geolocalización')
      return false
    }

    watchId.value = navigator.geolocation.watchPosition(
      (position) => {
        const { latitude, longitude, accuracy, speed, heading } = position.coords
        currentLocation.value = { lat: latitude, lng: longitude, accuracy, speed: speed ? speed * 3.6 : 0, heading }
        currentSpeed.value = currentLocation.value.speed
        if (onPositionCallback) onPositionCallback(currentLocation.value)
      },
      (error) => {
        console.warn('GPS Web error (código ' + error.code + '):', error.message)
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    )
    return true
  }

  const stopTracking = () => {
    if (isNativePlatform()) {
      if (watcherId.value) {
        import('@capacitor/core').then(({ registerPlugin }) => {
          registerPlugin('BackgroundGeolocation').removeWatcher({ id: watcherId.value })
        }).catch(console.error)
        watcherId.value = null
      }
    } else {
      if (watchId.value) {
        navigator.geolocation.clearWatch(watchId.value)
        watchId.value = null
      }
    }
  }

  return { currentLocation, currentSpeed, startTracking, stopTracking }
}

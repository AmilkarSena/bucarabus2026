import { ref } from 'vue'
import { Capacitor } from '@capacitor/core'
import { Geolocation } from '@capacitor/geolocation'

// Detecta si el GPS está bloqueado por falta de HTTPS
const isGpsBlocked = (error) => {
  if (!error) return false
  // code 1 = PERMISSION_DENIED (incluye el bloqueo por origen inseguro)
  return error.code === 1 && (
    error.message?.includes('secure origin') ||
    error.message?.includes('Only secure') ||
    error.message?.includes('permanently-removed')
  )
}

export function usePassengerGeolocation(onLocationUpdate, onFirstPosition) {
  const userLocation = ref(null)
  const watchId = ref(null)
  const gpsError = ref(null)    // 'denied' | 'insecure' | 'unavailable' | null
  const gpsBlocked = ref(false) // true si el sitio no tiene HTTPS

  const startWatchingLocation = async () => {
    if (watchId.value) return

    if (Capacitor.isNativePlatform()) {
      watchId.value = await Geolocation.watchPosition(
        { enableHighAccuracy: true, maximumAge: 5000 },
        (position, err) => {
          if (err || !position) { console.warn('Error watch nativo:', err); return }
          gpsError.value = null
          userLocation.value = { lat: position.coords.latitude, lng: position.coords.longitude }
          if (onLocationUpdate) onLocationUpdate(userLocation.value)
        }
      )
    } else {
      watchId.value = navigator.geolocation.watchPosition(
        (position) => {
          gpsError.value = null
          userLocation.value = { lat: position.coords.latitude, lng: position.coords.longitude }
          if (onLocationUpdate) onLocationUpdate(userLocation.value)
        },
        (error) => {
          // Error silencioso en el watcher, no mostramos popup
          console.warn('Error watching location:', error.message)
        },
        { enableHighAccuracy: true, maximumAge: 5000 }
      )
    }
  }

  const requestLocation = async () => {
    if (Capacitor.isNativePlatform()) {
      try {
        const permission = await Geolocation.requestPermissions()
        if (permission.location !== 'granted' && permission.location !== 'prompt') {
          gpsError.value = 'denied'
          return
        }
        const position = await Geolocation.getCurrentPosition({ enableHighAccuracy: true })
        gpsError.value = null
        gpsBlocked.value = false
        userLocation.value = { lat: position.coords.latitude, lng: position.coords.longitude }
        if (onLocationUpdate) onLocationUpdate(userLocation.value)
        if (onFirstPosition)  onFirstPosition(userLocation.value)
        startWatchingLocation()
      } catch (error) {
        console.warn('Error GPS Nativo:', error)
        gpsError.value = 'unavailable'
      }
    } else {
      if (!navigator.geolocation) {
        gpsError.value = 'unavailable'
        return
      }
      navigator.geolocation.getCurrentPosition(
        (position) => {
          gpsError.value = null
          gpsBlocked.value = false
          userLocation.value = { lat: position.coords.latitude, lng: position.coords.longitude }
          if (onLocationUpdate) onLocationUpdate(userLocation.value)
          if (onFirstPosition)  onFirstPosition(userLocation.value)
          startWatchingLocation()
        },
        (error) => {
          console.warn('Error GPS:', error.message)
          if (isGpsBlocked(error)) {
            gpsBlocked.value = true
            gpsError.value = 'insecure'
          } else if (error.code === 1) {
            gpsError.value = 'denied'
          } else {
            gpsError.value = 'unavailable'
          }
          // No mostramos alert() — la UI reacciona al estado gpsError/gpsBlocked
        },
        { enableHighAccuracy: true, timeout: 10000 }
      )
    }
  }

  const stopWatchingLocation = () => {
    if (watchId.value) {
      if (Capacitor.isNativePlatform()) Geolocation.clearWatch({ id: watchId.value })
      else navigator.geolocation.clearWatch(watchId.value)
      watchId.value = null
    }
  }

  return { userLocation, requestLocation, stopWatchingLocation, gpsError, gpsBlocked }
}

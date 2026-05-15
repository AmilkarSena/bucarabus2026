import { ref, onMounted, onUnmounted } from 'vue'

export function usePWAInstall() {
  const deferredPrompt = ref(null)
  const isInstallable = ref(false)

  const handleBeforeInstallPrompt = (e) => {
    // Previene que el mini-infobar de Chrome aparezca automáticamente
    e.preventDefault()
    // Guarda el evento para poder dispararlo después
    deferredPrompt.value = e
    // Actualiza el estado para mostrar nuestro botón de instalación
    isInstallable.value = true
  }

  const installPWA = async () => {
    if (!deferredPrompt.value) return

    // Muestra el prompt de instalación nativo
    deferredPrompt.value.prompt()

    // Espera a que el usuario responda al prompt
    const { outcome } = await deferredPrompt.value.userChoice
    
    // Opcional: limpiar la variable si ya fue instalada o rechazada
    if (outcome === 'accepted') {
      console.log('El usuario aceptó instalar la PWA')
    } else {
      console.log('El usuario rechazó la instalación')
    }
    
    // Independientemente de la elección, el prompt no puede usarse de nuevo
    deferredPrompt.value = null
    isInstallable.value = false
  }

  // Detectar si ya fue instalada exitosamente para ocultar el botón
  const handleAppInstalled = () => {
    deferredPrompt.value = null
    isInstallable.value = false
    console.log('PWA instalada con éxito')
  }

  onMounted(() => {
    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.addEventListener('appinstalled', handleAppInstalled)
  })

  onUnmounted(() => {
    window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    window.removeEventListener('appinstalled', handleAppInstalled)
  })

  return {
    isInstallable,
    installPWA
  }
}

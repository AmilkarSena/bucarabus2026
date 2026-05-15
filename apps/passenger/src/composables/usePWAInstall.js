import { ref } from 'vue'

// Estado global para que el evento no se pierda si se dispara muy temprano
const deferredPrompt = ref(null)
const isInstallable = ref(false)

const handleBeforeInstallPrompt = (e) => {
  e.preventDefault()
  deferredPrompt.value = e
  isInstallable.value = true
}

const handleAppInstalled = () => {
  deferredPrompt.value = null
  isInstallable.value = false
  console.log('PWA instalada con éxito')
}

// Escuchar los eventos tan pronto como se cargue el script (muy temprano)
if (typeof window !== 'undefined') {
  window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
  window.addEventListener('appinstalled', handleAppInstalled)
}

export function usePWAInstall() {
  const installPWA = async () => {
    if (!deferredPrompt.value) return

    deferredPrompt.value.prompt()
    const { outcome } = await deferredPrompt.value.userChoice
    
    if (outcome === 'accepted') {
      console.log('El usuario aceptó instalar la PWA')
    } else {
      console.log('El usuario rechazó la instalación')
    }
    
    deferredPrompt.value = null
    isInstallable.value = false
  }

  return {
    isInstallable,
    installPWA
  }
}

<template>
  <Transition name="fade">
    <div v-if="appStore.isCreatingRoute" class="creation-mode-banner">
      <div class="banner-left">
        <span class="pulse-dot" :style="{ backgroundColor: appStore.draftRouteColor }"></span>
        <span>Modo Creación Activo: Selecciona paradas</span>
      </div>
      <div class="banner-right">
        <label style="font-size: 12px; opacity: 0.8; margin-right: 6px; display: flex; align-items: center; gap: 4px; cursor: pointer;">
          <input type="checkbox" v-model="appStore.useSmartRouting" style="cursor: pointer;">
          Trazado Inteligente
        </label>
        <div style="width: 1px; height: 20px; background: rgba(255,255,255,0.2); margin-left: 6px; margin-right: 12px;"></div>
        
        <label for="route-color-picker" style="font-size: 12px; opacity: 0.8; margin-right: 6px;">Color:</label>
        <input 
          type="color" 
          id="route-color-picker" 
          v-model="appStore.draftRouteColor" 
          class="route-color-picker"
          title="Elige el color de la ruta"
          style="cursor: pointer; border: none; width: 24px; height: 24px; border-radius: 4px; padding: 0; margin-right: 12px;"
        >
        <div style="width: 1px; height: 20px; background: rgba(255,255,255,0.2); margin-right: 12px;"></div>
        <button @click="appStore.cancelRouteCreation()" class="cancel-creation-btn" title="Cancelar creación de ruta">
          ✕
        </button>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { useAppStore } from '../../stores/app'

const appStore = useAppStore()
</script>

<style scoped>
.creation-mode-banner {
  position: absolute;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(15, 23, 42, 0.85);
  backdrop-filter: blur(8px);
  color: white;
  padding: 10px 20px;
  border-radius: 30px;
  font-size: 14px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 10px;
  z-index: 1000;
  box-shadow: 0 4px 15px rgba(0, 0, 0, 0.3);
  border: 1px solid rgba(255, 255, 255, 0.1);
  pointer-events: auto;
  justify-content: space-between;
  animation: banner-glow 1.5s ease-in-out infinite alternate;
}

@keyframes banner-glow {
  from {
    box-shadow: 0 0 5px rgba(59, 130, 246, 0.3), 0 4px 15px rgba(0, 0, 0, 0.3);
    border-color: rgba(59, 130, 246, 0.4);
  }
  to {
    box-shadow: 0 0 20px rgba(59, 130, 246, 0.9), 0 4px 15px rgba(0, 0, 0, 0.3);
    border-color: rgba(59, 130, 246, 1);
  }
}

.banner-left {
  display: flex;
  align-items: center;
  gap: 10px;
}

.banner-right {
  display: flex;
  align-items: center;
  gap: 5px;
}

.cancel-creation-btn {
  background: transparent;
  border: none;
  color: rgba(255, 255, 255, 0.6);
  font-size: 16px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 4px;
  border-radius: 50%;
  transition: all 0.2s ease;
}

.cancel-creation-btn:hover {
  color: #ef4444;
  background: rgba(239, 68, 68, 0.1);
}

.pulse-dot {
  width: 10px;
  height: 10px;
  background-color: #ef4444;
  border-radius: 50%;
  display: inline-block;
  animation: pulse-red 1.5s infinite;
}

@keyframes pulse-red {
  0% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.5); opacity: 0.5; }
  100% { transform: scale(1); opacity: 1; }
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>

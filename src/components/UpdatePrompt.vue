<template>
  <Transition name="slide-up">
    <div v-if="needRefresh" class="update-prompt">
      <span class="update-icon">🔄</span>
      <span class="update-text">Nueva versión disponible</span>
      <button class="btn-update" @click="update">Actualizar</button>
      <button class="btn-dismiss" @click="close">✕</button>
    </div>
  </Transition>
</template>

<script setup>
import { useRegisterSW } from 'virtual:pwa-register/vue'

const { needRefresh, updateServiceWorker } = useRegisterSW({
  onRegistered(r) {
    // Check for updates every 60 minutes
    if (r) setInterval(() => r.update(), 60 * 60 * 1000)
  }
})

const update = () => updateServiceWorker(true)
const close = () => { needRefresh.value = false }
</script>

<style scoped>
.update-prompt {
  position: fixed;
  bottom: 80px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  gap: 10px;
  background: #1e293b;
  color: white;
  padding: 12px 16px;
  border-radius: 12px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.3);
  z-index: 9999;
  max-width: 340px;
  width: calc(100% - 32px);
  font-size: 0.9rem;
}

.update-icon { font-size: 1.2rem; flex-shrink: 0; }
.update-text { flex: 1; font-weight: 500; }

.btn-update {
  background: #667eea;
  color: white;
  border: none;
  border-radius: 8px;
  padding: 6px 14px;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  flex-shrink: 0;
}

.btn-update:hover { background: #5568d3; }

.btn-dismiss {
  background: none;
  border: none;
  color: #94a3b8;
  font-size: 1rem;
  cursor: pointer;
  padding: 4px;
  flex-shrink: 0;
}

.btn-dismiss:hover { color: white; }

.slide-up-enter-active,
.slide-up-leave-active {
  transition: all 0.3s ease;
}

.slide-up-enter-from,
.slide-up-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(20px);
}
</style>

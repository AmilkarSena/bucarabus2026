<template>
  <header class="app-header">
    <div class="header-left">
      <button class="btn-menu" @click="$emit('open-menu')">☰</button>
      <span class="logo">🚌</span>
      <h1>BucaraBus</h1>
      <div class="connection-indicator" :class="{ connected: isConnected }" title="Conexión en tiempo real">
        <span class="status-dot"></span>
      </div>
    </div>

    <div class="header-right">
      <div v-if="isOffline" class="offline-badge" title="Mostrando rutas guardadas localmente">
        <span>📶</span> Offline
      </div>
      <button @click="$emit('locate')" class="btn-locate" :disabled="!userLocation" title="Mi ubicación">📍</button>
    </div>
  </header>
</template>

<script setup>
// App Pasajero es pública — sin autenticación, sin router
defineProps({
  isConnected:  { type: Boolean, default: false },
  userLocation: { type: Object,  default: null  },
  isOffline:    { type: Boolean, default: false }
})
defineEmits(['locate', 'open-menu'])
</script>

<style scoped>
.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  z-index: 1000;
  flex-shrink: 0;
}
.header-left  { display: flex; align-items: center; gap: 8px; }
.btn-menu { background: none; border: none; color: white; font-size: 1.5rem; cursor: pointer; padding: 4px; display: flex; align-items: center; justify-content: center; }
.logo         { font-size: 1.5rem; margin-left: 2px; }
.app-header h1 { font-size: 1.2rem; font-weight: 600; margin: 0; }
.connection-indicator { display: flex; align-items: center; margin-left: 4px; }
.status-dot   { width: 10px; height: 10px; border-radius: 50%; background: #f44336; }
.connection-indicator.connected .status-dot { background: #4caf50; animation: pulse 2s infinite; }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
.header-right { display: flex; align-items: center; gap: 12px; }
.offline-badge { display: flex; align-items: center; gap: 4px; background: rgba(0,0,0,0.3); padding: 4px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: 600; }
.btn-locate   { width: 36px; height: 36px; border-radius: 50%; border: none; background: rgba(255,255,255,0.2); color: white; font-size: 1.1rem; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: background 0.2s; }
.btn-locate:hover:not(:disabled) { background: rgba(255,255,255,0.3); }
.btn-locate:disabled { opacity: 0.5; }
</style>

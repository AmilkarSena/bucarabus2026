<template>
  <div class="connection-status" :class="{ connected: isConnected }">
    <span class="status-dot"></span>
    <span>{{ isConnected ? 'Conectado' : 'Sin conexión' }}</span>
  </div>
</template>

<script setup>
defineProps({
  isConnected: {
    type: Boolean,
    default: false
  }
})
</script>

<style scoped>
.connection-status {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 8px;
  background: rgba(248, 113, 113, 0.1);
  color: #f87171;
  font-size: 12px;
  font-weight: 500;
}

.connection-status.connected {
  background: rgba(34, 197, 94, 0.1);
  color: #22c55e;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}
</style>

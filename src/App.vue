<template>
  <router-view />
  <UpdatePrompt />
</template>

<script setup>
import { onMounted } from 'vue'
import { useRoutesStore } from './stores/routes'
import UpdatePrompt from './components/UpdatePrompt.vue'

const routesStore = useRoutesStore()

// Inicialización
onMounted(async () => {
  console.log('Vue BucaraBus App initialized with Router')
  
  // Cargar rutas desde PostgreSQL
  console.log('📡 Cargando rutas desde la base de datos...')
  const loaded = await routesStore.loadRoutes()
  
  if (loaded) {
    console.log('✅ Rutas cargadas exitosamente')
  } else {
    console.warn('⚠️ No se pudieron cargar las rutas desde la BD, usando datos locales')
  }
})
</script>

<style>
/* Estilos globales */
* {
  box-sizing: border-box;
}

#app {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

body {
  margin: 0;
  padding: 0;
  overflow: hidden;
}
</style>
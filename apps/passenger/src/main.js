import { createApp } from 'vue'
import 'leaflet/dist/leaflet.css'
import App from './App.vue'

// App Pasajero — Sin Vue Router (SPA de una sola vista), Sin Pinia
// La app es pública: no requiere autenticación
createApp(App).mount('#app')

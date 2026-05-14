import { createApp } from 'vue'
import { createPinia } from 'pinia'
import 'leaflet/dist/leaflet.css'
import App from './App.vue'
import router from './router'
import './assets/css/styles.css'
import './assets/modal-forms.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)

import { useAuthStore } from '@shared/api/auth'
useAuthStore().initializeUser()

app.use(router)

app.mount('#app')

// Cargar catálogos al inicio (estados de viaje desde la DB)
import { useCatalogsStore } from './stores/catalogs.js'
useCatalogsStore().fetchTripStatuses()
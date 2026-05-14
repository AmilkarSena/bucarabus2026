import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/LoginView.vue'),
    meta: { title: 'Iniciar Sesión — Conductor', public: true }
  },
  {
    path: '/',
    name: 'driver-app',
    component: () => import('../views/DriverAppView.vue'),
    meta: { title: 'Mi Turno — BucaraBus', requiresAuth: true, requiresRole: 'driver' }
  }
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
})

// Guard de autenticación — usa localStorage directamente para evitar
// dependencia de Pinia (que puede no estar activa aún en el ciclo de vida)
router.beforeEach((to, from, next) => {
  document.title = to.meta.title || 'BucaraBus Conductor'

  const token = localStorage.getItem('bucarabus_token')
  const isAuthenticated = !!token

  if (to.meta.requiresAuth && !isAuthenticated) {
    next({ name: 'login', query: { redirect: to.fullPath } })
  } else if (to.name === 'login' && isAuthenticated) {
    next({ name: 'driver-app' })
  } else {
    next()
  }
})

export default router

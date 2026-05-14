import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

// Layout base unificado
import BaseLayout from '../layouts/BaseLayout.vue'

// Views
import LandingView from '../views/LandingView.vue'
import LoginView from '../views/LoginView.vue'
import RegisterView from '../views/RegisterView.vue'
import ResetPasswordView from '../views/ResetPasswordView.vue'
const MonitorView = () => import('../views/MonitorView.vue')
const FleetView = () => import('../views/FleetView.vue')
const RoutesView = () => import('../views/RoutesView.vue')
const DriversView = () => import('../views/DriversView.vue')
const ShiftsView = () => import('../views/ShiftsView.vue')
const AlertsView = () => import('../views/AlertsView.vue')
const SettingsView = () => import('../views/SettingsView.vue')
const UsersView = () => import('../views/UsersView.vue')
const RolesPermissionsView = () => import('../views/RolesPermissionsView.vue')
const UserPermissionsView = () => import('../views/UserPermissionsView.vue')
const CatalogsView = () => import('../views/CatalogsView.vue')

const routes = [
  // Landing Page
  {
    path: '/',
    name: 'landing',
    component: LandingView,
    meta: { title: 'BucaraBus - Sistema de Gestión de Transporte', hideNav: true, public: true }
  },
  // Login
  {
    path: '/login',
    name: 'login',
    component: LoginView,
    meta: { title: 'Iniciar Sesión', hideNav: true, public: true }
  },
  // Register
  {
    path: '/register',
    name: 'register',
    component: RegisterView,
    meta: { title: 'Registrarse', hideNav: true, public: true }
  },
  // Reset Password
  {
    path: '/reset-password',
    name: 'reset-password',
    component: ResetPasswordView,
    meta: { title: 'Restablecer Contraseña', hideNav: true, public: true }
  },
  // Todas las rutas principales usan BaseLayout
  {
    path: '/',
    component: BaseLayout,
    meta: { requiresAuth: true },
    children: [
      // Rutas con mapa
      {
        path: 'monitor',
        name: 'monitor',
        component: MonitorView,
        meta: { title: 'Monitor en Tiempo Real', section: 'monitor', hasMap: true }
      },
      {
        path: 'routes',
        name: 'routes',
        component: RoutesView,
        meta: { title: 'Gestión de Rutas', section: 'routes', hasMap: true }
      },
      // Rutas sin mapa
      {
        path: 'fleet',
        name: 'fleet',
        component: FleetView,
        meta: { title: 'Buses', section: 'buses', hasMap: false }
      },
      {
        path: 'fleet/assign-driver',
        name: 'assign-driver',
        component: () => import('../views/AssignDriverView.vue'),
        meta: { title: 'Asignar Conductor', section: 'assign-driver', hasMap: false }
      },
      {
        path: 'drivers',
        name: 'drivers',
        component: DriversView,
        meta: { title: 'Gestión de Conductores', section: 'drivers', hasMap: false }
      },
      {
        path: 'shifts',
        name: 'shifts',
        component: ShiftsView,
        meta: { title: 'Gestión de Turnos', section: 'shifts', hasMap: false }
      },
      {
        path: 'users',
        name: 'users',
        component: UsersView,
        meta: { title: 'Gestión de Usuarios', section: 'users', hasMap: false }
      },
      {
        path: 'users/permissions',
        name: 'permissions',
        component: RolesPermissionsView,
        meta: { title: 'Gestión de Permisos de Roles', section: 'permissions', hasMap: false }
      },
      {
        path: 'users/user-permissions',
        name: 'user-permissions',
        component: UserPermissionsView,
        meta: { title: 'Permisos por Usuario', section: 'user-permissions', hasMap: false }
      },
      {
        path: 'catalogs',
        name: 'catalogs',
        component: CatalogsView,
        meta: { title: 'Catálogos del Sistema', section: 'catalogs', hasMap: false }
      },
      {
        path: 'alerts',
        name: 'alerts',
        component: AlertsView,
        meta: { title: 'Centro de Alertas', section: 'alerts', hasMap: false }
      },
      {
        path: 'settings',
        name: 'settings',
        component: SettingsView,
        meta: { title: 'Configuración del Sistema', section: 'settings', hasMap: false }
      }
    ]
  }
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes
})

// Actualizar el título de la página y proteger rutas
router.beforeEach((to, from, next) => {
  // Actualizar título
  document.title = to.meta.title ? `${to.meta.title} - BucaraBus` : 'BucaraBus Dashboard'
  
  // Verificar autenticación
  const authStore = useAuthStore()
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  const isPublic = to.meta.public
  const userRole = authStore.userRole
  
  if (requiresAuth && !authStore.isAuthenticated) {
    // Ruta protegida y usuario no autenticado -> redirigir a login
    console.log('🔒 Acceso denegado, redirigiendo a login')
    next({
      name: 'login',
      query: { redirect: to.fullPath }
    })
  } else if (to.name === 'login' && authStore.isAuthenticated) {
    // Usuario autenticado intenta ir a login -> redirigir según rol
    console.log('✅ Usuario ya autenticado, redirigiendo...')
    next({ name: 'monitor' })
  } else {
    // Permitir acceso
    next()
  }
})

export default router
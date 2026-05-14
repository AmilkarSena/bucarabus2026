<template>
  <div class="login-page">
    <div class="login-container">
      <!-- Logo y marca -->
      <div class="login-header" @click="router.push('/')" style="cursor:pointer">
        <div class="logo-circle">
          <span class="logo-icon">🚌</span>
        </div>
        <h1>BucaraBus</h1>
        <p class="subtitle">Sistema de Gestión de Transporte Urbano</p>
      </div>

      <!-- Formulario de login -->
      <div class="login-card">
        <h2>Iniciar Sesión</h2>
        
        <form @submit.prevent="handleLogin">
          <div class="form-group">
            <label for="email">
              <span class="label-icon">👤</span>
              Usuario o Email
            </label>
            <input
              id="email"
              v-model="credentials.email"
              type="text"
              placeholder="admin@bucarabus.com"
              required
              autocomplete="username"
              :disabled="loading"
            />
          </div>

          <div class="form-group">
            <label for="password">
              <span class="label-icon">🔒</span>
              Contraseña
            </label>
            <div class="password-input">
              <input
                id="password"
                v-model="credentials.password"
                :type="showPassword ? 'text' : 'password'"
                placeholder="••••••••"
                required
                autocomplete="current-password"
                :disabled="loading"
              />
              <button
                type="button"
                class="toggle-password"
                @click="showPassword = !showPassword"
                :disabled="loading"
              >
                {{ showPassword ? '👁️' : '👁️‍🗨️' }}
              </button>
            </div>
          </div>

          <!-- Recuperar contraseña -->
          <div class="forgot-password">
            <a href="#" @click.prevent="showRecoveryModal = true" class="forgot-link">¿Olvidaste tu contraseña?</a>
          </div>

          <!-- Mensaje de error -->
          <div v-if="error" class="error-message">
            <span class="error-icon">⚠️</span>
            {{ error }}
          </div>

          <!-- Botón de login -->
          <button type="submit" class="btn-login" :disabled="loading">
            <span v-if="!loading">🚀 Ingresar al Sistema</span>
            <span v-else class="loading-spinner">⏳ Ingresando...</span>
          </button>
        </form>
      </div>

      <!-- Acceso sin login -->
      <div class="guest-access">
        <p class="guest-text">¿Solo quieres ver dónde está tu bus?</p>
        <button class="btn-guest" @click="router.push('/pasajero')">
          🗺️ Ver mapa en tiempo real
        </button>
      </div>

      <!-- Footer -->
      <div class="login-footer">
        <button class="btn-back" @click="goBack">
          ← Volver a inicio
        </button>
      </div>
    </div>

    <!-- Background decorativo -->
    <div class="login-background">
      <div class="bg-shape shape-1"></div>
      <div class="bg-shape shape-2"></div>
      <div class="bg-shape shape-3"></div>
    </div>

    <!-- Modal de Recuperación de Contraseña (componente separado) -->
    <ForgotPasswordModal v-model="showRecoveryModal" />
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import ForgotPasswordModal from '../components/ForgotPasswordModal.vue'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const credentials = ref({
  email: '',
  password: ''
})

const showPassword = ref(false)
const loading = ref(false)
const error = ref(null)

// Estado del modal de recuperación
const showRecoveryModal = ref(false)

const handleLogin = async () => {
  loading.value = true
  error.value = null

  try {
    const result = await authStore.login(credentials.value.email, credentials.value.password)
    
    if (result.success) {
      // Redirigir según el rol del usuario
      const userRole = authStore.userRole
      let redirectPath = '/monitor' // Default para admin
      
      if (userRole === 'driver') {
        redirectPath = '/conductor'
      } else if (userRole === 'passenger') {
        redirectPath = '/pasajero'
      } else if (route.query.redirect) {
        redirectPath = route.query.redirect
      }
      
      console.log(`✅ Login exitoso, redirigiendo a ${redirectPath}`)
      router.push(redirectPath)
    } else {
      error.value = result.error || 'Error al iniciar sesión'
    }
  } catch (err) {
    error.value = 'Error de conexión. Por favor, intenta nuevamente.'
    console.error('Login error:', err)
  } finally {
    loading.value = false
  }
}

const goBack = () => {
  router.push('/')
}
</script>

<style scoped>
.login-page {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 1rem;
}

.login-container {
  position: relative;
  z-index: 10;
  width: 100%;
  max-width: 450px;
  margin: auto;
  padding: 1rem 0;
}

/* Header del login */
.login-header {
  text-align: center;
  margin-bottom: 1rem;
}

.logo-circle {
  width: 55px;
  height: 55px;
  background: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 0.6rem;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
  animation: float 3s ease-in-out infinite;
}

@keyframes float {
  0%, 100% { transform: translateY(0px); }
  50% { transform: translateY(-10px); }
}

.logo-icon {
  font-size: 2rem;
}

.login-header h1 {
  font-size: 1.85rem;
  font-weight: 800;
  color: white;
  margin: 0 0 0.3rem 0;
  text-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
}

.subtitle {
  color: rgba(255, 255, 255, 0.9);
  font-size: 0.875rem;
  margin: 0;
}

/* Card del formulario */
.login-card {
  background: white;
  border-radius: 16px;
  padding: 1.5rem;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  animation: slideUp 0.5s ease-out;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.login-card h2 {
  margin: 0 0 1rem 0;
  font-size: 1.4rem;
  font-weight: 700;
  color: #1e293b;
  text-align: center;
}

/* Formulario */
.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.875rem;
  font-weight: 600;
  color: #475569;
  margin-bottom: 0.4rem;
}

.label-icon {
  font-size: 1.2rem;
}

.form-group input {
  width: 100%;
  padding: 0.7rem 0.85rem;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.9rem;
  transition: all 0.3s;
  background: #f8fafc;
}

.form-group input:focus {
  outline: none;
  border-color: #667eea;
  background: white;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-group input:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.password-input {
  position: relative;
  display: flex;
  align-items: center;
}

.password-input input {
  padding-right: 3rem;
}

.toggle-password {
  position: absolute;
  right: 0.75rem;
  background: none;
  border: none;
  font-size: 1.2rem;
  cursor: pointer;
  padding: 0.5rem;
  opacity: 0.6;
  transition: opacity 0.3s;
}

.toggle-password:hover:not(:disabled) {
  opacity: 1;
}

.toggle-password:disabled {
  cursor: not-allowed;
}

/* Recuperar contraseña */
.forgot-password {
  display: flex;
  justify-content: flex-end;
  margin-top: -10px;
  margin-bottom: 20px;
}

.forgot-link {
  font-size: 0.85rem;
  color: var(--primary-color, #6366f1);
  text-decoration: none;
  transition: color 0.3s;
}

.forgot-link:hover {
  text-decoration: underline;
  color: var(--primary-hover, #4f46e5);
}

/* Error message */
.error-message {
  background: #fee2e2;
  color: #991b1b;
  padding: 0.65rem 0.8rem;
  border-radius: 8px;
  font-size: 0.8rem;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  margin-bottom: 1rem;
  border: 1px solid #fecaca;
}

.error-icon {
  font-size: 1.2rem;
}

/* Botón de login */
.btn-login {
  width: 100%;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border: none;
  padding: 0.8rem;
  border-radius: 8px;
  font-size: 0.95rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3);
}

.btn-login:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 6px 25px rgba(102, 126, 234, 0.4);
}

.btn-login:active:not(:disabled) {
  transform: translateY(0);
}

.btn-login:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.loading-spinner {
  display: inline-block;
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

/* Footer */
.login-footer {
  text-align: center;
  margin-top: 1rem;
}

/* Acceso sin login */
.guest-access {
  text-align: center;
  margin-top: 1.25rem;
  padding: 1rem;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.guest-text {
  color: rgba(255, 255, 255, 0.85);
  font-size: 0.875rem;
  margin: 0 0 0.75rem;
}

.btn-guest {
  background: rgba(255, 255, 255, 0.95);
  color: #667eea;
  border: none;
  padding: 0.65rem 1.5rem;
  border-radius: 25px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  width: 100%;
}

.btn-guest:hover {
  background: white;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
}

.btn-back {
  background: rgba(255, 255, 255, 0.2);
  color: white;
  border: 2px solid rgba(255, 255, 255, 0.4);
  padding: 0.65rem 1.25rem;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-back:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateX(-5px);
}

/* Background decorativo */
.login-background {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  z-index: 1;
}

.bg-shape {
  position: absolute;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 50%;
  animation: float-shape 20s ease-in-out infinite;
}

.shape-1 {
  width: 400px;
  height: 400px;
  top: -200px;
  right: -100px;
  animation-delay: 0s;
}

.shape-2 {
  width: 300px;
  height: 300px;
  bottom: -150px;
  left: -100px;
  animation-delay: 3s;
}

.shape-3 {
  width: 200px;
  height: 200px;
  top: 50%;
  left: 10%;
  animation-delay: 6s;
}

@keyframes float-shape {
  0%, 100% { transform: translate(0, 0) scale(1); }
  25% { transform: translate(20px, -20px) scale(1.1); }
  50% { transform: translate(0, -40px) scale(0.9); }
  75% { transform: translate(-20px, -20px) scale(1.05); }
}

/* Responsive */
@media (max-width: 768px) {
  .login-page {
    padding: 0.65rem 0.65rem 1.25rem 0.65rem;
    align-items: flex-start;
  }

  .login-container {
    margin-top: 0.35rem;
    margin-bottom: 1.25rem;
    padding: 0.5rem 0;
  }

  .login-header {
    margin-bottom: 0.85rem;
  }

  .logo-circle {
    width: 48px;
    height: 48px;
    margin-bottom: 0.45rem;
  }

  .logo-icon {
    font-size: 1.65rem;
  }

  .login-card {
    padding: 1.35rem 1.15rem;
  }

  .login-header h1 {
    font-size: 1.65rem;
    margin-bottom: 0.2rem;
  }

  .subtitle {
    font-size: 0.8rem;
  }

  .login-card h2 {
    font-size: 1.3rem;
    margin-bottom: 0.85rem;
  }

  .form-group {
    margin-bottom: 0.85rem;
  }

  .form-group label {
    font-size: 0.825rem;
    margin-bottom: 0.35rem;
  }

  .form-group input {
    padding: 0.6rem 0.7rem;
    font-size: 0.875rem;
  }

  .btn-login {
    padding: 0.7rem;
    font-size: 0.9rem;
  }

  .login-footer {
    margin-top: 0.85rem;
  }

  .btn-back {
    padding: 0.6rem 1.15rem;
    font-size: 0.85rem;
  }
}


</style>

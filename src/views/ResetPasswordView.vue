<template>
  <div class="reset-page">
    <div class="reset-container">
      <div class="reset-header">
        <div class="logo-circle">
          <span class="logo-icon">🔑</span>
        </div>
        <h1>Restablecer Contraseña</h1>
        <p class="subtitle">BucaraBus — Gestión de Transporte</p>
      </div>

      <div class="reset-card">
        <!-- Estado: Cargando validación de token -->
        <div v-if="isValidating" class="status-state">
          <div class="spinner"></div>
          <p>Validando enlace de recuperación...</p>
        </div>

        <!-- Estado: Token Inválido o Expirado -->
        <div v-else-if="!isTokenValid" class="status-state error">
          <span class="status-icon">❌</span>
          <h3>Enlace Inválido</h3>
          <p>El enlace de recuperación ha expirado o es incorrecto. Por favor, solicita uno nuevo desde la página de inicio de sesión.</p>
          <button class="btn-primary" @click="router.push('/login')">Ir al Login</button>
        </div>

        <!-- Estado: Éxito -->
        <div v-else-if="isSuccess" class="status-state success">
          <span class="status-icon">✅</span>
          <h3>¡Contraseña Actualizada!</h3>
          <p>Tu contraseña ha sido restablecida correctamente. Ya puedes iniciar sesión con tus nuevas credenciales.</p>
          <button class="btn-primary" @click="router.push('/login')">Ir al Login</button>
        </div>

        <!-- Formulario: Restablecimiento -->
        <form v-else @submit.prevent="handleReset">
          <p class="form-help">Ingresa tu nueva contraseña para acceder a tu cuenta.</p>

          <div class="form-group">
            <label for="password">Nueva Contraseña</label>
            <div class="password-input">
              <input
                id="password"
                v-model="passwords.new"
                :type="showPassword ? 'text' : 'password'"
                placeholder="Mínimo 8 caracteres"
                required
                minlength="8"
                :disabled="loading"
              />
              <button type="button" class="toggle-btn" @click="showPassword = !showPassword">
                {{ showPassword ? '👁️' : '👁️‍🗨️' }}
              </button>
            </div>
          </div>

          <div class="form-group">
            <label for="confirm">Confirmar Contraseña</label>
            <input
              id="confirm"
              v-model="passwords.confirm"
              type="password"
              placeholder="Repite la contraseña"
              required
              :disabled="loading"
            />
          </div>

          <div v-if="error" class="error-message">
            ⚠️ {{ error }}
          </div>

          <button type="submit" class="btn-submit" :disabled="loading || !isMatching">
            <span v-if="!loading">Actualizar Contraseña</span>
            <span v-else>⏳ Procesando...</span>
          </button>
        </form>
      </div>

      <div class="reset-footer">
        <a href="#" @click.prevent="router.push('/login')" class="back-link">← Volver al inicio de sesión</a>
      </div>
    </div>

    <!-- Background decorativo (mismo que login) -->
    <div class="reset-background">
      <div class="bg-shape shape-1"></div>
      <div class="bg-shape shape-2"></div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import api from '../api/client.js'

const router = useRouter()
const route = useRoute()

const token = route.query.token

const isValidating = ref(true)
const isTokenValid = ref(false)
const loading = ref(false)
const isSuccess = ref(false)
const error = ref(null)
const showPassword = ref(false)

const passwords = reactive({
  new: '',
  confirm: ''
})

const isMatching = computed(() => {
  return passwords.new.length >= 8 && passwords.new === passwords.confirm
})

onMounted(async () => {
  if (!token) {
    isValidating.value = false
    isTokenValid.value = false
    return
  }

  try {
    const { data } = await api.get(`/auth/validate-reset-token?token=${token}`)
    isTokenValid.value = data.valid
  } catch (err) {
    isTokenValid.value = false
  } finally {
    isValidating.value = false
  }
})

const handleReset = async () => {
  if (!isMatching.value) return

  loading.value = true
  error.value = null

  try {
    const { data } = await api.post('/auth/reset-password', {
      token,
      newPassword: passwords.new
    })

    if (data.success) {
      isSuccess.value = true
    } else {
      error.value = data.message || 'No se pudo actualizar la contraseña.'
    }
  } catch (err) {
    error.value = err.response?.data?.message || 'Error de conexión con el servidor.'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.reset-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f1f5f9;
  position: relative;
  overflow: hidden;
  padding: 20px;
}

.reset-container {
  width: 100%;
  max-width: 420px;
  position: relative;
  z-index: 10;
}

.reset-header {
  text-align: center;
  margin-bottom: 2rem;
}

.logo-circle {
  width: 64px;
  height: 64px;
  background: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 1rem;
  box-shadow: 0 4px 12px rgba(0,0,0,0.05);
}

.logo-icon { font-size: 2rem; }

.reset-header h1 {
  font-size: 1.5rem;
  font-weight: 700;
  color: #1e293b;
  margin: 0;
}

.subtitle {
  color: #64748b;
  font-size: 0.875rem;
  margin-top: 0.25rem;
}

.reset-card {
  background: white;
  border-radius: 16px;
  padding: 2rem;
  box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1);
}

.status-state {
  text-align: center;
  padding: 1rem 0;
}

.status-icon {
  font-size: 3rem;
  display: block;
  margin-bottom: 1rem;
}

.status-state h3 {
  color: #1e293b;
  margin-bottom: 0.5rem;
}

.status-state p {
  color: #64748b;
  margin-bottom: 1.5rem;
  line-height: 1.5;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #f3f3f3;
  border-top: 4px solid #6366f1;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin: 0 auto 1rem;
}

@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

.form-help {
  color: #64748b;
  font-size: 0.95rem;
  margin-bottom: 1.5rem;
}

.form-group { margin-bottom: 1.25rem; }

.form-group label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #475569;
  margin-bottom: 0.5rem;
}

.password-input {
  position: relative;
  display: flex;
}

.password-input input {
  width: 100%;
  padding: 0.75rem 2.5rem 0.75rem 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 1rem;
  outline: none;
  transition: all 0.2s;
}

.password-input input:focus {
  border-color: #6366f1;
  box-shadow: 0 0 0 3px rgba(99,102,241,0.1);
}

#confirm {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 1rem;
  outline: none;
  box-sizing: border-box;
}

.toggle-btn {
  position: absolute;
  right: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  cursor: pointer;
  padding: 0;
  font-size: 1.2rem;
}

.btn-submit, .btn-primary {
  width: 100%;
  padding: 0.875rem;
  background: #6366f1;
  color: white;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 1rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-submit:hover:not(:disabled), .btn-primary:hover {
  background: #4f46e5;
  transform: translateY(-1px);
}

.btn-submit:disabled {
  background: #cbd5e1;
  cursor: not-allowed;
}

.error-message {
  background: #fef2f2;
  color: #991b1b;
  padding: 0.75rem;
  border-radius: 8px;
  font-size: 0.9rem;
  margin-bottom: 1.25rem;
}

.reset-footer {
  text-align: center;
  margin-top: 1.5rem;
}

.back-link {
  color: #64748b;
  text-decoration: none;
  font-size: 0.9rem;
  transition: color 0.2s;
}

.back-link:hover { color: #1e293b; }

/* Background shapes */
.reset-background {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
}

.bg-shape {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
}

.shape-1 {
  width: 500px;
  height: 500px;
  background: rgba(99, 102, 241, 0.1);
  top: -250px;
  right: -100px;
}

.shape-2 {
  width: 400px;
  height: 400px;
  background: rgba(139, 92, 246, 0.1);
  bottom: -200px;
  left: -100px;
}
</style>

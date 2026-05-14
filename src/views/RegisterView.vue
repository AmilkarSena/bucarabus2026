<template>
  <div class="register-page">
    <div class="register-container">
      <!-- Logo y marca -->
      <div class="register-header" @click="router.push('/')" style="cursor:pointer">
        <div class="logo-circle">
          <span class="logo-icon">🚌</span>
        </div>
        <h1>BucaraBus</h1>
        <p class="subtitle">Registro de Pasajeros</p>
      </div>

      <!-- Formulario de registro -->
      <div class="register-card">
        <h2>Crear Cuenta de Pasajero</h2>
        
        <form @submit.prevent="handleRegister">
          <div class="form-group">
            <label for="name">
              <span class="label-icon">👤</span>
              Nombre Completo
            </label>
            <input
              id="name"
              v-model="formData.name"
              type="text"
              placeholder="Juan Pérez"
              required
              autocomplete="name"
              minlength="3"
              maxlength="100"
              :disabled="loading"
              @blur="validateNameField"
            />
            <small class="field-hint">Entre 3 y 100 caracteres (solo letras y espacios)</small>
            <small v-if="fieldErrors.name" class="field-error">{{ fieldErrors.name }}</small>
          </div>

          <div class="form-group">
            <label for="email">
              <span class="label-icon">📧</span>
              Correo Electrónico
            </label>
            <input
              id="email"
              v-model="formData.email"
              type="email"
              placeholder="usuario@ejemplo.com"
              required
              autocomplete="email"
              :disabled="loading"
              @blur="validateEmailField"
            />
            <small class="field-hint">Correo electrónico válido (máximo 255 caracteres)</small>
            <small v-if="fieldErrors.email" class="field-error">{{ fieldErrors.email }}</small>
          </div>

          <div class="form-group">
            <label for="password">
              <span class="label-icon">🔒</span>
              Contraseña
            </label>
            <div class="password-input">
              <input
                id="password"
                v-model="formData.password"
                :type="showPassword ? 'text' : 'password'"
                placeholder="••••••••"
                required
                autocomplete="new-password"
                :disabled="loading"
                @blur="validatePasswordField"
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
            <small class="field-hint">Mínimo 8 caracteres (mayúscula, minúscula y número)</small>
            <small v-if="fieldErrors.password" class="field-error">{{ fieldErrors.password }}</small>
            <small v-else-if="passwordStrength" :class="['password-strength', passwordStrength.toLowerCase()]">Fortaleza: {{ passwordStrength }}</small>
          </div>

          <div class="form-group">
            <label for="confirmPassword">
              <span class="label-icon">🔐</span>
              Confirmar Contraseña
            </label>
            <div class="password-input">
              <input
                id="confirmPassword"
                v-model="formData.confirmPassword"
                :type="showConfirmPassword ? 'text' : 'password'"
                placeholder="••••••••"
                required
                autocomplete="new-password"
                :disabled="loading"
                @blur="validateConfirmPasswordField"
              />
              <button
                type="button"
                class="toggle-password"
                @click="showConfirmPassword = !showConfirmPassword"
                :disabled="loading"
              >
                {{ showConfirmPassword ? '👁️' : '👁️‍🗨️' }}
              </button>
            </div>
            <small v-if="fieldErrors.confirmPassword" class="field-error">{{ fieldErrors.confirmPassword }}</small>
          </div>

          <!-- Mensaje de error -->
          <div v-if="error" class="error-message">
            <span class="error-icon">⚠️</span>
            {{ error }}
          </div>

          <!-- Mensaje de éxito -->
          <div v-if="success" class="success-message">
            <span class="success-icon">✅</span>
            {{ success }}
          </div>

          <!-- Botón de registro -->
          <button type="submit" class="btn-register" :disabled="loading">
            <span v-if="!loading">🚌 Crear Cuenta de Pasajero</span>
            <span v-else class="loading-spinner">⏳ Creando cuenta...</span>
          </button>
        </form>

        <!-- Link de login -->
        <div class="login-link">
          <span>¿Ya tienes cuenta?</span>
          <a href="#" @click.prevent="goToLogin">Iniciar Sesión</a>
        </div>
      </div>

      <!-- Botón volver -->
      <button class="btn-back" @click="goToLanding">
        ← Volver al inicio
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const formData = ref({
  name: '',
  email: '',
  password: '',
  confirmPassword: ''
})

const fieldErrors = ref({
  name: '',
  email: '',
  password: '',
  confirmPassword: ''
})

const passwordStrength = ref('')

const showPassword = ref(false)
const showConfirmPassword = ref(false)
const loading = ref(false)
const error = ref('')
const success = ref('')

const validateName = (name) => {
  // Trim automático
  const trimmedName = name.trim()
  
  // Validar longitud
  if (trimmedName.length < 3) {
    return 'El nombre debe tener al menos 3 caracteres'
  }
  if (trimmedName.length > 100) {
    return 'El nombre no puede exceder 100 caracteres'
  }
  
  // Validar que solo contenga letras, espacios, acentos y ñ
  const nameRegex = /^[a-záéíóúñA-ZÁÉÍÓÚÑ\s]+$/
  if (!nameRegex.test(trimmedName)) {
    return 'El nombre solo puede contener letras y espacios'
  }
  
  // Validar que no haya espacios múltiples
  if (/\s{2,}/.test(trimmedName)) {
    return 'El nombre no puede contener espacios múltiples'
  }
  
  return null
}

const validateNameField = () => {
  fieldErrors.value.name = validateName(formData.value.name)
}

const validateEmail = (email) => {
  // Trim automático
  const trimmedEmail = email.trim()
  
  // Validar longitud
  if (trimmedEmail.length === 0) {
    return 'El correo electrónico es obligatorio'
  }
  if (trimmedEmail.length > 255) {
    return 'El correo electrónico no puede exceder 255 caracteres'
  }
  
  // Validar formato de email (patrón más robusto)
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(trimmedEmail)) {
    return 'El correo electrónico no es válido (ej: usuario@ejemplo.com)'
  }
  
  // Validar que no haya caracteres especiales prohibidos
  if (/[<>()\[\]\\,;:\s"]/g.test(trimmedEmail)) {
    return 'El correo electrónico contiene caracteres no permitidos'
  }
  
  return null
}

const validateEmailField = () => {
  fieldErrors.value.email = validateEmail(formData.value.email)
}

const validatePassword = (password) => {
  // Validar longitud
  if (password.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres'
  }
  if (password.length > 128) {
    return 'La contraseña no puede exceder 128 caracteres'
  }
  
  // Validar que contenga al menos una mayúscula
  if (!/[A-Z]/.test(password)) {
    return 'La contraseña debe contener al menos una LETRA MAYÚSCULA'
  }
  
  // Validar que contenga al menos una minúscula
  if (!/[a-z]/.test(password)) {
    return 'La contraseña debe contener al menos una letra minúscula'
  }
  
  // Validar que contenga al menos un número
  if (!/[0-9]/.test(password)) {
    return 'La contraseña debe contener al menos un NÚMERO (0-9)'
  }
  
  return null
}

const calculatePasswordStrength = (password) => {
  if (password.length === 0) {
    return ''
  }
  
  let strength = 0
  
  if (password.length >= 8) strength++
  if (password.length >= 12) strength++
  if (/[a-z]/.test(password)) strength++
  if (/[A-Z]/.test(password)) strength++
  if (/[0-9]/.test(password)) strength++
  if (/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) strength++
  
  if (strength <= 2) return 'Débil'
  if (strength <= 4) return 'Media'
  return 'Fuerte'
}

const validatePasswordField = () => {
  const error = validatePassword(formData.value.password)
  fieldErrors.value.password = error
  
  // Calcular fortaleza sólo si no hay errores
  if (!error) {
    passwordStrength.value = calculatePasswordStrength(formData.value.password)
  } else {
    passwordStrength.value = ''
  }
}

const validateConfirmPasswordField = () => {
  if (formData.value.password !== formData.value.confirmPassword) {
    fieldErrors.value.confirmPassword = 'Las contraseñas no coinciden'
  } else {
    fieldErrors.value.confirmPassword = ''
  }
}

const handleRegister = async () => {
  error.value = ''
  success.value = ''

  // Trim automático del nombre
  formData.value.name = formData.value.name.trim()

  // Validaciones
  if (!formData.value.name || !formData.value.email || !formData.value.password || !formData.value.confirmPassword) {
    error.value = 'Todos los campos son obligatorios'
    return
  }

  // Validar nombre específicamente
  const nameError = validateName(formData.value.name)
  if (nameError) {
    error.value = nameError
    return
  }

  // Validar email específicamente
  const emailError = validateEmail(formData.value.email)
  if (emailError) {
    error.value = emailError
    return
  }

  // Validar contraseña específicamente
  const passwordError = validatePassword(formData.value.password)
  if (passwordError) {
    error.value = passwordError
    return
  }

  if (formData.value.password !== formData.value.confirmPassword) {
    error.value = 'Las contraseñas no coinciden'
    return
  }

  loading.value = true

  try {
    // Registrar como pasajero (role hardcoded por seguridad)
    const result = await authStore.register({
      name: formData.value.name,
      email: formData.value.email,
      password: formData.value.password,
      role: 'passenger'  // Siempre pasajero en registro público
    })

    if (result.success) {
      success.value = '¡Cuenta creada exitosamente! Redirigiendo a la app...'
      
      // Limpiar formulario
      formData.value = {
        name: '',
        email: '',
        password: '',
        confirmPassword: ''
      }

      // Redirigir a vista de pasajero después de 1.5 segundos
      setTimeout(() => {
        router.push('/pasajero')
      }, 1500)
    } else {
      error.value = result.error || 'Error al crear la cuenta'
    }
  } catch (err) {
    console.error('Error en registro:', err)
    error.value = 'Error al crear la cuenta. Intenta nuevamente.'
  } finally {
    loading.value = false
  }
}

const goToLogin = () => {
  router.push('/login')
}

const goToLanding = () => {
  router.push('/')
}
</script>

<style scoped>
/* === VARIABLES === */
.register-page {
  --primary: #667eea;
  --secondary: #764ba2;
  --success: #10b981;
  --error: #ef4444;
  --dark: #1e293b;
  --gray: #64748b;
  --light: #f8fafc;
  --white: #ffffff;

  width: 100%;
  min-height: 100vh;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 1rem;
  overflow-y: auto;
}

.register-container {
  width: 100%;
  max-width: 450px;
  padding: 1rem 0;
  margin: auto;
}

/* === HEADER === */
.register-header {
  text-align: center;
  margin-bottom: 1rem;
  color: white;
}

.logo-circle {
  width: 55px;
  height: 55px;
  background: rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(10px);
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 0.75rem;
}

.logo-icon {
  font-size: 1.75rem;
}

.register-header h1 {
  font-size: 1.85rem;
  font-weight: 800;
  margin: 0 0 0.3rem 0;
  color: white;
}

.subtitle {
  font-size: 0.875rem;
  margin: 0;
  opacity: 0.95;
  color: white;
}

/* === CARD === */
.register-card {
  background: white;
  border-radius: 16px;
  padding: 1.5rem;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  margin-bottom: 0.75rem;
}

.register-card h2 {
  font-size: 1.4rem;
  font-weight: 700;
  color: var(--dark);
  margin: 0 0 1rem 0;
  text-align: center;
}

/* === FORM === */
.form-group {
  margin-bottom: 0.85rem;
}

.form-group label {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  font-weight: 600;
  font-size: 0.85rem;
  color: var(--dark);
  margin-bottom: 0.35rem;
}

.label-icon {
  font-size: 1rem;
}

.form-group input,
.form-group select {
  width: 100%;
  padding: 0.7rem;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  font-size: 0.9rem;
  transition: all 0.3s;
  font-family: inherit;
  background: white;
}

.form-group input:focus,
.form-group select:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.form-group input:disabled,
.form-group select:disabled {
  background: var(--light);
  cursor: not-allowed;
  opacity: 0.6;
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
  right: 0.5rem;
  background: transparent;
  border: none;
  cursor: pointer;
  font-size: 1.1rem;
  padding: 0.25rem;
  transition: transform 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.toggle-password:hover:not(:disabled) {
  transform: scale(1.15);
}

.toggle-password:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.field-hint {
  display: block;
  font-size: 0.75rem;
  color: var(--gray);
  margin-top: 0.25rem;
  font-style: italic;
}

.field-error {
  display: block;
  font-size: 0.75rem;
  color: var(--error);
  margin-top: 0.25rem;
  font-weight: 500;
}

.password-strength {
  display: block;
  font-size: 0.75rem;
  margin-top: 0.25rem;
  font-weight: 600;
}

.password-strength.débil {
  color: #ef4444;
}

.password-strength.media {
  color: #f59e0b;
}

.password-strength.fuerte {
  color: #10b981;
}

/* === MESSAGES === */
.error-message,
.success-message {
  padding: 0.65rem;
  border-radius: 8px;
  margin-bottom: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.85rem;
  font-weight: 500;
}

.error-message {
  background: rgba(239, 68, 68, 0.1);
  color: var(--error);
  border: 1px solid rgba(239, 68, 68, 0.3);
}

.success-message {
  background: rgba(16, 185, 129, 0.1);
  color: var(--success);
  border: 1px solid rgba(16, 185, 129, 0.3);
}

.error-icon,
.success-icon {
  font-size: 1rem;
}

/* === BUTTONS === */
.btn-register {
  width: 100%;
  padding: 0.8rem;
  background: linear-gradient(135deg, #10b981, #059669);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 0.95rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.3s;
  margin-top: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
}

.btn-register:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 10px 25px rgba(16, 185, 129, 0.3);
}

.btn-register:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

.loading-spinner {
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

.btn-back {
  width: 100%;
  padding: 0.65rem 1.25rem;
  background: rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(10px);
  color: white;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
}

.btn-back:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateY(-2px);
}

/* === LOGIN LINK === */
.login-link {
  text-align: center;
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px dashed #e2e8f0;
  font-size: 0.875rem;
  color: var(--gray);
}

.login-link a {
  color: var(--primary);
  text-decoration: none;
  font-weight: 600;
  margin-left: 0.5rem;
}

.login-link a:hover {
  text-decoration: underline;
}

/* === RESPONSIVE === */
@media (max-width: 768px) {
  .register-page {
    padding: 0.65rem;
  }

  .register-container {
    padding: 0.5rem 0;
  }

  .logo-circle {
    width: 48px;
    height: 48px;
  }

  .logo-icon {
    font-size: 1.6rem;
  }

  .register-header h1 {
    font-size: 1.65rem;
  }

  .register-card {
    padding: 1.35rem;
  }

  .register-card h2 {
    font-size: 1.3rem;
  }

  .form-group {
    margin-bottom: 0.75rem;
  }

  .form-group input,
  .form-group select {
    padding: 0.6rem;
    font-size: 0.875rem;
  }

  .btn-register {
    padding: 0.75rem;
  }
}
</style>

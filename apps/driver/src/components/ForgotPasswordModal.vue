<template>
  <Teleport to="body">
    <div v-if="modelValue" class="modal-overlay" @click.self="close">
      <div class="recovery-modal" role="dialog" aria-modal="true" aria-labelledby="recovery-title">

        <div class="modal-header">
          <h3 id="recovery-title">Recuperar Contraseña</h3>
          <button class="close-btn" @click="close" aria-label="Cerrar">×</button>
        </div>

        <div class="modal-body">
          <p class="recovery-text">
            Ingresa tu correo electrónico y te enviaremos las instrucciones para restablecer tu contraseña.
          </p>

          <form @submit.prevent="handleRecovery">
            <div class="form-group">
              <label for="recovery-email">Correo Electrónico</label>
              <input
                id="recovery-email"
                v-model="recoveryEmail"
                type="email"
                placeholder="usuario@ejemplo.com"
                required
                class="form-input"
                :disabled="recoveryLoading || recoverySuccess"
              />
            </div>

            <div v-if="recoverySuccess" class="success-message">
              ✅ Correo enviado con éxito. Revisa tu bandeja de entrada.
            </div>
            <div v-if="recoveryError" class="error-message">
              ⚠️ {{ recoveryError }}
            </div>

            <button type="submit" class="btn-recovery" :disabled="recoveryLoading || recoverySuccess">
              <span v-if="!recoveryLoading">✉️ Enviar Instrucciones</span>
              <span v-else>⏳ Enviando...</span>
            </button>
          </form>
        </div>

      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, watch } from 'vue'
import api from '@shared/api/client.js'

const props = defineProps({
  modelValue: { type: Boolean, required: true }
})

const emit = defineEmits(['update:modelValue'])

const recoveryEmail   = ref('')
const recoveryLoading = ref(false)
const recoverySuccess = ref(false)
const recoveryError   = ref(null)

// Limpiar el estado cada vez que el modal se abre
watch(() => props.modelValue, (isOpen) => {
  if (isOpen) {
    recoveryEmail.value   = ''
    recoverySuccess.value = false
    recoveryError.value   = null
  }
})

const close = () => emit('update:modelValue', false)

const handleRecovery = async () => {
  recoveryLoading.value = true
  recoveryError.value   = null

  try {
    const { data } = await api.post('/auth/forgot-password', { email: recoveryEmail.value })
    if (data.success) {
      recoverySuccess.value = true
      setTimeout(() => close(), 4000)
    } else {
      recoveryError.value = data.message || 'Error al enviar el correo'
    }
  } catch (err) {
    // Distinguir error de red vs error HTTP del servidor
    if (err.response?.data?.message) {
      recoveryError.value = err.response.data.message
    } else {
      recoveryError.value = 'No se pudo conectar con el servidor. Verifica tu conexión.'
    }
  } finally {
    recoveryLoading.value = false
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(15, 23, 42, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.recovery-modal {
  background: white;
  border-radius: 16px;
  width: 90%;
  max-width: 400px;
  box-shadow: 0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04);
  animation: modalFadeIn 0.3s ease-out;
  overflow: hidden;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #e2e8f0;
  background: #f8fafc;
}

.modal-header h3 {
  margin: 0;
  color: #1e293b;
  font-size: 1.25rem;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  color: #64748b;
  cursor: pointer;
  padding: 0;
  line-height: 1;
  transition: color 0.2s;
}

.close-btn:hover { color: #ef4444; }

.modal-body { padding: 1.5rem; }

.recovery-text {
  color: #64748b;
  font-size: 0.95rem;
  margin-bottom: 1.5rem;
  line-height: 1.5;
}

.form-group { margin-bottom: 0.5rem; }

.form-group label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
  margin-bottom: 0.4rem;
}

.form-input {
  width: 100%;
  padding: 0.65rem 0.85rem;
  border: 1px solid #d1d5db;
  border-radius: 8px;
  font-size: 0.95rem;
  outline: none;
  transition: border-color 0.2s;
  box-sizing: border-box;
}

.form-input:focus { border-color: #6366f1; box-shadow: 0 0 0 3px rgba(99,102,241,0.15); }
.form-input:disabled { background: #f9fafb; color: #9ca3af; cursor: not-allowed; }

.btn-recovery {
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
  margin-top: 1rem;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 0.5rem;
}

.btn-recovery:hover:not(:disabled) {
  background: #4f46e5;
  transform: translateY(-1px);
}

.btn-recovery:disabled { background: #94a3b8; cursor: not-allowed; }

.success-message {
  background: #dcfce7;
  color: #166534;
  padding: 0.75rem;
  border-radius: 8px;
  font-size: 0.9rem;
  margin-top: 1rem;
  text-align: center;
}

.error-message {
  background: #fef2f2;
  color: #991b1b;
  padding: 0.75rem;
  border-radius: 8px;
  font-size: 0.9rem;
  margin-top: 0.5rem;
}

@keyframes modalFadeIn {
  from { opacity: 0; transform: translateY(-20px) scale(0.95); }
  to   { opacity: 1; transform: translateY(0) scale(1); }
}
</style>

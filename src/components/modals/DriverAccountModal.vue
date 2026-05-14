<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="account-panel">
      <!-- Header -->
      <div class="account-header">
        <h2>
          {{ driver.id_user ? '🔗 Cuenta vinculada' : '👤 Sin cuenta de sistema' }}
        </h2>
        <button class="close-btn" @click="$emit('close')">&times;</button>
      </div>

      <div class="account-body">
        <p class="driver-name">Conductor: <strong>{{ driver.name_driver }}</strong></p>

        <!-- Modo: ya tiene cuenta -->
        <template v-if="driver.id_user">
          <div class="linked-info">
            <div v-if="loadingLinked" class="state-msg">Cargando...</div>
            <template v-else>
              <div class="info-row">
                <span class="label">ID usuario:</span>
                <span class="value">{{ driver.id_user }}</span>
              </div>
              <div class="info-row" v-if="linkedUser">
                <span class="label">Nombre:</span>
                <span class="value">{{ linkedUser.full_name }}</span>
              </div>
              <div class="info-row" v-if="linkedUser">
                <span class="label">Email:</span>
                <span class="value">{{ linkedUser.email_user }}</span>
              </div>
            </template>
          </div>

          <div class="action-row">
            <button
              class="btn btn-danger"
              :disabled="busy"
              @click="onUnlink"
            >
              {{ busy ? 'Desvinculando...' : '🔓 Desvincular cuenta' }}
            </button>
          </div>
        </template>

        <!-- Modo: sin cuenta -->
        <template v-else>
          <p class="hint">
            Selecciona un usuario existente con rol Conductor para vincularlo.
          </p>

          <div v-if="loadingUsers" class="state-msg">Cargando usuarios...</div>
          <div v-else-if="usersError" class="state-msg error">{{ usersError }}</div>
          <template v-else>
            <div class="form-field">
              <label for="user-select">Usuario</label>
              <select id="user-select" v-model="selectedUserId">
                <option value="">-- Seleccionar usuario --</option>
                <option
                  v-for="u in availableUsers"
                  :key="u.id_user"
                  :value="u.id_user"
                >
                  {{ u.full_name }} ({{ u.email_user }})
                </option>
              </select>
              <p v-if="availableUsers.length === 0" class="hint warn">
                ⚠️ No hay usuarios con rol Conductor sin cuenta asignada.
              </p>
            </div>

            <div class="action-row">
              <button
                class="btn btn-primary"
                :disabled="!selectedUserId || busy"
                @click="onLink"
              >
                {{ busy ? 'Vinculando...' : '🔗 Vincular cuenta' }}
              </button>
            </div>
          </template>
        </template>

        <!-- Mensaje de error de operación -->
        <p v-if="opError" class="state-msg error">{{ opError }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import apiClient from '../../api/client'
import { useDriversStore } from '../../stores/drivers'

const props = defineProps({
  driver: {
    type: Object,
    required: true
  }
})

const emit = defineEmits(['close', 'updated'])

const driversStore = useDriversStore()

// Usuario seleccionado en el select
const selectedUserId = ref('')

// Estado de carga de usuarios para vincular
const loadingUsers = ref(false)
const usersError = ref(null)
const availableUsers = ref([])

// Usuario vinculado (para mostrar nombre/email en modo "tiene cuenta")
const linkedUser = ref(null)
const loadingLinked = ref(false)

// Estado de operación (link/unlink)
const busy = ref(false)
const opError = ref(null)

onMounted(async () => {
  if (props.driver.id_user) {
    await loadLinkedUser()
  } else {
    await loadAvailableUsers()
  }
})

async function loadLinkedUser() {
  loadingLinked.value = true
  try {
    const response = await apiClient.get(`/users/${props.driver.id_user}`)
    linkedUser.value = response.data.data || response.data
  } catch {
    // Si falla, solo se muestra el ID
  } finally {
    loadingLinked.value = false
  }
}

async function loadAvailableUsers() {
  loadingUsers.value = true
  usersError.value = null
  try {
    // Traer usuarios con rol Conductor (id_role = 3) activos
    const response = await apiClient.get('/users', { params: { role: 3, active: true } })
    const all = response.data.data || []

    // Filtrar los que ya están vinculados a otro conductor
    // (el backend rechazará de todos modos por UNIQUE, pero filtramos para UX)
    const driversWithAccount = driversStore.drivers
      .filter(d => d.id_user !== null)
      .map(d => d.id_user)

    availableUsers.value = all.filter(u => !driversWithAccount.includes(u.id_user))
  } catch (err) {
    usersError.value = err.response?.data?.message || err.message
  } finally {
    loadingUsers.value = false
  }
}

async function onLink() {
  if (!selectedUserId.value) return
  busy.value = true
  opError.value = null
  try {
    const result = await driversStore.linkDriverAccount(props.driver.id_driver, selectedUserId.value)
    if (result.success) {
      emit('updated')
      emit('close')
    } else {
      opError.value = result.error || 'Error al vincular cuenta'
    }
  } finally {
    busy.value = false
  }
}

async function onUnlink() {
  if (!confirm(`¿Desvincular la cuenta del sistema de ${props.driver.name_driver}?\nEl usuario quedará inactivo.`)) return
  busy.value = true
  opError.value = null
  try {
    const result = await driversStore.unlinkDriverAccount(props.driver.id_driver)
    if (result.success) {
      emit('updated')
      emit('close')
    } else {
      opError.value = result.error || 'Error al desvincular cuenta'
    }
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.account-panel {
  background: white;
  border-radius: 12px;
  width: 420px;
  max-width: 95vw;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  overflow: hidden;
}

.account-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px 24px 16px;
  border-bottom: 1px solid #e2e8f0;
  background: #f8fafc;
}

.account-header h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #1e293b;
}

.close-btn {
  background: none;
  border: none;
  font-size: 22px;
  cursor: pointer;
  color: #64748b;
  line-height: 1;
  padding: 0 4px;
}

.close-btn:hover {
  color: #1e293b;
}

.account-body {
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.driver-name {
  margin: 0;
  color: #475569;
  font-size: 14px;
}

.hint {
  margin: 0;
  color: #64748b;
  font-size: 13px;
}

.hint.warn {
  color: #b45309;
}

.linked-info {
  background: #f0fdf4;
  border: 1px solid #bbf7d0;
  border-radius: 8px;
  padding: 12px 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.info-row {
  display: flex;
  gap: 8px;
  font-size: 14px;
}

.info-row .label {
  color: #64748b;
  min-width: 90px;
}

.info-row .value {
  color: #1e293b;
  font-weight: 500;
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-field label {
  font-size: 13px;
  font-weight: 500;
  color: #374151;
}

.form-field select {
  padding: 8px 12px;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 14px;
  color: #1e293b;
  background: white;
  cursor: pointer;
}

.form-field select:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.action-row {
  display: flex;
  justify-content: flex-end;
}

.btn {
  padding: 10px 20px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-primary {
  background: #667eea;
  color: white;
}

.btn-primary:not(:disabled):hover {
  background: #5a6fd6;
}

.btn-danger {
  background: #ef4444;
  color: white;
}

.btn-danger:not(:disabled):hover {
  background: #dc2626;
}

.state-msg {
  font-size: 13px;
  color: #64748b;
  text-align: center;
  padding: 8px;
}

.state-msg.error {
  color: #dc2626;
  background: #fef2f2;
  border-radius: 6px;
  padding: 8px 12px;
}
</style>

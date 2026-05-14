<template>
  <div class="settings-section">
    <div class="settings-header">
      <h4>Configuración General</h4>
      <p>Personaliza el comportamiento del sistema BucaraBus</p>
    </div>

    <div class="settings-content">
      <div class="settings-group">
        <h5>Información de la Empresa</h5>
        <div class="form-group">
          <label>Nombre de la Empresa</label>
          <input type="text" v-model="companyName" class="form-input">
        </div>
        <div class="form-group">
          <label>Zona Horaria</label>
          <select v-model="timezone" class="form-select">
            <option value="America/Bogota">América/Bogotá</option>
            <option value="America/New_York">América/Nueva York</option>
          </select>
        </div>
      </div>

      <div class="settings-group">
        <h5>Preferencias del Sistema</h5>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="checkbox" v-model="emailNotifications">
            <span>Notificaciones por email</span>
          </label>
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="checkbox" v-model="darkMode">
            <span>Modo oscuro</span>
          </label>
        </div>
        <div class="form-group">
          <label class="checkbox-label">
            <input type="checkbox" v-model="autoRefresh">
            <span>Actualización automática de datos</span>
          </label>
        </div>
      </div>

      <div class="settings-group">
        <h5>Configuración del Mapa</h5>
        <div class="form-group">
          <label>Proveedor de Mapas</label>
          <select v-model="mapProvider" class="form-select">
            <option value="openstreetmap">OpenStreetMap</option>
            <option value="mapbox">Mapbox</option>
          </select>
        </div>
        <div class="form-group">
          <label>Zoom por defecto</label>
          <input type="number" v-model.number="defaultZoom" min="1" max="20" class="form-input">
        </div>
      </div>

      <div class="settings-actions">
        <button class="btn primary" @click="saveSettings">Guardar Cambios</button>
        <button class="btn secondary" @click="resetSettings">Restablecer</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'

// Estado local
const companyName = ref('BucaraBus')
const timezone = ref('America/Bogota')
const emailNotifications = ref(true)
const darkMode = ref(false)
const autoRefresh = ref(true)
const mapProvider = ref('openstreetmap')
const defaultZoom = ref(13)

// Métodos
const saveSettings = () => {
  const settings = {
    companyName: companyName.value,
    timezone: timezone.value,
    emailNotifications: emailNotifications.value,
    darkMode: darkMode.value,
    autoRefresh: autoRefresh.value,
    mapProvider: mapProvider.value,
    defaultZoom: defaultZoom.value
  }

  // Guardar en localStorage (simulado)
  localStorage.setItem('bucarabus_settings', JSON.stringify(settings))
  alert('Configuración guardada exitosamente')
}

const resetSettings = () => {
  if (confirm('¿Está seguro de que desea restablecer la configuración?')) {
    companyName.value = 'BucaraBus'
    timezone.value = 'America/Bogota'
    emailNotifications.value = true
    darkMode.value = false
    autoRefresh.value = true
    mapProvider.value = 'openstreetmap'
    defaultZoom.value = 13
    alert('Configuración restablecida')
  }
}
</script>

<style scoped>
.settings-section {
  padding: 0;
}

.settings-header {
  margin-bottom: 24px;
}

.settings-header h4 {
  margin: 0 0 8px 0;
  color: #1e293b;
  font-size: 18px;
  font-weight: 600;
}

.settings-header p {
  margin: 0;
  color: #64748b;
}

.settings-content {
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
}

.settings-group {
  padding: 24px;
  border-bottom: 1px solid #f1f5f9;
}

.settings-group:last-child {
  border-bottom: none;
}

.settings-group h5 {
  margin: 0 0 20px 0;
  color: #1e293b;
  font-size: 16px;
  font-weight: 600;
}

.form-group {
  margin-bottom: 16px;
}

.form-group label {
  display: block;
  margin-bottom: 8px;
  color: #374151;
  font-weight: 500;
  font-size: 14px;
}

.form-input,
.form-select {
  width: 100%;
  max-width: 400px;
  padding: 12px;
  border: 1px solid #d1d5db;
  border-radius: 8px;
  font-size: 14px;
  background: white;
  transition: border-color 0.3s ease;
}

.form-input:focus,
.form-select:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.checkbox-label {
  display: flex !important;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  margin-bottom: 8px;
}

.checkbox-label input[type="checkbox"] {
  width: auto !important;
  margin: 0;
}

.checkbox-label span {
  color: #374151;
  font-weight: 500;
}

.settings-actions {
  display: flex;
  gap: 12px;
  padding: 20px 24px;
  border-top: 1px solid #e2e8f0;
  background: #f8fafc;
}

/* Responsive */
@media (max-width: 768px) {
  .settings-group {
    padding: 20px;
  }

  .settings-actions {
    flex-direction: column;
    padding: 16px 20px;
  }

  .form-input,
  .form-select {
    max-width: none;
  }
}
</style>
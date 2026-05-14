<template>
  <div>
    <div class="drivers-table-container">
      <table class="drivers-table">
        <thead>
          <tr>
            <th>Cédula</th>
            <th>Conductor</th>
            <th>Teléfono</th>
            <th>Licencia</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="driver in filteredDrivers" :key="driver.id_driver">
            <td>{{ driver.id_driver }}</td>
            <td class="driver-cell">
              <div class="driver-info-compact">
                <div class="driver-avatar-small">
                  <span>👤</span>
                </div>
                <div class="driver-name-col">
                  <span class="name">{{ driver.name_driver }}</span>
                  <span class="email" v-if="driver.email_driver">{{ driver.email_driver }}</span>
                </div>
              </div>
            </td>
            <td>{{ driver.phone_driver || '—' }}</td>
            <td>
              <div class="license-cell">
                <span class="category-badge-small">{{ driver.license_cat || '—' }}</span>
                <span class="license-date" :class="getLicenseStatusClass(driver.id_driver)">
                  {{ formatDate(driver.license_exp) }}
                  <span v-if="!isLicenseValid(driver.id_driver)">⚠️</span>
                </span>
              </div>
            </td>
            <td>
              <span class="status-badge-small" :class="getStatusClass(driver)">
                {{ driver.status_name || (driver.is_active ? 'Activo' : 'Inactivo') }}
              </span>
            </td>
            <td>
              <div class="actions-cell">
                <button
                  v-if="canEdit"
                  class="btn-icon"
                  title="Editar"
                  @click="$emit('edit-driver', driver)"
                >✏️</button>
                <button
                  class="btn-icon"
                  title="Ver Detalles"
                  @click="$emit('view-driver', driver)"
                >👁️</button>
                <button
                  v-if="canEdit"
                  class="btn-icon"
                  :title="driver.id_user ? 'Gestionar cuenta de sistema' : 'Vincular cuenta de sistema'"
                  @click="$emit('open-account', driver)"
                >{{ driver.id_user ? '🔗' : '👤' }}</button>
              </div>
            </td>
          </tr>
          <tr v-if="filteredDrivers.length === 0">
            <td colspan="6" class="no-data-cell">
              {{ isSearching
                ? 'No se encontraron conductores con los criterios de búsqueda.'
                : 'No hay conductores registrados.' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  filteredDrivers: { type: Array, required: true },
  canEdit:         { type: Boolean, default: false },
  isSearching:     { type: Boolean, default: false },
  // Helpers de presentación pasados desde el composable
  formatDate:           { type: Function, required: true },
  getStatusClass:       { type: Function, required: true },
  getLicenseStatusClass:{ type: Function, required: true },
  isLicenseValid:       { type: Function, required: true }
})

defineEmits(['edit-driver', 'view-driver', 'open-account'])
</script>

<style scoped>
/* ── Contenedor con scroll ─────────────────────────────────── */
.drivers-table-container {
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  overflow: auto;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  max-width: 100%;
  max-height: calc(100vh - 330px);
  min-height: 400px;
  margin-bottom: 40px;
  scrollbar-width: thin;
  scrollbar-color: #cbd5e1 #f1f5f9;
}

.drivers-table-container::-webkit-scrollbar { width: 8px; height: 8px; }
.drivers-table-container::-webkit-scrollbar-track { background: #f1f5f9; border-radius: 12px; }
.drivers-table-container::-webkit-scrollbar-thumb { background-color: #cbd5e1; border-radius: 4px; border: 2px solid #f1f5f9; }
.drivers-table-container::-webkit-scrollbar-thumb:hover { background-color: #94a3b8; }

/* ── Tabla ──────────────────────────────────────────────────── */
.drivers-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  min-width: 800px;
}

.drivers-table th {
  background: #f8fafc;
  padding: 16px;
  text-align: left;
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 1px solid #e2e8f0;
  position: sticky;
  top: 0;
  z-index: 10;
}

.drivers-table td {
  padding: 16px;
  border-bottom: 1px solid #f1f5f9;
  color: #1e293b;
  font-size: 14px;
  vertical-align: middle;
}

.drivers-table tr:last-child td { border-bottom: none; }
.drivers-table tr:hover { background: #f8fafc; }

/* ── Celda Conductor ────────────────────────────────────────── */
.driver-info-compact { display: flex; align-items: center; gap: 12px; }

.driver-avatar-small {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  flex-shrink: 0;
}

.driver-name-col { display: flex; flex-direction: column; }
.driver-name-col .name  { font-weight: 600; color: #1e293b; }
.driver-name-col .email { font-size: 12px; color: #64748b; }

/* ── Celda Licencia ─────────────────────────────────────────── */
.license-cell { display: flex; flex-direction: column; gap: 4px; }

.category-badge-small {
  background: #e0e7ff;
  color: #4338ca;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 700;
  display: inline-block;
  width: fit-content;
}

.license-date { font-size: 12px; }
.license-valid-text   { color: #10b981; }
.license-warning-text { color: #f59e0b; font-weight: 700; }
.license-expired-text { color: #ef4444; font-weight: 700; }

/* ── Badge de estado ────────────────────────────────────────── */
.status-badge-small {
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 500;
}

.status-badge-small.available  { background: #d1fae5; color: #065f46; }
.status-badge-small.on-trip    { background: #dbeafe; color: #1e40af; }
.status-badge-small.resting    { background: #fef3c7; color: #92400e; }
.status-badge-small.sick       { background: #fee2e2; color: #991b1b; }
.status-badge-small.unavailable{ background: #f1f5f9; color: #475569; }

/* ── Acciones ───────────────────────────────────────────────── */
.actions-cell { display: flex; gap: 8px; }

.btn-icon {
  width: 32px;
  height: 32px;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
  background: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  transition: all 0.2s ease;
}

.btn-icon:hover { background: #f8fafc; border-color: #cbd5e1; transform: translateY(-1px); }

/* ── Sin datos ──────────────────────────────────────────────── */
.no-data-cell {
  text-align: center;
  padding: 40px;
  color: #64748b;
  font-style: italic;
}
</style>

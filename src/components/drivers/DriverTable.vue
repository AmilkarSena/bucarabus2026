<template>
  <div>
    <div class="drivers-table-container">
      <table class="drivers-table">
        <thead class="mobile-hidden">
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
          <tr v-for="driver in filteredDrivers" :key="driver.id_driver" class="driver-row">
            <td class="id-cell mobile-hidden" data-label="Cédula">{{ driver.id_driver }}</td>
            <td class="driver-cell" data-label="Conductor">
              <div class="driver-info-compact">
                <div class="driver-avatar-small">
                  <span>👤</span>
                </div>
                <div class="driver-name-col">
                  <span class="name">{{ driver.name_driver }}</span>
                  <span class="email mobile-hidden" v-if="driver.email_driver">{{ driver.email_driver }}</span>
                </div>
              </div>
            </td>
            <td class="phone-cell-wrapper" data-label="Teléfono">{{ driver.phone_driver || '—' }}</td>
            <td class="license-cell-wrapper" data-label="Licencia">
              <div class="license-cell-compact">
                <span class="category-badge-small">{{ driver.license_cat || '—' }}</span>
                <span class="license-dot" :class="getLicenseStatusClass(driver.id_driver)" :title="formatDate(driver.license_exp)"></span>
              </div>
            </td>
            <td class="status-cell-wrapper" data-label="Estado">
              <span class="status-dot-large" :class="getStatusClass(driver)" :title="driver.status_name"></span>
            </td>
            <td class="actions-cell-wrapper" data-label="Acciones">
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

.license-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  display: inline-block;
}
.license-dot.license-valid-text { background: #10b981; }
.license-dot.license-warning-text { background: #f59e0b; }
.license-dot.license-expired-text { background: #ef4444; }

.status-dot-large {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  display: inline-block;
}
.status-dot-large.available { background: #10b981; box-shadow: 0 0 8px rgba(16, 185, 129, 0.4); }
.status-dot-large.on-trip { background: #3b82f6; }
.status-dot-large.resting { background: #f59e0b; }
.status-dot-large.sick { background: #ef4444; }
.status-dot-large.unavailable { background: #94a3b8; }

.license-cell-compact {
  display: flex;
  align-items: center;
  gap: 6px;
}

/* Responsive */
@media (max-width: 768px) {
  .drivers-table-container {
    background: transparent;
    border: none;
    box-shadow: none;
    max-height: none;
    padding: 0;
  }

  .mobile-hidden { display: none !important; }

  .drivers-table, .drivers-table tbody, .drivers-table tr {
    display: block;
    width: 100% !important;
    min-width: 0 !important; /* Fix explosion de 800px */
  }

  .driver-row {
    display: flex !important;
    align-items: center;
    padding: 10px 8px; /* Ajuste para evitar corte izquierdo */
    background: white;
    border-bottom: 1px solid #f1f5f9;
    gap: 8px; /* Reducido para mejor distribución */
    margin-bottom: 0 !important;
    border-radius: 0 !important;
    box-shadow: none !important;
  }

  .drivers-table td {
    padding: 0 !important;
    border: none !important;
    display: block;
    width: auto !important;
  }

  .drivers-table td::before { display: none !important; }

  .driver-info-compact {
    flex-direction: row;
    align-items: center;
    gap: 8px;
    text-align: left;
  }

  .driver-avatar-small {
    width: 32px;
    height: 32px;
    font-size: 14px;
    margin-left: 2px; /* Margen de seguridad */
  }

  .driver-name-col .name {
    font-size: 13px;
    max-width: 140px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .phone-cell-wrapper {
    display: none !important;
  }

  .driver-cell {
    flex: 1;
    min-width: 0;
  }

  .license-cell-wrapper {
    display: flex;
    justify-content: flex-end;
    align-items: center;
  }

  .status-cell-wrapper {
    width: 20px;
    display: flex;
    justify-content: center;
  }

  .actions-cell-wrapper {
    width: auto !important;
  }

  .actions-cell {
    background: transparent !important;
    padding: 0 !important;
    gap: 8px !important;
  }

  .btn-icon {
    width: 32px;
    height: 32px;
    font-size: 14px;
    border-radius: 8px;
    box-shadow: none;
  }
}
</style>

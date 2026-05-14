<template>
  <div>
    <div class="fleet-table-container">
      <table class="fleet-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Bus</th>
            <th>Empresa</th>
            <th>Seguros</th>
            <th>Documentos</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="bus in filteredBuses" :key="bus.id_bus">
            <td class="id-cell">{{ bus.id_bus }}</td>
            <td class="bus-cell">
              <div class="bus-info-compact">
                <div class="bus-avatar-with-plate">
                  <div class="bus-emoji">🚌</div>
                  <div class="bus-plate-overlay">{{ bus.plate_number }}</div>
                </div>
                <div class="bus-name-col">
                  <span class="code" v-if="bus.amb_code">{{ bus.amb_code }}</span>
                  <span class="driver" v-if="bus.assigned_driver">
                    👨‍✈️ {{ getDriverName(bus.assigned_driver) }}
                  </span>
                  <span class="driver no-driver" v-else>Sin conductor</span>
                </div>
              </div>
            </td>
            <td>
              <div class="company-cell">
                <span class="company-name" :class="getCompanyClass(bus.id_company)">
                  {{ getCompanyName(bus.id_company) }}
                </span>
              </div>
            </td>
            <td>
              <div class="coverage-row">
                <template v-if="(bus.insurance_coverage || []).length">
                  <span
                    v-for="a in bus.insurance_coverage"
                    :key="'i-' + a.type"
                    class="doc-chip"
                    :class="chipClass(a.status)"
                    :title="a.name + ': ' + alertLabel(a.status)"
                  >{{ a.type }}</span>
                </template>
                <span v-else class="no-coverage">—</span>
              </div>
            </td>
            <td>
              <div class="coverage-row">
                <template v-if="(bus.transit_doc_coverage || []).length">
                  <span
                    v-for="a in bus.transit_doc_coverage"
                    :key="'d-' + a.type"
                    class="doc-chip"
                    :class="chipClass(a.status)"
                    :title="a.name + ': ' + alertLabel(a.status)"
                  >{{ a.type }}</span>
                </template>
                <span v-else class="no-coverage">—</span>
              </div>
            </td>
            <td>
              <div class="actions-cell">
                <button
                  v-if="canEdit"
                  class="btn-icon"
                  title="Editar"
                  @click="$emit('edit-bus', bus)"
                >✏️</button>
                <button
                  class="btn-icon btn-icon-compliance"
                  title="Gestionar Cumplimiento"
                  @click="$emit('open-compliance', bus.plate_number)"
                >📋</button>
              </div>
            </td>
          </tr>
          <tr v-if="filteredBuses.length === 0">
            <td colspan="6" class="no-data-cell">
              {{ isSearching ? 'No se encontraron buses con los criterios de búsqueda.' : 'No hay buses registrados.' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="filteredBuses.length === 0" class="no-data">
      {{ isSearching
        ? 'No se encontraron buses con los criterios de búsqueda.'
        : 'No hay buses registrados. Haga clic en "Nuevo Bus" para agregar el primero.' }}
    </div>
  </div>
</template>

<script setup>
const props = defineProps({
  filteredBuses: { type: Array, required: true },
  companies:     { type: Array, required: true },
  drivers:       { type: Array, required: true },
  canEdit:       { type: Boolean, default: false },
  isSearching:   { type: Boolean, default: false }
})

defineEmits(['edit-bus', 'open-compliance'])

const chipClass = (status) => {
  if (status === 'missing')  return 'chip-missing'
  if (status === 'expired')  return 'chip-expired'
  if (status === 'expiring') return 'chip-warning'
  return 'chip-valid'
}

const alertLabel = (status) => {
  if (status === 'missing')  return 'Sin registro activo'
  if (status === 'expired')  return 'Vencido'
  if (status === 'expiring') return 'Vence en ≤30 días'
  return 'Vigente'
}

const getCompanyName = (companyId) => {
  const found = props.companies.find(c => c.id_company === companyId)
  return found ? found.company_name : 'Desconocida'
}

const COMPANY_COLOR_CLASSES = ['company-1', 'company-2', 'company-3', 'company-4']

const getCompanyClass = (companyId) => {
  const idx = props.companies.findIndex(c => c.id_company === companyId)
  if (idx === -1) return 'company-default'
  return COMPANY_COLOR_CLASSES[idx % COMPANY_COLOR_CLASSES.length]
}

const getDriverName = (driverId) => {
  if (!driverId) return 'Sin asignar'
  const driver = props.drivers.find(d => d.id_driver === driverId)
  return driver ? driver.name_driver : 'Desconocido'
}
</script>

<style scoped>
/* ── Contenedor con scroll ─────────────────────────────────── */
.fleet-table-container {
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

.fleet-table-container::-webkit-scrollbar { width: 8px; height: 8px; }
.fleet-table-container::-webkit-scrollbar-track { background: #f1f5f9; border-radius: 12px; }
.fleet-table-container::-webkit-scrollbar-thumb { background-color: #cbd5e1; border-radius: 4px; border: 2px solid #f1f5f9; }
.fleet-table-container::-webkit-scrollbar-thumb:hover { background-color: #94a3b8; }

/* ── Tabla ──────────────────────────────────────────────────── */
.fleet-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  table-layout: fixed;
}

.fleet-table th:nth-child(1), .fleet-table td:nth-child(1) { width: 6%;  text-align: center; }
.fleet-table th:nth-child(2), .fleet-table td:nth-child(2) { width: 28%; }
.fleet-table th:nth-child(3), .fleet-table td:nth-child(3) { width: 17%; text-align: center; }
.fleet-table th:nth-child(4), .fleet-table td:nth-child(4) { width: 17%; }
.fleet-table th:nth-child(5), .fleet-table td:nth-child(5) { width: 17%; }
.fleet-table th:nth-child(6), .fleet-table td:nth-child(6) { width: 15%; text-align: center; }

.fleet-table th {
  background: #f8fafc;
  padding: 14px 20px;
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

.fleet-table td {
  padding: 12px 20px;
  border-bottom: 1px solid #f1f5f9;
  color: #1e293b;
  font-size: 14px;
  vertical-align: middle;
}

.fleet-table tr:last-child td { border-bottom: none; }
.fleet-table tr:hover { background: #f8fafc; }

/* ── Celda ID ───────────────────────────────────────────────── */
.id-cell { text-align: center; font-size: 13px; color: #64748b; }

/* ── Celda Bus ──────────────────────────────────────────────── */
.bus-info-compact { display: flex; align-items: center; gap: 14px; }

.bus-avatar-with-plate {
  position: relative;
  width: 70px;
  height: 60px;
  border-radius: 50%;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
  flex-shrink: 0;
  overflow: hidden;
}

.bus-emoji { font-size: 28px; margin-top: -12px; }

.bus-plate-overlay {
  position: absolute;
  bottom: 5px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(30, 41, 59, 0.95);
  border: 1px solid rgba(71, 85, 105, 0.8);
  border-radius: 3px;
  padding: 2px 5px;
  font-size: 8.5px;
  font-weight: 700;
  letter-spacing: 1px;
  color: white;
  text-align: center;
  white-space: nowrap;
  max-width: 85%;
  overflow: hidden;
  text-overflow: ellipsis;
}

.bus-name-col { display: flex; flex-direction: column; }
.bus-name-col .code   { font-size: 14px; color: #1e293b; font-weight: 700; text-transform: uppercase; }
.bus-name-col .driver { font-size: 12px; color: #64748b; font-weight: 400; margin-top: 2px; }
.bus-name-col .driver.no-driver { color: #94a3b8; font-style: italic; }

/* ── Celda Empresa ──────────────────────────────────────────── */
.company-cell { display: flex; justify-content: center; align-items: center; }

.company-name {
  display: inline-block;
  padding: 6px 14px;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  border: 1px solid;
  transition: all 0.2s ease;
}

.company-name:hover { transform: translateY(-1px); box-shadow: 0 2px 4px rgba(0,0,0,0.1); }

.company-name.company-1 { background: linear-gradient(135deg,#dbeafe,#bfdbfe); color:#1e40af; border-color:#93c5fd; }
.company-name.company-2 { background: linear-gradient(135deg,#d1fae5,#a7f3d0); color:#065f46; border-color:#6ee7b7; }
.company-name.company-3 { background: linear-gradient(135deg,#fed7aa,#fdba74); color:#9a3412; border-color:#fb923c; }
.company-name.company-4 { background: linear-gradient(135deg,#e9d5ff,#d8b4fe); color:#6b21a8; border-color:#c084fc; }
.company-name.company-default { background: linear-gradient(135deg,#f1f5f9,#e2e8f0); color:#475569; border-color:#cbd5e1; }

/* ── Chips de cobertura ─────────────────────────────────────── */
.coverage-row { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
.no-coverage  { color: #cbd5e1; font-size: 13px; }

.doc-chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  font-size: 7.5px;
  font-weight: 700;
  cursor: help;
  border: 1.5px solid;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  letter-spacing: -0.3px;
}

.doc-chip:hover { transform: scale(1.2); box-shadow: 0 2px 8px rgba(0,0,0,0.18); }

.doc-chip.chip-valid   { background:#d1fae5; color:#065f46; border-color:#10b981; }
.doc-chip.chip-warning { background:#fef3c7; color:#92400e; border-color:#f59e0b; }
.doc-chip.chip-expired { background:#fee2e2; color:#991b1b; border-color:#ef4444; }
.doc-chip.chip-missing { background:#f1f5f9; color:#94a3b8; border-color:#cbd5e1; }

/* ── Acciones ───────────────────────────────────────────────── */
.actions-cell { display: flex; gap: 10px; justify-content: center; align-items: center; }

.btn-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  background: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  transition: all 0.2s ease;
}

.btn-icon:hover { background:#f8fafc; border-color:#cbd5e1; transform:translateY(-1px); }
.btn-icon-compliance:hover { background:#e0f2fe; border-color:#38bdf8; }

/* ── Sin datos ──────────────────────────────────────────────── */
.no-data-cell { text-align: center; padding: 40px; color: #64748b; font-style: italic; }

.no-data {
  text-align: center;
  padding: 40px 20px;
  color: #64748b;
  font-style: italic;
  background: #f8fafc;
  border-radius: 12px;
  margin: 20px 0;
}
</style>

<template>
  <div class="catalog-card">
    <div class="card-header">
      <div class="card-title">
        <span>{{ icon }}</span>
        <h3>{{ title }}</h3>
        <span class="record-count">{{ items.length }}</span>
      </div>
      <button v-if="canCreate" class="btn primary btn-sm" @click="$emit('create')">
        ➕ {{ singular }}
      </button>
    </div>
    <div v-if="cardError" class="card-error-banner">
      <span class="card-error-icon">🚫</span>
      <span class="card-error-msg">{{ cardError }}</span>
    </div>
    <div class="catalog-table-container">
      <div v-if="loading" class="loading-state">Cargando...</div>
      <table v-else class="catalog-table">
        <thead class="mobile-hidden">
          <tr>
            <th class="th-id">ID</th>
            <th>Nombre</th>
            <th v-if="extraKey">{{ extraLabel }}</th>
            <th>Estado</th>
            <th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="items.length === 0">
            <td :colspan="extraKey ? 5 : 4" class="empty-row">Sin registros</td>
          </tr>
          <tr v-for="item in items" :key="item[idKey]" class="catalog-row">
            <td class="id-cell">{{ item[idKey] }}</td>
            <td class="name-cell">
              <span class="main-text">{{ item[nameKey] }}</span>
              <span v-if="extraKey" class="sub-text">{{ item[extraKey] }}</span>
            </td>
            <td class="status-cell">
              <span class="status-dot" :class="item.is_active ? 'active' : 'inactive'" :title="item.is_active ? 'Activo' : 'Inactivo'"></span>
              <span class="status-label mobile-hidden">{{ item.is_active ? 'Activo' : 'Inactivo' }}</span>
            </td>
            <td class="actions-cell">
              <button v-if="canEdit" class="btn-action edit" @click="$emit('edit', item)" title="Editar">✏️</button>
              <button
                v-if="canToggle"
                class="btn-action toggle"
                @click="$emit('toggle', item)"
                :title="item.is_active ? 'Inactivar' : 'Activar'"
              >{{ item.is_active ? '🔴' : '🟢' }}</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
defineProps({
  title:      { type: String,  required: true },
  icon:       { type: String,  required: true },
  singular:   { type: String,  required: true },
  items:      { type: Array,   default: () => [] },
  loading:    { type: Boolean, default: false },
  idKey:      { type: String,  required: true },
  nameKey:    { type: String,  required: true },
  extraKey:   { type: String,  default: null },
  extraLabel: { type: String,  default: null },
  cardError:  { type: String,  default: null },
  // Props de permisos RBAC
  canCreate:  { type: Boolean, default: false },
  canEdit:    { type: Boolean, default: false },
  canToggle:  { type: Boolean, default: false },
})
defineEmits(['create', 'edit', 'toggle'])
</script>

<style scoped>
.catalog-card {
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 14px;
  border-bottom: 1px solid #f1f5f9;
  background: #f8fafc;
}

.card-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.card-title h3 {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: #1e293b;
}

.record-count {
  background: #e2e8f0;
  color: #64748b;
  font-size: 12px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 20px;
}

.catalog-table-container {
  overflow-x: auto;
}

.card-error-banner {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  background: #fee2e2;
  border-left: 4px solid #ef4444;
  padding: 12px 16px;
  animation: fadeInBanner 0.25s ease;
}

@keyframes fadeInBanner {
  from { opacity: 0; transform: translateY(-4px); }
  to   { opacity: 1; transform: translateY(0); }
}

.card-error-icon {
  font-size: 18px;
  flex-shrink: 0;
  line-height: 1.3;
}

.card-error-msg {
  font-size: 13px;
  font-weight: 500;
  color: #991b1b;
  line-height: 1.4;
}

.catalog-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.catalog-table thead th {
  background: #f8fafc;
  padding: 6px 12px;
  text-align: left;
  font-weight: 600;
  color: #475569;
  border-bottom: 1px solid #e2e8f0;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  white-space: nowrap;
}

.catalog-table tbody tr {
  border-bottom: 1px solid #f1f5f9;
  transition: background 0.15s;
}

.catalog-table tbody tr:hover { background: #f8fafc; }

.catalog-table td {
  padding: 7px 12px;
  color: #334155;
}

.id-cell {
  color: #94a3b8;
  font-size: 12px;
}

.empty-row {
  text-align: center;
  color: #94a3b8;
  padding: 18px 12px !important;
  font-size: 13px;
}

.status-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
}
.status-dot.active { background: #10b981; box-shadow: 0 0 8px rgba(16, 185, 129, 0.4); }
.status-dot.inactive { background: #94a3b8; }

.actions-cell {
  display: flex;
  gap: 4px;
  white-space: nowrap;
}

.btn-action {
  background: none;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 3px 7px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.15s;
}

.btn-action:hover { background: #f1f5f9; border-color: #cbd5e1; }

.loading-state {
  padding: 18px;
  text-align: center;
  color: #94a3b8;
  font-size: 13px;
}

.btn {
  padding: 7px 14px;
  border-radius: 8px;
  border: none;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  transition: all 0.2s;
}

.btn.primary { background: #2563eb; color: white; }
.btn-sm { padding: 5px 11px; font-size: 12px; }

/* Responsive */
@media (max-width: 768px) {
  .catalog-card { border: none; border-radius: 0; }
  .card-header {
    padding: 12px 16px;
    background: white;
    border-bottom: 1px solid #f1f5f9;
  }
  .card-title h3 { font-size: 14px; }
  .mobile-hidden { display: none !important; }
  .catalog-table, .catalog-table tbody, .catalog-table tr { display: block; width: 100%; }
  .catalog-row {
    display: flex !important;
    align-items: center;
    padding: 12px 16px;
    background: white;
    border-bottom: 1px solid #f1f5f9;
    gap: 12px;
  }
  .id-cell { width: 30px; font-size: 10px; color: #cbd5e1; padding: 0 !important; }
  .name-cell { flex: 1; display: flex; flex-direction: column; padding: 0 !important; min-width: 0; }
  .main-text { font-size: 14px; font-weight: 500; color: #1e293b; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sub-text { font-size: 11px; color: #94a3b8; }
  .status-cell { width: 24px; padding: 0 !important; display: flex; justify-content: center; }
  .actions-cell { width: auto; padding: 0 !important; gap: 12px; border: none !important; }
  .btn-action {
    width: 36px; height: 36px; border: none; background: #f1f5f9;
    font-size: 15px; border-radius: 8px; display: flex; align-items: center; justify-content: center;
  }
}
</style>

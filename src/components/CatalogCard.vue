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
        <thead>
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
          <tr v-for="item in items" :key="item[idKey]">
            <td class="id-cell">{{ item[idKey] }}</td>
            <td>{{ item[nameKey] }}</td>
            <td v-if="extraKey">{{ item[extraKey] }}</td>
            <td>
              <span class="status-badge" :class="item.is_active ? 'active' : 'inactive'">
                {{ item.is_active ? 'Activo' : 'Inactivo' }}
              </span>
            </td>
            <td class="actions-cell">
              <button v-if="canEdit" class="btn-action" @click="$emit('edit', item)" title="Editar">✏️</button>
              <button
                v-if="canToggle"
                class="btn-action"
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

.catalog-table thead th:nth-child(2) {
  width: 100%;
}

.th-id { width: 48px; }

.catalog-table tbody tr {
  border-bottom: 1px solid #f1f5f9;
  transition: background 0.15s;
}

.catalog-table tbody tr:hover { background: #f8fafc; }
.catalog-table tbody tr:last-child { border-bottom: none; }

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

.status-badge {
  display: inline-block;
  padding: 2px 9px;
  border-radius: 20px;
  font-size: 11px;
  font-weight: 500;
  white-space: nowrap;
}

.status-badge.active   { background: #dcfce7; color: #166534; }
.status-badge.inactive { background: #f1f5f9; color: #64748b; }

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
.btn.primary:hover { background: #1d4ed8; }
.btn-sm { padding: 5px 11px; font-size: 12px; }
</style>

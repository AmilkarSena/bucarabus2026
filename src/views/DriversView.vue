<template>
  <div class="drivers-section">

    <!-- Encabezado: estadísticas + botón -->
    <div class="section-header">
      <div class="header-stats">
        <div class="stat-card">
          <h3>Total Conductores</h3>
          <span>{{ totalDrivers }}</span>
        </div>
        <div class="stat-card">
          <h3>Disponibles</h3>
          <span class="available">{{ availableDriversCount }}</span>
        </div>
      </div>
      <div class="header-actions">
        <button v-if="canCreate" class="btn primary" @click="openDriverModal">
          <span>➕</span> Nuevo Conductor
        </button>
      </div>
    </div>

    <!-- Filtros y búsqueda -->
    <div class="drivers-controls">
      <div class="search-filters">
        <input
          type="text"
          v-model="searchQuery"
          placeholder="Buscar por nombre, cédula o teléfono..."
          class="search-input"
        />
        <select v-model="availabilityFilter" class="filter-select">
          <option value="">Todos los estados</option>
          <option value="true">Activos</option>
          <option value="false">Inactivos</option>
        </select>
        <select v-model="categoryFilter" class="filter-select">
          <option value="">Todas las categorías</option>
          <option value="C1">Categoría C1</option>
          <option value="C2">Categoría C2</option>
          <option value="C3">Categoría C3</option>
        </select>
      </div>
    </div>

    <!-- Tabla de conductores -->
    <DriverTable
      :filteredDrivers="filteredDrivers"
      :canEdit="canEdit"
      :isSearching="isSearching"
      :formatDate="formatDate"
      :getStatusClass="getStatusClass"
      :getLicenseStatusClass="getLicenseStatusClass"
      :isLicenseValid="isLicenseValid"
      @edit-driver="editDriver"
      @view-driver="viewDriverDetails"
      @open-account="openAccountModal"
    />

    <!-- Modal cuenta de sistema -->
    <DriverAccountModal
      v-if="showAccountModal"
      :driver="selectedDriverForAccount"
      @close="showAccountModal = false"
      @updated="onAccountUpdated"
    />

  </div>
</template>

<script setup>
import DriverTable from '../components/drivers/DriverTable.vue'
import DriverAccountModal from '../components/modals/DriverAccountModal.vue'
import { useDrivers } from '../composables/useDrivers'

const {
  searchQuery,
  availabilityFilter,
  categoryFilter,
  showAccountModal,
  selectedDriverForAccount,
  totalDrivers,
  availableDriversCount,
  filteredDrivers,
  isSearching,
  canEdit,
  canCreate,
  formatDate,
  getStatusClass,
  getLicenseStatusClass,
  isLicenseValid,
  openDriverModal,
  editDriver,
  viewDriverDetails,
  toggleStatus,
  openAccountModal,
  onAccountUpdated
} = useDrivers()
</script>

<style scoped>
.drivers-section { padding: 0; }

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 24px;
  padding: 20px;
  background: white;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.header-stats { display: flex; gap: 16px; }

.stat-card {
  text-align: center;
  background: #f8fafc;
  padding: 16px;
  border-radius: 8px;
  min-width: 120px;
}

.stat-card h3 {
  font-size: 12px;
  color: #64748b;
  margin: 0 0 8px 0;
  text-transform: uppercase;
  font-weight: 500;
}

.stat-card span { font-size: 24px; font-weight: 700; color: #667eea; }
.stat-card span.available { color: #10b981; }

.header-actions { display: flex; gap: 12px; }

.btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 20px;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 500;
  transition: all 0.3s ease;
}

.btn.primary { background: #667eea; color: white; }
.btn.primary:hover {
  background: #5a67d8;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.drivers-controls { margin: 20px 0; }

.search-filters { display: flex; gap: 15px; flex-wrap: wrap; }

.search-input,
.filter-select {
  padding: 10px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  background: white;
  transition: border-color 0.3s ease;
}

.search-input { flex: 1; min-width: 200px; }
.search-input:focus, .filter-select:focus { outline: none; border-color: #667eea; }

/* Responsive */
@media (max-width: 768px) {
  .section-header { flex-direction: column; gap: 16px; align-items: stretch; }
  .header-stats { flex-wrap: wrap; justify-content: center; }
  .header-actions { justify-content: center; }
  .search-filters { flex-direction: column; }
  .search-input { min-width: auto; }
}
</style>

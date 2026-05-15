<template>
  <div class="fleet-section">
    <!-- Modal de cumplimiento (Seguros y Documentos) -->
    <BusComplianceModal
      v-if="showComplianceModal"
      :plate="selectedBusPlate"
      :initial-section="initialComplianceSection"
      @close="showComplianceModal = false"
      @updated="busesStore.fetchBuses()"
    />
    <div class="section-header">
      <FleetStats
        :totalBuses="totalBuses"
        :availableBusesCount="availableBusesCount"
        :totalCapacity="totalCapacity"
      />
      <div class="header-actions">
        <button class="btn primary" v-if="canEdit" @click="openBusModal">
          <span>➕</span> Nuevo Bus
        </button>
      </div>
    </div>

    <FleetControls
      v-model:searchQuery="searchQuery"
      v-model:availabilityFilter="availabilityFilter"
      v-model:companyFilter="companyFilter"
      :companies="companies"
    />

    <FleetTable
      :filteredBuses="filteredBuses"
      :companies="companies"
      :drivers="drivers"
      :canEdit="canEdit"
      :isSearching="isSearching"
      @edit-bus="editBus"
      @open-compliance="openComplianceModal"
    />
  </div>
</template>

<script setup>
import BusComplianceModal from '../components/modals/compliance/BusComplianceModal.vue'
import FleetStats from '../components/fleet/FleetStats.vue'
import FleetControls from '../components/fleet/FleetControls.vue'
import FleetTable from '../components/fleet/FleetTable.vue'
import { useFleet } from '../composables/useFleet'

const {
  searchQuery,
  availabilityFilter,
  companyFilter,
  showComplianceModal,
  initialComplianceSection,
  selectedBusPlate,
  companies,
  drivers,
  canEdit,
  busesStore,
  totalBuses,
  availableBusesCount,
  totalCapacity,
  filteredBuses,
  isSearching,
  openComplianceModal,
  openBusModal,
  editBus
} = useFleet()
</script>

<style scoped>
.fleet-section {
  padding: 0;
}

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

.header-actions {
  display: flex;
  gap: 12px;
}

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

.btn.primary {
  background: #667eea;
  color: white;
}

.btn.primary:hover {
  background: #5a67d8;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

/* Responsive */
@media (max-width: 768px) {
  .fleet-section { padding: 12px; }
  
  .section-header {
    flex-direction: column;
    gap: 12px;
    padding: 12px;
    margin-bottom: 16px;
  }

  .header-actions {
    width: 100%;
  }

  .header-actions .btn {
    width: 100%;
    justify-content: center;
    padding: 10px;
    font-size: 14px;
  }
}
</style>

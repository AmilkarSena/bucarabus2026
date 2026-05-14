<template>
  <div class="fleet-controls">
    <div class="search-filters">
      <input
        type="text"
        :value="searchQuery"
        @input="$emit('update:searchQuery', $event.target.value)"
        placeholder="Buscar por placa, código AMB o compañía..."
        class="search-input"
      />
      <select 
        :value="availabilityFilter" 
        @change="$emit('update:availabilityFilter', $event.target.value)" 
        class="filter-select"
      >
        <option value="true">Activos (Disponibles)</option>
        <option value="">Todos los estados</option>
        <option value="false">Inactivos</option>
      </select>
      <select 
        :value="companyFilter" 
        @change="$emit('update:companyFilter', $event.target.value)" 
        class="filter-select"
      >
        <option value="">Todas las compañías</option>
        <option v-for="c in companies" :key="c.id_company" :value="String(c.id_company)">
          {{ c.company_name }}
        </option>
      </select>
    </div>
  </div>
</template>

<script setup>
defineProps({
  searchQuery: {
    type: String,
    required: true
  },
  availabilityFilter: {
    type: String,
    required: true
  },
  companyFilter: {
    type: String,
    required: true
  },
  companies: {
    type: Array,
    default: () => []
  }
})

defineEmits([
  'update:searchQuery', 
  'update:availabilityFilter', 
  'update:companyFilter'
])
</script>

<style scoped>
.fleet-controls {
  margin: 20px 0;
}

.search-filters {
  display: flex;
  gap: 15px;
  flex-wrap: wrap;
}

.search-input,
.filter-select {
  padding: 10px 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  background: white;
  transition: border-color 0.3s ease;
}

.search-input {
  flex: 1;
  min-width: 200px;
}

.search-input:focus,
.filter-select:focus {
  outline: none;
  border-color: #667eea;
}

@media (max-width: 768px) {
  .search-filters {
    flex-direction: column;
  }

  .search-input {
    min-width: auto;
  }
}
</style>

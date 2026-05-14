<template>
  <div class="info-panel stops-panel full-width">
    <div class="stops-header">
      <strong v-if="!isEdit && !fromDraft">🚏 Paradas detectadas: {{ detectedStops.length }}</strong>
      <strong v-else>🚏 Paradas {{ isEdit ? 'asignadas' : 'seleccionadas' }}: {{ stops.length }}</strong>
      
      <template v-if="!isEdit && !fromDraft">
        <span v-if="loadingDetection" class="loading-text"> Buscando...</span>
        <label class="threshold-label">
          Umbral: <strong>{{ threshold }}m</strong>
          <input 
            type="range" 
            min="30" 
            max="200" 
            step="10" 
            :value="threshold"
            @change="$emit('update:threshold', parseInt($event.target.value))" 
            class="threshold-slider"
          >
        </label>
      </template>
    </div>
    
    <div v-if="!isEdit && !fromDraft && detectedStops.length === 0 && !loadingDetection" class="stops-empty">
      No se encontraron paradas dentro de {{ threshold }}m de la ruta.
    </div>
    
    <div v-else class="stops-table-container">
      <table class="stops-table">
        <thead>
          <tr>
            <th style="width: 40px;">#</th>
            <th style="width: 60px;">ID</th>
            <th>Nombre de la Parada</th>
            <th v-if="!isEdit && !fromDraft" style="width: 80px;">Distancia</th>
          </tr>
        </thead>
        <tbody>
          <!-- Si es dibujo libre, iterar detectedStops -->
          <template v-if="!isEdit && !fromDraft">
            <tr v-for="(p, i) in detectedStops" :key="i">
              <td class="stop-order">{{ i + 1 }}</td>
              <td class="stop-id">{{ p.idPoint }}</td>
              <td>{{ p.namePoint || 'Sin nombre' }}</td>
              <td>{{ p.dist }}m</td>
            </tr>
          </template>
          <!-- Si es borrador o edición, iterar stops -->
          <template v-else>
            <tr v-for="(s, i) in stops" :key="s.id_point">
              <td class="stop-order">{{ i + 1 }}</td>
              <td class="stop-id">{{ s.id_point }}</td>
              <td>{{ s.name_point || 'Sin nombre' }}</td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
defineProps({
  isEdit: {
    type: Boolean,
    default: false
  },
  fromDraft: {
    type: Boolean,
    default: false
  },
  detectedStops: {
    type: Array,
    default: () => []
  },
  stops: {
    type: Array,
    default: () => []
  },
  loadingDetection: {
    type: Boolean,
    default: false
  },
  threshold: {
    type: Number,
    default: 80
  }
})

defineEmits(['update:threshold'])
</script>

<style scoped>
.stops-panel {
  background: rgba(16, 185, 129, 0.06);
  border-color: rgba(16, 185, 129, 0.25);
  color: #065f46;
}

.stops-panel strong {
  color: #047857;
}



.stops-header {
  display: flex;
  align-items: center;
  gap: 16px;
  flex-wrap: wrap;
  margin-bottom: 8px;
}

.threshold-label {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: #047857;
  cursor: default;
  margin-left: auto;
}

.threshold-slider {
  width: 90px;
  accent-color: #10b981;
  cursor: pointer;
}

.stops-empty {
  font-size: 13px;
  color: #6b7280;
  font-style: italic;
}

.loading-text {
  font-size: 13px;
  color: #059669;
  font-style: italic;
}

.stops-table-container {
  max-height: 200px;
  overflow-y: auto;
  margin-top: 10px;
  border: 1px solid rgba(16, 185, 129, 0.2);
  border-radius: 6px;
  background: white;
}

.stops-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;
  text-align: left;
}

.stops-table th {
  background: #f8fafc;
  padding: 8px 12px;
  color: #475569;
  font-weight: 600;
  position: sticky;
  top: 0;
  z-index: 1;
  border-bottom: 1px solid #e2e8f0;
}

.stops-table td {
  padding: 6px 12px;
  border-bottom: 1px solid #f1f5f9;
  color: #334155;
}

.stops-table tbody tr:hover {
  background: #f8fafc;
}

.stop-order {
  font-weight: 700;
  color: #047857;
}

.stop-id {
  color: #64748b;
  font-family: monospace;
}
</style>

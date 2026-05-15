<template>
  <div class="header-stats">
    <div class="stat-card">
      <h3>Total Buses</h3>
      <span>{{ totalBuses }}</span>
    </div>
    <div class="stat-card">
      <h3>Disponibles</h3>
      <span class="available">{{ availableBusesCount }}</span>
    </div>
    <div class="stat-card">
      <h3>Capacidad Total</h3>
      <span>{{ totalCapacity }}</span>
    </div>
  </div>
</template>

<script setup>
defineProps({
  totalBuses: {
    type: Number,
    required: true
  },
  availableBusesCount: {
    type: Number,
    required: true
  },
  totalCapacity: {
    type: Number,
    required: true
  }
})
</script>

<style scoped>
.header-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  width: 100%;
}

.stat-card {
  text-align: center;
  background: #f8fafc;
  padding: 16px 8px;
  border-radius: 10px;
  border: 1px solid #e2e8f0;
}

.stat-card h3 {
  font-size: 11px;
  color: #64748b;
  margin: 0 0 6px 0;
  text-transform: uppercase;
  font-weight: 600;
  letter-spacing: 0.5px;
}

.stat-card span {
  font-size: 20px;
  font-weight: 800;
  color: #667eea;
}

.stat-card span.available {
  color: #10b981;
}

@media (max-width: 1024px) {
  .header-stats {
    gap: 10px;
  }
}

@media (max-width: 768px) {
  .header-stats {
    grid-template-columns: repeat(3, 1fr); /* Mantener 3 columnas en móvil para que sean pequeñas */
    gap: 6px;
  }
  .stat-card {
    padding: 8px 4px;
  }
  .stat-card h3 {
    font-size: 9px;
    margin-bottom: 2px;
  }
  .stat-card span {
    font-size: 15px;
  }
}

@media (max-width: 480px) {
  .stat-card span {
    font-size: 14px;
  }
}
</style>

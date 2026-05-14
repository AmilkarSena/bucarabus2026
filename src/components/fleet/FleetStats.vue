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
  display: flex;
  gap: 16px;
}

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

.stat-card span {
  font-size: 24px;
  font-weight: 700;
  color: #667eea;
}

.stat-card span.available {
  color: #10b981;
}

@media (max-width: 768px) {
  .header-stats {
    flex-wrap: wrap;
    justify-content: center;
  }
}
</style>
